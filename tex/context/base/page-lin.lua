if not modules then modules = { } end modules ['page-lin'] = {
    version   = 1.001,
    comment   = "companion to page-lin.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- experimental

nodes            = nodes            or { }
nodes.lines      = nodes.lines      or { }
nodes.lines.data = nodes.lines.data or { } -- start step tag

do

    -- if there is demand for it, we can support multiple numbering streams
    -- and use more than one attibute

    local hlist, vlist, whatsit = node.id('hlist'), node.id('vlist'), node.id('whatsit')

    local display_math     = attributes.numbers['display-math']   or 121
    local line_number      = attributes.numbers['line-number']    or 131
    local line_reference   = attributes.numbers['line-reference'] or 132

    local current_list     = { }
    local cross_references = { }
    local chunksize        = 250 -- not used in boxed

    local has_attribute    = node.has_attribute
    local traverse_id      = node.traverse_id
    local copy             = node.copy
    local format           = string.format
    local sprint           = tex.sprint

    local data = nodes.lines.data

    nodes.lines.scratchbox = nodes.lines.scratchbox or 0

    -- cross referencing

    function nodes.lines.number(n)
        local cr = cross_references[n] or 0
        cross_references[n] = nil
        return cr
    end

    local function resolve(n,m)
        while n do
            local id = n.id
            if id == whatsit then
                local a = has_attribute(n,line_reference)
                if a then
                    cross_references[a] = m
                end
            elseif id == hlist or id == vlist then
                resolve(n.list,m)
            end
            n = n.next
        end
    end

    -- boxed variant

    nodes.lines.boxed = { }

    function nodes.lines.boxed.register(configuration)
        data[#data+1] = configuration
        return #data
    end
    function nodes.lines.boxed.setup(n,configuration)
        local d = data[n]
        if d then
            for k,v in pairs(configuration) do d[k] = v end
        else
            data[n] = configuration
        end
        return n
    end

    local leftskip = nodes.leftskip

    function nodes.lines.boxed.stage_one(n)
        current_list = { }
        local head = tex.box[n].list
        local function check_number(n,a) -- move inline
            local d = data[a]
            if d then
                local s = d.start
                current_list[#current_list+1] = { n, s }
                if d.start % d.step == 0 then
                    sprint(tex.ctxcatcodes, format("\\makenumber{%s}{%s}{%s}{%s}{%s}\\endgraf", d.tag or "", s, n.shift, n.width, leftskip(n.list)))
                else
                    sprint(tex.ctxcatcodes, "\\skipnumber\\endgraf")
                end
                d.start = s + 1 -- (d.step or 1)
            end
        end
        for n in traverse_id(hlist,head) do -- attr test here and quit as soon as zero found
            if n.height == 0 and n.depth == 0 then
                -- skip funny hlists
            else
                local a = has_attribute(n.list,line_number)
                if a and a > 0 then
                    if has_attribute(n,display_math) then
                        if nodes.is_display_math(n) then
                            check_number(n,a)
                        end
                    else
                        if node.first_character(n.list) then
                            check_number(n,a)
                        end
                    end
                end
            end
        end
    end

    function nodes.lines.boxed.stage_two(n,m)
        m = m or nodes.lines.scratchbox
        local t, i = { }, 0
        for l in traverse_id(hlist,tex.box[m].list) do
            t[#t+1] = copy(l)
        end
        for _, l in ipairs(current_list) do
            local n, m = l[1], l[2]
            i = i + 1
            t[i].next = n.list
            n.list = t[i]
            resolve(n,m)
       end
    end

    -- flow variant
    --
    -- it's too hard to make this one robust, so for the moment it's not
    -- available; todo: line refs

    if false then

        nodes.lines.flowed = { }

        function nodes.lines.flowed.prepare()
            for i=1,#data do
                sprint(tex.ctxcatcodes,format("\\ctxlua{nodes.lines.flowed.prepare_a(%s)}\\ctxlua{nodes.lines.flowed.prepare_b(%s)}",i, i))
            end
        end

        function nodes.lines.flowed.prepare_a(i)
            local d = data[i]
            local p = d.present
            if p < chunksize then
                local b = nodes.lines.scratchbox
                sprint(tex.ctxcatcodes, format("{\\forgetall\\global\\setbox%s=\\vbox{\\unvbox%s\\relax\\offinterlineskip", b, b))
                while p < chunksize do
                    sprint(tex.ctxcatcodes, format("\\mkmaketextlinenumber{%s}{%s}\\endgraf",d.start,1))
                    p = p + 1
                    d.start = d.start + d.step
                end
                d.present = p
                sprint(tex.ctxcatcodes, "}}")
            end
        end

        function nodes.lines.flowed.prepare_b(i)
            local d = data[i]
            local b = nodes.lines.scratchbox
            local l = tex.box[b]
            if l then
                l = l.list
                local n = d.numbers
                while l do
                    if l.id == hlist then
                        local m = node.copy(l)
                        m.next = nil
                        if n then
                            n.next = m
                        else
                            d.numbers = m
                        end
                        n = m
                    end
                    l = l.next
                end
            end
            tex.box[b] = nil
        end

        function nodes.lines.flowed.cleanup(i)
            if i then
                node.flush_list(data[i].numbers)
            else
                for i=1,#data do
                    node.flush_list(data[i].numbers)
                end
            end
        end

        function nodes.lines.flowed.apply(head)
            local function check_number(n,a)
                local d = data[a]
                if d then
                    local m = d.numbers
                    if m then
                        d.numbers = m.next
                        m.next = n.list
                        n.list = m
                        d.present = d.present - 1
                    end
                end
            end
            for n in node.traverse(head) do
                local id = n.id
                if id == hlist then
                    if n.height == 0 and n.depth == 0 then
                        -- skip funny hlists
                    else
                        local a = has_attribute(n,line_number)
                        if a and a > 0 then
                            if has_attribute(n,display_math) then
                                if nodes.is_display_math(n) then
                                    check_number(n,a)
                                end
                            else
                                check_number(n,a)
                            end
                        end
                    end
                end
            end
            return head, true
        end

    end

end

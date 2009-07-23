if not modules then modules = { } end modules ['node-bck'] = {
    version   = 1.001,
    comment   = "companion to node-bck.tex",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- We supported pdf right from the start and in mkii this has resulted in
-- extensive control over the links. Nowadays pdftex provides a lot more
-- control over margins but as mkii supports multiple backends we stuck to
-- our own mechanisms. In mkiv again we implement our own handling. Eventually
-- we will even disable the pdf primitives.

-- helper, will end up in luatex

local cleanupreferences, cleanupdestinations = false, true

local nodeinjections = backends.nodeinjections
local codeinjections = backends.codeinjections

local hpack_list = node.hpack
local copy_list  = node.copy_list
local flush_list = node.flush_list

local function dimensions(parent,start,stop) -- so we need parent for glue_set info
    local n = stop.next
    stop.next = nil
    local p = hpack_list(copy_list(start))
    stop.next = n
    local w, h, d = p.width, p.height, p.depth
    flush_list(p)
    return w, h, d
end

-- current.glue_set current.glue_sign

local trace_backend      = false  trackers.register("nodes.backend",      function(v) trace_backend      = v end)
local trace_references   = false  trackers.register("nodes.references",   function(v) trace_references   = v end)
local trace_destinations = false  trackers.register("nodes.destinations", function(v) trace_destinations = v end)

local hlist   = node.id("hlist")
local vlist   = node.id("vlist")
local glue    = node.id("glue")
local whatsit = node.id("whatsit")

local new_kern = nodes.kern

local has_attribute  = node.has_attribute
local traverse       = node.traverse
local find_node_tail = node.tail or node.slide
local tosequence     = nodes.tosequence

local function inject_range(head,first,last,reference,make,stack,parent,pardir,txtdir)
    local width, height, depth = dimensions(parent,first,last)
    if pardir == "TRT" or txtdir == "+TRT" then
        width = - width
    end
    local result, resolved = make(width,height,depth,reference)
    if result and resolved then
        if head == first then
            if trace_backend then
                logs.report("backend","head: %04i %s %s %s => w=%s, h=%s, d=%s, c=%s",reference,pardir or "---",txtdir or "----",tosequence(first,last,true),width,height,depth,resolved)
            end
            result.next = first
            first.prev = result
            return result, last
        else
            if trace_backend then
                logs.report("backend","middle: %04i %s %s => w=%s, h=%s, d=%s, c=%s",reference,pardir or "---",txtdir or "----",tosequence(first,last,true),width,height,depth,resolved)
            end
            local prev = first.prev
            if prev then
                result.next = first
                result.prev = prev
                prev.next = result
                first.prev = result
            else
                result.next = first
                first.prev = result
            end
            if first == head.next then
                head.next = result -- hm, weird
            end
            return head, last
        end
    else
        return head, last
    end
end

local function inject_list(id,current,reference,make,stack,pardir,txtdir)
    local width, height, depth, correction = current.width, current.height, current.depth, 0
    local moveright = false
    local first = current.list
    if id == hlist then
        -- can be either an explicit hbox or a line and there is no way
        -- to recognize this; anyway only if ht/dp (then inline)
        local sr = stack[reference]
        if first then
            if sr and sr[2] then
                local last = find_node_tail(first)
                if last.id == glue and last.subtype == 9 then
                    local prev = last.prev
                    moveright = first.id == glue and first.subtype == 8
                    if prev.id == glue and prev.subtype == 15 then
                        width = dimensions(current,first,prev.prev) -- maybe not current as we already take care of it
                    else
                        if moveright and first.spec then
                            width = width - first.spec.stretch*current.glue_set * current.glue_sign
                        end
                        if last.spec then
                            width = width - last.spec.stretch*current.glue_set * current.glue_sign
                        end
                    end
                end
            else
                -- also weird
            end
        else
            -- ok
        end
        correction = width
    else
        correction = height + depth
        height, depth = depth, height -- ugly hack, needed because pdftex backend does something funny
    end
    if pardir == "TRT" then
        width = - width
    end
    local result, resolved = make(width,height,depth,reference)
    if result and resolved then
        if trace_backend then
            logs.report("backend","box: %04i %s %s: w=%s, h=%s, d=%s, c=%s",reference,pardir or "---",txtdir or "----",width,height,depth,resolved)
        end
        if not first then
            current.list = result
        elseif moveright then -- brr no prevs done
            -- result after first
            local n = first.next
            result.next = n
            first.next = result
            result.prev = first
            if n then n.prev = result end
        else
            -- first after result
            result.next = first
            first.prev = result
            current.list = result
        end
    end
end

local function inject_areas(head,attribute,make,stack,done,skip,parent,pardir,txtdir)  -- main
    if head then
        local current, first, last, firstdir, reference = head, nil, nil, nil, nil
        pardir = pardir or "==="
        txtdir = txtdir or "==="
        while current do
            local id = current.id
            local r = has_attribute(current,attribute)
            if id == whatsit then
                local subtype = current.subtype
                if subtype == 6 then
                    pardir = current.dir
                elseif subtype == 7 then
                    txtdir = current.dir
                end
            elseif id == hlist or id == vlist then
                if r and (not skip or r > skip) then
                    inject_list(id,current,r,make,stack,pardir,txtdir)
                    done[r] = true
                end
                local list = current.list
                if list then
                    local pd
                    current.list, _, pardir, txtdir = inject_areas(list,attribute,make,stack,done,r or skip or 0,current,pardir,txtdir)
                end
            elseif not r then
                -- just go on, can be kerns
            elseif not reference then
                reference, first, last, firstdir = r, current, current, txtdir
            elseif r == reference then
                last = current
            elseif not done[reference] then
                if not skip or r > skip then
                    head, current = inject_range(head,first,last,reference,make,stack,parent,pardir,firstdir)
                    reference, first, last, firstdir = nil, nil, nil, nil
                end
            else
                reference, first, last, firstdir = r, current, current, txtdir
            end
            current = current.next
        end
        if reference and not done[reference] then
            head = inject_range(head,first,last,reference,make,stack,parent,pardir,firstdir)
        end
    end
    return head, true, pardir, txtdir
end

local function inject_area(head,attribute,make,stack,done,pardir,txtdir) -- singular  !
    if head then
        pardir = pardir or "==="
        txtdir = txtdir or "==="
        local current = head
        while current do
            local id = current.id
            local r = has_attribute(current,attribute)
            if id == whatsit then
                local subtype = current.subtype
                if subtype == 6 then
                    pardir = current.dir
                elseif subtype == 7 then
                    txtdir = current.dir
                end
            elseif id == hlist or id == vlist then
                if r and not done[r] then
                    done[r] = true
                    inject_list(id,current,r,make,stack,pardir,txtdir)
                end
                current.list = inject_area(current.list,attribute,make,stack,done,pardir,txtdir)
            elseif r and not done[r] then
                done[r] = true
                head, current = inject_range(head,current,current,r,make,stack,pardir,txtdir)
            end
            current = current.next
        end
    end
    return head, true
end

-- tracing

local new_rule       = nodes.rule
local new_kern       = nodes.kern
local set_attribute  = node.set_attribute
local register_color = colors.register

local a_colormodel   = attributes.private('colormodel')
local a_color        = attributes.private('color')
local a_transparency = attributes.private('transparency')
local u_transparency = nil
local u_colors       = { }
local force_gray     = true

local function colorize(width,height,depth,n)
    if force_gray then n = 0 end
    u_transparency = u_transparency or transparencies.register(nil,2,.65)
    local ucolor = u_colors[n]
    if not ucolor then
        if n == 1 then
            u_color = register_color(nil,'rgb',.75,0,0)
        elseif n == 2 then
            u_color = register_color(nil,'rgb',0,.75,0)
        elseif n == 3 then
            u_color = register_color(nil,'rgb',0,0,.75)
        else
            n = 0
            u_color = register_color(nil,'gray',.5)
        end
        u_colors[n] = u_color
    end
    local rule = new_rule(width,height,depth)
    set_attribute(rule,a_colormodel,1) -- gray color model
    set_attribute(rule,a_color,u_color)
    set_attribute(rule,a_transparency,u_transparency)
    if width < 0 then
        local kern = new_kern(width)
        rule.width = -width
        kern.next = rule
        rule.prev = kern
        return kern
    else
        return rule
    end
end

local new_kern     = nodes.kern
local texattribute = tex.attribute
local texcount     = tex.count

-- references:

nodes.references = {
    attribute = attributes.private('reference'),
    stack = { },
    done  = { },
}

local stack, done, attribute = nodes.references.stack, nodes.references.done, nodes.references.attribute

local nofreferences, topofstack = 0, 0

local function setreference(n,h,d,r) -- n is just a number, can be used for tracing
    topofstack = topofstack + 1
    stack[topofstack] = { n, h, d, codeinjections.prerollreference(r) } -- the preroll permits us to determine samepage (but delayed also has some advantages)
--~     texattribute[attribute] = topofstack -- todo -> at tex end
    texcount.lastreferenceattribute = topofstack
end

nodes.setreference = setreference

local function makereference(width,height,depth,reference)
    local sr = stack[reference]
    if sr then
        local resolved, ht, dp, set = sr[1], sr[2], sr[3], sr[4]
        if ht then
            if height < ht then height = ht end
            if depth  < dp then depth  = dp end
        end
        local annot = nodeinjections.reference(width,height,depth,set)
        if annot then
            nofreferences = nofreferences + 1
            local result, current
            if trace_references then
                local step = 65536
                result = hpack_list(colorize(width,height-step,depth-step,2)) -- step subtracted so that we can see seperate links
                result.width = 0
                current = result
            end
            if current then
                current.next = annot
            else
                result = annot
            end
            result = hpack_list(result,0)
            result.width, result.height, result.depth = 0, 0, 0
            if cleanupreferences then stack[reference] = nil end
            return result, resolved
        else
            logs.report("backends","unable to resolve reference annotation %s",reference)
        end
    else
        logs.report("backends","unable to resolve reference attribute %s",reference)
    end
end

function nodes.add_references(head)
    if topofstack > 0 then
        return inject_areas(head,attribute,makereference,stack,done)
    else
        return head, false
    end
end

-- destinations (we can clean up once set!)

nodes.destinations = {
    attribute = attributes.private('destination'),
    stack = { },
    done  = { },
}

local stack, done, attribute = nodes.destinations.stack, nodes.destinations.done, nodes.destinations.attribute

local nofdestinations, topofstack = 0, 0

local function setdestination(n,h,d,name,view) -- n = grouplevel, name == table
    topofstack = topofstack + 1
    stack[topofstack] = { n, h, d, name, view }
    return topofstack
end

nodes.setdestination = setdestination

local function makedestination(width,height,depth,reference)
    local sr = stack[reference]
    if sr then
        local resolved, ht, dp, name, view = sr[1], sr[2], sr[3], sr[4], sr[5]
        if ht then
            if height < ht then height = ht end
            if depth  < dp then depth  = dp end
        end
        local result, current
        if trace_destinations then
            local step = 0
            if width  == 0 then
                step = 4*65536
                width, height, depth = 5*step, 5*step, 0
            end
            for n=1,#name do
                local rule = hpack_list(colorize(width,height,depth,3))
                rule.width = 0
                if not result then
                    result, current = rule, rule
                else
                    current.next = rule
                    rule.prev = current
                    current = rule
                end
                width, height = width - step, height - step
            end
        end
        nofdestinations = nofdestinations + 1
        for n=1,#name do
            local annot = nodeinjections.destination(width,height,depth,name[n],view)
            if not result then
                result, current = annot, annot
            else
                current.next = annot
                annot.prev = current
                current = annot
            end
        end
        result = hpack_list(result,0)
        result.width, result.height, result.depth = 0, 0, 0
        if cleanupdestinations then stack[reference] = nil end
        return result, resolved
    else
        logs.report("backends","unable to resolve destination attribute %s",reference)
    end
end

function nodes.add_destinations(head)
    if topofstack > 0 then
        return inject_area(head,attribute,makedestination,stack,done) -- singular
    else
        return head, false
    end
end

-- will move

function jobreferences.mark(reference,h,d,view)
    return setdestination(tex.currentgrouplevel,h,d,reference,view)
end

function jobreferences.inject(prefix,reference,h,d,highlight,newwindow,layer) -- todo: use currentreference is possible
    local set, bug = jobreferences.identify(prefix,reference)
    if bug or #set == 0 then
        -- unknown ref, just don't set it and issue an error
    else
        -- check
        set.highlight, set.newwindow,set.layer = highlight, newwindow, layer
        setreference(tex.currentgrouplevel,h,d,set) -- sets attribute / todo: for set[*].error
    end
end

function jobreferences.injectcurrentset(h,d) -- used inside doifelse
    local currentset = jobreferences.currentset
    if currentset then
        setreference(tex.currentgrouplevel,h,d,currentset) -- sets attribute / todo: for set[*].error
    end
end

--

local function checkboth(open,close)
    if open and open ~= "" then
        local set, bug = jobreferences.identify("",open)
        open = not bug and #set > 0 and set
    end
    if close and close ~= "" then
        local set, bug = jobreferences.identify("",close)
        close = not bug and #set > 0 and set
    end
    return open, close
end

-- expansion is temp hack

local opendocument, closedocument, openpage, closepage

local function check(what)
    if what and what ~= "" then
        local set, bug = jobreferences.identify("",what)
        return not bug and #set > 0 and set
    end
end

function jobreferences.checkopendocumentactions (open)  opendocument  = check(open)  end
function jobreferences.checkclosedocumentactions(close) closedocument = check(close) end
function jobreferences.checkopenpageactions     (open)  openpage      = check(open)  end
function jobreferences.checkclosepageactions    (close) closepage     = check(close) end

function jobreferences.flushdocumentactions()
    if opendocument or closedocument then
        backends.codeinjections.flushdocumentactions(opendocument,closedocument) -- backend
    end
end
function jobreferences.flushpageactions()
    if openpage or closepage then
        backends.codeinjections.flushpageactions(openpage,closepage) -- backend
    end
end

-- end temp hack

statistics.register("interactive elements", function()
    if nofreferences > 0 or nofdestinations > 0 then
        return string.format("%s references, %s destinations",nofreferences,nofdestinations)
    else
        return nil
    end
end)

if not modules then modules = { } end modules ['node-bck'] = {
    version   = 1.001,
    comment   = "companion to node-bck.mkiv",
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

-- is grouplevel still used?

local format = string.format

local allocate, mark = utilities.storage.allocate, utilities.storage.mark

local cleanupreferences, cleanupdestinations = false, true

local attributes, nodes, node = attributes, nodes, node

local nodeinjections  = backends.nodeinjections
local codeinjections  = backends.codeinjections

local transparencies  = attributes.transparencies
local colors          = attributes.colors
local references      = structures.references
local tasks           = nodes.tasks

local hpack_list      = node.hpack
local list_dimensions = node.dimensions

-- current.glue_set current.glue_sign

local trace_backend      = false  trackers.register("nodes.backend",      function(v) trace_backend      = v end)
local trace_references   = false  trackers.register("nodes.references",   function(v) trace_references   = v end)
local trace_destinations = false  trackers.register("nodes.destinations", function(v) trace_destinations = v end)

local report_reference   = logs.reporter("backend","references")
local report_destination = logs.reporter("backend","destinations")
local report_area        = logs.reporter("backend","areas")

local nodecodes        = nodes.nodecodes
local skipcodes        = nodes.skipcodes
local whatcodes        = nodes.whatcodes
local listcodes        = nodes.listcodes

local hlist_code       = nodecodes.hlist
local vlist_code       = nodecodes.vlist
local glue_code        = nodecodes.glue
local whatsit_code     = nodecodes.whatsit

local leftskip_code    = skipcodes.leftskip
local rightskip_code   = skipcodes.rightskip
local parfillskip_code = skipcodes.parfillskip

local localpar_code    = whatcodes.localpar
local dir_code         = whatcodes.dir

local line_code        = listcodes.line

local nodepool         = nodes.pool

local new_kern         = nodepool.kern

local has_attribute    = node.has_attribute
local traverse         = node.traverse
local find_node_tail   = node.tail or node.slide
local tosequence       = nodes.tosequence

local function dimensions(parent,start,stop)
    stop = stop and stop.next
    if parent then
        if stop then
            return list_dimensions(parent.glue_set,parent.glue_sign,parent.glue_order,start,stop)
        else
            return list_dimensions(parent.glue_set,parent.glue_sign,parent.glue_order,start)
        end
    else
        if stop then
            return list_dimensions(start,stop)
        else
            return list_dimensions(start)
        end
    end
end

--~ more compact

local function dimensions(parent,start,stop)
    if parent then
        return list_dimensions(parent.glue_set,parent.glue_sign,parent.glue_order,start,stop and stop.next)
    else
        return list_dimensions(start,stop and stop.next)
    end
end

-- is pardir important at all?

local function inject_range(head,first,last,reference,make,stack,parent,pardir,txtdir)
    local width, height, depth = dimensions(parent,first,last)
    if txtdir == "+TRT" or (txtdir == "===" and pardir == "TRT") then -- KH: textdir == "===" test added
        width = - width
    end
    local result, resolved = make(width,height,depth,reference)
    if result and resolved then
        if head == first then
            if trace_backend then
                report_area("head: %04i %s %s %s => w=%s, h=%s, d=%s, c=%s",reference,pardir or "---",txtdir or "----",tosequence(first,last,true),width,height,depth,resolved)
            end
            result.next = first
            first.prev = result
            return result, last
        else
            if trace_backend then
                report_area("middle: %04i %s %s => w=%s, h=%s, d=%s, c=%s",reference,pardir or "---",txtdir or "----",tosequence(first,last,true),width,height,depth,resolved)
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
    if id == hlist_code then -- box_code line_code
        -- can be either an explicit hbox or a line and there is no way
        -- to recognize this; anyway only if ht/dp (then inline)
        local sr = stack[reference]
        if first then
            if sr and sr[2] then
                local last = find_node_tail(first)
                if last.id == glue_code and last.subtype == rightskip_code then
                    local prev = last.prev
                    moveright = first.id == glue_code and first.subtype == leftskip_code
                    if prev and prev.id == glue_code and prev.subtype == parfillskip_code then
                        width = dimensions(current,first,prev.prev) -- maybe not current as we already take care of it
                    else
                        if moveright and first.writable then
                            width = width - first.spec.stretch*current.glue_set * current.glue_sign
                        end
                        if last.writable then
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
            report_area("box: %04i %s %s: w=%s, h=%s, d=%s, c=%s",reference,pardir or "---",txtdir or "----",width,height,depth,resolved)
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

-- skip is somewhat messy

local function inject_areas(head,attribute,make,stack,done,skip,parent,pardir,txtdir)  -- main
    if head then
        local current, first, last, firstdir, reference = head, nil, nil, nil, nil
        pardir = pardir or "==="
        txtdir = txtdir or "==="
        while current do
            local id = current.id
            local r = has_attribute(current,attribute)
            if id == whatsit_code then
                local subtype = current.subtype
                if subtype == localpar_code then
                    pardir = current.dir
                elseif subtype == dir_code then
                    txtdir = current.dir
                end
            elseif id == glue_code and current.subtype == leftskip_code then -- any glue at the left?
                --
            elseif id == hlist_code or id == vlist_code then
-- somehow reference is true so the following fails (second one not done) in
--    test \goto{test}[page(2)] test \gotobox{test}[page(2)]
-- so let's wait till this fails again
-- if not reference and r and (not skip or r > skip) then -- > or ~=
                if r and (not skip or r > skip) then -- > or ~=
                    inject_list(id,current,r,make,stack,pardir,txtdir)
                end
                if r then
                    done[r] = (done[r] or 0) + 1
                end
                local list = current.list
                if list then
                    local _
                    current.list, _, pardir, txtdir = inject_areas(list,attribute,make,stack,done,r or skip or 0,current,pardir,txtdir)
                end
                if r then
                    done[r] = done[r] - 1
                end
            elseif not r then
                -- just go on, can be kerns
            elseif not reference then
                reference, first, last, firstdir = r, current, current, txtdir
            elseif r == reference then
                last = current
            elseif (done[reference] or 0) == 0 then -- or id == glue_code and current.subtype == right_skip_code
                if not skip or r > skip then -- maybe no > test
                    head, current = inject_range(head,first,last,reference,make,stack,parent,pardir,firstdir)
                    reference, first, last, firstdir = nil, nil, nil, nil
                end
            else
                reference, first, last, firstdir = r, current, current, txtdir
            end
            current = current.next
        end
        if reference and (done[reference] or 0) == 0 then
            head = inject_range(head,first,last,reference,make,stack,parent,pardir,firstdir)
        end
    end
    return head, true, pardir, txtdir
end

local function inject_area(head,attribute,make,stack,done,parent,pardir,txtdir) -- singular  !
    if head then
        pardir = pardir or "==="
        txtdir = txtdir or "==="
        local current = head
        while current do
            local id = current.id
            local r = has_attribute(current,attribute)
            if id == whatsit_code then
                local subtype = current.subtype
                if subtype == localpar_code then
                    pardir = current.dir
                elseif subtype == dir_code then
                    txtdir = current.dir
                end
            elseif id == hlist_code or id == vlist_code then
                if r and not done[r] then
                    done[r] = true
                    inject_list(id,current,r,make,stack,pardir,txtdir)
                end
                current.list = inject_area(current.list,attribute,make,stack,done,current,pardir,txtdir)
            elseif r and not done[r] then
                done[r] = true
                head, current = inject_range(head,current,current,r,make,stack,parent,pardir,txtdir)
            end
            current = current.next
        end
    end
    return head, true
end

-- tracing


local nodepool       = nodes.pool

local new_rule       = nodepool.rule
local new_kern       = nodepool.kern

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
    if width == 0 then
        report_area("reference %s has no horizontal dimensions: width=%s, height=%s, depth=%s",reference,width,height,depth)
        width = 65536
    end
    if height + depth <= 0 then
        report_area("reference %s has no vertical dimensions: width=%s, height=%s, depth=%s",reference,width,height,depth)
        height = 65536/2
        depth  = height
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

local nodepool     = nodes.pool

local new_kern     = nodepool.kern

local texattribute = tex.attribute
local texcount     = tex.count

-- references:

local stack         = { }
local done          = { }
local attribute     = attributes.private('reference')
local nofreferences = 0
local topofstack    = 0

nodes.references = {
    attribute = attribute,
    stack     = stack,
    done      = done,
}

-- todo: get rid of n (n is just a number, can be used for tracing, obsolete)

local function setreference(h,d,r)
    topofstack = topofstack + 1
    -- the preroll permits us to determine samepage (but delayed also has some advantages)
    -- so some part of the backend work is already done here
    stack[topofstack] = { r, h, d, codeinjections.prerollreference(r) }
 -- texattribute[attribute] = topofstack -- todo -> at tex end
    texcount.lastreferenceattribute = topofstack
end

function references.get(n) -- not public so functionality can change
    local sn = stack[n]
    return sn and sn[1]
end

local function makereference(width,height,depth,reference)
    local sr = stack[reference]
    if sr then
        if trace_references then
            report_reference("resolving attribute %s",reference)
        end
        local resolved, ht, dp, set, n = sr[1], sr[2], sr[3], sr[4], sr[5]
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
                result = hpack_list(colorize(width,height-step,depth-step,2,reference)) -- step subtracted so that we can see seperate links
                result.width = 0
                current = result
            end
            if current then
                current.next = annot
            else
                result = annot
            end
            references.registerpage(n)
            result = hpack_list(result,0)
            result.width, result.height, result.depth = 0, 0, 0
            if cleanupreferences then stack[reference] = nil end
            return result, resolved
        elseif trace_references then
            report_reference("unable to resolve annotation %s",reference)
        end
    elseif trace_references then
        report_reference("unable to resolve attribute %s",reference)
    end
end

function nodes.references.handler(head)
    if topofstack > 0 then
        return inject_areas(head,attribute,makereference,stack,done)
    else
        return head, false
    end
end

-- destinations (we can clean up once set, unless tagging!)

local stack           = { }
local done            = { }
local attribute       = attributes.private('destination')
local nofdestinations = 0
local topofstack      = 0

nodes.destinations = {
    attribute = attribute,
    stack     = stack,
    done      = done,
}

local function setdestination(n,h,d,name,view) -- n = grouplevel, name == table
    topofstack = topofstack + 1
    stack[topofstack] = { n, h, d, name, view }
    return topofstack
end

local function makedestination(width,height,depth,reference)
    local sr = stack[reference]
    if sr then
        if trace_destinations then
            report_destination("resolving attribute %s",reference)
        end
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
                local rule = hpack_list(colorize(width,height,depth,3,reference))
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
        if result then
            -- some internal error
            result = hpack_list(result,0)
            result.width, result.height, result.depth = 0, 0, 0
        end
        if cleanupdestinations then stack[reference] = nil end
        return result, resolved
    elseif trace_destinations then
        report_destination("unable to resolve attribute %s",reference)
    end
end

function nodes.destinations.handler(head)
    if topofstack > 0 then
        return inject_area(head,attribute,makedestination,stack,done) -- singular
    else
        return head, false
    end
end

-- will move

function references.mark(reference,h,d,view)
    return setdestination(tex.currentgrouplevel,h,d,reference,view)
end

function references.inject(prefix,reference,h,d,highlight,newwindow,layer) -- todo: use currentreference is possible
    local set, bug = references.identify(prefix,reference)
    if bug or #set == 0 then
        -- unknown ref, just don't set it and issue an error
    else
        -- check
        set.highlight, set.newwindow,set.layer = highlight, newwindow, layer
        setreference(h,d,set) -- sets attribute / todo: for set[*].error
    end
end

function references.injectcurrentset(h,d) -- used inside doifelse
    local currentset = references.currentset
    if currentset then
        setreference(h,d,currentset) -- sets attribute / todo: for set[*].error
    end
end

--

local function checkboth(open,close)
    if open and open ~= "" then
        local set, bug = references.identify("",open)
        open = not bug and #set > 0 and set
    end
    if close and close ~= "" then
        local set, bug = references.identify("",close)
        close = not bug and #set > 0 and set
    end
    return open, close
end

-- end temp hack

statistics.register("interactive elements", function()
    if nofreferences > 0 or nofdestinations > 0 then
        return format("%s references, %s destinations",nofreferences,nofdestinations)
    else
        return nil
    end
end)

function references.enableinteraction()
    tasks.enableaction("shipouts","nodes.references.handler")
    tasks.enableaction("shipouts","nodes.destinations.handler")
end

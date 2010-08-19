if not modules then modules = { } end modules ['page-flt'] = {
    version   = 1.001,
    comment   = "companion to page-flt.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- floats -> managers.floats

local setdimen, setbox, setcount, texbox = tex.setdimen, tex.setbox, tex.setcount, tex.box
local insert, remove = table.insert, table.remove
local texwrite, texsprint, ctxcatcodes = tex.write, tex.sprint, tex.ctxcatcodes

local copy_node_list = node.copy_list

local trace_floats = false  trackers.register("graphics.floats", function(v) trace_floats = v end) -- name might change

local report_floats = logs.new("floats")

-- we use floatbox, floatwidth, floatheight
-- text page leftpage rightpage (todo: top, bottom, margin, order)

floats       = floats or { }
local floats = floats

local noffloats, last, default, pushed = 0, nil, "text", { }

local function initialize()
    return {
        text      = { },
        page      = { },
        leftpage  = { },
        rightpage = { },
    }
end

local stacks = initialize()

-- list location

function floats.stacked(which) -- floats.thenofstacked
    return #stacks[which or default]
end

function floats.thestacked(which)
    return texwrite(#stacks[which or default])
end

function floats.push()
    insert(pushed,stacks)
    stacks = initialize()
    setcount("global","savednoffloats",0)
end

function floats.pop()
    local popped = remove(pushed)
    if popped then
        for which, stack in next, stacks do
            for i=1,#stack do
                insert(popped[which],stack[i])
            end
        end
        stacks = popped
        setcount("global","savednoffloats",#stacks[default])
    end
end

local function setdimensions(b)
    local w, h, d = 0, 0, 0
    if b then
        w, h, d = b.width, b.height, b.depth
    end
    setdimen("global","floatwidth", w)
    setdimen("global","floatheight", h+d)
    return w, h, d
end

local function get(stack,n)
    n = n or #stack
    if n > 0 then
        local t = stack[n]
        if t then
            return t, t.box, n
        end
    end
end

function floats.save(which,data)
    which = which or default
    local b = texbox.floatbox
    if b then
        local stack = stacks[which]
        noffloats = noffloats + 1
        local w, h, d = b.width, b.height, b.depth
        local t = {
            n    = noffloats,
            data = data or { },
            box  = copy_node_list(b),
        }
        texbox.floatbox = nil
        insert(stack,t)
        setcount("global","savednoffloats",#stacks[default])
        if trace_floats then
            report_floats("saving %s float %s in slot %s (%i,%i,%i)",which,noffloats,#stack,w,h,d)
        else
            interfaces.showmessage("floatblocks",2,noffloats)
        end
    else
        report_floats("unable to save %s float %s (empty)",which,noffloats)
    end
end

function floats.resave(which)
    if last then
        which = which or default
        local stack = stacks[which]
        local b = texbox.floatbox
        local w, h, d = b.width, b.height, b.depth
        last.box = copy_node_list(b)
        texbox.floatbox = nil
        insert(stack,1,last)
        setcount("global","savednoffloats",#stacks[default])
        if trace_floats then
            report_floats("resaving %s float %s in slot %s (%i,%i,%i)",which,noffloats,#stack,w,h,d)
        else
            interfaces.showmessage("floatblocks",2,noffloats)
        end
    else
        report_floats("unable to resave float")
    end
end

function floats.flush(which,n)
    which = which or default
    local stack = stacks[which]
    local t, b, n = get(stack,n or 1)
    if t then
        local w, h, d = setdimensions(b)
        if trace_floats then
            report_floats("flushing %s float %s from slot %s (%i,%i,%i)",which,t.n,n,w,h,d)
        else
            interfaces.showmessage("floatblocks",3,t.n)
        end
        texbox.floatbox = b
        last = remove(stack,n)
        last.box = nil
        setcount("global","savednoffloats",#stacks[default]) -- default?
    else
        setdimensions()
    end
end

function floats.thevar(name,default)
    local value = last and last.data[name] or default
    if value and value ~= "" then
        texsprint(ctxcatcodes,value)
    end
end

function floats.consult(which,n)
    which = which or default
    local stack = stacks[which]
    local t, b, n = get(stack,n)
    if t then
        local w, h, d = setdimensions(b)
        if trace_floats then
            report_floats("consulting %s float %s in slot %s (%i,%i,%i)",which,t.n,n,w,h,d)
        end
        return t, b, n
    else
        if trace_floats then
            report_floats("nothing to consult")
        end
        setdimensions()
    end
end

function floats.collect(which,maxwidth,distance)
    which = which or default
    local stack = stacks[which]
    local n, m = #stack, 0
    for i=1,n do
        local t, b, n = get(stack,i)
        if t then
            local w, h, d = setdimensions(b)
            if w + distance < maxwidth then
                m = m + 1
                maxwidth = maxwidth - w - distance
            else
                break
            end
        else
            break
        end
    end
    if m == 0 then
        m = 1
    end
    setcount("global","nofcollectedfloats",m)
end

function commands.doifsavedfloatelse(which)
    local stack = stacks[which or default]
    commands.doifelse(#stack>0)
end

function floats.thecheckedpagefloat(packed)
    local result = ""
    if structures.pages.is_odd() then
        if #stacks.rightpage > 0 then
            result = "rightpage"
        elseif #stacks.page > 0 then
            result = "page"
        elseif #stacks.leftpage > 0 then
            if packed then
                result = "leftpage"
            else
                result = "empty"
            end
        end
    else
        if #stacks.leftpage > 0 then
            result = "leftpage"
        elseif #stacks.page > 0 then
            result = "page"
        elseif #stacks.rightpage > 0 then
            if packed then
                result = "rightpage"
            else
                result = "empty"
            end
        end
    end
    texsprint(ctxcatcodes,result)
end

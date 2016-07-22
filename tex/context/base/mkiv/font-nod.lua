if not modules then modules = { } end modules ['font-nod'] = {
    version   = 1.001,
    comment   = "companion to font-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

--[[ldx--
<p>This is rather experimental. We need more control and some of this
might become a runtime module instead. This module will be cleaned up!</p>
--ldx]]--

local tonumber, tostring, rawget = tonumber, tostring, rawget
local utfchar = utf.char
local concat, fastcopy = table.concat, table.fastcopy
local match, rep = string.match, string.rep

fonts = fonts or { }
nodes = nodes or { }

local fonts, nodes, node, context = fonts, nodes, node, context

local tracers          = nodes.tracers or { }
nodes.tracers          = tracers

local tasks            = nodes.tasks or { }
nodes.tasks            = tasks

local handlers         = nodes.handlers or { }
nodes.handlers         = handlers

local injections       = nodes.injections or { }
nodes.injections       = injections

local char_tracers     = tracers.characters or { }
tracers.characters     = char_tracers

local step_tracers     = tracers.steppers or { }
tracers.steppers       = step_tracers

local nodecodes        = nodes.nodecodes

local glyph_code       = nodecodes.glyph
local hlist_code       = nodecodes.hlist
local vlist_code       = nodecodes.vlist
local disc_code        = nodecodes.disc
local glue_code        = nodecodes.glue
local kern_code        = nodecodes.kern
local dir_code         = nodecodes.dir
local localpar_code    = nodecodes.localpar

local nuts             = nodes.nuts
local tonut            = nuts.tonut
local tonode           = nuts.tonode

local getfield         = nuts.getfield
local getnext          = nuts.getnext
local getprev          = nuts.getprev
local getid            = nuts.getid
local getfont          = nuts.getfont
local getsubtype       = nuts.getsubtype
local getchar          = nuts.getchar
local getlist          = nuts.getlist
local getdisc          = nuts.getdisc
local isglyph          = nuts.isglyph

local setfield         = nuts.setfield
local setbox           = nuts.setbox
local setchar          = nuts.setchar
local setsubtype       = nuts.setsubtype

local copy_node_list   = nuts.copy_list
local hpack_node_list  = nuts.hpack
local flush_node_list  = nuts.flush_list
local traverse_nodes   = nuts.traverse
local traverse_id      = nuts.traverse_id
local protect_glyphs   = nuts.protect_glyphs

local nodepool         = nuts.pool
local new_glyph        = nodepool.glyph

local formatters       = string.formatters
local formatter        = string.formatter

local hashes           = fonts.hashes

local fontidentifiers  = hashes.identifiers
local fontdescriptions = hashes.descriptions
local fontcharacters   = hashes.characters
local fontproperties   = hashes.properties
local fontparameters   = hashes.parameters

local properties = nodes.properties.data

-- direct.set_properties_mode(true,false)
-- direct.set_properties_mode(true,true)  -- default

local function freeze(h,where)
    for n in traverse_nodes(tonut(h)) do -- todo: disc but not traced anyway
        local p = properties[n]
        if p then
            local i = p.injections         if i then p.injections        = fastcopy(i) end
         -- local i = r.preinjections      if i then p.preinjections     = fastcopy(i) end
         -- local i = r.postinjections     if i then p.postinjections    = fastcopy(i) end
         -- local i = r.replaceinjections  if i then p.replaceinjections = fastcopy(i) end
            -- only injections
        end
    end
end

function char_tracers.collect(head,list,tag,n)
    head = tonut(head)
    n = n or 0
    local ok, fn = false, nil
    while head do
        local c, id = isglyph(head)
        if c then
            local f = getfont(head)
            if f ~= fn then
                ok, fn = false, f
            end
            if not ok then
                ok = true
                n = n + 1
                list[n] = list[n] or { }
                list[n][tag] = { }
            end
            local l = list[n][tag]
         -- l[#l+1] = { c, f, i }
            l[#l+1] = { c, f }
        elseif id == disc_code then
            -- skip
--             local pre, post, replace = getdisc(head)
--             if replace then
--                 for n in traverse_id(glyph_code,replace) do
--                     l[#l+1] = { c, f }
--                 end
--             end
--             if pre then
--                 for n in traverse_id(glyph_code,pre) do
--                     l[#l+1] = { c, f }
--                 end
--             end
--             if post then
--                 for n in traverse_id(glyph_code,post) do
--                     l[#l+1] = { c, f }
--                 end
--             end
        else
            ok = false
        end
        head = getnext(head)
    end
end

function char_tracers.equal(ta, tb)
    if #ta ~= #tb then
        return false
    else
        for i=1,#ta do
            local a, b = ta[i], tb[i]
         -- if a[1] ~= b[1] or a[2] ~= b[2] or a[3] ~= b[3] then
            if a[1] ~= b[1] or a[2] ~= b[2] then
                return false
            end
        end
    end
    return true
end

function char_tracers.string(t)
    local tt = { }
    for i=1,#t do
        tt[i] = utfchar(t[i][1])
    end
    return concat(tt,"")
end

local f_unicode = formatters["%U"]
local f_badcode = formatters["{%i}"]

function char_tracers.unicodes(t,decimal)
    local tt = { }
    for i=1,#t do
        local n = t[i][1]
        if n == 0 then
            tt[i] = "-"
        elseif decimal then
            tt[i] = n
        else
            tt[i] = f_unicode(n)
        end
    end
    return concat(tt," ")
end

-- function char_tracers.indices(t,decimal)
--     local tt = { }
--     for i=1,#t do
--         local n = t[i][3]
--         if n == 0 then
--             tt[i] = "-"
--         elseif decimal then
--             tt[i] = n
--         else
--             tt[i] = f_unicode(n)
--         end
--     end
--     return concat(tt," ")
-- end

function char_tracers.start()
    local npc = handlers.characters -- should accept nuts too
    local list = { }
    function handlers.characters(head)
        local n = #list
        char_tracers.collect(head,list,'before',n)
        local h, d = npc(tonode(head)) -- for the moment tonode
        char_tracers.collect(head,list,'after',n)
        if #list > n then
            list[#list+1] = { }
        end
        return h, d
    end
    function char_tracers.stop()
        tracers.list['characters'] = list
        local variables = {
            ['title']                = 'ConTeXt Character Processing Information',
            ['color-background-one'] = lmx.get('color-background-yellow'),
            ['color-background-two'] = lmx.get('color-background-purple'),
        }
        lmx.show('context-characters.lmx',variables)
        handlers.characters = npc
        tasks.restart("processors", "characters")
    end
    tasks.restart("processors", "characters")
end

local stack = { }

function tracers.start(tag)
    stack[#stack+1] = tag
    local tracer = tracers[tag]
    if tracer and tracer.start then
        tracer.start()
    end
end
function tracers.stop()
    local tracer = stack[#stack]
    if tracer and tracer.stop then
        tracer.stop()
    end
    stack[#stack] = nil
end

-- experimental

local collection, collecting, messages = { }, false, { }

function step_tracers.start()
    collecting = true
end

function step_tracers.stop()
    collecting = false
end

function step_tracers.reset()
    for i=1,#collection do
        local c = collection[i]
        if c then
            flush_node_list(c)
        end
    end
    collection, messages = { }, { }
end

function step_tracers.nofsteps()
    return context(#collection)
end

function step_tracers.glyphs(n,i)
    local c = collection[i]
    if c then
        local c = copy_node_list(c)
        local b = hpack_node_list(c) -- multiple arguments
        setbox(n,b)
    end
end

function step_tracers.features()
    -- we cannot use first_glyph here as it only finds characters with subtype < 256
    local f = collection[1]
    while f do
        if getid(f) == glyph_code then
            local tfmdata, t = fontidentifiers[getfont(f)], { }
            for feature, value in table.sortedhash(tfmdata.shared.features) do
                if feature == "number" or feature == "features" then
                    -- private
                elseif type(value) == "boolean" then
                    if value then
                        t[#t+1] = formatters["%s=yes"](feature)
                    else
                        -- skip
                    end
                else
                    t[#t+1] = formatters["%s=%s"](feature,value)
                end
            end
            if #t > 0 then
                context(concat(t,", "))
            else
                context("no features")
            end
            return
        end
        f = getnext(f)
    end
end

function tracers.fontchar(font,char)
    local n = new_glyph(font,char)
    setsubtype(n,256)
    context(tonode(n))
end

function step_tracers.font(command)
    local c = collection[1]
    while c do
        local id = getid(c)
        if id == glyph_code then
            local font = getfont(c)
            local name = file.basename(fontproperties[font].filename or "unknown")
            local size = fontparameters[font].size or 0
            if command then
                context[command](font,name,size) -- size in sp
            else
                context("[%s: %s @ %p]",font,name,size)
            end
            return
        else
            c = getnext(c)
        end
    end
end

local colors = {
    pre     = { "darkred" },
    post    = { "darkgreen" },
    replace = { "darkblue" },
}

function step_tracers.codes(i,command,space)
    local c = collection[i]

    local function showchar(c)
        local f = getfont(c)
        local c = getchar(c)
        if command then
            local d = fontdescriptions[f]
            local d = d and d[c]
            context[command](f,c,d and d.class or "")
        else
            context("[%s:U+%05X]",f,c)
        end
    end

    local function showdisc(d,w,what)
        if w then
            context.startcolor(colors[what])
            context("%s:",what)
            for c in traverse_nodes(w) do
                local id = getid(c)
                if id == glyph_code then
                    showchar(c)
                else
                    context("[%s]",nodecodes[id])
                end
            end
            context[space]()
            context.stopcolor()
        end
    end

    while c do
        local id = getid(c)
        if id == glyph_code then
            showchar(c)
        elseif id == dir_code or id == localpar_code then
            context("[%s]",getfield(c,"dir"))
        elseif id == disc_code then
            local pre, post, replace = getdisc(c)
            if pre or post or replace then
                context("[")
                context[space]()
                showdisc(c,pre,"pre")
                showdisc(c,post,"post")
                showdisc(c,replace,"replace")
                context[space]()
                context("]")
            else
                context("[disc]")
            end
        else
            context("[%s]",nodecodes[id])
        end
        c = getnext(c)
    end
end

function step_tracers.messages(i,command,split)
    local list = messages[i] -- or { "no messages" }
    if list then
        for i=1,#list do
            local l = list[i]
            if not command then
                context("(%s)",l)
            elseif split then
                local a, b = match(l,"^(.-)%s*:%s*(.*)$")
                context[command](a or l or "",b or "")
            else
                context[command](l)
            end
        end
    end
end

-- hooks into the node list processor (see otf)

function step_tracers.check(head)
    if collecting then
        step_tracers.reset()
        local h = tonut(head)
        local n = copy_node_list(h)
        freeze(n,"check")
        injections.keepcounts(n) -- one-time
        injections.handler(n,"trace")
        protect_glyphs(n)
        collection[1] = n
    end
end

function step_tracers.register(head)
    if collecting then
        local nc = #collection+1
        if messages[nc] then
            local h = tonut(head)
            local n = copy_node_list(h)
            freeze(n,"register")
            injections.keepcounts(n) -- one-time
            injections.handler(n,"trace")
            protect_glyphs(n)
            collection[nc] = n
        end
    end
end

function step_tracers.message(str,...)
    str = formatter(str,...)
    if collecting then
        local n = #collection + 1
        local m = messages[n]
        if not m then m = { } messages[n] = m end
        m[#m+1] = str
    end
    return str -- saves an intermediate var in the caller
end

--

local threshold = 65536

local function toutf(list,result,nofresult,stopcriterium)
    if list then
        for n in traverse_nodes(tonut(list)) do
            local c, id = isglyph(n)
            if c then
                local components = getfield(n,"components")
                if components then
                    result, nofresult = toutf(components,result,nofresult)
                elseif c > 0 then
                    local fc = fontcharacters[getfont(n)]
                    if fc then
                        local fcc = fc[c]
                        if fcc then
                            local u = fcc.unicode
                            if not u then
                                nofresult = nofresult + 1
                                result[nofresult] = utfchar(c)
                            elseif type(u) == "table" then
                                for i=1,#u do
                                    nofresult = nofresult + 1
                                    result[nofresult] = utfchar(u[i])
                                end
                            else
                                nofresult = nofresult + 1
                                result[nofresult] = utfchar(u)
                            end
                        else
                            nofresult = nofresult + 1
                            result[nofresult] = utfchar(c)
                        end
                    else
                        nofresult = nofresult + 1
                        result[nofresult] = f_unicode(c)
                    end
                else
                    nofresult = nofresult + 1
                    result[nofresult] = f_badcode(c)
                end
            elseif id == disc_code then
                result, nofresult = toutf(getfield(n,"replace"),result,nofresult) -- needed?
            elseif id == hlist_code or id == vlist_code then
             -- if nofresult > 0 and result[nofresult] ~= " " then
             --     nofresult = nofresult + 1
             --     result[nofresult] = " "
             -- end
                result, nofresult = toutf(getlist(n),result,nofresult)
            elseif id == glue_code then
                if nofresult > 0 and result[nofresult] ~= " " then
                    nofresult = nofresult + 1
                    result[nofresult] = " "
                end
            elseif id == kern_code and getfield(n,"kern") > threshold then
                if nofresult > 0 and result[nofresult] ~= " " then
                    nofresult = nofresult + 1
                    result[nofresult] = " "
                end
            end
            if n == stopcriterium then
                break
            end
        end
    end
    if nofresult > 0 and result[nofresult] == " " then
        result[nofresult] = nil
        nofresult = nofresult - 1
    end
    return result, nofresult
end

function nodes.toutf(list,stopcriterium)
    local result, nofresult = toutf(list,{},0,stopcriterium)
    return concat(result)
end

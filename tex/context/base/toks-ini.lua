if not modules then modules = { } end modules ['toks-ini'] = {
    version   = 1.001,
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local utf = unicode.utf8
local format, gsub, texsprint = string.format, string.gsub, tex.sprint

local ctxcatcodes = tex.ctxcatcodes

--[[ldx--
<p>This code is experimental and needs a cleanup. The visualizers will move to
a module.</p>
--ldx]]--

-- 1 = command, 2 = modifier (char), 3 = controlsequence id
--
-- callback.register('token_filter', token.get_next)
--
-- token.get_next()
-- token.expand()
-- token.create()
-- token.csname_id()
-- token.csname_name(v)
-- token.command_id()
-- token.command_name(v)
-- token.is_expandable()
-- token.is_activechar()
-- token.lookup(v)

-- actually, we can use token registers to store tokens

tokens = tokens or { }

tokens.vbox   = token.create("vbox")
tokens.hbox   = token.create("hbox")
tokens.vtop   = token.create("vtop")
tokens.bgroup = token.create(utf.byte("{"), 1)
tokens.egroup = token.create(utf.byte("}"), 2)

tokens.letter = function(chr) return token.create(utf.byte(chr), 11) end
tokens.other  = function(chr) return token.create(utf.byte(chr), 12) end

tokens.letters = function(str)
    local t = { }
    for chr in string.utfvalues(str) do
        t[#t+1] = token.create(chr, 11)
    end
    return t
end

collectors       = collectors      or { }
collectors.data  = collectors.data or { }

function tex.printlist(data)
    callbacks.push('token_filter', function ()
       callbacks.pop('token_filter') -- tricky but the nil assignment helps
       return data
    end)
end

function collectors.flush(tag)
    tex.printlist(collectors.data[tag])
end

function collectors.test(tag)
    tex.printlist(collectors.data[tag])
end

collectors.registered = { }

function collectors.register(name)
    collectors.registered[token.csname_id(name)] = name
end

--~ function collectors.install(tag,end_cs)
--~     collectors.data[tag] = { }
--~     local data   = collectors.data[tag]
--~     local call   = token.command_id("call")
--~     local relax  = token.command_id("relax")
--~     local endcs  = token.csname_id(end_cs)
--~     local expand = collectors.registered
--~     local get    = token.get_next -- so no callback!
--~     while true do
--~         local t = get()
--~         local a, b = t[1], t[3]
--~         if a == relax and b == endcs then
--~             return
--~         elseif a == call and expand[b] then
--~             token.expand()
--~         else
--~             data[#data+1] = t
--~         end
--~     end
--~ end

function collectors.install(tag,end_cs)
    collectors.data[tag] = { }
    local data   = collectors.data[tag]
    local call   = token.command_id("call")
    local endcs  = token.csname_id(end_cs)
    local expand = collectors.registered
    local get    = token.get_next
    while true do
        local t = get()
        local a, b = t[1], t[3]
        if b == endcs then
            tex.print('\\' ..end_cs)
            return
        elseif a == call and expand[b] then
            token.expand()
        else
            data[#data+1] = t
        end
    end
end

function collectors.handle(tag,handle,flush)
    collectors.data[tag] = handle(collectors.data[tag])
    if flush then
        collectors.flush(tag)
    end
end

collectors.show_methods = { }

function collectors.show(tag, method)
    if type(tag) == "table" then
        collectors.show_methods[method or 'a'](tag)
    else
        collectors.show_methods[method or 'a'](collectors.data[tag])
    end
end

commands = commands or { }

commands.letter = token.command_id("letter")
commands.other  = token.command_id("other_char")

function collectors.default_words(t,str)
    t[#t+1] = tokens.bgroup
    t[#t+1] = token.create("red")
    for i=1,#str do
        t[#t+1] = tokens.other('*')
    end
    t[#t+1] = tokens.egroup
end

function collectors.with_words(tag,handle)
    local t, w = { }, { }
    handle = handle or collectors.default_words
    local tagdata = collectors.data[tag]
    for k=1,#tagdata do
        local v = tagdata[k]
        if v[1] == commands.letter then
            w[#w+1] = v[2]
        else
            if #w > 0 then
                handle(t,w)
                w = { }
            end
            t[#t+1] = v
        end
    end
    if #w > 0 then
        handle(t,w)
    end
    collectors.data[tag] = t
end

function collectors.show_token(t)
    if t then
        local cmd, chr, id, cs, name = t[1], t[2], t[3], nil, token.command_name(t) or ""
        if cmd == commands.letter or cmd == commands.other then
            return format("%s-> %s -> %s", name, chr, utf.char(chr))
        elseif id > 0 then
            cs = token.csname_name(t) or nil
            if cs then
                return format("%s-> %s", name, cs)
            elseif tonumber(chr) < 0 then
                return format("%s-> %s", name, id)
            else
                return format("%s-> (%s,%s)", name, chr, id)
            end
        else
            return format("%s", name)
        end
    else
        return "no node"
    end
end

function collectors.trace()
    local t = token.get_next()
    texio.write_nl(collectors.show_token(t))
    return t
end

collectors.show_methods.a = function(data) -- no need to store the table, just pass directly
    local template = "\\NC %s\\NC %s\\NC %s\\NC %s\\NC %s\\NC\\NR "
    texsprint(ctxcatcodes, "\\starttabulate[|T|Tr|cT|Tr|T|]")
    texsprint(ctxcatcodes, format(template,"cmd","chr","","id","name"))
    texsprint(ctxcatcodes, "\\HL")
    for _,v in next, data do
        local cmd, chr, id, cs, sym = v[1], v[2], v[3], "", ""
        local name = gsub(token.command_name(v) or "","_","\\_")
        if id > 0 then
            cs = token.csname_name(v) or ""
            if cs ~= "" then cs = "\\string " .. cs end
        else
            id = ""
        end
        if cmd == commands.letter or cmd == commands.other then
            sym = "\\char " .. chr
        end
        if tonumber(chr) < 0 then
            texsprint(ctxcatcodes, format(template, name,  "", sym, id, cs))
        else
            texsprint(ctxcatcodes, format(template, name, chr, sym, id, cs))
        end
    end
    texsprint(ctxcatcodes, "\\stoptabulate")
end

collectors.show_methods.b_c = function(data,swap) -- no need to store the table, just pass directly
    local template = "\\NC %s\\NC %s\\NC %s\\NC\\NR"
    if swap then
        texsprint(ctxcatcodes, "\\starttabulate[|Tl|Tl|Tr|]")
    else
        texsprint(ctxcatcodes, "\\starttabulate[|Tl|Tr|Tl|]")
    end
    texsprint(ctxcatcodes, format(template,"cmd","chr","name"))
    texsprint(ctxcatcodes, "\\HL")
    for _,v in next, data do
        local cmd, chr, id, cs, sym = v[1], v[2], v[3], "", ""
        local name = gsub(token.command_name(v) or "","_","\\_")
        if id > 0 then
            cs = token.csname_name(v) or ""
        end
        if cmd == commands.letter or cmd == commands.other then
            sym = "\\char " .. chr
        elseif cs ~= "" then
            if token.is_activechar(v) then
                sym = "\\string " .. cs
            else
                sym = "\\string\\" .. cs
            end
        end
        if swap then
            texsprint(ctxcatcodes, format(template, name, sym, chr))
        elseif tonumber(chr) < 0 then
            texsprint(ctxcatcodes, format(template, name,  "", sym))
        else
            texsprint(ctxcatcodes, format(template, name, chr, sym))
        end
    end
    texsprint(ctxcatcodes, "\\stoptabulate")
end

-- Even more experimental ...

collectors.show_methods.b = function(tag) collectors.show_methods.b_c(tag,false) end
collectors.show_methods.c = function(tag) collectors.show_methods.b_c(tag,true ) end

collectors.remapper = {
    -- namespace
}

collectors.remapper.data = {
    -- user mappings
}

function collectors.remapper.store(tag,class,key)
    local s = collectors.remapper.data[class]
    if not s then
        s = { }
        collectors.remapper.data[class] = s
    end
    s[key] = collectors.data[tag]
    collectors.data[tag] = nil
end

function collectors.remapper.convert(tag,toks)
    local data = collectors.remapper.data[tag]
    local leftbracket, rightbracket = utf.byte('['), utf.byte(']')
    local skipping = 0
    -- todo: math
    if data then
        local t = { }
        for s=1,#toks do
            local tok = toks[s]
            local one, two = tok[1], tok[2]
            if one == 11 or one == 12 then
                if two == leftbracket then
                    skipping = skipping + 1
                    t[#t+1] = tok
                elseif two == rightbracket then
                    skipping = skipping - 1
                    t[#t+1] = tok
                elseif skipping == 0 then
                    local new = data[two]
                    if new then
                        if #new > 1 then
                            for n=1,#new do
                                t[#t+1] = new[n]
                            end
                        else
                            t[#t+1] = new[1]
                        end
                    else
                        t[#t+1] = tok
                    end
                else
                    t[#t+1] = tok
                end
            else
                t[#t+1] = tok
            end
        end
        return t
    else
        return toks
    end
end

if not modules then modules = { } end modules ['toks-ini'] = {
    version   = 1.001,
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

utf   = utf or unicode.utf8

--[[ldx--
<p>This code is experimental.</p>
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

collector       = collector      or { }
collector.data  = collector.data or { }

function tex.printlist(data)
    callbacks.push('token_filter', function ()
       callbacks.pop('token_filter')
       return data
    end)
end

function collector.flush(tag)
    tex.printlist(collector.data[tag])
end

function collector.test(tag)
    tex.printlist(collector.data[tag])
end

collector.registered = { }

function collector.register(name)
    collector.registered[token.csname_id(name)] = name
end

function collector.install(tag,end_cs)
    collector.data[tag] = { }
    local data   = collector.data[tag]
    local call   = token.command_id("call")
    local relax  = token.command_id("relax")
    local endcs  = token.csname_id(end_cs)
    local expand = collector.registered
    local get    = token.get_next -- so no callback!
    while true do
        local t = get()
        local a, b = t[1], t[3]
        if a == relax and b == endcs then
            return
        elseif a == call and expand[b] then
            token.expand()
        else
            data[#data+1] = t
        end
    end
end

collector.show_methods = { }

function collector.show(tag, method)
    if type(tag) == "table" then
        collector.show_methods[method or 'a'](tag)
    else
        collector.show_methods[method or 'a'](collector.data[tag])
    end
end

commands = commands or { }

commands.letter = token.command_id("letter")
commands.other  = token.command_id("other_char")

function collector.default_words(t,str)
    t[#t+1] = tokens.bgroup
    t[#t+1] = token.create("red")
    for k,v in ipairs(str) do
        t[#t+1] = tokens.other('*')
    end
    t[#t+1] = tokens.egroup
end

function collector.with_words(tag,handle)
    local t, w = { }, { }
    handle = handle or collector.default_words
    for _,v in ipairs(collector.data[tag]) do
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
    collector.data[tag] = t
end

function collector.show_token(t)
    if t then
        local cmd, chr, id, cs, name = t[1], t[2], t[3], nil, token.command_name(t) or ""
        if cmd == commands.letter or cmd == commands.other then
            return string.format("%s-> %s -> %s", name, chr, utf.char(chr))
        elseif id > 0 then
            cs = token.csname_name(t) or nil
            if cs then
                return string.format("%s-> %s", name, cs)
            elseif tonumber(chr) < 0 then
                return string.format("%s-> %s", name, id)
            else
                return string.format("%s-> (%s,%s)", name, chr, id)
            end
        else
            return string.format("%s", name)
        end
    else
        return "no node"
    end
end

function collector.trace()
    local t = token.get_next()
    texio.write_nl(collector.show_token(t))
    return t
end

collector.show_methods.a = function(data) -- no need to store the table, just pass directly
    local flush, ct = tex.sprint, tex.ctxcatcodes
    local template = "\\NC %s\\NC %s\\NC %s\\NC %s\\NC %s\\NC\\NR "
    flush(ct, "\\starttabulate[|T|Tr|cT|Tr|T|]")
    flush(ct, template:format("cmd","chr","","id","name"))
    flush(ct, "\\HL")
    for _,v in pairs(data) do
        local cmd, chr, id, cs, sym = v[1], v[2], v[3], "", ""
        local name = (token.command_name(v) or ""):gsub("_","\\_")
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
            flush(ct, template:format(name,  "", sym, id, cs))
        else
            flush(ct, template:format(name, chr, sym, id, cs))
        end
    end
    flush(ct, "\\stoptabulate")
end

collector.show_methods.b_c = function(data,swap) -- no need to store the table, just pass directly
    local flush, ct = tex.sprint, tex.ctxcatcodes
    local template = "\\NC %s\\NC %s\\NC %s\\NC\\NR"
    if swap then
        flush(ct, "\\starttabulate[|Tl|Tl|Tr|]")
    else
        flush(ct, "\\starttabulate[|Tl|Tr|Tl|]")
    end
    flush(ct, template:format("cmd","chr","name"))
    flush(ct, "\\HL")
    for _,v in pairs(data) do
        local cmd, chr, id, cs, sym = v[1], v[2], v[3], "", ""
        local name = (token.command_name(v) or ""):gsub("_","\\_")
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
            flush(ct, template:format(name, sym, chr))
        elseif tonumber(chr) < 0 then
            flush(ct, template:format(name,  "", sym))
        else
            flush(ct, template:format(name, chr, sym))
        end
    end
    flush(ct, "\\stoptabulate")
end

collector.show_methods.b = function(tag) collector.show_methods.b_c(tag,false) end
collector.show_methods.c = function(tag) collector.show_methods.b_c(tag,true ) end

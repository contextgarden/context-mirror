if not modules then modules = { } end modules ['toks-ini'] = {
    version   = 1.001,
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local utfbyte, utfchar, utfvalues = utf.byte, utf.char, utf.values
local format, gsub = string.format, string.gsub

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

local token, tex = token, tex

local createtoken   = token.create
local csname_id     = token.csname_id
local command_id    = token.command_id
local command_name  = token.command_name
local get_next      = token.get_next
local expand        = token.expand
local is_activechar = token.is_activechar
local csname_name   = token.csname_name

tokens        = tokens or { }
local tokens  = tokens

tokens.vbox   = createtoken("vbox")
tokens.hbox   = createtoken("hbox")
tokens.vtop   = createtoken("vtop")
tokens.bgroup = createtoken(utfbyte("{"), 1)
tokens.egroup = createtoken(utfbyte("}"), 2)

tokens.letter = function(chr) return createtoken(utfbyte(chr), 11) end
tokens.other  = function(chr) return createtoken(utfbyte(chr), 12) end

tokens.letters = function(str)
    local t, n = { }, 0
    for chr in utfvalues(str) do
        n = n + 1
        t[n] = createtoken(chr, 11)
    end
    return t
end

tokens.collectors     = tokens.collectors or { }
local collectors      = tokens.collectors

collectors.data       = collectors.data or { }
local collectordata   = collectors.data

collectors.registered = collectors.registered or { }
local registered      = collectors.registered

local function printlist(data)
    callbacks.push('token_filter', function ()
       callbacks.pop('token_filter') -- tricky but the nil assignment helps
       return data
    end)
end

tex.printlist = printlist -- will change to another namespace

function collectors.flush(tag)
    printlist(collectordata[tag])
end

function collectors.test(tag)
    printlist(collectordata[tag])
end

function collectors.register(name)
    registered[csname_id(name)] = name
end

local call   = command_id("call")
local letter = command_id("letter")
local other  = command_id("other_char")

function collectors.install(tag,end_cs)
    local data, d = { }, 0
    collectordata[tag] = data
    local endcs = csname_id(end_cs)
    while true do
        local t = get_next()
        local a, b = t[1], t[3]
        if b == endcs then
            context["end_cs"]()
            return
        elseif a == call and registered[b] then
            expand()
        else
            d = d + 1
            data[d] = t
        end
    end
end

function collectors.handle(tag,handle,flush)
    collectordata[tag] = handle(collectordata[tag])
    if flush then
        collectors.flush(tag)
    end
end

local show_methods      = { }
collectors.show_methods = show_methods

function collectors.show(tag, method)
    if type(tag) == "table" then
        show_methods[method or 'a'](tag)
    else
        show_methods[method or 'a'](collectordata[tag])
    end
end

function collectors.defaultwords(t,str)
    local n = #t
    n = n + 1
    t[n] = tokens.bgroup
    n = n + 1
    t[n] = createtoken("red")
    for i=1,#str do
        n = n + 1
        t[n] = tokens.other('*')
    end
    n = n + 1
    t[n] = tokens.egroup
end

function collectors.dowithwords(tag,handle)
    local t, w, tn, wn = { }, { }, 0, 0
    handle = handle or collectors.defaultwords
    local tagdata = collectordata[tag]
    for k=1,#tagdata do
        local v = tagdata[k]
        if v[1] == letter then
            wn = wn + 1
            w[wn] = v[2]
        else
            if wn > 0 then
                handle(t,w)
                wn = 0
            end
            tn = tn + 1
            t[tn] = v
        end
    end
    if wn > 0 then
        handle(t,w)
    end
    collectordata[tag] = t
end

local function showtoken(t)
    if t then
        local cmd, chr, id, cs, name = t[1], t[2], t[3], nil, command_name(t) or ""
        if cmd == letter or cmd == other then
            return format("%s-> %s -> %s", name, chr, utfchar(chr))
        elseif id > 0 then
            cs = csname_name(t) or nil
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

collectors.showtoken = showtoken

function collectors.trace()
    local t = get_next()
    logs.report("tokenlist",showtoken(t))
    return t
end

-- these might move to a runtime module

show_methods.a = function(data) -- no need to store the table, just pass directly
    local function row(one,two,three,four,five)
        context.NC() context(one)
        context.NC() context(two)
        context.NC() context(three)
        context.NC() context(four)
        context.NC() context(five)
        context.NC() context.NR()
    end
    context.starttabulate { "|T|Tr|cT|Tr|T|" }
    row("cmd","chr","","id","name")
    context.HL()
    for _,v in next, data do
        local cmd, chr, id, cs, sym = v[1], v[2], v[3], "", ""
        local name = gsub(command_name(v) or "","_","\\_")
        if id > 0 then
            cs = csname_name(v) or ""
            if cs ~= "" then cs = "\\string " .. cs end
        else
            id = ""
        end
        if cmd == letter or cmd == other then
            sym = "\\char " .. chr
        end
        if tonumber(chr) < 0 then
            row(name,"",sym,id,cs)
        else
            row(name,chr,sym,id,cs)
        end
    end
    context.stoptabulate()
end

local function show_b_c(data,swap) -- no need to store the table, just pass directly
    local function row(one,two,three)
        context.NC() context(one)
        context.NC() context(two)
        context.NC() context(three)
        context.NC() context.NR()
    end
    if swap then
        context.starttabulate { "|Tl|Tl|Tr|" }
    else
        context.starttabulate { "|Tl|Tr|Tl|" }
    end
    row("cmd","chr","name")
    context.HL()
    for _,v in next, data do
        local cmd, chr, id, cs, sym = v[1], v[2], v[3], "", ""
        local name = gsub(command_name(v) or "","_","\\_")
        if id > 0 then
            cs = csname_name(v) or ""
        end
        if cmd == letter or cmd == other then
            sym = "\\char " .. chr
        elseif cs == "" then
            -- okay
        elseif is_activechar(v) then
            sym = "\\string " .. cs
        else
            sym = "\\string\\" .. cs
        end
        if swap then
            row(name,sym,chr)
        elseif tonumber(chr) < 0 then
            row(name,"",sym)
        else
            row(name,chr,sym)
        end
    end
    context.stoptabulate()
end

-- Even more experimental ...

show_methods.b = function(data) show_b_c(data,false) end
show_methods.c = function(data) show_b_c(data,true ) end

local remapper      = { }  -- namespace
collectors.remapper = remapper

local remapperdata  = { }  -- user mappings
remapper.data       = remapperdata

function remapper.store(tag,class,key)
    local s = remapperdata[class]
    if not s then
        s = { }
        remapperdata[class] = s
    end
    s[key] = collectordata[tag]
    collectordata[tag] = nil
end

function remapper.convert(tag,toks)
    local data = remapperdata[tag]
    local leftbracket, rightbracket = utfbyte('['), utfbyte(']')
    local skipping = 0
    -- todo: math
    if data then
        local t, n = { }, 0
        for s=1,#toks do
            local tok = toks[s]
            local one, two = tok[1], tok[2]
            if one == 11 or one == 12 then
                if two == leftbracket then
                    skipping = skipping + 1
                    n = n + 1 ; t[n] = tok
                elseif two == rightbracket then
                    skipping = skipping - 1
                    n = n + 1 ; t[n] = tok
                elseif skipping == 0 then
                    local new = data[two]
                    if new then
                        if #new > 1 then
                            for n=1,#new do
                                n = n + 1 ; t[n] = new[n]
                            end
                        else
                            n = n + 1 ; t[n] = new[1]
                        end
                    else
                        n = n + 1 ; t[n] = tok
                    end
                else
                    n = n + 1 ; t[n] = tok
                end
            else
                n = n + 1 ; t[n] = tok
            end
        end
        return t
    else
        return toks
    end
end

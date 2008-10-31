-- filename : core-buf.lua
-- comment  : companion to core-buf.tex
-- author   : Hans Hagen, PRAGMA-ADE, Hasselt NL
-- copyright: PRAGMA ADE / ConTeXt Development Team
-- license  : see context related readme files

-- ctx lua reference model / hooks and such
-- to be optimized

-- redefine buffers.get

if not versions then versions = { } end versions['core-buf'] = 1.001

if unicode and not utf then utf = unicode.utf8 end

buffers             = { }
buffers.data        = { }
buffers.hooks       = { }
buffers.flags       = { }
buffers.commands    = { }
buffers.visualizers = { }

-- if needed we can make 'm local

local concat, texsprint, texprint, texwrite = table.concat, tex.sprint, tex.print, tex.write
local utfbyte, utffind, utfgsub = utf.byte, utf.find, utf.gsub
local byte, sub, find, char, gsub, rep = string.byte, string.sub, string.find, string.char, string.gsub, string.rep

local data, commands, flags, hooks, visualizers = buffers.data, buffers.commands, buffers.flags, buffers.hooks, buffers.visualizers

function buffers.erase(name)
    data[name] = nil
end

function buffers.set(name, str)
    data[name] = { str } -- CHECK THIS
end

function buffers.append(name, str)
    data[name] = (data[name] or "") .. str
end

buffers.flags.store_as_table = true

-- to be sorted out: crlf + \ ; slow now

local n = 0

function buffers.grab(name,begintag,endtag,bufferdata)
    local dn = data[name] or ""
    if dn == "" then
        buffers.level = 0
    end
    buffers.level = buffers.level + bufferdata:count("\\"..begintag) - bufferdata:count("\\"..endtag)
    local more = buffers.level>0
    if more then
        dn = dn .. bufferdata .. endtag
        buffers.level = buffers.level - 1
    else
        if dn == "" then
            dn = bufferdata:sub(1,#bufferdata-1)
        else
            dn = dn .. "\n" .. bufferdata:sub(1,#bufferdata-1)
        end
        dn = dn:gsub("[\010\013]$","")
        if flags.store_as_table then
            dn = dn:splitlines()
        end
    end
    data[name] = dn
    cs.testcase(more)
end

function buffers.exists(name)
    return data[name] ~= nil
end

function buffers.doifelsebuffer(name)
    cs.testcase(data[name] ~= nil)
end

flags.optimize_verbatim        = true
flags.count_empty_lines        = false

commands.no_break              = "\\doverbatimnobreak"
commands.do_break              = "\\doverbatimgoodbreak"
commands.begin_of_line_command = "\\doverbatimbeginofline"
commands.end_of_line_command   = "\\doverbatimendofline"
commands.empty_line_command    = "\\doverbatimemptyline"

function buffers.verbatimbreak(n,m)
    if flags.optimize_verbatim then
        if n == 2 or n == m then
            texsprint(commands.no_break)
        else
            texsprint(commands.do_break)
        end
    end
end

function buffers.strip(lines)
    local first, last = 1, #lines
    for i=first,last do
        if #lines[i] == 0 then
            first = first + 1
        else
            break
        end
    end
    for i=last,first,-1 do
        if #lines[i] == 0 then
            last = last - 1
        else
            break
        end
    end
    return first, last, last - first + 1
end

function buffers.type(name)
    local lines = data[name]
    local action = buffers.typeline
    if lines then
        if type(lines) == "string" then
            lines = lines:splitlines()
        end
        local line, n = 0, 0
        local first, last, m = buffers.strip(lines)
        for i=first,last do
            n, line = action(lines[i], n, m, line)
        end
    end
end

--~ function buffers.typefile(name) -- keep this one, uses tex reader
--~     local t = input.openfile(name)
--~     local action = buffers.typeline
--~     if t then
--~         local lines = { }
--~         while true do
--~             local str = t.reader()
--~             if str then
--~                 lines[#lines+1] = str
--~             else
--~                 break
--~             end
--~         end
--~         t.close()
--~         local line, n = 0, 0
--~         local first, last, m = buffers.strip(lines)
--~         for i=first,last do
--~             n, line = action(lines[i], n, m, line)
--~         end
--~     end
--~ end

function buffers.typefile(name)
    local str = io.loaddata(name)
    if str then
        local lines = str:splitlines()
        local line, n, action = 0, 0, buffers.typeline
        local first, last, m = buffers.strip(lines)
        for i=first,last do
            n, line = action(lines[i], n, m, line)
        end
    end
end

function buffers.typeline(str,n,m,line)
    n = n + 1
    buffers.verbatimbreak(n,m)
    if str:find("%S") then
        line = line + 1
        hooks.begin_of_line(line)
        hooks.flush_line(hooks.line(str))
        hooks.end_of_line()
    else
        if flags.count_empty_lines then
            line = line + 1
        end
        hooks.empty_line(line)
    end
    return n, line
end

function buffers.save(name)
    if not name or name == "" then
        name = tex.jobname
    end
    local b, f = data[name], tex.jobname .. "-" .. name .. ".tmp"
    b = (b and type(b) == "table" and table.join(b,"\n")) or b or ""
    io.savedata(f,b)
end

-- todo, use more locals

--~ function buffers.get(name)
--~     local b = data[name]
--~     if b then
--~         if type(b) == "table" then
--~             for i=1,#b do
--~                 texprint(b[i])
--~             end
--~         else
--~             string.piecewise(b, " *[\010\013]", texprint) -- hm, can be faster
--~         end
--~     end
--~ end

local printer = (lpeg.linebyline/texprint)^0

function buffers.get(name)
    local b = buffers.data[name]
    if b then
        if type(b) == "table" then
            for i=1,#b do
                texprint(b[i])
            end
        else
        --  b:piecewise(" *[\010\013]", texprint) -- hm, can be faster
            printer:match(b)
        end
    end
end

function buffers.content(name) -- no print
    local b = data[name]
    if b then
        if type(b) == "table" then
            return concat(b," ")
        else
            return b
        end
    else
        return ""
    end
end

function buffers.collect(names,separator) -- no print
    local t = { }
    if type(names) == "table" then
        for i=1,#names do
            local c = buffers.content(names[i])
            if c ~= "" then
                t[#t+1] = c
            end
        end
    else
        for name in names:gmatch("[^,]+") do
            local c = buffers.content(name)
            if c ~= "" then
                t[#t+1] = c
            end
        end
    end
    return concat(t,separator or " ") -- maybe this will change to "\n"
end

function buffers.inspect(name)
    local b = data[name]
    if b then
        if type(b) == "table" then
            for _,v in ipairs(b) do
                if v == "" then
                    texsprint(tex.ctxcatcodes,"[crlf]\\par ")
                else
                    texsprint(tex.ctxcatcodes,(b:gsub("(.)",function(c)
                        return " [" .. byte(c) .. "] "
                    end)) .. "\\par")
                end
            end
        else
            texsprint(tex.ctxcatcodes,(b:gsub("(.)",function(c)
                return " [" .. byte(c) .. "] "
            end)))
        end
    end
end

-- maybe just line(n,str) empty(n,str)

visualizers.default      = { }
visualizers.tex          = { }
visualizers.mp           = { }

visualizers.escapetoken  = nil
visualizers.tablength    = 7

visualizers.enabletab    = false
visualizers.enableescape = false
visualizers.obeyspace    = true

function visualizers.reset()
--~     visualizers.enabletab    = false
--~     visualizers.enableescape = false
--~     buffers.currentvisualizer        = 'default'
end

buffers.currentvisualizer = 'default'

function buffers.setvisualizer(str)
    buffers.currentvisualizer = str:lower()
    if not visualizers[buffers.currentvisualizer] then
        buffers.currentvisualizer = 'default'
    end
end

function buffers.doifelsevisualizer(str)
    cs.testcase((str ~= "") and (visualizers[str:lower()] ~= nil))
end

-- calling routines, don't change


function hooks.flush_line(str,nesting)
    str = str:gsub(" *[\n\r]+ *"," ")
    local flush_line = visualizers[buffers.currentvisualizer].flush_line
    if flush_line then
        flush_line(str,nesting)
    else
        visualizers.default.flush_line(str,nesting)
    end
end

function hooks.begin_of_line(n)
    local begin_of_line = visualizers[buffers.currentvisualizer].begin_of_line
    if begin_of_line then
        begin_of_line(n)
    else
        visualizers.default.begin_of_line(n)
    end
end

function hooks.end_of_line()
    local end_of_line = visualizers[buffers.currentvisualizer].end_of_line
    if end_of_line then
        end_of_line()
    else
        visualizers.default.end_of_line(str)
    end
end

function hooks.empty_line()
    local empty_line = visualizers[buffers.currentvisualizer].empty_line
    if empty_line then
        empty_line()
    else
        visualizers.default.empty_line()
    end
end

function hooks.line(str)
    local empty_line = visualizers[buffers.currentvisualizer].line
    if line then
        return line(str)
    else
        return visualizers.default.line(str)
    end
end

-- defaults

function visualizers.default.flush_line(str)
    texsprint(tex.ctxcatcodes,buffers.escaped(str))
end

function visualizers.default.begin_of_line(n)
    texsprint(tex.ctxcatcodes, commands.begin_of_line_command .. "{" .. n .. "}")
end

function visualizers.default.end_of_line()
    texsprint(tex.ctxcatcodes,commands.end_of_line_command)
end

function visualizers.default.empty_line()
    texsprint(tex.ctxcatcodes,commands.empty_line_command)
end

function visualizers.default.line(str)
    return str
end

-- special one

commands.nested = "\\switchslantedtype "

-- todo : utf + faster, direct print and such. no \\char, vrb catcodes, see end

function visualizers.flush_nested(str, enable) -- no utf, kind of obsolete mess
    str = str:gsub(" *[\n\r]+ *"," ")
    local result, c, nested, i = "", "", 0, 1
    while i < #str do -- slow
        c = sub(str,i,i+1)
        if c == "<<" then
            nested = nested + 1
            if enable then
                result = result .. "{" .. commands.nested
            else
                result = result .. "{"
            end
            i = i + 2
        elseif c == ">>" then
            if nested > 0 then
                nested = nested - 1
                result = result .. "}"
            end
            i = i + 2
        else
            c = sub(str,i,i)
            if c == " " then
                result = result .. "\\obs "
            elseif c:find("%a") then
                result = result .. c
            else
                result = result .. "\\char" .. byte(c) .. " "
            end
            i = i + 1
        end
    end
    result = result .. "\\char" .. byte(sub(str,i,i)) .. " " .. string.rep("}",nested)
    texsprint(tex.ctxcatcodes,result)
end

-- handy helpers
--
-- \sop[color] switch_of_pretty
-- \bop[color] begin_of_pretty
-- \eop        end_of_pretty
-- \obs        obeyedspace
-- \char <n>   special characters

buffers.currentcolors = { }

function buffers.change_state(n, state, result)
    if n then
        if state ~= n then
            if state > 0 then
                result[#result+1] = "\\sop[" .. buffers.currentcolors[n] .. "]"
            else
                result[#result+1] = "\\bop[" .. buffers.currentcolors[n] .. "]"
            end
            return n
        end
    elseif state > 0 then
        result[#result+1] = "\\eop "
        return 0
    end
    return state
end

function buffers.finish_state(state, result)
    if state > 0 then
        result[#result+1] = "\\eop "
        return 0
    else
        return state
    end
end

buffers.open_nested  = rep("\\char"..byte('<').." ",2)
buffers.close_nested = rep("\\char"..byte('>').." ",2)

function buffers.replace_nested(result)
    return (gsub(result:gsub(buffers.open_nested,"{"),buffers.close_nested,"}"))
end

function buffers.flush_result(result,nested)
    if nested then
        texsprint(tex.ctxcatcodes,buffers.replace_nested(concat(result,"")))
    else
        texsprint(tex.ctxcatcodes,concat(result,""))
    end
end

local function escaped_token(c)
    if utffind(c,"^(%a%d)$") then
        return c
    elseif c == " " then
        return "\\obs "
    else
        return "\\char" .. utfbyte(c) .. " "
    end
end

buffers.escaped_token = escaped_token

function buffers.escaped(str)
    -- use the utfcharacters loop
    return (utfgsub(str,"(.)", escaped_token))
end

--~ function buffers.escaped_chr(ch)
--~     local b = utfbyte(ch)
--~     if b == 32 then
--~         return "\\obs "
--~     else
--~         return "\\char" .. b .. " "
--~     end
--~ end

function buffers.escaped_chr(ch)
    if ch == " " then
        return "\\obs "
    else
        return "\\char" .. utfbyte(ch) .. " "
    end
end

-- redone

--~ function visualizers.default.flush_line(str)
--~     local tc = tex.ctxcatcodes
--~     for u in str:utfcharacters() do
--~         texsprint(tc,escaped_token(u))
--~     end
--~ end

--~ local a, z, A, Z, zero, nine = byte("a"), byte("z"), byte("A"), byte("Z"), byte("0"), byte("9")

--~ function visualizers.default.flush_line(str)
--~     local tc = tex.ctxcatcodes
--~     for b in str:utfvalues() do
--~         if (b>=a and b<=z) or (b>=A and b<=Z) or (b>=zero and b<=nine) then
--~             texsprint(tc,char(b))
--~         elseif b == 32 then
--~             texsprint(tc,"\\obs ")
--~         else
--~             texsprint(tc,"\\char",b," ")
--~         end
--~     end
--~ end

--~ function visualizers.default.flush_line(str)
--~     local tc = tex.ctxcatcodes
--~     local vc = tex.vrbcatcodes
--~     local vs = visualizers.obeyspace
--~     for ch in str:utfcharacters() do
--~         if ch == "{" or ch == "}" then
--~             texsprint(tc,"\\char",ch:byte()," ")
--~         elseif vs and ch == " " then
--~             texsprint(tc,"\\obs ")
--~         else
--~             texsprint(vc,ch)
--~         end
--~     end
--~ end

function visualizers.default.flush_line(str)
    str = str:gsub(" *[\n\r]+ *"," ")
    local vc = tex.vrbcatcodes
    if visualizers.obeyspace then
        local tc = tex.ctxcatcodes
        for c in str:utfcharacters() do
            if c == " " then
                texsprint(tc,"\\obs ")
            else
                texsprint(vc,c)
            end
        end
    else
        texsprint(vc,str)
    end
end

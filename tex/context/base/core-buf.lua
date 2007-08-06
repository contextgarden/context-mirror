-- filename : core-buf.lua
-- comment  : companion to core-buf.tex
-- author   : Hans Hagen, PRAGMA-ADE, Hasselt NL
-- copyright: PRAGMA ADE / ConTeXt Development Team
-- license  : see context related readme files

-- ctx lua reference model / hooks and such
-- to be optimized

if not versions then versions = { } end versions['core-buf'] = 1.001

if unicode and not utf then utf = unicode.utf8 end

buffers          = { }
buffers.data     = { }
buffers.hooks    = { }
buffers.flags    = { }
buffers.commands = { }

function buffers.erase(name)
    buffers.data[name] = nil
end

function buffers.set(name, str)
    buffers.data[name] = { str } -- CHECK THIS
end

function buffers.append(name, str)
    buffers.data[name] = (buffers.data[name] or "") .. str
end

buffers.flags.store_as_table = true

-- to be sorted out: crlf + \ ; slow now

function buffers.grab(name,begintag,endtag,data)
    if not buffers.data[name] or buffers.data[name] == "" then
        buffers.data[name] = ""
        buffers.level = 0
    end
    buffers.level = buffers.level + data:count("\\"..begintag) - data:count("\\"..endtag)
    local more = buffers.level>0
    if more then
        buffers.data[name] = buffers.data[name] .. data .. endtag
        buffers.level = buffers.level - 1
    else
        if buffers.data[name] == "" then
            buffers.data[name] = data:sub(1,#data-1)
        else
            buffers.data[name] = buffers.data[name] .. "\n" .. data:sub(1,#data-1)
        end
        buffers.data[name] = buffers.data[name]:gsub("[\010\013]$","")
        if buffers.flags.store_as_table then
            -- todo: specific splitter, do we really want to erase the spaces?
            buffers.data[name] = string.split(buffers.data[name]," *[\010\013]")
        end
    end
    cs.testcase(more)
end

function buffers.doifelsebuffer(name)
    cs.testcase(buffers.data[name] ~= nil)
end

buffers.flags.optimize_verbatim        = true
buffers.flags.count_empty_lines        = false

buffers.commands.no_break              = "\\doverbatimnobreak"
buffers.commands.do_break              = "\\doverbatimgoodbreak"
buffers.commands.begin_of_line_command = "\\doverbatimbeginofline"
buffers.commands.end_of_line_command   = "\\doverbatimendofline"
buffers.commands.empty_line_command    = "\\doverbatimemptyline"

function buffers.verbatimbreak(n,m)
    if buffers.flags.optimize_verbatim then
        if (n==2) or (n==m) then
            tex.sprint(buffers.commands.no_break)
        else
            tex.sprint(buffers.commands.do_break)
        end
    end
end

function buffers.type(name)
    if buffers.data[name] then
        if type(buffers.data[name]) == "string" then
            -- todo: use linestepper (no need for a table)
            local lines = string.split(buffers.data[name]," *[\010\013]")
            local line, n, m = 0, 0, #lines
            for _,str in ipairs(lines) do
                n, line = buffers.typeline(str, n, m, line)
            end
        else
            local line, n, m = 0, 0, #buffers.data[name]
            for _,str in ipairs(buffers.data[name]) do
                n, line = buffers.typeline(str, n, m, line)
            end
        end
    end
end

function buffers.typefile(name)
    local t = input.openfile(name)
    if t then
        local line, n, m = 0, 0, t.noflines
        while true do
            str = t.reader(t)
            if str then
                n, line = buffers.typeline(str, n, m, line)
            else
                break
            end
        end
        t.close()
    end
end

function buffers.typeline(str,n,m,line)
    n = n + 1
    buffers.verbatimbreak(n,m)
    if str:find("%S") then
        line = line + 1
        buffers.hooks.begin_of_line(line)
        buffers.hooks.flush_line(buffers.hooks.line(str))
        buffers.hooks.end_of_line()
    else
        if buffers.flags.count_empty_lines then
            line = line + 1
        end
        buffers.hooks.empty_line(line)
    end
    return n, line
end

function buffers.get(name)
    if buffers.data[name] then
        if type(buffers.data[name]) == "table" then
            for _,v in ipairs(buffers.data[name]) do
                tex.print(v)
            end
        else
            string.piecewise(buffers.data[name], " *[\010\013]", tex.print)
        end
    end
end

function buffers.inspect(name)
    if buffers.data[name] then
        if type(buffers.data[name]) == "table" then
            for _,v in ipairs(buffers.data[name]) do
                if v == "" then
                    tex.sprint(tex.ctxcatcodes,"[crlf]\\par ")
                else
                    tex.sprint(tex.ctxcatcodes,(string.gsub("(.)",function(c)
                        return " [" .. string.byte(c) .. "] "
                    end)) .. "\\par")
                end
            end
        else
            tex.sprint(tex.ctxcatcodes,(string.gsub(buffers.data[name],"(.)",function(c)
                return " [" .. string.byte(c) .. "] "
            end)))
        end
    end
end

-- maybe just line(n,str) empty(n,str)

buffers.visualizers              = { }
buffers.visualizers.default      = { }
buffers.visualizers.tex          = { }
buffers.visualizers.mp           = { }

buffers.visualizers.escapetoken  = nil
buffers.visualizers.tablength    = 7

buffers.visualizers.enabletab    = false
buffers.visualizers.enableescape = false

function buffers.visualizers.reset()
    buffers.visualizers.enabletab    = false
    buffers.visualizers.enableescape = false
    buffers.currentvisualizer        = 'default'
end

buffers.currentvisualizer = 'default'

function buffers.setvisualizer(str)
    buffers.currentvisualizer = string.lower(str)
    if not buffers.visualizers[buffers.currentvisualizer] then
        buffers.currentvisualizer = 'default'
    end
end

function buffers.doifelsevisualizer(str)
    cs.testcase((str ~= "") and (buffers.visualizers[string.lower(str)] ~= nil))
end

-- calling routines, don't change

function buffers.hooks.flush_line(str,nesting)
    if buffers.visualizers[buffers.currentvisualizer].flush_line then
        buffers.visualizers[buffers.currentvisualizer].flush_line(str,nesting)
--~     elseif nesting then
--~         buffers.visualizers.flush_nested(str,false) -- no real nesting
    else
        buffers.visualizers.default.flush_line(str,nesting)
    end
end

function buffers.hooks.begin_of_line(n)
    if buffers.visualizers[buffers.currentvisualizer].begin_of_line then
        buffers.visualizers[buffers.currentvisualizer].begin_of_line(n)
    else
        buffers.visualizers.default.begin_of_line(n)
    end
end

function buffers.hooks.end_of_line()
    if buffers.visualizers[buffers.currentvisualizer].end_of_line then
        buffers.visualizers[buffers.currentvisualizer].end_of_line()
    else
        buffers.visualizers.default.end_of_line(str)
    end
end

function buffers.hooks.empty_line()
    if buffers.visualizers[buffers.currentvisualizer].empty_line then
        buffers.visualizers[buffers.currentvisualizer].empty_line()
    else
        buffers.visualizers.default.empty_line()
    end
end

function buffers.hooks.line(str)
    if buffers.visualizers[buffers.currentvisualizer].line then
        return buffers.visualizers[buffers.currentvisualizer].line(str)
    else
        return buffers.visualizers.default.line(str)
    end
end

-- defaults

function buffers.visualizers.default.flush_line(str)
    tex.sprint(tex.ctxcatcodes,buffers.escaped(str))
end

function buffers.visualizers.default.begin_of_line(n)
    tex.sprint(tex.ctxcatcodes, buffers.commands.begin_of_line_command .. "{" .. n .. "}")
end

function buffers.visualizers.default.end_of_line()
    tex.sprint(tex.ctxcatcodes,buffers.commands.end_of_line_command)
end

function buffers.visualizers.default.empty_line()
    tex.sprint(tex.ctxcatcodes,buffers.commands.empty_line_command)
end

function buffers.visualizers.default.line(str)
    return str
end

-- special one

buffers.commands.nested = "\\switchslantedtype "

-- todo : utf + faster

function buffers.visualizers.flush_nested(str, enable) -- no utf, kind of obsolete mess
    local result, c, nested, i = "", "", 0, 1
    local sb, ss, sf = string.byte, string.sub, string.find
    while i < #str do -- slow
        c = ss(str,i,i+1)
        if c == "<<" then
            nested = nested + 1
            if enable then
                result = result .. "{" .. buffers.commands.nested
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
            c = ss(str,i,i)
            if c == " " then
                result = result .. "\\obs "
            elseif sf(c,"%a") then
                result = result .. c
            else
                result = result .. "\\char" .. sb(c) .. " "
            end
            i = i + 1
        end
    end
    result = result .. "\\char" .. sb(ss(str,i,i)) .. " " .. string.rep("}",nested)
    tex.sprint(tex.ctxcatcodes,result)
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

buffers.open_nested  = string.rep("\\char"..string.byte('<').." ",2)
buffers.close_nested = string.rep("\\char"..string.byte('>').." ",2)

function buffers.replace_nested(result)
    return (string.gsub(string.gsub(result,buffers.open_nested,"{"),buffers.close_nested,"}"))
end

function buffers.flush_result(result,nested)
    if nested then
        tex.sprint(tex.ctxcatcodes,buffers.replace_nested(table.concat(result,"")))
    else
        tex.sprint(tex.ctxcatcodes,table.concat(result,""))
    end
end

function buffers.escaped(str)
    local sb, sf = utf.byte, utf.find
    return (utf.gsub(str,"(.)", function(c)
        if sf(c,"^(%a%d)$") then
            return c
        elseif c == " " then
            return "\\obs "
        else
            return "\\char" .. sb(c) .. " "
        end
    end))
end

function buffers.escaped_chr(ch)
    local b = utf.byte(ch)
    if b == 32 then
        return "\\obs "
    else
        return "\\char" .. b .. " "
    end
end

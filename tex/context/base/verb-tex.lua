-- filename : type-tex.lua
-- comment  : companion to core-buf.tex
-- author   : Hans Hagen, PRAGMA-ADE, Hasselt NL
-- copyright: PRAGMA ADE / ConTeXt Development Team
-- license  : see context related readme files

if not buffers                 then buffers                 = { } end
if not buffers.visualizers     then buffers.visualizers     = { } end
if not buffers.visualizers.tex then buffers.visualizers.tex = { } end

buffers.visualizers.tex.colors = {
    "prettytwo",
    "prettyone",
    "prettythree",
    "prettyfour"
}

buffers.visualizers.tex.states = {
    ['$']=2, ['{']=2, ['}']=2,
    ['[']=3, [']']=3, ['(']=3, [')']=3, ['<']=3, ['>']=3, ['#']=3, ['=']=3, ['"']=3,
    ['/']=4, ['^']=4, ['_']=4, ['-']=4, ['&']=4, ['+']=4, ["'"]=4, ['`']=4, ['|']=4, ['%']=4
}

-- using a table to store the result does not make sense here (actually,
-- it's substantial slower since we're flushing lines on the fly)
--
-- we could use a special catcode regime: only \ { }

function buffers.visualizers.tex.flush_line(str,nested)
    local result, state = { }, 0
    local first, escaping = false, false
    local byte, find = utf.byte, utf.find
    local finish, change = buffers.finish_state, buffers.change_state
    buffers.currentcolors = buffers.visualizers.tex.colors
    for c in string.utfcharacters(str) do
        if c == " " then
            if escaping then
                result[#result+1] = " "
            else
                state = finish(state, result)
                result[#result+1] = "\\obs "
            end
            escaping, first = false, false
        elseif c == "\t" then
            if escaping then
                result[#result+1] = " "
            else
                state = finish(state, result)
                result[#result+1] = "\\obs "
            end
            if buffers.visualizers.enabletab then
                result[#result+1] = string.rep("\\obs ",i%buffers.visualizers.tablength)
            end
            escaping, first = false, false
        elseif buffers.visualizers.enableescape and (c == buffers.visualizers.escapetoken) then
            if escaping then
                if first then
                    if find(c,"^[%a%!%?%@]$") then
                        result[#result+1] =c
                    else
                        result[#result+1] ="\\char" .. byte(c) .. " "
                    end
                    first = false
                else
                    result[#result+1] = "\\"
                    first = true
                end
            else
                state = finish(state, result)
                result[#result+1] = "\\"
                escaping, first = true, true
            end
        elseif escaping then
            if find(c,"^[%a%!%?%@]$") then
                result[#result+1] = c
            else
                result[#result+1] = "\\char" .. byte(c) .. " "
            end
            first = false
        elseif first then
            state = 1
            if find(c,"^[%a%!%?%@]$") then
                result[#result+1] = c
            else
                result[#result+1] = "\\char" .. byte(c) .. " "
                state = finish(state, result)
            end
            first = false
        elseif state == 1 then
            if find(c,"^[%a%!%?%@]$") then
                result[#result+1] = c
                first = false
            elseif c == "\\" then
                state = change(1, state, result)
                result[#result+1] = "\\char" .. byte(c) .. " "
                first = true
            else
                state = change(buffers.visualizers.tex.states[c], state, result)
                if state == 0 then
                    result[#result+1] = c
                else
                    result[#result+1] = "\\char" .. byte(c) .. " "
                end
                first = false
            end
        elseif c == "\\" then
            first = true
            state = change(1, state, result)
            result[#result+1] = "\\char" .. byte(c) .. " "
        else
            state = change(buffers.visualizers.tex.states[c], state, result)
            if state == 0 then
                result[#result+1] = c
            else
                result[#result+1] = "\\char" .. byte(c) .. " "
            end
            first = false
        end
    end
    state = finish(state, result)
    buffers.flush_result(result,nested)
end

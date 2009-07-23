if not modules then modules = { } end modules ['pret-tex'] = {
    version   = 1.001,
    comment   = "companion to buff-ver.tex",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local utf = unicode.utf8

local utfcharacters, utfvalues = string.utfcharacters, string.utfvalues
local utfbyte, utffind = utf.byte, utf.find
local rep = string.rep
local texsprint, texwrite = tex.sprint, tex.write
local ctxcatcodes, vrbcatcodes = tex.ctxcatcodes, tex.vrbcatcodes

local visualizer = buffers.newvisualizer("tex")

local colors = {
    "prettytwo",
    "prettyone",
    "prettythree",
    "prettyfour"
}

local states = {
    ['$']=2, ['{']=2, ['}']=2,
    ['[']=3, [']']=3, ['(']=3, [')']=3, ['<']=3, ['>']=3, ['#']=3, ['=']=3, ['"']=3,
    ['/']=4, ['^']=4, ['_']=4, ['-']=4, ['&']=4, ['+']=4, ["'"]=4, ['`']=4, ['|']=4, ['%']=4
}

-- some day I'll make an lpeg

local change_state, finish_state = buffers.change_state, buffers.finish_state

local chardata = characters.data
local is_letter = characters.is_letter

function visualizer.flush_line(str,nested)
    local state, first = 0, false
    buffers.currentcolors = colors
    for c in utfcharacters(str) do
        if c == " " then
            state = finish_state(state)
            texsprint(ctxcatcodes,"\\obs")
            first = false
        elseif c == "\t" then
            state = finish_state(state)
            texsprint(ctxcatcodes,"\\obs")
            if buffers.visualizers.enabletab then
                texsprint(ctxcatcodes,rep("\\obs ",i%buffers.visualizers.tablength))
            end
            first = false
        elseif first then
            state = 1
            texwrite(c)
            if not utffind(c,"^[%a%!%?%@]$") then
                state = finish_state(state)
            end
            first = false
        elseif state == 1 then
            if utffind(c,"^[%a%!%?%@]$") then
                texwrite(c)
                first = false
            elseif c == "\\" then
                state = change_state(1, state)
                texwrite(c)
                first = true
            else
                state = change_state(states[c], state)
                texwrite(c)
                first = false
            end
        elseif c == "\\" then
            first = true
            state = change_state(1, state)
            texwrite(c)
        else
            state = change_state(states[c], state)
            texwrite(c)
            first = false
        end
    end
    state = finish_state(state)
end

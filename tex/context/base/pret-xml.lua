if not modules then modules = { } end modules ['pret-xml'] = {
    version   = 1.001,
    comment   = "companion to buff-ver.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- line by line, no check because can be snippet (educational) and
-- a somewhat simplified view on xml; we forget about dtd's and
-- cdata (some day i'll make a visualizer for valid xml using the
-- built in parser)

local utf = unicode.utf8
local utfcharacters, utfvalues = string.utfcharacters, string.utfvalues
local utfbyte, utffind = utf.byte, utf.find
local texwrite = tex.write

local buffers = buffers
local context = context

local changestate, finishstate = buffers.changestate, buffers.finishstate

local visualizer = buffers.newvisualizer("xml")

local colors = {
    "prettytwo",
    "prettyone",
    "prettythree",
    "prettyfour"
}

local states = {
    ['"']=2, ["'"]=2,
    ["-"]=1, ["?"]=1, ["!"]=1, [":"]=1, ["_"]=1, ["/"]=1,
}

local state, intag, dotag, inentity, inquote

function visualizer.reset()
    state, intag, dotag, inentity, inquote = 0, false, false, false, false
end

local space = context.obs

function visualizer.flush_line(str,nested)
    buffers.currentcolors = colors
    for c in utfcharacters(str) do
        if c == "&" then
            inentity = true -- no further checking
            state = changestate(3, state)
            texwrite(c)
        elseif c == ";" then
            if inentity then
                inentity = false
                state = changestate(3, state)
                texwrite(c)
                state = finishstate(state)
            else
                texwrite(c)
            end
        elseif inentity then
            state = changestate(3, state)
            texwrite(c)
        elseif c == " " then
            state = finishstate(state)
            space()
            intag = false
        elseif c == "\t" then
            state = finishstate(state)
            space()
            if buffers.visualizers.enabletab then
                for i=1,i%buffers.visualizers.tablength do
                    space()
                end
            end
            intag = false
        elseif c == "<" then
            if intag then
                state = finishstate(state)
                -- error
            else
                intag = 1
                dotag = true
                state = changestate(1, state)
            end
            texwrite(c)
        elseif c == ">" then
            if intag then
                texwrite(c)
                state = finishstate(state)
                intag, dotag = false, false
            elseif dotag then
                state = changestate(1, state)
                texwrite(c)
                state = finishstate(state)
                intag, dotag = false, false
            else
                state = finishstate(state)
                texwrite(c)
            end
        elseif intag then
            if utffind(c,"^[%S]$") then
                state = changestate(1, state)
                texwrite(c)
                intag = intag + 1
            else
                intag = false
                state = finishstate(state)
                texwrite(c)
            end
        elseif dotag then
            if c == "'" or c == '"' then
                if inquote then
                    if c == inquote then
                        state = changestate(states[c], state) -- 2
                        texwrite(c)
                        state = finishstate(state)
                        inquote = false
                    else
                        texwrite(c)
                    end
                else
                    inquote = c
                    state = changestate(states[c], state)
                    texwrite(c)
                    state = finishstate(state)
                end
            elseif inquote then
                texwrite(c)
            else
                state = changestate(states[c], state)
                texwrite(c)
            end
        else
            texwrite(c)
        end
    end
    state = finishstate(state)
end

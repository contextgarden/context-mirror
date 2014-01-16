if not modules then modules = { } end modules ['char-utf'] = {
    version   = 1.001,
    comment   = "companion to char-utf.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- todo: trackers
-- todo: no longer special characters (high) here, only needed in special cases and
-- these don't go through this file anyway
-- graphemes: basic symbols

--[[ldx--
<p>When a sequence of <l n='utf'/> characters enters the application, it may be
neccessary to collapse subsequences into their composed variant.</p>

<p>This module implements methods for collapsing and expanding <l n='utf'/>
sequences. We also provide means to deal with characters that are special to
<l n='tex'/> as well as 8-bit characters that need to end up in special kinds
of output (for instance <l n='pdf'/>).</p>

<p>We implement these manipulations as filters. One can run multiple filters
over a string.</p>
--ldx]]--

local concat, gmatch, gsub, find = table.concat, string.gmatch, string.gsub, string.find
local utfchar, utfbyte, utfcharacters, utfvalues = utf.char, utf.byte, utf.characters, utf.values
local allocate = utilities.storage.allocate
local lpegmatch, lpegpatterns = lpeg.match, lpeg.patterns

local charfromnumber = characters.fromnumber

characters            = characters or { }
local characters      = characters

characters.graphemes  = allocate()
local graphemes       = characters.graphemes

characters.combined   = allocate()
local combined        = characters.combined

characters.decomposed = allocate()
local decomposed      = characters.decomposed

characters.mathpairs  = allocate()
local mathpairs       = characters.mathpairs

characters.filters    = allocate()
local filters         = characters.filters

filters.utf           = filters.utf  or { }
local utffilters      = characters.filters.utf

-- is characters.combined cached?

--[[ldx--
<p>It only makes sense to collapse at runtime, since we don't expect source code
to depend on collapsing.</p>
--ldx]]--

-- for the moment, will be entries in char-def.lua

local decomposed = allocate {
    ["Ĳ"] = "IJ",
    ["ĳ"] = "ij",
    ["և"] = "եւ",
    ["ﬀ"] = "ff",
    ["ﬁ"] = "fi",
    ["ﬂ"] = "fl",
    ["ﬃ"] = "ffi",
    ["ﬄ"] = "ffl",
    ["ﬅ"] = "ſt",
    ["ﬆ"] = "st",
    ["ﬓ"] = "մն",
    ["ﬔ"] = "մե",
    ["ﬕ"] = "մի",
    ["ﬖ"] = "վն",
    ["ﬗ"] = "մխ",
}

characters.decomposed = decomposed

local function initialize() -- maybe only 'mn'
    local data = characters.data
    for unicode, v in next, data do
        -- using vs and first testing for length is faster (.02->.01 s)
        local vs = v.specials
        local vc = vs and #vs == 3 and vs[1]
        if vc == "char" then
            local one, two = vs[2], vs[3]
            if data[two].category == "mn" then
                local cgf = combined[one]
                if not cgf then
                    cgf = { [two] = unicode }
                    combined[one]  = cgf
                else
                    cgf[two] = unicode
                end
            end
            local first, second, combination = utfchar(one), utfchar(two), utfchar(unicode)
            local cgf = graphemes[first]
            if not cgf then
                cgf = { [second] = combination }
                graphemes[first] = cgf
            else
                cgf[second] = combination
            end
            if v.mathclass or v.mathspec then
                local mps = mathpairs[two]
                if not mps then
                    mps = { [one] = unicode }
                    mathpairs[two] = mps
                else
                    mps[one] = unicode -- here unicode
                end
                local mps = mathpairs[second]
                if not mps then
                    mps = { [first] = combination }
                    mathpairs[second] = mps
                else
                    mps[first] = combination
                end
            end
     -- elseif vc == "compat" then
     -- else
     --     local description = v.description
     --     if find(description,"LIGATURE") then
     --         if vs then
     --             local t = { }
     --             for i=2,#vs do
     --                 t[#t+1] = utfchar(vs[i])
     --             end
     --             decomposed[utfchar(unicode)] = concat(t)
     --         else
     --             local vs = v.shcode
     --             if vs then
     --                 local t = { }
     --                 for i=1,#vs do
     --                     t[i] = utfchar(vs[i])
     --                 end
     --                 decomposed[utfchar(unicode)] = concat(t)
     --             end
     --         end
     --     end
        end
    end
    initialize = false
    characters.initialize = function() end -- when used outside tex
end

characters.initialize = initialize

-- utffilters.addgrapheme(utfchar(318),'l','\string~')
-- utffilters.addgrapheme('c','a','b')

function utffilters.addgrapheme(result,first,second) -- can be U+ 0x string or utf or number
    local result = charfromnumber(result)
    local first  = charfromnumber(first)
    local second = charfromnumber(second)
    if not graphemes[first] then
        graphemes[first] = { [second] = result }
    else
        graphemes[first][second] = result
    end
end

--[[ldx--
<p>In order to deal with 8-bit output, we need to find a way to go from <l n='utf'/> to
8-bit. This is handled in the <l n='luatex'/> engine itself.</p>

<p>This leaves us problems with characters that are specific to <l n='tex'/> like
<type>{}</type>, <type>$</type> and alike. We can remap some chars that tex input files
are sensitive for to a private area (while writing to a utility file) and revert then
to their original slot when we read in such a file. Instead of reverting, we can (when
we resolve characters to glyphs) map them to their right glyph there. For this purpose
we can use the private planes 0x0F0000 and 0x100000.</p>
--ldx]]--

local low     = allocate()
local high    = allocate()
local escapes = allocate()
local special = "~#$%^&_{}\\|" -- "~#$%{}\\|"

local private = {
    low     = low,
    high    = high,
    escapes = escapes,
}

utffilters.private = private

local tohigh = lpeg.replacer(low)   -- frozen, only for basic tex
local tolow  = lpeg.replacer(high)  -- frozen, only for basic tex

lpegpatterns.utftohigh = tohigh
lpegpatterns.utftolow  = tolow

function utffilters.harden(str)
    return lpegmatch(tohigh,str)
end

function utffilters.soften(str)
    return lpegmatch(tolow,str)
end

local function set(ch)
    local cb
    if type(ch) == "number" then
        cb, ch = ch, utfchar(ch)
    else
        cb = utfbyte(ch)
    end
    if cb < 256 then
        escapes[ch] = "\\" .. ch
        low[ch] = utfchar(0x0F0000 + cb)
        if ch == "%" then
            ch = "%%" -- nasty, but we need this as in replacements (also in lpeg) % is interpreted
        end
        high[utfchar(0x0F0000 + cb)] = ch
    end
end

private.set = set

-- function private.escape (str) return    gsub(str,"(.)", escapes) end
-- function private.replace(str) return utfgsub(str,"(.)", low    ) end
-- function private.revert (str) return utfgsub(str,"(.)", high   ) end

private.escape  = utf.remapper(escapes)
private.replace = utf.remapper(low)
private.revert  = utf.remapper(high)

for ch in gmatch(special,".") do set(ch) end

--[[ldx--
<p>We get a more efficient variant of this when we integrate
replacements in collapser. This more or less renders the previous
private code redundant. The following code is equivalent but the
first snippet uses the relocated dollars.</p>

<typing>
[󰀤x󰀤] [$x$]
</typing>

<p>The next variant has lazy token collecting, on a 140 page mk.tex this saves
about .25 seconds, which is understandable because we have no graphemes and
not collecting tokens is not only faster but also saves garbage collecting.
</p>
--ldx]]--

local skippable  = table.tohash { "mkiv", "mkvi" }
local filesuffix = file.suffix

function utffilters.collapse(str,filename)   -- we can make high a seperate pass (never needed with collapse)
    if skippable[filesuffix(filename)] then
        return str
 -- elseif find(filename,"^virtual://") then
 --     return str
 -- else
 --  -- print("\n"..filename)
    end
    if str and str ~= "" then
        local nstr = #str
        if nstr > 1 then
            if initialize then -- saves a call
                initialize()
            end
            local tokens, t, first, done, n = { }, 0, false, false, 0
            for second in utfcharacters(str) do
                if done then
                    if first then
                        if second == " " then
                            t = t + 1
                            tokens[t] = first
                            first = second
                        else
                         -- local crs = high[second]
                         -- if crs then
                         --     t = t + 1
                         --     tokens[t] = first
                         --     first = crs
                         -- else
                                local cgf = graphemes[first]
                                if cgf and cgf[second] then
                                    first = cgf[second]
                                else
                                    t = t + 1
                                    tokens[t] = first
                                    first = second
                                end
                         -- end
                        end
                    elseif second == " " then
                        first = second
                    else
                     -- local crs = high[second]
                     -- if crs then
                     --     first = crs
                     -- else
                            first = second
                     -- end
                    end
                elseif second == " " then
                    first = nil
                    n = n + 1
                else
                 -- local crs = high[second]
                 -- if crs then
                 --     for s in utfcharacters(str) do
                 --         if n == 1 then
                 --             break
                 --         else
                 --             t = t + 1
                 --             tokens[t] = s
                 --             n = n - 1
                 --         end
                 --     end
                 --     if first then
                 --         t = t + 1
                 --         tokens[t] = first
                 --     end
                 --     first = crs
                 --     done = true
                 -- else
                        local cgf = graphemes[first]
                        if cgf and cgf[second] then
                            for s in utfcharacters(str) do
                                if n == 1 then
                                    break
                                else
                                    t = t + 1
                                    tokens[t] = s
                                    n = n - 1
                                end
                            end
                            first = cgf[second]
                            done = true
                        else
                            first = second
                            n = n + 1
                        end
                 -- end
                end
            end
            if done then
                if first then
                    t = t + 1
                    tokens[t] = first
                end
                return concat(tokens) -- seldom called
            end
        elseif nstr > 0 then
            return high[str] or str
        end
    end
    return str
end

-- function utffilters.decompose(str)
--     if str and str ~= "" then
--         local nstr = #str
--         if nstr > 1 then
--          -- if initialize then -- saves a call
--          --     initialize()
--          -- end
--             local tokens, t, done, n = { }, 0, false, 0
--             for s in utfcharacters(str) do
--                 local dec = decomposed[s]
--                 if dec then
--                     if not done then
--                         if n > 0 then
--                             for s in utfcharacters(str) do
--                                 if n == 0 then
--                                     break
--                                 else
--                                     t = t + 1
--                                     tokens[t] = s
--                                     n = n - 1
--                                 end
--                             end
--                         end
--                         done = true
--                     end
--                     t = t + 1
--                     tokens[t] = dec
--                 elseif done then
--                     t = t + 1
--                     tokens[t] = s
--                 else
--                     n = n + 1
--                 end
--             end
--             if done then
--                 return concat(tokens) -- seldom called
--             end
--         end
--     end
--     return str
-- end

local tree     = lpeg.utfchartabletopattern(table.keys(decomposed))
local finder   = lpeg.finder(tree,false,true)
local replacer = lpeg.replacer(tree,decomposed,false,true)

function utffilters.decompose(str) -- 3 to 4 times faster than the above
    if str and str ~= "" and #str > 1 and lpegmatch(finder,str) then
        return lpegmatch(replacer,str)
    end
    return str
end

local sequencers = utilities.sequencers

if sequencers then

    local textfileactions = resolvers.openers.helpers.textfileactions

    sequencers.appendaction (textfileactions,"system","characters.filters.utf.collapse")
    sequencers.disableaction(textfileactions,"characters.filters.utf.collapse")

    sequencers.appendaction (textfileactions,"system","characters.filters.utf.decompose")
    sequencers.disableaction(textfileactions,"characters.filters.utf.decompose")

    function characters.filters.utf.enable()
        sequencers.enableaction(textfileactions,"characters.filters.utf.collapse")
        sequencers.enableaction(textfileactions,"characters.filters.utf.decompose")
    end

    directives.register("filters.utf.collapse", function(v)
        sequencers[v and "enableaction" or "disableaction"](textfileactions,"characters.filters.utf.collapse")
    end)

    directives.register("filters.utf.decompose", function(v)
        sequencers[v and "enableaction" or "disableaction"](textfileactions,"characters.filters.utf.decompose")
    end)

end

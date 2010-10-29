if not modules then modules = { } end modules ['char-utf'] = {
    version   = 1.001,
    comment   = "companion to char-utf.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

--[[ldx--
<p>When a sequence of <l n='utf'/> characters enters the application, it may
be neccessary to collapse subsequences into their composed variant.</p>

<p>This module implements methods for collapsing and expanding <l n='utf'/>
sequences. We also provide means to deal with characters that are
special to <l n='tex'/> as well as 8-bit characters that need to end up
in special kinds of output (for instance <l n='pdf'/>).</p>

<p>We implement these manipulations as filters. One can run multiple filters
over a string.</p>
--ldx]]--

local utfchar, utfbyte, utfgsub = utf.char, utf.byte, utf.gsub
local concat, gmatch, gsub = table.concat, string.gmatch, string.gsub
local utfcharacters, utfvalues = string.utfcharacters, string.utfvalues
local allocate = utilities.storage.allocate

-- todo: trackers

characters            = characters or { }
local characters      = characters

characters.graphemes  = allocate()
local graphemes       = characters.graphemes

characters.mathpairs  = allocate()
local mathpairs       = characters.mathpairs

characters.filters    = allocate()
local filters         = characters.filters

filters.utf           = filters.utf  or { }
local utffilters      = characters.filters.utf

utffilters.collapsing = true
utffilters.expanding  = true

--[[ldx--
<p>It only makes sense to collapse at runtime, since we don't expect
source code to depend on collapsing.</p>
--ldx]]--

local function initialize()
    for k,v in next, characters.data do
        -- using vs and first testing for length is faster (.02->.01 s)
        local vs = v.specials
        if vs and #vs == 3 and vs[1] == 'char' then
            local one, two = vs[2], vs[3]
            local first, second, combined = utfchar(one), utfchar(two), utfchar(k)
            local cgf = graphemes[first]
            if not cgf then
                cgf = { }
                graphemes[first] = cgf
            end
            cgf[second] = combined
            if v.mathclass or v.mathspec then
                local mps = mathpairs[two]
                if not mps then
                    mps = { }
                    mathpairs[two] = mps
                end
                mps[one] = k
                local mps = mathpairs[second]
                if not mps then
                    mps = { }
                    mathpairs[second] = mps
                end
                mps[first] = combined
            end
        end
    end
    initialize = false
end

-- utffilters.addgrapheme(utfchar(318),'l','\string~')
-- utffilters.addgrapheme('c','a','b')

function utffilters.addgrapheme(result,first,second)
    local r, f, s = tonumber(result), tonumber(first), tonumber(second)
    if r then result = utfchar(r) end
    if f then first  = utfchar(f) end
    if s then second = utfchar(s) end
    if not graphemes[first] then
        graphemes[first] = { [second] = result }
    else
        graphemes[first][second] = result
    end
end

--~ function utffilters.collapse(str) -- old one
--~     if utffilters.collapsing and str and #str > 1 then
--~         if initialize then -- saves a call
--~             initialize()
--~         end
--~         local tokens, n, first, done = { }, 0, false, false
--~         for second in utfcharacters(str) do
--~             local cgf = graphemes[first]
--~             if cgf and cgf[second] then
--~                 first, done = cgf[second], true
--~             elseif first then
--~                 n + n + 1
--~                 tokens[n] = first
--~                 first = second
--~             else
--~                 first = second
--~             end
--~         end
--~         if done then
--~             n + n + 1
--~             tokens[n] = first
--~             return concat(tokens)
--~         end
--~     end
--~     return str
--~ end

--[[ldx--
<p>In order to deal with 8-bit output, we need to find a way to
go from <l n='utf'/> to 8-bit. This is handled in the
<l n='luatex'/> engine itself.</p>

<p>This leaves us problems with characters that are specific to
<l n='tex'/> like <type>{}</type>, <type>$</type> and alike.</p>

<p>We can remap some chars that tex input files are sensitive for to
a private area (while writing to a utility file) and revert then
to their original slot when we read in such a file. Instead of
reverting, we can (when we resolve characters to glyphs) map them
to their right glyph there.</p>

<p>For this purpose we can use the private planes 0x0F0000 and
0x100000.</p>
--ldx]]--

local low     = allocate({ })
local high    = allocate({ })
local escapes = allocate({ })
local special = "~#$%^&_{}\\|"

local private = {
    low     = low,
    high    = high,
    escapes = escapes,
}

utffilters.private = private

local function set(ch)
    local cb
    if type(ch) == "number" then
        cb, ch = ch, utfchar(ch)
    else
        cb = utfbyte(ch)
    end
    if cb < 256 then
        low[ch] = utfchar(0x0F0000 + cb)
        high[utfchar(0x0F0000 + cb)] = ch
        escapes[ch] = "\\" .. ch
    end
end

private.set = set

function private.escape (str) return    gsub(str,"(.)", escapes) end
function private.replace(str) return utfgsub(str,"(.)", low    ) end
function private.revert (str) return utfgsub(str,"(.)", high   ) end

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
about .25 seconds, which is understandable because we have no graphmes and
not collecting tokens is not only faster but also saves garbage collecting.
</p>
--ldx]]--

-- lpeg variant is not faster

function utffilters.collapse(str) -- not really tested (we could preallocate a table)
    if utffilters.collapsing and str then
        local nstr = #str
        if nstr > 1 then
            if initialize then -- saves a call
                initialize()
            end
            local tokens, t, first, done, n = { }, 0, false, false, 0
            for second in utfcharacters(str) do
                if done then
                    local crs = high[second]
                    if crs then
                        if first then
                            t = t + 1
                            tokens[t] = first
                        end
                        first = crs
                    else
                        local cgf = graphemes[first]
                        if cgf and cgf[second] then
                            first = cgf[second]
                        elseif first then
                            t = t + 1
                            tokens[t] = first
                            first = second
                        else
                            first = second
                        end
                    end
                else
                    local crs = high[second]
                    if crs then
                        for s in utfcharacters(str) do
                            if n == 1 then
                                break
                            else
                                t = t + 1
                                tokens[t] = s
                                n = n -1
                            end
                        end
                        if first then
                            t = t + 1
                            tokens[t] = first
                        end
                        first = crs
                        done = true
                    else
                        local cgf = graphemes[first]
                        if cgf and cgf[second] then
                            for s in utfcharacters(str) do
                                if n == 1 then
                                    break
                                else
                                    t = t + 1
                                    tokens[t] = s
                                    n = n -1
                                end
                            end
                            first = cgf[second]
                            done = true
                        else
                            first = second
                            n = n + 1
                        end
                    end
                end
            end
            if done then
                t = t + 1
                tokens[t] = first
                return concat(tokens) -- seldom called
            end
        elseif nstr > 0 then
            return high[str] or str
        end
    end
    return str
end

--[[ldx--
<p>Next we implement some commands that are used in the user interface.</p>
--ldx]]--

commands = commands or { }

--~ function commands.uchar(first,second)
--~     context(utfchar(first*256+second))
--~ end

--[[ldx--
<p>A few helpers (used to be <t>luat-uni<t/>).</p>
--ldx]]--

function utf.split(str)
    local t, n = { }, 0
    for snippet in utfcharacters(str) do
        n = n + 1
        t[n+1] = snippet
    end
    return t
end

function utf.each(str,fnc)
    for snippet in utfcharacters(str) do
        fnc(snippet)
    end
end

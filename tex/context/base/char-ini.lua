if not modules then modules = { } end modules ['char-ini'] = {
    version   = 1.001,
    comment   = "companion to char-ini.tex",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

utf = utf or unicode.utf
tex = tex or { }

function tex.ctxprint(...)
    tex.sprint(tex.ctxcatcodes,...)
end

--[[ldx--
<p>This module implements some methods and creates additional datastructured
from the big character table that we use for all kind of purposes:
<type>char-def.lua</type>.</p>
--ldx]]--

characters          = characters          or { }
characters.data     = characters.data     or { }
characters.synonyms = characters.synonyms or { }
characters.context  = characters.context  or { }

characters.categories = {
    lu = "Letter Uppercase",
    ll = "Letter Lowercase",
    lt = "Letter Titlecase",
    lm = "Letter Modifier",
    lo = "Letter Other",
    mn = "Mark Nonspacing",
    mc = "Mark Spacing Combining",
    me = "Mark Enclosing",
    nd = "Number Decimal Digit",
    nl = "Number Letter",
    no = "Number Other",
    pc = "Punctuation Connector",
    pd = "Punctuation Dash",
    ps = "Punctuation Open",
    pe = "Punctuation Close",
    pi = "Punctuation Initial Quote",
    pf = "Punctuation Final Quote",
    po = "Punctuation Other",
    sm = "Symbol Math",
    sc = "Symbol Currency",
    sk = "Symbol Modifier",
    so = "Symbol Other",
    zs = "Separator Space",
    zl = "Separator Line",
    zp = "Separator Paragraph",
    cc = "Other Control",
    cf = "Other Format",
    cs = "Other Surrogate",
    co = "Other Private Use",
    cn = "Other Not Assigned",
}

--~ special   : cf (softhyphen) zs (emspace)
--~ characters: ll lm lo lt lu mn nl no pc pd pe pf pi po ps sc sk sm so

characters.is_character = table.tohash {
    "ll","lm","lo","lt","lu","mn","nl","no","pc","pd","pe","pf","pi","po","ps","sc","sk","sm","so"
}

characters.is_command = table.tohash {
    "cf","zs"
}

-- linebreak:
--
-- normative   : BK CR LF CM SG GL CB SP ZW NL WJ JL JV JT H2 H3
-- informative : XX OP CL QU NS EX SY IS PR PO NU AL ID IN HY BB BA SA AI B2

-- east asian width:
--
-- N A H W F Na

do
    local _empty_table_ = { __index = function(t,k) return "" end }

    function table.set_empty_metatable(t)
        setmetatable(t,_empty_table_)
    end
end

table.set_empty_metatable(characters.data)

--[[ldx--
<p>At this point we assume that the big data table is loaded. From this
table we derive a few more.</p>
--ldx]]--

-- used ?

characters.context.unicodes  = characters.context.unicodes  or { }
characters.context.utfcodes  = characters.context.utfcodes  or { }
characters.context.enccodes  = characters.context.enccodes  or { }
characters.context.fallbacks = characters.context.fallbacks or { }

function characters.context.rehash()
    local unicodes, utfcodes, enccodes, fallbacks, utfchar = characters.context.unicodes, characters.context.utfcodes, characters.context.enccodes, characters.context.fallbacks, utf.char
    for k,v in pairs(characters.data) do
        local contextname, adobename, specials = v.contextname, v.adobename, v.specials
        if contextname then
            local slot = v.unicodeslot
            unicodes[contextname] = slot
            utfcodes[contextname] = utfchar(slot)
        end
        local encname = adobename or contextname
        if encname then
            enccodes[encname] = k
        end
        if specials and specials[1] == "compat" and specials[2] == 0x0020 and specials[3] then
            local s = specials[3]
            fallbacks[k] = s
            fallbacks[s] = k
        end
    end
    for name,code in pairs(characters.synonyms) do
        if not enccodes[name] then enccodes[name] = code end
    end
end

--[[ldx--
<p>The <type>context</type> namespace is used to store methods and data
which is rather specific to <l n='context'/>.</p>
--ldx]]--

function characters.context.show(n)
    local n = characters.number(n)
    local d = characters.data[n]
    if d then
        local function entry(label,name)
            tex.ctxprint(string.format("\\NC %s\\NC %s\\NC\\NR",label,characters.valid(d[name])))
        end
        tex.ctxprint("\\starttabulate[|Tl|Tl|]")
        entry("unicode index" , "unicodeslot")
        entry("context name"  , "contextname")
        entry("adobe name"    , "adobename")
        entry("category"      , "category")
        entry("description"   , "description")
        entry("uppercase code", "uccode")
        entry("lowercase code", "lccode")
        entry("specials"      , "specials")
        tex.ctxprint("\\stoptabulate ")
    end
end

--[[ldx--
<p>Instead of using a <l n='tex'/> file to define the named glyphs, we
use the table. After all, we have this information available anyway.</p>
--ldx]]--

function characters.makeactive(n,name)
    tex.sprint(string.format("\\catcode%s=13\\unexpanded\\def %s{\\%s}",n,utf.char(n),name))
end

function tex.uprint(n)
    tex.sprint(tex.ctxcatcodes,utf.char(n))
end

--~ function characters.context.define()
--~     local unicodes, utfcodes = characters.context.unicodes, characters.context.utfcodes
--~     local flush, tc, char = tex.sprint, tex.ctxcatcodes, utf.char
--~     local is_character, is_command = characters.is_character, characters.is_command
--~     for u, chr in pairs(characters.data) do
--~         local contextname = chr.contextname
--~         if contextname then
--~             local category = chr.category
--~             if is_character[category] then
--~              -- by this time, we're still in normal catcode mode
--~                  if chr.unicodeslot < 128 then
--~                     flush(tc, "\\chardef\\" .. contextname .. "=" .. u) -- unicodes[contextname])
--~                  else
--~                     flush(tc, "\\let\\" .. contextname .. "=" .. char(u)) -- utfcodes[contextname])
--~                  end
--~             elseif is_command[category] then
--~                  flush("\\catcode"..u.."=13\\unexpanded\\def "..char(u).."{\\"..contextname.."}")
--~             --  characters.makeactive(u,contextname)
--~             end
--~         end
--~     end
--~ end

characters.activated = { }

function characters.context.define()
    local unicodes, utfcodes = characters.context.unicodes, characters.context.utfcodes
    local flush, tc, char = tex.sprint, tex.ctxcatcodes, utf.char
    local is_character, is_command = characters.is_character, characters.is_command
    for u, chr in pairs(characters.data) do
        local contextname = chr.contextname
        if contextname then
            local category = chr.category
            if is_character[category] then
             -- by this time, we're still in normal catcode mode
                 if chr.unicodeslot < 128 then
                    flush(tc, "\\chardef\\" .. contextname .. "=" .. u) -- unicodes[contextname])
                 else
                    flush(tc, "\\let\\" .. contextname .. "=" .. char(u)) -- utfcodes[contextname])
                 end
            elseif is_command[category] then
                 flush("{\\catcode"..u.."=13\\unexpanded\\gdef "..char(u).."{\\"..contextname.."}}")
                 characters.activated[u] = true
            end
        end
    end
end

function characters.context.activate()
    for u,_ in pairs(characters.activated) do
        tex.sprint(tex.ctxcatcodes,"\\catcode "..u.."=13 ")
    end
end

function characters.charcode(box)
    local b = tex.box[box]
    local l = b.list
    tex.sprint((l and l.id == node.id('glyph') and l.char) or 0)
end

--[[ldx--
<p>Setting the lccodes is also done in a loop over the data table.</p>
--ldx]]--

function characters.setcodes()
    local flush, tc = tex.sprint, tex.ctxcatcodes
    for code, chr in pairs(characters.data) do
        local cc = chr.category
        if cc == 'll' or cc == 'lu' or cc == 'lt' then
            local lc, uc = chr.lccode, chr.uccode
            if not lc then chr.lccode, lc = code, code end
            if not uc then chr.uccode, uc = code, code end
            flush(tc, '\\setcclcuc '.. code .. ' ' .. lc .. ' ' .. uc .. ' ')
        end
    end
end

--[[ldx--
<p>Next comes a whole series of helper methods. These are (will be) part
of the official <l n='api'/>.</p>
--ldx]]--

--[[ldx--
<p>This converts a string (if given) into a number.</p>
--ldx]]--

function characters.number(n)
    if type(n) == "string" then return tonumber(n,16) else return n end
end

--[[ldx--
<p>Checking for valid characters.</p>
--ldx]]--

function characters.is_valid(s)
    return s or ""
end

function characters.checked(s, default)
    return s or default
end

characters.valid = characters.is_valid

--[[ldx--
<p>The next method is used when constructing the main table, although nowadays
we do this in one step. The index can be a string or a number.</p>
--ldx]]--

function characters.define(c)
    characters.data[characters.number(c.unicodeslot)] = c
end

--[[ldx--
<p></p>
--ldx]]--
-- set a table entry; index is number (can be different from unicodeslot)

function characters.set(n, c)
    characters.data[characters.number(n)] = c
end

--[[ldx--
<p>Get a table entry happens by number. Keep in mind that the unicodeslot
can be different (not likely).</p>
--ldx]]--

function characters.get(n)
    return characters.data[characters.number(n)]
end

--[[ldx--
<p>A couple of convenience methods. Beware, these are not that fast due
to the checking.</p>
--ldx]]--

function characters.hexindex(n)
    return string.format("%04X", characters.valid(characters.data[characters.number(n)].unicodeslot))
end

function characters.contextname(n)
    return characters.valid(characters.data[characters.number(n)].contextname)
end

function characters.adobename(n)
    return characters.valid(characters.data[characters.number(n)].adobename)
end

function characters.description(n)
    return characters.valid(characters.data[characters.number(n)].description)
end

function characters.category(n)
    return characters.valid(characters.data[characters.number(n)].category)
end

--[[ldx--
<p>Requesting lower and uppercase codes:</p>
--ldx]]--

function characters.uccode(n) return characters.data[n].uccode or n end
function characters.lccode(n) return characters.data[n].lccode or n end

function characters.flush(n)
    local c = characters.data[n]
    if c and c.contextname then
        tex.sprint(tex.texcatcodes, "\\"..c.contextname)
    else
        tex.sprint(unicode.utf8.char(n))
    end
end

function characters.shape(n)
    local shcode = characters.data[n].shcode
    if not shcode then
        return n, nil
    elseif type(shcode) == "table" then
        return shcode[1], shcode[#shcode]
    else
        return shcode, nil
    end
end

--[[ldx--
<p>Categories play an important role, so here are some checkers.</p>
--ldx]]--

function characters.is_of_category(token,category)
    if type(token) == "string" then
        return characters.data[utf.byte(token)].category == category
    else
        return characters.data[token].category == category
    end
end

function characters.i_is_of_category(i,category) -- by index (number)
    local cd = characters.data[i]
    return cd and cd.category == category
end

function characters.n_is_of_category(n,category) -- by name (string)
    local cd = characters.data[utf.byte(n)]
    return cd and cd.category == category
end

--[[ldx--
<p>The following code is kind of messy. It is used to generate the right
unicode reference tables.</p>
--ldx]]--

function characters.setpdfunicodes()
--~     local flush, tc, sf = tex.sprint, tex.ctxcatcodes, string.format
--~     for _,v in pairs(characters.data) do
--~         if v.adobename then
--~             flush(tc,sf("\\pdfglyphtounicode{%s}{%04X}", v.adobename, v.unicodeslot))
--~         end
--~     end
end

--[[ldx--
<p>The next method generates a table for good old <l n='pdftex'/>.</p>

<typing>
characters.pdftex.make_pdf_to_unicodetable("pdfr-def.tex")
</typing>
--ldx]]--

characters.pdftex = characters.pdftex or { }

function characters.pdftex.make_pdf_to_unicodetable(filename)
--~     local sf = string.format
--~     f = io.open(filename,'w')
--~     if f then
--~         f:write("% This file is generated with Luatex using the\n")
--~         f:write("% character tables that come with ConTeXt MkIV.\n")
--~         f:write("%\n")
--~         f:write("\\ifx\\pdfglyphtounicode\\undefined\\endinput\\fi\n") -- just to be sure
--~         for _, v in pairs(characters.data) do
--~             if v.adobename then
--~                 f:write(sf("\\pdfglyphtounicode{%s}{%04X}", v.adobename, v.unicodeslot))
--~             end
--~         end
--~         f:write("%\n")
--~         f:write("%\n")
--~         f:write("\\endinput")
--~         f:close()
--~     end
end

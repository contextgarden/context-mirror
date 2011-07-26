if not modules then modules = { } end modules ['x-markdown'] = {
    version   = 1.001,
    comment   = "companion to x-markdown.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "see below",
    license   = "see context related readme files"
}

--[[
Copyright (C) 2009 John MacFarlane / Khaled Hosny / Hans Hagen

The main parser is derived from the lunamark parser written by John MacFarlane. You
can download lunamark from:

    http://github.com/jgm/lunamark.git

Khaled Hosny provided the context writer for lunamark and that was used as starting
point for the mapping. The original code can be fetched from the above location.

While playing with the original code I got the feeling that lpeg could perform better.
The slowdown was due to the fact that the parser's lpeg was reconstructed each time a
nested parse was needed. After changing that code a bit I could bring down parsing of
some test code from 2 seconds to less than 0.1 second so I decided to stick to this
parser instead of writing my own. After all, the peg code looks pretty impressive and
visiting Johns pandoc pages is worth the effort:

    http://johnmacfarlane.net/pandoc/

The code here is mostly meant for processing snippets embedded in a context
documents and is no replacement for pandoc at all. Therefore an alternative is to use
pandoc in combination with Aditya's filter module.

As I changed (and optimized) the original code, it will be clear that all errors
are mine. Eventually I might also adapt the parser code a bit more. When I ran into of
closure stack limitations I decided to flatten the code. The following implementation
seems to be a couple of hundred times faster than what I started with which is not that
bad.
]]--

-- todo: we have better quote and tag scanners in ctx
-- todo: provide an xhtml mapping

local type, next = type, next
local lower, upper, gsub, rep, gmatch, format, length = string.lower, string.upper, string.gsub, string.rep, string.gmatch, string.format, string.len
local concat = table.concat
local P, R, S, V, C, Ct, Cg, Cb, Cmt, Cc, Cf, Cs = lpeg.P, lpeg.R, lpeg.S, lpeg.V, lpeg.C, lpeg.Ct, lpeg.Cg, lpeg.Cb, lpeg.Cmt, lpeg.Cc, lpeg.Cf, lpeg.Cs
local lpegmatch = lpeg.match
local utfbyte = utf.byte

moduledata.markdown = moduledata.markdown or { }
local markdown      = moduledata.markdown

local nofruns, nofbytes, nofhtmlblobs = 0, 0, 0

local function process(func,t)
    if func then
        for i=1,#t do
            t[i] = func(t[i])
        end
        return t
    else
        return "ERROR: NO FUNCTION"
    end
end

local function traverse_tree(t,buffer,n)
    for k, v in next, t do
        if type(v) == "string" then
            n = n + 1
            buffer[n] = v
        else
            n = traverse_tree(v,buffer,n)
        end
    end
    return n
end

local function to_string(t)
    local buffer = { }
    traverse_tree(t, buffer, 0)
    return concat(buffer)
end

local function normalize_label(a)
    return upper(gsub(a, "[\n\r\t ]+", " "))
end

-- generic

local blocktags = table.tohash {
    "address", "blockquote" , "center", "dir", "div", "p", "pre",
    "li", "ol", "ul", "dl", "dd",
    "form", "fieldset", "isindex", "menu", "noframes", "frameset",
    "h1", "h2", "h3", "h4", "h5", "h6",
    "hr", "ht", "script", "noscript",
    "table", "tbody", "tfoot", "thead", "th", "td", "tr",
}

local asterisk               = P("*")
local dash                   = P("-")
local plus                   = P("+")
local underscore             = P("_")
local period                 = P(".")
local hash                   = P("#")
local ampersand              = P("&")
local backtick               = P("`")
local less                   = P("<")
local more                   = P(">")
local space                  = P(" ")
local squote                 = P("'")
local dquote                 = P('"')
local lparent                = P("(")
local rparent                = P(")")
local lbracket               = P("[")
local rbracket               = P("]")
local slash                  = P("/")
local equal                  = P("=")
local colon                  = P(":")
local semicolon              = P(";")

local digit                  = R("09")
local hexdigit               = R("09","af","AF")
local alphanumeric           = R("AZ","az","09")

local doubleasterisks        = P("**")
local doubleunderscores      = P("__")
local fourspaces             = P("    ")

local any                    = P(1)
local always                 = P("")

local tab                    = P("\t")
local spacechar              = S("\t ")
local newline                = P("\r")^-1 * P("\n")
local spaceornewline         = spacechar + newline
local nonspacechar           = any - spaceornewline
local optionalspace          = spacechar^0
local spaces                 = spacechar^1
local eof                    = - any
local nonindentspace         = space^-3
local blankline              = optionalspace * C(newline)
local blanklines             = blankline^0
local skipblanklines         = (optionalspace * newline)^0
local linechar               = P(1 - newline)
local indent                 = fourspaces + (nonindentspace * tab) / ""
local indentedline           = indent    * C(linechar^1 * (newline + eof))
local optionallyindentedline = indent^-1 * C(linechar^1 * (newline + eof))
local spnl                   = optionalspace * (newline * optionalspace)^-1
local specialchar            = S("*_`*&[]<!\\")
local normalchar             = any - (specialchar + spaceornewline)
local line                   = C((any - newline)^0 * newline)
                             + C(any^1 * eof)
local nonemptyline           = (any - newline)^1 * newline
local htmlattributevalue     = squote * C((any - (blankline + squote))^0) * squote
                             + dquote * C((any - (blankline + dquote))^0) * dquote
                             + (any - S("\t >"))^1 -- any - tab - space - more
local htmlattribute          = (alphanumeric + S("_-"))^1 * spnl * (equal * spnl * htmlattributevalue)^-1 * spnl
local htmlcomment            = P("<!--") * (any - P("-->"))^0 * P("-->")
local htmltag                = less * spnl * slash^-1 * alphanumeric^1 * spnl * htmlattribute^0 * slash^-1 * spnl * more

local function lineof(c)
    return (nonindentspace * (P(c) * optionalspace)^3 * newline * blankline^1)
end

local lineof_asterisks       = lineof(asterisk)
local lineof_dashes          = lineof(dash)
local lineof_underscores     = lineof(underscore)

local bullet                 = nonindentspace * (plus + (asterisk - lineof_asterisks) + (dash - lineof_dashes)) * spaces
local enumerator             = nonindentspace * digit^1 * period * spaces

local openticks              = Cg(backtick^1, "ticks")
local closeticks             = space^-1 * Cmt(C(backtick^1) * Cb("ticks"), function(s,i,a,b) return #a == #b and i end)
local intickschar            = (any - S(" \n\r`"))
                             + (newline * -blankline)
                             + (space - closeticks)
                             + (backtick^1 - closeticks)
local inticks                = openticks * space^-1 * C(intickschar^1) * closeticks

local blocktag               = Cmt(C(alphanumeric^1), function(s,i,a) return blocktags[lower(a)] and i, a end)

local openblocktag           = less * spnl * Cg(blocktag, "opentag") * spnl * htmlattribute^0 * more
local closeblocktag          = less * spnl * slash * Cmt(C(alphanumeric^1) * Cb("opentag"), function(s,i,a,b) return lower(a) == lower(b) and i end) * spnl * more
local selfclosingblocktag    = less * spnl * slash^-1 * blocktag * spnl * htmlattribute^0 * slash * spnl * more

-- yields a blank line unless we're at the beginning of the document -- can be made more efficient

interblockspace              = Cmt(blanklines, function(s,i) if i == 1 then return i, "" else return i, "\n" end end)

local nestedparser -- forward reference

-- helper stuff

local escaped = {
    ["{" ] = "",
    ["}" ] = "",
    ["$" ] = "",
    ["&" ] = "",
    ["#" ] = "",
    ["~" ] = "",
    ["|" ] = "",
    ["%%"] = "",
    ["\\"] = "",
}

for k, v in next, escaped do
    escaped[k] = "\\char" .. utfbyte(k) .. "{}"
end

local itemsignal = "\001"

local itemsplitter = lpeg.tsplitat(itemsignal)

-- what is lab.inline

local c_linebreak = "\\crlf\n" -- is this ok?
local c_entity    = "?"        -- todo, no clue of usage (use better entity handler)
local c_space     = " "

local function c_string(s)
    return (gsub(s,".",escaped))
end

local function c_paragraph(c)
    return { c, "\n" } -- { "\\startparagraph ", c, " \\stopparagraph\n" }
end

-- local function c_plain(c)
--     return c
-- end

-- itemize

local function listitem(c)
    return {
        "\\startitem\n",
        process(nestedparser, lpegmatch(itemsplitter,c) or c),
        "\n\\stopitem\n"
    }
end

local function c_tightbulletlist(c)
    return {
        "\\startmarkdownitemize[packed]\n",
        process(listitem, c),
        "\\stopmarkdownitemize\n"
    }
end

local function c_loosebulletlist(c)
    return {
        "\\startmarkdownitemize\n",
        process(listitem, c),
        "\\stopmarkdownitemize\n"
    }
end

local function c_tightorderedlist(c)
    return {
        "\\startmarkdownitemize[n,packed]\n",
        process(listitem, c),
        "\\stopmarkdownitemize\n"
    }
end

local function c_looseorderedlist(c)
    return {
        "\\startmarkdownitemize[n]\n",
        process(listitem, c),
        "\\stopmarkdownitemize\n"
    }
end

-- html

local showhtml = false

local function c_inline_html(c)
    nofhtmlblobs = nofhtmlblobs + 1
    if showhtml then
        local x = xml.convert(c)
        return {
            "\\type{",
            xml.tostring(x),
            "}"
        }
    else
        return ""
    end
end

local function c_display_html(c)
    nofhtmlblobs = nofhtmlblobs + 1
    if showhtml then
        local x = xml.convert(c)
        return {
            "\\starttyping\n",
            xml.tostring(x),
            "\\stoptyping\n"
        }
    else
        return ""
    end
end

-- highlight

local function c_emphasis(c)
     return {
        "\\markdownemphasis{",
        c,
        "}"
    }
end

local function c_strong(c)
    return {
        "\\markdownstrong{",
        c,
        "}"
    }
end

-- blockquote

local function c_blockquote(c)
    return {
        "\\startmarkdownblockquote\n",
        nestedparser(concat(c,"\n")),
        "\\stopmarkdownblockquote\n"
    }
end

-- verbatim

local function c_verbatim(c)
    return {
        "\\startmarkdowntyping\n",
        concat(c),
        "\\stopmarkdowntyping\n"
    }
end

local function c_code(c)
     return {
        "\\markdowntype{",
        c,
        "}"
    }
end

-- sectioning (only relative, so no # -> ###)

local levels  = { "", "", "", "", "", "" }

local function c_start_document()
    levels = { "", "", "", "", "", "" }
    return ""
end

local function c_stop_document()
    return concat(levels,"\n") or ""
end

local function c_heading(level,c)
    if level > #levels then
        level = #levels
    end
    local finish = concat(levels,"\n",level) or ""
    for i=level+1,#levels do
        levels[i] = ""
    end
    levels[level] = "\\stopstructurelevel"
    return {
        finish,
        "\\startstructurelevel[markdown][title={",
        c,
        "}]\n"
    }
end

--

local function c_hrule()
    return "\\markdownrule\n"
end

local function c_link(lab,src,tit)
    return {
        "\\goto{",
        lab.inlines,
        "}[url(",
        src,
        ")]"
    }
end

local function c_image(lab,src,tit)
    return {
        "\\externalfigure[",
        src,
        "]"
    }
end

local function c_email_link(addr)
    return c_link(addr,"mailto:"..addr)
end

-- Instead of local lpeg definitions we defne the nested parser first (this trick
-- could be backported to the original code if needed).

local references = { }

local function f_reference_set(lab,src,tit)
    return {
        key    = normalize_label(lab.raw),
        label  = lab.inlines,
        source = src,
        title  = tit
    }
end

local function f_reference_link_double(s,i,l)
    local key = normalize_label(l.raw)
    if references[key] then
        return i, references[key].source, references[key].title
    else
        return false
    end
end

local function f_reference_link_single(s,i,l)
    local key = normalize_label(l.raw)
    if references[key] then
        return i, l, references[key].source, references[key].title
    else
        return false
    end
end

local function f_label_collect(a)
    return { "[", a.inlines, "]" }
end

local function f_label(a,b)
    return {
        raw     = a,
        inlines = b
    }
end

local function f_pack_list(a)
    return itemsignal .. concat(a)
end

local function f_reference(ref)
    references[ref.key] = ref
end

local function f_append(a,b)
    return a .. b
end

local function f_level_one_heading(c)
    return c_heading(1,c)
end

local function f_level_two_heading(c)
    return c_heading(2,c)
end

local function f_link(a)
    return c_link({ inlines = c_string(a) }, a, "")
end

local syntax

nestedparser = function(inp) return to_string(lpegmatch(syntax,inp)) end

syntax = { "Document",  -- still rather close to the original but reformatted etc etc

    Document              = #(Cmt(V("References"), function(s,i,a) return i end)) -- what does this do
                          * Ct((interblockspace *  V("Block"))^0)
                          * blanklines * eof,

    References            = (V("Reference") / f_reference + (nonemptyline^1 * blankline^1) + line)^0
                          * blanklines * eof,

    Block                 = V("Blockquote")
                          + V("Verbatim")
                          + V("Reference") / { }
                          + V("HorizontalRule")
                          + V("Heading")
                          + V("OrderedList")
                          + V("BulletList")
                          + V("HtmlBlock")
                          + V("Para")
                          + V("Plain"),

    Heading               = V("AtxHeading")
                          + V("SetextHeading"),

    AtxStart              = C(hash * hash^-5) / length,

    AtxInline             = V("Inline") - V("AtxEnd"),

    AtxEnd                = optionalspace * hash^0 * optionalspace * newline * blanklines,

    AtxHeading            = V("AtxStart") * optionalspace * Ct(V("AtxInline")^1) * V("AtxEnd") / c_heading,

    SetextHeading         = V("SetextHeading1")
                          + V("SetextHeading2"),

    SetextHeading1        = Ct((V("Inline") - V("Endline"))^1) * newline * equal^3 * newline * blanklines / f_level_one_heading,
    SetextHeading2        = Ct((V("Inline") - V("Endline"))^1) * newline * dash ^3 * newline * blanklines / f_level_two_heading,

    BulletList            = V("BulletListTight")
                          + V("BulletListLoose"),

    BulletListTight       = Ct((bullet * V("ListItem"))^1) * blanklines * -bullet / c_tightbulletlist,

    BulletListLoose       = Ct((bullet * V("ListItem") * C(blanklines) / f_append)^1) / c_loosebulletlist, -- just Cs

    OrderedList           = V("OrderedListTight") + V("OrderedListLoose"),

    OrderedListTight      = Ct((enumerator * V("ListItem"))^1) * blanklines * -enumerator / c_tightorderedlist,

    OrderedListLoose      = Ct((enumerator * V("ListItem") * C(blanklines) / f_append)^1) / c_looseorderedlist, -- just Cs

    ListItem              = Ct(V("ListBlock") * (V("NestedList") + V("ListContinuationBlock")^0)) / concat,

    ListBlock             = Ct(line * V("ListBlockLine")^0) / concat,

    ListContinuationBlock = blanklines * indent * V("ListBlock"),

    NestedList            = Ct((optionallyindentedline - (bullet + enumerator))^1) / f_pack_list,

    ListBlockLine         = -blankline * -(indent^-1 * (bullet + enumerator)) * optionallyindentedline,

    InBlockTags           = openblocktag * (V("HtmlBlock") + (any - closeblocktag))^0 * closeblocktag,

    HtmlBlock             = C(V("InBlockTags") + selfclosingblocktag + htmlcomment) * blankline^1 / c_display_html,

    BlockquoteLine        = ((nonindentspace * more * space^-1 * C(linechar^0) * newline)^1 * ((C(linechar^1) - blankline) * newline)^0 * C(blankline)^0 )^1,

    Blockquote            = Ct((V("BlockquoteLine"))^1) / c_blockquote,

    VerbatimChunk         = blanklines * (indentedline - blankline)^1,

    Verbatim              = Ct(V("VerbatimChunk")^1) * (blankline^1 + eof) / c_verbatim,

    Label                 = lbracket * Cf(Cc("") * #((C(V("Label") + V("Inline")) - rbracket)^1), f_append) *
                            Ct((V("Label") / f_label_collect + V("Inline") - rbracket)^1) * rbracket / f_label,

    RefTitle              = dquote  * C((any - (dquote ^-1 * blankline))^0) * dquote  +
                            squote  * C((any - (squote ^-1 * blankline))^0) * squote  +
                            lparent * C((any - (rparent    * blankline))^0) * rparent +
                            Cc(""),

    RefSrc                = C(nonspacechar^1),

    Reference             = nonindentspace * V("Label") * colon * spnl * V("RefSrc") * spnl * V("RefTitle") * blanklines / f_reference_set,

    HorizontalRule        = (lineof_asterisks + lineof_dashes + lineof_underscores) / c_hrule,

    Para                  = nonindentspace * Ct(V("Inline")^1) * newline * blankline^1 / c_paragraph,

    Plain                 = Ct(V("Inline")^1), -- / c_plain,

    Inline                = V("Str")
                          + V("Endline")
                          + V("UlOrStarLine")
                          + V("Space")
                          + V("Strong")
                          + V("Emphasis")
                          + V("Image")
                          + V("Link")
                          + V("Code")
                          + V("RawHtml")
                          + V("Entity")
                          + V("EscapedChar")
                          + V("Symbol"),

    RawHtml               = C(htmlcomment + htmltag) / c_inline_html,

    EscapedChar           = P("\\") * C(P(1 - newline)) / c_string,

    -- we will use the regular entity handler

    Entity                = V("HexEntity")
                          + V("DecEntity")
                          + V("CharEntity") / c_entity,

    HexEntity             = C(ampersand * hash * S("Xx") * hexdigit^1 * semicolon),
    DecEntity             = C(ampersand * hash * digit^1 * semicolon),
    CharEntity            = C(ampersand * alphanumeric^1 * semicolon),

    --

    Endline               = V("LineBreak")
                          + V("TerminalEndline")
                          + V("NormalEndline"),

    NormalEndline         = optionalspace * newline * -(
                                blankline
                              + more
                              + V("AtxStart")
                              + ( line * (P("===")^3 + P("---")^3) * newline )
                            ) / c_space,

    TerminalEndline       = optionalspace * newline * eof / "",

    LineBreak             = P("  ") * V("NormalEndline") / c_linebreak,

    Code                  = inticks / c_code,

    -- This keeps the parser from getting bogged down on long strings of '*' or '_'
    UlOrStarLine          = asterisk^4
                          + underscore^4
                          + (spaces * S("*_")^1 * #spaces) / c_string,

    Emphasis              = V("EmphasisStar")
                          + V("EmphasisUl"),

    EmphasisStar          = asterisk   * -spaceornewline * Ct((V("Inline") - asterisk  )^1) * asterisk   / c_emphasis,
    EmphasisUl            = underscore * -spaceornewline * Ct((V("Inline") - underscore)^1) * underscore / c_emphasis,

    Strong                = V("StrongStar")
                          + V("StrongUl"),

    StrongStar            = doubleasterisks   * -spaceornewline * Ct((V("Inline") - doubleasterisks  )^1) * doubleasterisks   / c_strong,
    StrongUl              = doubleunderscores * -spaceornewline * Ct((V("Inline") - doubleunderscores)^1) * doubleunderscores / c_strong,

    Image                 = P("!") * (V("ExplicitLink") + V("ReferenceLink")) / c_image,

    Link                  = V("ExplicitLink") / c_link
                          + V("ReferenceLink") / c_link
                          + V("AutoLinkUrl")
                          + V("AutoLinkEmail"),

    ReferenceLink         = V("ReferenceLinkDouble")
                          + V("ReferenceLinkSingle"),

    ReferenceLinkDouble   = V("Label") * spnl * Cmt(V("Label"), f_reference_link_double),

    ReferenceLinkSingle   = Cmt(V("Label"), f_reference_link_single) * (spnl * P("[]"))^-1,

    AutoLinkUrl           = less * C(alphanumeric^1 * P("://") * (any - (newline + more))^1) * more / f_link,

    AutoLinkEmail         = less * C((alphanumeric + S("-_+"))^1 * P("@") * (any - (newline + more))^1) * more / c_email_link,

    BasicSource           = (nonspacechar - S("()>"))^1 + (lparent * V("Source") * rparent)^1 + always,

    AngleSource           = less * C(V("BasicSource")) * more,

    Source                = V("AngleSource")
                          + C(V("BasicSource")),

    LinkTitle             = dquote * C((any - (dquote * optionalspace * rparent))^0) * dquote +
                            squote * C((any - (squote * optionalspace * rparent))^0) * squote +
                            Cc(""),

    ExplicitLink          = V("Label") * spnl * lparent * optionalspace * V("Source") * spnl * V("LinkTitle") * optionalspace * rparent,

    Str                   = normalchar^1 / c_string,
    Space                 = spacechar^1  / c_space,
    Symbol                = specialchar  / c_string,
}

local function convert(str)
    nofruns = nofruns + 1
    nofbytes = nofbytes + #str
    statistics.starttiming(markdown)
    local result = c_start_document() .. nestedparser(str) .. c_stop_document()
    statistics.stoptiming(markdown)
    return result
end

markdown.convert = convert

function markdown.typesetstring(data)
    if data and data ~= "" then
        local result = convert(data)
        context.viafile(result)
    end
end

function markdown.typesetbuffer(name)
    markdown.typesetstring(buffers.getcontent(name))
end

function markdown.typesetfile(name)
    local fullname = resolvers.findctxfile(name)
    if fullname and fullname ~= "" then
        markdown.typesetstring(io.loaddata(fullname))
    end
end

statistics.register("markdown",function()
    if nofruns > 0 then
        return format("%s bytes converted, %s runs, %s html blobs, %s seconds used",
            nofbytes, nofruns, nofhtmlblobs, statistics.elapsedtime(markdown))
    end
end)

-- test

--~ context.starttext()
--~     moduledata.markdown.convert(str)
--~ context.stoptext()

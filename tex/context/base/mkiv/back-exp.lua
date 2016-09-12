if not modules then modules = { } end modules ['back-exp'] = {
    version   = 1.001,
    comment   = "companion to back-exp.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- Todo: share properties more with tagged pdf (or thge reverse)

-- Because we run into the 200 local limit we quite some do .. end wrappers .. not always
-- that nice but it has to be.

-- Experiments demonstrated that mapping to <div> and classes is messy because we have to
-- package attributes (some 30) into one set of (space seperatated but prefixed classes)
-- which only makes things worse .. so if you want something else, use xslt to get there.

-- language       -> only mainlanguage, local languages should happen through start/stoplanguage
-- tocs/registers -> maybe add a stripper (i.e. just don't flush entries in final tree)
-- footnotes      -> css 3
-- bodyfont       -> in styles.css

-- Because we need to look ahead we now always build a tree (this was optional in
-- the beginning). The extra overhead in the frontend is neglectable.
--
-- We can optimize the code ... currently the overhead is some 10% for xml + html so
-- there is no hurry.

-- todo: move critital formatters out of functions
-- todo: delay loading (apart from basic tag stuff)

-- problem : too many local variables

-- check setting __i__

local next, type, tonumber = next, type, tonumber
local sub, gsub = string.sub, string.gsub
local validstring = string.valid
local lpegmatch = lpeg.match
local utfchar, utfvalues = utf.char, utf.values
local concat, insert, remove, merge, sort = table.concat, table.insert, table.remove, table.merge, table.sort
local sortedhash = table.sortedhash
local formatters = string.formatters
local todimen = number.todimen
local replacetemplate = utilities.templates.replace

local trace_export  = false  trackers.register  ("export.trace",         function(v) trace_export  = v end)
local trace_spacing = false  trackers.register  ("export.trace.spacing", function(v) trace_spacing = v end)

local less_state    = false  directives.register("export.lessstate",     function(v) less_state    = v end)
local show_comment  = true   directives.register("export.comment",       function(v) show_comment  = v end)

show_comment = false -- figure out why break comment

-- maybe we will also support these:
--
-- local css_hyphens       = false  directives.register("export.css.hyphens",      function(v) css_hyphens      = v end)
-- local css_textalign     = false  directives.register("export.css.textalign",    function(v) css_textalign    = v end)
-- local css_bodyfontsize  = false  directives.register("export.css.bodyfontsize", function(v) css_bodyfontsize = v end)
-- local css_textwidth     = false  directives.register("export.css.textwidth",    function(v) css_textwidth    = v end)

local report_export     = logs.reporter("backend","export")

local nodes             = nodes
local attributes        = attributes

local variables         = interfaces.variables
local v_yes             = variables.yes
local v_no              = variables.no
local v_hidden          = variables.hidden

local implement         = interfaces.implement

local included          = backends.included

local settings_to_array = utilities.parsers.settings_to_array

local setmetatableindex = table.setmetatableindex
local tasks             = nodes.tasks
local fontchar          = fonts.hashes.characters
local fontquads         = fonts.hashes.quads
local languagenames     = languages.numbers

local nodecodes         = nodes.nodecodes
local skipcodes         = nodes.skipcodes
local listcodes         = nodes.listcodes

local hlist_code        = nodecodes.hlist
local vlist_code        = nodecodes.vlist
local glyph_code        = nodecodes.glyph
local glue_code         = nodecodes.glue
local kern_code         = nodecodes.kern
local disc_code         = nodecodes.disc

local userskip_code     = skipcodes.userskip
local rightskip_code    = skipcodes.rightskip
local parfillskip_code  = skipcodes.parfillskip
local spaceskip_code    = skipcodes.spaceskip
local xspaceskip_code   = skipcodes.xspaceskip

local line_code         = listcodes.line

local texgetcount       = tex.getcount

local privateattribute  = attributes.private
local a_characters      = privateattribute('characters')
local a_exportstatus    = privateattribute('exportstatus')
local a_tagged          = privateattribute('tagged')
local a_taggedpar       = privateattribute("taggedpar")
local a_image           = privateattribute('image')
local a_reference       = privateattribute('reference')
local a_textblock       = privateattribute("textblock")

local nuts              = nodes.nuts
local tonut             = nuts.tonut

local getnext           = nuts.getnext
local getsubtype        = nuts.getsubtype
local getfont           = nuts.getfont
local getdisc           = nuts.getdisc
local getlist           = nuts.getlist
local getid             = nuts.getid
local getfield          = nuts.getfield
local getattr           = nuts.getattr
local setattr           = nuts.setattr
local isglyph           = nuts.isglyph

local traverse_id       = nuts.traverse_id
local traverse_nodes    = nuts.traverse

local references        = structures.references
local structurestags    = structures.tags
local taglist           = structurestags.taglist
local specifications    = structurestags.specifications
local properties        = structurestags.properties
local locatedtag        = structurestags.locatedtag

structurestags.usewithcare = { }

local starttiming       = statistics.starttiming
local stoptiming        = statistics.stoptiming

local characterdata     = characters.data
local overloads         = fonts.mappings.overloads

-- todo: more locals (and optimize)

local exportversion     = "0.34"
local mathmlns          = "http://www.w3.org/1998/Math/MathML"
local contextns         = "http://www.contextgarden.net/context/export" -- whatever suits
local cssnamespaceurl   = "@namespace context url('%namespace%') ;"
local cssnamespace      = "context|"
----- cssnamespacenop   = "/* no namespace */"

local usecssnamespace   = false

local nofcurrentcontent = 0 -- so we don't free (less garbage collection)
local currentcontent    = { }
local currentnesting    = nil
local currentattribute  = nil
local last              = nil
local currentparagraph  = nil

local noftextblocks     = 0

local hyphencode        = 0xAD
local hyphen            = utfchar(0xAD) -- todo: also emdash etc
local tagsplitter       = structurestags.patterns.splitter
----- colonsplitter     = lpeg.splitat(":")
----- dashsplitter      = lpeg.splitat("-")
local threshold         = 65536
local indexing          = false
local keephyphens       = false
local exportproperties  = false

local finetuning        = { }

local treestack         = { }
local nesting           = { }
local currentdepth      = 0

local wrapups           = { }

local tree              = { data = { }, fulltag == "root" } -- root
local treeroot          = tree
local treehash          = { }
local extras            = { }
local checks            = { }
local finalizers        = { }
local nofbreaks         = 0
local used              = { }
local exporting         = false
local restart           = false
local specialspaces     = { [0x20] = " "  }               -- for conversion
local somespace         = { [0x20] = true, [" "] = true } -- for testing
local entities          = { ["&"] = "&amp;", [">"] = "&gt;", ["<"] = "&lt;" }
local attribentities    = { ["&"] = "&amp;", [">"] = "&gt;", ["<"] = "&lt;", ['"'] = "quot;" }

local p_entity          = lpeg.replacer(entities) -- was: entityremapper = utf.remapper(entities)
local p_attribute       = lpeg.replacer(attribentities)
local p_stripper        = lpeg.patterns.stripper
local p_escaped         = lpeg.patterns.xml.escaped

local f_tagid           = formatters["%s-%04i"]

-- local alignmapping = {
--     flushright = "right",
--     middle     = "center",
--     flushleft  = "left",
-- }

local defaultnature = "mixed" -- "inline"

setmetatableindex(used, function(t,k)
    if k then
        local v = { }
        t[k] = v
        return v
    end
end)

local f_entity    = formatters["&#x%X;"]
local f_attribute = formatters[" %s=%q"]
local f_property  = formatters[" %s%s=%q"]

setmetatableindex(specialspaces, function(t,k)
    local v = utfchar(k)
    t[k] = v
    entities[v] = f_entity(k)
    somespace[k] = true
    somespace[v] = true
    return v
end)


local namespaced = {
    -- filled on
}

local namespaces = {
    msubsup      = "m",
    msub         = "m",
    msup         = "m",
    mn           = "m",
    mi           = "m",
    ms           = "m",
    mo           = "m",
    mtext        = "m",
    mrow         = "m",
    mfrac        = "m",
    mroot        = "m",
    msqrt        = "m",
    munderover   = "m",
    munder       = "m",
    mover        = "m",
    merror       = "m",
    math         = "m",
    mrow         = "m",
    mtable       = "m",
    mtr          = "m",
    mtd          = "m",
    mfenced      = "m",
    maction      = "m",
    mspace       = "m",
    -- only when testing
    mstacker     = "m",
    mstackertop  = "m",
    mstackermid  = "m",
    mstackerbot  = "m",
}

setmetatableindex(namespaced, function(t,k)
    if k then
        local namespace = namespaces[k]
        local v = namespace and namespace .. ":" .. k or k
        t[k] = v
        return v
    end
end)

local function attribute(key,value)
    if value and value ~= "" then
        return f_attribute(key,lpegmatch(p_attribute,value))
    else
        return ""
    end
end

local function setattribute(di,key,value,escaped)
    if value and value ~= "" then
        local a = di.attributes
        if escaped then
            value = lpegmatch(p_escaped,value)
        end
        if not a then
            di.attributes = { [key] = value }
        else
            a[key] = value
        end
    end
end

local listdata = { } -- this has to be done otherwise: each element can just point back to ...

function wrapups.hashlistdata()
    local c = structures.lists.collected
    for i=1,#c do
        local ci = c[i]
        local tag = ci.references.tag
        if tag then
            local m = ci.metadata
            local t = m.kind .. ">" .. tag -- todo: use internal (see strc-lst.lua where it's set)
            listdata[t] = ci
        end
    end
end

function structurestags.setattributehash(attr,key,value) -- public hash
    local specification = taglist[attr]
    if specification then
        specification[key] = value
    else
        -- some kind of error
    end
end

local usedstyles = { }

local namespacetemplate = [[
/* %what% for file %filename% */

%cssnamespaceurl%
]]

do

    -- experiment: styles and images
    --
    -- officially we should convert to bp but we round anyway

    -- /* padding      : ; */
    -- /* text-justify : inter-word ; */
    -- /* text-align : justify ; */

local documenttemplate = [[
document, %namespace%div.document {
    font-size  : %size% !important ;
    max-width  : %width% !important ;
    text-width : %align% !important ;
    hyphens    : %hyphens% !important ;
}
]]

local styletemplate = [[
%element%[detail="%detail%"], %namespace%div.%element%.%detail% {
    display      : inline ;
    font-style   : %style% ;
    font-variant : %variant% ;
    font-weight  : %weight% ;
    font-family  : %family% ;
    color        : %color% ;
}]]

    local numbertoallign = {
        [0] = "justify", ["0"] = "justify", [variables.normal    ] = "justify",
        [1] = "right",   ["1"] = "right",   [variables.flushright] = "right",
        [2] = "center",  ["2"] = "center",  [variables.middle    ] = "center",
        [3] = "left",    ["3"] = "left",    [variables.flushleft ] = "left",
    }

    function wrapups.allusedstyles(basename)
        local result = { replacetemplate(namespacetemplate, {
            what            = "styles",
            filename        = basename,
            namespace       = contextns,
         -- cssnamespaceurl = usecssnamespace and cssnamespaceurl or cssnamespacenop,
            cssnamespaceurl = cssnamespaceurl,
        }) }
        --
        local bodyfont = finetuning.bodyfont
        local width    = finetuning.width
        local hyphen   = finetuning.hyphen
        local align    = finetuning.align
        --
        if type(bodyfont) == "number" then
            bodyfont = todimen(bodyfont)
        else
            bodyfont = "12pt"
        end
        if type(width) == "number" then
            width = todimen(width) or "50em"
        else
            width = "50em"
        end
        if hyphen == v_yes then
            hyphen = "manual"
        else
            hyphen = "inherited"
        end
        if align then
            align = numbertoallign[align]
        end
        if not align then
            align = hyphen and "justify" or "inherited"
        end
        --
        result[#result+1] = replacetemplate(documenttemplate,{
            size    = bodyfont,
            width   = width,
            align   = align,
            hyphens = hyphen
        })
        --
        local colorspecification = xml.css.colorspecification
        local fontspecification = xml.css.fontspecification
        for element, details in sortedhash(usedstyles) do
            for detail, data in sortedhash(details) do
                local s = fontspecification(data.style)
                local c = colorspecification(data.color)
                detail = gsub(detail,"[^A-Za-z0-9]+","-")
                result[#result+1] = replacetemplate(styletemplate,{
                    namespace = usecssnamespace and cssnamespace or "",
                    element   = element,
                    detail    = detail,
                    style     = s.style   or "inherit",
                    variant   = s.variant or "inherit",
                    weight    = s.weight  or "inherit",
                    family    = s.family  or "inherit",
                    color     = c         or "inherit",
                })
            end
        end
        return concat(result,"\n\n")
    end

end

local usedimages = { }

do

local imagetemplate = [[
%element%[id="%id%"], %namespace%div.%element%[id="%id%"] {
    display           : block ;
    background-image  : url('%url%') ;
    background-size   : 100%% auto ;
    background-repeat : no-repeat ;
    width             : %width% ;
    height            : %height% ;
}]]

    local f_svgname = formatters["%s.svg"]
    local f_svgpage = formatters["%s-page-%s.svg"]
    local collected = { }

    local function usedname(name,page)
        if file.suffix(name) == "pdf" then
            -- temp hack .. we will have a remapper
            if page and page > 1 then
                name = f_svgpage(file.nameonly(name),page)
            else
                name = f_svgname(file.nameonly(name))
            end
        end
        local scheme = url.hasscheme(name)
        if not scheme or scheme == "file" then
            -- or can we just use the name ?
            return file.join("../images",file.basename(url.filename(name)))
        else
            return name
        end
    end

    function wrapups.allusedimages(basename)
        local result = { replacetemplate(namespacetemplate, {
            what            = "images",
            filename        = basename,
            namespace       = contextns,
         -- cssnamespaceurl = usecssnamespace and cssnamespaceurl or "",
            cssnamespaceurl = cssnamespaceurl,
        }) }
        for element, details in sortedhash(usedimages) do
            for detail, data in sortedhash(details) do
                local name = data.name
                local page = tonumber(data.page) or 1
                local spec = {
                    element   = element,
                    id        = data.id,
                    name      = name,
                    page      = page,
                    url       = usedname(name,page),
                    width     = data.width,
                    height    = data.height,
                    used      = data.used,
                    namespace = usecssnamespace and cssnamespace or "",
                }
                result[#result+1] = replacetemplate(imagetemplate,spec)
                collected[detail] = spec
            end
        end
        return concat(result,"\n\n")
    end

    function wrapups.uniqueusedimages() -- todo: combine these two
        return collected
    end

end

--

properties.vspace = { export = "break",     nature = "display" }
----------------- = { export = "pagebreak", nature = "display" }

local function makebreaklist(list)
    nofbreaks = nofbreaks + 1
    local t = { }
    local l = list and list.taglist
    if l then
        for i=1,#list do
            t[i] = l[i]
        end
    end
    t[#t+1] = "break>" .. nofbreaks -- maybe no number or 0
    return { taglist = t }
end

local breakattributes = {
    type = "collapse"
}

local function makebreaknode(attributes) -- maybe no fulltag
    nofbreaks = nofbreaks + 1
    return {
        tg         = "break",
        fulltag    = "break>" .. nofbreaks,
        n          = nofbreaks,
        element    = "break",
        nature     = "display",
        attributes = attributes or nil,
     -- data       = { }, -- not needed
     -- attribute  = 0, -- not needed
     -- parnumber  = 0,
    }
end

local function ignorebreaks(di,element,n,fulltag)
    local data = di.data
    for i=1,#data do
        local d = data[i]
        if d.content == " " then
            d.content = ""
        end
    end
end

local function ignorespaces(di,element,n,fulltag)
    local data = di.data
    for i=1,#data do
        local d = data[i]
        local c = d.content
        if type(c) == "string" then
            d.content = lpegmatch(p_stripper,c)
        end
    end
end

do

    local fields = { "title", "subtitle", "author", "keywords" }

    local function checkdocument(root)
        local data = root.data
        if data then
            for i=1,#data do
                local di = data[i]
                local tg = di.tg
                if tg == "noexport" then
                    local s = specifications[di.fulltag]
                    local u = s and s.userdata
                    if u then
                        local comment = u.comment
                        if comment then
                            di.element = "comment"
                            di.data = { { content = comment } }
                            u.comment = nil
                        else
                            data[i] = false
                        end
                    else
                        data[i] = false
                    end
                elseif di.content then
                    -- okay
                elseif tg == "ignore" then
                    di.element = ""
                    checkdocument(di)
                else
                    checkdocument(di) -- new, else no noexport handling
                end
            end
        end
    end

    function extras.document(di,element,n,fulltag)
        setattribute(di,"language",languagenames[texgetcount("mainlanguagenumber")])
        if not less_state then
            setattribute(di,"file",tex.jobname)
            if included.date then
                setattribute(di,"date",backends.timestamp())
            end
            setattribute(di,"context",environment.version)
            setattribute(di,"version",exportversion)
            setattribute(di,"xmlns:m",mathmlns)
            local identity = interactions.general.getidentity()
            for i=1,#fields do
                local key   = fields[i]
                local value = identity[key]
                if value and value ~= "" then
                    setattribute(di,key,value)
                end
            end
        end
        checkdocument(di)
    end

end

do

    local symbols = { }

    function structurestags.settagdelimitedsymbol(symbol)
        symbols[locatedtag("delimitedsymbol")] = {
            symbol = symbol,
        }
    end

    function extras.delimitedsymbol(di,element,n,fulltag)
        local hash = symbols[fulltag]
        if hash then
            setattribute(di,"symbol",hash.symbol or nil)
        end
    end

end

do

    local symbols = { }

    function structurestags.settagsubsentencesymbol(symbol)
        symbols[locatedtag("subsentencesymbol")] = {
            symbol = symbol,
        }
    end

    function extras.subsentencesymbol(di,element,n,fulltag)
        local hash = symbols[fulltag]
        if hash then
            setattribute(di,"symbol",hash.symbol or nil)
        end
    end

end

do

    local itemgroups = { }

    function structurestags.setitemgroup(packed,level,symbol)
        itemgroups[locatedtag("itemgroup")] = {
            packed = packed,
            symbol = symbol,
            level  = level,
        }
    end

    function structurestags.setitem(kind)
        itemgroups[locatedtag("item")] = {
            kind = kind,
        }
    end

    function extras.itemgroup(di,element,n,fulltag)
        local hash = itemgroups[fulltag]
        if hash then
            setattribute(di,"packed",hash.packed and "yes" or nil)
            setattribute(di,"symbol",hash.symbol)
            setattribute(di,"level",hash.level)
        end
    end

    function extras.item(di,element,n,fulltag)
        local hash = itemgroups[fulltag]
        if hash then
            local kind = hash.kind
            if kind and kind ~= "" then
                setattribute(di,"kind",kind)
            end
        end
    end

end

do

    local synonyms = { }
    local sortings = { }

    function structurestags.setsynonym(tag)
        synonyms[locatedtag("synonym")] = tag
    end

    function extras.synonym(di,element,n,fulltag)
        local tag = synonyms[fulltag]
        if tag then
            setattribute(di,"tag",tag)
        end
    end

    function structurestags.setsorting(tag)
        sortings[locatedtag("sorting")] = tag
    end

    function extras.sorting(di,element,n,fulltag)
        local tag = sortings[fulltag]
        if tag then
            setattribute(di,"tag",tag)
        end
    end

end

do

    local highlight      = { }
    usedstyles.highlight = highlight

    local strippedtag    = structurestags.strip -- we assume global styles

    function structurestags.sethighlight(style,color)
        highlight[strippedtag(locatedtag("highlight"))] = {
            style = style, -- xml.css.fontspecification(style),
            color = color, -- xml.css.colorspec(color),
        }
    end

end

do

    local descriptions = { }
    local symbols      = { }
    local linked       = { }

    -- we could move the notation itself to the first reference (can be an option)

    function structurestags.setnotation(tag,n) -- needs checking (is tag needed)
        -- we can also use the internals hash or list
        local nd = structures.notes.get(tag,n)
        if nd then
            local references = nd.references
            descriptions[references and references.internal] = locatedtag("description")
        end
    end

    function structurestags.setnotationsymbol(tag,n) -- needs checking (is tag needed)
        local nd = structures.notes.get(tag,n) -- todo: use listdata instead
        if nd then
            local references = nd.references
            symbols[references and references.internal] = locatedtag("descriptionsymbol")
        end
    end

    function finalizers.descriptions(tree)
        local n = 0
        for id, tag in sortedhash(descriptions) do
            local sym = symbols[id]
            if sym then
                n = n + 1
                linked[tag] = n
                linked[sym] = n
            end
        end
    end

    function extras.description(di,element,n,fulltag)
        local id = linked[fulltag]
        if id then
            setattribute(di,"insert",id)
        end
    end

    function extras.descriptionsymbol(di,element,n,fulltag)
        local id = linked[fulltag]
        if id then
            setattribute(di,"insert",id)
        end
    end

end

-- -- todo: ignore breaks
--
-- function extras.verbatimline(di,element,n,fulltag)
--     inspect(di)
-- end

do

    local f_id       = formatters["%s-%s"]
    local image      = { }
    usedimages.image = image

    structurestags.usewithcare.images = image

    function structurestags.setfigure(name,used,page,width,height,label)
        local fulltag = locatedtag("image")
        local spec    = specifications[fulltag]
        local page    = tonumber(page)
        image[fulltag] = {
            id     = f_id(spec.tagname,spec.tagindex),
            name   = name,
            used   = used,
            page   = page and page > 1 and page or nil,
            width  = todimen(width, "cm","%0.3F%s"),
            height = todimen(height,"cm","%0.3F%s"),
            label  = label,
        }
    end

    function extras.image(di,element,n,fulltag)
        local data = image[fulltag]
        if data then
            setattribute(di,"name",data.name)
            setattribute(di,"page",data.page)
            setattribute(di,"id",data.id)
            setattribute(di,"width",data.width)
            setattribute(di,"height",data.height)
            setattribute(di,"label",data.height)
        end
    end

end

do

    local combinations = { }

    function structurestags.setcombination(nx,ny)
        combinations[locatedtag("combination")] = {
            nx = nx,
            ny = ny,
        }
    end

    function extras.combination(di,element,n,fulltag)
        local data = combinations[fulltag]
        if data then
            setattribute(di,"nx",data.nx)
            setattribute(di,"ny",data.ny)
        end
    end

end

-- quite some code deals with exporting references  --

-- links:
--
-- url      :
-- file     :
-- internal : automatic location
-- location : named reference

-- references:
--
-- implicit : automatic reference
-- explicit : named reference

local evaluators = { }
local specials   = { }
local explicits  = { }

evaluators.inner = function(di,var)
    local inner = var.inner
    if inner then
        setattribute(di,"location",inner,true)
    end
end

evaluators.outer = function(di,var)
    local file, url = references.checkedfileorurl(var.outer,var.outer)
    if url then
        setattribute(di,"url",url,true)
    elseif file then
        setattribute(di,"file",file,true)
    end
end

evaluators["outer with inner"] = function(di,var)
    local file = references.checkedfile(var.f)
    if file then
        setattribute(di,"file",file,true)
    end
    local inner = var.inner
    if inner then
        setattribute(di,"inner",inner,true)
    end
end

evaluators.special = function(di,var)
    local handler = specials[var.special]
    if handler then
        handler(di,var)
    end
end

local referencehash = { }

do

    evaluators["special outer with operation"]     = evaluators.special
    evaluators["special operation"]                = evaluators.special
    evaluators["special operation with arguments"] = evaluators.special

    function specials.url(di,var)
        local url = references.checkedurl(var.operation)
        if url and url ~= "" then
            setattribute(di,"url",url,true)
        end
    end

    function specials.file(di,var)
        local file = references.checkedfile(var.operation)
        if file and file ~= "" then
            setattribute(di,"file",file,true)
        end
    end

    function specials.fileorurl(di,var)
        local file, url = references.checkedfileorurl(var.operation,var.operation)
        if url and url ~= "" then
            setattribute(di,"url",url,true)
        elseif file and file ~= "" then
            setattribute(di,"file",file,true)
        end
    end

    function specials.internal(di,var)
        local internal = references.checkedurl(var.operation)
        if internal then
            setattribute(di,"location",internal)
        end
    end

    local function adddestination(di,references) -- todo: specials -> exporters and then concat
        if references then
            local reference = references.reference
            if reference and reference ~= "" then
                local prefix = references.prefix
                if prefix and prefix ~= "" then
                    setattribute(di,"prefix",prefix,true)
                end
                setattribute(di,"destination",reference,true)
                for i=1,#references do
                    local r = references[i]
                    local e = evaluators[r.kind]
                    if e then
                        e(di,r)
                    end
                end
            end
        end
    end

    function extras.addimplicit(di,references)
        if references then
            local internal = references.internal
            if internal then
                setattribute(di,"implicit",internal)
            end
        end
    end

    function extras.addinternal(di,references)
        if references then
            local internal = references.internal
            if internal then
                setattribute(di,"internal",internal)
            end
        end
    end

    local p_firstpart = lpeg.Cs((1-lpeg.P(","))^0)

    local function addreference(di,references)
        if references then
            local reference = references.reference
            if reference and reference ~= "" then
                local prefix = references.prefix
                if prefix and prefix ~= "" then
                    setattribute(di,"prefix",prefix)
                end
                setattribute(di,"reference",reference,true)
                setattribute(di,"explicit",lpegmatch(p_firstpart,reference),true)
            end
            local internal = references.internal
            if internal and internal ~= "" then
                setattribute(di,"implicit",internal)
            end
        end
    end

    local function link(di,element,n,fulltag)
        -- for instance in lists a link has nested elements and no own text
        local reference = referencehash[fulltag]
        if reference then
            adddestination(di,structures.references.get(reference))
            return true
        else
            local data = di.data
            if data then
                for i=1,#data do
                    local di = data[i]
                    if di then
                        local fulltag = di.fulltag
                        if fulltag and link(di,element,n,fulltag) then
                            return true
                        end
                    end
                end
            end
        end
    end

    extras.adddestination = adddestination
    extras.addreference   = addreference

    extras.link           = link

end

-- no settings, as these are obscure ones

do

    local automathrows   = true  directives.register("export.math.autorows",   function(v) automathrows   = v end)
    local automathapply  = true  directives.register("export.math.autoapply",  function(v) automathapply  = v end)
    local automathnumber = true  directives.register("export.math.autonumber", function(v) automathnumber = v end)
    local automathstrip  = true  directives.register("export.math.autostrip",  function(v) automathstrip  = v end)

    local functions      = mathematics.categories.functions

    local function collapse(di,i,data,ndata,detail,element)
        local collapsing = di.data
        if data then
            di.element = element
            di.detail = nil
            i = i + 1
            while i <= ndata do
                local dn = data[i]
                if dn.detail == detail then
                    collapsing[#collapsing+1] = dn.data[1]
                    dn.skip = "ignore"
                    i = i + 1
                else
                    break
                end
            end
        end
        return i
    end

    local function collapse_mn(di,i,data,ndata)
        -- this is tricky ... we need to make sure that we wrap in mrows if we want
        -- to bypass this one
        local collapsing = di.data
        if data then
            i = i + 1
            while i <= ndata do
                local dn = data[i]
                local tg = dn.tg
                if tg == "mn" then
                    collapsing[#collapsing+1] = dn.data[1]
                    dn.skip = "ignore"
                    i = i + 1
                elseif tg == "mo" then
                    local d = dn.data[1]
                    if d == "." then
                        collapsing[#collapsing+1] = d
                        dn.skip = "ignore"
                        i = i + 1
                    else
                        break
                    end
                else
                    break
                end
            end
        end
        return i
    end

    -- maybe delay __i__ till we need it

    local apply_function = {
        {
            element = "mo",
         -- comment = "apply function",
         -- data    = { utfchar(0x2061) },
            data    = { "&#x2061;" },
            nature  = "mixed",
        }
    }

    local functioncontent = { }

    setmetatableindex(functioncontent,function(t,k)
        local v = { { content = k } }
        t[k] = v
        return v
    end)

    local dummy_nucleus = {
        element   = "mtext",
        data      = { content = "" },
        nature    = "inline",
        comment   = "dummy nucleus",
        fulltag   = "mtext>0"
    }

    local function accentchar(d)
        for i=1,3 do
            d = d.data
            if not d then
                return
            end
            d = d[1]
            if not d then
                return
            end
            local tg = d.tg
            if tg == "mover" then
                local s = specifications[d.fulltag]
                local t = s.top
                if t then
                    d = d.data[1]
                    local d1 = d.data[1]
                    d1.content = utfchar(t)
                    d.data = { d1 }
                    return d
                end
            elseif tg == "munder" then
                local s = specifications[d.fulltag]
                local b = s.bottom
                if b then
                    d = d.data[1]
                    local d1 = d.data[1]
                    d1.content = utfchar(b)
                    d.data = { d1 }
                    return d
                end
            end
        end
    end

    local no_mrow = {
        mrow     = true,
        mfenced  = true,
        mfrac    = true,
        mroot    = true,
        msqrt    = true,
        mi       = true,
        mo       = true,
        mn       = true,
    }

    local function checkmath(root) -- we can provide utf.toentities as an option
        local data = root.data
        if data then
            local ndata = #data
            local roottg = root.tg
            if roottg == "msubsup" then
                local nucleus, superscript, subscript
                for i=1,ndata do
                    local di = data[i]
                    if not di then
                        -- weird
                    elseif di.content then
                        -- text
                    elseif not nucleus then
                        nucleus = i
                    elseif not superscript then
                        superscript = i
                    elseif not subscript then
                        subscript = i
                    else
                        -- error
                    end
                end
                if superscript and subscript then
                    local sup, sub = data[superscript], data[subscript]
                    data[superscript], data[subscript] = sub, sup
                 -- sub.__o__, sup.__o__ = subscript, superscript
                    sub.__i__, sup.__i__ = superscript, subscript
                end
--             elseif roottg == "msup" or roottg == "msub" then
--                 -- m$^2$
--                 if ndata == 1 then
--                     local d = data[1]
--                     data[2] = d
--                     d.__i__ = 2
--                     data[1] = dummy_nucleus
--                 end
            elseif roottg == "mfenced" then
                local s = specifications[root.fulltag]
                local l, m, r = s.left, s.middle, s.right
                if l then
                    l = utfchar(l)
                end
                if m then
                    local t = { }
                    for i=1,#m do
                        t[i] = utfchar(m[i])
                    end
                    m = concat(t)
                end
                if r then
                    r = utfchar(r)
                end
                root.attributes = {
                    open       = l,
                    separators = m,
                    close      = r,
                }
            end
            if ndata == 0 then
                return
            elseif ndata == 1 then
                local d = data[1]
                if not d then
                    return
                elseif d.content then
                    return
                elseif #root.data == 1 then
                    local tg = d.tg
                    if automathrows and roottg == "mrow" then
                        -- maybe just always ! check spec first
                        if no_mrow[tg] then
                            root.skip = "comment"
                        end
                    elseif roottg == "mo" then
                        if tg == "mo" then
                            root.skip = "comment"
                        end
                    end
                end
            end
            local i = 1
            while i <= ndata do                   -- -- -- TOO MUCH NESTED CHECKING -- -- --
                local di = data[i]
                if di and not di.content then
                    local tg = di.tg
                    if tg == "math" then
                     -- di.element = "mrow" -- when properties
                        di.skip = "comment"
                        checkmath(di)
                        i = i + 1
                    elseif tg == "mover" then
                        local s = specifications[di.fulltag]
                        if s.accent then
                            local t = s.top
                            local d = di.data
                            -- todo: accent = "false" (for scripts like limits)
                            di.attributes = {
                                accent = "true",
                            }
                            -- todo: p.topfixed
                            if t then
                                -- mover
                                d[1].data[1].content = utfchar(t)
                                di.data = { d[2], d[1] }
                            end
                        else
                            -- can't happen
                        end
                        checkmath(di)
                        i = i + 1
                    elseif tg == "munder" then
                        local s = specifications[di.fulltag]
                        if s.accent then
                            local b = s.bottom
                            local d = di.data
                            -- todo: accent = "false" (for scripts like limits)
                            di.attributes = {
                                accent = "true",
                            }
                         -- todo: p.bottomfixed
                            if b then
                                -- munder
                                d[2].data[1].content = utfchar(b)
                            end
                        else
                            -- can't happen
                        end
                        checkmath(di)
                        i = i + 1
                    elseif tg == "munderover" then
                        local s = specifications[di.fulltag]
                        if s.accent then
                            local t = s.top
                            local b = s.bottom
                            local d = di.data
                            -- todo: accent      = "false" (for scripts like limits)
                            -- todo: accentunder = "false" (for scripts like limits)
                            di.attributes = {
                                accent      = "true",
                                accentunder = "true",
                            }
                         -- todo: p.topfixed
                         -- todo: p.bottomfixed
                            if t and b then
                                -- munderover
                                d[1].data[1].content = utfchar(t)
                                d[3].data[1].content = utfchar(b)
                                di.data = { d[2], d[3], d[1] }
                            else
                                -- can't happen
                            end
                        else
                            -- can't happen
                        end
                        checkmath(di)
                        i = i + 1
                    elseif tg == "mstacker" then
                        local d = di.data
                        local d1 = d[1]
                        local d2 = d[2]
                        local d3 = d[3]
                        local t1 = d1 and d1.tg
                        local t2 = d2 and d2.tg
                        local t3 = d3 and d3.tg
                        local m  = nil -- d1.data[1]
                        local t  = nil
                        local b  = nil
                        -- only accent when top / bot have stretch
                        -- normally we flush [base under over] which is better for tagged pdf
                        if t1 == "mstackermid" then
                            m = accentchar(d1) -- or m
                            if t2 == "mstackertop" then
                                if t3 == "mstackerbot" then
                                    t = accentchar(d2)
                                    b = accentchar(d3)
                                    di.element = "munderover"
                                    di.data    = { m or d1.data[1], b or d3.data[1], t or d2.data[1] }
                                else
                                    t = accentchar(d2)
                                    di.element = "mover"
                                    di.data    = { m or d1.data[1], t or d2.data[1] }
                                end
                            elseif t2 == "mstackerbot" then
                                if t3 == "mstackertop" then
                                    b = accentchar(d2)
                                    t = accentchar(d3)
                                    di.element = "munderover"
                                    di.data    = { m or d1.data[1], t or d3.data[1], m, b or d2.data[1] }
                                else
                                    b = accentchar(d2)
                                    di.element = "munder"
                                    di.data    = { m or d1.data[1], b or d2.data[1] }
                                end
                            else
                                -- can't happen
                            end
                        else
                            -- can't happen
                        end
                        if t or b then
                            di.attributes = {
                                accent      = t and "true" or nil,
                                accentunder = b and "true" or nil,
                            }
                            di.detail = nil
                        end
                        checkmath(di)
                        i = i + 1
                    elseif tg == "mroot" then
                        local data = di.data
                        local size = #data
                        if size == 1 then
                            -- else firefox complains ... code in math-tag (for pdf tagging)
                            di.element = "msqrt"
                        elseif size == 2 then
                            data[1], data[2] = data[2], data[1]
                        end
                        checkmath(di)
                        i = i + 1
                    elseif tg == "break" then
                        di.skip = "comment"
                        i = i + 1
                    elseif tg == "mtext" then
                        -- this is only needed for unboxed mtexts ... all kind of special
                        -- tex border cases and optimizations ... trial and error
                        local data = di.data
                        if #data > 1 then
                            for i=1,#data do
                                local di = data[i]
                                local content = di.content
                                if content then
                                    data[i] = {
                                        element = "mtext",
                                        nature  = "inline",
                                        data    = { di },
                                        n       = 0,
                                    }
                                elseif di.tg == "math" then
                                    local di = di.data[1]
                                    data[i] = di
                                    checkmath(di)
                                end
                            end
                            di.element = "mrow"
                         -- di.tg = "mrow"
                         -- di.nature  = "inline"
                        end
                        checkmath(di)
                        i = i + 1
                    elseif tg == "mrow" and detail then -- hm, falls through
                        di.detail = nil
                        checkmath(di)
                        di = {
                            element    = "maction",
                            nature     = "display",
                            attributes = { actiontype = detail },
                            data       = { di },
                            n          = 0,
                        }
                        data[i] = di
                        i = i + 1
                    else
                        local category = di.mathcategory
                        if category then
                         -- no checkmath(di) here
                            if category == 1 then -- mo
                                i = collapse(di,i,data,ndata,detail,"mo")
                            elseif category == 2 then -- mi
                                i = collapse(di,i,data,ndata,detail,"mi")
                            elseif category == 3 then -- mn
                                i = collapse(di,i,data,ndata,detail,"mn")
                            elseif category == 4 then -- ms
                                i = collapse(di,i,data,ndata,detail,"ms")
                            elseif category >= 1000 then
                                local apply = category >= 2000
                                if apply then
                                    category = category - 1000
                                end
                                if tg == "mi" then -- function
                                    if roottg == "mrow" then
                                        root.skip = "comment"
                                        root.element = "function"
                                    end
                                    i = collapse(di,i,data,ndata,detail,"mi")
                                    local tag = functions[category]
                                    if tag then
                                        di.data = functioncontent[tag]
                                    end
                                    if apply then
                                        di.after = apply_function
                                    elseif automathapply then -- make function
                                        local following
                                        if i <= ndata then
                                            -- normally not the case
                                            following = data[i]
                                        else
                                            local parent = di.__p__ -- == root
                                            if parent.tg == "mrow" then
                                                parent = parent.__p__
                                            end
                                            local index = parent.__i__
                                            following = parent.data[index+1]
                                        end
                                        if following then
                                            local tg = following.tg
                                            if tg == "mrow" or tg == "mfenced" then -- we need to figure out the right condition
                                                di.after = apply_function
                                            end
                                        end
                                    end
                                else -- some problem
                                    checkmath(di)
                                    i = i + 1
                                end
                            else
                                checkmath(di)
                                i = i + 1
                            end
                        elseif automathnumber and tg == "mn" then
                            checkmath(di)
                            i = collapse_mn(di,i,data,ndata)
                        else
                            checkmath(di)
                            i = i + 1
                        end
                    end
                else -- can be string or boolean
                    if parenttg ~= "mtext" and di == " " then
                        data[i] = false
                    end
                    i = i + 1
                end
            end
        end
    end

    local function stripmath(di)
        if not di then
            --
        elseif di.content then
            return di
        else
            local tg = di.tg
            if tg == "mtext" or tg == "ms" then
                return di
            else
                local data = di.data
                local ndata = #data
                local n = 0
                for i=1,ndata do
                    local d = data[i]
                    if d and not d.content then
                        d = stripmath(d)
                    end
                    if d then
                        local content = d.content
                        if not content then
                            n = n + 1
                            d.__i__ = n
                            data[n] = d
                        elseif content == " " or content == "" then
                            if di.tg == "mspace" then
                                -- we append or prepend a space to a preceding or following mtext
                                local parent = di.__p__
                                local index  = di.__i__ -- == i
                                local data   = parent.data
                                if index > 1 then
                                    local d = data[index-1]
                                    if d.tg == "mtext" then
                                        local dd = d.data
                                        local dn = dd[#dd]
                                        local dc = dn.content
                                        if dc then
                                            dn.content = dc .. content
                                        end
                                    end
                                elseif index < ndata then
                                    local d = data[index+1]
                                    if d.tg == "mtext" then
                                        local dd = d.data
                                        local dn = dd[1]
                                        local dc = dn.content
                                        if dc then
                                            dn.content = content .. dc
                                        end
                                    end
                                end
                            end
                        else
                            n = n + 1
                            data[n] = d
                        end
                    end
                end
                for i=ndata,n+1,-1 do
                    data[i] = nil
                end
                if #data > 0 then
                    return di
                end
-- end
            end
            -- could be integrated but is messy then
--             while roottg == "mrow" and #data == 1 do
--                 data = data[1]
--                 for k, v in next, data do
--                     root[k] = v
--                 end
--                 roottg = data.tg
--             end
        end
    end

    function checks.math(di)
        local specification = specifications[di.fulltag]
        local mode = specification and specification.mode == "display" and "block" or "inline"
        di.attributes = {
            ["display"] = mode,
            ["xmlns:m"] = mathmlns,
        }
        -- can be option if needed:
        if mode == "inline" then
         -- di.nature = "mixed"  -- else spacing problem (maybe inline)
            di.nature = "inline" -- we need to catch x$X$x and x $X$ x
        else
            di.nature = "display"
        end
        if automathstrip then
            stripmath(di)
        end
        checkmath(di)
    end

    local a, z, A, Z = 0x61, 0x7A, 0x41, 0x5A

    function extras.mi(di,element,n,fulltag) -- check with content
        local str = di.data[1].content
        if str and sub(str,1,1) ~= "&" then -- hack but good enough (maybe gsub op eerste)
            for v in utfvalues(str) do
                if (v >= a and v <= z) or (v >= A and v <= Z) then
                    local a = di.attributes
                    if a then
                        a.mathvariant = "normal"
                    else
                        di.attributes = { mathvariant = "normal" }
                    end
                end
            end
        end
    end

    function extras.msub(di,element,n,fulltag)
        -- m$^2$
        local data = di.data
        if #data == 1 then
            local d = data[1]
            data[2] = d
            d.__i__ = 2
            data[1] = dummy_nucleus
        end
    end

    extras.msup = extras.msub

end

do

    local registered = structures.sections.registered

    local function resolve(di,element,n,fulltag)
        local data = listdata[fulltag]
        if data then
            extras.addreference(di,data.references)
            return true
        else
            local data = di.data
            if data then
                for i=1,#data do
                    local di = data[i]
                    if di then
                        local ft = di.fulltag
                        if ft and resolve(di,element,n,ft) then
                            return true
                        end
                    end
                end
            end
        end
    end

    function extras.section(di,element,n,fulltag)
        local r = registered[specifications[fulltag].detail]
        if r then
            setattribute(di,"level",r.level)
        end
        resolve(di,element,n,fulltag)
    end

    extras.float = resolve

    -- todo: internal is already hashed

    function structurestags.setlist(n)
        local data = structures.lists.getresult(n)
        if data then
            referencehash[locatedtag("listitem")] = data
        end
    end

    function extras.listitem(di,element,n,fulltag)
        local data = referencehash[fulltag]
        if data then
            extras.addinternal(di,data.references)
            return true
        end
    end

end

do

    -- todo: internal is already hashed

    function structurestags.setregister(tag,n) -- check if tag is needed
        local data = structures.registers.get(tag,n)
        if data then
            referencehash[locatedtag("registerlocation")] = data
        end
    end

    function extras.registerlocation(di,element,n,fulltag)
        local data = referencehash[fulltag]
        if type(data) == "table" then
            extras.addinternal(di,data.references)
            return true
        else
            -- needs checking, probably bookmarks
        end
    end

    extras.registerpages     = ignorebreaks
    extras.registerseparator = ignorespaces

end

do

    local tabledata = { }

    local function hascontent(data)
        for i=1,#data do
            local di = data[i]
            if not di then
                --
            elseif di.content then
                return true
            else
                local d = di.data
                if d and #d > 0 and hascontent(d) then
                    return true
                end
            end
        end
    end

    function structurestags.settablecell(rows,columns,align)
        if align > 0 or rows > 1 or columns > 1 then
            tabledata[locatedtag("tablecell")] = {
                rows    = rows,
                columns = columns,
                align   = align,
            }
        end
    end

    function extras.tablecell(di,element,n,fulltag)
        local hash = tabledata[fulltag]
        if hash then
            local columns = hash.columns
            if columns and columns > 1 then
                setattribute(di,"columns",columns)
            end
            local rows = hash.rows
            if rows and rows > 1 then
                setattribute(di,"rows",rows)
            end
            local align = hash.align
            if not align or align == 0 then
                -- normal
            elseif align == 1 then -- use numbertoalign here
                setattribute(di,"align","flushright")
            elseif align == 2 then
                setattribute(di,"align","middle")
            elseif align == 3 then
                setattribute(di,"align","flushleft")
            end
        end
    end

    local tabulatedata = { }

    function structurestags.settabulatecell(align)
        if align > 0 then
            tabulatedata[locatedtag("tabulatecell")] = {
                align = align,
            }
        end
    end

    function extras.tabulate(di,element,n,fulltag)
        local data = di.data
        for i=1,#data do
            local di = data[i]
            if di.tg == "tabulaterow" and not hascontent(di.data) then
                di.element = "" -- or simply remove
            end
        end
    end

    function extras.tabulatecell(di,element,n,fulltag)
        local hash = tabulatedata[fulltag]
        if hash then
            local align = hash.align
            if not align or align == 0 then
                -- normal
            elseif align == 1 then
                setattribute(di,"align","flushleft")
            elseif align == 2 then
                setattribute(di,"align","flushright")
            elseif align == 3 then
                setattribute(di,"align","middle")
            end
        end
    end

end

-- flusher

do

    local f_detail                     = formatters[' detail="%s"']
    local f_chain                      = formatters[' chain="%s"']
    local f_index                      = formatters[' n="%s"']
    local f_spacing                    = formatters['<c n="%s">%s</c>']

    local f_empty_inline               = formatters["<%s/>"]
    local f_empty_mixed                = formatters["%w<%s/>\n"]
    local f_empty_display              = formatters["\n%w<%s/>\n"]
    local f_empty_inline_attr          = formatters["<%s%s/>"]
    local f_empty_mixed_attr           = formatters["%w<%s%s/>"]
    local f_empty_display_attr         = formatters["\n%w<%s%s/>\n"]

    local f_begin_inline               = formatters["<%s>"]
    local f_begin_mixed                = formatters["%w<%s>"]
    local f_begin_display              = formatters["\n%w<%s>\n"]
    local f_begin_inline_attr          = formatters["<%s%s>"]
    local f_begin_mixed_attr           = formatters["%w<%s%s>"]
    local f_begin_display_attr         = formatters["\n%w<%s%s>\n"]

    local f_end_inline                 = formatters["</%s>"]
    local f_end_mixed                  = formatters["</%s>\n"]
    local f_end_display                = formatters["%w</%s>\n"]

    local f_begin_inline_comment       = formatters["<!-- %s --><%s>"]
    local f_begin_mixed_comment        = formatters["%w<!-- %s --><%s>"]
    local f_begin_display_comment      = formatters["\n%w<!-- %s -->\n%w<%s>\n"]
    local f_begin_inline_attr_comment  = formatters["<!-- %s --><%s%s>"]
    local f_begin_mixed_attr_comment   = formatters["%w<!-- %s --><%s%s>"]
    local f_begin_display_attr_comment = formatters["\n%w<!-- %s -->\n%w<%s%s>\n"]

    local f_comment_begin_inline       = formatters["<!-- begin %s -->"]
    local f_comment_begin_mixed        = formatters["%w<!-- begin %s -->"]
    local f_comment_begin_display      = formatters["\n%w<!-- begin %s -->\n"]

    local f_comment_end_inline         = formatters["<!-- end %s -->"]
    local f_comment_end_mixed          = formatters["<!-- end %s -->\n"]
    local f_comment_end_display        = formatters["%w<!-- end %s -->\n"]

    local f_metadata_begin             = formatters["\n%w<metadata>\n"]
    local f_metadata                   = formatters["%w<metavariable name=%q>%s</metavariable>\n"]
    local f_metadata_end               = formatters["%w</metadata>\n"]

    local function attributes(a)
        local r = { }
        local n = 0
        for k, v in next, a do
            n = n + 1
            r[n] = f_attribute(k,v) -- lpegmatch(p_escaped,v)
        end
        sort(r)
        return concat(r,"")
    end

    local function properties(a)
        local r = { }
        local n = 0
        for k, v in next, a do
            n = n + 1
            r[n] = f_property(exportproperties,k,v)
        end
        sort(r)
        return concat(r,"")
    end

    local depth  = 0
    local inline = 0

    local function bpar(result)
        result[#result+1] = "\n<p>"
    end
    local function epar(result)
        result[#result+1] = "</p>\n"
    end

    local function emptytag(result,embedded,element,nature,di) -- currently only break but at some point
        local a = di.attributes                       -- we might add detail etc
        if a then -- happens seldom
            if nature == "display" then
                result[#result+1] = f_empty_display_attr(depth,namespaced[element],attributes(a))
            elseif nature == "mixed" then
                result[#result+1] = f_empty_mixed_attr(depth,namespaced[element],attributes(a))
            else
                result[#result+1] = f_empty_inline_attr(namespaced[element],attributes(a))
            end
        else
            if nature == "display" then
                result[#result+1] = f_empty_display(depth,namespaced[element])
            elseif nature == "mixed" then
                result[#result+1] = f_empty_mixed(depth,namespaced[element])
            else
                result[#result+1] = f_empty_inline(namespaced[element])
            end
        end
    end

    local function begintag(result,embedded,element,nature,di,skip)
        local index         = di.n
        local fulltag       = di.fulltag
        local specification = specifications[fulltag] or { } -- we can have a dummy
        local comment       = di.comment
        local detail        = specification.detail
        if skip == "comment" then
            if show_comment then
                if nature == "inline" or inline > 0 then
                    result[#result+1] = f_comment_begin_inline(namespaced[element])
                    inline = inline + 1
                elseif nature == "mixed" then
                    result[#result+1] = f_comment_begin_mixed(depth,namespaced[element])
                    depth = depth + 1
                    inline = 1
                else
                    result[#result+1] = f_comment_begin_display(depth,namespaced[element])
                    depth = depth + 1
                end
            end
        elseif skip then
            -- ignore
        else

         -- if embedded then
         --     if element == "math" then
         --         embedded[f_tagid(element,index)] = #result+1
         --     end
         -- end

            local n = 0
            local r = { } -- delay this
            if detail then
                detail = gsub(detail,"[^A-Za-z0-9]+","-")
                specification.detail = detail -- we use it later in for the div
                n = n + 1
                r[n] = f_detail(detail)
            end
            local parents = specification.parents
            if parents then
                parents = gsub(parents,"[^A-Za-z0-9 ]+","-")
                specification.parents = parents -- we use it later in for the div
                n = n + 1
                r[n] = f_chain(parents)
            end
            if indexing and index then
                n = n + 1
                r[n] = f_index(index)
            end
            local extra = extras[element]
            if extra then
                extra(di,element,index,fulltag)
            end
            if exportproperties then
                local p = specification.userdata
                if not p then
                    -- skip
                elseif exportproperties == v_yes then
                    r[n] = attributes(p)
                else
                    r[n] = properties(p)
                end
            end
            local a = di.attributes
            if a then
                n = n + 1
                r[n] = attributes(a)
            end
            if n == 0 then
                if nature == "inline" or inline > 0 then
                    if show_comment and comment then
                        result[#result+1] = f_begin_inline_comment(comment,namespaced[element])
                    else
                        result[#result+1] = f_begin_inline(namespaced[element])
                    end
                    inline = inline + 1
                elseif nature == "mixed" then
                    if show_comment and comment then
                        result[#result+1] = f_begin_mixed_comment(depth,comment,namespaced[element])
                    else
                        result[#result+1] = f_begin_mixed(depth,namespaced[element])
                    end
                    depth = depth + 1
                    inline = 1
                else
                    if show_comment and comment then
                        result[#result+1] = f_begin_display_comment(depth,comment,depth,namespaced[element])
                    else
                        result[#result+1] = f_begin_display(depth,namespaced[element])
                    end
                    depth = depth + 1
                end
            else
                r = concat(r,"",1,n)
                if nature == "inline" or inline > 0 then
                    if show_comment and comment then
                        result[#result+1] = f_begin_inline_attr_comment(comment,namespaced[element],r)
                    else
                        result[#result+1] = f_begin_inline_attr(namespaced[element],r)
                    end
                    inline = inline + 1
                elseif nature == "mixed" then
                    if show_comment and comment then
                        result[#result+1] = f_begin_mixed_attr_comment(depth,comment,namespaced[element],r)
                    else
                        result[#result+1] = f_begin_mixed_attr(depth,namespaced[element],r)
                    end
                    depth = depth + 1
                    inline = 1
                else
                    if show_comment and comment then
                        result[#result+1] = f_begin_display_attr_comment(depth,comment,depth,namespaced[element],r)
                    else
                        result[#result+1] = f_begin_display_attr(depth,namespaced[element],r)
                    end
                    depth = depth + 1
                end
            end
        end
        used[element][detail or ""] = { nature, specification.parents }  -- for template css
        -- also in last else ?
        local metadata = specification.metadata
        if metadata then
            result[#result+1] = f_metadata_begin(depth)
            for k, v in table.sortedpairs(metadata) do
                result[#result+1] = f_metadata(depth+1,k,lpegmatch(p_entity,v))
            end
            result[#result+1] = f_metadata_end(depth)
        end
    end

    local function endtag(result,embedded,element,nature,di,skip)
        if skip == "comment" then
            if show_comment then
                if nature == "display" and (inline == 0 or inline == 1) then
                    depth = depth - 1
                    result[#result+1] = f_comment_end_display(depth,namespaced[element])
                    inline = 0
                elseif nature == "mixed" and (inline == 0 or inline == 1) then
                    depth = depth - 1
                    result[#result+1] = f_comment_end_mixed(namespaced[element])
                    inline = 0
                else
                    inline = inline - 1
                    result[#result+1] = f_comment_end_inline(namespaced[element])
                end
            end
        elseif skip then
            -- ignore
        else
            if nature == "display" and (inline == 0 or inline == 1) then
                depth = depth - 1
                result[#result+1] = f_end_display(depth,namespaced[element])
                inline = 0
            elseif nature == "mixed" and (inline == 0 or inline == 1) then
                depth = depth - 1
                result[#result+1] = f_end_mixed(namespaced[element])
                inline = 0
            else
                inline = inline - 1
                result[#result+1] = f_end_inline(namespaced[element])
            end

         -- if embedded then
         --     if element == "math" then
         --         local id = f_tagid(element,di.n) -- index)
         --         local tx = concat(result,"",embedded[id],#result)
         --         embedded[id] = "<?xml version='1.0' standalone='yes'?>" .. "\n" .. tx
         --     end
         -- end
        end
    end

    local function flushtree(result,embedded,data,nature)
        local nofdata = #data
        for i=1,nofdata do
            local di = data[i]
            if not di then -- hm, di can be string
                -- whatever
            else
                local content = di.content
             -- also optimize for content == "" : trace that first
                if content then
                    -- already has breaks
                    local content = lpegmatch(p_entity,content)
                    if i == nofdata and sub(content,-1) == "\n" then -- move check
                        -- can be an end of line in par but can also be the last line
                        if trace_spacing then
                            result[#result+1] = f_spacing(di.parnumber or 0,sub(content,1,-2))
                        else
                            result[#result+1] = sub(content,1,-2)
                        end
                        result[#result+1] = " "
                    else
                        if trace_spacing then
                            result[#result+1] = f_spacing(di.parnumber or 0,content)
                        else
                            result[#result+1] = content
                        end
                    end
                elseif not di.collapsed then -- ignore collapsed data (is appended, reconstructed par)
                    local element = di.element
                    if not element then
                        -- skip
                    elseif element == "break" then -- or element == "pagebreak"
                        emptytag(result,embedded,element,nature,di)
                    elseif element == "" or di.skip == "ignore" then
                        -- skip
                    else
                        if di.before then
                            flushtree(result,embedded,di.before,nature)
                        end
                        local natu = di.nature
                        local skip = di.skip
                        if di.breaknode then
                            emptytag(result,embedded,"break","display",di)
                        end
                        begintag(result,embedded,element,natu,di,skip)
                        flushtree(result,embedded,di.data,natu)
                        endtag(result,embedded,element,natu,di,skip)
                        if di.after then
                            flushtree(result,embedded,di.after,nature)
                        end
                    end
                end
            end
        end
    end

    local function breaktree(tree,parent,parentelement) -- also removes double breaks
        local data = tree.data
        if data then
            local nofdata = #data
            local prevelement
            local prevnature
            local prevparnumber
            local newdata = { }
            local nofnewdata = 0
            for i=1,nofdata do
                local di = data[i]
                if not di then
                    -- skip
                elseif di.content then
                    local parnumber = di.parnumber
                    if prevnature == "inline" and prevparnumber and prevparnumber ~= parnumber then
                        nofnewdata = nofnewdata + 1
                        if trace_spacing then
                            newdata[nofnewdata] = makebreaknode { type = "a", p = prevparnumber, n = parnumber }
                        else
                            newdata[nofnewdata] = makebreaknode()
                        end
                    end
                    prevelement = nil
                    prevnature = "inline"
                    prevparnumber = parnumber
                    nofnewdata = nofnewdata + 1
                    newdata[nofnewdata] = di
                elseif not di.collapsed then
                    local element = di.element
                    if element == "break" then -- or element == "pagebreak"
                        if prevelement == "break" then
                            di.element = ""
                        end
                        prevelement = element
                        prevnature = "display"
                    elseif element == "" or di.skip == "ignore" then
                        -- skip
                    else
                        local nature = di.nature
                        local parnumber = di.parnumber
                        if prevnature == "inline" and nature == "inline" and prevparnumber and prevparnumber ~= parnumber then
                            nofnewdata = nofnewdata + 1
                            if trace_spacing then
                                newdata[nofnewdata] = makebreaknode { type = "b", p = prevparnumber, n = parnumber }
                            else
                                newdata[nofnewdata] = makebreaknode()
                            end
                        end
                        prevnature = nature
                        prevparnumber = parnumber
                        prevelement = element
                        breaktree(di,tree,element)
                    end
                    nofnewdata = nofnewdata + 1
                    newdata[nofnewdata] = di
                else
                    local nature = di.nature
                    local parnumber = di.parnumber
                    if prevnature == "inline" and nature == "inline" and prevparnumber and prevparnumber ~= parnumber then
                        nofnewdata = nofnewdata + 1
                        if trace_spacing then
                            newdata[nofnewdata] = makebreaknode { type = "c", p = prevparnumber, n = parnumber }
                        else
                            newdata[nofnewdata] = makebreaknode()
                        end
                    end
                    prevnature = nature
                    prevparnumber = parnumber
                    nofnewdata = nofnewdata + 1
                    newdata[nofnewdata] = di
                end
            end
            tree.data = newdata
        end
    end

    -- also tabulaterow reconstruction .. maybe better as a checker
    -- i.e cell attribute

    local function collapsetree()
        for tag, trees in next, treehash do
            local d = trees[1].data
            if d then
                local nd = #d
                if nd > 0 then
                    for i=2,#trees do
                        local currenttree = trees[i]
                        local currentdata = currenttree.data
                        local currentpar  = currenttree.parnumber
                        local previouspar = trees[i-1].parnumber
                        currenttree.collapsed = true
                        -- is the next ok?
                        if previouspar == 0 or not (di and di.content) then
                            previouspar = nil -- no need anyway so no further testing needed
                        end
                        for j=1,#currentdata do
                            local cd = currentdata[j]
                            if not cd or cd == "" then
                                -- skip
                            elseif cd.content then
                                if not currentpar then
                                    -- add space ?
                                elseif not previouspar then
                                    -- add space ?
                                elseif currentpar ~= previouspar then
                                    nd = nd + 1
                                    if trace_spacing then
                                        d[nd] = makebreaknode { type = "d", p = previouspar, n = currentpar }
                                    else
                                        d[nd] = makebreaknode()
                                    end
                                end
                                previouspar = currentpar
                                nd = nd + 1
                                d[nd] = cd
                            else
                                nd = nd + 1
                                d[nd] = cd
                            end
                            currentdata[j] = false
                        end
                    end
                end
            end
        end
    end

    local function finalizetree(tree)
        for _, finalizer in next, finalizers do
            finalizer(tree)
        end
    end

    local function indextree(tree)
        local data = tree.data
        if data then
            local n, new = 0, { }
            for i=1,#data do
                local d = data[i]
                if not d then
                    -- skip
                elseif d.content then
                    n = n + 1
                    new[n] = d
                elseif not d.collapsed then
                    n = n + 1
                    d.__i__ = n
                    d.__p__ = tree
                    indextree(d)
                    new[n] = d
                end
            end
            tree.data = new
        end
    end

    local function checktree(tree)
        local data = tree.data
        if data then
            for i=1,#data do
                local d = data[i]
                if type(d) == "table" then
                    local check = checks[d.tg]
                    if check then
                        check(d)
                    end
                    checktree(d)
                end
            end
        end
    end

    wrapups.flushtree    = flushtree
    wrapups.breaktree    = breaktree
    wrapups.collapsetree = collapsetree
    wrapups.finalizetree = finalizetree
    wrapups.indextree    = indextree
    wrapups.checktree    = checktree

end

-- collector code

local function push(fulltag,depth)
    local tg, n, detail
    local specification = specifications[fulltag]
    if specification then
        tg     = specification.tagname
        n      = specification.tagindex
        detail = specification.detail
    else
        -- a break (more efficient if we don't store those in specifications)
        tg, n = lpegmatch(tagsplitter,fulltag)
        n = tonumber(n) -- to tonumber in tagsplitter
    end
    local p        = properties[tg]
    local element  = p and p.export or tg
    local nature   = p and p.nature or "inline" -- defaultnature
    local treedata = tree.data
    local t = { -- maybe we can use the tag table
        tg         = tg,
        fulltag    = fulltag,
        detail     = detail,
        n          = n, -- already a number
        element    = element,
        nature     = nature,
        data       = { },
        attribute  = currentattribute,
        parnumber  = currentparagraph,
    }
    treedata[#treedata+1] = t
    currentdepth = currentdepth + 1
    nesting[currentdepth] = fulltag
    treestack[currentdepth] = tree
    if trace_export then
        if detail and detail ~= "" then
            report_export("%w<%s trigger=%q n=%q paragraph=%q index=%q detail=%q>",currentdepth-1,tg,n,currentattribute or 0,currentparagraph or 0,#treedata,detail)
        else
            report_export("%w<%s trigger=%q n=%q paragraph=%q index=%q>",currentdepth-1,tg,n,currentattribute or 0,currentparagraph or 0,#treedata)
        end
    end
    tree = t
    if tg == "break" then
        -- no need for this
    else
        local h = treehash[fulltag]
        if h then
            h[#h+1] = t
        else
            treehash[fulltag] = { t }
        end
    end
end

local function pop()
    if currentdepth > 0 then
        local top = nesting[currentdepth]
        tree = treestack[currentdepth]
        currentdepth = currentdepth - 1
        if trace_export then
            if top then
                report_export("%w</%s>",currentdepth,top)
            else
                report_export("</%s>",top)
            end
        end
    else
        report_export("%w<!-- too many pops -->",currentdepth)
    end
end

local function continueexport()
    if nofcurrentcontent > 0 then
        if trace_export then
            report_export("%w<!-- injecting pagebreak space -->",currentdepth)
        end
        nofcurrentcontent = nofcurrentcontent + 1
        currentcontent[nofcurrentcontent] = " " -- pagebreak
    end
end

local function pushentry(current)
    if not current then
        -- bad news
        return
    end
    current = current.taglist
    if not current then
        -- even worse news
        return
    end
    if restart then
        continueexport()
        restart = false
    end
    local newdepth = #current
    local olddepth = currentdepth
    if trace_export then
        report_export("%w<!-- moving from depth %s to %s (%s) -->",currentdepth,olddepth,newdepth,current[newdepth])
    end
    if olddepth <= 0 then
        for i=1,newdepth do
            push(current[i],i)
        end
    else
        local difference
        if olddepth < newdepth then
            for i=1,olddepth do
                if current[i] ~= nesting[i] then
                    difference = i
                    break
                end
            end
        else
            for i=1,newdepth do
                if current[i] ~= nesting[i] then
                    difference = i
                    break
                end
            end
        end
        if difference then
            for i=olddepth,difference,-1 do
                pop()
            end
            for i=difference,newdepth do
                push(current[i],i)
            end
        elseif newdepth > olddepth then
            for i=olddepth+1,newdepth do
                push(current[i],i)
            end
        elseif newdepth < olddepth then
            for i=olddepth,newdepth,-1 do
                pop()
            end
        elseif trace_export then
            report_export("%w<!-- staying at depth %s (%s) -->",currentdepth,newdepth,nesting[newdepth] or "?")
        end
    end
    return olddepth, newdepth
end

local function pushcontent(oldparagraph,newparagraph)
    if nofcurrentcontent > 0 then
        if oldparagraph then
            if currentcontent[nofcurrentcontent] == "\n" then
                if trace_export then
                    report_export("%w<!-- removing newline -->",currentdepth)
                end
                nofcurrentcontent = nofcurrentcontent - 1
            end
        end
        local content = concat(currentcontent,"",1,nofcurrentcontent)
        if content == "" then
            -- omit; when oldparagraph we could push, remove spaces, pop
        elseif somespace[content] and oldparagraph then
            -- omit; when oldparagraph we could push, remove spaces, pop
        else
            local olddepth, newdepth
            local list = taglist[currentattribute]
            if list then
                olddepth, newdepth = pushentry(list)
            end
            if tree then
                local td = tree.data
                local nd = #td
                td[nd+1] = { parnumber = oldparagraph or currentparagraph, content = content }
                if trace_export then
                    report_export("%w<!-- start content with length %s -->",currentdepth,#content)
                    report_export("%w%s",currentdepth,(gsub(content,"\n","\\n")))
                    report_export("%w<!-- stop content -->",currentdepth)
                end
                if olddepth then
                    for i=newdepth-1,olddepth,-1 do
                        pop()
                    end
                end
            end
        end
        nofcurrentcontent = 0
    end
    if oldparagraph then
        pushentry(makebreaklist(currentnesting))
        if trace_export then
            report_export("%w<!-- break added between paragraph %a and %a -->",currentdepth,oldparagraph,newparagraph)
        end
    end
end

local function finishexport()
    if trace_export then
        report_export("%w<!-- start finalizing -->",currentdepth)
    end
    if nofcurrentcontent > 0 then
        if somespace[currentcontent[nofcurrentcontent]] then
            if trace_export then
                report_export("%w<!-- removing space -->",currentdepth)
            end
            nofcurrentcontent = nofcurrentcontent - 1
        end
        pushcontent()
    end
    for i=currentdepth,1,-1 do
        pop()
    end
    currentcontent = { } -- we're nice and do a cleanup
    if trace_export then
        report_export("%w<!-- stop finalizing -->",currentdepth)
    end
end

local function collectresults(head,list,pat,pap) -- is last used (we also have currentattribute)
    local p
    for n in traverse_nodes(head) do
        local c, id = isglyph(n) -- 14: image, 8: literal (mp)
        if c then
            local at = getattr(n,a_tagged) or pat
            if not at then
             -- we need to tag the pagebody stuff as being valid skippable
             --
             -- report_export("skipping character: %C (no attribute)",n.char)
            else
                -- we could add tonunicodes for ligatures (todo)
                local components = getfield(n,"components")
                if components and (not characterdata[c] or overloads[c]) then -- we loose data
                    collectresults(components,nil,at) -- this assumes that components have the same attribute as the glyph ... we should be more tolerant (see math)
                else
                    if last ~= at then
                        local tl = taglist[at]
                        pushcontent()
                        currentnesting = tl
                        currentparagraph = getattr(n,a_taggedpar) or pap
                        currentattribute = at
                        last = at
                        pushentry(currentnesting)
                        if trace_export then
                            report_export("%w<!-- processing glyph %C tagged %a -->",currentdepth,c,at)
                        end
                        -- We need to intercept this here; maybe I will also move this
                        -- to a regular setter at the tex end.
                        local r = getattr(n,a_reference)
                        if r then
                            local t = tl.taglist
                            referencehash[t[#t]] = r -- fulltag
                        end
                        --
                    elseif last then
                        -- we can consider tagging the pars (lines) in the parbuilder but then we loose some
                        -- information unless we inject a special node (but even then we can run into nesting
                        -- issues)
                        local ap = getattr(n,a_taggedpar) or pap
                        if ap ~= currentparagraph then
                            pushcontent(currentparagraph,ap)
                            pushentry(currentnesting)
                            currentattribute = last
                            currentparagraph = ap
                        end
                        if trace_export then
                            report_export("%w<!-- processing glyph %C tagged %a) -->",currentdepth,c,last)
                        end
                    else
                        if trace_export then
                            report_export("%w<!-- processing glyph %C tagged %a) -->",currentdepth,c,at)
                        end
                    end
                    local s = getattr(n,a_exportstatus)
                    if s then
                        c = s
                    end
                    if c == 0 then
                        if trace_export then
                            report_export("%w<!-- skipping last glyph -->",currentdepth)
                        end
                    elseif c == 0x20 then
                        local a = getattr(n,a_characters)
                        nofcurrentcontent = nofcurrentcontent + 1
                        if a then
                            if trace_export then
                                report_export("%w<!-- turning last space into special space %U -->",currentdepth,a)
                            end
                            currentcontent[nofcurrentcontent] = specialspaces[a] -- special space
                        else
                            currentcontent[nofcurrentcontent] = " "
                        end
                    else
                        local fc = fontchar[getfont(n)]
                        if fc then
                            fc = fc and fc[c]
                            if fc then
                                local u = fc.unicode
                                if not u then
                                    nofcurrentcontent = nofcurrentcontent + 1
                                    currentcontent[nofcurrentcontent] = utfchar(c)
                                elseif type(u) == "table" then
                                    for i=1,#u do
                                        nofcurrentcontent = nofcurrentcontent + 1
                                        currentcontent[nofcurrentcontent] = utfchar(u[i])
                                    end
                                else
                                    nofcurrentcontent = nofcurrentcontent + 1
                                    currentcontent[nofcurrentcontent] = utfchar(u)
                                end
                            elseif c > 0 then
                                nofcurrentcontent = nofcurrentcontent + 1
                                currentcontent[nofcurrentcontent] = utfchar(c)
                            else
                                -- we can have -1 as side effect of an explicit hyphen (unless we expand)
                            end
                        elseif c > 0 then
                            nofcurrentcontent = nofcurrentcontent + 1
                            currentcontent[nofcurrentcontent] = utfchar(c)
                        else
                            -- we can have -1 as side effect of an explicit hyphen (unless we expand)
                        end
                    end
                end
            end
        elseif id == disc_code then -- probably too late
            local pre, post, replace = getdisc(n)
            if keephyphens then
                if pre and not getnext(pre) and isglyph(pre) == hyphencode then
                    nofcurrentcontent = nofcurrentcontent + 1
                    currentcontent[nofcurrentcontent] = hyphen
                end
            end
            if replace then
                collectresults(replace,nil)
            end
        elseif id == glue_code then
            -- we need to distinguish between hskips and vskips
            local ca = getattr(n,a_characters)
            if ca == 0 then
                -- skip this one ... already converted special character (node-acc)
            elseif ca then
                local a = getattr(n,a_tagged) or pat
                if a then
                    local c = specialspaces[ca]
                    if last ~= a then
                        local tl = taglist[a]
                        if trace_export then
                            report_export("%w<!-- processing space glyph %U tagged %a case 1 -->",currentdepth,ca,a)
                        end
                        pushcontent()
                        currentnesting = tl
                        currentparagraph = getattr(n,a_taggedpar) or pap
                        currentattribute = a
                        last = a
                        pushentry(currentnesting)
                        -- no reference check (see above)
                    elseif last then
                        local ap = getattr(n,a_taggedpar) or pap
                        if ap ~= currentparagraph then
                            pushcontent(currentparagraph,ap)
                            pushentry(currentnesting)
                            currentattribute = last
                            currentparagraph = ap
                        end
                        if trace_export then
                            report_export("%w<!-- processing space glyph %U tagged %a case 2 -->",currentdepth,ca,last)
                        end
                    end
                    -- if somespace[currentcontent[nofcurrentcontent]] then
                    --     if trace_export then
                    --         report_export("%w<!-- removing space -->",currentdepth)
                    --     end
                    --     nofcurrentcontent = nofcurrentcontent - 1
                    -- end
                    nofcurrentcontent = nofcurrentcontent + 1
                    currentcontent[nofcurrentcontent] = c
                end
            else
                local subtype = getsubtype(n)
                if subtype == userskip_code then
                    if getfield(n,"width") > threshold then
                        if last and not somespace[currentcontent[nofcurrentcontent]] then
                            local a = getattr(n,a_tagged) or pat
                            if a == last then
                                if trace_export then
                                    report_export("%w<!-- injecting spacing 5a -->",currentdepth)
                                end
                                nofcurrentcontent = nofcurrentcontent + 1
                                currentcontent[nofcurrentcontent] = " "
                            elseif a then
                                -- e.g LOGO<space>LOGO
                                if trace_export then
                                    report_export("%w<!-- processing glue > threshold tagged %s becomes %s -->",currentdepth,last,a)
                                end
                                pushcontent()
                                if trace_export then
                                    report_export("%w<!-- injecting spacing 5b -->",currentdepth)
                                end
                                last = a
                                nofcurrentcontent = nofcurrentcontent + 1
                                currentcontent[nofcurrentcontent] = " "
                                currentnesting = taglist[last]
                                pushentry(currentnesting)
                                currentattribute = last
                            end
                        end
                    end
                elseif subtype == spaceskip_code or subtype == xspaceskip_code then
                    if not somespace[currentcontent[nofcurrentcontent]] then
                        local a = getattr(n,a_tagged) or pat
                        if a == last then
                            if trace_export then
                                report_export("%w<!-- injecting spacing 7 (stay in element) -->",currentdepth)
                            end
                            nofcurrentcontent = nofcurrentcontent + 1
                            currentcontent[nofcurrentcontent] = " "
                        else
                            if trace_export then
                                report_export("%w<!-- injecting spacing 7 (end of element) -->",currentdepth)
                            end
                            last = a
                            pushcontent()
                            nofcurrentcontent = nofcurrentcontent + 1
                            currentcontent[nofcurrentcontent] = " "
                            currentnesting = taglist[last]
                            pushentry(currentnesting)
                            currentattribute = last
                        end
                    end
                elseif subtype == rightskip_code then
                    -- a line
                    if nofcurrentcontent > 0 then
                        local r = currentcontent[nofcurrentcontent]
                        if r == hyphen then
                            if not keephyphens then
                                nofcurrentcontent = nofcurrentcontent - 1
                            end
                        elseif not somespace[r] then
                            local a = getattr(n,a_tagged) or pat
                            if a == last then
                                if trace_export then
                                    report_export("%w<!-- injecting spacing 1 (end of line, stay in element) -->",currentdepth)
                                end
                                nofcurrentcontent = nofcurrentcontent + 1
                                currentcontent[nofcurrentcontent] = " "
                            else
                                if trace_export then
                                    report_export("%w<!-- injecting spacing 1 (end of line, end of element) -->",currentdepth)
                                end
                                last = a
                                pushcontent()
                                nofcurrentcontent = nofcurrentcontent + 1
                                currentcontent[nofcurrentcontent] = " "
                                currentnesting = taglist[last]
                                pushentry(currentnesting)
                                currentattribute = last
                            end
                        end
                    end
                elseif subtype == parfillskip_code then
                    -- deal with paragaph endings (crossings) elsewhere and we quit here
                    -- as we don't want the rightskip space addition
                    return
                end
            end
        elseif id == hlist_code or id == vlist_code then
            local ai = getattr(n,a_image)
            if ai then
                local at = getattr(n,a_tagged) or pat
                if nofcurrentcontent > 0 then
                    pushcontent()
                    pushentry(currentnesting) -- ??
                end
                pushentry(taglist[at]) -- has an index, todo: flag empty element
                if trace_export then
                    report_export("%w<!-- processing image tagged %a",currentdepth,last)
                end
                last = nil
                currentparagraph = nil
            else
                -- we need to determine an end-of-line
                local list = getlist(n)
                if list then
                    local at = getattr(n,a_tagged) or pat
                    collectresults(list,n,at)
                end
            end
        elseif id == kern_code then
            local kern = getfield(n,"kern")
            if kern > 0 then
                local limit = threshold
                if p and getid(p) == glyph_code then
                    limit = fontquads[getfont(p)] / 4
                end
                if kern > limit then
                    if last and not somespace[currentcontent[nofcurrentcontent]] then
                        local a = getattr(n,a_tagged) or pat
                        if a == last then
                            if not somespace[currentcontent[nofcurrentcontent]] then
                                if trace_export then
                                    report_export("%w<!-- injecting spacing 8 (kern %p) -->",currentdepth,kern)
                                end
                                nofcurrentcontent = nofcurrentcontent + 1
                                currentcontent[nofcurrentcontent] = " "
                            end
                        elseif a then
                            -- e.g LOGO<space>LOGO
                            if trace_export then
                                report_export("%w<!-- processing kern, threshold %p, tag %s => %s -->",currentdepth,limit,last,a)
                            end
                            last = a
                            pushcontent()
                            if trace_export then
                                report_export("%w<!-- injecting spacing 9 (kern %p) -->",currentdepth,kern)
                            end
                            nofcurrentcontent = nofcurrentcontent + 1
                            currentcontent[nofcurrentcontent] = " "
                            currentnesting = taglist[last]
                            pushentry(currentnesting)
                            currentattribute = last
                        end
                    end
                end
            end
        end
        p = n
    end
end

function nodes.handlers.export(head) -- hooks into the page builder
    starttiming(treehash)
    if trace_export then
        report_export("%w<!-- start flushing page -->",currentdepth)
    end
 -- continueexport()
    restart = true

-- local function f(head,depth,pat)
--     for n in node.traverse(head) do
--         local a = n[a_tagged] or pat
--         local t = taglist[a]
--         print(depth,n,a,t and table.concat(t," "))
--         if n.id == hlist_code or n.id == vlist_code and n.list then
--             f(n.list,depth+1,a)
--         end
--     end
-- end
-- f(head,1)

    collectresults(tonut(head))
    if trace_export then
        report_export("%w<!-- stop flushing page -->",currentdepth)
    end
    stoptiming(treehash)
    return head, true
end

function builders.paragraphs.tag(head)
    noftextblocks = noftextblocks + 1
    for n in traverse_id(hlist_code,tonut(head)) do
        local subtype = getsubtype(n)
        if subtype == line_code then
            setattr(n,a_textblock,noftextblocks)
        elseif subtype == glue_code or subtype == kern_code then
            setattr(n,a_textblock,0)
        end
    end
    return false
end

do

local xmlpreamble = [[
<?xml version="1.0" encoding="UTF-8" standalone="%standalone%" ?>

<!--

    input filename   : %filename%
    processing date  : %date%
    context version  : %contextversion%
    exporter version : %exportversion%

-->

]]

    local flushtree = wrapups.flushtree

    local function wholepreamble(standalone)
        return replacetemplate(xmlpreamble, {
            standalone     = standalone and "yes" or "no",
            filename       = tex.jobname,
            date           = included.date and backends.timestamp(),
            contextversion = environment.version,
            exportversion  = exportversion,
        })
    end


local csspreamble = [[
<?xml-stylesheet type="text/css" href="%filename%" ?>
]]

local cssheadlink = [[
<link type="text/css" rel="stylesheet" href="%filename%" />
]]

    local function allusedstylesheets(cssfiles,files,path)
        local done   = { }
        local result = { }
        local extras = { }
        for i=1,#cssfiles do
            local cssfile = cssfiles[i]
            if type(cssfile) ~= "string" then
                -- error
            elseif cssfile == "export-example.css" then
                -- ignore
            elseif not done[cssfile] then
                cssfile = file.join(path,cssfile)
                report_export("adding css reference '%s'",cssfile)
                files[#files+1]   = cssfile
                result[#result+1] = replacetemplate(csspreamble, { filename = cssfile })
                extras[#extras+1] = replacetemplate(cssheadlink, { filename = cssfile })
                done[cssfile]     = true
            end
        end
        return concat(result), concat(extras)
    end

local elementtemplate = [[
/* element="%element%" detail="%detail%" chain="%chain%" */

%element%, %namespace%div.%element% {
    display: %display% ;
}]]

local detailtemplate = [[
/* element="%element%" detail="%detail%" chain="%chain%" */

%element%[detail=%detail%], %namespace%div.%element%.%detail% {
    display: %display% ;
}]]

-- <!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.1 plus MathML 2.0 plus SVG 1.1//EN" "http://www.w3.org/2002/04/xhtml-math-svg/xhtml-math-svg.dtd" >

local htmltemplate = [[
%preamble%

<html xmlns="http://www.w3.org/1999/xhtml" xmlns:math="http://www.w3.org/1998/Math/MathML">

    <head>

        <meta charset="utf-8"/>

        <title>%title%</title>

%style%

    </head>
    <body>
        <div xmlns="http://www.pragma-ade.com/context/export">

<div class="warning">Rendering can be suboptimal because there is no default/fallback css loaded.</div>

%body%

        </div>
    </body>
</html>
]]

    local displaymapping = {
        inline  = "inline",
        display = "block",
        mixed   = "inline",
    }

    local function allusedelements(basename)
        local result = { replacetemplate(namespacetemplate, {
            what            = "template",
            filename        = basename,
            namespace       = contextns,
         -- cssnamespaceurl = usecssnamespace and cssnamespaceurl or "",
            cssnamespaceurl = cssnamespaceurl,
        }) }
        for element, details in sortedhash(used) do
            if namespaces[element] then
                -- skip math
            else
                for detail, what in sortedhash(details) do
                    local nature  = what[1] or "display"
                    local chain   = what[2]
                    local display = displaymapping[nature] or "block"
                    if detail == "" then
                        result[#result+1] = replacetemplate(elementtemplate, {
                            element   = element,
                            display   = display,
                            chain     = chain,
                            namespace = usecssnamespace and namespace or "",
                        })
                    else
                        result[#result+1] = replacetemplate(detailtemplate, {
                            element   = element,
                            display   = display,
                            detail    = detail,
                            chain     = chain,
                            namespace = usecssnamespace and cssnamespace or "",
                        })
                    end
                end
            end
        end
        return concat(result,"\n\n")
    end

    local function allcontent(tree,embed)
        local result   = { }
        local embedded = embed and { }
        flushtree(result,embedded,tree.data,"display") -- we need to collect images
        result = concat(result)
        -- no need to lpeg .. fast enough
        result = gsub(result,"\n *\n","\n")
        result = gsub(result,"\n +([^< ])","\n%1")
        return result, embedded
    end

    -- local xhtmlpreamble = [[
    --     <!DOCTYPE html PUBLIC
    --         "-//W3C//DTD XHTML 1.1 plus MathML 2.0 plus SVG 1.1//EN"
    --         "http://www.w3.org/2002/04/xhtml-math-svg/xhtml-math-svg.dtd"
    --     >
    -- ]]

    local function cleanxhtmltree(xmltree)
        if xmltree then
            local implicits = { }
            local explicits = { }
            local overloads = { }
            for e in xml.collected(xmltree,"*") do
                local at = e.at
                if at then
                    local explicit = at.explicit
                    local implicit = at.implicit
                    if explicit then
                        if not explicits[explicit] then
                            explicits[explicit] = true
                            at.id = explicit
                            if implicit then
                                overloads[implicit] = explicit
                            end
                        end
                    else
                        if implicit and not implicits[implicit] then
                            implicits[implicit] = true
                            at.id = "aut:" .. implicit
                        end
                    end
                end
            end
            for e in xml.collected(xmltree,"*") do
                local at = e.at
                if at then
                    local internal = at.internal
                    local location = at.location
                    if internal then
                        if location then
                            local explicit = overloads[location]
                            if explicit then
                                at.href = "#" .. explicit
                            else
                                at.href = "#aut:" .. internal
                            end
                        else
                            at.href = "#aut:" .. internal
                        end
                    else
                        if location then
                            at.href = "#" .. location
                        else
                            local url = at.url
                            if url then
                                at.href = url
                            else
                                local file = at.file
                                if file then
                                    at.href = file
                                end
                            end
                        end
                    end
                end
            end
            return xmltree
        else
            return xml.convert('<?xml version="1.0"?>\n<error>invalid xhtml tree</error>')
        end
    end

    -- maybe the reverse: be explicit about what is permitted

    local private = {
        destination = true,
        prefix      = true,
        reference   = true,
        --
        id          = true,
        href        = true,
        --
        implicit    = true,
        explicit    = true,
        --
        url         = true,
        file        = true,
        internal    = true,
        location    = true,
        --
        name        = true, -- image name
        used        = true, -- image name
        page        = true, -- image name
        width       = true,
        height      = true,
        --
    }

    local addclicks   = true
    local f_onclick   = formatters[ [[location.href='%s']] ]
    local f_onclick   = formatters[ [[location.href='%s']] ]

    local p_cleanid   = lpeg.replacer { [":"] = "-" }
    local p_cleanhref = lpeg.Cs(lpeg.P("#") * p_cleanid)

    local p_splitter  = lpeg.Ct ( (
        lpeg.Carg(1) * lpeg.C((1-lpeg.P(" "))^1) / function(d,s) if not d[s] then d[s] = true return s end end
      * lpeg.P(" ")^0 )^1 )


    local classes = table.setmetatableindex(function(t,k)
        local v = concat(lpegmatch(p_splitter,k,1,{})," ")
        t[k] = v
        return v
    end)

    local function makeclass(tg,at)
        local detail     = at.detail
        local chain      = at.chain
        local extra      = nil
        local classes    = { }
        local nofclasses = 0
        at.detail        = nil
        at.chain         = nil
        for k, v in next, at do
            if not private[k] then
                nofclasses = nofclasses + 1
                classes[nofclasses] = k .. "-" .. v
            end
        end
        if detail and detail ~= "" then
            if chain and chain ~= "" then
                if chain ~= detail then
                    extra = classes[tg .. " " .. chain .. " " .. detail]
                elseif tg ~= detail then
                    extra = detail
                end
            elseif tg ~= detail then
                extra = detail
            end
        elseif chain and chain ~= "" then
            if tg ~= chain then
                extra = chain
            end
        end
        -- in this order
        if nofclasses > 0 then
            sort(classes)
            classes = concat(classes," ")
            if extra then
                return tg .. " " .. extra .. " " .. classes
            else
                return tg .. " " .. classes
            end
        else
            if extra then
                return tg .. " " .. extra
            else
                return tg
            end
        end
    end

    local function remap(specification,source,target)
        local comment = nil -- share comments
        for c in xml.collected(source,"*") do
            if not c.special then
                local tg = c.tg
                local ns = c.ns
                if ns == "m" then
                    if false then -- yes or no
                        c.ns = ""
                        c.at["xmlns:m"] = nil
                    end
             -- elseif tg == "a" then
             --     c.ns = ""
                else
                 -- if tg == "tabulatecell" or tg == "tablecell" then
                        local dt = c.dt
                        local nt = #dt
                        if nt == 0 or (nt == 1 and dt[1] == "") then
                            if comment then
                                c.dt = comment
                            else
                                xml.setcomment(c,"empty")
                                comment = c.dt
                            end
                        end
                 -- end
                    local at    = c.at
                    local class = nil
                    if tg == "document" then
                        at.href   = nil
                        at.detail = nil
                        at.chain  = nil
                    elseif tg == "metavariable" then
                        at.detail = "metaname-" .. at.name
                        class = makeclass(tg,at)
                    else
                        class = makeclass(tg,at)
                    end
                    local id   = at.id
                    local href = at.href
                    if id then
                        id = lpegmatch(p_cleanid,  id)   or id
                        if href then
                            href = lpegmatch(p_cleanhref,href) or href
                            c.at = {
                                class   = class,
                                id      = id,
                                href    = href,
                                onclick = addclicks and f_onclick(href) or nil,
                            }
                        else
                            c.at = {
                                class = class,
                                id    = id,
                            }
                        end
                    else
                        if href then
                            href = lpegmatch(p_cleanhref,href) or href
                            c.at = {
                                class   = class,
                                href    = href,
                                onclick = addclicks and f_onclick(href) or nil,
                            }
                        else
                            c.at = {
                                class = class,
                            }
                        end
                    end
                    c.tg = "div"
                end
            end
        end
    end

 -- local cssfile = nil  directives.register("backend.export.css", function(v) cssfile = v end)

    local addsuffix = file.addsuffix
    local joinfile  = file.join

    local embedfile = false  directives.register("export.embed",function(v) embedfile = v end)
    local embedmath = false

    local function stopexport(v)

        starttiming(treehash)
        --
        finishexport()
        --
        report_export("")
        report_export("exporting xml, xhtml and html files")
        report_export("")
        --
        wrapups.collapsetree(tree)
        wrapups.indextree(tree)
        wrapups.checktree(tree)
        wrapups.breaktree(tree)
        wrapups.finalizetree(tree)
        --
        wrapups.hashlistdata()
        --
        if type(v) ~= "string" or v == v_yes or v == "" then
            v = tex.jobname
        end

        -- we use a dedicated subpath:
        --
        -- ./jobname-export
        -- ./jobname-export/images
        -- ./jobname-export/styles
        -- ./jobname-export/styles
        -- ./jobname-export/jobname-export.xml
        -- ./jobname-export/jobname-export.xhtml
        -- ./jobname-export/jobname-export.html
        -- ./jobname-export/jobname-specification.lua
        -- ./jobname-export/styles/jobname-defaults.css
        -- ./jobname-export/styles/jobname-styles.css
        -- ./jobname-export/styles/jobname-images.css
        -- ./jobname-export/styles/jobname-templates.css

        local basename  = file.basename(v)
        local basepath  = basename .. "-export"
        local imagepath = joinfile(basepath,"images")
        local stylepath = joinfile(basepath,"styles")

        local function validpath(what,pathname)
            if lfs.isdir(pathname) then
                report_export("using exiting %s path %a",what,pathname)
                return pathname
            end
            lfs.mkdir(pathname)
            if lfs.isdir(pathname) then
                report_export("using cretated %s path %a",what,basepath)
                return pathname
            else
                report_export("unable to create %s path %a",what,basepath)
                return false
            end
        end

        if not (validpath("export",basepath) and validpath("images",imagepath) and validpath("styles",stylepath)) then
            return
        end

        -- we're now on the dedicated export subpath so we can't clash names

        local xmlfilebase           = addsuffix(basename .. "-raw","xml"  )
        local xhtmlfilebase         = addsuffix(basename .. "-tag","xhtml")
        local htmlfilebase          = addsuffix(basename .. "-div","xhtml")
        local specificationfilebase = addsuffix(basename .. "-pub","lua"  )

        local xmlfilename           = joinfile(basepath, xmlfilebase          )
        local xhtmlfilename         = joinfile(basepath, xhtmlfilebase        )
        local htmlfilename          = joinfile(basepath, htmlfilebase         )
        local specificationfilename = joinfile(basepath, specificationfilebase)
        --
        local defaultfilebase       = addsuffix(basename .. "-defaults", "css")
        local imagefilebase         = addsuffix(basename .. "-images",   "css")
        local stylefilebase         = addsuffix(basename .. "-styles",   "css")
        local templatefilebase      = addsuffix(basename .. "-templates","css")
        --
        local defaultfilename       = joinfile(stylepath,defaultfilebase )
        local imagefilename         = joinfile(stylepath,imagefilebase   )
        local stylefilename         = joinfile(stylepath,stylefilebase   )
        local templatefilename      = joinfile(stylepath,templatefilebase)

        local cssfile               = finetuning.cssfile

        -- we keep track of all used files

        local files = {
        }

        -- we always load the defaults and optionally extra css files; we also copy the example
        -- css file so that we always have the latest version

        local cssfiles = {
            defaultfilebase,
            imagefilebase,
            stylefilebase,
        }

        local examplefilename = resolvers.find_file("export-example.css")
        if examplefilename then
            local data = io.loaddata(examplefilename)
            if not data or data == "" then
                data = "/* missing css file */"
            elseif not usecssnamespace then
                data = gsub(data,cssnamespace,"")
            end
            io.savedata(defaultfilename,data)
        end

        if cssfile then
            local list = table.unique(settings_to_array(cssfile))
            for i=1,#list do
                local source = addsuffix(list[i],"css")
                local target = joinfile(stylepath,file.basename(source))
                cssfiles[#cssfiles+1] = source
                if not lfs.isfile(source) then
                    source = joinfile("../",source)
                end
                if lfs.isfile(source) then
                    report_export("copying %s",source)
                    file.copy(source,target)
                end
            end
        end

        local x_styles, h_styles = allusedstylesheets(cssfiles,files,"styles")

        -- at this point we're ready for the content; the collector also does some
        -- housekeeping and data collecting; at this point we still have an xml
        -- representation that uses verbose element names and carries information in
        -- attributes


        local data = tree.data
        for i=1,#data do
            if data[i].tg ~= "document" then
                data[i] = { }
            end
        end

        local result, embedded = allcontent(tree,embedmath) -- embedfile is for testing

        local attach = backends.nodeinjections.attachfile

        if embedfile and attach then
            -- only for testing
            attach {
                data       = concat{ wholepreamble(true), result },
                name       = file.basename(xmlfilename),
                registered = "export",
                title      = "raw xml export",
                method     = v_hidden,
                mimetype   = "application/mathml+xml",
            }
        end
     -- if embedmath and attach then
     --     local refs = { }
     --     for k, v in sortedhash(embedded) do
     --         attach {
     --             data       = v,
     --             file       = file.basename(k),
     --             name       = file.addsuffix(k,"xml"),
     --             registered = k,
     --             reference  = k,
     --             title      = "xml export snippet: " .. k,
     --             method     = v_hidden,
     --             mimetype   = "application/mathml+xml",
     --         }
     --         refs[k] = 0
     --     end
     -- end

        result = concat {
            wholepreamble(true),
            x_styles, -- adds to files
            result,
        }

        cssfiles = table.unique(cssfiles)

        -- we're now ready for saving the result in the xml file

        report_export("saving xml data in %a",xmlfilename)
        io.savedata(xmlfilename,result)

        report_export("saving css image definitions in %a",imagefilename)
        io.savedata(imagefilename,wrapups.allusedimages(basename))

        report_export("saving css style definitions in %a",stylefilename)
        io.savedata(stylefilename,wrapups.allusedstyles(basename))

        report_export("saving css template in %a",templatefilename)
        io.savedata(templatefilename,allusedelements(basename))

        -- additionally we save an xhtml file; for that we load the file as xml tree

        report_export("saving xhtml variant in %a",xhtmlfilename)

        local xmltree = cleanxhtmltree(xml.convert(result))

        xml.save(xmltree,xhtmlfilename)

        -- now we save a specification file that can b eused for generating an epub file

        -- looking at identity is somewhat redundant as we also inherit from interaction
        -- at the tex end

        local identity = interactions.general.getidentity()

        local specification = {
            name        = file.removesuffix(v),
            identifier  = os.uuid(),
            images      = wrapups.uniqueusedimages(),
            imagefile   = joinfile("styles",imagefilebase),
            imagepath   = "images",
            stylepath   = "styles",
            xmlfiles    = { xmlfilebase },
            xhtmlfiles  = { xhtmlfilebase },
            htmlfiles   = { htmlfilebase },
            styles      = cssfiles,
            htmlroot    = htmlfilebase,
            language    = languagenames[texgetcount("mainlanguagenumber")],
            title       = validstring(finetuning.title) or validstring(identity.title),
            subtitle    = validstring(finetuning.subtitle) or validstring(identity.subtitle),
            author      = validstring(finetuning.author) or validstring(identity.author),
            firstpage   = validstring(finetuning.firstpage),
            lastpage    = validstring(finetuning.lastpage),
        }

        report_export("saving specification in %a",specificationfilename,specificationfilename)

        io.savedata(specificationfilename,table.serialize(specification,true))

        -- the html export for epub is different in the sense that it uses div's instead of
        -- specific tags

        report_export("saving div based alternative in %a",htmlfilename)

        remap(specification,xmltree)

        local title = specification.title

        if not title or title == "" then
            title = "no title" -- believe it or not, but a <title/> can prevent viewing in browsers
        end

        local variables = {
            style    = h_styles,
            body     = xml.tostring(xml.first(xmltree,"/div")),
            preamble = wholepreamble(false),
            title    = title,
        }

        io.savedata(htmlfilename,replacetemplate(htmltemplate,variables,"xml"))

        -- finally we report how an epub file can be made (using the specification)

        report_export("")
        report_export('create epub with: mtxrun --script epub --make "%s" [--purge --rename --svgmath]',file.nameonly(basename))
        report_export("")

        stoptiming(treehash)
    end

    local appendaction = nodes.tasks.appendaction
    local enableaction = nodes.tasks.enableaction

    function structurestags.setupexport(t)
        merge(finetuning,t)
        keephyphens      = finetuning.hyphen == v_yes
        exportproperties = finetuning.properties
        if exportproperties == v_no then
            exportproperties = false
        end
    end

    local function startexport(v)
        if v and not exporting then
            report_export("enabling export to xml")
         -- not yet known in task-ini
            appendaction("shipouts","normalizers", "nodes.handlers.export")
         -- enableaction("shipouts","nodes.handlers.export")
            enableaction("shipouts","nodes.handlers.accessibility")
            enableaction("math",    "noads.handlers.tags")
         -- appendaction("finalizers","lists","builders.paragraphs.tag")
         -- enableaction("finalizers","builders.paragraphs.tag")
            luatex.registerstopactions(structurestags.finishexport)
            exporting = v
        end
    end

    function structurestags.finishexport()
        if exporting then
            stopexport(exporting)
            exporting = false
        end
    end

    directives.register("backend.export",startexport) -- maybe .name

    statistics.register("xml exporting time", function()
        if exporting then
            return string.format("%s seconds, version %s", statistics.elapsedtime(treehash),exportversion)
        end
    end)

end

-- These are called at the tex end:

implement {
    name      = "setupexport",
    actions   = structurestags.setupexport,
    arguments = {
        {
            { "align" },
            { "bodyfont", "dimen" },
            { "width", "dimen" },
            { "properties" },
            { "hyphen" },
            { "title" },
            { "subtitle" },
            { "author" },
            { "firstpage" },
            { "lastpage" },
            { "svgstyle" },
            { "cssfile" },
        }
    }
}

implement {
    name      = "finishexport",
    actions   = structurestags.finishexport,
}

implement {
    name      = "settagitemgroup",
    actions   = structurestags.setitemgroup,
    arguments = { "boolean", "integer", "string" }
}

implement {
    name      = "settagitem",
    actions   = structurestags.setitem,
    arguments = "string"
}

implement {
    name      = "settagdelimitedsymbol",
    actions   = structurestags.settagdelimitedsymbol,
    arguments = "string"
}

implement {
    name      = "settagsubsentencesymbol",
    actions   = structurestags.settagsubsentencesymbol,
    arguments = "string"
}

implement {
    name      = "settagsynonym",
    actions   = structurestags.setsynonym,
    arguments = "string"
}

implement {
    name      = "settagsorting",
    actions   = structurestags.setsorting,
    arguments = "string"
}

implement {
    name      = "settagnotation",
    actions   = structurestags.setnotation,
    arguments = { "string", "integer" }
}

implement {
    name      = "settagnotationsymbol",
    actions   = structurestags.setnotationsymbol,
    arguments = { "string", "integer" }
}

implement {
    name      = "settaghighlight",
    actions   = structurestags.sethighlight,
    arguments = { "string", "integer" }
}

implement {
    name      = "settagfigure",
    actions    = structurestags.setfigure,
    arguments = { "string", "string", "string", "dimen", "dimen", "string" }
}

implement {
    name      = "settagcombination",
    actions   = structurestags.setcombination,
    arguments = { "integer", "integer" }
}

implement {
    name      = "settagtablecell",
    actions   = structurestags.settablecell,
    arguments = { "integer", "integer", "integer" }
}

implement {
    name      = "settagtabulatecell",
    actions   = structurestags.settabulatecell,
    arguments = "integer"
}

implement {
    name      = "settagregister",
    actions   = structurestags.setregister,
    arguments = { "string", "integer" }
}

implement {
    name      = "settaglist",
    actions   = structurestags.setlist,
    arguments = "integer"
}

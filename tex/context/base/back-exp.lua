if not modules then modules = { } end modules ['back-exp'] = {
    version   = 1.001,
    comment   = "companion to back-exp.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- depth can go away (autodepth nu)


-- language       -> only mainlanguage, local languages should happen through start/stoplanguage
-- tocs/registers -> maybe add a stripper (i.e. just don't flush entries in final tree)

-- Because we need to look ahead we now always build a tree (this was optional in
-- the beginning). The extra overhead in the frontend is neglectable.

-- We can consider replacing attributes by the hash entry ... slower
-- in resolving but it's still quite okay.

-- todo: less attributes e.g. internal only first node
-- todo: build xml tree in mem (handy for cleaning)

-- delimited: left/right string (needs marking)

-- we can optimize the code ... currently the overhead is some 10% for xml + html

-- option: pack strings each page so that we save memory

local nodecodes       = nodes.nodecodes
local traverse_nodes  = node.traverse
local hlist_code      = nodecodes.hlist
local vlist_code      = nodecodes.vlist

local function locate(start,wantedid,wantedsubtype)
    for n in traverse_nodes(start) do
        local id = n.id
        if id == wantedid then
            if not wantedsubtype or n.subtype == wantedsubtype then
                return n
            end
        elseif id == hlist_code or id == vlist_code then
            local found = locate(n.list,wantedid,wantedsubtype)
            if found then
                return found
            end
        end
    end
end

nodes.locate =  locate

local next, type = next, type
local format, match, concat, rep, sub, gsub, gmatch, find = string.format, string.match, table.concat, string.rep, string.sub, string.gsub, string.gmatch, string.find
local lpegmatch = lpeg.match
local utfchar, utfbyte, utfsub, utfgsub = utf.char, utf.byte, utf.sub, utf.gsub
local insert, remove = table.insert, table.remove
local topoints = number.topoints
local utfvalues = string.utfvalues

local trace_export = false  trackers.register  ("structures.export",            function(v) trace_export = v end)
local less_state   = false  directives.register("structures.export.lessstate",  function(v) less_state   = v end)
local show_comment = true   directives.register("structures.export.comment",    function(v) show_comment = v end)

local report_export     = logs.reporter("backend","export")

local nodes             = nodes
local attributes        = attributes
local variables         = interfaces.variables

local settings_to_array = utilities.parsers.settings_to_array

local setmetatableindex = table.setmetatableindex
local tasks             = nodes.tasks
local fontchar          = fonts.hashes.characters
local fontquads         = fonts.hashes.quads
local languagenames     = languages.numbers

local nodecodes         = nodes.nodecodes
local skipcodes         = nodes.skipcodes
local whatsitcodes      = nodes.whatsitcodes
local listcodes         = nodes.listcodes

local hlist_code        = nodecodes.hlist
local vlist_code        = nodecodes.vlist
local glyph_code        = nodecodes.glyph
local glue_code         = nodecodes.glue
local kern_code         = nodecodes.kern
local disc_code         = nodecodes.disc
local insert_code       = nodecodes.insert
local whatsit_code      = nodecodes.whatsit
local refximage_code    = whatsitcodes.pdfrefximage
local localpar_code     = whatsitcodes.localpar

local userskip_code     = skipcodes.userskip
local rightskip_code    = skipcodes.rightskip
local parfillskip_code  = skipcodes.parfillskip
local spaceskip_code    = skipcodes.spaceskip
local xspaceskip_code   = skipcodes.xspaceskip

local line_code         = listcodes.line

local a_characters      = attributes.private('characters')
local a_exportstatus    = attributes.private('exportstatus')

local a_tagged          = attributes.private('tagged')
local a_image           = attributes.private('image')

local a_taggedalign     = attributes.private("taggedalign")
local a_taggedcolumns   = attributes.private("taggedcolumns")
local a_taggedrows      = attributes.private("taggedrows")
local a_taggedpar       = attributes.private("taggedpar")
local a_taggedpacked    = attributes.private("taggedpacked")
local a_taggedsymbol    = attributes.private("taggedsymbol")
local a_taggedinsert    = attributes.private("taggedinsert")
local a_taggedtag       = attributes.private("taggedtag")
local a_mathcategory    = attributes.private("mathcategory")
local a_mathmode        = attributes.private("mathmode")

local a_reference       = attributes.private('reference')

local a_textblock       = attributes.private("textblock")

local has_attribute     = node.has_attribute
local set_attribute     = node.set_attribute
local traverse_id       = node.traverse_id
local traverse_nodes    = node.traverse
local slide_nodelist    = node.slide
local texattribute      = tex.attribute
local unsetvalue        = attributes.unsetvalue
local locate_node       = nodes.locate

local references        = structures.references
local structurestags    = structures.tags
local taglist           = structurestags.taglist
local properties        = structurestags.properties
local userdata          = structurestags.userdata -- might be combines with taglist
local tagdata           = structurestags.data
local tagmetadata       = structurestags.metadata

local starttiming       = statistics.starttiming
local stoptiming        = statistics.stoptiming

-- todo: more locals (and optimize)

local exportversion     = "0.22"

local nofcurrentcontent = 0 -- so we don't free (less garbage collection)
local currentcontent    = { }
local currentnesting    = nil
local currentattribute  = nil
local last              = nil
local currentparagraph  = nil

local noftextblocks     = 0

local attributehash     = { } -- to be considered: set the values at the tex end
local hyphen            = utfchar(0xAD) -- todo: also emdash etc
local colonsplitter     = lpeg.splitat(":")
local dashsplitter      = lpeg.splitat("-")
local threshold         = 65536
local indexing          = false

local treestack         = { }
local nesting           = { }
local currentdepth      = 0

local tree              = { data = { }, depth = 0, fulltag == "root" } -- root
local treeroot          = tree
local treehash          = { }
local extras            = { }
local checks            = { }
local nofbreaks         = 0
local used              = { }
local exporting         = false
local restart           = false
local specialspaces     = { [0x20] = " "  }               -- for conversion
local somespace         = { [0x20] = true, [" "] = true } -- for testing
local entities          = { ["&"] = "&amp;", [">"] = "&gt;", ["<"] = "&lt;" }

local defaultnature     = "mixed" -- "inline"

setmetatableindex(used, function(t,k)
    if k then
        local v = { }
        t[k] = v
        return v
    end
end)

setmetatableindex(specialspaces, function(t,k)
    local v = utfchar(k)
    t[k] = v
    entities[v] = format("&#%X;",k)
    somespace[k] = true
    somespace[v] = true
    return v
end)


local namespaced = {
    -- filled on
}

local namespaces = {
    msubsup    = "m",
    msub       = "m",
    msup       = "m",
    mn         = "m",
    mi         = "m",
    ms         = "m",
    mo         = "m",
    mtext      = "m",
    mrow       = "m",
    mfrac      = "m",
    mroot      = "m",
    msqrt      = "m",
    munderover = "m",
    munder     = "m",
    mover      = "m",
    merror     = "m",
    math       = "m",
    mrow       = "m",
    mtable     = "m",
    mtr        = "m",
    mtd        = "m",
    mfenced    = "m",
    maction    = "m",
    mspace     = "m",
}

setmetatableindex(namespaced, function(t,k)
    if k then
        local namespace = namespaces[k]
        local v = namespace and namespace .. ":" .. k or k
        t[k] = v
        return v
    end
end)

-- local P, C, Cc = lpeg.P, lpeg.C, lpeg.Cc
--
-- local dash, colon = P("-"), P(":")
--
-- local precolon, predash, rest = P((1-colon)^1), P((1-dash )^1), P(1)^1
--
-- local tagsplitter = C(precolon) * colon * C(predash) * dash * C(rest) +
--                     C(predash)  * dash  * Cc(nil)           * C(rest)

local listdata = { }

local function hashlistdata()
    local c = structures.lists.collected
    for i=1,#c do
        local ci = c[i]
        local tag = ci.references.tag
        if tag then
            listdata[ci.metadata.kind .. ":" .. ci.metadata.name .. "-" .. tag] = ci
        end
    end
end

local spaces = { } -- watch how we also moved the -1 in depth-1 to the creator

setmetatableindex(spaces, function(t,k)
    if not k then
        k = 1
    end
    local s = rep("  ",k-1)
    t[k] = s
    return s
end)

function structurestags.setattributehash(fulltag,key,value)
    if type(fulltag) == "number" then
        fulltag = taglist[fulltag]
        if fulltag then
            fulltag = fulltag[#fulltag]
        end
    end
    if fulltag then
        local ah = attributehash[fulltag] -- could be metatable magic
        if not ah then
            ah = { }
            attributehash[fulltag] = ah
        end
        ah[key] = value
    end
end

properties.vspace = { export = "break",     nature = "display" }
----------------- = { export = "pagebreak", nature = "display" }

local function makebreaklist(list)
    nofbreaks = nofbreaks + 1
    local t = { }
    if list then
        for i=1,#list do
            t[i] = list[i]
        end
    end
    t[#t+1] = "break-" .. nofbreaks -- maybe no number
    return t
end

local breakattributes = {
    type = "collapse"
}

local function makebreaknode(node) -- maybe no fulltag
    nofbreaks = nofbreaks + 1
    return {
        tg         = "break",
        fulltag    = "break-" .. nofbreaks,
        n          = nofbreaks,
        depth      = node.depth,
        element    = "break",
        nature     = "display",
     -- attributes = breakattributes,
     -- data       = { }, -- not needed
     -- attribute  = 0, -- not needed
     -- parnumber  = 0,
    }
end

local fields = { "title", "subtitle", "author", "keywords" }

local function checkdocument(root)
    local data = root.data
    if data then
        for i=1,#data do
            local di = data[i]
            if type(di) == "table" then
                if di.tg == "ignore" then
                    di.element = ""
                else
                    checkdocument(di)
                end
            end
        end
    end
end

function extras.document(result,element,detail,n,fulltag,di)
    result[#result+1] = format(" language=%q",languagenames[tex.count.mainlanguagenumber])
    if not less_state then
        result[#result+1] = format(" file=%q",tex.jobname)
        result[#result+1] = format(" date=%q",os.date())
        result[#result+1] = format(" context=%q",environment.version)
        result[#result+1] = format(" version=%q",exportversion)
        result[#result+1] = format(" xmlns:m=%q","http://www.w3.org/1998/Math/MathML")
        local identity = interactions.general.getidentity()
        for i=1,#fields do
            local key   = fields[i]
            local value = identity[key]
            if value and value ~= "" then
                result[#result+1] = format(" %s=%q",key,value)
            end
        end
    end
    checkdocument(di)
end

local snames, snumbers = { }, { }

function structurestags.setitemgroup(packed,symbol,di)
    local s = snumbers[symbol]
    if not s then
        s = #snames + 1
        snames[s], snumbers[symbol] = symbol, s
    end
    texattribute[a_taggedpacked] = packed and 1 or unsetvalue
    texattribute[a_taggedsymbol] = s
end

-- todo: per class

local synonymnames, synonymnumbers = { }, { } -- can be one hash

function structurestags.setsynonym(class,tag)
    local s = synonymnumbers[tag]
    if not s then
        s = #synonymnames + 1
        synonymnames[s], synonymnumbers[tag] = tag, s
    end
    texattribute[a_taggedtag] = s
end

local sortingnames, sortingnumbers = { }, { } -- can be one hash

function structurestags.setsorting(class,tag)
    local s = sortingnumbers[tag]
    if not s then
        s = #sortingnames + 1
        sortingnames[s], sortingnumbers[tag] = tag, s
    end
    texattribute[a_taggedtag] = s
end

local insertids = { }

function structurestags.setdescriptionid(tag,n)
    local nd = structures.notes.get(tag,n) -- todo: use listdata instead
    if nd then
        local r = nd.references
        texattribute[a_taggedinsert] = r.internal or unsetvalue
    else
        texattribute[a_taggedinsert] = unsetvalue
    end
end

function extras.descriptiontag(result,element,detail,n,fulltag,di)
    local hash = attributehash[fulltag]
    if hash then
        local v = hash.insert
        v = v and insertids[v]
        if v then
            result[#result+1] = format(" insert='%s'",v)
        end
    end
end

function extras.descriptionsymbol(result,element,detail,n,fulltag,di)
    local hash = attributehash[fulltag]
    if hash then
        local v = hash.insert
        v = v and insertids[v]
        if v then
            result[#result+1] = format(" insert='%s'",v)
        end
    end
end

function extras.synonym(result,element,detail,n,fulltag,di)
    local hash = attributehash[fulltag]
    if hash then
        local v = hash.tag
        v = v and synonymnames[v]
        if v then
            result[#result+1] = format(" tag='%s'",v)
        end
    end
end

function extras.sorting(result,element,detail,n,fulltag,di)
    local hash = attributehash[fulltag]
    if hash then
        local v = hash.tag
        v = v and sortingnames[v]
        if v then
            result[#result+1] = format(" tag='%s'",v)
        end
    end
end

function extras.image(result,element,detail,n,fulltag,di)
    local hash = attributehash[fulltag]
    if hash then
        local v = hash.imageindex
        if v then
            local figure = img.ofindex(v)
            if figure then
                local fullname = figure.filepath
                local name = file.basename(fullname)
                local path = file.dirname(fullname)
                local page = figure.page or 1
                if name ~= "" then
                    result[#result+1] = format(" name='%s'",name)
                end
                if path ~= "" then
                    result[#result+1] = format(" path='%s'",path)
                end
                if page > 1 then
                    result[#result+1] = format(" page='%s'",page)
                end
            end
        end
    end
end

-- quite some code deals with exporting references  --

local evaluators = { }
local specials   = { }

evaluators.inner = function(result,var)
    local inner = var.inner
    if inner then
        result[#result+1] = format(" location='%s'",inner)
    end
end

evaluators.outer = function(result,var)
    local file, url = references.checkedfileorurl(var.outer,var.outer)
    if url then
        result[#result+1] = format(" url='%s'",url)
    elseif file then
        result[#result+1] = format(" file='%s'",file)
    end
end

evaluators["outer with inner"] = function(result,var)
    local file = references.checkedfile(var.f)
    if file then
        result[#result+1] = format(" file='%s'",file)
    end
    local inner = var.inner
    if inner then
        result[#result+1] = format(" location='%s'",inner)
    end
end

evaluators.special = function(result,var)
    local handler = specials[var.special]
    if handler then
        handler(result,var)
    end
end

evaluators["special outer with operation"]     = evaluators.special
evaluators["special operation"]                = evaluators.special
evaluators["special operation with arguments"] = evaluators.special

function specials.url(result,var)
    local url = references.checkedurl(var.operation)
    if url then
        result[#result+1] = format(" url='%s'",url)
    end
end

function specials.file(result,var)
    local file = references.checkedfile(var.operation)
    if file then
        result[#result+1] = format(" file='%s'",file)
    end
end

function specials.fileorurl(result,var)
    local file, url = references.checkedfileorurl(var.operation,var.operation)
    if url then
        result[#result+1] = format(" url='%s'",url)
    elseif file then
        result[#result+1] = format(" file='%s'",file)
    end
end

function specials.internal(result,var)
    local internal = references.checkedurl(var.operation)
    if internal then
        result[#result+1] = format(" location='aut:%s'",internal)
    end
end

local function adddestination(result,references) -- todo: specials -> exporters and then concat
    if references then
        local reference = references.reference
        if reference and reference ~= "" then
            local prefix = references.prefix
            if prefix and prefix ~= "" then
                result[#result+1] = format(" prefix='%s'",prefix)
            end
            result[#result+1] = format(" destination='%s'",reference)
            for i=1,#references do
                local r = references[i]
                local e = evaluators[r.kind]
                if e then
                    e(result,r)
                end
            end
        end
    end
end

local function addreference(result,references)
    if references then
        local reference = references.reference
        if reference and reference ~= "" then
            local prefix = references.prefix
            if prefix and prefix ~= "" then
                result[#result+1] = format(" prefix='%s'",prefix)
            end
            result[#result+1] = format(" reference='%s'",reference)
        end
        local internal = references.internal
        if internal and internal ~= "" then
            result[#result+1] = format(" location='aut:%s'",internal)
        end
    end
end

function extras.link(result,element,detail,n,fulltag,di)
    -- for instance in lists a link has nested elements and no own text
    local hash = attributehash[fulltag]
    if hash then
        local references = hash.reference
        if references then
            adddestination(result,structures.references.get(references))
        end
        return true
    else
        local data = di.data
        if data then
            for i=1,#data do
                local di = data[i]
                if di and extras.link(result,element,detail,n,di.fulltag,di) then
                    return true
                end
            end
        end
    end
end

local automathrows   = true  directives.register("backend.export.math.autorows",   function(v) automathrows   = v end)
local automathapply  = true  directives.register("backend.export.math.autoapply",  function(v) automathapply  = v end)
local automathnumber = true  directives.register("backend.export.math.autonumber", function(v) automathnumber = v end)
local automathstrip  = true  directives.register("backend.export.math.autostrip",  function(v) automathstrip  = v end)

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

local function checkmath(root) -- we can provide utf.toentities as an option
    local data = root.data
    if data then
        local ndata = #data
        local roottg = root.tg
        if roottg == "msubsup" then
            local nucleus, superscript, subscript
            for i=1,ndata do
                if type(data[i]) == "table" then
                    if not nucleus then
                        nucleus = i
                    elseif not superscript then
                        superscript = i
                    elseif not subscript then
                        subscript = i
                    else
                        -- error
                    end
                end
            end
            if superscript and subscript then
                local sup, sub = data[superscript], data[subscript]
                data[superscript], data[subscript] = sub, sup
             -- sub.__o__, sup.__o__ = subscript, superscript
                sub.__i__, sup.__i__ = superscript, subscript
            end
        elseif roottg == "mfenced" then
            local new, n = { }, 0
            local attributes = { }
            root.attributes = attributes
            for i=1,ndata do
                local di = data[i]
                if type(di) == "table" then
                    local tg = di.tg
                    if tg == "mleft" then
                        attributes.left   = tostring(di.data[1].data[1])
                    elseif tg == "mmiddle" then
                        attributes.middle = tostring(di.data[1].data[1])
                    elseif tg == "mright" then
                        attributes.right  = tostring(di.data[1].data[1])
                    else
                        n = n + 1
                        di.__i__ = n
                        new[n] = di
                    end
                else
                    n = n + 1
                    new[n] = di
                end
            end
            root.data = new
            ndata = n
        end
        if ndata == 0 then
            return
        elseif ndata == 1 then
            local d = data[1]
            if type(d) ~= "table" then
                return -- can be string or false
            elseif #root.data == 1 then
                local tg = d.tg
                if automathrows and roottg == "mrow" then
                    -- maybe just always ! check spec first
                    if tg == "mrow" or tg == "mfenced" or tg == "mfrac" or tg == "mroot" then
                        root.skip = "comment"
                    elseif tg == "mo" then
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
            if di and type(di) == "table" then
                local tg = di.tg
                local detail = di.detail
                if tg == "math" then
                 -- di.element = "mrow" -- when properties
                    di.skip = "comment"
                    checkmath(di)
                    i = i + 1
                elseif tg == "mover" or tg == "munder" or tg == "munderover" then
                    if detail == "accent" then
                        di.attributes = { accent = "true" }
                        di.detail = nil
                    end
                    checkmath(di)
                    i = i + 1
                elseif tg == "break" then
                    di.skip = "comment"
                    i = i + 1
                elseif tg == "mrow" and detail then
                    di.detail = nil
                    checkmath(di)
                    di = {
                        element    = "maction",
                        nature     = "display",
                        depth      = di.depth,
                        attributes = { actiontype = detail },
                        data       = { di },
                        n          = 0,
                    }
                    data[i] = di
                    i = i + 1
                elseif detail then
                 -- no checkmath(di) here
                    local category = tonumber(detail) or 0
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
                                di.data = { tag }
                            end
                            if apply then
                                di.after = {
                                    {
                                        element = "mo",
                                     -- comment = "apply function",
                                     -- data    = { utfchar(0x2061) },
                                        data    = { "&#x2061;" },
                                        nature  = "mixed",
                                        depth   = di.depth,
                                    }
                                }
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
                                        di.after = {
                                            {
                                                element = "mo",
                                             -- comment = "apply function",
                                             -- data    = { utfchar(0x2061) },
                                                data    = { "&#x2061;" },
                                                nature  = "mixed",
                                                depth   = di.depth,
                                            }
                                        }
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
            else -- can be string or boolean
                if parenttg ~= "mtext" and di == " " then
                    data[i] = false
                end
                i = i + 1
            end
        end
    end
end

function stripmath(di)
    local tg = di.tg
    if tg == "mtext" or tg == "ms" then
        return di
    else
        local data = di.data
        local ndata = #data
        local n = 0
        for i=1,ndata do
            local di = data[i]
            if type(di) == "table" then
                di = stripmath(di)
            end
            if not di or di == " " or di == "" then
                -- skip
            elseif type(di) == "table" then
                n = n + 1
                di.__i__ = n
                data[n] = di
            else
                n = n + 1
                data[n] = di
            end
        end
        for i=ndata,n+1,-1 do
            data[i] = nil
        end
        if #data > 0 then
            return di
        end
    end
end

function checks.math(di)
    local hash = attributehash[di.fulltag]
    local mode = (hash and hash.mode) == "display" and "block" or "inline"
    di.attributes = {
        display = mode
    }
    -- can be option if needed:
    if mode == "inline" then
        di.nature = "mixed" -- else spacing problem (maybe inline)
    else
        di.nature = "display"
    end
    if automathstrip then
        stripmath(di)
    end
    checkmath(di)
end

local a, z, A, Z = 0x61, 0x7A, 0x41, 0x5A

function extras.mi(result,element,detail,n,fulltag,di)
    local str = di.data[1]
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

function extras.section(result,element,detail,n,fulltag,di)
    local data = listdata[fulltag]
    if data then
        addreference(result,data.references)
        return true
    else
        local data = di.data
        if data then
            for i=1,#data do
                local di = data[i]
                if di then
                    local ft = di.fulltag
                    if ft and extras.section(result,element,detail,n,ft,di) then
                        return true
                    end
                end
            end
        end
    end
end

function extras.float(result,element,detail,n,fulltag,di)
    local data = listdata[fulltag]
    if data then
        addreference(result,data.references)
        return true
    else
        local data = di.data
        if data then
            for i=1,#data do
                local di = data[i]
                if di and extras.section(result,element,detail,n,di.fulltag,di) then
                    return true
                end
            end
        end
    end
end

function extras.itemgroup(result,element,detail,n,fulltag,di)
    local data = di.data
    if data then
        for i=1,#data do
            local di = data[i]
            if type(di) == "table" and di.tg == "item" then
                local ddata = di.data
                for i=1,#ddata do
                    local ddi = ddata[i]
                    if type(ddi) == "table" then
                        local tg = ddi.tg
                        if tg == "itemtag" or tg == "itemcontent" then
                            local hash = attributehash[ddi.fulltag]
                            if hash then
                                local v = hash.packed
                                if v and v == 1 then
                                    result[#result+1] = " packed='yes'"
                                end
                                local v = hash.symbol
                                if v then
                                    result[#result+1] = format(" symbol='%s'",snames[v])
                                end
                                return
                            end
                        end
                    end
                end
            end
        end
    end
end

function extras.tablecell(result,element,detail,n,fulltag,di)
    local hash = attributehash[fulltag]
    if hash then
        local v = hash.align
        if not v or v == 0 then
            -- normal
        elseif v == 1 then
            result[#result+1] = " align='flushright'"
        elseif v == 2 then
            result[#result+1] = " align='middle'"
        elseif v == 3 then
            result[#result+1] = " align='flushleft'"
        end
        local v = hash.columns
        if v and v > 1 then
            result[#result+1] = format(" columns='%s'",v)
        end
        local v = hash.rows
        if v and v > 1 then
            result[#result+1] = format(" rows='%s'",v)
        end
    end
end

function extras.tabulatecell(result,element,detail,n,fulltag,di)
    local hash = attributehash[fulltag]
    if hash then
        local v = hash.align
        if not v or v == 0 then
            -- normal
        elseif v == 1 then
            result[#result+1] = " align='flushright'"
        elseif v == 2 then
            result[#result+1] = " align='middle'"
        elseif v == 3 then
            result[#result+1] = " align='flushleft'"
        end
    end
end

-- flusher

local linedone    = false -- can go ... we strip newlines anyway
local inlinedepth = 0

local function emptytag(result,element,nature,depth)
    if linedone then
        result[#result+1] = format("%s<%s/>\n",spaces[depth],namespaced[element])
    else
        result[#result+1] = format("\n%s<%s/>\n",spaces[depth],namespaced[element])
    end
    linedone = false
end

local function btag(result,element,nature,depth)
    if linedone then
        result[#result+1] = format("%s<%s>\n",spaces[depth],namespaced[element])
    else
        result[#result+1] = format("\n%s<%s>\n",spaces[depth],namespaced[element])
    end
    linedone = false
end

local function etag(result,element,nature,depth)
    if linedone then
        result[#result+1] = format("%s</%s>\n",spaces[depth],namespaced[element])
    else
        result[#result+1] = format("\n%s</%s>\n",spaces[depth],namespaced[element])
    end
    linedone = false
end

local function begintag(result,element,nature,depth,di,skip)
    -- if needed we can use a local result with xresult
--~ local result = { }
    local detail  = di.detail
    local n       = di.n
    local fulltag = di.fulltag
    local comment = di.comment
    if nature == "inline" then
        linedone = false
        inlinedepth = inlinedepth + 1
        if show_comment and comment then
            result[#result+1] = format("<!-- %s -->",comment)
        end
    elseif nature == "mixed" then
        if inlinedepth > 0 then
            if show_comment and comment then
                result[#result+1] = format("<!-- %s -->",comment)
            end
        elseif linedone then
            result[#result+1] = spaces[depth]
            if show_comment and comment then
                result[#result+1] = format("<!-- %s -->",comment)
            end
        else
            result[#result+1] = format("\n%s",spaces[depth])
            linedone = false
            if show_comment and comment then
                result[#result+1] = format("<!-- %s -->\n%s",comment,spaces[depth])
            end
        end
        inlinedepth = inlinedepth + 1
    else
        if inlinedepth > 0 then
            if show_comment and comment then
                result[#result+1] = format("<!-- %s -->",comment)
            end
        elseif linedone then
            result[#result+1] = spaces[depth]
            if show_comment and comment then
                result[#result+1] = format("<!-- %s -->",comment)
            end
        else
            result[#result+1] = format("\n%s",spaces[depth]) -- can introduced extra line in mixed+mixed (filtered later on)
            linedone = false
            if show_comment and comment then
                result[#result+1] = format("<!-- %s -->\n%s",comment,spaces[depth])
            end
        end
    end
    if skip == "comment" then
        if show_comment then
            result[#result+1] = format("<!-- begin %s -->",namespaced[element])
        end
    elseif skip then
        -- ignore
    else
        result[#result+1] = format("<%s",namespaced[element])
        if detail then
            result[#result+1] = format(" detail=%q",detail)
        end
        if indexing and n then
            result[#result+1] = format(" n=%q",n)
        end
        local extra = extras[element]
        if extra then
            extra(result,element,detail,n,fulltag,di)
        end
        local u = userdata[fulltag]
        if u then
            for k, v in next, u do
                result[#result+1] = format(" %s=%q",k,v)
            end
        end
        local a = di.attributes
        if a then
            for k, v in next, a do
                result[#result+1] = format(" %s=%q",k,v)
            end
        end
        result[#result+1] = ">"
    end
    if inlinedepth > 0 then
    elseif nature == "display" then
        result[#result+1] = "\n"
        linedone = true
    end
--~ xresult[#xresult+1] = concat(result)
    used[element][detail or ""] = nature -- for template css
    local metadata = tagmetadata[fulltag]
    if metadata then
     -- used[element] = "mixed"
        metadata = table.toxml(metadata,"metadata",true,depth*2,2) -- nobanner
        if not linedone then
            result[#result+1] = format("\n%s\n",metadata)
        else
            result[#result+1] = format("%s\n",metadata)
        end
        linedone = true
    end
end

local function endtag(result,element,nature,depth,skip)
    if nature == "display" then
        if inlinedepth == 0 then
            if not linedone then
                result[#result+1] = "\n"
            end
            if skip == "comment" then
                if show_comment then
                    result[#result+1] = format("%s<!-- end %s -->\n",spaces[depth],namespaced[element])
                end
            elseif skip then
                -- ignore
            else
                result[#result+1] = format("%s</%s>\n",spaces[depth],namespaced[element])
            end
            linedone = true
        else
            if skip == "comment" then
                if show_comment then
                    result[#result+1] = format("<!-- end %s -->",namespaced[element])
                end
            elseif skip then
                -- ignore
            else
                result[#result+1] = format("</%s>",namespaced[element])
            end
        end
    else
        inlinedepth = inlinedepth - 1
        if skip == "comment" then
            if show_comment then
                result[#result+1] = format("<!-- end %s -->",namespaced[element])
            end
        elseif skip then
            -- ignore
        else
            result[#result+1] = format("</%s>",namespaced[element])
        end
        linedone = false
    end
end

local function flushtree(result,data,nature,depth)
    depth = depth + 1
    local nofdata = #data
    for i=1,nofdata do
        local di = data[i]
        if not di then -- or di == ""
            -- whatever
        elseif type(di) == "string" then
            -- already has breaks
            di = utfgsub(di,".",entities) -- new
            if i == nofdata and sub(di,-1) == "\n" then
                if nature == "inline" or nature == "mixed" then
                    result[#result+1] = sub(di,1,-2)
                else
                    result[#result+1] = sub(di,1,-2)
                    result[#result+1] = " "
                end
            else
                result[#result+1] = di
            end
            linedone = false
        elseif not di.collapsed then -- ignore collapsed data (is appended, reconstructed par)
            local element = di.element
            if element == "break" then -- or element == "pagebreak"
                emptytag(result,element,nature,depth)
            elseif element == "" or di.skip == "ignore" then
                -- skip
            else
                if di.before then
                    flushtree(result,di.before,nature,depth)
                end
                local natu = di.nature
                local skip = di.skip
                if di.breaknode then
                    emptytag(result,"break","display",depth)
                end
                begintag(result,element,natu,depth,di,skip)
                flushtree(result,di.data,natu,depth)
                endtag(result,element,natu,depth,skip)
                if di.after then
                    flushtree(result,di.after,nature,depth)
                end
            end
        end
    end
end

-- way too fragile

local function breaktree(tree,parent,parentelement) -- also removes double breaks
     local data = tree.data
     if data then
         local nofdata = #data
         local prevelement
         for i=1,nofdata do
             local di = data[i]
             if not di then
                 -- skip
             elseif type(di) == "string" then
                 prevelement = nil
             elseif not di.collapsed then
                 local element = di.element
                 if element == "break" then -- or element == "pagebreak"
                     if prevelement == "break" then
                         di.element = ""
                     end
                     prevelement = element
                 elseif element == "" or di.skip == "ignore" then
                     -- skip
                 else
--~ if element == "p" and di.nature ~= "display" then
--~     di = di.data
--~     data[i] = di
--~                     breaktree(di,tree,element)
--~ else
                    prevelement = element
                    breaktree(di,tree,element)
--~ end
                 end
             end
         end
     end
end

-- finalizers

local function checkinserts(data)
    local nofinserts = 0
    for i=1,#data do
        local di = data[i]
        if type(di) == "table" then -- id ~= false
            if di.element == "descriptionsymbol" then
                local hash = attributehash[di.fulltag]
                if hash then
                    local i = hash.insert
                    if i then
                        nofinserts = nofinserts + 1
                        insertids[i] = nofinserts
                    end
                else
                    -- something is wrong
                end
            end
            local d = di.data
            if d then
                checkinserts(d)
            end
        end
    end
end

-- tabulaterow reconstruction .. can better be a checker (TO BE CHECKED)

--~ local function xcollapsetree() -- unwanted space injection
--~     for tag, trees in next, treehash do
--~         local d = trees[1].data
--~         if d then
--~             local nd = #d
--~             if nd > 0 then
--~                 for i=2,#trees do
--~                     local currenttree = trees[i]
--~                     local currentdata = currenttree.data
--~                     local previouspar = trees[i-1].parnumber
--~                     currenttree.collapsed = true
--~                     if previouspar == 0 or type(currentdata[1]) ~= "string" then
--~                         previouspar = nil -- no need anyway so no further testing needed
--~                     end
--~                     local done = false
--~                     local breakdone = false
--~                     local spacedone = false
--~                     for j=1,#currentdata do
--~                         local cd = currentdata[j]
--~                         if not cd then
--~                             -- skip
--~                         elseif type(cd) == "string" then
--~                             if cd == "" then
--~                                 -- skip
--~                             elseif cd == " " then
--~                                 -- done check ?
--~                                 if not spacedone and not breakdone then
--~                                     nd = nd + 1
--~                                     d[nd] = cd
--~                                     spacedone = true
--~                                 end
--~                             elseif done then
--~                                 if not spacedone and not breakdone then
--~                                     nd = nd + 1
--~                                     d[nd] = " "
--~                                     spacedone = true
--~                                 end
--~                                 nd = nd + 1
--~                                 d[nd] = cd
--~                             else
--~                                 done = true
--~                                 local currentpar = d.parnumber
--~                                 if not currentpar then
--~                                     if not spacedone and not breakdone then
--~                                         nd = nd + 1
--~                                         d[nd] = " " -- brr adds space in unwanted places (like math)
--~                                         spacedone = true
--~                                     end
--~                                     previouspar = nil
--~                                 elseif not previouspar then
--~                                     if not spacedone and not breakdone then
--~                                         nd = nd + 1
--~                                         d[nd] = " "
--~                                         spacedone = true
--~                                     end
--~                                     previouspar = currentpar
--~                                 elseif currentpar ~= previouspar then
--~                                     if not breakdone then
--~                                         if not spacedone then
--~                                             nd = nd + 1
--~                                         end
--~                                         d[nd] = makebreaknode(currenttree)
--~                                         breakdone = true
--~                                     end
--~                                     previouspar = currentpar
--~                                 else
--~                                     spacedone = false
--~                                     breakdone = false
--~                                 end
--~                                 nd = nd + 1
--~                                 d[nd] = cd
--~                             end
--~                         else
--~                             if cd.tg == "break" then
--~                                 breakdone = true
--~                             end
--~                             nd = nd + 1
--~                             d[nd] = cd
--~                         end
--~                         currentdata[j] = false
--~                     end
--~                 end
--~             end
--~         end
--~     end
--~ end

local function collapsetree()
    for tag, trees in next, treehash do
        local d = trees[1].data
        if d then
            local nd = #d
            if nd > 0 then
                for i=2,#trees do
                    local currenttree = trees[i]
                    local currentdata = currenttree.data
                    local currentpar = currenttree.parnumber
                    local previouspar = trees[i-1].parnumber
                    currenttree.collapsed = true
                    -- is the next ok?
                    if previouspar == 0 or type(currentdata[1]) ~= "string" then
                        previouspar = nil -- no need anyway so no further testing needed
                    end
                    for j=1,#currentdata do
                        local cd = currentdata[j]
                        if not cd or cd == "" then
                            -- skip
                        elseif type(cd) == "string" then
                            if not currentpar then
                                -- add space ?
                            elseif not previouspar then
                                -- add space ?
                            elseif currentpar ~= previouspar then
                                nd = nd + 1
                                d[nd] = makebreaknode(currenttree)
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

local function indextree(tree)
    local data = tree.data
    if data then
        for i=1,#data do
            local d = data[i]
            if type(d) == "table" then
                d.__i__ = i
                d.__p__ = tree
                indextree(d)
            end
        end
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

-- collector code

local function push(fulltag,depth)
    local tag, n = lpegmatch(dashsplitter,fulltag)
    local tg, detail = lpegmatch(colonsplitter,tag)
    local element, nature
    if detail then
        local pd = properties[tag]
        local pt = properties[tg]
        element = pd and pd.export or pt and pt.export or tg
        nature  = pd and pd.nature or pt and pt.nature or defaultnature
    else
        local p = properties[tg]
        element = p and p.export or tg
        nature  = p and p.nature or "inline"
    end
    local treedata = tree.data
    local t = {
        tg         = tg,
        fulltag    = fulltag,
        detail     = detail,
        n          = tonumber(n), -- more efficient
        depth      = depth,
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
            report_export("%s<%s trigger='%s' paragraph='%s' index='%s' detail='%s'>",spaces[currentdepth-1],fulltag,currentattribute or 0,currentparagraph or 0,#treedata,detail)
        else
            report_export("%s<%s trigger='%s' paragraph='%s' index='%s'>",spaces[currentdepth-1],fulltag,currentattribute or 0,currentparagraph or 0,#treedata)
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
    local top = nesting[currentdepth]
    tree = treestack[currentdepth]
    currentdepth = currentdepth - 1
    if trace_export then
        if top then
            report_export("%s</%s>",spaces[currentdepth],top)
        else
            report_export("</%s>",top)
        end
    end
end

local function continueexport()
    if nofcurrentcontent > 0 then
        if trace_export then
            report_export("%s<!-- injecting pagebreak space -->",spaces[currentdepth])
        end
        nofcurrentcontent = nofcurrentcontent + 1
        currentcontent[nofcurrentcontent] = " " -- pagebreak
    end
end

local function pushentry(current)
    if current then
        if restart then
            continueexport()
            restart = false
        end
        local newdepth = #current
        local olddepth = currentdepth
        if trace_export then
            report_export("%s<!-- moving from depth %s to %s (%s) -->",spaces[currentdepth],olddepth,newdepth,current[newdepth])
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
                report_export("%s<!-- staying at depth %s (%s) -->",spaces[currentdepth],newdepth,nesting[newdepth] or "?")
            end
        end
        return olddepth, newdepth
    end
end

local function pushcontent(addbreak)
    if nofcurrentcontent > 0 then
        if addbreak then
            if currentcontent[nofcurrentcontent] == "\n" then
                if trace_export then
                    report_export("%s<!-- removing newline -->",spaces[currentdepth])
                end
                nofcurrentcontent = nofcurrentcontent - 1
            end
        end
        local content = concat(currentcontent,"",1,nofcurrentcontent)
        if content == "" then
            -- omit; when addbreak we could push, remove spaces, pop
--~         elseif content == " " and addbreak then
        elseif somespace[content] and addbreak then
            -- omit; when addbreak we could push, remove spaces, pop
        else
            local olddepth, newdepth
            local list = taglist[currentattribute]
            if list then
                olddepth, newdepth = pushentry(list)
            end
            local td = tree.data
            local nd = #td
            td[nd+1] = content
            if trace_export then
                report_export("%s<!-- start content with length %s -->",spaces[currentdepth],#content)
                report_export("%s%s",spaces[currentdepth],content)
                report_export("%s<!-- stop content -->",spaces[currentdepth])
            end
            if olddepth then
                for i=newdepth-1,olddepth,-1 do
                    pop()
                end
            end
        end
        nofcurrentcontent = 0
    end
    if addbreak then
        pushentry(makebreaklist(currentnesting))
     -- if trace_export then
     --     report_export("%s<!-- add break -->",spaces[currentdepth])
     -- end
    end
end

local function finishexport()
    if trace_export then
        report_export("%s<!-- start finalizing -->",spaces[currentdepth])
    end
    if nofcurrentcontent > 0 then
        if somespace[currentcontent[nofcurrentcontent]] then
            if trace_export then
                report_export("%s<!-- removing space -->",spaces[currentdepth])
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
        report_export("%s<!-- stop finalizing -->",spaces[currentdepth])
    end
end

-- whatsit_code localpar_code

local function collectresults(head,list)
    local p
    for n in traverse_nodes(head) do
        local id = n.id -- 14: image, 8: literal (mp)
        if id == glyph_code then
            local at = has_attribute(n,a_tagged)
            if not at then
             -- we need to tag the pagebody stuff as being valid skippable
             --
             -- report_export("skipping character: 0x%05X %s (no attribute)",n.char,utfchar(n.char))
            else
                -- we could add tonunicodes for ligatures (todo)
                local components =  n.components
                if components then -- we loose data
                    collectresults(components,nil)
                else
                    local c = n.char
                    if last ~= at then
                        local tl = taglist[at]
                        if trace_export then
                            report_export("%s<!-- processing glyph %s (tag %s) -->",spaces[currentdepth],utfchar(c),at)
                        end
                        pushcontent()
                        currentparagraph = has_attribute(n,a_taggedpar)
                        currentnesting = tl
                        currentattribute = at
                        local ah = { -- this includes detail ! -- we can move some to te tex end
                            align       = has_attribute(n,a_taggedalign  ),
                            columns     = has_attribute(n,a_taggedcolumns),
                            rows        = has_attribute(n,a_taggedrows   ),
                            packed      = has_attribute(n,a_taggedpacked ),
                            symbol      = has_attribute(n,a_taggedsymbol ),
                            insert      = has_attribute(n,a_taggedinsert ),
                            reference   = has_attribute(n,a_reference    ),
                            tag         = has_attribute(n,a_taggedtag    ), -- used for synonyms
                        }
                        if next(ah) then
                            attributehash[tl[#tl]] = ah
                        end
                        last = at
                        pushentry(currentnesting)
                    elseif last then
                        local at = has_attribute(n,a_taggedpar)
                        if at ~= currentparagraph then
                            pushcontent(true) -- add break
                            pushentry(currentnesting)
                            currentattribute = last
                            currentparagraph = at
                        end
                        if trace_export then
                            report_export("%s<!-- processing glyph %s (tag %s) -->",spaces[currentdepth],utfchar(c),last)
                        end
                    else
                        if trace_export then
                            report_export("%s<!-- processing glyph %s (tag %s) -->",spaces[currentdepth],utfchar(c),at)
                        end
                    end
                    local s = has_attribute(n,a_exportstatus)
                    if s then
                        c = s
                    end
                    if c == 0 then
                        if trace_export then
                            report_export("%s<!-- skipping last glyph -->",spaces[currentdepth])
                        end
                    elseif c == 0x20 then
                        local a = has_attribute(n,a_characters)
                        nofcurrentcontent = nofcurrentcontent + 1
                        if a then
                            if trace_export then
                                report_export("%s<!-- turning last space into special space U+%05X -->",spaces[currentdepth],a)
                            end
                            currentcontent[nofcurrentcontent] = specialspaces[a] -- special space
                        else
                            currentcontent[nofcurrentcontent] = " "
                        end
                    else
                        local fc = fontchar[n.font]
                        if fc then
                            fc = fc and fc[c]
                            if fc then
                                local u = fc.tounicode
                                if u and u ~= "" then
                                    -- tracing
                                    for s in gmatch(u,"....") do -- is this ok?
                                        nofcurrentcontent = nofcurrentcontent + 1
                                        currentcontent[nofcurrentcontent] = utfchar(tonumber(s,16))
                                    end
                                else
                                    nofcurrentcontent = nofcurrentcontent + 1
                                    currentcontent[nofcurrentcontent] = utfchar(c)
                                end
                            else -- weird, happens in hz (we really need to get rid of the pseudo fonts)
                                nofcurrentcontent = nofcurrentcontent + 1
                                currentcontent[nofcurrentcontent] = utfchar(c)
                            end
                        else
                            nofcurrentcontent = nofcurrentcontent + 1
                            currentcontent[nofcurrentcontent] = utfchar(c)
                        end
                    end
                end
            end
        elseif id == hlist_code or id == vlist_code then
            local ai = has_attribute(n,a_image)
            if ai then
                local at = has_attribute(n,a_tagged)
                if nofcurrentcontent > 0 then
                    pushcontent()
                    pushentry(currentnesting) -- ??
                end
                local tl = taglist[at]
                local i = locate_node(n,whatsit_code,refximage_code)
                if i then
                    attributehash[tl[#tl]] = { imageindex = i.index }
                end
                pushentry(tl) -- has an index, todo: flag empty element
                if trace_export then
                    report_export("%s<!-- processing image (tag %s)",spaces[currentdepth],last)
                end
                last = nil
                currentparagraph = nil
            else
                -- we need to determine an end-of-line
                collectresults(n.list,n)
            end
        elseif id == disc_code then -- probably too late
            collectresults(n.replace,nil)
        elseif id == glue_code then
            -- we need to distinguish between hskips and vskips
            local subtype = n.subtype
            if subtype == userskip_code then
                local ca = has_attribute(n,a_characters)
                if ca then
                    if ca == 0 then
                        -- skip this one ... already converted special character (node-acc)
                    else
                        local a = has_attribute(n,a_tagged)
                        if somespace[currentcontent[nofcurrentcontent]] then
                            if trace_export then
                                report_export("%s<!-- removing space -->",spaces[currentdepth])
                            end
                            nofcurrentcontent = nofcurrentcontent - 1
                        end
                        if last ~= a then
                            pushcontent()
                            last = a
                            currentnesting = taglist[last]
                            pushentry(currentnesting)
                            currentattribute = last
                        end
                        nofcurrentcontent = nofcurrentcontent + 1
                        currentcontent[nofcurrentcontent] = specialspaces[ca] -- utfchar(ca)
                        if trace_export then
                            report_export("%s<!-- adding special space/glue (tag %s => %s) -->",spaces[currentdepth],last,a)
                        end
                    end
                elseif n.spec.width > threshold then
                    if last and not somespace[currentcontent[nofcurrentcontent]] then
                        local a = has_attribute(n,a_tagged)
                        if a == last then
                            if trace_export then
                                report_export("%s<!-- injecting spacing 5a -->",spaces[currentdepth])
                            end
                            nofcurrentcontent = nofcurrentcontent + 1
                            currentcontent[nofcurrentcontent] = " "
                        elseif a then
                            -- e.g LOGO<space>LOGO
                            if trace_export then
                                report_export("%s<!-- processing glue > threshold (tag %s => %s) -->",spaces[currentdepth],last,a)
                            end
                            pushcontent()
                            if trace_export then
                                report_export("%s<!-- injecting spacing 5b -->",spaces[currentdepth])
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
                    if trace_export then
                        report_export("%s<!-- injecting spacing 7 -->",spaces[currentdepth])
                    end
                    nofcurrentcontent = nofcurrentcontent + 1
                    currentcontent[nofcurrentcontent] = " "
                end
            elseif subtype == rightskip_code or subtype == parfillskip_code then
                if nofcurrentcontent > 0 then -- and n.subtype == line_code then
                    local r = currentcontent[nofcurrentcontent]
                    if type(r) == "string" and r ~= " " then
                        local s = utfsub(r,-1)
                        if s == hyphen then
                            currentcontent[nofcurrentcontent] = utfsub(r,1,-2)
                        elseif s ~= "\n" then
-- test without this
                            if trace_export then
                                report_export("%s<!-- injecting newline 1 -->",spaces[currentdepth])
                            end
                            nofcurrentcontent = nofcurrentcontent + 1
                            currentcontent[nofcurrentcontent] = "\n"
                        end
                    end
                end
            end
        elseif id == kern_code then
            local kern = n.kern
            if kern > 0 then
                local limit = threshold
                if p and p.id == glyph_code then
                    limit = fontquads[p.font] / 4
                end
                if kern > limit then
                    if last and not somespace[currentcontent[nofcurrentcontent]] then
                        local a = has_attribute(n,a_tagged)
                        if a == last then
                            if not somespace[currentcontent[nofcurrentcontent]] then
                                if trace_export then
                                    report_export("%s<!-- injecting spacing 8 (%s) -->",spaces[currentdepth],topoints(kern,true))
                                end
                                nofcurrentcontent = nofcurrentcontent + 1
                                currentcontent[nofcurrentcontent] = " "
                            end
                        elseif a then
                            -- e.g LOGO<space>LOGO
                            if trace_export then
                                report_export("%s<!-- processing kern, threshold %s, tag %s => %s -->",spaces[currentdepth],topoints(limit,true),last,a)
                            end
                            last = a
                            pushcontent()
                            if trace_export then
                                report_export("%s<!-- injecting spacing 9 (%s) -->",spaces[currentdepth],topoints(kern,true))
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
     -- elseif id == whatsit_code and n.subtype == localpar_code then
        end
        p = n
    end
end

function nodes.handlers.export(head) -- hooks into the page builder
    starttiming(treehash)
    if trace_export then
        report_export("%s<!-- start flushing page -->",spaces[currentdepth])
    end
 -- continueexport()
    restart = true
    collectresults(head)
    if trace_export then
        report_export("%s<!-- stop flushing page -->",spaces[currentdepth])
    end
    stoptiming(treehash)
    return head, true
end

function builders.paragraphs.tag(head)
    noftextblocks = noftextblocks + 1
    for n in traverse_id(hlist_code,head) do
        local subtype = n.subtype
        if subtype == line_code then
            set_attribute(n,a_textblock,noftextblocks)
        elseif subtype == glue_code or subtype == kern_code then
            set_attribute(n,a_textblock,0)
        end
    end
    return false
end

-- wrapper

local displaymapping = {
    inline  = "inline",
    display = "block",
    mixed   = "inline",
}

local e_template = [[
%s {
    display: %s ;
}]]

local d_template = [[
%s[detail=%s] {
    display: %s ;
}]]

-- encoding='utf-8'

local xmlpreamble = [[
<?xml version='1.0' encoding='UTF-8' standalone='yes' ?>

<!-- input filename   : %- 17s -->
<!-- processing date  : %- 17s -->
<!-- context version  : %- 17s -->
<!-- exporter version : %- 17s -->
]]

local csspreamble = [[

<?xml-stylesheet type="text/css" href="%s"?>
]]

-- local xhtmlpreamble = [[
--     <!DOCTYPE html PUBLIC
--         "-//W3C//DTD XHTML 1.1 plus MathML 2.0 plus SVG 1.1//EN"
--         "http://www.w3.org/2002/04/xhtml-math-svg/xhtml-math-svg.dtd"
--     >
-- ]]

local cssfile, xhtmlfile = nil, nil

directives.register("backend.export.css",  function(v) cssfile   = v end)
directives.register("backend.export.xhtml",function(v) xhtmlfile = v end)

local function stopexport(v)
    starttiming(treehash)
    finishexport()
    collapsetree(tree)
    indextree(tree)
    checktree(tree)
    breaktree(tree)
    checkinserts(tree.data)
    hashlistdata()
    if type(v) ~= "string" or v == variables.yes or v == "" then
        v = tex.jobname
    end
    local xmlfile = file.addsuffix(v,"export")
    if type(cssfile) ~= "string" or cssfile == "" then
        cssfile = nil
    end
    local files = { }
    local specification = {
        name = file.removesuffix(v),
        identifier = os.uuid(),
        files = files,
    }
    report_export("saving xml data in '%s",xmlfile)
    local results = { }
    results[#results+1] = format(xmlpreamble,tex.jobname,os.date(),environment.version,exportversion)
    if cssfile then
        local cssfiles = settings_to_array(cssfile)
        for i=1,#cssfiles do
            local cssfile = cssfiles[i]
            files[#files+1] = cssfile
            if type(cssfile) ~= "string" or cssfile == variables.yes or cssfile == "" or cssfile == xmlfile then
                cssfile = file.replacesuffix(xmlfile,"css")
            else
                cssfile = file.addsuffix(cssfile,"css")
            end
            report_export("adding css reference '%s",cssfile)
            results[#results+1] = format(csspreamble,cssfile)
        end
    end
    -- collect tree
    local result  = { }
    flushtree(result,tree.data,"display",0)
    result = concat(result)
result = gsub(result,"\n *\n","\n")
result = gsub(result,"\n +([^< ])","\n%1")
    results[#results+1] = result
    results = concat(results)
    -- if needed we can do a cleanup of the tree (no need to load for xhtml then)
    -- write to file
    io.savedata(xmlfile,results)
    -- css template file
    if cssfile then
        local cssfile = file.replacesuffix(xmlfile,"template")
        report_export("saving css template in '%s",cssfile)
        local templates = { format("/* template for file %s */",xmlfile) }
        for element, details in table.sortedhash(used) do
            templates[#templates+1] = format("/* category: %s */",element)
            for detail, nature in table.sortedhash(details) do
                local d = displaymapping[nature or "display"] or "block"
                if detail == "" then
                    templates[#templates+1] = format(e_template,element,d)
                else
                    templates[#templates+1] = format(d_template,element,detail,d)
                end
            end
        end
        io.savedata(cssfile,concat(templates,"\n\n"))
    end
    -- xhtml references
    if xhtmlfile then
        -- messy
        if type(v) ~= "string" or xhtmlfile == true or xhtmlfile == variables.yes or xhtmlfile == "" or xhtmlfile == xmlfile then
            xhtmlfile = file.replacesuffix(xmlfile,"xhtml")
        else
            xhtmlfile = file.addsuffix(xhtmlfile,"xhtml")
        end
        report_export("saving xhtml variant in '%s",xhtmlfile)
     -- local xmltree = xml.load(xmlfile)
        local xmltree = xml.convert(results)
        if xmltree then
            local xmlwrap = xml.wrap
            for e in xml.collected(xmltree,"/document") do
                e.at["xmlns:xhtml"] = "http://www.w3.org/1999/xhtml"
                break
            end
            -- todo: inject xhtmlpreamble (xmlns should have be enough)
            local wrapper = { tg = "a", ns = "xhtml", at = { href = "unknown" } }
            for e in xml.collected(xmltree,"link") do
                local location = e.at.location
                if location then
                    wrapper.at.href = "#" .. gsub(location,":","_")
                    xmlwrap(e,wrapper)
                end
            end
            local wrapper = { tg = "a", ns = "xhtml", at = { name = "unknown" } }
            for e in xml.collected(xmltree,"!link[@location]") do
                local location = e.at.location
                if location then
                    wrapper.at.name = gsub(location,":","_")
                    xmlwrap(e,wrapper)
                end
            end
            xml.save(xmltree,xhtmlfile)
        end
        files[#files+1] = xhtmlfile
        specification.root = xhtmlfile
        local specfile = file.replacesuffix(xmlfile,"specification")
        report_export("saving specification in '%s' (mtxrun --script epub --make %s)",specfile,specfile)
        io.savedata(specfile,table.serialize(specification,true))
    end
    stoptiming(treehash)
end

local appendaction = nodes.tasks.appendaction
local enableaction = nodes.tasks.enableaction

local function startexport(v)
    if v and not exporting then
        report_export("enabling export to xml")
-- not yet known in task-ini
        appendaction("shipouts",     "normalizers", "nodes.handlers.export")
--      enableaction("shipouts","nodes.handlers.export")
--
        enableaction("shipouts","nodes.handlers.accessibility")
        enableaction("math",    "noads.handlers.tags")
--~ appendaction("finalizers","lists","builders.paragraphs.tag")
--~ enableaction("finalizers","builders.paragraphs.tag")
        luatex.registerstopactions(function() stopexport(v) end)
        exporting = true
    end
end

directives.register("backend.export",startexport) -- maybe .name

statistics.register("xml exporting time", function()
    if exporting then
        return format("%s seconds, version %s", statistics.elapsedtime(treehash),exportversion)
    end
end)

commands.settagitemgroup     = structurestags.setitemgroup
commands.settagsynonym       = structurestags.setsynonym
commands.settagsorting       = structurestags.setsorting
commands.settagdescriptionid = structurestags.setdescriptionid

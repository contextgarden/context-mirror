if not modules then modules = { } end modules ['back-exp'] = {
    version   = 1.001,
    comment   = "companion to back-exp.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- language       -> only mainlanguage, local languages should happen through start/stoplanguage
-- tocs/registers -> maybe add a stripper (i.e. just don't flush entries in final tree)

-- Because we need to look ahead we now always build a tree (this was optional in
-- the beginning). The extra overhead in the frontend is neglectable.

-- We can consider replacing attributes by the hash entry ... slower in resolving but it's still
-- quite okay.

-- todo: less attributes e.g. internal only first node
-- todo: build xml tree in mem (handy for cleaning)

-- delimited: left/right string (needs marking)

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
local format, match, concat, rep, sub, gsub = string.format, string.match, table.concat, string.rep, string.sub, string.gsub
local lpegmatch = lpeg.match
local utfchar, utfsub = utf.char, utf.sub
local insert, remove = table.insert, table.remove

local trace_export = false  trackers.register  ("structures.export",            function(v) trace_export = v end)
local trace_spaces = false  trackers.register  ("structures.export.spaces",     function(v) trace_spaces = v end)
local trace_tree   = false  trackers.register  ("structures.export.showtree",   function(v) trace_tree   = v end)
local less_state   = false  directives.register("structures.export.lessstate",  function(v) less_state   = v end)
local page_breaks  = false  directives.register("structures.export.pagebreaks", function(v) page_breaks  = v end)

local report_export     = logs.reporter("backend","export")

local nodes             = nodes
local attributes        = attributes
local variables         = interfaces.variables

local settings_to_array = utilities.parsers.settings_to_array

local setmetatableindex = table.setmetatableindex
local tasks             = nodes.tasks
local fontchar          = fonts.hashes.characters
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

local userskip_code     = skipcodes.userskip
local rightskip_code    = skipcodes.rightskip
local parfillskip_code  = skipcodes.parfillskip

local line_code         = listcodes.line

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

local a_reference       = attributes.private('reference')

local has_attribute     = node.has_attribute
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

local starttiming       = statistics.starttiming
local stoptiming        = statistics.stoptiming

-- todo: more locals (and optimize)

local version       = "0.20"
local result        = nil -- todo: nofresult
local entry         = nil
local attributehash = { }
local hyphen        = utfchar(0xAD) -- todo: also emdash etc
local colonsplitter = lpeg.splitat(":")
local dashsplitter  = lpeg.splitat("-")
local threshold     = 65536
local indexing      = false
local linedone      = false
local inlinedepth   = 0
local tree          = { data = { }, depth = 0 } -- root
local treestack     = { }
local treehash      = { }
local extras        = { }
local nofbreaks     = 0
local used          = { }
local exporting     = false
local last          = nil
local lastpar       = nil

setmetatableindex(used, function(t,k)
    if k then
        local v = { }
        t[k] = v
        return v
    end
end)

local joiner_1   = " "
local joiner_2   = " " -- todo: test if this one can always be ""
local joiner_3   = " "
local joiner_4   = " "
local joiner_5   = " "
local joiner_6   = " "
local joiner_7   = "\n"
local joiner_8   = " "
local joiner_9   = " "
local joiner_0   = " "

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
}

setmetatableindex(namespaced, function(t,k)
    local namespace = namespaces[k]
    local v = namespace and namespace .. ":" .. k or k
    t[k] = v
    return v
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

setmetatableindex(spaces, function(t,k) t[k] = rep("  ",k-1) return t[k] end)

properties.vspace = { export = "break",     nature = "display" }
properties.pbreak = { export = "pagebreak", nature = "display" }

local function makebreak(entry)
    nofbreaks = nofbreaks + 1
    local t, tl = { }, entry[1]
    if tl then
        for i=1,#tl do
            t[i] = tl[i]
        end
    end
    t[#t+1] = "break-" .. nofbreaks
    return { t, { "" }, 0, 0 }
end

local function makebreaknode(node)
    nofbreaks = nofbreaks + 1
    return {
        tg         = "break",
        fulltag    = "break-" .. nofbreaks,
        n          = nofbreaks,
        depth      = node.depth,
        element    = "break",
        nature     = "display",
        data       = { },
        attribute  = { } ,
        parnumber  = 0,
    }
end

local fields = { "title", "subtitle", "author", "keywords" }

function extras.document(handle,element,detail,n,fulltag,hash)
    handle:write(format(" language=%q",languagenames[tex.count.mainlanguagenumber]))
    if not less_state then
        handle:write(format(" file=%q",tex.jobname))
        handle:write(format(" date=%q",os.date()))
        handle:write(format(" context=%q",environment.version))
        handle:write(format(" version=%q",version))
        handle:write(format(" xmlns:m=%q","http://www.w3.org/1998/Math/MathML"))
        local identity = interactions.general.getidentity()
        for i=1,#fields do
            local key   = fields[i]
            local value = identity[key]
            if value and value ~= "" then
                handle:write(format(" %s=%q",key,value))
            end
        end
    end
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

function extras.descriptiontag(handle,element,detail,n,fulltag,di)
    local hash = attributehash[fulltag]
    if hash then
        local v = hash.insert
        v = v and insertids[v]
        if v then
            handle:write(" insert='",v,"'")
        end
    end
end

function extras.descriptionsymbol(handle,element,detail,n,fulltag,di)
    local hash = attributehash[fulltag]
    if hash then
        local v = hash.insert
        v = v and insertids[v]
        if v then
            handle:write(" insert='",v,"'")
        end
    end
end

function extras.synonym(handle,element,detail,n,fulltag,di)
    local hash = attributehash[fulltag]
    if hash then
        local v = hash.tag
        v = v and synonymnames[v]
        if v then
            handle:write(" tag='",v,"'")
        end
    end
end

function extras.sorting(handle,element,detail,n,fulltag,di)
    local hash = attributehash[fulltag]
    if hash then
        local v = hash.tag
        v = v and sortingnames[v]
        if v then
            handle:write(" tag='",v,"'")
        end
    end
end

function extras.image(handle,element,detail,n,fulltag,di)
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
                    handle:write(" name='",name,"'")
                end
                if path ~= "" then
                    handle:write(" path='",path,"'")
                end
                if page > 1 then
                    handle:write(" page='",page,"'")
                end
            end
        end
    end
end

-- quite some code deals with exporting references  --

local evaluators = { }
local specials   = { }

evaluators.inner = function(handle,var)
    local inner = var.inner
    if var.inner then
        handle:write(" location='",inner,"'")
    end
end

evaluators.outer = function(handle,var)
    local file, url = references.checkedfileorurl(var.outer,var.outer)
    if url then
        handle:write(" url='",file,"'")
    elseif file then
        handle:write(" file='",file,"'")
    end
end

evaluators["outer with inner"] = function(handle,var)
    local file = references.checkedfile(var.f)
    if file then
        handle:write(" file='",file,"'")
    end
    local inner = var.inner
    if var.inner then
        handle:write(" location='",inner,"'")
    end
end

evaluators.special = function(handle,var)
    local handler = specials[var.special]
    if handler then
        handler(handle,var)
    end
end

evaluators["special outer with operation"]     = evaluators.special
evaluators["special operation"]                = evaluators.special
evaluators["special operation with arguments"] = evaluators.special

function specials.url(handle,var)
    local url = references.checkedurl(var.operation)
    if url then
        handle:write(" url='",url,"'")
    end
end

function specials.file(handle,var)
    local file = references.checkedfile(var.operation)
    if file then
        handle:write(" file='",file,"'")
    end
end

function specials.fileorurl(handle,var)
    local file, url = references.checkedfileorurl(var.operation,var.operation)
    if url then
        handle:write(" url='",file,"'")
    elseif file then
        handle:write(" file='",file,"'")
    end
end

function specials.internal(handle,var)
    local internal = references.checkedurl(var.operation)
    if internal then
        handle:write(" location='aut:",internal,"'")
    end
end

local function adddestination(handle,references) -- todo: specials -> exporters and then concat
    if references then
        local reference = references.reference
        if reference and reference ~= "" then
            local prefix = references.prefix
            if prefix and prefix ~= "" then
                handle:write(" prefix='",prefix,"'")
            end
            handle:write(" destination='",reference,"'")
            for i=1,#references do
                local r = references[i]
                local e = evaluators[r.kind]
                if e then
                    e(handle,r)
                end
            end
        end
    end
end

local function addreference(handle,references)
    if references then
        local reference = references.reference
        if reference and reference ~= "" then
            local prefix = references.prefix
            if prefix and prefix ~= "" then
                handle:write(" prefix='",prefix,"'")
            end
            handle:write(" reference='",reference,"'")
        end
        local internal = references.internal
        if internal and internal ~= "" then
            handle:write(" location='aut:",internal,"'")
        end
    end
end

function extras.link(handle,element,detail,n,fulltag,di)
    -- for instance in lists a link has nested elements and no own text
    local hash = attributehash[fulltag]
    if hash then
        local references = hash.reference
        if references then
            adddestination(handle,structures.references.get(references))
        end
        return true
    else
        local data = di.data
        if data then
            for i=1,#data do
                local di = data[i]
                if di and extras.link(handle,element,detail,n,di.fulltag,di) then
                    return true
                end
            end
        end
    end
end

function extras.section(handle,element,detail,n,fulltag,di)
    local data = listdata[fulltag]
    if data then
        addreference(handle,data.references)
        return true
    else
        local data = di.data
        if data then
            for i=1,#data do
                local di = data[i]
                if di then
                    local ft = di.fulltag
                    if ft and extras.section(handle,element,detail,n,ft,di) then
                        return true
                    end
                end
            end
        end
    end
end

function extras.float(handle,element,detail,n,fulltag,di)
    local data = listdata[fulltag]
    if data then
        addreference(handle,data.references)
        return true
    else
        local data = di.data
        if data then
            for i=1,#data do
                local di = data[i]
                if di and extras.section(handle,element,detail,n,di.fulltag,di) then
                    return true
                end
            end
        end
    end
end

function extras.itemgroup(handle,element,detail,n,fulltag,di)
    local data = di.data
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
                                handle:write(" packed='yes'")
                            end
                            local v = hash.symbol
                            if v then
                                handle:write(" symbol='",snames[v],"'")
                            end
                            return
                        end
                    end
                end
            end
        end
    end
end

function extras.tablecell(handle,element,detail,n,fulltag,di)
    local hash = attributehash[fulltag]
    if hash then
        local v = hash.align
        if not v or v == 0 then
            -- normal
        elseif v == 1 then
            handle:write(" align='flushright'")
        elseif v == 2 then
            handle:write(" align='middle'")
        elseif v == 3 then
            handle:write(" align='flushleft'")
        end
        local v = hash.columns
        if v and v > 1 then
            handle:write(" columns='",v,"'")
        end
        local v = hash.rows
        if v and v > 1 then
            handle:write(" rows='",v,"'")
        end
    end
end

function extras.tabulatecell(handle,element,detail,n,fulltag,di)
    local hash = attributehash[fulltag]
    if hash then
        local v = hash.align
        if not v or v == 0 then
            -- normal
        elseif v == 1 then
            handle:write(" align='flushright'")
        elseif v == 2 then
            handle:write(" align='middle'")
        elseif v == 3 then
            handle:write(" align='flushleft'")
        end
    end
end

local function emptytag(handle,element,nature,depth)
    handle:write("\n",spaces[depth],"<",namespaced[element],"/>\n")
end

local function begintag(handle,element,nature,depth,di,empty)
    local detail, n, fulltag = di.detail, di.n, di.fulltag
    if nature == "inline" then
        linedone = false
        inlinedepth = inlinedepth + 1
    elseif nature == "mixed" then
        if inlinedepth > 0 then
        elseif linedone then
            handle:write(spaces[depth])
        else
            handle:write("\n",spaces[depth])
            linedone = false
        end
        inlinedepth = inlinedepth + 1
    else
        if inlinedepth > 0 then
        elseif linedone then
            handle:write(spaces[depth])
        else
            handle:write("\n",spaces[depth])
            linedone = false
        end
    end
    handle:write("<",namespaced[element])
    if detail then
        handle:write(" detail='",detail,"'")
    end
    if indexing and n then
        handle:write(" n='",n,"'")
    end
    local extra = extras[element]
    if extra then
        extra(handle,element,detail,n,fulltag,di)
    end
    local u = userdata[fulltag]
    if u then
        for k, v in next, u do
            handle:write(format(" %s=%q",k,v))
        end
    end
    if not empty then
        handle:write(">")
        if inlinedepth > 0 then
        elseif nature == "display" then
            handle:write("\n")
            linedone = true
        end
    end
    used[element][detail or ""] = nature
end

local function endtag(handle,element,nature,depth,empty)
    if nature == "display" then
        if inlinedepth == 0 then
            if empty then
                handle:write("</>\n")
            else
                if not linedone then
                    handle:write("\n")
                end
                handle:write(spaces[depth],"</",namespaced[element],">\n")
            end
            linedone = true
        else
            if empty then
                handle:write("/>")
            else
                handle:write("</",namespaced[element],">")
            end
        end
    else
        inlinedepth = inlinedepth - 1
        if empty then
            handle:write("/>")
        else
            handle:write("</",namespaced[element],">")
        end
        linedone = false
    end
end

local function push(fulltag,depth,entry)
    local attribute, parnumber = entry[3], entry[4]
 -- local tg, detail, n = lpegmatch(tagsplitter,fulltag)
    local tag, n = lpegmatch(dashsplitter,fulltag)
    local tg, detail = lpegmatch(colonsplitter,tag)
    local element, nature
    if detail then
        local pd = properties[tag]
        local pt = properties[tg]
        element = pd and pd.export or pt and pt.export or tg
        nature  = pd and pd.nature or pt and pt.nature or "inline"
    else
        local p = properties[tg]
        element = p and p.export or tg
        nature  = p and p.nature or "inline"
    end
    local t = {
     -- parent     = tree,
        tg         = tg,
        fulltag    = fulltag,
        detail     = detail,
        n          = tonumber(n), -- more efficient
        depth      = depth,
        element    = element,
        nature     = nature,
        data       = { },
        attribute  = attribute,
        parnumber  = parnumber,
     -- node       = entry[5], -- will go
    }
    local treedata = tree.data
    treedata[#treedata+1] = t
    insert(treestack,tree)
    tree = t
    local h = treehash[fulltag]
    if h then
        h[#h+1] = t
    else
        treehash[fulltag] = { t }
    end
end

local function pop()
    tree = remove(treestack)
end

local function flushresult(entry)
    local current, content = entry[1], entry[2]
    if not content then
        -- skip, normally this cannot happen
    else
        local newdepth, olddepth, content = #current, #treestack, concat(content)
        if trace_export then
            report_export("%s => %s : handling: %s",olddepth,newdepth,current[newdepth])
        end
        if olddepth <= 0 then
            for i=1,newdepth do
                if trace_export then
                    report_export("[1]  push : %s",current[i])
                end
                push(current[i],i,entry)
            end
            if content then
                tree.data[#tree.data+1] = content
            end
        elseif newdepth < olddepth then
            for i=newdepth,olddepth-1 do
                if trace_export then
                    report_export("[2a] pop  : %s",current[i])
                end
                pop()
            end
            -- we can have a pagebreak and for instance a new chapter
            -- will mess up the structure then
            for i=newdepth,1,-1 do
                if current[i] ~= treestack[i].fulltag then -- needs checking
                    if trace_export then
                        report_export("[2b] pop  : %s",current[i])
                    end
                    pop()
                else
                    break
                end
            end
            olddepth = #treestack
            for i=olddepth+1,newdepth do
                if trace_export then
                    report_export("[2]  push : %s",current[i])
                end
                push(current[i],i,entry)
            end
            if content then
                tree.data[#tree.data+1] = content
            end
        elseif newdepth > olddepth then
            for i=olddepth,1,-1 do
                if current[i] ~= treestack[i].fulltag then
                    if trace_export then
                        report_export("[3]  pop  : %s",current[i])
                    end
                    pop()
                else
                    break
                end
            end
            olddepth = #treestack
            for i=olddepth+1,newdepth do
                if trace_export then
                    report_export("[3]  push : %s",current[i])
                end
                push(current[i],i,entry)
            end
            if content then
                tree.data[#tree.data+1] = content
            end
        elseif current[newdepth] == treestack[olddepth] then --move up ?
            -- continuation
            if content then
                tree.data[#tree.data+1] = content
            end
        else
            for i=olddepth,1,-1 do
                if current[i] ~= treestack[i].fulltag then
                    if trace_export then
                        report_export("[4]  pop  : %s",current[i])
                    end
                    pop()
                else
                    break
                end
            end
            olddepth = #treestack
            for i=olddepth+1,newdepth do
                if trace_export then
                    report_export("[4]  push : %s",current[i])
                end
                push(current[i],i,entry)
            end
            if content then
                tree.data[#tree.data+1] = content
            end
        end
    end
end

local function checkinserts(data)
    local nofinserts = 0
    for i=1,#data do
        local di = data[i]
        if type(di) == "table" then -- id ~= false
            if di.element == "descriptionsymbol" then
                local i = attributehash[di.fulltag].insert
                if i then
                    nofinserts = nofinserts + 1
                    insertids[i] = nofinserts
                end
            end
            if di.data then
                checkinserts(di.data)
            end
        end
    end
end

local function flushtree(handle,data,nature)
    local nofdata = #data
    for i=1,nofdata do
        local di = data[i]
        if not di then
        -- collapsed
        elseif type(di) == "string" then
if i == nofdata and sub(di,-1) == joiner_7 then
    if nature == "inline" or nature == "mixed" then
            handle:write(sub(di,1,-2))
    else
            handle:write(sub(di,1,-2)," ")
    end
else
            handle:write(di)
end
            linedone = false
        elseif not di.collapsed then
            local element = di.element
            if element == "break" or element == "pagebreak" then
                emptytag(handle,element,nature,di.depth)
            else
                local nature, depth = di.nature, di.depth
                local did = di.data
                local nid = #did
                if nid == 0 or (nid == 1 and did[1] == "") then
                    begintag(handle,element,nature,depth,di,true)
                    -- no content
                    endtag(handle,element,nature,depth,true)
                else
                    begintag(handle,element,nature,depth,di)
                    flushtree(handle,did,nature)
                    endtag(handle,element,nature,depth)
                end
            end
        end
    end
end

local function collapsetree()
    for k, v in next, treehash do
        local d = v[1].data
        local nd = #d
        for i=2,#v do
            local vi = v[i]
            local vd = vi.data
            local done = false
            local lpn = v[i-1].parnumber
            if lpn and lpn == 0 then lpn = nil end
            if type(d[1]) ~= "string" then lpn = nil end -- no need anyway so no further testing needed
local justdone = false
            for j=1,#vd do
                local vdj = vd[j]
                if type(vdj) == "string" then
--~ print(vdj)
                    -- experiment, should be improved
                    -- can be simplified ... lpn instead of done
                    if done then
                        nd = nd + 1
                        d[nd] = joiner_1
                    else
                        done = true
                        local pn = vi.parnumber
                        if not pn then
                            nd = nd + 1
                            d[nd] = joiner_2
                            lpn = nil
                        elseif not lpn then
                            nd = nd + 1
                            d[nd] = joiner_3
                            lpn = pn
                        elseif pn and pn ~= lpn then
                            nd = nd + 1
                            d[nd] = makebreaknode(vi)
                            lpn = pn
                        else
                         -- nd = nd + 1
                         -- d[nd] = joiner_4 -- we need to be more clever
                        end
                    end
                else
--~ nd = nd + 1
--~ d[nd] = joiner_3
                  -- lpn = nil
                end
                if vdj ~= "" then
                    nd = nd + 1
                    d[nd] = vdj -- hm, any?
                end
                vd[j] = false
            end
            v[i].collapsed = true
        end
    end
end

local function prunetree(tree)
    if not tree.collapsed then
        local data = tree.data
        if data then
            local p, np = { }, 0
            for i=1,#data do
                local d = data[i]
                if type(d) == "table" then
                    if not d.collapsed then
                        prunetree(d)
                        np = np + 1
                        p[np] = d
                    end
                elseif type(d) == "string" then
                    np = np + 1
                    p[np] = d
                end
            end
            tree.data = np > 0 and p
        end
    end
end

local function finishexport()
    if entry then
        local result = entry[2]
        if result and result[#result] == " " then
            result[#result] = nil -- nicer, remove last space
        end
        flushresult(entry)
    end
    for i=#treestack,1,-1 do
        pop()
    end
end

local displaymapping = {
    inline  = "inline",
    display = "block",
    mixed   = "inline",
}

local e_template = [[
%s {
    display: %s
}]]

local d_template = [[
%s[detail=%s] {
    display: %s
}]]

-- encoding='utf-8'

local xmlpreamble = [[
<?xml version='1.0' standalone='yes' ?>

<!-- input filename   : %- 17s -->
<!-- processing date  : %- 17s -->
<!-- context version  : %- 17s -->
<!-- exporter version : %- 17s -->
]]

local csspreamble = [[

<?xml-stylesheet type="text/css" href="%s"?>
]]

local cssfile, xhtmlfile = nil, nil

directives.register("backend.export.css",  function(v) cssfile   = v end)
directives.register("backend.export.xhtml",function(v) xhtmlfile = v end)

local function stopexport(v)
    starttiming(treehash)
    report_export("finalizing")
    finishexport()
    collapsetree()
    if trace_tree then
        prunetree(tree)
        report_export(table.serialize(tree,"root"))
    end
    checkinserts(tree.data)
    hashlistdata()
    if type(v) ~= "string" or v == variables.yes or v == "" then
        v = tex.jobname
    end
    local xmlfile = file.addsuffix(v,"export")
    local handle = io.open(xmlfile,"wb")
    if handle then
        report_export("saving xml data in '%s",xmlfile)
        handle:write(format(xmlpreamble,tex.jobname,os.date(),environment.version,version))
        if cssfile then
            local cssfiles = settings_to_array(cssfile)
            for i=1,#cssfiles do
                local cssfile = cssfiles[i]
                if type(cssfile) ~= "string" or cssfile == variables.yes or cssfile == "" or cssfile == xmlfile then
                    cssfile = file.replacesuffix(xmlfile,"css")
                else
                    cssfile = file.addsuffix(cssfile,"css")
                end
                report_export("adding css reference '%s",cssfile)
                handle:write(format(csspreamble,cssfile))
            end
        end
        flushtree(handle,tree.data)
        handle:close()
        -- css template file
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
        -- xhtml references
        if xhtmlfile then
            if type(v) ~= "string" or xhtmlfile == variables.yes or xhtmlfile == "" or xhtmlfile == xmlfile then
                xhtmlfile = file.replacesuffix(xmlfile,"xhtml")
            else
                xhtmlfile = file.addsuffix(xhtmlfile,"xhtml")
            end
            report_export("saving xhtml variant in '%s",xhtmlfile)
            local xmltree = xml.load(xmlfile)
            if xmltree then
                local xmlwrap = xml.wrap
                for e in xml.collected(xmltree,"/document") do
                    e.at["xmlns:xhtml"] = "http://www.w3.org/1999/xhtml"
                    break
                end
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
        end
    else
        report_export("unable to saving xml in '%s",xmlfile)
    end
    stoptiming(treehash)
end

local function startexport(v)
    if v and not exporting then
        nodes.tasks.appendaction("shipouts", "normalizers", "nodes.handlers.export")
        report_export("enabling export to xml")
        luatex.registerstopactions(function() stopexport(v) end)
        if trace_spaces then
            joiner_1 = "<S1/>"  joiner_2 = "<S2/>"  joiner_3 = "<S3/>"  joiner_4 = "<S4/>"  joiner_5 = "<S5/>"
            joiner_6 = "<S6/>"  joiner_7 = "<S7/>"  joiner_8 = "<S8/>"  joiner_9 = "<S9/>"  joiner_0 = "<S0/>"
        end
        exporting = true
    end
end

directives.register("backend.export",startexport) -- maybe .name

local function injectbreak()
    flushresult(entry)
    flushresult(makebreak(entry))
    result = { }
    entry = { entry[1], result, last, lastpar } -- entry[1] ?
end

local function injectspace(a,joiner)
    flushresult(entry)
    result = { joiner }
    local tl = taglist[a]
    entry = { tl , result, a, lastpar, n }
end

local function collectresults(head,list,p)
    local preceding = p or false
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
                    collectresults(components,nil,preceding)
--~                     preceding = true
                else
                    if last ~= at then
                        local tl = taglist[at]
                        if entry then
                            flushresult(entry)
                        end
                        if preceding then
                            preceding = false
                            result = { joiner_5 }
                        else
                            result = { }
                        end
                        lastpar = has_attribute(n,a_taggedpar)
                        entry = { tl, result, at, lastpar, n }
                        local ah = { -- this includes detail !
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
                    elseif last then
                        local at = has_attribute(n,a_taggedpar)
                        if at ~= lastpar then
                            injectbreak()
                            lastpar = at
                        end
                    end
                    local c = n.char
                    if c == 0x26 then
                        result[#result+1] = "&amp;"
                    elseif c == 0x3E then
                        result[#result+1] = "&gt;"
                    elseif c == 0x3C then
                        result[#result+1] = "&lt;"
                    elseif c == 0 then
                        result[#result+1] = "" -- utfchar(0) -- todo: check if "" is needed
                    else
                        local fc = fontchar[n.font]
                        if fc then
                            fc = fc and fc[c]
                            if fc then
                                local u = fc.tounicode
                                if u and u ~= "" then
                                    for s in gmatch(u,"....") do -- is this ok?
                                        result[#result+1] = utfchar(tonumber(s,16))
                                    end
                                else
                                    result[#result+1] = utfchar(c)
                                end
                            else -- weird, happens in hz (we really need to get rid of the pseudo fonts)
                                result[#result+1] = utfchar(c)
                            end
                        else
                            result[#result+1] = utfchar(c)
                        end
                    end
                end
            end
        elseif id == hlist_code or id == vlist_code then
            local ai = has_attribute(n,a_image)
            if ai then
                local at = has_attribute(n,a_tagged)
                if entry then
                    flushresult(entry)
                    result = { }
                    entry[2] = result -- mess, to be sorted out, but otherwise duplicates (still some spacing issues)
                end
                local tl = taglist[at]
                local i = locate_node(n,whatsit_code,refximage_code)
                if i then
                    attributehash[tl[#tl]] = { imageindex = i.index }
                end
                flushresult { tl, { }, 0, 0 } -- has an index, todo: flag empty element
                last = nil
                lastpar = nil
            else
--~                 if result and #result > 0 then -- and n.subtype == line_code then
--~                     local r = result[#result]
--~                     if type(r) == "string" and r ~= " " then
--~                         local s = utfsub(r,-1)
--~                         if s == hyphen then
--~                             result[#result] = utfsub(r,1,-2)
--~                         elseif s ~= joiner_7 then
--~                             result[#result] = r .. joiner_7
--~                 --~ preceding = true
--~                         end
--~                     end
--~                     preceding = false
--~                 end
                -- we need to determine an end-of-line
                preceding = collectresults(n.list,n,preceding)
                preceding = false
            end
        elseif id == disc_code then -- probably too late
            collectresults(n.replace,nil)
            preceding = false
        elseif id == glue_code then
            -- we need to distinguish between hskips and vskips
            local subtype = n.subtype
            if subtype == userskip_code then -- todo space_code
                if n.spec.width > threshold then
--~                     preceding = true
                    if result and last and #result > 0 and result[#result] ~= " " then
                        local a = has_attribute(n,a_tagged)
                        if a == last then
                            result[#result+1] = joiner_6
                            preceding = false
                        elseif a then
                            -- e.g LOGO<space>LOGO
                            preceding = false
                            last = a
                            injectspace(last,joiner_6)
                        end
                    end
                end
            elseif subtype == rightskip_code or subtype == parfillskip_code then
if result and #result > 0 then -- and n.subtype == line_code then
    local r = result[#result]
    if type(r) == "string" and r ~= " " then
        local s = utfsub(r,-1)
        if s == hyphen then
            result[#result] = utfsub(r,1,-2)
        elseif s ~= joiner_7 then
            result[#result] = r .. joiner_7
--~ preceding = true
        end
    end
    preceding = false
end
            end
        elseif id == kern_code then
            if n.kern > threshold then
--~                 preceding = true
                if result and last and #result > 0 and result[#result] ~= " " then
                    local a = has_attribute(n,a_tagged)
                    if a == last then
                        result[#result+1] = joiner_8
                        preceding = false
                    elseif a then
                        -- e.g LOGO<space>LOGO
                        preceding = false
                        last = a
                        injectspace(last,joiner_8)
                    end
                end
            end
        end
    end
    return preceding
end

function nodes.handlers.export(head)
    if result then
        -- maybe we need a better test for what is in result so far
        if page_breaks then
            joiner_0 = "<pagebreak/>"
        end
        result[#result+1] = joiner_0
    end
    starttiming(treehash)
    collectresults(head)
    -- no flush here, pending page stuff
    stoptiming(treehash)
    return head, true
end

statistics.register("xml exporting time", function()
    if exporting then
        return format("%s seconds", statistics.elapsedtime(treehash))
    end
end)

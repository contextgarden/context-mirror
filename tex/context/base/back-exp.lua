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
local format, match, concat, rep = string.format, string.match, table.concat, string.rep
local lpegmatch = lpeg.match
local utfchar = utf.char
local insert, remove = table.insert, table.remove

local trace_export = false  trackers.register  ("structures.export",           function(v) trace_export = v end)
local trace_spaces = false  trackers.register  ("structures.export.spaces",    function(v) trace_spaces = v end)
local trace_tree   = false  trackers.register  ("structures.export.showtree",  function(v) trace_tree   = v end)
local less_state   = false  directives.register("structures.export.lessstate", function(v) less_state   = v end)

local report_export = logs.new("export")

local nodes           = nodes
local attributes      = attributes
local variables       = interfaces.variables

local tasks           = nodes.tasks
local fontchar        = fonts.characters
local languagenames   = languages.numbers

local nodecodes       = nodes.nodecodes
local skipcodes       = nodes.skipcodes
local whatsitcodes    = nodes.whatsitcodes
local listcodes       = nodes.listcodes

local hlist_code      = nodecodes.hlist
local vlist_code      = nodecodes.vlist
local glyph_code      = nodecodes.glyph
local glue_code       = nodecodes.glue
local kern_code       = nodecodes.kern
local disc_code       = nodecodes.disc
local insert_code     = nodecodes.insert
local whatsit_code    = nodecodes.whatsit
local refximage_code  = whatsitcodes.pdfrefximage

local userskip_code   = skipcodes.userskip
local rightskip_code  = skipcodes.rightskip
local parfillskip_code= skipcodes.parfillskip

local line_code       = listcodes.line

local a_tagged        = attributes.private('tagged')
local a_image         = attributes.private('image')

local a_taggedalign   = attributes.private("taggedalign")
local a_taggedcolumns = attributes.private("taggedcolumns")
local a_taggedrows    = attributes.private("taggedrows")
local a_taggedpar     = attributes.private("taggedpar")
local a_taggedpacked  = attributes.private("taggedpacked")
local a_taggedsymbol  = attributes.private("taggedsymbol")
local a_taggedinsert  = attributes.private("taggedinsert")

local a_reference     = attributes.private('reference')

local has_attribute   = node.has_attribute
local traverse_nodes  = node.traverse
local slide_nodelist  = node.slide
local texattribute    = tex.attribute
local unsetvalue      = attributes.unsetvalue
local locate_node     = nodes.locate

local references      = structures.references
local structurestags  = structures.tags
local taglist         = structurestags.taglist
local properties      = structurestags.properties
local userdata        = structurestags.userdata -- might be combines with taglist

local version       = "0.10"
local result        = nil
local entry         = nil
local attributehash = { }
local handle        = nil
local hyphen        = utfchar(0xAD)
local colonsplitter = lpeg.splitat(":")
local dashsplitter  = lpeg.splitat("-")
local threshold     = 65536
local indexing      = false
local linedone      = false
local inlinedepth   = 0
local collapse      = true
local tree          = { data = { }, depth = 0 } -- root
local treestack     = { }
local treehash      = { }
local extras        = { }
local nofbreaks     = 0
local listhash      = { }

local last          = nil
local lastpar       = nil

local joiner_1      = " "
local joiner_2      = " " -- todo: test if this one can alwasy be ""
local joiner_3      = " "
local joiner_4      = " "
local joiner_5      = " "
local joiner_6      = " "
local joiner_7      = " "
local joiner_8      = " "
local joiner_9      = " "
local joiner_0      = " "

-- local P, C, Cc = lpeg.P, lpeg.C, lpeg.Cc
--
-- local dash, colon = P("-"), P(":")
--
-- local precolon, predash, rest = P((1-colon)^1), P((1-dash )^1), P(1)^1
--
-- local tagsplitter = C(precolon) * colon * C(predash) * dash * C(rest) +
--                     C(predash)  * dash  * Cc(nil)           * C(rest)

local spaces = { } -- watch how we also moved the -1 in depth-1 to the creator

setmetatable(spaces, { __index = function(t,k) t[k] = rep("  ",k-1) return t[k] end } )

properties.vspace = { export = "break", nature = "display" }

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

function extras.document(element,detail,n,fulltag,hash)
    handle:write(" language='",languagenames[tex.count.mainlanguagenumber],"'")
    if not less_state then
        handle:write(" file='",tex.jobname,"'")
        handle:write(" date='",os.date(),"'")
        handle:write(" context='",environment.version,"'")
        handle:write(" version='",version,"'")
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

local insertids = { }

function structurestags.setdescriptionid(tag,n)
    local nd = structures.notes.get(tag,n)
    if nd then
        local r = nd.references
        texattribute[a_taggedinsert] = r.internal or unsetvalue
    else
        texattribute[a_taggedinsert] = unsetvalue
    end
end

function extras.descriptiontag(element,detail,n,fulltag,di)
    local hash = attributehash[fulltag]
    if hash then
        local v = hash.insert
        v = v and insertids[v]
        if v then
            handle:write(" insert='",v,"'")
        end
    end
end

function extras.descriptionsymbol(element,detail,n,fulltag,di)
    local hash = attributehash[fulltag]
    if hash then
        local v = hash.insert
        v = v and insertids[v]
        if v then
            handle:write(" insert='",v,"'")
        end
    end
end

function extras.image(element,detail,n,fulltag,di)
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

evaluators.inner = function(var)
    local inner = var.inner
    if var.inner then
        handle:write(" location='",inner,"'")
    end
end

evaluators.outer = function(var)
    local file, url = references.checkedfileorurl(var.outer,var.outer)
    if url then
        handle:write(" url='",file,"'")
    elseif file then
        handle:write(" file='",file,"'")
    end
end

evaluators["outer with inner"] = function(var)
    local file = references.checkedfile(var.f)
    if file then
        handle:write(" file='",file,"'")
    end
    local inner = var.inner
    if var.inner then
        handle:write(" location='",inner,"'")
    end
end

evaluators.special = function(var)
    local handler = specials[var.special]
    if handler then
        handler(var)
    end
end

evaluators["special outer with operation"]     = evaluators.special
evaluators["special operation"]                = evaluators.special
evaluators["special operation with arguments"] = evaluators.special

function specials.url(var)
    local url = references.checkedurl(var.operation)
    if url then
        handle:write(" url='",url,"'")
    end
end

function specials.file(var)
    local file = references.checkedfile(var.operation)
    if file then
        handle:write(" file='",file,"'")
    end
end

function specials.fileorurl(var)
    local file, url = references.checkedfileorurl(var.operation,var.operation)
    if url then
        handle:write(" url='",file,"'")
    elseif file then
        handle:write(" file='",file,"'")
    end
end

local function addreference(references) -- todo: specials -> exporters and then concat
    if references then
        local reference = references.reference
        if reference and reference ~= "" then
            local prefix = references.prefix
            if prefix and prefix ~= "" then
                handle:write(" prefix='",prefix,"'")
            end
            handle:write(" reference='",reference,"'")
            for i=1,#references do
                local r = references[i]
                local e = evaluators[r.kind]
                if e then
                    e(r)
                end
            end
        end
    end
end

-- end of references related code  --

function extras.link(element,detail,n,fulltag,di)
    -- why so often
    local hash = attributehash[fulltag]
    if hash then
        local references = hash.reference
        if references then
            addreference(structures.references.get(references))
        end
    end
end

function extras.section(element,detail,n,fulltag,di)
    local hash = listhash[element]
    hash = hash and hash[n]
    addreference(hash and hash.references)
end

function extras.float(element,detail,n,fulltag,di)
    local hash = listhash[element]
    hash = hash and hash[n]
    addreference(hash and hash.references)
end

function extras.itemgroup(element,detail,n,fulltag,di)
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
--~ table.print(attributehash)
--~ print(ddi.fulltag,hash)
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

function extras.tablecell(element,detail,n,fulltag,di)
    local hash = attributehash[fulltag]
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

function extras.tabulatecell(element,detail,n,fulltag,di)
    local hash = attributehash[fulltag]
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

local function emptytag(element,nature,depth)
    handle:write("\n",spaces[depth],"<",element,"/>\n")
end

local function begintag(element,nature,depth,di,empty)
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
    handle:write("<",element)
    if detail then
        handle:write(" detail='",detail,"'")
    end
    if indexing and n then
        handle:write(" n='",n,"'")
    end
    local extra = extras[element]
    if extra then
        extra(element,detail,n,fulltag,di)
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
end

local function endtag(element,nature,depth,empty)
    if nature == "display" then
        if inlinedepth == 0 then
            if empty then
                handle:write("</>\n")
            else
                if not linedone then
                    handle:write("\n")
                end
                handle:write(spaces[depth],"</",element,">\n")
            end
            linedone = true
        else
            if empty then
                handle:write("/>")
            else
                handle:write("</",element,">")
            end
        end
    else
        inlinedepth = inlinedepth - 1
        if empty then
            handle:write("/>")
        else
            handle:write("</",element,">")
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
        node       = entry[5],
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

local function flush(current,content)
    if content then
        if collapse then
            tree.data[#tree.data+1] = content
        else
            handle:write(content)
        end
    end
end

local function flushresult(entry)
    local current, content = entry[1], entry[2]
    if not content then
        -- skip
    else
        local newdepth, olddepth, content = #current, #treestack, concat(content)
        if trace_export then
            report_export("%3i => %3i : handling: ",olddepth,newdepth,current[newdepth])
        end
        if olddepth <= 0 then
            for i=1,newdepth do
                if trace_export then
                    report_export("[1]  push :",current[i])
                end
                push(current[i],i,entry)
            end
            flush(current,content)
        elseif newdepth < olddepth then
            for i=newdepth,olddepth-1 do
                if trace_export then
                    report_export("[2a] pop  :",current[i])
                end
                pop()
            end
            -- we can have a pagebreak and for instance a new chapter
            -- will mess up the structure then
            for i=newdepth,1,-1 do
                if current[i] ~= treestack[i].fulltag then -- needs checking
                    if trace_export then
                        report_export("[2b] pop  :",current[i])
                    end
                    pop()
                else
                    break
                end
            end
            olddepth = #treestack
            for i=olddepth+1,newdepth do
                if trace_export then
                    report_export("[2]  push :",current[i])
                end
                push(current[i],i,entry)
            end
            flush(current,content)
        elseif newdepth > olddepth then
            for i=olddepth,1,-1 do
                if current[i] ~= treestack[i].fulltag then
                    if trace_export then
                        report_export("[3]  pop  :",current[i])
                    end
                    pop()
                else
                    break
                end
            end
            olddepth = #treestack
            for i=olddepth+1,newdepth do
                if trace_export then
                    report_export("[3]  push :",current[i])
                end
                push(current[i],i,entry)
            end
            flush(current,content)
        elseif current[newdepth] == treestack[olddepth] then --move up ?
            -- continuation
            flush(current,content)
        else
            for i=olddepth,1,-1 do
                if current[i] ~= treestack[i].fulltag then
                    if trace_export then
                        report_export("[4]  pop  :",current[i])
                    end
                    pop()
                else
                    break
                end
            end
            olddepth = #treestack
            for i=olddepth+1,newdepth do
                if trace_export then
                    report_export("[4]  push :",current[i])
                end
                push(current[i],i,entry)
            end
            flush(current,content)
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

local function checkreferences(data)
    local c = structures.lists.collected
    for i=1,#c do -- todo: make hash from name -> n
        local ci = c[i]
        local name = ci.metadata.kind
        local hash = listhash[name]
        if not hash then
            hash = { }
            listhash[name] = hash
        end
        local tag = ci.references.tag
        if tag then
            hash[tag] = ci
        end
    end
end

local function flushtree(data)
    for i=1,#data do
        local di = data[i]
        if not di then
        -- collapsed
        elseif type(di) == "string" then
            handle:write(di)
            linedone = false
        elseif not di.collapsed then
            local element = di.element
            if element == "break" then
                emptytag(element,nature,di.depth)
            else
                local nature, depth = di.nature, di.depth
                local did = di.data
                local nid = #did
                if nid == 0 or (nid == 1 and did[1] == "") then
                    begintag(element,nature,depth,di,true)
                    -- no content
                    endtag(element,nature,depth,true)
                else
                    begintag(element,nature,depth,di)
                    flushtree(did)
                    endtag(element,nature,depth)
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
            for j=1,#vd do
                local vdj = vd[j]
                if type(vdj) == "string" then
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

function finishexport()
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

local function stopexport()
    if handle then
        report_export("finalizing")
        finishexport()
        if collapse then
            collapsetree()
            if trace_tree then
                prunetree(tree)
                report_export(table.serialize(tree,"root"))
            end
        end
        checkinserts(tree.data)
        checkreferences(tree.data)
        flushtree(tree.data)
        handle = false
    end
end

-- encoding='utf-8'

local preamble = [[
<?xml version='1.0' standalone='yes' ?>

<!-- input filename   : %- 17s -->
<!-- processing date  : %- 17s -->
<!-- context version  : %- 17s -->
<!-- exporter version : %- 17s -->
]]

local done = false

local function startexport(v)
    if not done then
        local filename = tex.jobname
        if type(v) == "string" and v ~= variables.yes and v ~= "" then
            filename = v
        end
        local filename = file.addsuffix(filename,"export") -- todo: v
        handle = io.open(filename,"wb")
        if handle then
            nodes.tasks.appendaction("shipouts", "normalizers", "nodes.handlers.export")
            report_export("saving xml in '%s",filename)
            handle:write(format(preamble,tex.jobname,os.date(),environment.version,version))
            luatex.registerstopactions(stopexport)
        end
        done = true
    end
end

directives.register("backend.export",startexport)

local function injectbreak()
    flushresult(entry)
    flushresult(makebreak(entry))
    result = { }
    entry = { entry[1], result, last, lastpar }
end

local function collectresults(head,list,p)
    local preceding = p or false -- nasty hack
    for n in traverse_nodes(head) do
        local id = n.id -- 14: image, 8: literal (mp)
        if id == glyph_code then
            local at = has_attribute(n,a_tagged)
            if at then
                -- we could add tonunicodes for ligatures
                local components =  n.components
                if components then
                    collectresults(components,nil)
                    preceding = false
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
                        entry = { tl , result, at, lastpar, n }
                        attributehash[tl[#tl]] = { -- this includes detail !
                            align     = has_attribute(n,a_taggedalign  ),
                            columns   = has_attribute(n,a_taggedcolumns),
                            rows      = has_attribute(n,a_taggedrows   ),
                            packed    = has_attribute(n,a_taggedpacked ),
                            symbol    = has_attribute(n,a_taggedsymbol ),
                            insert    = has_attribute(n,a_taggedinsert ),
                            reference = has_attribute(n,a_reference    ),
                        }
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
                                if u then
                                    for s in gmatch(u,"....") do -- is this ok?
                                        result[#result+1] = utfchar(tonumber(s,16))
                                    end
                                else
                                    result[#result+1] = utfchar(c)
                                end
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
             -- maybe check for lines: n.subtype = line_code
                preceding = collectresults(n.list,n,preceding)
                preceding = false
            end
        elseif id == disc_code then
            collectresults(n.replace,nil)
            preceding = false
        elseif id == glue_code then
            local subtype = n.subtype
            if subtype == userskip_code then
                if n.spec.width > threshold then
                    preceding = true
                    if result then
                        if last and #result > 0 and result[#result] ~= " " then
                            if has_attribute(n,a_tagged) == last then
                                result[#result+1] = joiner_6
                                preceding = false
                            end
                        end
                    end
                end
--~             elseif subtype == rightskip_code or subtype == parfillskip_code then
--~                 if result and last and #result > 0 and result[#result] ~= " " then
--~                     result[#result+1] = joiner_7
--~                 end
            end
        elseif id == kern_code then
            if n.kern > threshold then
                preceding = true
                if result then
                    if last and #result > 0 and result[#result] ~= " " then
                        if has_attribute(n,a_tagged) == last then
                            result[#result+1] = joiner_8
                            preceding = false
                        end
                    end
                elseif not preceding then
                    preceding = true
                end
            end
        end
    end
    return preceding
end

function nodes.handlers.export(head)
    if trace_spaces then
        joiner_1 = "<S1/>"  joiner_2 = "<S2/>"  joiner_3 = "<S3/>"  joiner_4 = "<S4/>"  joiner_5 = "<S5/>"
        joiner_6 = "<S6/>"  joiner_7 = "<S7/>"  joiner_8 = "<S8/>"  joiner_9 = "<S9/>"  joiner_0 = "<S0/>"
    end
    collectresults(head)
    -- no flush here, pending page stuff
    return head, true
end

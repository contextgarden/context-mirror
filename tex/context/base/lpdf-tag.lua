if not modules then modules = { } end modules ['lpdf-tag'] = {
    version   = 1.001,
    comment   = "companion to lpdf-tag.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local format, match, concat = string.format, string.match, table.concat
local lpegmatch = lpeg.match
local utfchar = utf.char

local trace_tags = false  trackers.register("structures.tags", function(v) trace_tags = v end)

local report_tags = logs.reporter("backend","tags")

local backends, lpdf, nodes = backends, lpdf, nodes

local nodeinjections   = backends.pdf.nodeinjections
local codeinjections   = backends.pdf.codeinjections

local tasks            = nodes.tasks

local pdfdictionary    = lpdf.dictionary
local pdfarray         = lpdf.array
local pdfboolean       = lpdf.boolean
local pdfconstant      = lpdf.constant
local pdfreference     = lpdf.reference
local pdfunicode       = lpdf.unicode
local pdfstring        = lpdf.string
local pdfflushobject   = lpdf.flushobject
local pdfreserveobject = lpdf.reserveobject
local pdfpagereference = lpdf.pagereference

local nodepool         = nodes.pool

local pdfliteral       = nodepool.pdfliteral

local nodecodes        = nodes.nodecodes

local hlist_code       = nodecodes.hlist
local vlist_code       = nodecodes.vlist
local glyph_code       = nodecodes.glyph

local a_tagged         = attributes.private('tagged')
local a_image          = attributes.private('image')

local has_attribute, set_attribute, traverse_nodes, traverse_id = node.has_attribute, node.set_attribute, node.traverse, node.traverse_id
local tosequence = nodes.tosequence
local copy_node, slide_nodelist = node.copy, node.slide

local structure_stack = { }
local structure_kids  = pdfarray()
local structure_ref   = pdfreserveobject()
local parent_ref      = pdfreserveobject()
local root            = { pref = pdfreference(structure_ref), kids = structure_kids }
local tree            = { }
local elements        = { }
local names           = pdfarray()
local taglist         = structures.tags.taglist
local usedlabels      = structures.tags.labels
local properties      = structures.tags.properties
local usedmapping     = { }

local colonsplitter   = lpeg.splitat(":")
local dashsplitter    = lpeg.splitat("-")

local add_ids         = false -- true


--~ function codeinjections.maptag(original,target,kind)
--~     mapping[original] = { target, kind or "inline" }
--~ end

local function finishstructure()
    if #structure_kids > 0 then
        local nums, n = pdfarray(), 0
        for i=1,#tree do
            n = n + 1 ; nums[n] = i-1
            n = n + 1 ; nums[n] = pdfreference(pdfflushobject(tree[i]))
        end
        local parenttree = pdfdictionary {
            Nums = nums
        }
        -- we need to split names into smaller parts (e.g. alphabetic or so)
        if add_ids then
            local kids = pdfdictionary {
                Limits = pdfarray { names[1], names[#names-1] },
                Names  = names,
            }
            local idtree = pdfdictionary {
                Kids = pdfarray { pdfreference(pdfflushobject(kids)) },
            }
        end
        --
        local rolemap = pdfdictionary()
        for k, v in next, usedmapping do
            k = usedlabels[k] or k
            local p = properties[k]
            rolemap[k] = pdfconstant(p and p.pdf or "Span") -- or "Div"
        end
        local structuretree = pdfdictionary {
            Type       = pdfconstant("StructTreeRoot"),
            K          = pdfreference(pdfflushobject(structure_kids)),
            ParentTree = pdfreference(pdfflushobject(parent_ref,parenttree)),
            IDTree     = (add_ids and pdfreference(pdfflushobject(idtree))) or nil,
            RoleMap    = rolemap,
        }
        pdfflushobject(structure_ref,structuretree)
        lpdf.addtocatalog("StructTreeRoot",pdfreference(structure_ref))
        --
        local markinfo = pdfdictionary {
            Marked         = pdfboolean(true),
         -- UserProperties = pdfboolean(true),
         -- Suspects       = pdfboolean(true),
        }
        lpdf.addtocatalog("MarkInfo",pdfreference(pdfflushobject(markinfo)))
        --
        for fulltag, element in next, elements do
            pdfflushobject(element.knum,element.kids)
        end
    end
end

lpdf.registerdocumentfinalizer(finishstructure,"document structure")

local index, pageref, pagenum, list = 0, nil, 0, nil

local pdf_mcr            = pdfconstant("MCR")
local pdf_struct_element = pdfconstant("StructElem")

local function initializepage()
    index = 0
    pagenum = tex.count.realpageno
    pageref = pdfreference(pdfpagereference(pagenum))
    list = pdfarray()
    tree[pagenum] = list -- we can flush after done, todo
end

local function finishpage()
    -- flush what can be flushed
    lpdf.addtopageattributes("StructParents",pagenum-1)
end

-- here we can flush and free elements that are finished

local function makeelement(fulltag,parent)
    local tag, n = lpegmatch(dashsplitter,fulltag)
    local tg, detail = lpegmatch(colonsplitter,tag)
    local k, r = pdfarray(), pdfreserveobject()
    usedmapping[tg] = true
    tg = usedlabels[tg] or tg
    local d = pdfdictionary {
        Type       = pdf_struct_element,
        S          = pdfconstant(tg),
        ID         = (add_ids and fulltag) or nil,
        T          = detail and detail or nil,
        P          = parent.pref,
        Pg         = pageref,
        K          = pdfreference(r),
     -- Alt        = " Who cares ",
     -- ActualText = " Hi Hans ",
    }
    local s = pdfreference(pdfflushobject(d))
    if add_ids then
        names[#names+1] = fulltag
        names[#names+1] = s
    end
    local kids = parent.kids
    kids[#kids+1] = s
    elements[fulltag] = { tag = tag, pref = s, kids = k, knum = r, pnum = pagenum }
end

local function makecontent(parent,start,stop,slist,id)
    local tag, kids = parent.tag, parent.kids
    local last = index
    if id == "image" then
        local d = pdfdictionary {
            Type = pdf_mcr,
            Pg   = pageref,
            MCID = last,
            Alt  = "image",
        }
        kids[#kids+1] = d
    elseif pagenum == parent.pnum then
        kids[#kids+1] = last
    else
        local d = pdfdictionary {
            Type = pdf_mcr,
            Pg   = pageref,
            MCID = last,
        }
     -- kids[#kids+1] = pdfreference(pdfflushobject(d))
        kids[#kids+1] = d
    end
    --
    local bliteral = pdfliteral(format("/%s <</MCID %s>>BDC",tag,last))
    local prev = start.prev
    if prev then
        prev.next, bliteral.prev = bliteral, prev
    end
    start.prev, bliteral.next = bliteral, start
    if slist and slist.list == start then
        slist.list = bliteral
    elseif not prev then
        report_tags("this can't happen: injection in front of nothing")
    end
    --
    local eliteral = pdfliteral("EMC")
    local next = stop.next
    if next then
        next.prev, eliteral.next = eliteral, next
    end
    stop.next, eliteral.prev = eliteral, stop
    --
    index = index + 1
    list[index] = parent.pref
    return bliteral, eliteral
end

-- -- --

local level, last, ranges, range = 0, nil, { }, nil

local function collectranges(head,list)
    for n in traverse_nodes(head) do
        local id = n.id -- 14: image, 8: literal (mp)
        if id == glyph_code then
            local at = has_attribute(n,a_tagged)
            if not at then
                range = nil
            elseif last ~= at then
                range = { at, "glyph", n, n, list } -- attr id start stop list
                ranges[#ranges+1] = range
                last = at
            elseif range then
                range[4] = n -- stop
            end
        elseif id == hlist_code or id == vlist_code then
            local at = has_attribute(n,a_image)
            if at then
                local at = has_attribute(n,a_tagged)
                if not at then
                    range = nil
                else
                    ranges[#ranges+1] = { at, "image", n, n, list } -- attr id start stop list
                end
                last = nil
            else
                local nl = n.list
                slide_nodelist(nl) -- temporary hack till math gets slided (tracker item)
                collectranges(nl,n)
            end
        end
    end
end

function nodeinjections.addtags(head)
    -- no need to adapt head, as we always operate on lists
    level, last, ranges, range = 0, nil, { }, nil
    initializepage()
    collectranges(head)
    if trace_tags then
        for i=1,#ranges do
            local range = ranges[i]
            local attr, id, start, stop = range[1], range[2], range[3], range[4]
            local tags = taglist[attr]
            if tags then -- not ok ... only first lines
                report_tags("%s => %s : %05i %s",tosequence(start,start),tosequence(stop,stop),attr,concat(tags," "))
            end
        end
    end
    for i=1,#ranges do
        local range = ranges[i]
        local attr, id, start, stop, list = range[1], range[2], range[3], range[4], range[5]
        local tags = taglist[attr]
        local prev = root
        local noftags, tag = #tags, nil
        for j=1,noftags do
            local tag = tags[j]
            if not elements[tag] then
                makeelement(tag,prev)
            end
            prev = elements[tag]
        end
        local b, e = makecontent(prev,start,stop,list,id)
        if start == head then
            report_tags("this can't happen: parent list gets tagged")
            head = b
        end
    end
    finishpage()
    -- can be separate feature
    --
    -- injectspans(head) -- does to work yet
    --
    return head, true
end

-- this belongs elsewhere (export is not pdf related)

function codeinjections.enabletags(tg,lb)
    structures.tags.handler = nodeinjections.addtags
    tasks.enableaction("shipouts","structures.tags.handler")
    tasks.enableaction("shipouts","nodes.handlers.accessibility")
    tasks.enableaction("math","noads.handlers.tags")
    -- maybe also textblock
    if trace_tags then
        report_tags("enabling structure tags")
    end
end

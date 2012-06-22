if not modules then modules = { } end modules ['lpdf-nod'] = {
    version   = 1.001,
    comment   = "companion to lpdf-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local format         = string.format

local copy_node      = node.copy
local new_node       = node.new

local nodepool       = nodes.pool
local register       = nodepool.register
local whatsitcodes   = nodes.whatsitcodes
local nodeinjections = backends.nodeinjections

local pdfliteral     = register(new_node("whatsit", whatsitcodes.pdfliteral))    pdfliteral.mode  = 1
local pdfsave        = register(new_node("whatsit", whatsitcodes.pdfsave))
local pdfrestore     = register(new_node("whatsit", whatsitcodes.pdfrestore))
local pdfsetmatrix   = register(new_node("whatsit", whatsitcodes.pdfsetmatrix))
local pdfdest        = register(new_node("whatsit", whatsitcodes.pdfdest))       pdfdest.named_id = 1 -- xyz_zoom untouched
local pdfannot       = register(new_node("whatsit", whatsitcodes.pdfannot))

local variables      = interfaces.variables

local views = { -- beware, we do support the pdf keys but this is *not* official
    xyz   = 0, [variables.standard]  = 0,
    fit   = 1, [variables.fit]       = 1,
    fith  = 2, [variables.width]     = 2,
    fitv  = 3, [variables.height]    = 3,
    fitb  = 4,
    fitbh = 5, [variables.minwidth]  = 5,
    fitbv = 6, [variables.minheight] = 6,
    fitr  = 7,
}

function nodepool.pdfliteral(str)
    local t = copy_node(pdfliteral)
    t.data = str
    return t
end

function nodepool.pdfdirect(str)
    local t = copy_node(pdfliteral)
    t.data = str
    t.mode = 1
    return t
end

function nodepool.pdfsave()
    return copy_node(pdfsave)
end

function nodepool.pdfrestore()
    return copy_node(pdfrestore)
end

function nodepool.pdfsetmatrix(rx,sx,sy,ry,tx,ty)
    local t = copy_node(pdfsetmatrix)
    t.data = format("%s %s %s %s",rx or 0,sx or 0,sy or 0,ry or 0) -- todo: tx ty
    return t
end

nodeinjections.save      = nodepool.pdfsave
nodeinjections.restore   = nodepool.pdfrestore
nodeinjections.transform = nodepool.pdfsetmatrix

function nodepool.pdfannotation(w,h,d,data,n)
    local t = copy_node(pdfannot)
    if w and w ~= 0 then
        t.width = w
    end
    if h and h ~= 0 then
        t.height = h
    end
    if d and d ~= 0 then
        t.depth = d
    end
    if n then
        t.objnum = n
    end
    if data and data ~= "" then
        t.data = data
    end
    return t
end

-- (!) The next code in pdfdest.w is wrong:
--
-- case pdf_dest_xyz:
--     if (matrixused()) {
--         set_rect_dimens(pdf, p, parent_box, cur, alt_rule, pdf_dest_margin) ;
--     } else {
--         pdf_ann_left(p) = pos.h ;
--         pdf_ann_top (p) = pos.v ;
--     }
--     break ;
--
-- so we need to force a matrix.

function nodepool.pdfdestination(w,h,d,name,view,n)
    local t = copy_node(pdfdest)
    local hasdimensions = false
    if w and w ~= 0 then
        t.width = w
        hasdimensions = true
    end
    if h and h ~= 0 then
        t.height = h
        hasdimensions = true
    end
    if d and d ~= 0 then
        t.depth = d
        hasdimensions = true
    end
    if n then
        t.objnum = n
    end
    view = views[view] or view or 1 -- fit is default
    t.dest_id = name
    t.dest_type = view
    if hasdimensions and view == 0 then -- xyz
        -- see (!) s -> m -> t -> r
        local s = copy_node(pdfsave)
        local m = copy_node(pdfsetmatrix)
        local r = copy_node(pdfrestore)
        m.data = format("1 0 0 1")
        s.next = m  m.next = t  t.next = r
        m.prev = s  t.prev = m  r.prev = t
        return s -- a list
    else
        return t
    end
end

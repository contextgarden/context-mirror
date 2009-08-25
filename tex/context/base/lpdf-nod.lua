if not modules then modules = { } end modules ['lpdf-nod'] = {
    version   = 1.001,
    comment   = "companion to lpdf-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local copy_node, new_node = node.copy, node.new

local pdfliteral = nodes.register(new_node("whatsit", 8))    pdfliteral.mode  = 1
local pdfdest    = nodes.register(new_node("whatsit",19))    pdfdest.named_id = 1 -- xyz_zoom untouched
local pdfannot   = nodes.register(new_node("whatsit",15))

local variables = interfaces.variables

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

function nodes.pdfliteral(str)
    local t = copy_node(pdfliteral)
    t.data = str
    return t
end

function nodes.pdfannot(w,h,d,data,n)
    local t = copy_node(pdfannot)
    if w and w ~= 0 then t.width  = w end
    if h and h ~= 0 then t.height = h end
    if d and d ~= 0 then t.depth  = d end
    if n            then t.objnum = n end
    if data and data ~= "" then t.data = data end
    return t
end

function nodes.pdfdest(w,h,d,name,view,n)
    local t = copy_node(pdfdest)
    if w and w ~= 0 then t.width  = w end
    if h and h ~= 0 then t.height = h end
    if d and d ~= 0 then t.depth  = d end
    if n            then t.objnum = n end
    t.dest_id = name
    t.dest_type = views[view] or view or 1 -- fit is default
    return t
end

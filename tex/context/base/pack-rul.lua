if not modules then modules = { } end modules ['pack-rul'] = {
    version   = 1.001,
    comment   = "companion to pack-rul.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

--[[ldx--
<p>An explanation is given in the history document <t>mk</t>.</p>
--ldx]]--

-- we need to be careful with display math as it uses shifts
-- challenge: adapt glue_set
-- setfield(h,"glue_set", getfield(h,"glue_set") * getfield(h,"width")/maxwidth -- interesting ... doesn't matter much

local hlist_code      = nodes.nodecodes.hlist
local vlist_code      = nodes.nodecodes.vlist
local box_code        = nodes.listcodes.box
local line_code       = nodes.listcodes.line

local texsetdimen     = tex.setdimen
local texsetcount     = tex.setcount
local texgetbox       = tex.getbox
local hpack           = nodes.hpack
local free            = nodes.free
local copy            = nodes.copy_list
local traverse_id     = nodes.traverse_id
local node_dimensions = nodes.dimensions

function commands.doreshapeframedbox(n)
    local box            = texgetbox(n)
    local noflines       = 0
    local firstheight    = nil
    local lastdepth      = nil
    local lastlinelength = 0
    local minwidth       = 0
    local maxwidth       = 0
    local totalwidth     = 0
    local averagewidth   = 0
    local boxwidth       = box.width
    if boxwidth ~= 0 then -- and h.subtype == vlist_code
        local list = box.list
        if list then
            local function check(n,repack)
                if not firstheight then
                    firstheight = n.height
                end
                lastdepth = n.depth
                noflines = noflines + 1
                local l = n.list
                if l then
                    if repack then
                        local subtype = n.subtype
                        if subtype == box_code or subtype == line_code then
                            lastlinelength = node_dimensions(l,n.dir) -- used to be: hpack(copy(l)).width
                        else
                            lastlinelength = n.width
                        end
                    else
                        lastlinelength = n.width
                    end
                    if lastlinelength > maxwidth then
                        maxwidth = lastlinelength
                    end
                    if lastlinelength < minwidth or minwidth == 0 then
                        minwidth = lastlinelength
                    end
                    totalwidth = totalwidth + lastlinelength
                end
            end
            local hdone = false
            for h in traverse_id(hlist_code,list) do -- no dir etc needed
                check(h,true)
                hdone = true
            end
         -- local vdone = false
            for v in traverse_id(vlist_code,list) do -- no dir etc needed
                check(v,false)
             -- vdone = true
            end
            if not firstheight then
                -- done
            elseif maxwidth ~= 0 then
                if hdone then
                    for h in traverse_id(hlist_code,list) do
                        local l = h.list
                        if l then
                            local subtype = h.subtype
                            if subtype == box_code or subtype == line_code then
                                h.list = hpack(l,maxwidth,'exactly',h.dir)
                                h.shift = 0 -- needed for display math
                            end
                            h.width = maxwidth
                        end
                    end
                    box.width    = maxwidth -- moved
                    averagewidth = noflines > 0 and totalwidth/noflines or 0
                end
             -- if vdone then
             --     for v in traverse_id(vlist_code,list) do
             --         local width = n.width
             --         if width > maxwidth then
             --             v.width = maxwidth
             --         end
             --     end
             -- end
                box.width = maxwidth
                averagewidth = noflines > 0 and totalwidth/noflines or 0
            end
        end
    end
    texsetcount("global","framednoflines",noflines)
    texsetdimen("global","framedfirstheight",firstheight or 0) -- also signal
    texsetdimen("global","framedlastdepth",lastdepth or 0)
    texsetdimen("global","framedminwidth",minwidth)
    texsetdimen("global","framedmaxwidth",maxwidth)
    texsetdimen("global","framedaveragewidth",averagewidth)
end

function commands.doanalyzeframedbox(n)
    local box         = texgetbox(n)
    local noflines    = 0
    local firstheight = nil
    local lastdepth   = nil
    if box.width ~= 0 then
        local list = box.list
        if list then
            local function check(n)
                if not firstheight then
                    firstheight = n.height
                end
                lastdepth = n.depth
                noflines = noflines + 1
            end
            for h in traverse_id(hlist_code,list) do
                check(h)
            end
            for v in traverse_id(vlist_code,list) do
                check(v)
            end
        end
    end
    texsetcount("global","framednoflines",noflines)
    texsetdimen("global","framedfirstheight",firstheight or 0)
    texsetdimen("global","framedlastdepth",lastdepth or 0)
end

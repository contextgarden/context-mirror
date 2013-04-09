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

local texsetdimen, texsetcount, texbox = tex.setdimen, tex.setcount, tex.box
local hpack, free, copy, traverse_id = node.hpack, node.free, node.copy_list, node.traverse_id
local texdimen, texcount = tex.dimen, tex.count

local hlist_code      = nodes.nodecodes.hlist
local node_dimensions = node.dimensions

-- function commands.doreshapeframedbox(n)
--     local box            = texbox[n]
--     local noflines       = 0
--     local firstheight    = nil
--     local lastdepth      = nil
--     local lastlinelength = 0
--     local minwidth       = 0
--     local maxwidth       = 0
--     local totalwidth     = 0
--     if box.width ~= 0 then
--         local list = box.list
--         if list then
--             for h in traverse_id(hlist_code,list) do -- no dir etc needed
--                 if not firstheight then
--                     firstheight = h.height
--                 end
--                 lastdepth = h.depth
--                 noflines = noflines + 1
--                 local l = h.list
--                 if l then
--                     local p = hpack(copy(l))
--                     lastlinelength = p.width
--                     if lastlinelength > maxwidth then
--                         maxwidth = lastlinelength
--                     end
--                     if lastlinelength < minwidth or minwidth == 0 then
--                         minwidth = lastlinelength
--                     end
--                     totalwidth = totalwidth + lastlinelength
--                     free(p)
--                 end
--             end
--             if firstheight then
--                 if maxwidth ~= 0 then
--                     for h in traverse_id(hlist_code,list) do
--                         local l = h.list
--                         if l then
--                     --  if h.width ~= maxwidth then -- else no display math handling (uses shift)
--                             h.list = hpack(l,maxwidth,'exactly',h.dir)
--                             h.shift = 0 -- needed for display math
--                             h.width = maxwidth
--                     --  end
--                         end
--                     end
--                 end
--                 box.width = maxwidth
--             end
--         end
--     end
--  -- print("reshape", noflines, firstheight or 0, lastdepth or 0)
--     texsetcount("global","framednoflines",     noflines)
--     texsetdimen("global","framedfirstheight",  firstheight or 0)
--     texsetdimen("global","framedlastdepth",    lastdepth or 0)
--     texsetdimen("global","framedminwidth",     minwidth)
--     texsetdimen("global","framedmaxwidth",     maxwidth)
--     texsetdimen("global","framedaveragewidth", noflines > 0 and totalwidth/noflines or 0)
-- end

function commands.doreshapeframedbox(n)
    local box            = texbox[n]
    local noflines       = 0
    local firstheight    = nil
    local lastdepth      = nil
    local lastlinelength = 0
    local minwidth       = 0
    local maxwidth       = 0
    local totalwidth     = 0
    if box.width ~= 0 then
        local list = box.list
        if list then
            for h in traverse_id(hlist_code,list) do -- no dir etc needed
                if not firstheight then
                    firstheight = h.height
                end
                lastdepth = h.depth
                noflines = noflines + 1
                local l = h.list
                if l then
                    lastlinelength = node_dimensions(l)
                    if lastlinelength > maxwidth then
                        maxwidth = lastlinelength
                    end
                    if lastlinelength < minwidth or minwidth == 0 then
                        minwidth = lastlinelength
                    end
                    totalwidth = totalwidth + lastlinelength
                end
            end
            if firstheight then
                if maxwidth ~= 0 then
                    for h in traverse_id(hlist_code,list) do
                        local l = h.list
                        if l then
                    --  if h.width ~= maxwidth then -- else no display math handling (uses shift)
                            -- challenge: adapt glue_set
                         -- h.glue_set = h.glue_set * h.width/maxwidth -- interesting ... doesn't matter much
                         -- h.width = maxwidth
                            h.list = hpack(l,maxwidth,'exactly',h.dir)
                            h.shift = 0 -- needed for display math
                            h.width = maxwidth
                    --  end
                        end
                    end
                end
                box.width = maxwidth
            end
        end
    end
 -- print("reshape", noflines, firstheight or 0, lastdepth or 0)
    texsetcount("global","framednoflines",     noflines)
    texsetdimen("global","framedfirstheight",  firstheight or 0)
    texsetdimen("global","framedlastdepth",    lastdepth or 0)
    texsetdimen("global","framedminwidth",     minwidth)
    texsetdimen("global","framedmaxwidth",     maxwidth)
    texsetdimen("global","framedaveragewidth", noflines > 0 and totalwidth/noflines or 0)
end

function commands.doanalyzeframedbox(n)
    local box         = texbox[n]
    local noflines    = 0
    local firstheight = nil
    local lastdepth   = nil
    if box.width ~= 0 then
        local list = box.list
        if list then
            for h in traverse_id(hlist_code,list) do
                if not firstheight then
                    firstheight = h.height
                end
                lastdepth = h.depth
                noflines = noflines + 1
            end
        end
    end
 -- print("analyze", noflines, firstheight or 0, lastdepth or 0)
    texsetcount("global","framednoflines",    noflines)
    texsetdimen("global","framedfirstheight", firstheight or 0)
    texsetdimen("global","framedlastdepth",   lastdepth or 0)
end

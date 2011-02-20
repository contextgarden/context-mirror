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

-- fastrepack

function commands.doreshapeframedbox(n)
    local box, noflines, firstheight, lastdepth, lastlinelength = texbox[n], 0, nil, nil, 0
    if box.width ~= 0 then
        local list = box.list
        if list then
            local width, done = 0, false
            for h in traverse_id('hlist',list) do -- no dir etc needed
                if not firstheight then
                    firstheight = h.height
                end
                lastdepth = h.depth
                local l = h.list
                if l then
                    done = true
                    local p = hpack(copy(l))
                    lastlinelength = p.width
                    if lastlinelength > width then
                        width = lastlinelength
                    end
                    free(p)
                end
            end
            if done then
                if width ~= 0 then
                    for h in traverse_id('hlist',list) do
                        local l = h.list
                        if l then
                    --  if h.width ~= width then -- else no display math handling (uses shift)
                            h.list = hpack(l,width,'exactly',h.dir)
                            h.shift = 0 -- needed for display math
                            h.width = width
                    --  end
                        end
                    end
                end
                box.width = width
            end
        end
    end
--~     print("reshape", noflines, firstheight or 0, lastdepth or 0)
    texsetcount("global","framednoflines",    noflines)
    texsetdimen("global","framedfirstheight", firstheight or 0)
    texsetdimen("global","framedlastdepth",   lastdepth or 0)
end

function commands.doanalyzeframedbox(n)
    local box, noflines, firstheight, lastdepth = texbox[n], 0, nil, nil
    if box.width ~= 0 then
        local list = box.list
        if list then
            for h in traverse_id('hlist',list) do
                if not firstheight then
                    firstheight = h.height
                end
                lastdepth = h.depth
                noflines = noflines + 1
            end
        end
    end
--~     print("analyze", noflines, firstheight or 0, lastdepth or 0)
    texsetcount("global","framednoflines",    noflines)
    texsetdimen("global","framedfirstheight", firstheight or 0)
    texsetdimen("global","framedlastdepth",   lastdepth or 0)
end

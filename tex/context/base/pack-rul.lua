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

local texdimen, texcount, texbox = tex.dimen, tex.count, tex.box
local hpack, free, copy, traverse_id = node.hpack, node.free, node.copy_list, node.traverse_id

function commands.doreshapeframedbox(n)
    local noflines, lastlinelength, box = 0, 0, texbox[n]
    if box.width ~= 0 then
        local list = box.list
        if list then
            local width, done = 0, false
            for h in traverse_id('hlist',list) do -- no dir etc needed
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
    texdimen["framedlastlength"] = lastlinelength
    texcount["framednoflines"]   = noflines
end

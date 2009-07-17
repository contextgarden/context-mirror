if not modules then modules = { } end modules ['pack-rul'] = {
    version   = 1.001,
    comment   = "companion to pack-rul.tex",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

--[[ldx--
<p>An explanation is given in the history document <t>mk</t>.</p>
--ldx]]--

local texdimen, texcount, texbox, texwd = tex.dimen, tex.count, tex.box, tex.wd
local hpack, free, copy, traverse_id = node.hpack, node.free, node.copy_list, node.traverse_id

function commands.doreshapeframedbox(n)
    local noflines, lastlinelength = 0, 0
    if texwd[n] ~= 0 then
        local list = texbox[n].list
        if list then
            local width, done = 0, false
            for h in traverse_id('hlist',list) do
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
                            h.list = hpack(l,width,'exactly')
                            h.shift = 0 -- needed for display math
                            h.width = width
                    --  end
                        end
                    end
                end
                texwd[n] = width
            end
        end
    end
    texdimen["framedlastlength"] = lastlinelength
    texcount["framednoflines"]   = noflines
end

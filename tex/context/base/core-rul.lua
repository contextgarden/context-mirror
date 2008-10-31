if not modules then modules = { } end modules ['core-rul'] = {
    version   = 1.001,
    comment   = "companion to core-rul.tex",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

--[[ldx--
<p>An explanation is given in <t>mk.pdf</t>.</p>
--ldx]]--

function commands.doreshapeframedbox(n)
    local noflines, lastlinelength = 0, 0
    if tex.wd[n] ~= 0 then
        local hpack, free, copy = node.hpack, node.free, node.copy_list
        local noflines, width, done = 0, 0, false
        local list = tex.box[n].list
        for h in node.traverse_id('hlist',list) do
            done = true
         -- local p = hpack(h.list)
            local p = hpack(copy(h.list))
            lastlinelength = p.width
            if lastlinelength > width then
                width = lastlinelength
            end
            free(p)
        end
        if done then
            if width ~= 0 then
                for h in node.traverse_id('hlist',list) do
                    if h.width ~= width then
                        h.list = hpack(h.list,width,'exactly')
                        h.width = width
                    end
                end
            end
            tex.wd[n] = width
        end
    end
    tex.dimen["framedlastlength"] = lastlinelength
    tex.count["framednoflines"]   = noflines
end

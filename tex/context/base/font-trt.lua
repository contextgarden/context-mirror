if not modules then modules = { } end modules ['font-trt'] = {
    version   = 1.001,
    comment   = "companion to font-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local rawget, dofile, next = rawget, dofile, next

--[[ldx--
<p>We provide a simple treatment mechanism (mostly because I want to demonstrate
something in a manual). It's one of the few places where an lfg file gets loaded
outside the goodies manager.</p>
--ldx]]--

local treatments    = utilities.storage.allocate()
fonts.treatments    = treatments
local treatmentdata = { }
treatments.data     = treatmentdata
treatments.filename = "treatments.lfg"

-- function treatments.load(name)
--     local filename = resolvers.findfile(name)
--     if filename and filename ~= "" then
--         local goodies = dofile(filename)
--         if goodies then
--             local treatments = goodies.treatments
--             if treatments then
--                 for name, data in next, treatments do
--                     treatmentdata[name] = data -- always wins
--                 end
--             end
--         end
--     end
-- end

table.setmetatableindex(treatmentdata,function(t,k)
    local files = resolvers.findfiles(treatments.filename)
    if files then
        for i=1,#files do
            local goodies = dofile(files[i])
            if goodies then
                local treatments = goodies.treatments
                if treatments then
                    for name, data in next, treatments do
                        if not rawget(t,name) then
                            t[name] = data
                        end
                    end
                end
            end
        end
    end
    table.setmetatableindex(treatmentdata,nil)
    return treatmentdata[k]
end)

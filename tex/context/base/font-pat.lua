if not modules then modules = { } end modules ['font-pat'] = {
    version   = 1.001,
    comment   = "companion to font-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local match, lower = string.match, string.lower

-- older versions of latin modern didn't have the designsize set
-- so for them we get it from the name
-- reporter moved to elsewhere

local fonts    = fonts
local otf      = fonts.handlers.otf
local patches  = otf.enhancers.patches
local register = patches.register
local report   = patches.report

local function patch(data,filename)
    if data.design_size == 0 then
        local ds = match(file.basename(lower(filename)),"(%d+)")
        if ds then
            report("design size (%s)",ds)
            data.design_size = tonumber(ds) * 10
        end
    end
end

register("after","migrate metadata","^lmroman",     patch)
register("after","migrate metadata","^lmsans",      patch)
register("after","migrate metadata","^lmtypewriter",patch)

-- for some reason (either it's a bug in the font, or it's
-- a problem in the library) the palatino arabic fonts don't
-- have the mkmk features properly set up

local function patch(data,filename)
    local gpos = data.gpos
    if gpos then
        for k=1,#gpos do
            local v = gpos[k]
            if not v.features and v.type == "gpos_mark2mark" then
                report("mkmk feature (name: %s)", v.name or "?")
                v.features = {
                    {
                        scripts = {
                            arab = {
                                ["ARA "] = true,
                                ["FAR "] = true,
                                ["URD "] = true,
                                ["dflt"] = true,
                            }
                        },
                        tag     = "mkmk",
                    }
                }
            end
        end
    end
end

register("after","rehash features","palatino.*arabic",patch)

-- -- this code is now in lm-math.lfg
--
-- local function patch(data,filename)
--     local uni_to_ind = data.map.map
--     if not uni_to_ind[0x391] then
--         -- beware, this is a hack, features for latin often don't apply to greek
--         -- but lm has not much features anyway (and only greek for math)
--         report("adding 13 greek capitals")
--         uni_to_ind[0x391] = uni_to_ind[0x41]
--         uni_to_ind[0x392] = uni_to_ind[0x42]
--         uni_to_ind[0x395] = uni_to_ind[0x45]
--         uni_to_ind[0x397] = uni_to_ind[0x48]
--         uni_to_ind[0x399] = uni_to_ind[0x49]
--         uni_to_ind[0x39A] = uni_to_ind[0x4B]
--         uni_to_ind[0x39C] = uni_to_ind[0x4D]
--         uni_to_ind[0x39D] = uni_to_ind[0x4E]
--         uni_to_ind[0x39F] = uni_to_ind[0x4F]
--         uni_to_ind[0x3A1] = uni_to_ind[0x52]
--         uni_to_ind[0x3A4] = uni_to_ind[0x54]
--         uni_to_ind[0x3A7] = uni_to_ind[0x58]
--         uni_to_ind[0x396] = uni_to_ind[0x5A]
--     end
-- end
--
-- register("after","prepare glyphs","^lmroman",     patch)
-- register("after","prepare glyphs","^lmsans",      patch)
-- register("after","prepare glyphs","^lmtypewriter",patch)
--
-- -- this code is now in cambria-math.lfg and asana-math.lfg
--
-- local function patch_domh(data,filename,threshold)
--     local m = data.metadata.math
--     if m then
--         local d = m.DisplayOperatorMinHeight or 0
--         if d < threshold then
--             report("DisplayOperatorMinHeight(%s -> %s)",d,threshold)
--             m.DisplayOperatorMinHeight = threshold
--         end
--      end
-- end
--
-- register("after","check math parameters","cambria", function(data,filename) patch_domh(data,filename,2800) end)
-- register("after","check math parameters","cambmath",function(data,filename) patch_domh(data,filename,2800) end)
-- register("after","check math parameters","asana",   function(data,filename) patch_domh(data,filename,1350) end)

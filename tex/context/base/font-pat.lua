if not modules then modules = { } end modules ['font-pat'] = {
    version   = 1.001,
    comment   = "companion to font-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local match, lower = string.match, string.lower

local trace_loading = false  trackers.register("otf.loading", function(v) trace_loading = v end)

-- this will become a per font patch file
--
-- older versions of latin modern didn't have the designsize set
-- so for them we get it from the name

local patches = fonts.otf.enhancers.patches

local function patch(data,filename)
    if data.design_size == 0 then
        local ds = match(file.basename(lower(filename)),"(%d+)")
        if ds then
            if trace_loading then
                logs.report("load otf","patching design size (%s)",ds)
            end
            data.design_size = tonumber(ds) * 10
        end
    end
    local uni_to_ind = data.map.map
    if not uni_to_ind[0x391] then
        -- beware, this is a hack, features for latin often don't apply to greek
        -- but lm has not much features anyway (and only greek for math)
        if trace_loading then
            logs.report("load otf","adding 13 greek capitals")
        end
        uni_to_ind[0x391] = uni_to_ind[0x41]
        uni_to_ind[0x392] = uni_to_ind[0x42]
        uni_to_ind[0x395] = uni_to_ind[0x45]
        uni_to_ind[0x397] = uni_to_ind[0x48]
        uni_to_ind[0x399] = uni_to_ind[0x49]
        uni_to_ind[0x39A] = uni_to_ind[0x4B]
        uni_to_ind[0x39C] = uni_to_ind[0x4D]
        uni_to_ind[0x39D] = uni_to_ind[0x4E]
        uni_to_ind[0x39F] = uni_to_ind[0x4F]
        uni_to_ind[0x3A1] = uni_to_ind[0x52]
        uni_to_ind[0x3A4] = uni_to_ind[0x54]
        uni_to_ind[0x3A7] = uni_to_ind[0x58]
        uni_to_ind[0x396] = uni_to_ind[0x5A]
    end
    -- better make this into a feature
    --
    -- local glyphs = data.glyphs
    -- for i=0x300,0x36F do
    --     local c = glyphs[uni_to_ind[i]]
    --     if c and c.width == 0 then
    --         local boundingbox = c.boundingbox
    --         c.width = boundingbox[3] - boundingbox[1]
    --     end
    -- end
end

patches["^lmroman"]      = patch
patches["^lmsans"]       = patch
patches["^lmtypewriter"] = patch

-- for some reason (either it's a bug in the font, or it's
-- a problem in the library) the palatino arabic fonts don't
-- have the mkmk features properly set up

local function patch(data,filename)
    local gpos = data.gpos
    if gpos then
        for k=1,#gpos do
            local v = gpos[k]
            if not v.features and v.type == "gpos_mark2mark" then
                if trace_loading then
                    logs.report("load otf","patching mkmk feature (name: %s)", v.name or "?")
                end
                v.features = {
                    {
                        scripts = {
                            {
                                langs = { "ARA ", "FAR ", "URD ", "dflt" },
                                script = "arab",
                            },
                        },
                        tag = "mkmk"
                    }
                }
            end
        end
    end
end

patches["palatino.*arabic"] = patch

local function patch(data,filename)
    local m = data.math
    if m then
        local d = m.DisplayOperatorMinHeight or 0
        if d < 2800 then
            if trace_loading then
                logs.report("load otf","patching DisplayOperatorMinHeight(%s -> 2800)",d)
            end
            m.DisplayOperatorMinHeight = 2800
        end
    end
end

patches["cambria"] = patch

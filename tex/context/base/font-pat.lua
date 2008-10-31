if not modules then modules = { } end modules ['font-pat'] = {
    version   = 1.001,
    comment   = "companion to font-ini.tex",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- older versions of latin modern didn't have the designsize set
-- so for them we get it from the name

local patches = fonts.otf.enhance.patches

local function patch(data,filename)
    if data.design_size == 0 then
        local ds = (file.basename(filename:lower())):match("(%d+)")
        if ds then
            logs.report("load otf","patching design size (%s)",ds)
            data.design_size = tonumber(ds) * 10
        end
    end
end

patches["^lmroman"]      = patch
patches["^lmsans"]       = patch
patches["^lmtypewriter"] = patch

-- for some reason (either it's a bug in the font, or it's
-- a problem in the library) the palatino arabic fonts don't
-- have the mkmk features properly set up

local function patch(data,filename)
    if data.gpos then
        for _, v in ipairs(data.gpos) do
            if not v.features and v.type == "gpos_mark2mark" then
                logs.report("load otf","patching mkmk feature (name: %s)", v.name or "?")
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

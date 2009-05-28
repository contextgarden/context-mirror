if not modules then modules = { } end modules ['luatex-fonts'] = {
    version   = 1.001,
    comment   = "companion to luatex-fonts.tex",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- We keep track of load time by storing the current time. That
-- way we cannot be accused of slowing down luading too much.

local starttime = os.gettimeofday()

-- As we don't use the ConTeXt file searching, we need to
-- initialize the kpse library. As the progname can be anything
-- we will temporary switch to the ConTeXt namespace if needed.
-- Just adding the context paths to the path specification is
-- somewhat faster

-- kpse.set_program_name("luatex")

local ctxkpse = nil
local verbose = true

local function loadmodule(name,continue)
    local foundname = kpse.find_file(name,"tex") or ""
    if not foundname then
        if not ctxkpse then
            ctxkpse = kpse.new("luatex","context")
        end
        foundname = ctxkpse:find_file(name,"tex") or ""
    end
    if foundname == "" then
        if not continue then
            texio.write_nl(string.format(" <luatex-fonts: unable to locate %s>",name))
            os.exit()
        end
    else
        if verbose then
            texio.write(string.format(" <%s>",string.match(name,"([a-z%-]-%.[a-z]-)$"))) -- no file.basename yet
        end
        dofile(foundname)
    end
end

loadmodule('luatex-fonts-merged.lua',true) -- you might comment this line

if fonts then

    -- We're using the merged version. That one could be outdated so
    -- remove it from your system when you want to use the files from
    -- from the ConTeXt tree, or keep your copy of the merged version
    -- up to date.

    texio.write_nl("log",[[

I am using the merged version of 'luatex-fonts.lua' here. If
you run into problems or experience unexpected behaviour, and
if you have ConTeXt installed you can try to delete the file
'luatex-font-merged.lua' as I might then use the possibly
updated libraries. The merged version is not supported as it
is a frozen instance.

    ]])

else

    -- The following helpers are a bit overkill but I don't want to
    -- mess up ConTeXt code for the sake of general generality. Around
    -- version 1.0 there will be an official api defined.

    loadmodule('l-string.lua')
    loadmodule('l-lpeg.lua')
    loadmodule('l-boolean.lua')
    loadmodule('l-math.lua')
    loadmodule('l-table.lua')
    loadmodule('l-file.lua')
    loadmodule('l-io.lua')

    -- The following modules contain code that is either not used
    -- at all outside ConTeXt or will fail when enabled due to
    -- lack of other modules.

    -- First we load a few helper modules. This is about the miminum
    -- needed to let the font modules do theuir work.

    loadmodule('luat-dum.lua') -- not used in context at all
    loadmodule('data-con.lua') -- maybe some day we don't need this one

    -- We do need some basic node support although the following
    -- modules contain a little bit of code that is not used. It's
    -- not worth weeding.

    loadmodule('node-ini.lua')
    loadmodule('node-res.lua') -- will be stripped
    loadmodule('node-inj.lua') -- will be replaced (luatex > .50)
    loadmodule('node-fnt.lua')
    loadmodule('node-dum.lua')

    -- Now come the font modules that deal with traditional TeX fonts
    -- as well as open type fonts. We don't load the afm related code
    -- from font-enc.lua and font-afm.lua as only ConTeXt deals with
    -- it.
    --
    -- The font database file (if used at all) must be put someplace
    -- visible for kpse and is not shared with ConTeXt. The mtx-fonts
    -- script can be used to genate this file (using the --names
    -- option).

    loadmodule('font-ini.lua')
    loadmodule('font-tfm.lua') -- will be split (we may need font-log)
    loadmodule('font-cid.lua')
    loadmodule('font-ott.lua') -- might be split
    loadmodule('font-otf.lua')
    loadmodule('font-otd.lua')
    loadmodule('font-oti.lua')
    loadmodule('font-otb.lua')
    loadmodule('font-otn.lua')
    loadmodule('font-ota.lua') -- might be split
    loadmodule('font-otc.lua')
    loadmodule('font-def.lua')
    loadmodule('font-xtx.lua')
    loadmodule('font-dum.lua')

end

-- In order to deal with the fonts we need to initialize some
-- callbacks. One can overload them later on if needed.

callback.register('ligaturing',           nodes.simple_font_dummy)
callback.register('kerning',              nodes.simple_font_dummy)
callback.register('pre_linebreak_filter', nodes.simple_font_handler)
callback.register('hpack_filter',         nodes.simple_font_handler)
callback.register('define_font' ,         fonts.define.read)
callback.register('find_vf_file',         nil) -- reset to normal

-- We're done.

texio.write(string.format(" <luatex-fonts.lua loaded in %0.3f seconds>", os.gettimeofday()-starttime))

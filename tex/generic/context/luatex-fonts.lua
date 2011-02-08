if not modules then modules = { } end modules ['luatex-fonts'] = {
    version   = 1.001,
    comment   = "companion to luatex-fonts.tex",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- We keep track of load time by storing the current time. That
-- way we cannot be accused of slowing down luading too much.
--
-- Please don't update to this version without proper testing. It
-- might be that this version lags behind stock context and the only
-- formal release takes place around tex live code freeze.

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
            texio.write(string.format(" <%s>",foundname)) -- no file.basename yet
        end
        dofile(foundname)
    end
end

loadmodule('luatex-fonts-merged.lua',true) -- you might comment this line

if fonts then

    if not fonts._merge_loaded_message_done_ then
        texio.write_nl("log", "!")
        texio.write_nl("log", "! I am using the merged version of 'luatex-fonts.lua' here. If")
        texio.write_nl("log", "! you run into problems or experience unexpected behaviour, and")
        texio.write_nl("log", "! if you have ConTeXt installed you can try to delete the file")
        texio.write_nl("log", "! 'luatex-font-merged.lua' as I might then use the possibly")
        texio.write_nl("log", "! updated libraries. The merged version is not supported as it")
        texio.write_nl("log", "! is a frozen instance.")
        texio.write_nl("log", "!")
    end

    fonts._merge_loaded_message_done_ = true

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
    -- not worth weeding. Beware, in node-dum some functions use
    -- fonts.* tables, not that nice but I don't want two dummy
    -- files. Some day I will sort this out (no problem in context).

    loadmodule('node-dum.lua')
    loadmodule('node-inj.lua') -- will be replaced (luatex >= .70)

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
    loadmodule('font-map.lua') -- for loading lum file (will be stripped)
    loadmodule('font-lua.lua')
    loadmodule('font-otf.lua')
    loadmodule('font-otd.lua')
    loadmodule('font-oti.lua')
    loadmodule('font-otb.lua')
    loadmodule('font-otn.lua')
    loadmodule('font-ota.lua')
    loadmodule('font-otc.lua')
    loadmodule('font-agl.lua')
    loadmodule('font-def.lua')
    loadmodule('font-xtx.lua')
    loadmodule('font-dum.lua')

end

resolvers.loadmodule = loadmodule

-- In order to deal with the fonts we need to initialize some
-- callbacks. One can overload them later on if needed.

callback.register('ligaturing',           false)
callback.register('kerning',              false)
callback.register('pre_linebreak_filter', nodes.simple_font_handler)
callback.register('hpack_filter',         nodes.simple_font_handler)
callback.register('define_font' ,         fonts.definers.read)
callback.register('find_vf_file',         nil) -- reset to normal

-- We're done.

texio.write(string.format(" <luatex-fonts.lua loaded in %0.3f seconds>", os.gettimeofday()-starttime))

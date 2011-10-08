if not modules then modules = { } end modules ['luatex-fonts'] = {
    version   = 1.001,
    comment   = "companion to luatex-fonts.tex",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- The following code isolates the generic ConTeXt code from already
-- defined or to be defined namespaces. This is the reference loader
-- for plain, but the generic code is also used in luaotfload (which
-- is is a file meant for latex) and that is maintained by Khaled
-- Hosny. We do our best to keep the interface as clean as possible.
--
-- The code base is rather stable now, especially if you stay away from
-- the non generic code. All relevant data is organized in tables within
-- the main table of a font instance. There are a few places where in
-- context other code is plugged in, but this does not affect the core
-- code. Users can (given that their macro package provides this option)
-- access the font data (characters, descriptions, properties, parameters,
-- etc) of this main table.
--
-- Todo: all global namespaces in called modules will get local shortcuts.

utf = unicode.utf8

if not generic_context then

    generic_context  = { }

end

if not generic_context.push_namespaces then

    function generic_context.push_namespaces()
        texio.write(" <push namespace>")
        local normalglobal = { }
        for k, v in next, _G do
            normalglobal[k] = v
        end
        return normalglobal
    end

    function generic_context.pop_namespaces(normalglobal,isolate)
        if normalglobal then
            texio.write(" <pop namespace>")
            for k, v in next, _G do
                if not normalglobal[k] then
                    generic_context[k] = v
                    if isolate then
                        _G[k] = nil
                    end
                end
            end
            for k, v in next, normalglobal do
                _G[k] = v
            end
            -- just to be sure:
            setmetatable(generic_context,_G)
        else
            texio.write(" <fatal error: invalid pop of generic_context>")
            os.exit()
        end
    end

end

local whatever = generic_context.push_namespaces()

-- We keep track of load time by storing the current time. That
-- way we cannot be accused of slowing down loading too much.
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
        texio.write_nl("log", "! is a frozen instance. Problems can be reported to the ConTeXt")
        texio.write_nl("log", "! mailing list.")
        texio.write_nl("log", "!")
    end

    fonts._merge_loaded_message_done_ = true

else

    -- The following helpers are a bit overkill but I don't want to
    -- mess up ConTeXt code for the sake of general generality. Around
    -- version 1.0 there will be an official api defined.

    loadmodule('l-string.lua')
    loadmodule('l-table.lua')
    loadmodule('l-lpeg.lua')
    loadmodule('l-boolean.lua')
    loadmodule('l-math.lua')
    loadmodule('l-file.lua')
    loadmodule('l-io.lua')

    -- The following modules contain code that is either not used
    -- at all outside ConTeXt or will fail when enabled due to
    -- lack of other modules.

    -- First we load a few helper modules. This is about the miminum
    -- needed to let the font modules do their work. Don't depend on
    -- their functions as we might strip them in future versions of
    -- this generic variant.

    loadmodule('luatex-basics-gen.lua')
    loadmodule('data-con.lua')

    -- We do need some basic node support. The code in there is not for
    -- general use as it might change.

    loadmodule('luatex-basics-nod.lua')

    -- Now come the font modules that deal with traditional TeX fonts
    -- as well as open type fonts. We only support OpenType fonts here.
    --
    -- The font database file (if used at all) must be put someplace
    -- visible for kpse and is not shared with ConTeXt. The mtx-fonts
    -- script can be used to genate this file (using the --names
    -- option).

    loadmodule('font-ini.lua')
    loadmodule('font-con.lua')
    loadmodule('luatex-fonts-enc.lua') -- will load font-age on demand
    loadmodule('font-cid.lua')
    loadmodule('font-map.lua')         -- for loading lum file (will be stripped)
    loadmodule('luatex-fonts-syn.lua') -- deals with font names (synonyms)
    loadmodule('luatex-fonts-tfm.lua')
    loadmodule('font-oti.lua')
    loadmodule('font-otf.lua')
    loadmodule('font-otb.lua')
    loadmodule('node-inj.lua')         -- will be replaced (luatex >= .70)
    loadmodule('font-otn.lua')
 -- loadmodule('luatex-fonts-chr.lua')
    loadmodule('font-ota.lua')
    loadmodule('luatex-fonts-lua.lua')
    loadmodule('font-def.lua')
    loadmodule('luatex-fonts-def.lua')
    loadmodule('luatex-fonts-ext.lua') -- some extensions

    -- We need to plug into a callback and the following module implements
    -- the handlers. Actual plugging in happens later.

    loadmodule('luatex-fonts-cbk.lua')

end

resolvers.loadmodule = loadmodule

-- In order to deal with the fonts we need to initialize some
-- callbacks. One can overload them later on if needed. First
-- a bit of abstraction.

generic_context.callback_ligaturing           = false
generic_context.callback_kerning              = false
generic_context.callback_pre_linebreak_filter = nodes.simple_font_handler
generic_context.callback_hpack_filter         = nodes.simple_font_handler
generic_context.callback_define_font          = fonts.definers.read

-- The next ones can be done at a different moment if needed. You can create
-- a generic_context namespace and set no_callbacks_yet to true, load this
-- module, and enable the callbacks later.

if not generic_context.no_callbacks_yet then

    callback.register('ligaturing',           generic_context.callback_ligaturing)
    callback.register('kerning',              generic_context.callback_kerning)
    callback.register('pre_linebreak_filter', generic_context.callback_pre_linebreak_filter)
    callback.register('hpack_filter',         generic_context.callback_hpack_filter)
    callback.register('define_font' ,         generic_context.callback_define_font)

end

-- We're done.

texio.write(string.format(" <luatex-fonts.lua loaded in %0.3f seconds>", os.gettimeofday()-starttime))

generic_context.pop_namespaces(whatever)

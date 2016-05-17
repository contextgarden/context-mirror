if not modules then modules = { } end modules ['luatex-languages'] = {
    version   = 1.001,
    comment   = "companion to luatex-languages.tex",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- We borrow from ConTeXt.

languages = languages or { }

local loaded = { }

function languages.loadpatterns(tag)
    if not loaded[tag] then
        loaded[tag] = 0
        local filename = kpse.find_file("lang-" .. tag .. ".lua")
        if not filename or filename == "" then
            texio.write("<unknown language file for: " .. tag .. ">")
        else
            local whatever = loadfile(filename)
            if type(whatever) == "function" then
                whatever = whatever()
                if type(whatever) == "table" then
                    texio.write("<language file: " .. tag .. ">")
                    local characters = whatever.patterns.characters or ""
                    local patterns = whatever.patterns.data or ""
                    local exceptions = whatever.exceptions.data or ""
                    for b in string.utfvalues(characters) do
                        -- what about uppercase
-- lang.sethjcode(b,b)
                        tex.setlccode(b,b)
                    end
                    local language = lang.new()
                    lang.patterns(language, patterns)
                    lang.hyphenation(language, exceptions)
                    loaded[tag] = lang.id(language)
                else
                    texio.write("<invalid language table: " .. tag .. ">")
                    os.exit()
                end
            else
                texio.write("<invalid language file: " .. tag .. ">")
                os.exit()
            end
        end
    end
    return loaded[tag]
end

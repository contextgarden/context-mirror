if not modules then modules = { } end modules ['mtx-babel'] = {
    version   = 1.001,
    comment   = "companion to mtxrun.lua",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- data tables by Thomas A. Schmitz

scripts       = scripts       or { }
scripts.babel = scripts.babel or { }

do

    local converters = { }

    -- greek

    local replace_01 = { -- <' * |
        a = "ᾅ",
        h = "ᾕ",
        w = "ᾥ",
    }

    local replace_02 = { -- >' * |
        a = "ᾄ",
        h = "ᾔ",
        w = "ᾤ",
    }

    local replace_03 = { -- <` * |
        a = "ᾃ",
        h = "ᾓ",
        w = "ᾣ",
    }

    local replace_04 = { -- >` * |
        a = "ᾂ",
        h = "ᾒ",
        w = "ᾢ",
    }

    local replace_05 = { -- <~ * |
        a = "ᾇ",
        h = "ᾗ",
        w = "ᾧ",
    }

    local replace_06 = { -- >~ * |
        a = "ᾆ",
        h = "ᾖ",
        w = "ᾦ"
    }

    local replace_07 = { -- "' *
        i = "ΐ",
        u = "ΰ",
    }

    local replace_08 = { -- "` *
        i = "ῒ",
        u = "ῢ",
    }

    local replace_09 = { -- "~ *
        i = "ῗ",
        u = "ῧ",
    }

    local replace_10 = { -- <' *
        a = "ἅ",
        e = "ἕ",
        h = "ἥ",
        i = "ἵ",
        o = "ὅ",
        u = "ὕ",
        w = "ὥ",
        A = "Ἅ",
        E = "Ἕ",
        H = "Ἥ",
        I = "Ἵ",
        O = "Ὅ",
        U = "Ὕ",
        W = "Ὥ",
    }

    local replace_11 = { -- >' *
        a = "ἄ",
        e = "ἔ",
        h = "ἤ",
        i = "ἴ",
        o = "ὄ",
        u = "ὔ",
        w = "ὤ",
        A = "Ἄ",
        E = "Ἔ",
        H = "Ἤ",
        I = "Ἴ",
        O = "Ὄ",
        U = "῎Υ",
        W = "Ὤ",
    }

    local replace_12 = { -- <` *
        a = "ἃ",
        e = "ἓ",
        h = "ἣ",
        i = "ἳ",
        o = "ὃ",
        u = "ὓ",
        w = "ὣ",
        A = "Ἃ",
        E = "Ἒ",
        H = "Ἣ",
        I = "Ἳ",
        O = "Ὃ",
        U = "Ὓ",
        W = "Ὣ",
    }

    local replace_13 = { -- >` *
        a = "ἂ",
        e = "ἒ",
        h = "ἢ",
        i = "ἲ",
        o = "ὂ",
        u = "ὒ",
        w = "ὢ",
        A = "Ἂ",
        E = "Ἒ",
        H = "Ἢ",
        I = "Ἲ",
        O = "Ὂ",
        U = "῍Υ",
        W = "Ὢ",
    }

    local replace_14 = { -- <~ *
        a = "ἇ",
        h = "ἧ",
        i = "ἷ",
        u = "ὗ",
        w = "ὧ",
        A = "Ἇ",
        H = "Ἧ",
        I = "Ἷ",
        U = "Ὗ",
        W = "Ὧ",
    }

    local replace_15 = { -- >~ *
        a = "ἆ",
        h = "ἦ",
        i = "ἶ",
        u = "ὖ",
        w = "ὦ",
        A = "Ἆ",
        H = "Ἦ",
        I = "Ἶ",
        U = "῏Υ",
        W = "Ὦ",
    }

    local replace_16 = { -- ' * |
        a = "ᾴ",
        h = "ῄ",
        w = "ῴ",
    }

    local replace_17 = { -- ` * |
        a = "ᾲ",
        h = "ῂ",
        w = "ῲ",
    }

    local replace_18 = { -- ~ * |
        a = "ᾷ",
        h = "ῇ",
        w = "ῷ"
    }

    local replace_19 = { -- ' *
        a = "ά",
        e = "έ",
        h = "ή",
        i = "ί",
        o = "ό",
        u = "ύ",
        w = "ώ",
    }

    local replace_20 = { -- ` *
        a = "ὰ",
        e = "ὲ",
        h = "ὴ",
        i = "ὶ",
        o = "ὸ",
        u = "ὺ",
        w = "ὼ",
    }

    local replace_21 = { -- ~ *
        a = "ᾶ",
        h = "ῆ",
        i = "ῖ",
        u = "ῦ",
        w = "ῶ",
    }

    local replace_22 = { -- < *
        a = "ἁ",
        e = "ἑ",
        h = "ἡ",
        i = "ἱ",
        o = "ὁ",
        u = "ὑ",
        w = "ὡ",
        r = "ῥ",
        A = "Ἁ",
        E = "Ἑ",
        H = "Ἡ",
        I = "Ἱ",
        O = "Ὁ",
        U = "Ὑ",
        W = "Ὡ",
	R = "Ῥ",
    }

    local replace_23 = { -- > *
        a = "ἀ",
        e = "ἐ",
        h = "ἠ",
        i = "ἰ",
        o = "ὀ",
        u = "ὐ",
        w = "ὠ",
        A = "Ἀ",
        E = "Ἐ",
        H = "Ἠ",
        I = "Ἰ",
        O = "Ὀ",
        U = "᾿Υ",
        W = "Ὠ",
    }

    local replace_24 = { -- * |
        a = "ᾳ",
        h = "ῃ",
        w = "ῳ",
    }

    local replace_25 = { -- " *
        i = "ϊ",
        u = "ϋ",
    }

    local replace_26 = { -- *
        a = "α",
        b = "β",
        g = "γ",
        d = "δ",
        e = "ε",
        z = "ζ",
        h = "η",
        j = "θ",
        i = "ι",
        k = "κ",
        l = "λ",
        m = "μ",
        n = "ν",
        x = "ξ",
        o = "ο",
        p = "π",
        r = "ρ",
        s = "σ",
        c = "ς",
        t = "τ",
        u = "υ",
        f = "φ",
        q = "χ",
        y = "ψ",
        w = "ω",
        A = "Α",
        B = "Β",
        G = "Γ",
        D = "Δ",
        E = "Ε",
        Z = "Ζ",
        H = "Η",
        J = "Θ",
        I = "Ι",
        K = "Κ",
        L = "Λ",
        M = "Μ",
        N = "Ν",
        X = "Ξ",
        O = "Ο",
        P = "Π",
        R = "Ρ",
        S = "Σ",
        T = "Τ",
        U = "Υ",
        F = "Φ",
        Q = "Χ",
        Y = "Ψ",
        W = "Ω"
    }

    local skips_01 = lpeg.P("\\")  * lpeg.R("az", "AZ")^1
    local skips_02 = lpeg.P("[")   * (1- lpeg.S("[]"))^1  * lpeg.P("]")

    local greek_01 = (lpeg.P("<'")  * lpeg.Cs(1) * lpeg.P('|')) / replace_01
    local greek_02 = (lpeg.P(">'")  * lpeg.Cs(1) * lpeg.P('|')) / replace_02
    local greek_03 = (lpeg.P("<`")  * lpeg.Cs(1) * lpeg.P('|')) / replace_03
    local greek_04 = (lpeg.P(">`")  * lpeg.Cs(1) * lpeg.P('|')) / replace_04
    local greek_05 = (lpeg.P("<~")  * lpeg.Cs(1) * lpeg.P('|')) / replace_05
    local greek_06 = (lpeg.P(">~")  * lpeg.Cs(1) * lpeg.P('|')) / replace_06
    local greek_07 = (lpeg.P('"\'') * lpeg.Cs(1)              ) / replace_07
    local greek_08 = (lpeg.P('"`')  * lpeg.Cs(1)              ) / replace_08
    local greek_09 = (lpeg.P('"~')  * lpeg.Cs(1)              ) / replace_09
    local greek_10 = (lpeg.P("<'")  * lpeg.Cs(1)              ) / replace_10
    local greek_11 = (lpeg.P(">'")  * lpeg.Cs(1)              ) / replace_11
    local greek_12 = (lpeg.P("<`")  * lpeg.Cs(1)              ) / replace_12
    local greek_13 = (lpeg.P(">`")  * lpeg.Cs(1)              ) / replace_13
    local greek_14 = (lpeg.P("<~")  * lpeg.Cs(1)              ) / replace_14
    local greek_15 = (lpeg.P(">~")  * lpeg.Cs(1)              ) / replace_15
    local greek_16 = (lpeg.P("'")   * lpeg.Cs(1) * lpeg.P('|')) / replace_16
    local greek_17 = (lpeg.P("`")   * lpeg.Cs(1) * lpeg.P('|')) / replace_17
    local greek_18 = (lpeg.P("~")   * lpeg.Cs(1) * lpeg.P('|')) / replace_18
    local greek_19 = (lpeg.P("'")   * lpeg.Cs(1)              ) / replace_19
    local greek_20 = (lpeg.P("`")   * lpeg.Cs(1)              ) / replace_20
    local greek_21 = (lpeg.P("~")   * lpeg.Cs(1)              ) / replace_21
    local greek_22 = (lpeg.P("<")   * lpeg.Cs(1)              ) / replace_22
    local greek_23 = (lpeg.P(">")   * lpeg.Cs(1)              ) / replace_23
    local greek_24 = (lpeg.Cs(1)    * lpeg.P('|')             ) / replace_24
    local greek_25 = (lpeg.P('"')   * lpeg.Cs(1)              ) / replace_25
    local greek_26 = (lpeg.Cs(1)                              ) / replace_26

    local skips =
        skips_01 + skips_02

    local greek =
        greek_01 + greek_02 + greek_03 + greek_04 + greek_05 +
        greek_06 + greek_07 + greek_08 + greek_09 + greek_10 +
        greek_11 + greek_12 + greek_13 + greek_14 + greek_15 +
        greek_16 + greek_17 + greek_18 + greek_19 + greek_20 +
        greek_21 + greek_22 + greek_23 + greek_24 + greek_25 +
        greek_26

    local spacing      = lpeg.S(" \n\r\t")
    local startgreek   = lpeg.P("\\startgreek")
    local stopgreek    = lpeg.P("\\stopgreek")
    local localgreek   = lpeg.P("\\localgreek")
    local lbrace       = lpeg.P("{")
    local rbrace       = lpeg.P("}")

    local documentparser = lpeg.Cs((skips + greek + 1)^0)

    local contextgrammar = lpeg.Cs ( lpeg.P { "scan",
        ["scan"]     = (lpeg.V("global") + lpeg.V("local") + skips + 1)^0,
        ["global"]   = startgreek * ((skips + greek + 1)-stopgreek )^0 ,
        ["local"]    = localgreek * lpeg.V("grouped"),
        ["grouped"]  = spacing^0 * lbrace * (lpeg.V("grouped") + skips + (greek - rbrace))^0 * rbrace,
    } )

    converters['greek'] = {
        document = documentparser,
        context  = contextgrammar,
    }

    -- lpeg.print(parser): 254 lines

    function scripts.babel.convert(filename)
        if filename and filename ~= empty then
            local data = io.loaddata(filename) or ""
            if data ~= "" then
                local language  = environment.argument("language")  or ""
                if language ~= "" then
                    local converter = converters[language]
                    if converter then
                        local structure = environment.argument("structure") or "document"
                        converter = converter[structure]
                        if converter then
                            input.report("converting '%s' using language '%s' with structure '%s'", filename, language, structure)
                            data = converter:match(data)
                            local newfilename = filename .. ".utf"
                            io.savedata(newfilename, data)
                            input.report("converted data saved in '%s'", newfilename)
                        else
                            input.report("unknown structure '%s' language '%s'", structure, language)
                        end
                    else
                        input.report("no converter for language '%s'", language)
                    end
                else
                    input.report("provide language")
                end
            else
                input.report("no data in '%s'",filename)
            end
        end
    end

    --~ print(contextgrammar:match [[
    --~ oeps abg \localgreek{a}
    --~ \startgreek abg \stopgreek \oeps
    --~ oeps abg \localgreek{a{b}\oeps g}
    --~ ]])

end

banner = banner .. " | babel conversion tools "

messages.help = [[
--language=string     conversion language (e.g. greek)
--structure=string    obey given structure (e.g. 'document', default: 'context')
--convert             convert babel codes into utf
]]

input.verbose = true

if environment.argument("convert") then
    scripts.babel.convert(environment.files[1] or "")
else
    input.help(banner,messages.help)
end

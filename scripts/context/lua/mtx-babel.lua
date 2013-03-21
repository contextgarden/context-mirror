if not modules then modules = { } end modules ['mtx-babel'] = {
    version   = 1.002,
    comment   = "companion to mtxrun.lua",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- data tables by Thomas A. Schmitz

local helpinfo = [[
<?xml version="1.0"?>
<application>
 <metadata>
  <entry name="name">mtx-babel</entry>
  <entry name="detail">Babel Input To UTF Conversion</entry>
  <entry name="version">1.20</entry>
 </metadata>
 <flags>
  <category name="basic">
   <subcategory>
    <flag name="language" value="string"><short>conversion language (e.g. greek)</short></flag>
    <flag name="structure" value="string"><short>obey given structure (e.g. 'document', default: 'context')</short></flag>
    <flag name="convert"><short>convert babel codes into utf</short></flag>
   </subcategory>
  </category>
 </flags>
</application>
]]

local application = logs.application {
    name     = "mtx-babel",
    banner   = "Babel Input To UTF Conversion 1.20",
    helpinfo = helpinfo,
}

local report = application.report

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
    ["'"] = "’",
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
        W = "Ω",
    [";"] = "·",
    ["?"] = ";",
    }

    local P, R, S, V, Cs = lpeg.P, lpeg.R, lpeg.S, lpeg.V, lpeg.Cs

    local skips_01 = P("\\")   * R("az", "AZ")^1
    local skips_02 = P("[")    * (1- S("[]"))^1  * P("]")

    local greek_01 = (P("<'")  * Cs(1) * P('|')) / replace_01
    local greek_02 = (P(">'")  * Cs(1) * P('|')) / replace_02
    local greek_03 = (P("<`")  * Cs(1) * P('|')) / replace_03
    local greek_04 = (P(">`")  * Cs(1) * P('|')) / replace_04
    local greek_05 = (P("<~")  * Cs(1) * P('|')) / replace_05
    local greek_06 = (P(">~")  * Cs(1) * P('|')) / replace_06
    local greek_07 = (P('"\'') * Cs(1)         ) / replace_07
    local greek_08 = (P('"`')  * Cs(1)         ) / replace_08
    local greek_09 = (P('"~')  * Cs(1)         ) / replace_09
    local greek_10 = (P("<'")  * Cs(1)         ) / replace_10
    local greek_11 = (P(">'")  * Cs(1)         ) / replace_11
    local greek_12 = (P("<`")  * Cs(1)         ) / replace_12
    local greek_13 = (P(">`")  * Cs(1)         ) / replace_13
    local greek_14 = (P("<~")  * Cs(1)         ) / replace_14
    local greek_15 = (P(">~")  * Cs(1)         ) / replace_15
    local greek_16 = (P("'")   * Cs(1) * P('|')) / replace_16
    local greek_17 = (P("`")   * Cs(1) * P('|')) / replace_17
    local greek_18 = (P("~")   * Cs(1) * P('|')) / replace_18
    local greek_19 = (P("'")   * Cs(1)         ) / replace_19
    local greek_20 = (P("`")   * Cs(1)         ) / replace_20
    local greek_21 = (P("~")   * Cs(1)         ) / replace_21
    local greek_22 = (P("<")   * Cs(1)         ) / replace_22
    local greek_23 = (P(">")   * Cs(1)         ) / replace_23
    local greek_24 = (Cs(1)    * P('|')        ) / replace_24
    local greek_25 = (P('"')   * Cs(1)         ) / replace_25
    local greek_26 = (Cs(1)                    ) / replace_26

    local skips =
        skips_01 + skips_02

    local greek =
        greek_01 + greek_02 + greek_03 + greek_04 + greek_05 +
        greek_06 + greek_07 + greek_08 + greek_09 + greek_10 +
        greek_11 + greek_12 + greek_13 + greek_14 + greek_15 +
        greek_16 + greek_17 + greek_18 + greek_19 + greek_20 +
        greek_21 + greek_22 + greek_23 + greek_24 + greek_25 +
        greek_26

    local spacing      = S(" \n\r\t")
    local startgreek   = P("\\startgreek")
    local stopgreek    = P("\\stopgreek")
    local localgreek   = P("\\localgreek")
    local lbrace       = P("{")
    local rbrace       = P("}")

    local documentparser = Cs((skips + greek + 1)^0)

    local contextgrammar = Cs ( P { "scan",
        ["scan"]     = (V("global") + V("local") + skips + 1)^0,
        ["global"]   = startgreek * ((skips + greek + 1)-stopgreek )^0 ,
        ["local"]    = localgreek * V("grouped"),
        ["grouped"]  = spacing^0 * lbrace * (V("grouped") + skips + (greek - rbrace))^0 * rbrace,
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
                            report("converting '%s' using language '%s' with structure '%s'", filename, language, structure)
                            data = converter:match(data)
                            local newfilename = filename .. ".utf"
                            io.savedata(newfilename, data)
                            report("converted data saved in '%s'", newfilename)
                        else
                            report("unknown structure '%s' language '%s'", structure, language)
                        end
                    else
                        report("no converter for language '%s'", language)
                    end
                else
                    report("provide language")
                end
            else
                report("no data in '%s'",filename)
            end
        end
    end

    --~ print(contextgrammar:match [[
    --~ oeps abg \localgreek{a}
    --~ \startgreek abg \stopgreek \oeps
    --~ oeps abg \localgreek{a{b}\oeps g}
    --~ ]])

end

if environment.argument("convert") then
    scripts.babel.convert(environment.files[1] or "")
elseif environment.argument("exporthelp") then
   application.export(environment.argument("exporthelp"),environment.files[1])
else
    application.help()
end

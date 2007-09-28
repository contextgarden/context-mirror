-- data tables by Thomas A. Schmitz

dofile(input.find_file(instance,"luat-log.lua"))

texmf.instance = instance -- we need to get rid of this / maybe current instance in global table

scripts       = scripts       or { }
scripts.babel = scripts.babel or { }

do

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

    local stage_01 = (lpeg.P("<'")  * lpeg.Cs(1) * lpeg.P('|')) / replace_01
    local stage_02 = (lpeg.P(">'")  * lpeg.Cs(1) * lpeg.P('|')) / replace_02
    local stage_03 = (lpeg.P("<`")  * lpeg.Cs(1) * lpeg.P('|')) / replace_03
    local stage_04 = (lpeg.P(">`")  * lpeg.Cs(1) * lpeg.P('|')) / replace_04
    local stage_05 = (lpeg.P("<~")  * lpeg.Cs(1) * lpeg.P('|')) / replace_05
    local stage_06 = (lpeg.P(">~")  * lpeg.Cs(1) * lpeg.P('|')) / replace_06
    local stage_07 = (lpeg.P('"\'') * lpeg.Cs(1)              ) / replace_07
    local stage_08 = (lpeg.P('"`')  * lpeg.Cs(1)              ) / replace_08
    local stage_09 = (lpeg.P('"~')  * lpeg.Cs(1)              ) / replace_09
    local stage_10 = (lpeg.P("<'")  * lpeg.Cs(1)              ) / replace_10
    local stage_11 = (lpeg.P(">'")  * lpeg.Cs(1)              ) / replace_11
    local stage_12 = (lpeg.P("<`")  * lpeg.Cs(1)              ) / replace_12
    local stage_13 = (lpeg.P(">`")  * lpeg.Cs(1)              ) / replace_13
    local stage_14 = (lpeg.P(">~")  * lpeg.Cs(1)              ) / replace_14
    local stage_15 = (lpeg.P(">~")  * lpeg.Cs(1)              ) / replace_15
    local stage_16 = (lpeg.P("'")   * lpeg.Cs(1) * lpeg.P('|')) / replace_16
    local stage_17 = (lpeg.P("`")   * lpeg.Cs(1) * lpeg.P('|')) / replace_17
    local stage_18 = (lpeg.P("~")   * lpeg.Cs(1) * lpeg.P('|')) / replace_18
    local stage_19 = (lpeg.P("'")   * lpeg.Cs(1)              ) / replace_19
    local stage_20 = (lpeg.P("`")   * lpeg.Cs(1)              ) / replace_20
    local stage_21 = (lpeg.P("~")   * lpeg.Cs(1)              ) / replace_21
    local stage_22 = (lpeg.P("<")   * lpeg.Cs(1)              ) / replace_22
    local stage_23 = (lpeg.P(">")   * lpeg.Cs(1)              ) / replace_23
    local stage_24 = (lpeg.Cs(1)    * lpeg.P('|')             ) / replace_24
    local stage_25 = (lpeg.P('"')   * lpeg.Cs(1)              ) / replace_25
    local stage_26 = (lpeg.Cs(1)                              ) / replace_26

    local stages =
        skips_01 + skips_02 +
        stage_01 + stage_02 + stage_03 + stage_04 + stage_05 +
        stage_06 + stage_07 + stage_08 + stage_09 + stage_10 +
        stage_11 + stage_12 + stage_13 + stage_14 + stage_15 +
        stage_16 + stage_17 + stage_18 + stage_19 + stage_20 +
        stage_21 + stage_22 + stage_23 + stage_24 + stage_25 +
        stage_26

    local parser = lpeg.Cs((stages + 1)^0)

    -- lpeg.print(parser): 254 lines

    function scripts.babel.convert(filename)
        if filename and filename ~= empty then
            local data = io.loaddata(filename)
            if data then
                data = parser:match(data)
                io.savedata(filename .. ".utf", data)
            end
        end
    end

end

banner = banner .. " | conversion tools "

messages.help = [[
--convert             convert babel codes into utf
]]

input.verbose = true

if environment.argument("convert") then
    scripts.babel.convert(environment.files[1] or "")
else
    input.help(banner,messages.help)
end

if not modules then modules = { } end modules ['mtx-check'] = {
    version   = 1.001,
    comment   = "companion to mtxrun.lua",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

scripts         = scripts         or { }
scripts.checker = scripts.checker or { }

local validator = { }

do

    validator.n      = 1
    validator.errors = { }
    validator.trace  = false
    validator.direct = false

    validator.printer = print
    validator.tracer  = print

    local message = function(position, kind)
        local ve = validator.errors
        ve[#ve+1] = { kind, position, validator.n }
        if validator.direct then
            validator.printer(string.format("%s error at position %s (line %s)", kind, position, validator.n))
        end
    end
    local progress = function(position, data, kind)
        if validator.trace then
            validator.tracer(string.format("%s at position %s: %s", kind, position, data or ""))
        end
    end

    local P, R, S, V, C, CP, CC = lpeg.P, lpeg.R, lpeg.S, lpeg.V, lpeg.C, lpeg.Cp, lpeg.Cc

    local i_m, d_m = P("$"), P("$$")
    local l_s, r_s = P("["), P("]")
    local l_g, r_g = P("{"), P("}")

    local okay = lpeg.P("{[}") + lpeg.P("{]}")

    local esc     = P("\\")
    local cr      = P("\r")
    local lf      = P("\n")
    local crlf    = P("\r\n")
    local space   = S(" \t\f\v")
    local newline = crlf + cr + lf

    local line = newline / function() validator.n = validator.n + 1 end

    --  local grammar = P { "tokens",
    --      ["tokens"]   = (V("whatever") + V("grouped") +  V("setup") + V("display") + V("inline") + V("errors") + 1)^0,
    --      ["whatever"] = line + esc * 1 + C(P("%") * (1-line)^0),
    --      ["grouped"]  = CP() * C(l_g * (V("whatever") + V("grouped") + V("setup") + V("display") + V("inline") + (1 - l_g - r_g))^0 * r_g) * CC("group") / progress,
    --      ["setup"]    = CP() * C(l_s * (V("whatever") + V("grouped") + V("setup") + V("display") + V("inline") + (1 - l_s - r_s))^0 * r_s) * CC("setup") / progress,
    --      ["display"]  = CP() * C(d_m * (V("whatever") + V("grouped") + (1 - d_m))^0 * d_m) * CC("display") / progress,
    --      ["inline"]   = CP() * C(i_m * (V("whatever") + V("grouped") + (1 - i_m))^0 * i_m) * CC("inline") / progress,
    --      ["errors"]   = (V("gerror") + V("serror") + V("derror") + V("ierror")) * true,
    --      ["gerror"]   = CP() * (l_g + r_g) * CC("grouping") / message,
    --      ["serror"]   = CP() * (l_s + r_g) * CC("setup error") / message,
    --      ["derror"]   = CP() * d_m * CC("display math error") / message,
    --      ["ierror"]   = CP() * i_m * CC("inline math error") / message,
    --  }

    local startluacode = P("\\startluacode")
    local stopluacode  = P("\\stopluacode")

    local somecode  = startluacode * (1-stopluacode)^1 * stopluacode

    local grammar = P { "tokens",
        ["tokens"]   = (V("ignore") + V("whatever") + V("grouped") +  V("setup") + V("display") + V("inline") + V("errors") + 1)^0,
        ["whatever"] = line + esc * 1 + C(P("%") * (1-line)^0),
        ["grouped"]  = l_g * (V("whatever") + V("grouped") + V("setup") + V("display") + V("inline") + (1 - l_g - r_g))^0 * r_g,
        ["setup"]    = l_s * (okay + V("whatever") + V("grouped") + V("setup") + V("display") + V("inline") + (1 - l_s - r_s))^0 * r_s,
        ["display"]  = d_m * (V("whatever") + V("grouped") + (1 - d_m))^0 * d_m,
        ["inline"]   = i_m * (V("whatever") + V("grouped") + (1 - i_m))^0 * i_m,
        ["errors"]   = (V("gerror")+ V("serror") + V("derror") + V("ierror")),
        ["gerror"]   = CP() * (l_g + r_g) * CC("grouping") / message,
        ["serror"]   = CP() * (l_s + r_g) * CC("setup error") / message,
        ["derror"]   = CP() * d_m * CC("display math error") / message,
        ["ierror"]   = CP() * i_m * CC("inline math error") / message,
        ["ignore"]   = somecode,
    }

    function validator.check(str)
        validator.n = 1
        validator.errors = { }
        grammar:match(str)
    end

end

--~ str = [[
--~ a{oeps {oe\{\}ps} }
--~ test { oeps \} \[\] oeps \setupxxx[oeps=bla]}
--~ test $$ \hbox{$ oeps \} \[\] oeps $} $$
--~ {$x\$xx$ $
--~ ]]
--~ str = string.rep(str,10)

function scripts.checker.check(filename)
    local str = io.loaddata(filename)
    if str then
        validator.check(str)
        local errors = validator.errors
        if #errors > 0 then
            for k=1,#errors do
                local v = errors[k]
                local kind, position, line = v[1], v[2], v[3]
                local data = str:sub(position-30,position+30)
                data = data:gsub("(.)", {
                    ["\n"] = " <lf> ",
                    ["\r"] = " <cr> ",
                    ["\t"] = " <tab> ",
                })
                data = data:gsub("^ *","")
                print(string.format("% 5i  %s  %s", line,string.rpadd(kind,10," "),data))
            end
        else
            print("no error")
        end
    else
        print("no file")
    end
end

logs.extendbanner("Basic ConTeXt Syntax Checking 0.10",true)

messages.help = [[
--convert             check tex file for errors
]]

if environment.argument("check") then
    scripts.checker.check(environment.files[1])
elseif environment.argument("help") then
    logs.help(messages.help)
elseif environment.files[1] then
    scripts.checker.check(environment.files[1])
end


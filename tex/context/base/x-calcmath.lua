if not modules then modules = { } end modules ['x-calcmath'] = {
    version   = 1.001,
    comment   = "companion to x-calcmath.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}


tex = tex or { }

texsprint = tex.sprint or function(catcodes,str) print(str) end

-- ancient stuff, pre-lpeg so i need to redo it

calcmath = { }

calcmath.list_1   = {
    "median", "min", "max", "round", "ln", "log",
    "sin", "cos", "tan", "sinh", "cosh", "tanh"
}
calcmath.list_2   = {
    "int", "sum", "prod"
}
calcmath.list_3   = {
    "f", "g"
}
calcmath.list_4   = {
    "pi", "inf"
}

calcmath.list_1_1 = { }
calcmath.list_2_1 = { }
calcmath.list_2_2 = { }
calcmath.list_2_3 = { }
calcmath.list_4_1 = { }

calcmath.frozen   = false -- we can add stuff and unfreeze

function calcmath.freeze()
    for _,v in ipairs(calcmath.list_1) do
        calcmath.list_1_1[v] = "\\".. v:upper() .." "
    end
    for _,v in ipairs(calcmath.list_2) do
        calcmath.list_2_1[v .. "%((.-),(.-),(.-)%)"] = "\\" .. v:upper() .. "^{%1}_{%2}{%3}"
        calcmath.list_2_2[v .. "%((.-),(.-)%)"] = "\\" .. v:upper() .. "^{%1}{%2}"
        calcmath.list_2_3[v .. "%((.-)%)"] = "\\" .. v:upper() .. "{%1}"
    end
    for _,v in ipairs(calcmath.list_4) do
        calcmath.list_4_1[v] = "\\" .. v:upper()
    end
    calcmath.frozen = true
end

calcmath.entities = {
    ['gt'] = '>',
    ['lt'] = '<',
}

calcmath.symbols = {
    ["<="] = "\\LE ",
    [">="] = "\\GE ",
    ["=<"] = "\\LE ",
    ["=>"] = "\\GE ",
    ["=="] = "\\EQ ",
    ["<" ] = "\\LT ",
    [">" ] = "\\GT ",
    ["="]  = "\\EQ ",
}

--~ function calcmath.nsub(str,tag,pre,post)
--~     return (string.gsub(str, tag .. "(%b())", function(body)
--~         return pre .. calcmath.nsub(string.sub(body,2,-2),tag,pre,post) .. post
--~     end))
--~ end

--~ function calcmath.tex(str,mode)
--~     if not calcmath.frozen then calcmath.freeze() end
--~     local n = 0
--~     local ssub = string.gsub
--~     local nsub = calcmath.nsub
--~     local strp = string.sub
--~     -- crap
--~     str = ssub(str,"%s+"  , ' ')
--~     -- xml
--~     str = ssub(str,"&(.-);", calcmath.entities)
--~     -- ...E...
--~     str = ssub(str,"([%-%+]?[%d%.%+%-]+)E([%-%+]?[%d%.]+)", "{\\SCINOT{%1}{%2}}")
--~     -- ^-..
--~     str = ssub(str, "%^([%-%+]*%d+)", "^{%1}")
--~     -- ^(...)
--~     str = nsub(str, "%^", "^{", "}")
--~     -- 1/x^2
--~     repeat
--~         str, n = ssub(str, "([%d%w%.]+)/([%d%w%.]+%^{[%d%w%.]+})", "\\frac{%1}{%2}")
--~     until n == 0
--~     -- todo: autoparenthesis
--~     -- int(a,b,c)
--~     for k,v in pairs(calcmath.list_2_1) do -- for i=1,...
--~         repeat str, n = ssub(str, k, v) until n == 0
--~     end
--~     -- int(a,b)
--~     for k,v in pairs(calcmath.list_2_2) do
--~         repeat str, n = ssub(str, k, v) until n == 0
--~     end
--~     -- int(a)
--~     for k,v in pairs(calcmath.list_2_3) do
--~         repeat str, n = ssub(str, k, v) until n == 0
--~     end
--~     -- sin(x) => {\\sin(x)}
--~     for k,v in pairs(calcmath.list_1_1) do
--~         repeat str, n = ssub(str, k, v) until n == 0
--~     end
--~     -- mean
--~     str = nsub(str, "mean", "\\OVERLINE{", "}")
--~     -- (1+x)/(1+x) => \\FRAC{1+x}{1+x}
--~     repeat
--~         str, n = ssub(str, "(%b())/(%b())", function(a,b)
--~             return "\\FRAC{" .. strp(a,2,-2) .. "}{" .. strp(b,2,-2) .. "}"
--~         end )
--~     until n == 0
--~     -- (1+x)/x => \\FRAC{1+x}{x}
--~     repeat
--~         str, n = ssub(str, "(%b())/([%+%-]?[%.%d%w]+)", function(a,b)
--~             return "\\FRAC{" .. strp(a,2,-2) .. "}{" .. b .. "}"
--~         end )
--~     until n == 0
--~     -- 1/(1+x) => \\FRAC{1}{1+x}
--~     repeat
--~         str, n = ssub(str, "([%.%d%w]+)/(%b())", function(a,b)
--~             return "\\FRAC{" .. a .. "}{" .. strp(b,2,-2) .. "}"
--~         end )
--~     until n == 0
--~     -- 1/x => \\FRAC{1}{x}
--~     repeat
--~         str, n = ssub(str, "([%.%d%w]+)/([%+%-]?[%.%d%w]+)", "\\FRAC{%1}{%2}")
--~     until n == 0
--~     -- times
--~     str = ssub(str, "%*", " ")
--~     -- symbols -- we can use a table substitution here
--~     str = ssub(str, "([<>=][<>=]*)", calcmath.symbols)
--~     -- functions
--~     str = nsub(str, "sqrt", "\\SQRT{", "}")
--~     str = nsub(str, "exp", "e^{", "}")
--~     str = nsub(str, "abs", "\\left|", "\\right|")
--~     -- d/D
--~     str = nsub(str, "D", "{\\FRAC{\\MBOX{d}}{\\MBOX{d}x}{(", ")}}")
--~     str = ssub(str, "D([xy])", "\\FRAC{{\\RM d}%1}{{\\RM d}x}")
--~     -- f/g
--~     for k,v in pairs(calcmath.list_3) do -- todo : prepare k,v
--~         str = nsub(str, "D"..v,"{\\RM "..v.."}^{\\PRIME}(",")")
--~         str = nsub(str, v,"{\\RM "..v.."}(",")")
--~     end
--~     -- more symbols
--~     for k,v in pairs(calcmath.list_4_1) do
--~         str = ssub(str, k, v)
--~     end
--~     -- parenthesis (optional)
--~     if mode == 2 then
--~       str = ssub(str, "%(", "\\left\(")
--~       str = ssub(str, "%)", "\\right\)")
--~     end
--~     -- csnames
--~     str = ssub(str, "(\\[A-Z]+)", function(a) return a:lower() end)
--~     -- report
--~     texsprint(tex.texcatcodes,str)
--~ end

-- 5% faster

function calcmath.nsub(str,tag,pre,post)
    return (str:gsub(tag .. "(%b())", function(body)
        return pre .. calcmath.nsub(body:sub(2,-2),tag,pre,post) .. post
    end))
end

function calcmath.totex(str,mode) -- 5% faster
    if not calcmath.frozen then calcmath.freeze() end
    local n = 0
    local nsub = calcmath.nsub
    -- crap
    str = str:gsub("%s+"  , ' ')
    -- xml
    str = str:gsub("&(.-);", calcmath.entities)
    -- ...E...
    str = str:gsub("([%-%+]?[%d%.%+%-]+)E([%-%+]?[%d%.]+)", "{\\SCINOT{%1}{%2}}")
    -- ^-..
    str = str:gsub( "%^([%-%+]*%d+)", "^{%1}")
    -- ^(...)
    str = nsub(str, "%^", "^{", "}")
    -- 1/x^2
    repeat
        str, n = str:gsub("([%d%w%.]+)/([%d%w%.]+%^{[%d%w%.]+})", "\\frac{%1}{%2}")
    until n == 0
    -- todo: autoparenthesis
    -- int(a,b,c)
    for k,v in pairs(calcmath.list_2_1) do
        repeat str, n = str:gsub(k, v) until n == 0
    end
    -- int(a,b)
    for k,v in pairs(calcmath.list_2_2) do
        repeat str, n = str:gsub(k, v) until n == 0
    end
    -- int(a)
    for k,v in pairs(calcmath.list_2_3) do
        repeat str, n = str:gsub(k, v) until n == 0
    end
    -- sin(x) => {\\sin(x)}
    for k,v in pairs(calcmath.list_1_1) do
        repeat str, n = str:gsub(k, v) until n == 0
    end
    -- mean
    str = nsub(str, "mean", "\\OVERLINE{", "}")
    -- (1+x)/(1+x) => \\FRAC{1+x}{1+x}
    repeat
        str, n = str:gsub("(%b())/(%b())", function(a,b)
            return "\\FRAC{" .. a:sub(2,-2) .. "}{" .. b:sub(2,-2) .. "}"
        end )
    until n == 0
    -- (1+x)/x => \\FRAC{1+x}{x}
    repeat
        str, n = str:gsub("(%b())/([%+%-]?[%.%d%w]+)", function(a,b)
            return "\\FRAC{" .. a:sub(2,-2) .. "}{" .. b .. "}"
        end )
    until n == 0
    -- 1/(1+x) => \\FRAC{1}{1+x}
    repeat
        str, n = str:gsub("([%.%d%w]+)/(%b())", function(a,b)
            return "\\FRAC{" .. a .. "}{" .. b:sub(2,-2) .. "}"
        end )
    until n == 0
    -- 1/x => \\FRAC{1}{x}
    repeat
        str, n = str:gsub("([%.%d%w]+)/([%+%-]?[%.%d%w]+)", "\\FRAC{%1}{%2}")
    until n == 0
    -- times
    str = str:gsub("%*", " ")
    -- symbols -- we can use a table substitution here
    str = str:gsub("([<>=][<>=]*)", calcmath.symbols)
    -- functions
    str = nsub(str, "sqrt", "\\SQRT{", "}")
    str = nsub(str, "exp", "e^{", "}")
    str = nsub(str, "abs", "\\left|", "\\right|")
    -- d/D
    str = nsub(str, "D", "{\\FRAC{\\MBOX{d}}{\\MBOX{d}x}{(", ")}}")
    str = str:gsub("D([xy])", "\\FRAC{{\\RM d}%1}{{\\RM d}x}")
    -- f/g
    for k,v in pairs(calcmath.list_3) do -- todo : prepare k,v
        str = nsub(str, "D"..v,"{\\RM "..v.."}^{\\PRIME}(",")")
        str = nsub(str, v,"{\\RM "..v.."}(",")")
    end
    -- more symbols
    for k,v in pairs(calcmath.list_4_1) do
        str = str:gsub(k, v)
    end
    -- parenthesis (optional)
    if mode == 2 then
      str = str:gsub("%(", "\\left\(")
      str = str:gsub("%)", "\\right\)")
    end
    -- csnames
    str = str:gsub("(\\[A-Z]+)", function(a) return a:lower() end)
    -- report
    return str
end

function calcmath.tex(str,mode)
    texsprint(tex.texcatcodes,calcmath.totex(str))
end

function calcmath.xml(id,mode)
    local str = lxml.id(id).dt[1]
    texsprint(tex.texcatcodes,calcmath.totex(str,mode))
end

-- work in progress ... lpeg variant

if false then

    -- todo:

    -- maybe rewrite to current lpeg, i.e. string replacement and no Cc's

    -- table approach we have now is less efficient but more flexible

    -- D          \frac  {\rm d}   {{\rm d}x}
    -- Dx Dy      \frac {{\rm d}y} {{\rm d}x}
    -- Df Dg      {\rm f}^{\prime}
    -- f() g()    {\rm f}()

    -- valid utf8

    local S, P, R, C, V, Cc, Ct  = lpeg.S, lpeg.P, lpeg.R, lpeg.C, lpeg.V, lpeg.Cc, lpeg.Ct

    local space      = S(" \n\r\t")^0
    local number_x   = P("-")^-1 * R("09")^1
    local real_x     = P("-")^-1 * R("09")^1 * S(".")^1 * R("09")^1
    local number     = Cc("number")     * C(number_x) * space
    local real       = Cc("real")       * C(real_x) * space
    local float      = Cc("float")      * C(real_x) * lpeg.P("E") * lpeg.C(number_x) * space
    local identifier = Cc("identifier") * C(R("az","AZ")^1) * space
    --    compareop  = Cc("compare")    * C(P("<") + P("=") + P(">") + P(">=") + P("<=") + P("&gt;")/">" + P("&lt;")/"<") * space
    local compareop  = P("<") + P("=") + P(">") + P(">=") + P("<=") + P("&gt;") + P("&lt;")
    local factorop   = Cc("factor")     * C(S("+-^,") + compareop ) * space
    local termop     = Cc("term")       * C(S("*/")) * space
    local constant   = Cc("constant")   * C(P("pi") + lpeg.P("inf")) * space
    local functionop = Cc("function")   * C(R("az")^1) * space
    local open       = P("(") * space
    local close      = P(")") * space

    local grammar = P {
        "expression",
    --~ comparison = Ct(V("expression") * (compareop * V("expression"))^0),
        expression = Ct(V("factor"    ) * (factorop  * V("factor"    ))^0),
        factor     = Ct(V("term"      ) * (termop    * V("term"      ))^0),
        term       = Ct(
            float + real + number +
            (open * V("expression") * close) +
            (functionop * open * V("expression") * close) +
            constant + identifier
        ),
    }

    local parser = space * grammar * -1

    local format = string.format

    function totex(t)
        if t then
            local one, two, three = t[1], t[2], t[3]
            if one == "number" then
                return two
            elseif one == "real" then
                return two
            elseif one == "float" then
                return format("\\scinot{%s}{%s}", two, three)
            elseif one == "identifier" then
                return format(" %s ", two)
            elseif one == "constant" then
                return format("\\%s ", two)
            elseif one == "function" then
                if two == "sqrt" then
                    return format("\\sqrt{%s}", totex(three))
                elseif two == "exp" then
                    return format(" e^{%s}", totex(three))
                elseif two == "abs" then
                    return format("\\left|%s\\right|", totex(three))
                elseif two == "mean" then
                    return format("\\overline{%s}", totex(three))
                elseif two == "int" or two == "prod" or two == "sum" then --brrr, we need to parse better for ,,
                    local tt = three
                    if #tt == 1 then
                        return format("\\%s{%s}", two ,totex(tt[1]))
                    elseif #tt == 4 then
                        return format("\\%s^{%s}{%s}", two ,totex(tt[1]), totex(tt[4]))
                    elseif #tt == 7 then
                        return format("\\%s^{%s}_{%s}{%s}", two ,totex(tt[1]), totex(tt[4]), totex(tt[7]))
                    end
                elseif #two == 1 then
                    return format("%s(%s)", two, totex(three))
                else
                    return format("\\%s(%s)", two, totex(three))
                end
            elseif one == "factor" then
                if two == '^' then
                    return format("^{%s}%s",totex(three), (#t>3 and totex({unpack(t,4,#t)})) or "")
                else
                    if two == ">=" then
                        two = "\\ge "
                    elseif two == "<=" then
                        two = "\\le "
                    elseif two == "&gt;" then
                        two = "> "
                    elseif two == "&lt;" then
                        two = "< "
                    end
                    return format("%s%s%s", two, totex(three), (#t>3 and totex({unpack(t,4,#t)})) or "")
                end
            elseif one == "term" then
                if two == '/' then
                    if #t > 4 then
                        return format("\\frac{%s}{%s}", totex(three), totex({unpack(t,4,#t)}))
                    else
                        return format("\\frac{%s}{%s}", totex(three), totex(t[4]))
                    end
                elseif two == '*' then
                    local times = "\\times "
                    return format("%s%s%s", times, totex(three), (#t>3 and totex({unpack(t,4,#t)})) or "")
                else
                    return format("%s%s%s", two, totex(three), (#t>3 and totex({unpack(t,4,#t)})) or "")
                end
            elseif two == "factor" then
                if three == '^' then
                    return format("%s^{%s}", totex(one), totex(t[4]))
                else
                    if two == ">=" then
                        two = "\\ge "
                    elseif two == "<=" then
                        two = "\\le "
                    elseif two == "&gt;" then
                        two = "> "
                    elseif two == "&lt;" then
                        two = "< "
                    end
                    return format("%s%s", totex(one), (#t>1 and totex({unpack(t,2,#t)})) or "")
                end
            elseif two == "term" then
                if three == '/' then
                    return format("\\frac{%s}{%s}", totex(one), (#t>3 and totex({unpack(t,4,#t)})) or "")
                else
                    return format("%s%s", totex(one), (#t>1 and totex({unpack(t,2,#t)})) or "")
                end
            else
                return totex(one)
            end
        end
        return ""
    end

    calcmath = { }

    function calcmath.parse(str)
        return parser:match(str)
    end

    function calcmath.totex(str)
        str = totex(parser:match(str))
        return (str == "" and "[error]") or str
    end

end

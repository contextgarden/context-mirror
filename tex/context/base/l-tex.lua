-- filename : l-tex.lua
-- comment  : split off from luat-lib
-- author   : Hans Hagen, PRAGMA-ADE, Hasselt NL
-- copyright: PRAGMA ADE / ConTeXt Development Team
-- license  : see context related readme files

if not versions then versions = { } end versions['l-tex'] = 1.001

if not number then number = { } end

number.dimenfactors = {
    ["pt"] =             1/65536,
    ["in"] = (  100/ 7227)/65536,
    ["cm"] = (  254/ 7227)/65536,
    ["mm"] = (  254/72270)/65536,
    ["sp"] =                   1,
    ["bp"] = ( 7200/ 7227)/65536,
    ["pc"] = (    1/   12)/65536,
    ["dd"] = ( 1157/ 1238)/65536,
    ["cc"] = ( 1157/14856)/65536,
    ["nd"] = (20320/21681)/65536,
    ["nc"] = ( 5080/65043)/65536
}

function number.todimen(n,unit,fmt)
    if type(n) == 'string' then
        return n
    else
        return string.format(fmt or "%.5g%s",n*number.dimenfactors[unit or 'pt'],unit or 'pt')
    end
end

function number.topoints      (n) return number.todimen(n,"pt") end
function number.toinches      (n) return number.todimen(n,"in") end
function number.tocentimeters (n) return number.todimen(n,"cm") end
function number.tomillimeters (n) return number.todimen(n,"mm") end
function number.toscaledpoints(n) return number.todimen(n,"sp") end
function number.toscaledpoints(n) return n .. "sp" end
function number.tobasepoints  (n) return number.todimen(n,"bp") end
function number.topicas       (n) return number.todimen(n "pc") end
function number.todidots      (n) return number.todimen(n,"dd") end
function number.tociceros     (n) return number.todimen(n,"cc") end
function number.tonewdidots   (n) return number.todimen(n,"nd") end
function number.tonewciceros  (n) return number.todimen(n,"nc") end

--~ for k,v in pairs{nil, "%.5f%s", "%.8g%s", "%.8f%s"} do
--~     print(number.todimen(65536))
--~     print(number.todimen(  256))
--~     print(number.todimen(65536,'pt',v))
--~     print(number.todimen(  256,'pt',v))
--~ end

-- todo: use different scratchdimen
-- todo: use parser if no tex.dimen

function string.todimen(str)
    if type(str) == "number" then
        return str
    elseif str:find("^[%d%-%+%.]+$") then
        return tonumber(str)
--~     elseif tex then
--~         tex.dimen[0] = str
--~         return tex.dimen[0] or 0
    else
        local n, u = str:match("([%d%-%+%.]+)(%a%a)")
        if n and u then
            return n/number.dimenfactors[u]
        else
            return 0
        end
    end
end

--~ print(string.todimen("10000"))
--~ print(string.todimen("10pt"))

--~ See mk.pdf for an explanation of the following code:
--~
--~ function test(n)
--~     lua.delay(function(...)
--~         tex.sprint(string.format("pi: %s %s %s\\par",...))
--~     end)
--~     lua.delay(function(...)
--~         tex.sprint(string.format("more pi: %s %s %s\\par",...))
--~     end)
--~     tex.sprint(string.format("\\setbox0=\\hbox{%s}",math.pi*n))
--~     lua.flush(tex.wd[0],tex.ht[0],tex.dp[0])
--~ end

if lua then do

    delayed = { } -- could also be done with closures

    function lua.delay(f)
        delayed[#delayed+1] = f
    end

    function lua.flush_delayed(...)
        local t = delayed
        delayed = { }
        for _, fun in ipairs(t) do
            fun(...)
        end
    end

    function lua.flush(...)
        tex.sprint("\\directlua 0 {lua.flush_delayed(" .. table.concat({...},',') .. ")}")
    end

end end

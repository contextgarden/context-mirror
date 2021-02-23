    if not modules then modules = { } end modules ['syst-aux'] = {
    version   = 1.001,
    comment   = "companion to syst-aux.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- slower than lpeg:
--
-- utfmatch(str,"(.?)(.*)$")
-- utf.sub(str,1,1)

local tonumber, next, type = tonumber, next, type
local utfsub = utf.sub
local P, S, R, C, Cc, Cs, Carg, lpegmatch = lpeg.P, lpeg.S, lpeg.R, lpeg.C, lpeg.Cc, lpeg.Cs, lpeg.Carg, lpeg.match
local find, formatters = string.find, string.formatters

local context           = context
local implement         = interfaces.implement
local setmacro          = interfaces.setmacro
local setcatcode        = tex.setcatcode
local texget            = tex.get
local utf8character     = lpeg.patterns.utf8character
local settings_to_array = utilities.parsers.settings_to_array
local settings_to_set   = utilities.parsers.settings_to_set

local pattern           = C(utf8character^-1) * C(P(1)^0)

implement {
    name      = "getfirstcharacter",
    arguments = "string",
    actions   = function(str)
        local first, rest = lpegmatch(pattern,str)
        setmacro("firstcharacter",first)
        setmacro("remainingcharacters",rest)
    end
}

implement {
    name      = "thefirstcharacter",
    arguments = "string",
    actions   = function(str)
        local first, rest = lpegmatch(pattern,str)
        context(first)
    end
}

implement {
    name      = "theremainingcharacters",
    arguments = "string",
    actions   = function(str)
        local first, rest = lpegmatch(pattern,str)
        context(rest)
    end
}

local pattern      = C(utf8character^-1)
local ctx_doifelse = commands.doifelse

implement {
    name      = "doifelsefirstchar",
    arguments = "2 strings",
    actions   = function(str,chr)
        ctx_doifelse(lpegmatch(pattern,str) == chr)
    end
}

implement {
    name      = "getsubstring",
    arguments = "3 strings",
    actions   = function(str,first,last)
        context(utfsub(str,tonumber(first),tonumber(last)))
    end
}

-- function commands.addtocommalist(list,item)
--     if list == "" then
--         context(item)
--     else
--         context("%s,%s",list,item) -- using tex.print is some 10% faster
--     end
-- end
--
-- function commands.removefromcommalist(list,item)
--     if list == "" then
--         context(item)
--     else
--         -- okay, using a proper lpeg is probably faster
--         -- we could also check for #l = 1
--         local l = settings_to_array(list)
--         local t, n = { }
--         for i=1,#l do
--             if l[i] ~= item then
--                 n = n + 1
--                 t[n] = item
--             end
--         end
--         if n == 0 then
--             context(item)
--         else
--             context(concat(list,","))
--         end
--     end
-- end

local pattern = (C((1-P("%"))^1) * Carg(1)) / function(n,d)
    return formatters["%.0fsp"](d * tonumber(n)/100) end * P("%") * P(-1) -- .0 ?

-- percentageof("10%",65536*10)

implement {
    name      = "percentageof",
    arguments = { "string", "dimen" },
    actions   = function(str,dim)
        context(lpegmatch(pattern,str,1,dim) or str)
    end
}

-- \gdef\setpercentdimen#1#2%
--   {#1=\ctxcommand{percentageof("#2",\number#1)}\relax}

local space     = P(" ") / ""
local spaces    = P(" ")^0 / ""
local nohash    = 1 - P("#")
local digit     = R("09")
local double    = P("##") / "#"
local single    = P("#")
local sentinel  = spaces * (nohash^1 / "\\%0")
local sargument = (single * digit)^1
local dargument = (double * digit)^1

-- third variant:

local global    = nil
local protected = nil
local expanded  = nil
local optional  = nil
local csname    = nil
local rest      = nil

local function catcodes_s()
    setcatcode(32,10) -- space
    setcatcode(13, 5) -- endofline
end

local function catcodes_n()
    setcatcode(32, 9) -- ignore
    setcatcode(13, 9) -- ignore
end

local space  = P(" ")
local spaces = space^0

local option = (
        P("single")
      + P("double")
      + P("triple")
      + P("quadruple")
      + P("quintuple")
      + P("sixtuple")
  ) * (P("empty") + P("argument"))

local pattern = (
    (
        spaces * (
            ( P("spaces")     * space / catcodes_s )
          + ( P("nospaces")   * space / catcodes_n )
          + ( P("global")     * space / function()  global    = true end )
          + ( P("protected")  * space / function()  protected = true end)
          + ( P("permanent")  * space )
          + ( P("expanded")   * space / function()  expanded  = true end)
          + ( P("tolerant")   * space )
          + ( P("instance")   * space )
          + ( P("frozen")     * space )
          + ( P("mutable")    * space )
          + ( P("immutable")  * space )
          + ( P("unexpanded") * space / function()  protected = true end)
          + ( C(option)       * space / function(s) optional  = s    end)
        )
    )^0
  * spaces * ( C((1-S(" #["))^1) )
  * spaces *   Cs(
        ( P("[") * dargument * P("]") + dargument)^1 * sentinel^-1 * double^-1
      + ( P("[") * sargument * P("]") + sargument)^1 * sentinel^-1 * single^-1
      + sentinel^-1 * (double+single)^-1
    )
)

local ctx_dostarttexdefinition = context.dostarttexdefinition

local function texdefinition_one(str)
    global    = false
    protected = false
    expanded  = false
    optional  = false
    csname, rest = lpegmatch(pattern,str)
    ctx_dostarttexdefinition()
end

local function texdefinition_two()
    if optional then
        context (
            (protected and [[\protected]] or "") ..
            [[\expandafter]] .. (global and [[\xdef]] or [[\edef]]) ..
            [[\csname ]] .. csname .. [[\endcsname{\expandafter\noexpand\expandafter\do]] .. optional ..
            [[\csname _do_]] .. csname .. [[_\endcsname}\expandafter]] .. (global and [[\gdef]] or  [[\edef]]) ..
            [[\csname _do_]] .. csname .. [[_\endcsname ]] ..
            rest
        )
    else
        context (
            (protected and [[\protected]] or "") ..
            [[\expandafter]] .. (global and (expanded and [[\xdef]] or [[\gdef]]) or (expanded and [[\edef]] or [[\def]])) ..
            [[\csname ]] .. csname .. [[\endcsname ]] ..
            rest
        )
    end
end

implement { name = "texdefinition_one", actions = texdefinition_one, scope = "private", arguments = "string" }
implement { name = "texdefinition_two", actions = texdefinition_two, scope = "private" }

do

    -- Quite probably we don't yet have characters loaded so we delay some
    -- aliases.

    local _lower_, _upper_, _strip_

    _lower_ = function(s)
        if characters and characters.lower then
            _lower_ = characters.lower
            return _lower_(s)
        end
        return string.lower(s)
    end

    _upper_ = function(s)
        if characters and characters.upper then
            _upper_ = characters.upper
            return _upper_(s)
        end
        return string.upper(s)
    end

    _strip_ = function(s)
        -- or utf.strip
        if string.strip then
            _strip_ = string.strip
            return _strip_(s)
        end
        return s
    end

    local function lower(s) context(_lower_(s)) end
    local function upper(s) context(_upper_(s)) end
    local function strip(s) context(_strip_(s)) end

    implement { name = "upper", arguments = "string", actions = upper }
    implement { name = "lower", arguments = "string", actions = lower }
    implement { name = "strip", arguments = "string", actions = strip }

end

implement {
    name      = "converteddimen",
    arguments = { "dimen", "string" },
    actions   = function(dimen,unit)
        context(number.todimen(dimen,unit or "pt","%0.5f")) -- no unit appended (%F)
    end
}

-- where, not really the best spot for this:

implement {
    name      = "immediatemessage",
    arguments = { "'message'", "string" },
    actions   = logs.status
}

implement {
    name    = "resettimer",
    actions = function()
        statistics.resettiming("whatever")
        statistics.starttiming("whatever")
    end
}

implement {
    name    = "benchmarktimer",
    actions = function()
        statistics.benchmarktimer("whatever")
    end
}

implement {
    name    = "elapsedtime",
    actions = function()
        statistics.stoptiming("whatever")
        context(statistics.elapsedtime("whatever"))
    end
}

implement {
    name      = "elapsedsteptime",
    arguments = "integer",
    actions   = function(n)
        statistics.stoptiming("whatever")
        local t = statistics.elapsed("whatever")/(n > 0 and n or 1)
        if t > 0 then
            context("%0.9f",t)
        else
            context(0)
        end
    end
}

local accuracy = table.setmetatableindex(function(t,k)
    local v = formatters["%0." ..k .. "f"]
    t[k] = v
    return v
end)

implement {
    name      = "rounded",
    arguments = "integer",
    actions   = function(n,m) context(accuracy[n](m)) end
}

-- not faster but just less tracing:

local ctx_protected_cs         = context.protected.cs -- more efficient

local ctx_firstoftwoarguments  = ctx_protected_cs.firstoftwoarguments
local ctx_secondoftwoarguments = ctx_protected_cs.secondoftwoarguments
local ctx_firstofoneargument   = ctx_protected_cs.firstofoneargument
local ctx_gobbleoneargument    = ctx_protected_cs.gobbleoneargument

context.firstoftwoarguments    = ctx_firstoftwoarguments
context.secondoftwoarguments   = ctx_secondoftwoarguments
context.firstofoneargument     = ctx_firstofoneargument
context.gobbleoneargument      = ctx_gobbleoneargument

local ctx_iftrue  = context.iftrue
local ctx_iffalse = context.iffalse

local hash = utilities.parsers.hashes.settings_to_set

local function doifelsecommon(a,b)
    if a == b then
        setmacro("commalistelement",a)
        if a == "" then
            ctx_secondoftwoarguments()
        else
            ctx_firstoftwoarguments()
        end
        return
    end
    local ba = find(a,",",1,true)
    local bb = find(b,",",1,true)
    if ba and bb then
        local ha = hash[a]
        local hb = hash[b]
     -- local ha = settings_to_set(a)
     -- local hb = settings_to_set(b)
        for k in next, ha do
            if hb[k] then
                setmacro("commalistelement",k)
                ctx_firstoftwoarguments()
                return
            end
        end
    elseif ba then
        if hash[a][b] then
     -- if settings_to_set(a)[b] then
            setmacro("commalistelement",b)
            ctx_firstoftwoarguments()
            return
        end
    elseif bb then
        if hash[b][a] then
     -- if settings_to_set(b)[a] then
            setmacro("commalistelement",a)
            ctx_firstoftwoarguments()
            return
        end
    end
    setmacro("commalistelement","")
    ctx_secondoftwoarguments()
end

local function doifcommon(a,b)
    if a == b then
        setmacro("commalistelement",a)
        if a == "" then
            ctx_gobbleoneargument()
        else
            ctx_firstofoneargument()
        end
        return
    end
    local ba = find(a,",",1,true)
    local bb = find(b,",",1,true)
    if ba and bb then
        local ha = hash[a]
        local hb = hash[b]
     -- local ha = settings_to_set(a)
     -- local hb = settings_to_set(b)
        for k in next, ha do
            if hb[k] then
                setmacro("commalistelement",k)
                ctx_firstofoneargument()
                return
            end
        end
    elseif ba then
        if hash[a][b] then
     -- if settings_to_set(a)[b] then
            setmacro("commalistelement",b)
            ctx_firstofoneargument()
            return
        end
    elseif bb then
        if hash[b][a] then
     -- if settings_to_set(b)[a] then
            setmacro("commalistelement",a)
            ctx_firstofoneargument()
            return
        end
    end
    setmacro("commalistelement","")
    ctx_gobbleoneargument()
end

local function doifnotcommon(a,b)
    if a == b then
        setmacro("commalistelement",a)
        if a == "" then
            ctx_firstofoneargument()
        else
            ctx_gobbleoneargument()
        end
        return
    end
    local ba = find(a,",",1,true)
    local bb = find(b,",",1,true)
    if ba and bb then
        local ha = hash[a]
        local hb = hash[b]
     -- local ha = settings_to_set(a)
     -- local hb = settings_to_set(b)
        for k in next, ha do
            if hb[k] then
                setmacro("commalistelement",k)
                ctx_gobbleoneargument()
                return
            end
        end
    elseif ba then
        if hash[a][b] then
     -- if settings_to_set(a)[b] then
            setmacro("commalistelement",b)
            ctx_gobbleoneargument()
            return
        end
    elseif bb then
        if hash[b][a] then
     -- if settings_to_set(b)[a] then
            setmacro("commalistelement",a)
            ctx_gobbleoneargument()
            return
        end
    end
    setmacro("commalistelement","")
    ctx_firstofoneargument()
end

-- local function hascommonargumentcondition(a,b)
--     if a == b then
--         setmacro("commalistelement",a)
--         if a == "" then
--             ctx_iffalse()
--         else
--             ctx_iftrue()
--         end
--         return
--     end
--     local ba = find(a,",",1,true)
--     local bb = find(b,",",1,true)
--     if ba and bb then
--         local ha = hash[a]
--         local hb = hash[b]
--         for k in next, ha do
--             if hb[k] then
--                 setmacro("commalistelement",k)
--                 ctx_iftrue()
--                 return
--             end
--         end
--     elseif ba then
--         if hash[a][b] then
--             setmacro("commalistelement",b)
--             ctx_iftrue()
--             return
--         end
--     elseif bb then
--         if hash[b][a] then
--             setmacro("commalistelement",a)
--             ctx_iftrue()
--             return
--         end
--     end
--     setmacro("commalistelement","")
--     ctx_iffalse()
-- end

local function doifelseinset(a,b)
    if a == b then
        setmacro("commalistelement",a)
        if a == "" then
            ctx_secondoftwoarguments()
        else
            ctx_firstoftwoarguments()
        end
        return
    end
    local bb = find(b,",",1,true)
    if bb then
        if hash[b][a] then
     -- if settings_to_set(b)[a] then
            setmacro("commalistelement",a)
            ctx_firstoftwoarguments()
            return
        end
    end
    setmacro("commalistelement","")
    ctx_secondoftwoarguments()
end

local function doifinset(a,b)
    if a == b then
        setmacro("commalistelement",a)
        if a == "" then
            ctx_gobbleoneargument()
        else
            ctx_firstofoneargument()
        end
        return
    end
    local bb = find(b,",",1,true)
    if bb then
       if hash[b][a] then
    -- if settings_to_set(b)[a] then
            setmacro("commalistelement",a)
            ctx_firstofoneargument()
            return
        end
    end
    setmacro("commalistelement","")
    ctx_gobbleoneargument()
end

local function doifnotinset(a,b)
    if a == b then
        setmacro("commalistelement",a)
        if a == "" then
            ctx_firstofoneargument()
        else
            ctx_gobbleoneargument()
        end
        return
    end
    local bb = find(b,",",1,true)
    if bb then
        if hash[b][a] then
     -- if settings_to_set(b)[a] then
            setmacro("commalistelement",a)
            ctx_gobbleoneargument()
            return
        end
    end
    setmacro("commalistelement","")
    ctx_firstofoneargument()
end

implement {
    name      = "doifelsecommon",
    actions   = doifelsecommon,
    arguments = "2 strings",
}

implement {
    name      = "doifcommon",
    actions   = doifcommon,
    arguments = "2 strings",
}

implement {
    name      = "doifnotcommon",
    actions   = doifnotcommon,
    arguments = "2 strings",
}

-- implement {
--     name      = "hascommonargumentcondition",
--     actions   = hascommonargumentcondition,
--     arguments = "2 strings",
--     arguments = { "argument", "argument" },
-- }

implement {
    name      = "doifelseinset",
    actions   = doifelseinset,
    arguments = "2 strings",
--     arguments = { "argument", "argument" },
}

implement {
    name      = "doifinset",
    actions   = doifinset,
    arguments = "2 strings",
}

implement {
    name      = "doifnotinset",
    actions   = doifnotinset,
    arguments = "2 strings",
}

-- done elsewhere:
--
-- local function firstinset(a)
--     local aa = hash[a]
--     context(aa and aa[1] or a)
-- end
--
-- implement {
--     name      = "firstinset",
--     actions   = firstinset,
--     arguments = "string",
--     private   = false,
-- }

-- implement {
--     name      = "stringcompare",
--     arguments = "2 strings",
--     actions   = function(a,b)
--         context((a == b and 0) or (a > b and 1) or -1)
--     end
-- }
--
-- implement {
--     name      = "doifelsestringafter",
--     arguments = "2 strings",
--     actions   = function(a,b)
--         ctx_doifelse((a == b and 0) or (a > b and 1) or -1)
--     end
-- }
--
-- implement {
--     name      = "doifelsestringbefore",
--     arguments = "2 strings",
--     actions   = function(a,b)
--         ctx_doifelse((a == b and 0) or (a < b and -1) or 1)
--     end
-- }

-- implement { -- not faster than addtocommalist
--     name      = "additemtolist", -- unique
--     arguments = "2 strings",
--     actions   = function(l,s)
--         if l == "" or s == l then
--          -- s = s
--         elseif find("," .. l .. ",","," .. s .. ",") then
--             s = l
--         else
--             s = l .. "," .. s
--         end
--         context(s)
--     end
-- }

local bp = number.dimenfactors.bp

implement {
    name      = "tobigpoints",
    actions   = function(d) context("%.5F",bp * d) end,
    arguments = "dimension",
}

implement {
    name      = "towholebigpoints",
    actions   = function(d) context("%r",bp * d) end,
    arguments = "dimension",
}

-- for now here:

local function getshape(s)
    local t = texget(s)
    local n = t and #t or 0
    context(n)
    if n > 0 then
        for i=1,n do
            local ti = t[i]
            if type(ti) == "table" then
                context(" %isp %isp",ti[1],ti[2])
            else
                context(" %i",ti)
            end
        end
    end
end

implement {
    name    = "getparshape",
    public  = true,
    actions = function() getshape("parshape") end,
}
implement {
    name    = "getclubpenalties",
    public  = true,
    actions = function() getshape("clubpenalties") end,
}
implement {
    name    = "getinterlinepenalties",
    public  = true,
    actions = function() getshape("interlinepenalties") end,
    }
implement {
    name    = "getdisplaywidowpenalties",
    public  = true,
    actions = function() getshape("displaywidowpenalties") end,
}
implement {
    name    = "getwidowpenalties",
    public  = true,
    actions = function() getshape("widowpenalties") end,
}

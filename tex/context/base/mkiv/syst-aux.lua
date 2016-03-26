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

local tonumber = tonumber
local utfsub = utf.sub
local P, S, R, C, Cc, Cs, Carg, lpegmatch = lpeg.P, lpeg.S, lpeg.R, lpeg.C, lpeg.Cc, lpeg.Cs, lpeg.Carg, lpeg.match
local next = next
local find  = string.find

local context           = context
local implement         = interfaces.implement
local formatters        = string.formatters
local setcatcode        = tex.setcatcode
local utf8character     = lpeg.patterns.utf8character
local settings_to_array = utilities.parsers.settings_to_array
local settings_to_set  = utilities.parsers.settings_to_set
local setmacro          = interfaces.setmacro

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
    arguments = { "string", "string" },
    actions   = function(str,chr)
        ctx_doifelse(lpegmatch(pattern,str) == chr)
    end
}

implement {
    name      = "getsubstring",
    arguments = { "string", "string", "string" },
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

local spaces    = P(" ")^0 / ""
local nohash    = 1 - P("#")
local digit     = R("09")
local double    = P("##") / "#"
local single    = P("#")
local sentinel  = spaces * (nohash^1 / "\\%0")
local sargument = (single * digit)^1
local dargument = (double * digit)^1

local usespaces   = nil
local texpreamble = nil

local pattern = Cs( -- ^-1
    ( P("spaces") / function() usespaces = true return "" end )^0
  * spaces
  * ( P("nospaces") / function() usespaces = false return "" end )^0
  * spaces
  * ( P("global") / "\\global" )^0
  * spaces
  * ( P("unexpanded") / "\\unexpanded" )^0
  * spaces
  * Cc("\\expandafter\\")
  * spaces
  * ( P("expanded") / "e" )^0
  * spaces
  * ( P((1-S(" #"))^1) / "def\\csname %0\\endcsname" )
  * spaces
  * (
   --   (double * digit)^1 * sentinel^-1 * double^-1
   -- + (single * digit)^1 * sentinel^-1 * single^-1
        ( P("[") * dargument * P("]") + dargument)^1 * sentinel^-1 * double^-1
      + ( P("[") * sargument * P("]") + sargument)^1 * sentinel^-1 * single^-1
      + sentinel^-1 * (double+single)^-1
    )
)

local ctx_dostarttexdefinition = context.dostarttexdefinition

local function texdefinition_one(str)
    usespaces   = nil
    texpreamble = lpegmatch(pattern,str)
    if usespaces == true then
        setcatcode(32,10) -- space
        setcatcode(13, 5) -- endofline
    elseif usespaces == false then
        setcatcode(32, 9) -- ignore
        setcatcode(13, 9) -- ignore
    else
        -- this is default
     -- setcatcode(32,10) -- space
     -- setcatcode(13, 9) -- ignore
    end
    ctx_dostarttexdefinition()
end

local function texdefinition_two()
    context(texpreamble)
end

implement { name = "texdefinition_one", actions = texdefinition_one, scope = "private", arguments = "string" }
implement { name = "texdefinition_two", actions = texdefinition_two, scope = "private" }

implement { name = "upper", arguments = "string", actions = { utf.upper,    context } }
implement { name = "lower", arguments = "string", actions = { utf.lower,    context } }
implement { name = "strip", arguments = "string", actions = { string.strip, context } } -- or utf.strip

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
    name    = "elapsedtime",
    actions = function()
        statistics.stoptiming("whatever")
        context(statistics.elapsedtime("whatever"))
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

local firstoftwoarguments  = context.firstoftwoarguments
local secondoftwoarguments = context.secondoftwoarguments
local firstofoneargument   = context.firstofoneargument
local gobbleoneargument    = context.gobbleoneargument

local hash = utilities.parsers.hashes.settings_to_set

local function doifelsecommon(a,b)
    if a == b then
        setmacro("commalistelement",a)
        if a == "" then
            secondoftwoarguments()
        else
            firstoftwoarguments()
        end
        return
    end
    local ba = find(a,",")
    local bb = find(b,",")
    if ba and bb then
        local ha = hash[a]
        local hb = hash[b]
     -- local ha = settings_to_set(a)
     -- local hb = settings_to_set(b)
        for k in next, ha do
            if hb[k] then
                setmacro("commalistelement",k)
                firstoftwoarguments()
                return
            end
        end
    elseif ba then
        if hash[a][b] then
     -- if settings_to_set(a)[b] then
            setmacro("commalistelement",b)
            firstoftwoarguments()
            return
        end
    elseif bb then
        if hash[b][a] then
     -- if settings_to_set(b)[a] then
            setmacro("commalistelement",a)
            firstoftwoarguments()
            return
        end
    end
    setmacro("commalistelement","")
    secondoftwoarguments()
end

local function doifcommon(a,b)
    if a == b then
        setmacro("commalistelement",a)
        if a == "" then
            gobbleoneargument()
        else
            firstofoneargument()
        end
        return
    end
    local ba = find(a,",")
    local bb = find(b,",")
    if ba and bb then
        local ha = hash[a]
        local hb = hash[b]
     -- local ha = settings_to_set(a)
     -- local hb = settings_to_set(b)
        for k in next, ha do
            if hb[k] then
                setmacro("commalistelement",k)
                firstofoneargument()
                return
            end
        end
    elseif ba then
        if hash[a][b] then
     -- if settings_to_set(a)[b] then
            setmacro("commalistelement",b)
            firstofoneargument()
            return
        end
    elseif bb then
        if hash[b][a] then
     -- if settings_to_set(b)[a] then
            setmacro("commalistelement",a)
            firstofoneargument()
            return
        end
    end
    setmacro("commalistelement","")
    gobbleoneargument()
end

local function doifnotcommon(a,b)
    if a == b then
        setmacro("commalistelement",a)
        if a == "" then
            firstofoneargument()
        else
            gobbleoneargument()
        end
        return
    end
    local ba = find(a,",")
    local bb = find(b,",")
    if ba and bb then
        local ha = hash[a]
        local hb = hash[b]
     -- local ha = settings_to_set(a)
     -- local hb = settings_to_set(b)
        for k in next, ha do
            if hb[k] then
                setmacro("commalistelement",k)
                gobbleoneargument()
                return
            end
        end
    elseif ba then
        if hash[a][b] then
     -- if settings_to_set(a)[b] then
            setmacro("commalistelement",b)
            gobbleoneargument()
            return
        end
    elseif bb then
        if hash[b][a] then
     -- if settings_to_set(b)[a] then
            setmacro("commalistelement",a)
            gobbleoneargument()
            return
        end
    end
    setmacro("commalistelement","")
    firstofoneargument()
end

local function doifelseinset(a,b)
    if a == b then
        setmacro("commalistelement",a)
        if a == "" then
            secondoftwoarguments()
        else
            firstoftwoarguments()
        end
        return
    end
    local bb = find(b,",")
    if bb then
        if hash[b][a] then
     -- if settings_to_set(b)[a] then
            setmacro("commalistelement",a)
            firstoftwoarguments()
            return
        end
    end
    setmacro("commalistelement","")
    secondoftwoarguments()
end

local function doifinset(a,b)
    if a == b then
        setmacro("commalistelement",a)
        if a == "" then
            gobbleoneargument()
        else
            firstofoneargument()
        end
        return
    end
    local bb = find(b,",")
    if bb then
       if hash[b][a] then
    -- if settings_to_set(b)[a] then
            setmacro("commalistelement",a)
            firstofoneargument()
            return
        end
    end
    setmacro("commalistelement","")
    gobbleoneargument()
end

local function doifnotinset(a,b)
    if a == b then
        setmacro("commalistelement",a)
        if a == "" then
            firstofoneargument()
        else
            gobbleoneargument()
        end
        return
    end
    local bb = find(b,",")
    if bb then
        if hash[b][a] then
     -- if settings_to_set(b)[a] then
            setmacro("commalistelement",a)
            gobbleoneargument()
            return
        end
    end
    setmacro("commalistelement","")
    firstofoneargument()
end

implement {
    name      = "doifelsecommon",
    actions   = doifelsecommon,
    arguments = { "string", "string" },
}

implement {
    name      = "doifcommon",
    actions   = doifcommon,
    arguments = { "string", "string" },
}

implement {
    name      = "doifnotcommon",
    actions   = doifnotcommon,
    arguments = { "string", "string" },
}

implement {
    name      = "doifelseinset",
    actions   = doifelseinset,
    arguments = { "string", "string" },
}

implement {
    name      = "doifinset",
    actions   = doifinset,
    arguments = { "string", "string" },
}

implement {
    name      = "doifnotinset",
    actions   = doifnotinset,
    arguments = { "string", "string" },
}

-- implement {
--     name      = "stringcompare",
--     arguments = { "string", "string" },
--     actions   = function(a,b)
--         context((a == b and 0) or (a > b and 1) or -1)
--     end
-- }
--
-- implement {
--     name      = "doifelsestringafter",
--     arguments = { "string", "string" },
--     actions   = function(a,b)
--         ctx_doifelse((a == b and 0) or (a > b and 1) or -1)
--     end
-- }
--
-- implement {
--     name      = "doifelsestringbefore",
--     arguments = { "string", "string" },
--     actions   = function(a,b)
--         ctx_doifelse((a == b and 0) or (a < b and -1) or 1)
--     end
-- }

-- implement { -- not faster than addtocommalist
--     name      = "additemtolist", -- unique
--     arguments = { "string", "string" },
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

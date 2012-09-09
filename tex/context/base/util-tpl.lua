if not modules then modules = { } end modules ['util-tpl'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- experimental code

-- maybe make %% scanning optional
-- maybe use $[ and ]$ or {{ }}

utilities.templates = utilities.templates or { }
local templates     = utilities.templates

local trace_template  = false  trackers.register("templates.trace",function(v) trace_template = v end)
local report_template = logs.reporter("template")

local format = string.format
local P, C, Cs, Carg, lpegmatch = lpeg.P, lpeg.C, lpeg.Cs, lpeg.Carg, lpeg.match

-- todo: make installable template.new

local replacer

local function replacekey(k,t)
    local v = t[k]
    if not v then
        if trace_template then
            report_template("unknown key %q",k)
        end
        return ""
    else
        if trace_template then
            report_template("setting key %q to value %q",k,v)
        end
        return lpegmatch(replacer,v,1,t) -- recursive
    end
end

local sqlescape = lpeg.replacer {
    { "'",    "''"   },
    { "\\",   "\\\\" },
    { "\r\n", "\\n"  },
    { "\r",   "\\n"  },
 -- { "\t",   "\\t"  },
}

local escapers = {
    lua = function(s)
        return format("%q",s)
    end,
    sql = function(s)
        return lpegmatch(sqlescape,s)
    end,
}

local function replacekeyunquoted(s,t,how) -- ".. \" "
    local escaper = how and escapers[how] or escapers.lua
    return escaper(replacekey(s,t))
end

local single      = P("%")  -- test %test% test   : resolves test
local double      = P("%%") -- test 10%% test     : %% becomes %
local lquoted     = P("%[") -- test %[test]" test : resolves test with escaped "'s
local rquoted     = P("]%") --

local escape      = double  / '%%'
local nosingle    = single  / ''
local nodouble    = double  / ''
local nolquoted   = lquoted / ''
local norquoted   = rquoted / ''

local key         = nosingle * (C((1-nosingle)^1 * Carg(1))/replacekey) * nosingle
local unquoted    = nolquoted * ((C((1 - norquoted)^1) * Carg(1) * Carg(2))/replacekeyunquoted) * norquoted
local any         = P(1)

      replacer    = Cs((unquoted + escape + key + any)^0)

local function replace(str,mapping,how)
    if mapping then
        return lpegmatch(replacer,str,1,mapping,how or "lua") or str
    else
        return str
    end
end

-- print(replace("test '%[x]%' test",{ x = [[a 'x'  a]] }))
-- print(replace("test '%[x]%' test",{ x = [[a 'x'  a]] },'sql'))

templates.replace = replace

function templates.load(filename,mapping)
    local data = io.loaddata(filename) or ""
    if mapping and next(mapping) then
        return replace(data,mapping)
    else
        return data
    end
end

function templates.resolve(t,mapping)
    if not mapping then
        mapping = t
    end
    for k, v in next, t do
        t[k] = replace(v,mapping)
    end
    return t
end

-- inspect(utilities.templates.replace("test %one% test", { one = "%two%", two = "two" }))
-- inspect(utilities.templates.resolve({ one = "%two%", two = "two", three = "%three%" }))


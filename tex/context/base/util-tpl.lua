if not modules then modules = { } end modules ['util-tpl'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- This is experimental code. Coming from dos and windows, I've always used %whatever%
-- as template variables so let's stick to it. After all, it's easy to parse and stands
-- out well. A double %% is turned into a regular %.

utilities.templates = utilities.templates or { }
local templates     = utilities.templates

local trace_template  = false  trackers.register("templates.trace",function(v) trace_template = v end)
local report_template = logs.reporter("template")

local format = string.format
local P, C, Cs, Carg, lpegmatch = lpeg.P, lpeg.C, lpeg.Cs, lpeg.Carg, lpeg.match

-- todo: make installable template.new

local replacer

local function replacekey(k,t,recursive)
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
        if recursive then
            return lpegmatch(replacer,v,1,t)
        else
            return v
        end
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

lpeg.patterns.sqlescape = sqlescape

local function replacekeyunquoted(s,t,how,recurse) -- ".. \" "
    local escaper = how and escapers[how] or escapers.lua
    return escaper(replacekey(s,t,recurse))
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

local key         = nosingle * (C((1-nosingle)^1 * Carg(1) * Carg(2) * Carg(3))/replacekey) * nosingle
local unquoted    = nolquoted * ((C((1 - norquoted)^1) * Carg(1) * Carg(2) * Carg(3))/replacekeyunquoted) * norquoted
local any         = P(1)

      replacer    = Cs((unquoted + escape + key + any)^0)

local function replace(str,mapping,how,recurse)
    if mapping then
        return lpegmatch(replacer,str,1,mapping,how or "lua",recurse or false) or str
    else
        return str
    end
end

-- print(replace("test '%[x]%' test",{ x = [[a 'x'  a]] }))
-- print(replace("test '%[x]%' test",{ x = [[a 'x'  a]] },'sql'))

templates.replace = replace

function templates.load(filename,mapping,how,recurse)
    local data = io.loaddata(filename) or ""
    if mapping and next(mapping) then
        return replace(data,mapping,how,recurse)
    else
        return data
    end
end

function templates.resolve(t,mapping,how,recurse)
    if not mapping then
        mapping = t
    end
    for k, v in next, t do
        t[k] = replace(v,mapping,how,recurse)
    end
    return t
end

-- inspect(utilities.templates.replace("test %one% test", { one = "%two%", two = "two" }))
-- inspect(utilities.templates.resolve({ one = "%two%", two = "two", three = "%three%" }))

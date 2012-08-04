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

local P, C, Cs, Carg, lpegmatch = lpeg.P, lpeg.C, lpeg.Cs, lpeg.Carg, lpeg.match

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
        return v
    end
end

----- leftmarker  = P("<!-- ") / ""
----- rightmarker = P(" --!>") / ""

local escape      = P("%%") / "%%"
local leftmarker  = P("%")  / ""
local rightmarker = P("%")  / ""

local key         = leftmarker * (C((1-rightmarker)^1 * Carg(1))/replacekey) * rightmarker
local any         = P(1)
local replacer    = Cs((escape + key + any)^0)

function templates.replace(str,mapping)
    return mapping and lpegmatch(replacer,str,1,mapping) or str
end

function templates.load(filename,mapping)
    local data = io.loaddata(filename) or ""
    if mapping and next(mapping) then
        return templates.replace(data,mapping)
    else
        return data
    end
end

if not modules then modules = { } end modules ['java-ini'] = {
    version   = 1.001,
    comment   = "companion to java-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local format = string.format
local concat = table.concat
local lpegmatch, lpegP, lpegR, lpegS, lpegC = lpeg.match, lpeg.P, lpeg.R, lpeg.S, lpeg.C

local allocate  = utilities.storage.allocate
local variables = interfaces.variables

-- todo: don't flush scripts if no JS key

local trace_javascript = false  trackers.register("backends.javascript", function(v) trace_javascript = v end)

local report_javascript = logs.new("javascript")

interactions.javascripts = interactions.javascripts or { }
local javascripts        = interactions.javascripts

javascripts.codes        = allocate()
javascripts.preambles    = allocate()
javascripts.functions    = allocate()

local codes, preambles, functions = javascripts.codes, javascripts.preambles, javascripts.functions

local preambled = { }

local function storefunction(s)
    functions[s] = true
end

local uses     = lpegP("uses")
local used     = lpegP("used")
local left     = lpegP("{")
local right    = lpegP("}")
local space    = lpegS(" \r\n")
local spaces   = space^0
local braced   = left * lpegC((1-right-space)^1) * right
local unbraced = lpegC((1-space)^1)
local name     = spaces * (braced + unbraced) * spaces
local any      = lpegP(1)
local script   = lpegC(any^1)
local funct    = lpegP("function")
local leftp    = lpegP("(")
local rightp   = lpegP(")")
local fname    = spaces * funct * spaces * (((1-space-left)^1)/storefunction) * spaces * leftp

local parsecode      = name * ((uses * name) + lpeg.Cc("")) * spaces * script
local parsepreamble  = name * ((used * name) + lpeg.Cc("")) * spaces * script
local parsefunctions = (fname + any)^0

function javascripts.storecode(str)
    local name, uses, script = lpegmatch(parsecode,str)
    if name and name ~= "" then
        codes[name] = { uses, script }
    end
end

function javascripts.storepreamble(str) -- now later
    local name, used, script = lpegmatch(parsepreamble,str)
    if name and name ~= "" and not preambled[name] then
        local n = #preambles + 1
        preambles[n] = { name, used, script }
        preambled[name] = n
        if trace_javascript then
            report_javascript("storing preamble '%s', state '%s', order '%s'",name,used,n)
        end
        lpegmatch(parsefunctions,script)
    end
end

function javascripts.setpreamble(name,script) -- now later
    if name and name ~= "" and not preambled[name] then
        local n = #preambles + 1
        preambles[n] = { name, "now", script }
        preambled[name] = n
        if trace_javascript then
            report_javascript("setting preamble '%s', state 'now', order '%s'",name,n)
        end
        lpegmatch(parsefunctions,script)
    end
end

function javascripts.addtopreamble(name,script) -- now later
    if name and name ~= "" then
        local p = preambled[name]
        if p then
            preambles[p] = { "now", preambles[p] .. " ;\n" .. script }
            if trace_javascript then
                report_javascript("extending preamble '%s', state 'now'",name)
            end
        else
            local n = #preambles + 1
            preambles[n] = { name, "now", script }
            preambled[name] = n
            if trace_javascript then
                report_javascript("storing preamble '%s', state 'now', order '%s'",name,n)
            end
            lpegmatch(parsefunctions,script)
        end
    end
end

function javascripts.usepreamblenow(name) -- now later
    if name and name ~= "" and name ~= variables.reset then -- todo: reset
        local names = utilities.parsers.settings_to_array(name)
        for i=1,#names do
            local somename = names[i]
            if not preambled[somename] then
                preambles[preambled[somename]][2] = "now"
                if trace_javascript then
                    report_javascript("using preamble '%s', state 'now'",somename)
                end
            end
        end
    end
end

local splitter = lpeg.Ct(lpeg.splitat(lpeg.patterns.commaspacer))

local used, reported = false, { } -- we can cache more

function javascripts.code(name,arguments)
    local c = codes[name]
    if c then
        local u, code = c[1], c[2]
        if u ~= "" then
            local p = preambled[u]
            if p then
                preambles[p][2] = "now"
                if trace_javascript and not reported[name] then
                    reported[name] = true
                    report_javascript("using code '%s', preamble '%s'",name,u)
                end
            elseif trace_javascript and not reported[name] then
                reported[name] = true
                report_javascript("using code '%s'",name)
            end
        elseif trace_javascript and not reported[name] then
            reported[name] = true
            report_javascript("using code '%s'",name)
        end
        used = true
        return code
    end
    local f = functions[name]
    if f then
        used = true
        if trace_javascript and not reported[name] then
            reported[name] = true
            report_javascript("using function '%s'",name)
        end
        if arguments then
            local args = lpegmatch(splitter,arguments)
            for i=1,#args do -- can be a helper
                args[i] = format("%q",args[i])
            end
            return format("%s(%s)",name,concat(args,","))
        else
            return format("%s()",name)
        end
    end
end

function javascripts.flushpreambles()
    local t = { }
    if used then
        for i=1,#preambles do
            local preamble = preambles[i]
            if preamble[2] == "now" then
                if trace_javascript then
                    report_javascript("flushing preamble '%s'",preamble[1])
                end
                t[#t+1] = { preamble[1], preamble[3] }
            end
        end
    end
    return t
end

local patterns = { "java-imp-%s.mkiv", "java-imp-%s.tex", "java-%s.mkiv", "java-%s.tex" }

function javascripts.usescripts(name)
    if name ~= variables.reset then
        commands.uselibrary(name,patterns,function(name,foundname)
            context.startnointerference()
            context.startreadingfile()
            context.input(foundname)
            context.showcolormessage("javascript",1,name)
            context.stopreadingfile()
            context.stopnointerference()
        end)
    end
end

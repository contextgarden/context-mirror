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

javascripts           = javascripts           or { }
javascripts.codes     = javascripts.codes     or { }
javascripts.preambles = javascripts.preambles or { }
javascripts.functions = javascripts.functions or { }

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
        javascripts.codes[name] = { uses, script }
    end
end

function javascripts.storepreamble(str) -- now later
    local name, used, script = lpegmatch(parsepreamble,str)
    if name and name ~= "" then
        preambles[#preambles+1] = { name, used, script }
        preambled[name] = #preambles
        lpegmatch(parsefunctions,script)
    end
end

function javascripts.setpreamble(name,script) -- now later
    if name and name ~= "" then
        preambles[#preambles+1] = { name, "now", script }
        preambled[name] = #preambles
        lpegmatch(parsefunctions,script)
    end
end

function javascripts.addtopreamble(name,script) -- now later
    if name and name ~= "" then
        local p = preambled[name]
        if p then
            preambles[p] = { "now", preambles[p] .. " ;\n" .. script }
        else
            preambles[#preambles+1] = { name, "now", script }
            preambled[name] = #preambles
            lpegmatch(parsefunctions,script)
        end
    end
end

function javascripts.usepreamblenow(name) -- now later
    if name and name ~= "" and preambled[name] then
        preambles[preambled[name]][2] = "now"
    end
end

local splitter = lpeg.Ct(lpeg.splitat(lpeg.patterns.commaspacer))

function javascripts.code(name,arguments)
    local c = codes[name]
    if c then
        local u, code = c[1], c[2]
        if u ~= "" then
            local p = preambled[u]
            if p then
                preambles[p][1] = "now"
            end
        end
        return code
    end
    local f = functions[name]
    if f then
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
    for i=1,#preambles do
        local preamble = preambles[i]
        if preamble[2] == "now" then
            t[#t+1] = { preamble[1], preamble[3] }
        end
    end
    return t
end

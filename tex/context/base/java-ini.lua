if not modules then modules = { } end modules ['java-ini'] = {
    version   = 1.001,
    comment   = "companion to java-ini.tex",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

javascripts           = javascripts           or { }
javascripts.codes     = javascripts.codes     or { }
javascripts.preambles = javascripts.preambles or { }
javascripts.functions = javascripts.functions or { }

local codes, preambles, functions = javascripts.codes, javascripts.preambles, javascripts.functions

local preambled = { }

local function storefunction(s)
    functions[s] = true
end

local uses     = lpeg.P("uses")
local used     = lpeg.P("used")
local left     = lpeg.P("{")
local right    = lpeg.P("}")
local space    = lpeg.S(" \r\n")
local spaces   = space^0
local braced   = left * lpeg.C((1-right-space)^1) * right
local unbraced = lpeg.C((1-space)^1)
local name     = spaces * (braced + unbraced) * spaces
local any      = lpeg.P(1)
local script   = lpeg.C(any^1)
local funct    = lpeg.P("function")
local leftp    = lpeg.P("(")
local rightp   = lpeg.P(")")
local fname    = spaces * funct * spaces * (((1-space-left)^1)/storefunction) * spaces * leftp

local parsecode      = name * ((uses * name) + lpeg.Cc("")) * spaces * script
local parsepreamble  = name * ((used * name) + lpeg.Cc("")) * spaces * script
local parsefunctions = (fname + any)^0

function javascripts.storecode(str)
    local name, uses, script = parsecode:match(str)
    if name and name ~= "" then
        javascripts.codes[name] = { uses, script }
    end
end

function javascripts.storepreamble(str) -- now later
    local name, used, script = parsepreamble:match(str)
    if name and name ~= "" then
        preambles[#preambles+1] = { name, used, script }
        preambled[name] = #preambles
        parsefunctions:match(script)
    end
end

function javascripts.setpreamble(name,script) -- now later
    if name and name ~= "" then
        preambles[#preambles+1] = { name, "now", script }
        preambled[name] = #preambles
        parsefunctions:match(script)
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
            parsefunctions:match(script)
        end
    end
end

function javascripts.usepreamblenow(name) -- now later
    if name and name ~= "" and preambled[name] then
        preambles[preambled[name]][2] = "now"
    end
end

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
        return string.format("%s(%s)",name,arguments or "")
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

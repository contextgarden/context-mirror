if not modules then modules = { } end modules ['m-spreadsheet'] = {
    version   = 1.001,
    comment   = "companion to m-spreadsheet.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local byte, format, gsub, validstring = string.byte, string.format, string.gsub, string.valid
local R, P, C, Cs, Cc, Carg, lpegmatch = lpeg.R, lpeg.P, lpeg.C, lpeg.Cs, lpeg.Cc, lpeg.Carg, lpeg.match

local context = context

moduledata = moduledata or { }

local spreadsheets      = { }
moduledata.spreadsheets = spreadsheets

local data = {
    -- nothing yet
}

local settings = {
    numberseparator = ".",
}

spreadsheets.data     = data
spreadsheets.settings = settings

local stack, current = { }, "default"

local mt ; mt = {
    __index = function(t,k)
        local v = { }
        setmetatable(v,mt)
        t[k] = v
        return v
    end,
}

function spreadsheets.reset(name)
    if not name or name == "" then name = "default" end
    local d = { }
    setmetatable(d,mt)
    data[name] = d
end

function spreadsheets.start(name)
    if not name or name == "" then name = "default" end
    table.insert(stack,current)
    current = name
    if not data[current] then
        local d = { }
        setmetatable(d,mt)
        data[current] = d
    end
end

function spreadsheets.stop()
    current = table.remove(stack)
end

spreadsheets.reset()

local offset = byte("A") - 1

local function assign(s,n)
    return format("moduledata.spreadsheets.data['%s'][%s]",n,byte(s)-offset)
end

-------- datacell(name,a,b,...)
function datacell(a,b,...)
    local n = 0
    if b then
        local t = { a, b, ... }
        for i=1,#t do
            n = n * (i-1) * 26 + byte(t[i]) - offset
        end
    else
        n = byte(a) - offset
    end
 -- return format("dat['%s'][%s]",name,n)
    return format("dat[%s]",n)
end

----- cell    = (Carg(1) * C(R("AZ"))^1) / datacell * (Cc("[") * (R("09")^1) * Cc("]") + #P(1))
local cell    = C(R("AZ"))^1 / datacell * (Cc("[") * (R("09")^1) * Cc("]") + #P(1))
local pattern = Cs(Cc("return ") * (cell + P(1))^0)

local functions        = { }
spreadsheets.functions = functions

function functions.sum(c,f,t)
    if f and t then
        local r = 0
        for i=f,t do
            r = r + c[i]
        end
        return r
    else
        return 0
    end
end

function functions.fmt(pattern,n)
    return format("%"..pattern,n)
end

local template = [[
    local spr = moduledata.spreadsheets.functions
    local dat = moduledata.spreadsheets.data['%s']
    local sum = spr.sum
    local fmt = spr.fmt
    %s
]]

local function execute(name,r,c,str)
    if name == "" then name = current if name == "" then name = "default" end end
    str = lpegmatch(pattern,str,1,name)
    str = format(template,name,str)
 -- print(str)
    local result = loadstring(str)
    result = result and result() or 0
    data[name][c][r] = result
    return result
end

function spreadsheets.set(name,r,c,str)
    if name == "" then name = current if name == "" then name = "default" end end
    execute(name,r,c,str)
end

function spreadsheets.get(name,r,c,str)
    if name == "" then name = current if name == "" then name = "default" end end
    if not str or str == "" then
        context(data[name][c][r] or 0)
    else
        local result = execute(name,r,c,str)
        if result then
            if type(result) == "number" then
                data[name][c][r] = result
            end
            local numberseparator = validstring(settings.numberseparator,".")
            if numberseparator ~= "." then
                result = gsub(tostring(result),"%.",numberseparator)
            end
            context(result)
        end
    end
end

function spreadsheets.doifelsecell(name,r,c)
    if name == "" then name = current if name == "" then name = "default" end end
    local d = data[name]
    commands.testcase(d and d[c][r])
end

function spreadsheets.show(name)
    if name == "" then name = current if name == "" then name = "default" end end
    table.print(data[name],name)
end

if not modules then modules = { } end modules ['m-spreadsheet'] = {
    version   = 1.001,
    comment   = "companion to m-spreadsheet.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local byte, format, gsub = string.byte, string.format, string.gsub
local R, P, C, V, Cs, Cc, Carg, lpegmatch = lpeg.R, lpeg.P, lpeg.C, lpeg.V, lpeg.Cs, lpeg.Cc, lpeg.Carg, lpeg.match

local context = context

local splitthousands = utilities.parsers.splitthousands
local variables      = interfaces.variables

local v_yes = variables.yes

moduledata = moduledata or { }

local spreadsheets      = { }
moduledata.spreadsheets = spreadsheets

local data = {
    -- nothing yet
}

local settings = {
    period = ".",
    comma  = ",",
}

spreadsheets.data     = data
spreadsheets.settings = settings

local defaultname = "default"
local stack       = { }
local current     = defaultname

local d_mt ; d_mt = {
    __index = function(t,k)
        local v = { }
        setmetatable(v,d_mt)
        t[k] = v
        return v
    end,
}

local s_mt ; s_mt = {
    __index = function(t,k)
        local v = settings[k]
        t[k] = v
        return v
    end,
}

function spreadsheets.setup(t)
    for k, v in next, t do
        settings[k] = v
    end
end

function spreadsheets.reset(name)
    if not name or name == "" then name = defaultname end
    local d = { }
    local s = { }
    setmetatable(d,d_mt)
    setmetatable(s,s_mt)
    data[name] = {
        name     = name,
        data     = d,
        settings = s,
        temp      = { }, -- for local usage
    }
end

function spreadsheets.start(name,s)
    if not name or name == "" then name = defaultname end
    table.insert(stack,current)
    current = name
    if data[current] then
        setmetatable(s,s_mt)
        data[current].settings = s
    else
        local d = { }
        setmetatable(d,d_mt)
        setmetatable(s,s_mt)
        data[current] = {
            name     = name,
            data     = d,
            settings = s,
            temp     = { },
        }
    end
end

function spreadsheets.stop()
    current = table.remove(stack)
end

spreadsheets.reset()

local offset = byte("A") - 1

local function assign(s,n)
    return format("moduledata.spreadsheets.data['%s'].data[%s]",n,byte(s)-offset)
end

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
    return format("dat[%s]",n)
end

local cell    = C(R("AZ"))^1 / datacell * (Cc("[") * (R("09")^1) * Cc("]") + #P(1))
local pattern = Cs((cell + P(1))^0)

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
    if find(pattern,"^%%") then
        return format(pattern,n)
    else
        return format("%"..pattern,n)
    end
end

local template = [[
    local _m_ = moduledata.spreadsheets
    local dat = _m_.data['%s'].data
    local tmp = _m_.temp
    local fnc = _m_.functions
    local sum = fnc.sum
    local fmt = fnc.fmt
    return %s
]]

-- to be considered: a weak cache

local function execute(name,r,c,str)
 -- if name == "" then name = current if name == "" then name = defaultname end end
    str = lpegmatch(pattern,str,1,name)
    str = format(template,name,str)
    local result = loadstring(str)
    result = result and result() or 0
    data[name].data[c][r] = result
    if type(result) == "function" then
        return result()
    else
        return result
    end
end

function spreadsheets.set(name,r,c,str)
    if name == "" then name = current if name == "" then name = defaultname end end
    execute(name,r,c,str)
end

function spreadsheets.get(name,r,c,str)
    if name == "" then name = current if name == "" then name = defaultname end end
    local dname = data[name]
    if not str or str == "" then
        context(dname.data[c][r] or 0)
    else
        local result = execute(name,r,c,str)
        if result then
            if type(result) == "number" then
                dname.data[c][r] = result
                result = tostring(result)
            end
            local settings = dname.settings
            local split  = settings.split
            local period = settings.period
            local comma  = settings.comma
            if split == v_yes then
                result = splitthousands(result)
            end
            if period == "" then period = nil end
            if comma  == "" then comma = nil end
            result = gsub(result,".",{ ["."] = period, [","] = comma })
            context(result)
        end
    end
end

function spreadsheets.doifelsecell(name,r,c)
    if name == "" then name = current if name == "" then name = defaultname end end
    local d = data[name]
    commands.doifelse(d and d.data[c][r])
end

function spreadsheets.show(name)
    if name == "" then name = current if name == "" then name = defaultname end end
    table.print(data[name].data,name)
end

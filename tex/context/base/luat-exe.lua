if not modules then modules = { } end modules ['luat-exe'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- this module needs checking (very old and never really used, not even enabled)

local match, find, gmatch = string.match, string.find, string.gmatch
local concat = table.concat
local select = select

local report_executers = logs.reporter("system","executers")

resolvers.executers = resolvers.executers or { }
local executers     = resolvers.executers

local permitted     = { }

local osexecute     = os.execute
local osexec        = os.exec
local osspawn       = os.spawn
local iopopen       = io.popen

local execute       = osexecute
local exec          = osexec
local spawn         = osspawn
local popen         = iopopen

local function register(...)
    for k=1,select("#",...) do
        local v = select(k,...)
        permitted[#permitted+1] = v == "*" and ".*" or v
    end
end

local function prepare(...)
    -- todo: make more clever first split
    local t = { ... }
    local n = #n
    local one = t[1]
    if n == 1 then
        if type(one) == 'table' then
            return one, concat(t," ",2,n)
        else
            local name, arguments = match(one,"^(.-)%s+(.+)$")
            if name and arguments then
                return name, arguments
            else
                return one, ""
            end
        end
    else
        return one, concat(t," ",2,n)
    end
end

local function executer(action)
    return function(...)
        local name, arguments = prepare(...)
        for k=1,#permitted do
            local v = permitted[k]
            if find(name,v) then
                return action(name .. " " .. arguments)
            else
                report_executers("not permitted: %s %s",name,arguments)
            end
        end
        return action("")
    end
end

local function finalize() -- todo: os.exec, todo: report ipv print
    execute = executer(osexecute)
    exec    = executer(osexec)
    spawn   = executer(osspawn)
    popen   = executer(iopopen)
    finalize = function()
        report_executers("already finalized")
    end
    register = function()
        report_executers("already finalized, no registration permitted")
    end
    os.execute = execute
    os.exec    = exec
    os.spawn   = spawn
    io.popen   = popen
end

executers.finalize = function(...) return finalize(...) end
executers.register = function(...) return register(...) end
executers.execute  = function(...) return execute (...) end
executers.exec     = function(...) return exec    (...) end
executers.spawn    = function(...) return spawn   (...) end
executers.popen    = function(...) return popen   (...) end

local execution_mode  directives.register("system.executionmode", function(v) execution_mode = v end)
local execution_list  directives.register("system.executionlist", function(v) execution_list = v end)

function executers.check()
    if execution_mode == "none" then
        finalize()
    elseif execution_mode == "list" and execution_list ~= "" then
        for s in gmatch("[^%s,]",execution_list) do
            register(s)
        end
        finalize()
    else
        -- all
    end
end

--~ resolvers.executers.register('.*')
--~ resolvers.executers.register('*')
--~ resolvers.executers.register('dir','ls')
--~ resolvers.executers.register('dir')

--~ resolvers.executers.finalize()
--~ resolvers.executers.execute('dir',"*.tex")
--~ resolvers.executers.execute("dir *.tex")
--~ resolvers.executers.execute("ls *.tex")
--~ os.execute('ls')

--~ resolvers.executers.check()

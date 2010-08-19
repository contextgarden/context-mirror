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

local report_executers = logs.new("executers")

resolvers.executers = resolver.executers or { }
local executers     = resolvers.executers

local permitted     = { }
local osexecute     = os.execute
local execute       = osexecute

local function register(...)
    local t = { ... }
    for k=1,#t do
        local v = t[k]
        permitted[#permitted+1] = (v == "*" and ".*") or v
    end
end

local function finalize() -- todo: os.exec, todo: report ipv print
    execute = function execute(...)
        -- todo: make more clever first split
        local t, name, arguments = { ... }, "", ""
        local one = t[1]
        if #t == 1 then
            if type(one) == 'table' then
                name, arguments = one, concat(t," ",2,#t)
            else
                name, arguments = match(one,"^(.-)%s+(.+)$")
                if not (name and arguments) then
                    name, arguments = one, ""
                end
            end
        else
            name, arguments = one, concat(t," ",2,#t)
        end
        for k=1,#permitted do
            local v = permitted[k]
            if find(name,v) then
                osexecute(name .. " " .. arguments)
            --  print("executed: " .. name .. " " .. arguments)
            else
                report_executers("not permitted: %s %s",name,arguments)
            end
        end
    end
    finalize = function()
        report_executers("already finalized")
    end
    register = function()
        report_executers("already finalized, no registration permitted")
    end
    os.execute = execute
end

executers.finalize = function(...) finalize(...) end
executers.register = function(...) register(...) end
executers.execute  = function(...) execute (...) end

function executers.check()
    local mode = resolvers.variable("command_mode")
    local list = resolvers.variable("command_list")
    if mode == "none" then
        finalize()
    elseif mode == "list" and list ~= "" then
        for s in gmatch("[^%s,]",list) do
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

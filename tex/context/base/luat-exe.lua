if not modules then modules = { } end modules ['luat-exe'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local match, find = string.match, string.find
local concat = table.concat

if not executer then executer = { } end

executer.permitted = { }
executer.execute   = os.execute

function executer.register(...)
    local ep = executer.permitted
    local t = { ... }
    for k=1,#t do
        local v = t[k]
        ep[#ep+1] = (v == "*" and ".*") or v
    end
end

function executer.finalize() -- todo: os.exec, todo: report ipv print
    local execute = os.execute
    function executer.execute(...)
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
        local permitted = executer.permitted
        for k=1,#permitted do
            local v = permitted[k]
            if find(name,v) then
                execute(name .. " " .. arguments)
            --  print("executed: " .. name .. " " .. arguments)
            else
                logs.report("executer","not permitted: %s %s"name,arguments)
            end
        end
    end
    function executer.finalize()
        logs.report("executer","already finalized")
    end
    executer.register = executer.finalize
    os.execute = executer.execute
end

--~ executer.register('.*')
--~ executer.register('*')
--~ executer.register('dir','ls')
--~ executer.register('dir')

--~ executer.finalize()
--~ executer.execute('dir',"*.tex")
--~ executer.execute("dir *.tex")
--~ executer.execute("ls *.tex")
--~ os.execute('ls')

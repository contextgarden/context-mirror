-- filename : luat-exe.lua
-- comment  : companion to luat-lib.tex
-- author   : Hans Hagen, PRAGMA-ADE, Hasselt NL
-- copyright: PRAGMA ADE / ConTeXt Development Team
-- license  : see context related readme files

if not versions then versions = { } end versions['luat-exe'] = 1.001
if not executer then executer = { } end

executer.permitted = { }
executer.execute   = os.execute

function executer.register(...)
    for k,v in pairs({...}) do
        if v == "*" then
            table.insert(executer.permitted, ".*")
        else
            table.insert(executer.permitted, v)
        end
    end
end

function executer.finalize() -- todo: os.exec
    do
        local execute = os.execute
        function executer.execute(...)
            local t, name, arguments = {...}, "", ""
            if #t == 1 then
                if type(t[1]) == 'table' then
                    name, arguments = t[1], table.concat(t," ",2,#t)
                else
                    name, arguments = string.match(t[1],"^(.-)%s+(.+)$")
                    if not (name and arguments) then
                        name, arguments = t[1], ""
                    end
                end
            else
                name, arguments = t[1], table.concat(t," ",2,#t)
            end
            for _,v in pairs(executer.permitted) do
                if string.find(name,v) then
                    execute(name .. " " .. arguments)
                --  print("executed: " .. name .. " " .. arguments)
                else
                    print("not permitted: " .. name .. " " .. arguments)
                end
            end
        end
        function executer.finalize()
            print("executer is already finalized")
        end
        function executer.register(name)
            print("executer is already finalized")
        end
        os.execute = executer.execute
    end
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

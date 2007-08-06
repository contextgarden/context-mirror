-- filename : l-os.lua
-- comment  : split off from luat-lib
-- author   : Hans Hagen, PRAGMA-ADE, Hasselt NL
-- copyright: PRAGMA ADE / ConTeXt Development Team
-- license  : see context related readme files

if not versions then versions = { } end versions['l-os'] = 1.001

function os.resultof(command)
    return io.popen(command,"r"):read("*all")
end

--~ if not os.exec then -- still not ok
    os.exec = os.execute
--~ end

function os.launch(str)
    if os.platform == "windows" then
        os.execute("start " .. str)
    else
        os.execute(str .. " &")
    end
end

if not os.setenv then
    function os.setenv() return false end
end

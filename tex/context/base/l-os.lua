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

if not os.times then
    -- utime  = user time
    -- stime  = system time
    -- cutime = children user time
    -- cstime = children system time
    function os.times()
        return {
            utime  = os.clock(), -- user
            stime  = 0,          -- system
            cutime = 0,          -- children user
            cstime = 0,          -- children system
        }
    end
end

if os.gettimeofday then
    os.clock = os.gettimeofday
end

do
    local startuptime = os.gettimeofday()
    function os.runtime()
        return os.gettimeofday() - startuptime
    end
end

--~ print(os.gettimeofday()-os.time())
--~ os.sleep(1.234)
--~ print (">>",os.runtime())
--~ print(os.date("%H:%M:%S",os.gettimeofday()))
--~ print(os.date("%H:%M:%S",os.time()))

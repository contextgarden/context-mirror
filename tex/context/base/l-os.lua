if not modules then modules = { } end modules ['l-os'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local find = string.find

function os.resultof(command)
    return io.popen(command,"r"):read("*all")
end

if not os.exec  then os.exec  = os.execute end
if not os.spawn then os.spawn = os.execute end

--~ os.type : windows | unix (new, we already guessed os.platform)
--~ os.name : windows | msdos | linux | macosx | solaris | .. | generic (new)

if not io.fileseparator then
    if find(os.getenv("PATH"),";") then
        io.fileseparator, io.pathseparator, os.platform = "\\", ";", os.type or "windows"
    else
        io.fileseparator, io.pathseparator, os.platform = "/" , ":", os.type or "unix"
    end
end

os.platform = os.platform or os.type or (io.pathseparator == ";" and "windows") or "unix"

function os.launch(str)
    if os.platform == "windows" then
        os.execute("start " .. str) -- os.spawn ?
    else
        os.execute(str .. " &")     -- os.spawn ?
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
            utime  = os.gettimeofday(), -- user
            stime  = 0,                 -- system
            cutime = 0,                 -- children user
            cstime = 0,                 -- children system
        }
    end
end

os.gettimeofday = os.gettimeofday or os.clock

local startuptime = os.gettimeofday()

function os.runtime()
    return os.gettimeofday() - startuptime
end

--~ print(os.gettimeofday()-os.time())
--~ os.sleep(1.234)
--~ print (">>",os.runtime())
--~ print(os.date("%H:%M:%S",os.gettimeofday()))
--~ print(os.date("%H:%M:%S",os.time()))

os.arch = os.arch or function()
    local a = os.resultof("uname -m") or "linux"
    os.arch = function()
        return a
    end
    return a
end

local platform

function os.currentplatform(name,default)
    if not platform then
        local name = os.name or os.platform or name -- os.name is built in, os.platform is mine
        if not name then
            platform = default or "linux"
        elseif name == "windows" or name == "mswin" or name == "win32" or name == "msdos" then
            if os.getenv("PROCESSOR_ARCHITECTURE") == "AMD64" then
                platform = "mswin-64"
            else
                platform = "mswin"
            end
        else
            local architecture = os.arch()
            if name == "linux" then
                if find(architecture,"x86_64") then
                    platform = "linux-64"
                elseif find(architecture,"ppc") then
                    platform = "linux-ppc"
                else
                    platform = "linux"
                end
            elseif name == "macosx" then
                if find(architecture,"i386") then
                    platform = "osx-intel"
                else
                    platform = "osx-ppc"
                end
            elseif name == "sunos" then
                if find(architecture,"sparc") then
                    platform = "solaris-sparc"
                else -- if architecture == 'i86pc'
                    platform = "solaris-intel"
                end
            elseif name == "freebsd" then
                if find(architecture,"amd64") then
                    platform = "freebsd-amd64"
                else
                    platform = "freebsd"
                end
            else
                platform = default or name
            end
        end
        function os.currentplatform()
            return platform
        end
    end
    return platform
end

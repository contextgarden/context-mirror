if not modules then modules = { } end modules ['l-os'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- This file deals with some operating system issues. Please don't bother me
-- with the pros and cons of operating systems as they all have their flaws
-- and benefits. Bashing one of them won't help solving problems and fixing
-- bugs faster and is a waste of time and energy.
--
-- path separators: / or \ ... we can use / everywhere
-- suffixes       : dll so exe <none> ... no big deal
-- quotes         : we can use "" in most cases
-- expansion      : unless "" are used * might give side effects
-- piping/threads : somewhat different for each os
-- locations      : specific user file locations and settings can change over time
--
-- os.type     : windows | unix (new, we already guessed os.platform)
-- os.name     : windows | msdos | linux | macosx | solaris | .. | generic (new)
-- os.platform : extended os.name with architecture

-- os.sleep() => socket.sleep()
-- math.randomseed(tonumber(string.sub(string.reverse(tostring(math.floor(socket.gettime()*10000))),1,6)))

-- maybe build io.flush in os.execute

local os = os
local date, time = os.date, os.time
local find, format, gsub, upper, gmatch = string.find, string.format, string.gsub, string.upper, string.gmatch
local concat = table.concat
local random, ceil, randomseed = math.random, math.ceil, math.randomseed
local rawget, rawset, type, getmetatable, setmetatable, tonumber, tostring = rawget, rawset, type, getmetatable, setmetatable, tonumber, tostring

-- The following code permits traversing the environment table, at least
-- in luatex. Internally all environment names are uppercase.

-- The randomseed in Lua is not that random, although this depends on the operating system as well
-- as the binary (Luatex is normally okay). But to be sure we set the seed anyway.

math.initialseed = tonumber(string.sub(string.reverse(tostring(ceil(socket and socket.gettime()*10000 or time()))),1,6))

randomseed(math.initialseed)

if not os.__getenv__ then

    os.__getenv__ = os.getenv
    os.__setenv__ = os.setenv

    if os.env then

        local osgetenv  = os.getenv
        local ossetenv  = os.setenv
        local osenv     = os.env      local _ = osenv.PATH -- initialize the table

        function os.setenv(k,v)
            if v == nil then
                v = ""
            end
            local K = upper(k)
            osenv[K] = v
            if type(v) == "table" then
                v = concat(v,";") -- path
            end
            ossetenv(K,v)
        end

        function os.getenv(k)
            local K = upper(k)
            local v = osenv[K] or osenv[k] or osgetenv(K) or osgetenv(k)
            if v == "" then
                return nil
            else
                return v
            end
        end

    else

        local ossetenv  = os.setenv
        local osgetenv  = os.getenv
        local osenv     = { }

        function os.setenv(k,v)
            if v == nil then
                v = ""
            end
            local K = upper(k)
            osenv[K] = v
        end

        function os.getenv(k)
            local K = upper(k)
            local v = osenv[K] or osgetenv(K) or osgetenv(k)
            if v == "" then
                return nil
            else
                return v
            end
        end

        local function __index(t,k)
            return os.getenv(k)
        end
        local function __newindex(t,k,v)
            os.setenv(k,v)
        end

        os.env = { }

        setmetatable(os.env, { __index = __index, __newindex = __newindex } )

    end

end

-- end of environment hack

local execute, spawn, exec, iopopen, ioflush = os.execute, os.spawn or os.execute, os.exec or os.execute, io.popen, io.flush

function os.execute(...) ioflush() return execute(...) end
function os.spawn  (...) ioflush() return spawn  (...) end
function os.exec   (...) ioflush() return exec   (...) end
function io.popen  (...) ioflush() return iopopen(...) end

function os.resultof(command)
    local handle = io.popen(command,"r")
    return handle and handle:read("*all") or ""
end

if not io.fileseparator then
    if find(os.getenv("PATH"),";") then
        io.fileseparator, io.pathseparator, os.type = "\\", ";", os.type or "mswin"
    else
        io.fileseparator, io.pathseparator, os.type = "/" , ":", os.type or "unix"
    end
end

os.type = os.type or (io.pathseparator == ";"       and "windows") or "unix"
os.name = os.name or (os.type          == "windows" and "mswin"  ) or "linux"

if os.type == "windows" then
    os.libsuffix, os.binsuffix, os.binsuffixes = 'dll', 'exe', { 'exe', 'cmd', 'bat' }
else
    os.libsuffix, os.binsuffix, os.binsuffixes = 'so', '', { '' }
end

local launchers = {
    windows = "start %s",
    macosx  = "open %s",
    unix    = "$BROWSER %s &> /dev/null &",
}

function os.launch(str)
    os.execute(format(launchers[os.name] or launchers.unix,str))
end

if not os.times then -- ?
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

-- no need for function anymore as we have more clever code and helpers now
-- this metatable trickery might as well disappear

os.resolvers = os.resolvers or { } -- will become private

local resolvers = os.resolvers

setmetatable(os, { __index = function(t,k)
    local r = resolvers[k]
    return r and r(t,k) or nil -- no memoize
end })

-- we can use HOSTTYPE on some platforms

local name, platform = os.name or "linux", os.getenv("MTX_PLATFORM") or ""

local function guess()
    local architecture = os.resultof("uname -m") or ""
    if architecture ~= "" then
        return architecture
    end
    architecture = os.getenv("HOSTTYPE") or ""
    if architecture ~= "" then
        return architecture
    end
    return os.resultof("echo $HOSTTYPE") or ""
end

if platform ~= "" then

    os.platform = platform

elseif os.type == "windows" then

    -- we could set the variable directly, no function needed here

    function os.resolvers.platform(t,k)
        local platform, architecture = "", os.getenv("PROCESSOR_ARCHITECTURE") or ""
        if find(architecture,"AMD64") then
            platform = "mswin-64"
        else
            platform = "mswin"
        end
        os.setenv("MTX_PLATFORM",platform)
        os.platform = platform
        return platform
    end

elseif name == "linux" then

    function os.resolvers.platform(t,k)
        -- we sometimes have HOSTTYPE set so let's check that first
        local platform, architecture = "", os.getenv("HOSTTYPE") or os.resultof("uname -m") or ""
        if find(architecture,"x86_64") then
            platform = "linux-64"
        elseif find(architecture,"ppc") then
            platform = "linux-ppc"
        else
            platform = "linux"
        end
        os.setenv("MTX_PLATFORM",platform)
        os.platform = platform
        return platform
    end

elseif name == "macosx" then

    --[[
        Identifying the architecture of OSX is quite a mess and this
        is the best we can come up with. For some reason $HOSTTYPE is
        a kind of pseudo environment variable, not known to the current
        environment. And yes, uname cannot be trusted either, so there
        is a change that you end up with a 32 bit run on a 64 bit system.
        Also, some proper 64 bit intel macs are too cheap (low-end) and
        therefore not permitted to run the 64 bit kernel.
      ]]--

    function os.resolvers.platform(t,k)
     -- local platform, architecture = "", os.getenv("HOSTTYPE") or ""
     -- if architecture == "" then
     --     architecture = os.resultof("echo $HOSTTYPE") or ""
     -- end
        local platform, architecture = "", os.resultof("echo $HOSTTYPE") or ""
        if architecture == "" then
         -- print("\nI have no clue what kind of OSX you're running so let's assume an 32 bit intel.\n")
            platform = "osx-intel"
        elseif find(architecture,"i386") then
            platform = "osx-intel"
        elseif find(architecture,"x86_64") then
            platform = "osx-64"
        else
            platform = "osx-ppc"
        end
        os.setenv("MTX_PLATFORM",platform)
        os.platform = platform
        return platform
    end

elseif name == "sunos" then

    function os.resolvers.platform(t,k)
        local platform, architecture = "", os.resultof("uname -m") or ""
        if find(architecture,"sparc") then
            platform = "solaris-sparc"
        else -- if architecture == 'i86pc'
            platform = "solaris-intel"
        end
        os.setenv("MTX_PLATFORM",platform)
        os.platform = platform
        return platform
    end

elseif name == "freebsd" then

    function os.resolvers.platform(t,k)
        local platform, architecture = "", os.resultof("uname -m") or ""
        if find(architecture,"amd64") then
            platform = "freebsd-amd64"
        else
            platform = "freebsd"
        end
        os.setenv("MTX_PLATFORM",platform)
        os.platform = platform
        return platform
    end

elseif name == "kfreebsd" then

    function os.resolvers.platform(t,k)
        -- we sometimes have HOSTTYPE set so let's check that first
        local platform, architecture = "", os.getenv("HOSTTYPE") or os.resultof("uname -m") or ""
        if find(architecture,"x86_64") then
            platform = "kfreebsd-amd64"
        else
            platform = "kfreebsd-i386"
        end
        os.setenv("MTX_PLATFORM",platform)
        os.platform = platform
        return platform
    end

else

    -- platform = "linux"
    -- os.setenv("MTX_PLATFORM",platform)
    -- os.platform = platform

    function os.resolvers.platform(t,k)
        local platform = "linux"
        os.setenv("MTX_PLATFORM",platform)
        os.platform = platform
        return platform
    end

end

-- beware, we set the randomseed

-- from wikipedia: Version 4 UUIDs use a scheme relying only on random numbers. This algorithm sets the
-- version number as well as two reserved bits. All other bits are set using a random or pseudorandom
-- data source. Version 4 UUIDs have the form xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx with hexadecimal
-- digits x and hexadecimal digits 8, 9, A, or B for y. e.g. f47ac10b-58cc-4372-a567-0e02b2c3d479.
--
-- as we don't call this function too often there is not so much risk on repetition

local t = { 8, 9, "a", "b" }

function os.uuid()
    return format("%04x%04x-4%03x-%s%03x-%04x-%04x%04x%04x",
        random(0xFFFF),random(0xFFFF),
        random(0x0FFF),
        t[ceil(random(4))] or 8,random(0x0FFF),
        random(0xFFFF),
        random(0xFFFF),random(0xFFFF),random(0xFFFF)
    )
end

local d

function os.timezone(delta)
    d = d or tonumber(tonumber(date("%H")-date("!%H")))
    if delta then
        if d > 0 then
            return format("+%02i:00",d)
        else
            return format("-%02i:00",-d)
        end
    else
        return 1
    end
end

local timeformat = format("%%s%s",os.timezone(true))
local dateformat = "!%Y-%m-%d %H:%M:%S"

function os.fulltime(t,default)
    t = tonumber(t) or 0
    if t > 0 then
        -- valid time
    elseif default then
        return default
    else
        t = nil
    end
    return format(timeformat,date(dateformat,t))
end

local dateformat = "%Y-%m-%d %H:%M:%S"

function os.localtime(t,default)
    t = tonumber(t) or 0
    if t > 0 then
        -- valid time
    elseif default then
        return default
    else
        t = nil
    end
    return date(dateformat,t)
end

function os.converttime(t,default)
    local t = tonumber(t)
    if t and t > 0 then
        return date(dateformat,t)
    else
        return default or "-"
    end
end

local memory = { }

local function which(filename)
    local fullname = memory[filename]
    if fullname == nil then
        local suffix = file.suffix(filename)
        local suffixes = suffix == "" and os.binsuffixes or { suffix }
        for directory in gmatch(os.getenv("PATH"),"[^" .. io.pathseparator .."]+") do
            local df = file.join(directory,filename)
            for i=1,#suffixes do
                local dfs = file.addsuffix(df,suffixes[i])
                if io.exists(dfs) then
                    fullname = dfs
                    break
                end
            end
        end
        if not fullname then
            fullname = false
        end
        memory[filename] = fullname
    end
    return fullname
end

os.which = which
os.where = which

function os.today()
    return date("!*t") -- table with values
end

function os.now()
    return date("!%Y-%m-%d %H:%M:%S") -- 2011-12-04 14:59:12
end

if not os.sleep and socket then
    os.sleep = socket.sleep
end

-- print(os.which("inkscape.exe"))
-- print(os.which("inkscape"))
-- print(os.which("gs.exe"))
-- print(os.which("ps2pdf"))

if not modules then modules = { } end modules ['util-lib'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files",
}

-- This is experimental code for Hans and Luigi. Don't depend on it! There
-- will be a plain variant.

--[[

The problem with library bindings is manyfold. They are of course platform
dependent and while a binary with its directly related libraries are often
easy to maintain and load, additional libraries can each have their demands.

One important aspect is that loading additional libraries from within the
loaded one is also operating system dependent. There can be shared libraries
elsewhere on the system and as there can be multiple libraries with the same
name but different usage and versioning there can be clashes. So there has to
be some logic in where to look for these sublibraries.

We found out that for instance on windows libraries are by default sought on
the parents path and then on the binary paths and these of course can be in
an out of our control, thereby enlarging the changes on a clash. A rather
safe solution for that to load the library on the path where it sits.

Another aspect is initialization. When you ask for a library t.e.x it will
try to initialize luaopen_t_e_x no matter if such an inializer is present.
However, because loading is configurable and in the case of luatex is already
partly under out control, this is easy to deal with. We only have to make
sure that we inform the loader that the library has been loaded so that
it won't load it twice.

In swiglib we have chosen for a clear organization and although one can use
variants normally in the tex directory structure predictability is more or
less the standard. For instance:

..../tex/texmf-mswin/bin/swiglib/gmwand

]]--

local savedrequire = require
local loaded = package.loaded
local gsub, find = string.gsub, string.find

--[[

A request for t.e.x is converted to t/e/x.dll or t/e/x.so depending on the
platform. Then we use the regular finder to locate the file in the tex
directory structure. Once located we goto the path where it sits, load the
file and return to the original path. We register as t.e.x in order to
prevent reloading and also because the base name is seldom unique.

]]--

local function requireswiglib(required)
    local library = loaded[required]
    if not library then
        local name = gsub(required,"%.","/") .. "." .. os.libsuffix
        local full = resolvers.findfile(name,"lib")
   --   local full = resolvers.findfile(name)
        if not full or full == "" then
            -- We can consider alternatives but we cannot load yet ... I
            -- need to extent l-lua with a helper if we really want that.
            --
            -- package.helpers.trace = true
            -- package.extraclibpath(environment.ownpath)
        end
        local path = file.pathpart(full)
        local base = file.nameonly(full)
        dir.push(path)
     -- if false then
     --     local savedlibrary = loaded[base]
     --     library = savedrequire(base)
     --     loaded[base] = savedlibrary
     -- else
            library = package.loadlib(full,"luaopen_" .. base)
            if type(library) == "function" then
                library = library()
            else
                -- some error
            end
     -- end
        dir.pop()
        loaded[required] = library
    end
    return library
end

--[[

For convenience we make the require loader function swiglib aware. Alternatively
we could put the specific loader in the global namespace.

]]--

function require(name,...) -- this might disappear or change
    if find(name,"^swiglib%.") then
        return requireswiglib(name,...)
    else
        return savedrequire(name,...)
    end
end

--[[

At the cost of some overhead we provide a specific loader so that we can keep
track of swiglib usage which is handy for development.

]]--

local report_swiglib = logs.reporter("swiglib")

local swiglibs = { }

function swiglib(name)
    local library = swiglibs[name]
    if not library then
        statistics.starttiming(swiglibs)
        report_swiglib("loading %a",name)
        library = requireswiglib("swiglib." .. name)
        swiglibs[name] = library
        statistics.stoptiming(swiglibs)
    end
    return library
end

statistics.register("used swiglibs", function()
    if next(swiglibs) then
        return string.format("%s, initial load time %s seconds",table.concat(table.sortedkeys(swiglibs)," "),statistics.elapsedtime(swiglibs))
    end
end)

--[[

So, we now have:

----- gm = requireswiglib("swiglib.gmwand.core") -- most bare method (not public in context)
local gm = require("swiglib.gmwand.core")        -- nicer integrated (maybe not in context)
local gm = swiglib("gmwand.core")                -- the context way

Watch out, the last one is less explicit and lacks the swiglib prefix.

]]--

if not modules then modules = { } end modules ['util-lua'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

utilities        = utilities or {}
utilities.lua    = utilities.lua or { }
utilities.report = utilities.report or print

function utilities.lua.compile(luafile,lucfile,cleanup,strip) -- defaults: cleanup=false strip=true
    utilities.report("lua: compiling %s into %s",luafile,lucfile)
    os.remove(lucfile)
    local command = "-o " .. string.quoted(lucfile) .. " " .. string.quoted(luafile)
    if strip ~= false then
        command = "-s " .. command
    end
    local done = os.spawn("texluac " .. command) == 0 or os.spawn("luac " .. command) == 0
    if done and cleanup == true and lfs.isfile(lucfile) and lfs.isfile(luafile) then
        utilities.report("lua: removing %s",luafile)
        os.remove(luafile)
    end
    return done
end

--~ local getmetatable, type = getmetatable, type

--~ local types = { }

--~ function utilities.lua.registerdatatype(d,name)
--~     types[getmetatable(d)] = name
--~ end

--~ function utilities.lua.datatype(d)
--~     local t = type(d)
--~     if t == "userdata" then
--~         local m = getmetatable(d)
--~         return m and types[m] or "userdata"
--~     else
--~         return t
--~     end
--~ end

--~ utilities.lua.registerdatatype(lpeg.P("!"),"lpeg")

--~ print(utilities.lua.datatype(lpeg.P("oeps")))

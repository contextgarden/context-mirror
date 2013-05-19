if not modules then modules = { } end modules ['luat-iop'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- this paranoid stuff in web2c ... we cannot hook checks into the
-- input functions because one can always change the callback but
-- we can feed back specific patterns and paths into the next
-- mechanism

-- os.execute os.exec os.spawn io.fopen
-- os.remove lfs.chdir lfs.mkdir
-- io.open zip.open epdf.open mlib.new

-- cache

local topattern, find = string.topattern, string.find

local report_limiter = logs.reporter("system","limiter")

-- the basic methods

local function match(ruleset,name)
    local n = #ruleset
    if n > 0 then
        for i=1,n do
            local r = ruleset[i]
            if find(name,r[1]) then
                return r[2]
            end
        end
        return false
    else
        -- nothing defined (or any)
        return true
    end
end

local function protect(ruleset,proc)
    return function(name,...)
        if name == "" then
         -- report_limiter("no access permitted: <no name>") -- can happen in mplib code
            return nil, "no name given"
        elseif match(ruleset,name) then
            return proc(name,...)
        else
            report_limiter("no access permitted for %a",name)
            return nil, name .. ": no access permitted"
        end
    end
end

function io.limiter(preset)
    preset = preset or { }
    local ruleset = { }
    for i=1,#preset do
        local p = preset[i]
        local what, spec = p[1] or "", p[2] or ""
        if spec == "" then
            -- skip 'm
        elseif what == "tree" then
            resolvers.dowithpath(spec, function(r)
                local spec = resolvers.resolve(r) or ""
                if spec ~= "" then
                    ruleset[#ruleset+1] = { topattern(spec,true), true }
                end
            end)
        elseif what == "permit" then
            ruleset[#ruleset+1] = { topattern(spec,true), true }
        elseif what == "forbid" then
            ruleset[#ruleset+1] = { topattern(spec,true), false }
        end
    end
    if #ruleset > 0 then
        return {
            match   = function(name) return match  (ruleset,name) end,
            protect = function(proc) return protect(ruleset,proc) end,
        }
    else
        return {
            match   = function(name) return true end,
            protect = proc,
        }
    end
end

-- a few handlers

io.i_limiters = { }
io.o_limiters = { }

function io.i_limiter(v)
    local i = io.i_limiters[v]
    if i then
        local i_limiter = io.limiter(i)
        function io.i_limiter()
            return i_limiter
        end
        return i_limiter
    end
end

function io.o_limiter(v)
    local o = io.o_limiters[v]
    if o then
        local o_limiter = io.limiter(o)
        function io.o_limiter()
            return o_limiter
        end
        return o_limiter
    end
end

-- the real thing (somewhat fuzzy as we need to know what gets done)

local i_opener, i_limited = io.open, false
local o_opener, o_limited = io.open, false

local function i_register(v)
    if not i_limited then
        local i_limiter = io.i_limiter(v)
        if i_limiter then
            local protect = i_limiter.protect
            i_opener = protect(i_opener)
            i_limited = true
            report_limiter("input mode set to %a",v)
        end
    end
end

local function o_register(v)
    if not o_limited then
        local o_limiter = io.o_limiter(v)
        if o_limiter then
            local protect = o_limiter.protect
            o_opener = protect(o_opener)
            o_limited = true
            report_limiter("output mode set to %a",v)
        end
    end
end

function io.open(name,method)
    if method and find(method,"[wa]") then
        return o_opener(name,method)
    else
        return i_opener(name,method)
    end
end

directives.register("system.inputmode",  i_register)
directives.register("system.outputmode", o_register)

local i_limited = false
local o_limited = false

local function i_register(v)
    if not i_limited then
        local i_limiter = io.i_limiter(v)
        if i_limiter then
            local protect = i_limiter.protect
            lfs.chdir = protect(lfs.chdir) -- needs checking
            i_limited = true
        end
    end
end

local function o_register(v)
    if not o_limited then
        local o_limiter = io.o_limiter(v)
        if o_limiter then
            local protect = o_limiter.protect
            os.remove = protect(os.remove) -- rather okay
            lfs.chdir = protect(lfs.chdir) -- needs checking
            lfs.mkdir = protect(lfs.mkdir) -- needs checking
            o_limited = true
        end
    end
end

directives.register("system.inputmode",  i_register)
directives.register("system.outputmode", o_register)

-- the definitions

local limiters = resolvers.variable("limiters")

if limiters then
    io.i_limiters = limiters.input  or { }
    io.o_limiters = limiters.output or { }
end


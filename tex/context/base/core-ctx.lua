if not modules then modules = { } end modules ['core-ctx'] = {
    version   = 1.001,
    comment   = "companion to core-ctx.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local trace_prepfiles = false  trackers.register("resolvers.prepfiles", function(v) trace_prepfiles = v end)

commands = commands or { }

local list, suffix, islocal, found = { }, "prep", false, false

function commands.loadctxpreplist()
    local ctlname = file.replacesuffix(tex.jobname,"ctl")
    if lfs.isfile(ctlname) then
        local x = xml.load(ctlname)
        if x then
            islocal = xml.found(x,"ctx:preplist[@local=='yes']")
--~             if trace_prepfiles then
                if islocal then
                    commands.writestatus("systems","loading ctx log file (local)") -- todo: m!systems
                else
                    commands.writestatus("systems","loading ctx log file (specified)") -- todo: m!systems
                end
--~             end
            for e in xml.collected(x,"ctx:prepfile") do
                local name = xml.text(e)
                if islocal then
                    name = file.basename(name)
                end
                local done = e.at['done'] or 'no'
                if trace_prepfiles then
                    commands.writestatus("systems","registering %s -> %s",done)
                end
                found = true
                list[name] = done -- 'yes' or 'no'
            end
        end
    end
end

-- -- --

local function found(name) -- used in resolve
    local prepname = name .. "." .. suffix
    if list[name] and lfs.isfile(prepname) then
        if trace_prepfiles then
            commands.writestatus("systems", "preprocessing: using %s",prepname)
        end
        return prepname
    end
    return false
end

local function resolve(name) -- used a few times later on
    local filename = file.collapse_path(name)
    local prepname = islocal and found(file.basename(name))
    if prepname then
        return prepname
    end
    prepname = found(filename)
    if prepname then
        return prepname
    end
    return false
end

--~ support.doiffileexistelse(name)

local processfile       = commands.processfile
local doifinputfileelse = commands.doifinputfileelse

function commands.processfile(name,maxreadlevel) -- overloaded
    local prepname = found and resolve(name)
    if prepname then
        return processfile(prepname,0)
    end
    return processfile(name,maxreadlevel)
end

function commands.doifinputfileelse(name,depth)
    local prepname = found and resolve(name)
    if prepname then
        return doifinputfileelse(prepname,0)
    end
    return doifinputfileelse(name,depth)
end

function commands.preparedfile(name)
    return (found and resolve(name)) or name
end

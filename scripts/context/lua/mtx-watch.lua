if not modules then modules = { } end modules ['mtx-watch'] = {
    version   = 1.001,
    comment   = "companion to mtxrun.lua",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

scripts       = scripts       or { }
scripts.watch = scripts.watch or { }

local format, concat, difftime, time = string.format, table.concat, os.difftime, os.time
local pairs, ipairs, next, type = pairs, ipairs, next, type

function scripts.watch.save_exa_modes(joblog,ctmname)
    if joblog then
        local t= { }
        t[#t+1] = "<?xml version='1.0' standalone='yes'?>\n"
        t[#t+1] = "<exa:variables xmlns:exa='htpp://www.pragma-ade.com/schemas/exa-variables.rng'>"
        if joblog.values then
            for k, v in pairs(joblog.values) do
                t[#t+1] = format("\t<exa:variable label='%s'>%s</exa:variable>", k, tostring(v))
            end
        else
            t[#t+1] = "<!-- no modes -->"
        end
        t[#t+1] = "</exa:variables>"
        io.savedata(ctmname,concat(t,"\n"))
    else
        os.remove(ctmname)
    end
end

local function toset(t)
    if type(t) == "table" then
        return concat(t,",")
    else
        return t
    end
end

local function noset(t)
    if type(t) == "table" then
        return t[1]
    else
        return t
    end
end

local lfsdir, lfsattributes = lfs.dir, lfs.attributes

local function glob(files,path)
    for name in lfsdir(path) do
        if name:find("^%.") then
            -- skip . and ..
        else
            name = path .. "/" .. name
            local a = lfsattributes(name)
            if not a then
                -- weird
            elseif a.mode == "directory" then
                if name:find("graphics$") or name:find("figures$") or name:find("resources$") then
                    -- skip these too
                else
                    glob(files,name)
                end
            elseif name:find(".%luj$") then
                files[name] = a.change or a.ctime or a.modification or a.mtime
            end
        end
    end
end

local clock = os.gettimeofday or os.time -- we cannot trust os.clock on linux

function scripts.watch.watch()
    local delay   = tonumber(environment.argument("delay") or 5) or 5
    if delay == 0 then
        delay = .25
    end
    local logpath = environment.argument("logpath") or ""
    local pipe    = environment.argument("pipe")    or false
    local watcher = "mtxwatch.run"
    if #environment.files > 0 then
        for _, path in ipairs(environment.files) do
            logs.report("watch", "watching path ".. path)
        end
        local function process()
            local done = false
            for _, path in ipairs(environment.files) do
                lfs.chdir(path)
                local files = { }
                glob(files,path)
                table.sort(files) -- what gets sorted here, todo: by time
                for name, time in pairs(files) do
                --~ local ok, joblog = xpcall(function() return dofile(name) end, function() end )
                    local ok, joblog = pcall(dofile,name)
                    if ok and joblog then
                        if joblog.status == "processing" then
                            logs.report("watch",format("aborted job, %s added to queue",name))
                            joblog.status = "queued"
                            io.savedata(name, table.serialize(joblog,true))
                        elseif joblog.status == "queued" then
                            local command = joblog.command
                            if command then
                                local replacements = {
                                    inputpath  = toset((joblog.paths and joblog.paths.input ) or "."),
                                    outputpath = noset((joblog.paths and joblog.paths.output) or "."),
                                    filename   = joblog.filename or "",
                                }
                                -- todo: revision path etc
                                command = command:gsub("%%(.-)%%", replacements)
                                if command ~= "" then
                                    joblog.status = "processing"
                                    joblog.runtime = clock()
                                    io.savedata(name, table.serialize(joblog,true))
                                    logs.report("watch",format("running: %s", command))
                                    local newpath = file.dirname(name)
                                    io.flush()
                                    local result = ""
                                    local ctmname = file.basename(replacements.filename)
                                    if ctmname == "" then ctmname = name end -- use self as fallback
                                    ctmname = file.replacesuffix(ctmname,"ctm")
                                    if newpath ~= "" and newpath ~= "." then
                                        local oldpath = lfs.currentdir()
                                        lfs.chdir(newpath)
                                        scripts.watch.save_exa_modes(joblog,ctmname)
                                        if pipe then result = os.resultof(command) else result = os.spawn(command) end
                                        lfs.chdir(oldpath)
                                    else
                                        scripts.watch.save_exa_modes(joblog,ctmname)
                                        if pipe then result = os.resultof(command) else result = os.spawn(command) end
                                    end
                                    logs.report("watch",format("return value: %s", result))
                                    done = true
                                    local path, base = replacements.outputpath, file.basename(replacements.filename)
                                    joblog.runtime = clock() - joblog.runtime
                                    if base ~= "" then
                                        joblog.result  = file.replacesuffix(file.join(path,base),"pdf")
                                        joblog.size    = lfs.attributes(joblog.result,"size")
                                    end
                                    joblog.status  = "finished"
                                else
                                    joblog.status = "invalid command"
                                end
                            else
                                joblog.status = "no command"
                            end
                            -- pcall, when error sleep + again
                            io.savedata(name, table.serialize(joblog,true))
                            if logpath ~= "" then
                                local name = os.uuid() .. ".lua"
                                io.savedata(name, table.serialize(joblog,true))
                                logs.report("watch", "saving joblog ".. name)
                            end
                        end
                    end
                end
            end
        end
        local n, start = 0, time()
--~         local function wait()
--~             io.flush()
--~             if not done then
--~                 n = n + 1
--~                 if n >= 10 then
--~                     logs.report("watch", format("run time: %i seconds, memory usage: %0.3g MB", difftime(time(),start), (status.luastate_bytes/1024)/1000))
--~                     n = 0
--~                 end
--~                 os.sleep(delay)
--~             end
--~         end
        local wtime = 0
        local function wait()
            io.flush()
            if not done then
                n = n + 1
                if n >= 10 then
                    logs.report("watch", format("run time: %i seconds, memory usage: %0.3g MB", difftime(time(),start), (status.luastate_bytes/1024)/1000))
                    n = 0
                end
                local ttime = 0
                while ttime <= delay do
                    local wt = lfs.attributes(watcher,"mtime")
                    if wt and wt ~= wtime then
                        -- fast signal that there is a request
                        wtime = wt
                        break
                    end
                    ttime = ttime + 0.2
                    os.sleep(0.2)
                end
            end
        end
        local cleanupdelay, cleanup = environment.argument("cleanup"), false
        if cleanupdelay then
            local lasttime = time()
            cleanup = function()
                local currenttime = time()
                local delta = difftime(currenttime,lasttime)
                if delta > cleanupdelay then
                    lasttime = currenttime
                    for _, path in ipairs(environment.files) do
                        if string.find(path,"%.") then
                            -- safeguard, we want a fully qualified path
                        else
                            local files = dir.glob(file.join(path,"*"))
                            for _, name in ipairs(files) do
                                local filetime = lfs.attributes(name,"modification")
                                local delta = difftime(currenttime,filetime)
                                if delta > cleanupdelay then
                                 -- logs.report("watch",format("cleaning up '%s'",name))
                                    os.remove(name)
                                end
                            end
                        end
                    end
                end
            end
        else
            cleanup = function()
                -- nothing
            end
        end
        while true do
            if false then
--~             if true then
                process()
                cleanup()
                wait()
            else
                pcall(process)
                pcall(cleanup)
                pcall(wait)
            end
        end
    else
        logs.report("watch", "no paths to watch")
    end
end

function scripts.watch.collect_logs(path) -- clean 'm up too
    path = path or environment.argument("logpath") or ""
    path = (path == "" and ".") or path
    local files = dir.globfiles(path,false,"^%d+%.lua$")
    local collection = { }
    local valid = table.tohash({"filename","result","runtime","size","status"})
    for _, name in ipairs(files) do
        local t = dofile(name)
        if t and type(t) == "table" and t.status then
            for k, v in pairs(t) do
                if not valid[k] then
                    t[k] = nil
                end
            end
            collection[name:gsub("[^%d]","")] = t
        end
    end
    return collection
end

function scripts.watch.save_logs(collection,path) -- play safe
    if collection and not table.is_empty(collection) then
        path = path or environment.argument("logpath") or ""
        path = (path == "" and ".") or path
        local filename = format("%s/collected-%s.lua",path,tostring(time()))
        io.savedata(filename,table.serialize(collection,true))
        local check = dofile(filename)
        for k,v in pairs(check) do
            if not collection[k] then
                logs.error("watch", "error in saving file")
                os.remove(filename)
                return false
            end
        end
        for k,v in pairs(check) do
            os.remove(format("%s.lua",k))
        end
        return true
    else
        return false
    end
end

function scripts.watch.collect_collections(path) -- removes duplicates
    path = path or environment.argument("logpath") or ""
    path = (path == "" and ".") or path
    local files = dir.globfiles(path,false,"^collected%-%d+%.lua$")
    local collection = { }
    for _, name in ipairs(files) do
        local t = dofile(name)
        if t and type(t) == "table" then
            for k, v in pairs(t) do
                collection[k] = v
            end
        end
    end
    return collection
end

function scripts.watch.show_logs(path) -- removes duplicates
    local collection = scripts.watch.collect_collections(path) or { }
    local max = 0
    for k,v in pairs(collection) do
        v = v.filename or "?"
        if #v > max then max = #v end
    end
    print(max)
    for k,v in ipairs(table.sortedkeys(collection)) do
        local c = collection[v]
        local f, s, r, n = c.filename or "?", c.status or "?", c.runtime or 0, c.size or 0
        logs.report("watch", format("%s  %s  %3i  %8i  %s",string.padd(f,max," "),string.padd(s,10," "),r,n,v))
    end
end

function scripts.watch.cleanup_stale_files() -- removes duplicates
    local path  = environment.files[1]
    local delay = tonumber(environment.argument("cleanup"))
    local force = environment.argument("force")
    if not path or path == "." then
        logs.report("watch","provide qualified path")
    elseif not delay then
        logs.report("watch","missing --cleanup=delay")
    else
        logs.report("watch","dryrun, use --force for real cleanup")
        local files = dir.glob(file.join(path,"*"))
        local rtime = time()
        for _, name in ipairs(files) do
            local mtime = lfs.attributes(name,"modification")
            local delta = difftime(rtime,mtime)
            if delta > delay then
                logs.report("watch",format("cleaning up '%s'",name))
                if force then
                    os.remove(name)
                end
            end
        end
    end
end

logs.extendbanner("ConTeXt Request Watchdog 1.00",true)

messages.help = [[
--logpath             optional path for log files
--watch               watch given path [--delay]
--pipe                use pipe instead of execute
--delay               delay between sweeps
--collect             condense log files
--cleanup=delay       remove files in given path [--force]
--showlog             show log data
]]

if environment.argument("watch") then
    scripts.watch.watch()
elseif environment.argument("collect") then
    scripts.watch.save_logs(scripts.watch.collect_logs())
elseif environment.argument("cleanup") then
    scripts.watch.save_logs(scripts.watch.cleanup_stale_files())
elseif environment.argument("showlog") then
    scripts.watch.show_logs()
else
    logs.help(messages.help)
end

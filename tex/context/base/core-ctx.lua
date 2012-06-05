if not modules then modules = { } end modules ['core-ctx'] = {
    version   = 1.001,
    comment   = "companion to core-ctx.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

--[[
Job control files aka ctx files are rather old and date from the mkii times.
They were handled in texexec and mtx-context and deals with modes, modules,
environments and preprocessing in projects where one such file drives the
processing of lots of files without the need to provide command line
arguments.

In mkiv this concept was of course supported as well. The first implementation
of mtx-context took much of the approach of texexec, but by now we have gotten
rid of the option file (for passing modes, modules and environments), the stubs
(for directly processing cld and xml) as well as the preprocessing component
of the ctx files. Special helper features, like typesetting listings, were
already moved to the extras (a direct side effect of the ability to pass along
command line arguments.) All this made mtx-context more simple than its ancestor
texexec.

Because some of the modes might affect the mtx-context end, the ctx file is
still loaded there but only for getting the modes. The file is loaded again
during the run but as loading and basic processing takes less than a
millisecond it's not that much of a burden.
--]]

-- the ctxrunner tabel might either become private or move to the job namespace
-- which also affects the loading order

local trace_prepfiles = false  trackers.register("system.prepfiles", function(v) trace_prepfiles = v end)

local gsub, find = string.gsub, string.find

local report_prepfiles = logs.reporter("system","prepfiles")

commands       = commands or { }
local commands = commands

ctxrunner = ctxrunner or { }

ctxrunner.prepfiles = utilities.storage.allocate()

local function dontpreparefile(t,k)
    return k -- we only store when we have a prepper
end

table.setmetatableindex(ctxrunner.prepfiles,dontpreparefile)

local function filtered(str,method) -- in resolvers?
    str = tostring(str)
    if     method == 'name'     then str = file.removesuffix(file.basename(str))
    elseif method == 'path'     then str = file.dirname(str)
    elseif method == 'suffix'   then str = file.extname(str)
    elseif method == 'nosuffix' then str = file.removesuffix(str)
    elseif method == 'nopath'   then str = file.basename(str)
    elseif method == 'base'     then str = file.basename(str)
--  elseif method == 'full'     then
--  elseif method == 'complete' then
--  elseif method == 'expand'   then -- str = file.expandpath(str)
    end
    return (gsub(str,"\\","/"))
end

-- local function substitute(e,str)
--     local attributes = e.at
--     if str and attributes then
--         if attributes['method'] then
--             str = filtered(str,attributes['method'])
--         end
--         if str == "" and attributes['default'] then
--             str = attributes['default']
--         end
--     end
--     return str
-- end

local function substitute(str)
    return str
end

local function justtext(str)
    str = xml.unescaped(tostring(str))
    str = xml.cleansed(str)
    str = gsub(str,"\\+",'/')
    str = gsub(str,"%s+",' ')
    return str
end

function ctxrunner.load(ctxname)

    local xmldata = xml.load(ctxname)

    local jobname = tex.jobname -- todo

    local variables  = { job = jobname }
    local commands   = { }
    local flags      = { }
    local paths      = { } -- todo
    local treatments = { }
    local suffix     = "prep"

    xml.include(xmldata,'ctx:include','name', {'.', file.dirname(ctxname), "..", "../.." })

    for e in xml.collected(xmldata,"/ctx:job/ctx:flags/ctx:flag") do
        local key, value = match(flag,"^(.-)=(.+)$")
        if key and value then
            environment.setargument(key,value)
        else
            environment.setargument(flag,true)
        end
    end

    -- add to document.options.ctxfile[...]

    local ctxfile  = document.options.ctxfile

    local modes        = ctxfile.modes
    local modules      = ctxfile.modules
    local environments = ctxfile.environments

    for e in xml.collected(xmldata,"/ctx:job/ctx:process/ctx:resources/ctx:mode") do
        modes[#modes+1] = xml.text(e)
     -- context.enablemode { xml.text(e) }
    end

    for e in xml.collected(xmldata,"/ctx:job/ctx:process/ctx:resources/ctx:module") do
        modules[#modules+1] = xml.text(e)
     -- context.module { xml.text(e) }
    end

    for e in xml.collected(xmldata,"/ctx:job/ctx:process/ctx:resources/ctx:environment") do
        environments[#environments+1] = xml.text(e)
     -- context.environment { xml.text(e) }
    end

    for e in xml.collected(xmldata,"ctx:message") do
        report_prepfiles("ctx comment: %s", xml.text(e))
    end

    for r, d, k in xml.elements(xmldata,"ctx:value[@name='job']") do
        d[k] = variables['job'] or ""
    end

    for e in xml.collected(xmldata,"/ctx:job/ctx:preprocess/ctx:processors/ctx:processor") do
        commands[e.at and e.at['name'] or "unknown"] = e
    end

    local suffix   = xml.filter(xmldata,"xml:///ctx:job/ctx:preprocess/attribute('suffix')") -- or ...
    local runlocal = xml.filter(xmldata,"xml:///ctx:job/ctx:preprocess/ctx:processors/attribute('local')")

    runlocal = toboolean(runlocal)

    -- todo: only collect, then plug into file handler

    for files in xml.collected(xmldata,"/ctx:job/ctx:preprocess/ctx:files") do
        for pattern in xml.collected(files,"ctx:file") do
             local preprocessor = pattern.at['processor'] or ""
             if preprocessor ~= "" then
                treatments[#treatments+1] = {
                    pattern       = string.topattern(justtext(xml.tostring(pattern))),
                    preprocessors = utilities.parsers.settings_to_array(preprocessor),
                }
             end
        end
    end

    variables.old = jobname

    local function needstreatment(oldfile)
        for i=1,#treatments do
            local treatment = treatments[i]
            local pattern = treatment.pattern
            if find(oldfile,pattern) then
                return treatment
            end
        end
    end

    local preparefile = #treatments > 0 and function(prepfiles,filename)

        local treatment = needstreatment(filename)
        if treatment then
            local oldfile = filename
            newfile = oldfile .. "." .. suffix
            if runlocal then
                newfile = file.basename(newfile)
            end

            if file.needsupdating(oldfile,newfile) then
                local preprocessors = treatment.preprocessors
                local runners = { }
                for i=1,#preprocessors do
                    local preprocessor = preprocessors[i]
                    local command = commands[preprocessor]
                    if command then
                        command = xml.copy(command)
                        local suf = command.at and command.at['suffix'] or suffix
                        if suf then
                            newfile = oldfile .. "." .. suf
                        end
                        if runlocal then
                            newfile = file.basename(newfile)
                        end
                        for r, d, k in xml.elements(command,"ctx:old") do
                            d[k] = substitute(oldfile)
                        end
                        for r, d, k in xml.elements(command,"ctx:new") do
                            d[k] = substitute(newfile)
                        end
                        variables.old = oldfile
                        variables.new = newfile
                        for r, d, k in xml.elements(command,"ctx:value") do
                            local ek = d[k]
                            local ekat = ek.at and ek.at['name']
                            if ekat then
                                d[k] = substitute(variables[ekat] or "")
                            end
                        end
                        command = xml.content(command)
                        runners[#runners+1] = justtext(command)
                        oldfile = newfile
                        if runlocal then
                            oldfile = file.basename(oldfile)
                        end
                    end
                end
                -- for tracing we have collected commands first
                for i=1,#runners do
                    report_prepfiles("step %i: %s",i,runners[i])
                end
                --
                for i=1,#runners do
                    local command = runners[i]
                    report_prepfiles("command: %s",command)
                    local result = os.spawn(command) or 0
                 -- if result > 0 then
                 --     report_prepfiles("error, return code: %s",result)
                 -- end
                end
                if lfs.isfile(newfile) then
                    file.syncmtimes(filename,newfile)
                    report_prepfiles("%q is converted to %q",filename,newfile)
                else
                    report_prepfiles("%q is not converted to %q",filename,newfile)
                    newfile = filename
                end
            elseif lfs.isfile(newfile) then
                report_prepfiles("%q is already converted to %q",filename,newfile)
            else
             -- report_prepfiles("%q is not converted to %q",filename,newfile)
                newfile = filename
            end
        else
            newfile = filename
        end
        prepfiles[filename] = newfile

        return newfile

    end

    table.setmetatableindex(ctxrunner.prepfiles,preparefile or dontpreparefile)

end

local function resolve(name) -- used a few times later on
    return ctxrunner.prepfiles[file.collapsepath(name)] or false
end

local processfile       = commands.processfile
local doifinputfileelse = commands.doifinputfileelse

function commands.processfile(name,maxreadlevel) -- overloaded
    local prepname = resolve(name)
    if prepname then
        return processfile(prepname,0)
    end
    return processfile(name,maxreadlevel)
end

function commands.doifinputfileelse(name,depth)
    local prepname = resolve(name)
    if prepname then
        return doifinputfileelse(prepname,0)
    end
    return doifinputfileelse(name,depth)
end

function commands.preparedfile(name)
    return resolve(name) or name
end

function commands.getctxfile()
    local ctxfile = document.arguments.ctx or ""
    if ctxfile ~= "" then
        ctxrunner.load(ctxfile) -- do we need to locate it?
    end
end

-- ctxrunner.load("t:/sources/core-ctx.ctx")
--
-- context(ctxrunner.prepfiles["one-a.xml"]) context.par()
-- context(ctxrunner.prepfiles["one-b.xml"]) context.par()
-- context(ctxrunner.prepfiles["two-c.xml"]) context.par()
-- context(ctxrunner.prepfiles["two-d.xml"]) context.par()
-- context(ctxrunner.prepfiles["all-x.xml"]) context.par()
--
-- inspect(ctxrunner.prepfiles)

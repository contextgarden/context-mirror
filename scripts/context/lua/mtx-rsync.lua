if not modules then modules = { } end modules ['mtx-rsync'] = {
    version   = 1.000,
    comment   = "companion to mtxrun.lua",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- This is an experimental script that will be extended over time and
-- is used by myself. An example or a copy spec:
--
--
-- local devdir = "m:/develop/services"
-- local orgdir = "m:/pod/m4all"
--
-- return {
--     {
--         origin = { devdir, "framework/scripts/d-dispatchers.lua"},
--         target = { orgdir, "framework/scripts" },
--     },
--     {
--         origin = { devdir, "framework/scripts/common/*"},
--         target = { orgdir, "framework/scripts/common" },
--     },
--     {
--         origin = { devdir, "framework/scripts/d-buildtool.lua"  },
--         target = { orgdir, "framework/scripts" }
--     },
--     {
--         origin = { devdir, "framework/scripts/buildtool/*"},
--         target = { orgdir, "framework/scripts/buildtool" },
--     },
--     {
--         origin = { devdir, "framework/m4all*" },
--         target = { orgdir, "framework" },
--     },
--     {
--         origin = { devdir, "framework/configurations/*m4all*"},
--         target = { orgdir, "framework/configurations" },
--     },
--     {
--         recurse = true,
--         origin  = { devdir, "context/tex/texmf-project/tex/context/user/m4all/*" },
--         target  = { orgdir, "context/tex/texmf-project/tex/context/user/m4all" },
--     },
-- }

local helpinfo = [[
<?xml version="1.0"?>
<application>
 <metadata>
  <entry name="name">mtx-rsync</entry>
  <entry name="detail">Rsync Helpers</entry>
  <entry name="version">0.10</entry>
 </metadata>
 <flags>
  <category name="basic">
   <subcategory>
    <flag name="job"><short>use given file as specification</short></flag>
    <flag name="dryrun"><short>show what would happen</short></flag>
    <flag name="force"><short>force run</short></flag>
   </subcategory>
  </category>
 </flags>
</application>
]]

local application = logs.application {
    name     = "mtx-rsync",
    banner   = "Rsync Helpers 0.10",
    helpinfo = helpinfo,
}

local format, gsub = string.format, string.gsub
local concat = table.concat

local report_message = logs.new("rsync message")
local report_dryrun  = logs.new("rsync dryrun")
local report_normal  = logs.new("rsync normal")
local report_command = logs.new("rsync command")

local cleanup

if os.type == "windows" then
    os.setenv("CYGWIN","nontsec")
    cleanup = function(name)
        return (gsub(name,"([a-zA-Z]):/", "/cygdrive/%1/"))
    end
else
    cleanup = function(name)
        return name
    end
end

function rsynccommand(origin,target,dryrun,recurse,delete,exclude)
    local command = "rsync -t -p"
    if dryrun then
        command = command .. " -n"
    end
    if recurse then
        command = command .. " -r"
    end
    if type(exclude) == "table" then
        for i=1,#exclude do
            local e = exclude[i]
            if e then
                command = command .. ' --exclude "' .. e .. '"'
            end
        end
    elseif type(exclude) == "string" then
        command = command .. " --exclude-from " .. exclude
    end
    if delete and recurse then
        command = command .. " --delete"
    end
    return format('%s %s %s',command,origin,target)
end

scripts       = scripts or { }
scripts.rsync = scripts.rsync or { }
local rsync   = scripts.rsync

rsync.mode = "command"

function rsync.run(origin,target,message,recurse,delete,exclude)
    if type(origin) == "table" then
        origin = concat(origin,"/")
    end
    if type(target) == "table" then
        target = concat(target,"/")
    end
    origin = cleanup(origin)
    target = cleanup(target)
    local path = gsub(target,"^/cygdrive/(.)","%1:")
    if not lfs.isdir(path) then
        report_message("creating target dir %s",path)
        dir.makedirs(path) -- as rsync only creates them when --recursive
    end
    if message then
        report_message(message)
    end
    if rsync.mode == "dryrun" then
        local command = rsynccommand(origin,target,true,recurse,delete,exclude)
        report_dryrun(command.."\n")
        os.execute(command)
    elseif rsync.mode == "force" then
        local command = rsynccommand(origin,target,false,recurse,delete,exclude)
        report_normal(command.."\n")
        os.execute(command)
    else
        local command = rsynccommand(origin,target,true,recurse,delete,exclude)
        report_command(command)
    end
end

function rsync.job(list)
    if type(list) == "string" and lfs.isfile(list) then
        list = dofile(list)
    end
    if type(list) ~= "table" then
        report_message("invalid job specification")
        return
    end
    for i=1,#list do
        local li = list[i]
        local origin  = li.origin
        local target  = li.target
        local message = li.message
        local recurse = li.recurse
        local delete  = li.delete
        local exclude = li.exclude
        if origin and #origin > 0 and target and #target > 0 then -- string or table
            rsync.run(origin,target,message,recurse,delete,exclude)
        else
            report_message("invalid job specification at index %s",i)
        end
    end
end

if environment.ownscript then
    -- stand alone
else
    report(application.banner)
    return rsync
end

local arguments = environment.arguments
local files     = environment.files

if arguments.dryrun then
    rsync.mode = "dryrun"
elseif arguments.force then
    rsync.mode = "force"
end

if arguments.exporthelp then
    application.export(arguments.exporthelp,environment.files[1])
elseif arguments.job then
    rsync.job(files[1])
elseif files[1] and files[2] then
    rsync.run(files[1],files[2])
else
    application.help()
end

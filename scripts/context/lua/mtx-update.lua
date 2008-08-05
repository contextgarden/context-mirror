if not modules then modules = { } end modules ['mtx-update'] = {
    version   = 1.001,
    comment   = "companion to mtxrun.lua",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- This script is dedicated to Mojca Miklavec, who is the driving force behind
-- moving minimal generation from our internal machines to the context garden.
-- Together with Arthur Reutenauer she made sure that it worked well on all
-- platforms that matter.

scripts         = scripts         or { }
scripts.update  = scripts.update  or { }

minimals        = minimals        or { }
minimals.config = minimals.config or { }

os.setenv("CYGWIN","nontsec")

scripts.update.allformats = {
    "cont-en",
    "cont-nl",
    "cont-cz",
    "cont-de",
    "cont-fa",
    "cont-it",
    "cont-ro",
    "cont-uk",
    "metafun",
    "mptopdf",
    "plain"
}

scripts.update.fewformats = {
    "cont-en",
    "cont-nl",
    "metafun",
    "mptopdf",
    "plain"
}

scripts.update.repositories = {
    "current",
    "experimental"
}

scripts.update.versions = {
    "current",
    "latest"
}

scripts.update.engines = {
    ["luatex"] = {
        { "base/tex/",                "texmf" },
        { "base/metapost/",           "texmf" },
        { "fonts/new/",               "texmf" },
        { "fonts/common/",            "texmf" },
        { "fonts/other/",             "texmf" },
        { "context/<version>/",       "texmf-context" },
        { "context/img/",             "texmf-context" },
        { "context/config/",          "texmf-context" },
        { "misc/setuptex/",           "." },
        { "misc/web2c",               "texmf" },
        { "bin/common/<platform>/",   "texmf-<platform>" },
        { "bin/context/<platform>/",  "texmf-<platform>" },
        { "bin/metapost/<platform>/", "texmf-<platform>" },
        { "bin/luatex/<platform>/",   "texmf-<platform>" },
        { "bin/man/",                 "texmf-<platform>" }
    },
    ["xetex"] = {
        { "base/tex/",                "texmf" },
        { "base/metapost/",           "texmf" },
        { "base/xetex/",              "texmf" },
        { "fonts/new/",               "texmf" },
        { "fonts/common/",            "texmf" },
        { "fonts/other/",             "texmf" },
        { "context/<version>/",       "texmf-context" },
        { "context/img/",             "texmf-context" },
        { "context/config/",          "texmf-context" },
        { "misc/setuptex/",           "." },
        { "misc/web2c",               "texmf" },
        { "bin/common/<platform>/",   "texmf-<platform>" },
        { "bin/context/<platform>/",  "texmf-<platform>" },
        { "bin/metapost/<platform>/", "texmf-<platform>" },
        { "bin/xetex/<platform>/",    "texmf-<platform>" },
        { "bin/man/",                 "texmf-<platform>" }
    },
    ["pdftex"] = {
        { "base/tex/",                "texmf" },
        { "base/metapost/",           "texmf" },
        { "fonts/old/",               "texmf" },
        { "fonts/common/",            "texmf" },
        { "fonts/other/",             "texmf" },
        { "context/<version>/",       "texmf-context" },
        { "context/img/",             "texmf-context" },
        { "context/config/",          "texmf-context" },
        { "misc/setuptex/",           "." },
        { "misc/web2c",               "texmf" },
        { "bin/common/<platform>/",   "texmf-<platform>" },
        { "bin/context/<platform>/",  "texmf-<platform>" },
        { "bin/metapost/<platform>/", "texmf-<platform>" },
        { "bin/pdftex/<platform>/",   "texmf-<platform>" },
        { "bin/man/",                 "texmf-<platform>" }
    },
    ["all"] = {
        { "base/tex/",                "texmf" },
        { "base/metapost/",           "texmf" },
        { "base/xetex/",              "texmf" },
        { "fonts/old/",               "texmf" },
        { "fonts/new/",               "texmf" },
        { "fonts/common/",            "texmf" },
        { "fonts/other/",             "texmf" },
        { "context/<version>/",       "texmf-context" },
        { "context/img/",             "texmf-context" },
        { "context/config/",          "texmf-context" },
        { "misc/setuptex/",           "." },
        { "misc/web2c",               "texmf" },
        { "bin/common/<platform>/",   "texmf-<platform>" },
        { "bin/context/<platform>/",  "texmf-<platform>" },
        { "bin/metapost/<platform>/", "texmf-<platform>" },
        { "bin/luatex/<platform>/",   "texmf-<platform>" },
        { "bin/xetex/<platform>/",    "texmf-<platform>" },
        { "bin/pdftex/<platform>/",   "texmf-<platform>" },
        { "bin/man/",                 "texmf-<platform>" }
    },
}

scripts.update.platforms = {
    ["mswin"]       = "mswin",
    ["windows"]     = "mswin",
    ["win32"]       = "mswin",
    ["win"]         = "mswin",
    ["linux"]       = "linux",
    ["freebsd"]     = "freebsd",
    ["linux-32"]    = "linux",
    ["linux-64"]    = "linux-64",
    ["linux32"]     = "linux",
    ["linux64"]     = "linux-64",
    ["osx"]         = "osx-intel",
    ["osx-intel"]   = "osx-intel",
    ["osx-ppc"]     = "osx-ppc",
    ["osx-powerpc"] = "osx-ppc",
    ["osxintel"]    = "osx-intel",
    ["osxppc"]      = "osx-ppc",
    ["osxpowerpc"]  = "osx-ppc",
}

function scripts.update.run(str)
    logs.report("run", str)
    if environment.argument("force") then
        -- important, otherwise formats fly to a weird place
        -- (texlua sets luatex as the engine, we need to reset that or to fix texexec :)
        os.setenv("engine",nil)
        os.execute(str)
    end
end

function scripts.update.fullpath(path)
    if input.aux.rootbased_path(path) then
        return path
    else
        return lfs.currentdir() .. "/" .. path
    end
end

function scripts.update.synchronize()
    logs.report("update","start")
    local texroot = scripts.update.fullpath(states.get("paths.root"))
    local engines = states.get('engines')
    local platforms = states.get('platforms')
    local repositories = states.get('repositories')
    local bin = states.get("rsync.program")
    local url = states.get("rsync.server")
    local version = states.get("context.version")
    local force = environment.argument("force")
    if not url:find("::$") then url = url .. "::" end
    local ok = lfs.attributes(texroot,"mode") == "directory"
    if not ok and force then
        dir.mkdirs(texroot)
        ok = lfs.attributes(texroot,"mode") == "directory"
    end
    if ok or not force then
        if force then
            dir.mkdirs(string.format("%s/%s", texroot, "texmf-cache"))
        end
        local fetched, individual = { }, { }
        for engine, _ in pairs(engines) do
            local collections = scripts.update.engines[engine]
            if collections then
                for _, collection in ipairs(collections) do
                    for platform, _ in pairs(platforms) do
                        platform = scripts.update.platforms[platform]
                        if platform then
                            local archive = collection[1]:gsub("<platform>", platform)
                            local destination = string.format("%s/%s", texroot, collection[2]:gsub("<platform>", platform))
                            destination = destination:gsub("\\","/")
                            archive = archive:gsub("<version>",version)
--~                             if platform == "windows" or platform == "mswin" then
                            if os.currentplatform() == "windows" or os.currentplatform() == "mswin" then
                                destination = destination:gsub("([a-zA-Z]):/", "/cygdrive/%1/")
                            end
                            individual[#individual+1] = { archive, destination }
                        end
                    end
                end
            end
        end
        local combined = { }
        for _, repository in ipairs(scripts.update.repositories) do
            if repositories[repository] then
                for _, v in pairs(individual) do
                    local archive, destination = v[1], v[2]
                    local cd = combined[destination]
                    if not cd then
                        cd = { }
                        combined[destination] = cd
                    end
                    cd[#cd+1] = string.format("%s/%s/%s",states.get('rsync.module'),repository,archive)
                end
            end
        end
        if input.verbose then
            for k, v in pairs(combined) do
                logs.report("update", k)
                for k,v in ipairs(v) do
                    logs.report("update", "  <= " .. v)
                end
            end
        end
        for destination, archive in pairs(combined) do
            local archives, command = table.concat(archive," "), ""
            local normalflags, deleteflags = states.get("rsync.flags.normal"), states.get("rsync.flags.delete")
            if true then -- environment.argument("keep") or destination:find("%.$") then
                command = string.format("%s %s    %s'%s' '%s'", bin, normalflags,              url, archives, destination)
            else
                command = string.format("%s %s %s %s'%s' '%s'", bin, normalflags, deleteflags, url, archives, destination)
            end
            logs.report("mtx update", string.format("running command: %s",command))
            if not fetched[command] then
                scripts.update.run(command)
                fetched[command] = command
            end
        end
    else
        logs.report("mtx update", string.format("no valid texroot: %s",texroot))
    end
    if not force then
        logs.report("update", "use --force to really update")
    end
    logs.report("update","done")
end

function table.fromhash(t)
    local h = { }
    for k, v in pairs(t) do -- no ipairs here
        if v then h[#h+1] = k end
    end
    return h
end


function scripts.update.make()
    logs.report("make","start")
    local force = environment.argument("force")
    local texroot = scripts.update.fullpath(states.get("paths.root"))
    local engines = states.get('engines')
    local platforms = states.get('platforms')
    local formats = states.get('formats')
    input.load_tree(texroot)
    scripts.update.run("mktexlsr")
    scripts.update.run("luatools --generate")
    local formatlist = table.concat(table.fromhash(formats), " ")
    if formatlist ~= "" then
        for engine in pairs(engines) do
            -- todo: just handle make here or in mtxrun --script context --make
--~             os.execute("set")
            scripts.update.run(string.format("texexec --make --all --fast --%s %s",engine,formatlist))
        end
    end
    if not force then
        logs.report("make", "use --force to really make")
    end
    logs.report("make","done")
end

banner = banner .. " | download tools "

messages.help = [[
--platform=string     platform (windows, linux, linux-64, osx-intel, osx-ppc)
--server=string       repository url (rsync://contextgarden.net)
--module=string       repository url (minimals)
--repository=string   specify version (current, experimental)
--context=string      specify version (current, latest, yyyy.mm.dd)
--rsync=string        rsync binary (rsync)
--texroot             installation directory (not guessed for the moment)
--engine              tex engine (luatex, pdftex, xetex)
--force               instead of a dryrun, do the real thing
--update              update minimal tree
--make                also make formats and generate file databases
--keep                don't delete unused or obsolete files
--state               update tree using saved state
]]

input.verbose = true

scripts.savestate = true

if scripts.savestate then

    states.load("status-of-update.lua")

    -- tag, value, default, persistent

    input.starttiming(states)

    states.set("info.version",0.1) -- ok
    states.set("info.count",(states.get("info.count") or 0) + 1,1,false) -- ok
    states.set("info.comment","this file contains the settings of the last 'mtxrun --script update ' run",false) -- ok
    states.set("info.date",os.date("!%Y-%m-%d %H:%M:%S")) -- ok

    states.set("rsync.program", environment.argument("rsync"), "rsync", true) -- ok
    states.set("rsync.server", environment.argument("server"), "contextgarden.net::", true) -- ok
    states.set("rsync.module", environment.argument("module"), "minimals", true) -- ok
    states.set("rsync.flags.normal", environment.argument("flags"), "-rpztlv --stats", true) -- ok
    states.set("rsync.flags.delete", nil, "--delete", true) -- ok

    states.set("paths.root", environment.argument("texroot"), "tex", true) -- ok

    states.set("context.version", environment.argument("context"), "current", true) -- ok

    local valid = table.tohash(scripts.update.repositories)
    for r in string.gmatch(environment.argument("repository") or "current","([^, ]+)") do
        if valid[r] then states.set("repositories." .. r, true) end
    end
    local valid = scripts.update.engines
    for r in string.gmatch(environment.argument("engine") or "all","([^, ]+)") do
        if r == "all" then
            for k, v in pairs(valid) do
                if k ~= "all" then
                    states.set("engines." .. k, true)
                end
            end
        elseif valid[r] then
            states.set("engines." .. r, true)
        end
    end
    local valid = scripts.update.platforms
    for r in string.gmatch(environment.argument("platform") or os.currentplatform(),"([^, ]+)") do
        if valid[r] then states.set("platforms." .. r, true) end
    end

    local valid = table.tohash(scripts.update.allformats)
    for r in string.gmatch(environment.argument("formats") or "","([^, ]+)") do
        if valid[r] then states.set("formats." .. r, true) end
    end

    states.set("formats.cont-en", true)
    states.set("formats.cont-nl", true)
    states.set("formats.metafun", true)

    -- modules

    logs.report("state","loaded")

end

if environment.argument("state") then
    environment.setargument("update",true)
    environment.setargument("force",true)
    environment.setargument("make",true)
end

if environment.argument("update") then
    scripts.update.synchronize()
    if environment.argument("make") then
        scripts.update.make()
    end
elseif environment.argument("make") then
    scripts.update.make()
else
    input.help(banner,messages.help)
end

if scripts.savestate then
    input.stoptiming(states)
    states.set("info.runtime",tonumber(input.elapsedtime(states)))
    if environment.argument("force") then
        states.save()
        logs.report("state","saved")
    end
end

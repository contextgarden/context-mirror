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

texmf.instance  = instance -- we need to get rid of this / maybe current instance in global table

scripts         = scripts         or { }
scripts.update  = scripts.update  or { }

minimals        = minimals        or { }
minimals.config = minimals.config or { }

scripts.update.collections = {
    ["luatex"] = {
        { "base/tex/",         "texmf" },
        { "base/metapost/",    "texmf" },
        { "fonts/new/",        "texmf" },
        { "fonts/common/",     "texmf" },
        { "fonts/other/",      "texmf" },
        { "context/current/",  "texmf-context" },
        { "context/img/",      "texmf-context" },
        { "misc/setuptex/",    "." },
        { "misc/web2c",        "texmf" },
        { "bin/common/%s/",    "texmf-%s" },
        { "bin/context/%s/",   "texmf-%s" },
        { "bin/metapost/%s/",  "texmf-%s" },
        { "bin/luatex/%s/",    "texmf-%s" },
        { "bin/man/",          "texmf-%s" }
    },
    ["xetex"] = {
        { "base/tex/",         "texmf" },
        { "base/metapost/",    "texmf" },
        { "base/xetex/",       "texmf" },
        { "fonts/new/",        "texmf" },
        { "fonts/common/",     "texmf" },
        { "fonts/other/",      "texmf" },
        { "context/current/",  "texmf-context" },
        { "context/img/",      "texmf-context" },
        { "misc/setuptex/",    "." },
        { "misc/web2c",        "texmf" },
        { "bin/common/%s/",    "texmf-%s" },
        { "bin/context/%s/",   "texmf-%s" },
        { "bin/metapost/%s/",  "texmf-%s" },
        { "bin/xetex/%s/",     "texmf-%s" },
        { "bin/man/",          "texmf-%s" }
    },
    ["pdftex"] = {
        { "base/tex/",         "texmf" },
        { "base/metapost/",    "texmf" },
        { "fonts/old/",        "texmf" },
        { "fonts/common/",     "texmf" },
        { "fonts/other/",      "texmf" },
        { "context/current/",  "texmf-context" },
        { "context/img/",      "texmf-context" },
        { "misc/setuptex/",    "." },
        { "misc/web2c",        "texmf" },
        { "bin/common/%s/",    "texmf-%s" },
        { "bin/context/%s/",   "texmf-%s" },
        { "bin/metapost/%s/",  "texmf-%s" },
        { "bin/pdftex/%s/",    "texmf-%s" },
        { "bin/man/",          "texmf-%s" }
    },
    ["all"] = {
        { "base/tex/",         "texmf" },
        { "base/metapost/",    "texmf" },
        { "base/xetex/",       "texmf" },
        { "fonts/old/",        "texmf" },
        { "fonts/new/",        "texmf" },
        { "fonts/common/",     "texmf" },
        { "fonts/other/",      "texmf" },
        { "context/current/",  "texmf-context" },
        { "context/img/",      "texmf-context" },
        { "misc/setuptex/",    "." },
        { "misc/web2c",        "texmf" },
        { "bin/common/%s/",    "texmf-%s" },
        { "bin/context/%s/",   "texmf-%s" },
        { "bin/metapost/%s/",  "texmf-%s" },
        { "bin/luatex/%s/",    "texmf-%s" },
        { "bin/xetex/%s/",     "texmf-%s" },
        { "bin/pdftex/%s/",    "texmf-%s" },
        { "bin/man/",          "texmf-%s" }
    },
}

scripts.update.platforms = {
    ["mswin"]     = "mswin",
    ["windows"]   = "mswin",
    ["win32"]     = "mswin",
    ["win"]       = "mswin",
    ["linux"]     = "linux",
    ["linux-32"]  = "linux",
    ["linux-64"]  = "linux-64",
    ["osx"]       = "osx-intel",
    ["osx-intel"] = "osx-intel",
    ["osx-ppc"]   = "osx-ppc",
}

scripts.update.rsyncflagspath = "-rpztlv --stats --delete"
scripts.update.rsyncflagsroot = "-rpztlv --stats"

function scripts.update.prepare()
    local texroot  = environment.argument("texroot") or "tex"
    local engines  = environment.argument("engine")
    if engines then
        engines = engines:split(",")
    else
        engines = minimals.config.engines or { "all" }
    end
    local platforms = environment.argument("platform")
    if platforms then
        platforms = platforms:split(",")
    else
        platforms = minimals.config.platform or { os.currentplatform() }
    end
    return texroot, engines, platforms
end

function scripts.update.run(str)
    if environment.argument("dryrun") then
        logs.report("run", str)
    else
        -- important, otherwise formats fly to a weird place
        -- (texlua sets luatex as the engine, we need to reset that or to fix texexec :)
        os.setenv("engine",nil)
        os.spawn(str)
    end
end

function scripts.update.synchronize()
    local texroot, engines, platforms = scripts.update.prepare()
    local dryrun = environment.argument("dryrun")
    os.setenv("CYGWIN","nontsec")
    local rsyncbin = environment.argument("rsync") or "rsync"
    local url = environment.argument("url") or "contextgarden.net::"
    if not url:find("::$") then url = url .. "::" end
    local ok = lfs.attributes(texroot,"mode") == "directory"
    if not ok and not dryrun then
        dir.mkdirs(texroot)
        ok = lfs.attributes(texroot,"mode") == "directory"
    end
    if ok or dryrun then
        if not dryrun then
            dir.mkdirs(string.format("%s/%s", texroot, "texmf-cache"))
        end
        local fetched = { }
        local individual = { }
        local context = environment.argument("context")
        for _, engine in ipairs(engines) do
            local collections = scripts.update.collections[engine]
            if collections then
                for _, collection in ipairs(collections) do
                    for _, platform in ipairs(platforms) do
                        platform = scripts.update.platforms[platform]
                        if platform then
                            local archive = string.format(collection[1], platform)
                            local destination = string.format("%s/%s", texroot, string.format(collection[2], platform))
                            destination = destination:gsub("\\","/")
                            if platform == "windows" or platform == "mswin" then
                                destination = destination:gsub("([a-zA-Z]):/", "/cygdrive/%1/")
                            end
                            -- if one uses experimental, context=... has no effect
                            if context and not environment.argument("experimental") then
                                archive = archive:gsub("/current/", "/" .. context .. "/")
                            end
                            individual[#individual+1] = { archive, destination }
                        end
                    end
                end
            end
        end
        local combined = { }
        local distributions = { "current" }
        -- we need to fetch files from both "current" and "experimental" branch
        if environment.argument("experimental") then
            distributions = { "experimental", "current" }
        end
        for _, d in pairs(distributions) do
            for _, v in pairs(individual) do
                local archive, destination = v[1], v[2]
                local cd = combined[destination]
                if not cd then
                    cd = { }
                    combined[destination] = cd
                end
                cd[#cd+1] = 'minimals/' .. d .. '/' .. archive
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
            if not environment.argument("delete") or destination:find("%.$") then
                command = string.format("%s %s %s'%s' %s", rsyncbin, scripts.update.rsyncflagsroot, url, archives, destination)
            else
                command = string.format("%s %s %s'%s' %s", rsyncbin, scripts.update.rsyncflagspath, url, archives, destination)
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
    if environment.argument("make") then
        scripts.update.make()
    end
end

function scripts.update.make()
    local texroot, engines, platforms = scripts.update.prepare()
    input.load_tree(texroot)
    scripts.update.run("mktexlsr")
    scripts.update.run("luatools --generate")
    engines = (engines[1] and engines[1] == "all" and { "pdftex", "xetex", "luatex" }) or engines
    for _, engine in ipairs(engines) do
        scripts.update.run(string.format("texexec --make --all --fast --%s",engine))
    end
end

banner = banner .. " | download tools "

input.runners.save_list = {
    "update", "engine", "platform", "url", "rsync", "texroot", "dryrun", "make", "delete", "context"
}

messages.help = [[
--update              update minimal tree
--engine              tex engine (luatex, pdftex, xetex)
--platform            platform (windows, linux, linux-64, osx-intel, osx-ppc)
--url                 repository url (rsync://contextgarden.net/minimals)
--rsync               rsync binary (rsync)
--texroot             installation directory (not guessed for the moment)
--dryrun              just show what will be done
--make                also make formats and generate file databases
--delete              delete unused files
--context=string      specify version (current, experimental, yyyy.mm.dd)
]]

input.verbose = true

if environment.argument("update") then
    logs.report("update","start")
    scripts.update.synchronize()
    logs.report("update","done")
elseif environment.argument("make") then
    logs.report("make","start")
    scripts.update.make()
    logs.report("make","done")
else
    input.help(banner,messages.help)
end

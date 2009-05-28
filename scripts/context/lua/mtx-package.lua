if not modules then modules = { } end modules ['mtx-package'] = {
    version   = 1.002,
    comment   = "companion to mtxrun.lua",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local format, gsub, gmatch = string.format, string.gsub, string.gmatch

scripts         = scripts         or { }
messages        = messages        or { }
scripts.package = scripts.package or { }

function scripts.package.merge_luatex_files(name,strip)
    local oldname = resolvers.find_file(name) or ""
    oldname = file.replacesuffix(oldname,"lua")
    if oldname == "" then
        logs.simple("missing '%s'",name)
    else
        local newname = file.removesuffix(oldname) .. "-merged.lua"
        local data = io.loaddata(oldname) or ""
        if data == "" then
            logs.simple("missing '%s'",newname)
        else
            logs.simple("loading '%s'",oldname)
            local collected = { }
            collected[#collected+1] = format("-- merged file : %s\n",newname)
            collected[#collected+1] = format("-- parent file : %s\n",oldname)
            collected[#collected+1] = format("-- merge date  : %s\n",os.date())
            -- loadmodule can have extra arguments
            for lib in gmatch(data,"loadmodule *%([\'\"](.-)[\'\"]") do
                if file.basename(lib) ~= file.basename(newname) then
                    local fullname = resolvers.find_file(lib) or ""
                    if fullname == "" then
                        logs.simple("missing '%s'",lib)
                    else
                        logs.simple("fetching '%s'",fullname)
                        local data = io.loaddata(fullname)
                        if strip then
                            data = gsub(data,"%-%-%[%[ldx%-%-.-%-%-%ldx%]%]%-%-[\n\r]*","")
                            data = gsub(data,"%-%-%~[^\n\r]*[\n\r]*","\n")
                            data = gsub(data,"%s+%-%-[^\n\r]*[\n\r]*","\n")
                            data = gsub(data,"[\n\r]+","\n")
                        end
                        collected[#collected+1] = "\ndo -- begin closure to overcome local limits and interference\n\n"
                        collected[#collected+1] = data
                        collected[#collected+1] = "\nend -- closure\n"
                    end
                end
            end
            logs.simple("saving '%s'",newname)
            io.savedata(newname,table.concat(collected))
        end
    end
end

logs.extendbanner("Package Tools 0.1",true)

messages.help = [[
--merge               merge 'loadmodule' into merge file
]]

if environment.argument("merge") then
    scripts.package.merge_luatex_files(environment.files[1] or "")
else
    logs.help(messages.help)
end

if not modules then modules = { } end modules ['data-aux'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.tex",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local find = string.find

local trace_verbose = false  trackers.register("resolvers.verbose", function(v) trace_verbose = v end)

function resolvers.update_script(oldname,newname) -- oldname -> own.name, not per se a suffix
    local scriptpath = "scripts/context/lua"
    newname = file.addsuffix(newname,"lua")
    local oldscript = resolvers.clean_path(oldname)
    if trace_verbose then
        logs.report("fileio","to be replaced old script %s", oldscript)
    end
    local newscripts = resolvers.find_files(newname) or { }
    if #newscripts == 0 then
        if trace_verbose then
            logs.report("fileio","unable to locate new script")
        end
    else
        for i=1,#newscripts do
            local newscript = resolvers.clean_path(newscripts[i])
            if trace_verbose then
                logs.report("fileio","checking new script %s", newscript)
            end
            if oldscript == newscript then
                if trace_verbose then
                    logs.report("fileio","old and new script are the same")
                end
            elseif not find(newscript,scriptpath) then
                if trace_verbose then
                    logs.report("fileio","new script should come from %s",scriptpath)
                end
            elseif not (find(oldscript,file.removesuffix(newname).."$") or find(oldscript,newname.."$")) then
                if trace_verbose then
                    logs.report("fileio","invalid new script name")
                end
            else
                local newdata = io.loaddata(newscript)
                if newdata then
                    if trace_verbose then
                        logs.report("fileio","old script content replaced by new content")
                    end
                    io.savedata(oldscript,newdata)
                    break
                elseif trace_verbose then
                    logs.report("fileio","unable to load new script")
                end
            end
        end
    end
end

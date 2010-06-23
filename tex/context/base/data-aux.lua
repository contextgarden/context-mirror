if not modules then modules = { } end modules ['data-aux'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local find = string.find
local type, next = type, next

local trace_locating = false  trackers.register("resolvers.locating", function(v) trace_locating = v end)

local report_resolvers = logs.new("resolvers")

function resolvers.update_script(oldname,newname) -- oldname -> own.name, not per se a suffix
    local scriptpath = "scripts/context/lua"
    newname = file.addsuffix(newname,"lua")
    local oldscript = resolvers.clean_path(oldname)
    if trace_locating then
        report_resolvers("to be replaced old script %s", oldscript)
    end
    local newscripts = resolvers.find_files(newname) or { }
    if #newscripts == 0 then
        if trace_locating then
            report_resolvers("unable to locate new script")
        end
    else
        for i=1,#newscripts do
            local newscript = resolvers.clean_path(newscripts[i])
            if trace_locating then
                report_resolvers("checking new script %s", newscript)
            end
            if oldscript == newscript then
                if trace_locating then
                    report_resolvers("old and new script are the same")
                end
            elseif not find(newscript,scriptpath) then
                if trace_locating then
                    report_resolvers("new script should come from %s",scriptpath)
                end
            elseif not (find(oldscript,file.removesuffix(newname).."$") or find(oldscript,newname.."$")) then
                if trace_locating then
                    report_resolvers("invalid new script name")
                end
            else
                local newdata = io.loaddata(newscript)
                if newdata then
                    if trace_locating then
                        report_resolvers("old script content replaced by new content")
                    end
                    io.savedata(oldscript,newdata)
                    break
                elseif trace_locating then
                    report_resolvers("unable to load new script")
                end
            end
        end
    end
end

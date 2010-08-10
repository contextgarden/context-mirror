if not modules then modules = { } end modules ['mtx-colors'] = {
    version   = 1.001,
    comment   = "companion to mtxrun.lua",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- todo: fc-cache -v en check dirs, or better is: fc-cat -v | grep Directory

if not fontloader then fontloader = fontforge end

dofile(resolvers.find_file("colo-icc.lua","tex"))

scripts        = scripts        or { }
scripts.colors = scripts.colors or { }

function scripts.colors.table()
    local files = environment.files
    if #files > 0 then
        for i=1,#files do
            local profile, okay, message = colors.iccprofile(files[i])
            if not okay then
                logs.simple(message)
            else
                logs.simple(table.serialize(profile,"profile"))
            end
        end
    else
        logs.simple("no file(s) given" )
    end
end

logs.extendbanner("ConTeXt Color Management 0.1")

messages.help = [[
--table               show icc table

example:

mtxrun --script color --table somename
]]

--~ local track = environment.argument("track")
--~ if track then trackers.enable(track) end

if environment.argument("table") then
    scripts.colors.table()
else
    logs.help(messages.help)
end

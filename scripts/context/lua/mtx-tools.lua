if not modules then modules = { } end modules ['mtx-tools'] = {
    version   = 1.002,
    comment   = "companion to mtxrun.lua",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- data tables by Thomas A. Schmitz

local find, gsub = string.find, string.gsub

scripts       = scripts       or { }
scripts.tools = scripts.tools or { }

local bomb_1, bomb_2 = "^\254\255", "^\239\187\191"

function scripts.tools.disarmutfbomb()
    local force, done = environment.argument("force"), false
    for _, name in ipairs(environment.files) do
        if lfs.isfile(name) then
            local data = io.loaddata(name)
            if not data then
                -- just skip
            elseif find(data,bomb_1) then
                logs.simple("file '%s' has a 2 character utf bomb",name)
                if force then
                    io.savedata(name,(gsub(data,bomb_1,"")))
                end
                done = true
            elseif find(data,bomb_2) then
                logs.simple("file '%s' has a 3 character utf bomb",name)
                if force then
                    io.savedata(name,(gsub(data,bomb_2,"")))
                end
                done = true
            else
            --  logs.simple("file '%s' has no utf bomb",name)
            end
        end
    end
    if done and not force then
        logs.simple("use --force to do a real disarming")
    end
end

logs.extendbanner("All Kind Of Tools 1.0",true)

messages.help = [[
--disarmutfbomb       remove utf bomb if present
]]

if environment.argument("disarmutfbomb") then
    scripts.tools.disarmutfbomb()
else
    logs.help(messages.help)
end

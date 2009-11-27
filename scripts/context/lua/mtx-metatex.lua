if not modules then modules = { } end modules ['mtx-metatex'] = {
    version   = 1.001,
    comment   = "companion to mtxrun.lua",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- future versions will deal with specific variants of metatex

scripts         = scripts         or { }
scripts.metatex = scripts.metatex or { }

-- metatex

function scripts.metatex.make()
    local command = "luatools --make --compile metatex"
    logs.simple("running command: %s",command)
    os.spawn(command)
end

--~ function scripts.metatex.run()
--~     local name = environment.files[1] or ""
--~     if name ~= "" then
--~         local command = "luatools --fmt=metatex " .. name
--~         logs.simple("running command: %s",command)
--~         os.spawn(command)
--~     end
--~ end

function scripts.metatex.run(ctxdata,filename)
    local filename = environment.files[1] or ""
    if filename ~= "" then
        local formatfile, scriptfile = resolvers.locate_format("metatex")
        if formatfile and scriptfile then
            local command = string.format("luatex --fmt=%s --lua=%s  %s",
                string.quote(formatfile), string.quote(scriptfile), string.quote(filename))
            logs.simple("running command: %s",command)
            os.spawn(command)
        elseif formatname then
            logs.simple("error, no format found with name: %s",formatname)
        else
            logs.simple("error, no format found (provide formatname or interface)")
        end
    end
end

function scripts.metatex.timed(action)
    statistics.timed(action)
end

logs.extendbanner("MetaTeX Process Management 0.10",true)

messages.help = [[
--run                 process (one or more) files (default action)
--make                create metatex format(s)
]]

if environment.argument("run") then
    scripts.metatex.timed(scripts.metatex.run)
elseif environment.argument("make") then
    scripts.metatex.timed(scripts.metatex.make)
elseif environment.argument("help") then
    logs.help(messages.help,false)
elseif environment.files[1] then
    scripts.metatex.timed(scripts.metatex.run)
else
    logs.help(messages.help,false)
end

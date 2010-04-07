if not modules then modules = { } end modules ['mtx-tools'] = {
    version   = 1.002,
    comment   = "companion to mtxrun.lua",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local find, format, sub, rep, gsub, lower = string.find, string.format, string.sub, string.rep, string.gsub, string.lower

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

function scripts.tools.downcase()
    local pattern = environment.argument('pattern') or "*"
    local recurse = environment.argument('recurse')
    local force   = environment.argument('force')
    local n = 0
    if recurse and not find(pattern,"^%*%*%/") then
        pattern = "**/*" .. pattern
    end
    dir.glob(pattern,function(name)
        local basename = file.basename(name)
        if lower(basename) ~= basename then
            n = n + 1
            if force then
                os.rename(name,lower(name))
            end
        end
    end)
    if n > 0 then
        if force then
            logs.simple("%s files renamed",n)
        else
            logs.simple("use --force to do a real rename (%s files involved)",n)
        end
    else
        logs.simple("nothing to do")
    end
end


function scripts.tools.dirtoxml()

    local join, removesuffix, extname, date = file.join, file.removesuffix, file.extname, os.date

    local xmlns      = "http://www.pragma-ade.com/rlg/xmldir.rng"
    local timestamp  = "%Y-%m-%d %H:%M"

    local pattern    = environment.argument('pattern') or ".*"
    local url        = environment.argument('url')     or "no-url"
    local root       = environment.argument('root')    or "."
    local outputfile = environment.argument('output')

    local recurse    = environment.argument('recurse')
    local stripname  = environment.argument('stripname')
    local longname   = environment.argument('longname')

    local function flush(list,result,n,path)
        n, result = n or 1, result or { }
        local d = rep("  ",n)
        for name, attr in table.sortedpairs(list) do
            local mode = attr.mode
            if mode == "file" then
                result[#result+1] = format("%s<file name='%s'>",d,(longname and path and join(path,name)) or name)
                result[#result+1] = format("%s  <base>%s</base>",d,removesuffix(name))
                result[#result+1] = format("%s  <type>%s</type>",d,extname(name))
                result[#result+1] = format("%s  <size>%s</size>",d,attr.size)
                result[#result+1] = format("%s  <permissions>%s</permissions>",d,sub(attr.permissions,7,9))
                result[#result+1] = format("%s  <date>%s</date>",d,date(timestamp,attr.modification))
                result[#result+1] = format("%s</file>",d)
            elseif mode == "directory" then
                result[#result+1] = format("%s<directory name='%s'>",d,name)
                flush(attr.list,result,n+1,(path and join(path,name)) or name)
                result[#result+1] = format("%s</directory>",d)
            end
        end
    end

    if not pattern or pattern == ""  then
        logs.report('provide --pattern=')
        return
    end

    if stripname then
        pattern = file.dirname(pattern)
    end

    local luapattern = string.topattern(pattern,true)

    lfs.chdir(root)

    local list = dir.collect_pattern(root,luapattern,recurse)

    if list[outputfile] then
        list[outputfile] = nil
    end

    local result = { "<?xml version='1.0'?>" }
    result[#result+1] = format("<files url=%q root=%q pattern=%q luapattern=%q xmlns='%s' timestamp='%s'>",url,root,pattern,luapattern,xmlns,date(timestamp))
    flush(list,result)
    result[#result+1] = "</files>"

    result = table.concat(result,"\n")

    if not outputfile or outputfile == "" then
        texio.write_nl(result)
    else
        io.savedata(outputfile,result)
    end

end

logs.extendbanner("Some File Related Goodies 1.01",true)

messages.help = [[
--disarmutfbomb       remove utf bomb if present
    --force             remove indeed

--dirtoxml              glob directory into xml
    --pattern           glob pattern (default: *)
    --url               url attribute (no processing)
    --root              the root of the globbed path (default: .)
    --output            output filename (console by default)
    --recurse           recurse into subdirecories
    --stripname         take pathpart of given pattern
    --longname          set name attributes to full path name

--downcase
    --pattern           glob pattern (default: *)
    --recurse           recurse into subdirecories
    --force             downcase indeed
]]

if environment.argument("disarmutfbomb") then
    scripts.tools.disarmutfbomb()
elseif environment.argument("dirtoxml") then
    scripts.tools.dirtoxml()
elseif environment.argument("downcase") then
    scripts.tools.downcase()
else
    logs.help(messages.help)
end

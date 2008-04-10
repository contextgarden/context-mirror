if not modules then modules = { } end modules ['mtx-context'] = {
    version   = 1.001,
    comment   = "companion to mtxrun.lua",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

texmf.instance = instance -- we need to get rid of this / maybe current instance in global table

scripts         = scripts         or { }
scripts.context = scripts.context or { }

-- l-file / todo

function file.needsupdate(oldfile,newfile)
    return true
end
function file.syncmtimes(oldfile,newfile)
end

-- l-io

function io.copydata(fromfile,tofile)
    io.savedata(tofile,io.loaddata(fromfile) or "")
end

-- luat-inp

function input.locate_format(name) -- move this to core / luat-xxx
    local barename, fmtname = name:gsub("%.%a+$",""), ""
    if input.usecache then
        local path = file.join(caches.setpath(instance,"formats")) -- maybe platform
        fmtname = file.join(path,barename..".fmt") or ""
    end
    if fmtname == "" then
        fmtname = input.find_files(instance,barename..".fmt")[1] or ""
    end
    fmtname = input.clean_path(fmtname)
    if fmtname ~= "" then
        barename = fmtname:gsub("%.%a+$","")
        local luaname, lucname = barename .. ".lua", barename .. ".luc"
        if io.exists(lucname) then
            return barename, luaname
        elseif io.exists(luaname) then
            return barename, luaname
        end
    end
    return nil, nil
end

-- ctx

ctxrunner = { }

do

    function ctxrunner.filtered(str,method)
        str = tostring(str)
        if     method == 'name'     then str = file.removesuffix(file.basename(str))
        elseif method == 'path'     then str = file.dirname(str)
        elseif method == 'suffix'   then str = file.extname(str)
        elseif method == 'nosuffix' then str = file.removesuffix(str)
        elseif method == 'nopath'   then str = file.basename(str)
        elseif method == 'base'     then str = file.basename(str)
    --  elseif method == 'full'     then
    --  elseif method == 'complete' then
    --  elseif method == 'expand'   then -- str = file.expand_path(str)
        end
        return str:gsub("\\","/")
    end

    function ctxrunner.substitute(e,str)
        local attributes = e.at
        if str and attributes then
            if attributes['method'] then
                str = ctxrunner.filtered(str,attributes['method'])
            end
            if str == "" and attributes['default'] then
                str = attributes['default']
            end
        end
        return str
    end

    function ctxrunner.reflag(flags)
        local t = { }
        for _, flag in pairs(flags) do
            local key, value = flag:match("^(.-)=(.+)$")
            if key and value then
                t[key] = value
            else
                t[flag] = true
            end
        end
        return t
    end

    function ctxrunner.substitute(str)
        return str
    end

    function ctxrunner.justtext(str)
        str = xml.unescaped(tostring(str))
        str = xml.cleansed(str)
        str = str:gsub("\\+",'/')
        str = str:gsub("%s+",' ')
        return str
    end

    function ctxrunner.new()
        return {
            ctxname      = "",
            jobname      = "",
            xmldata      = nil,
            suffix       = "prep",
            locations    = { '..', '../..' },
            variables    = { },
            messages     = { },
            environments = { },
            modules      = { },
            filters      = { },
            flags        = { },
            modes        = { },
            prepfiles    = { },
            paths        = { },
        }
    end

    function ctxrunner.savelog(ctxdata,ctlname)
        local function yn(b)
            if b then return 'yes' else return 'no' end
        end
        if not ctlname or ctlname == "" or ctlname == ctxdata.jobname then
            if ctxdata.jobname then
                ctlname = file.replacesuffix(ctxdata.jobname,'ctl')
            elseif ctxdata.ctxname then
                ctlname = file.replacesuffix(ctxdata.ctxname,'ctl')
            else
                input.report(string.format("invalid ctl name %s",ctlname or "?"))
                return
            end
        end
        if table.is_empty(ctxdata.prepfiles) then
            input.report("nothing prepared, no ctl file saved")
            os.remove(ctlname)
        else
            input.report(string.format("saving logdata in %s",ctlname))
            f = io.open(ctlname,'w')
            if f then
                f:write("<?xml version='1.0' standalone='yes'?>\n\n")
                f:write(string.format("<ctx:preplist local='%s'>\n",yn(ctxdata.runlocal)))
--~                 for name, value in pairs(ctxdata.prepfiles) do
                for _, name in ipairs(table.sortedkeys(ctxdata.prepfiles)) do
                    f:write(string.format("\t<ctx:prepfile done='%s'>%s</ctx:prepfile>\n",yn(ctxdata.prepfiles[name]),name))
                end
                f:write("</ctx:preplist>\n")
                f:close()
            end
        end
    end

    function ctxrunner.register_path(ctxdata,path)
        -- test if exists
        ctxdata.paths[ctxdata.paths+1] = path
    end

    function ctxrunner.trace(ctxdata)
        print(table.serialize(ctxdata.messages))
        print(table.serialize(ctxdata.flags))
        print(table.serialize(ctxdata.environments))
        print(table.serialize(ctxdata.modules))
        print(table.serialize(ctxdata.filters))
        print(table.serialize(ctxdata.modes))
        print(xml.serialize(ctxdata.xmldata))
    end

    function ctxrunner.manipulate(ctxdata,ctxname,defaultname)

        if not ctxdata.jobname or ctxdata.jobname == "" then
            return
        end

        ctxdata.ctxname = ctxname or file.removesuffix(ctxdata.jobname) or ""

        if ctxdata.ctxname == "" then
            return
        end

        ctxdata.jobname = file.addsuffix(ctxdata.jobname,'tex')
        ctxdata.ctxname = file.addsuffix(ctxdata.ctxname,'ctx')

        input.report("jobname:",ctxdata.jobname)
        input.report("ctxname:",ctxdata.ctxname)

        -- mtxrun should resolve kpse: and file:

        local usedname = ctxdata.ctxname
        local found    = io.exists(usedname)

        if not found then
            for _, path in pairs(ctxdata.locations) do
                local fullname = file.join(path,ctxdata.ctxname)
                if io.exists(fullname) then
                    usedname, found = fullname, true
                    break
                end
            end
        end

        if not found and defaultname and defaultname ~= "" and file.exists(defaultname) then
            usedname, found = defaultname, true
        end

        if not found then
            return
        end

        ctxdata.xmldata = xml.load(usedname)

        if not ctxdata.xmldata then
            return
        else
            -- test for valid, can be text file
        end

        xml.include(ctxdata.xmldata,'ctx:include','name', table.append({'.', file.dirname(ctxdata.ctxname)},ctxdata.locations))

        ctxdata.variables['job'] = ctxdata.jobname

        ctxdata.flags        = xml.collect_texts(ctxdata.xmldata,"/ctx:job/ctx:flags/ctx:flag",true)
        ctxdata.environments = xml.collect_texts(ctxdata.xmldata,"/ctx:job/ctx:process/ctx:resources/ctx:environment",true)
        ctxdata.modules      = xml.collect_texts(ctxdata.xmldata,"/ctx:job/ctx:process/ctx:resources/ctx:module",true)
        ctxdata.filters      = xml.collect_texts(ctxdata.xmldata,"/ctx:job/ctx:process/ctx:resources/ctx:filter",true)
        ctxdata.modes        = xml.collect_texts(ctxdata.xmldata,"/ctx:job/ctx:process/ctx:resources/ctx:mode",true)
        ctxdata.messages     = xml.collect_texts(ctxdata.xmldata,"ctx:message",true)

        ctxdata.flags = ctxrunner.reflag(ctxdata.flags)

        for _, message in ipairs(ctxdata.messages) do
        -- message ctxdata.justtext(xml.tostring(message))
        end

        --~ REXML::XPath.each(root,"//ctx:block") do |blk|
        --~     if @jobname && blk.attributes['pattern'] then
        --~         root.delete(blk) unless @jobname =~ /#{blk.attributes['pattern']}/
        --~     else
        --~         root.delete(blk)
        --~     end
        --~ end

        xml.each(ctxdata.xmldata,"ctx:value[@name='job']", function(ek,e,k)
            e[k] = ctxdata.variables['job'] or ""
        end)

        local commands = { }
        xml.each(ctxdata.xmldata,"/ctx:job/ctx:preprocess/ctx:processors/ctx:processor", function(r,d,k)
            local ek = d[k]
            commands[ek.at and ek.at['name'] or "unknown"] = ek
        end)

        local suffix   = xml.first(ctxdata.xmldata,"/ctx:job/ctx:preprocess/@suffix") or ctxdata.suffix
        local runlocal = xml.first(ctxdata.xmldata,"/ctx:job/ctx:preprocess/ctx:processors/@local")

        runlocal = toboolean(runlocal)

        for _, files in ipairs(xml.filters.elements(ctxdata.xmldata,"/ctx:job/ctx:preprocess/ctx:files")) do
            for _, pattern in ipairs(xml.filters.elements(files,"ctx:file")) do

                preprocessor = pattern.at['processor'] or ""

                if preprocessor ~= "" then

                    ctxdata.variables['old'] = ctxdata.jobname
                    xml.each(ctxdata.xmldata,"ctx:value", function(r,d,k)
                        local ek = d[k]
                        local ekat = ek.at['name']
                        if ekat == 'old' then
                            d[k] = ctxrunner.substitute(ctxdata.variables[ekat] or "")
                        end
                    end)

                    pattern = ctxrunner.justtext(xml.tostring(pattern))

                    local oldfiles = dir.glob(pattern)
                    local pluspath = false
                    if #oldfiles == 0 then
                        -- message: no files match pattern
                        for _, p in ipairs(ctxdata.paths) do
                            local oldfiles = dir.glob(path.join(p,pattern))
                            if #oldfiles > 0 then
                                pluspath = true
                                break
                            end
                        end
                    end
                    if #oldfiles == 0 then
                        -- message: no old files
                    else
                        for _, oldfile in ipairs(oldfiles) do
                            newfile = oldfile .. "." .. suffix -- addsuffix will add one only
                            if ctxdata.runlocal then
                                newfile = file.basename(newfile)
                            end
                            if oldfile ~= newfile and file.needsupdate(oldfile,newfile) then
                            --  message: oldfile needs preprocessing
                            --  os.remove(newfile)
                                for _, pp in ipairs(preprocessor:split(',')) do
                                    local command = commands[pp]
                                    if command then
                                        command = xml.copy(command)
                                        local suf = (command.at and command.at['suffix']) or ctxdata.suffix
                                        if suf then
                                            newfile = oldfile .. "." .. suf
                                        end
                                        if ctxdata.runlocal then
                                            newfile = file.basename(newfile)
                                        end
                                        xml.each(command,"ctx:old", function(r,d,k)
                                            d[k] = ctxrunner.substitute(oldfile)
                                        end)
                                        xml.each(command,"ctx:new", function(r,d,k)
                                            d[k] = ctxrunner.substitute(newfile)
                                        end)
                                        --  message: preprocessing #{oldfile} into #{newfile} using #{pp}
                                        ctxdata.variables['old'] = oldfile
                                        ctxdata.variables['new'] = newfile
                                        xml.each(command,"ctx:value", function(r,d,k)
                                            local ek = d[k]
                                            local ekat = ek.at and ek.at['name']
                                            if ekat then
                                                d[k] = ctxrunner.substitute(ctxdata.variables[ekat] or "")
                                            end
                                        end)
                                        -- potential optimization: when mtxrun run internal
                                        command = ctxrunner.justtext(command) -- command is still xml element here
                                        input.report("command",command)
                                        local result = os.spawn(command)
                                        if result > 0 then
                                            input.report("error, return code",result)
                                        end
                                        if ctxdata.runlocal then
                                            oldfile = file.basename(oldfile)
                                        end
                                    end
                                end
                                if io.exists(newfile) then
                                    file.syncmtimes(oldfile,newfile)
                                    ctxdata.prepfiles[oldfile] = true
                                else
                                    input.report("error, check target location of new file", newfile)
                                    ctxdata.prepfiles[oldfile] = false
                                end
                            else
                                input.report("old file needs no preprocessing")
                                ctxdata.prepfiles[oldfile] = io.exists(newfile)
                            end
                        end
                    end
                end
            end
        end

        ctxrunner.savelog(ctxdata)

    end

end

-- rest

scripts.context.multipass = {
    suffixes = { ".tuo", ".tuc" },
    nofruns = 8,
}

function scripts.context.multipass.hashfiles(jobname)
    local hash = { }
    for _, suffix in ipairs(scripts.context.multipass.suffixes) do
        local full = jobname .. suffix
        hash[full] = md5.hex(io.loaddata(full) or "unknown")
    end
    return hash
end

function scripts.context.multipass.changed(oldhash, newhash)
    for k,v in pairs(oldhash) do
        if v ~= newhash[k] then
            return true
        end
    end
    return false
end

scripts.context.backends = {
    pdftex = 'pdftex',
    luatex = 'pdftex',
    pdf    = 'pdftex',
    dvi    = 'dvipdfmx',
    dvips  = 'dvips'
}

function scripts.context.multipass.makeoptionfile(jobname,ctxdata)
    -- take jobname from ctx
    local f = io.open(jobname..".top","w")
    if f then
        local finalrun, kindofrun, currentrun = false, 0, 0
        local function someflag(flag)
            return (ctxdata and ctxdata.flags[flag]) or environment.argument(flag)
        end
--~         local someflag = environment.argument
        local function setvalue(flag,format,hash,default)
            local a = someflag(flag) or default
            if a and a ~= "" then
                if hash then
                    if hash[a] then
                        f:write(format:format(a),"\n")
                    end
                else
                    f:write(format:format(a),"\n")
                end
            end
        end
        local function setvalues(flag,format)
            if type(flag) == "table"  then
                for k, v in pairs(flag) do
                    f:write(format:format(v),"\n")
                end
            else
                local a = someflag(flag)
                if a and a ~= "" then
                    for v in a:gmatch("%s*([^,]+)") do
                        f:write(format:format(v),"\n")
                    end
                end
            end
        end
        local function setfixed(flag,format,...)
            if someflag(flag) then
                f:write(format:format(...),"\n")
            end
        end
        local function setalways(format,...)
            f:write(format:format(...),"\n")
        end
        setalways("\\unprotect")
        setvalue('output'       , "\\setupoutput[%s]", scripts.context.backends, 'pdftex')
        setalways(                "\\setupsystem[\\c!n=%s,\\c!m=%s]", kindofrun, currentrun)
        setalways(                "\\setupsystem[\\c!type=%s]",os.platform)
        setfixed ("batchmode"    , "\\batchmode")
        setfixed ("nonstopmode"  , "\\nonstopmode")
        setfixed ("tracefiles"   , "\\tracefilestrue")
        setfixed ("paranoid"     , "\\def\\maxreadlevel{1}")
        setvalues("modefile"     , "\\readlocfile{%s}{}{}")
        setvalue ("result"       , "\\setupsystem[file=%s]")
        setvalues("path"         , "\\usepath[%s]")
        setfixed ("color"        , "\\setupcolors[\\c!state=\\v!start]")
        setfixed ("nompmode"     , "\\runMPgraphicsfalse") -- obsolete, we assume runtime mp graphics
        setfixed ("nomprun"      , "\\runMPgraphicsfalse") -- obsolete, we assume runtime mp graphics
        setfixed ("automprun"    , "\\runMPgraphicsfalse") -- obsolete, we assume runtime mp graphics
        setfixed ("fast"         , "\\fastmode\n")
        setfixed ("silentmode"   , "\\silentmode\n")
        setvalue ("separation"   , "\\setupcolors[\\c!split=%s]")
        setvalue ("setuppath"    , "\\setupsystem[\\c!directory={%s}]")
        setfixed ("noarrange"    , "\\setuparranging[\\v!disable]")
        if environment.argument('arrange') and not finalrun then
            setalways(             "\\setuparranging[\\v!disable]")
        end
        setvalue ("arguments"    , "\\setupenv[%s]")
        setvalue ("randomseed"   , "\\setupsystem[\\c!random=%s]")
        setvalues("modes"        , "\\enablemode[%s]")
        setvalues("mode"         , "\\enablemode[%s]")
        setvalues("filters"      , "\\useXMLfilter[%s]")
        setvalues("usemodules"   , "\\usemodule[%s]")
        setvalues("environments" , "\\environment %s ")
        -- ctx stuff
        if ctxdata then
            setvalues(ctxdata.modes,        "\\enablemode[%s]")
            setvalues(ctxdata.modules,      "\\usemodule[%s]")
            setvalues(ctxdata.environments, "\\environment %s ")
        end
        -- done
        setalways(                 "\\protect")
        setalways(                 "\\endinput")
        f:close()
    end
end

function scripts.context.multipass.copyluafile(jobname)
    io.savedata(jobname..".tuc",io.loaddata(jobname..".tua") or "")
end

function scripts.context.multipass.copytuifile(jobname)
    local f, g = io.open(jobname..".tui"), io.open(jobname..".tuo",'w')
    if f and g then
        g:write("% traditional utility file, only commands written by mtxrun/context\n%\n")
        for line in f:lines() do
            if line:find("^c ") then
                g:write((line:gsub("^c ","")),"%\n")
            end
        end
        g:write("\\endinput\n")
        f:close()
        g:close()
    end
end

scripts.context.xmlsuffixes = table.tohash {
    "xml",
}

function scripts.context.run(ctxdata)
    local function makestub(format,filename)
        local stubname = file.replacesuffix(file.basename(filename),'run')
        local f = io.open(stubname,'w')
        if f then
            f:write("\\starttext\n")
            f:write(string.format(format,filename),"\n")
            f:write("\\stoptext\n")
            f:close()
            filename = stubname
        end
        return filename
    end
    if ctxdata then
        -- todo: interface
        for k,v in pairs(ctxdata.flags) do
            environment.setargument(k,v)
        end
    end
    local files = environment.files
    if #files > 0 then
        input.identify_cnf(instance)
        input.load_cnf(instance)
        input.expand_variables(instance)
        local formatname = "cont-en"
        local formatfile, scriptfile = input.locate_format(formatname)
        if formatfile and scriptfile then
            for _, filename in ipairs(files) do
                local basename, pathname = file.basename(filename), file.dirname(filename)
                local jobname = file.removesuffix(basename)
                if pathname == "" then
                    filename = "./" .. filename
                end
                -- also other stubs
                if environment.argument("forcexml") or scripts.context.xmlsuffixes[file.extname(filename) or "?"] then -- mkii
                    filename = makestub("\\processXMLfilegrouped{%s}",filename)
                elseif environment.argument("processxml") then -- mkiv
                    filename = makestub("\\xmlprocess{%s}",filename)
                end
                --
                if environment.argument("autopdf") then
                    os.spawn(string.format('pdfclose --file "%s" 2>&1', file.replacesuffix(filename,"pdf")))
                end
                --
                local command = "luatex --fmt=" .. string.quote(formatfile) .. " --lua=" .. string.quote(scriptfile) .. " " .. string.quote(filename)
                local oldhash, newhash = scripts.context.multipass.hashfiles(jobname), { }
                scripts.context.multipass.makeoptionfile(jobname,ctxdata)
                for i=1, scripts.context.multipass.nofruns do
                    input.report(string.format("run %s: %s",i,command))
                    local returncode = os.spawn(command)
                    input.report("return code: " .. returncode)
                    if returncode > 0 then
                        input.report("fatal error, run aborted")
                        break
                    else
                        scripts.context.multipass.copyluafile(jobname)
                        scripts.context.multipass.copytuifile(jobname)
                        newhash = scripts.context.multipass.hashfiles(jobname)
                        if scripts.context.multipass.changed(oldhash,newhash) then
                            oldhash = newhash
                        else
                            break
                        end
                    end
                end
                --
                -- todo: result
                --
                if environment.argument("autopdf") then
                    os.spawn(string.format('pdfopen --file "%s" 2>&1', file.replacesuffix(filename,"pdf")))
                end
                --
            end
        else
            input.error("no format found with name " .. formatname)
        end
    end
end

function scripts.context.make()
    local list = (environment.files[1] and environment.files) or { "cont-en", "cont-nl", "mptopdf" }
    for _, name in ipairs(list) do
        local command = "luatools --make --compile " .. name
        input.report("running command: " .. command)
        os.spawn(command)
    end
end

function scripts.context.generate()
    -- hack, should also be a shared function
    local command = "luatools --generate "
    input.report("running command: " .. command)
    os.spawn(command)
end

function scripts.context.ctx()
    local ctxdata = ctxrunner.new()
    ctxdata.jobname = environment.files[1]
    ctxrunner.manipulate(ctxdata,environment.argument("ctx"))
    scripts.context.run(ctxdata)
end

banner = banner .. " | context tools "

messages.help = [[
--run                 process (one or more) files (default action)
--make                create context formats formats
--generate            generate file database etc.
--ctx=name            use ctx file
--autopdf             open pdf file afterwards
]]

input.verbose = true

input.starttiming(scripts.context)

if environment.argument("once") then
    scripts.context.multipass.nofruns = 1
end

if environment.argument("run") then
    scripts.context.run()
elseif environment.argument("make") then
    scripts.context.make()
elseif environment.argument("ctx") then
    scripts.context.ctx()
elseif environment.argument("help") then
    input.help(banner,messages.help)
elseif environment.files[1] then
    scripts.context.run()
else
    input.help(banner,messages.help)
end

input.stoptiming(scripts.context)
input.report("total runtime: " .. input.elapsedtime(scripts.context))

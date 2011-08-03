if not modules then modules = { } end modules ['mtx-context'] = {
    version   = 1.001,
    comment   = "companion to mtxrun.lua",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local format, gmatch, match, gsub, find = string.format, string.gmatch, string.match, string.gsub, string.find
local quote = string.quote
local concat = table.concat

local basicinfo = [[
--run                 process (one or more) files (default action)
--make                create context formats

--ctx=name            use ctx file (process management specification)
--interface           use specified user interface (default: en)

--autopdf             close pdf file in viewer and start pdf viewer afterwards
--purge(all)          purge files either or not after a run (--pattern=...)

--usemodule=list      load the given module or style, normally part o fthe distribution
--environment=list    load the given environment file first (document styles)
--mode=list           enable given the modes (conditional processing in styles)
--path=list           also consult the given paths when files are looked for
--arguments=list      set variables that can be consulted during a run (key/value pairs)
--randomseed=number   set the randomseed
--result=name         rename the resulting output to the given name
--trackers=list       set tracker variables (show list with --showtrackers)
--directives=list     set directive variables (show list with --showdirectives)
--silent=list         disable logcatgories (show list with --showlogcategories)
--noconsole           disable logging to the console (logfile only)
--purgeresult         purge result file before run

--forcexml            force xml stub (optional flag: --mkii)
--forcecld            force cld (context lua document) stub

--arrange             run extra imposition pass, given that the style sets up imposition
--noarrange           ignore imposition specifications in the style

--once                only run once (no multipass data file is produced)
--batchmode           run without stopping and don't show messages on the console
--nonstopmode         run without stopping

--generate            generate file database etc. (as luatools does)
--paranoid            don't descend to .. and ../..
--version             report installed context version

--expert              expert options
]]

-- filter=list      is kind of obsolete
-- color            is obsolete for mkiv, always on
-- separation       is obsolete for mkiv, no longer available
-- output           is currently obsolete for mkiv
-- setuppath=list   must check
-- modefile=name    must check
-- input=name   load the given inputfile (must check)

local expertinfo = [[
expert options:

--touch               update context version number (remake needed afterwards, also provide --expert)
--nostats             omit runtime statistics at the end of the run
--update              update context from website (not to be confused with contextgarden)
--profile             profile job (use: mtxrun --script profile --analyze)
--timing              generate timing and statistics overview

--extra=name          process extra (mtx-context-<name> in distribution)
--extras              show extras
]]

local specialinfo = [[
special options:

--pdftex              process file with texexec using pdftex
--xetex               process file with texexec using xetex

--pipe                don't check for file and enter scroll mode (--dummyfile=whatever.tmp)
]]

local application = logs.application {
    name     = "mtx-context",
    banner   = "ConTeXt Process Management 0.52",
    helpinfo = {
        basic  = basicinfo,
        extra  = extrainfo,
        expert = expertinfo,
    }
}

local report = application.report

scripts         = scripts         or { }
scripts.context = scripts.context or { }

-- a demo cld file:
--
-- context.starttext()
-- context.chapter("Hello There")
-- context.readfile("tufte","","not found")
-- context.stoptext()

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

-- ctx (will become util-ctx)

local ctxrunner = { }

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
--  elseif method == 'expand'   then -- str = file.expandpath(str)
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
    for _, flag in next, flags do
        local key, value = match(flag,"^(.-)=(.+)$")
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
            report("invalid ctl name: %s",ctlname or "?")
            return
        end
    end
    local prepfiles = ctxdata.prepfiles
    if prepfiles and next(prepfiles) then
        report("saving logdata in: %s",ctlname)
        f = io.open(ctlname,'w')
        if f then
            f:write("<?xml version='1.0' standalone='yes'?>\n\n")
            f:write(format("<ctx:preplist local='%s'>\n",yn(ctxdata.runlocal)))
            local sorted = table.sortedkeys(prepfiles)
            for i=1,#sorted do
                local name = sorted[i]
                f:write(format("\t<ctx:prepfile done='%s'>%s</ctx:prepfile>\n",yn(prepfiles[name]),name))
            end
            f:write("</ctx:preplist>\n")
            f:close()
        end
    else
        report("nothing prepared, no ctl file saved")
        os.remove(ctlname)
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
    print(xml.tostring(ctxdata.xmldata))
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

    report("jobname: %s",ctxdata.jobname)
    report("ctxname: %s",ctxdata.ctxname)

    -- mtxrun should resolve kpse: and file:

    local usedname = ctxdata.ctxname
    local found    = lfs.isfile(usedname)

    -- no futher test if qualified path

    if not found then
        for _, path in next, ctxdata.locations do
            local fullname = file.join(path,ctxdata.ctxname)
            if lfs.isfile(fullname) then
                usedname, found = fullname, true
                break
            end
        end
    end

    if not found then
        usedname = resolvers.findfile(ctxdata.ctxname,"tex")
        found = usedname ~= ""
    end

    if not found and defaultname and defaultname ~= "" and lfs.isfile(defaultname) then
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

    local messages = ctxdata.messages
    for i=1,#messages do
        report("ctx comment: %s", xml.tostring(messages[i]))
    end

    for r, d, k in xml.elements(ctxdata.xmldata,"ctx:value[@name='job']") do
        d[k] = ctxdata.variables['job'] or ""
    end

    local commands = { }
    for e in xml.collected(ctxdata.xmldata,"/ctx:job/ctx:preprocess/ctx:processors/ctx:processor") do
        commands[e.at and e.at['name'] or "unknown"] = e
    end

    local suffix   = xml.filter(ctxdata.xmldata,"/ctx:job/ctx:preprocess/attribute('suffix')") or ctxdata.suffix
    local runlocal = xml.filter(ctxdata.xmldata,"/ctx:job/ctx:preprocess/ctx:processors/attribute('local')")

    runlocal = toboolean(runlocal)

    for files in xml.collected(ctxdata.xmldata,"/ctx:job/ctx:preprocess/ctx:files") do
        for pattern in xml.collected(files,"ctx:file") do

            preprocessor = pattern.at['processor'] or ""

            if preprocessor ~= "" then

                ctxdata.variables['old'] = ctxdata.jobname
                for r, d, k in xml.elements(ctxdata.xmldata,"ctx:value") do
                    local ek = d[k]
                    local ekat = ek.at['name']
                    if ekat == 'old' then
                        d[k] = ctxrunner.substitute(ctxdata.variables[ekat] or "")
                    end
                end

                pattern = ctxrunner.justtext(xml.tostring(pattern))

                local oldfiles = dir.glob(pattern)

                local pluspath = false
                if #oldfiles == 0 then
                    -- message: no files match pattern
                    local paths = ctxdata.paths
                    for i=1,#paths do
                        local p = paths[i]
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
                    for i=1,#oldfiles do
                        local oldfile = oldfiles[i]
                        local newfile = oldfile .. "." .. suffix -- addsuffix will add one only
                        if ctxdata.runlocal then
                            newfile = file.basename(newfile)
                        end
                        if oldfile ~= newfile and file.needsupdate(oldfile,newfile) then
                        --  message: oldfile needs preprocessing
                        --  os.remove(newfile)
                            local splitted = preprocessor:split(',')
                            for i=1,#splitted do
                                local pp = splitted[i]
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
                                    for r, d, k in xml.elements(command,"ctx:old") do
                                        d[k] = ctxrunner.substitute(oldfile)
                                    end
                                    for r, d, k in xml.elements(command,"ctx:new") do
                                        d[k] = ctxrunner.substitute(newfile)
                                    end
                                    ctxdata.variables['old'] = oldfile
                                    ctxdata.variables['new'] = newfile
                                    for r, d, k in xml.elements(command,"ctx:value") do
                                        local ek = d[k]
                                        local ekat = ek.at and ek.at['name']
                                        if ekat then
                                            d[k] = ctxrunner.substitute(ctxdata.variables[ekat] or "")
                                        end
                                    end
                                    -- potential optimization: when mtxrun run internal
                                    command = xml.content(command)
                                    command = ctxrunner.justtext(command)
                                    report("command: %s",command)
                                    local result = os.spawn(command) or 0
                                    -- somehow we get the wrong return value
                                    if result > 0 then
                                        report("error, return code: %s",result)
                                    end
                                    if ctxdata.runlocal then
                                        oldfile = file.basename(oldfile)
                                    end
                                end
                            end
                            if lfs.isfile(newfile) then
                                file.syncmtimes(oldfile,newfile)
                                ctxdata.prepfiles[oldfile] = true
                            else
                                report("error, check target location of new file: %s", newfile)
                                ctxdata.prepfiles[oldfile] = false
                            end
                        else
                            report("old file needs no preprocessing")
                            ctxdata.prepfiles[oldfile] = lfs.isfile(newfile)
                        end
                    end
                end
            end
        end
    end

    ctxrunner.savelog(ctxdata)

end

function ctxrunner.preppedfile(ctxdata,filename)
    if ctxdata.prepfiles[file.basename(filename)] then
        return filename .. ".prep"
    else
        return filename
    end
end

-- rest

scripts.context.multipass = {
--  suffixes = { ".tuo", ".tuc" },
    suffixes = { ".tuc" },
    nofruns = 8,
}

function scripts.context.multipass.hashfiles(jobname)
    local hash = { }
    local suffixes = scripts.context.multipass.suffixes
    for i=1,#suffixes do
        local suffix = suffixes[i]
        local full = jobname .. suffix
        hash[full] = md5.hex(io.loaddata(full) or "unknown")
    end
    return hash
end

function scripts.context.multipass.changed(oldhash, newhash)
    for k,v in next, oldhash do
        if v ~= newhash[k] then
            return true
        end
    end
    return false
end

function scripts.context.multipass.makeoptionfile(jobname,ctxdata,kindofrun,currentrun,finalrun)
    -- take jobname from ctx
    jobname = file.removesuffix(jobname)
    local f = io.open(jobname..".top","w")
    if f then
        local function someflag(flag)
            return (ctxdata and ctxdata.flags[flag]) or environment.argument(flag)
        end
        local function setvalue(flag,template,hash,default)
            local a = someflag(flag) or default
            if a and a ~= "" then
                if hash then
                    if hash[a] then
                        f:write(format(template,a),"\n")
                    end
                else
                    f:write(format(template,a),"\n")
                end
            end
        end
        local function setvalues(flag,template,plural)
            if type(flag) == "table"  then
                for k, v in next, flag do
                    f:write(format(template,v),"\n")
                end
            else
                local a = someflag(flag) or (plural and someflag(flag.."s"))
                if a and a ~= "" then
                    for v in gmatch(a,"%s*([^,]+)") do
                        f:write(format(template,v),"\n")
                    end
                end
            end
        end
        local function setfixed(flag,template,...)
            if someflag(flag) then
                f:write(format(template,...),"\n")
            end
        end
        local function setalways(template,...)
            f:write(format(template,...),"\n")
        end
        --
        -- This might change ... we can just pass the relevant flags directly.
        --
        setalways("%% runtime options files (command line driven)")
        --
        setalways("\\unprotect")
        --
        setalways("%% feedback and basic job control")
        --
        -- Option file, we can pass more on the commandline some day soon. Actually we
        -- should use directives and trackers.
        --
        setfixed ("timing"       , "\\usemodule[timing]")
        setfixed ("batchmode"    , "\\batchmode")
        setfixed ("batch"        , "\\batchmode")
        setfixed ("nonstopmode"  , "\\nonstopmode")
        setfixed ("nonstop"      , "\\nonstopmode")
     -- setfixed ("tracefiles"   , "\\tracefilestrue")
        setfixed ("nostats"      , "\\nomkivstatistics")
        setfixed ("paranoid"     , "\\def\\maxreadlevel{1}")
        --
        setalways("%% handy for special styles")
        --
        setalways("\\startluacode")
        setalways("document = document or { }")
        setalways(table.serialize(environment.arguments, "document.arguments"))
        setalways(table.serialize(environment.files,     "document.files"))
        setalways("\\stopluacode")
        --
        setalways("%% process info")
        --
        setalways(                 "\\setupsystem[inputfile=%s]",environment.argument("input") or environment.files[1] or "\\jobname")
        setvalue ("result"       , "\\setupsystem[file=%s]")
        setalways(                 "\\setupsystem[\\c!n=%s,\\c!m=%s]", kindofrun or 0, currentrun or 0)
        setvalues("path"         , "\\usepath[%s]")
        setvalue ("setuppath"    , "\\setupsystem[\\c!directory={%s}]")
        setvalue ("randomseed"   , "\\setupsystem[\\c!random=%s]")
        setvalue ("arguments"    , "\\setupenv[%s]")
        setalways("%% modes")
        setvalues("modefile"     , "\\readlocfile{%s}{}{}")
        setvalues("mode"         , "\\enablemode[%s]", true)
        if ctxdata then
            setvalues(ctxdata.modes, "\\enablemode[%s]")
        end
        --
        setalways("%% options (not that important)")
        --
        setalways("\\startsetups *runtime:options")
        setfixed ("color"        , "\\setupcolors[\\c!state=\\v!start]")
        setvalue ("separation"   , "\\setupcolors[\\c!split=%s]")
        setfixed ("noarrange"    , "\\setuparranging[\\v!disable]")
        if environment.argument('arrange') and not finalrun then
            setalways(             "\\setuparranging[\\v!disable]")
        end
        setalways("\\stopsetups")
        --
        setalways("%% styles and modules")
        --
        setalways("\\startsetups *runtime:modules")
        setvalues("usemodule"    , "\\usemodule[%s]", true)
        setvalues("environment"  , "\\environment %s ", true)
        if ctxdata then
            setvalues(ctxdata.modules,      "\\usemodule[%s]")
            setvalues(ctxdata.environments, "\\environment %s ")
        end
        setalways("\\stopsetups")
        --
        setalways("%% done")
        --
        setalways("\\protect \\endinput")
        f:close()
    end
end

function scripts.context.multipass.copyluafile(jobname)
    local tuaname, tucname = jobname..".tua", jobname..".tuc"
    if lfs.isfile(tuaname) then
        os.remove(tucname)
        os.rename(tuaname,tucname)
    end
end

scripts.context.cldsuffixes = table.tohash {
    "cld",
}

scripts.context.xmlsuffixes = table.tohash {
    "xml",
}

scripts.context.luasuffixes = table.tohash {
    "lua",
}

scripts.context.beforesuffixes = {
    "tuo", "tuc"
}
scripts.context.aftersuffixes = {
    "pdf", "tuo", "tuc", "log"
}

scripts.context.interfaces = {
    en = "cont-en",
    uk = "cont-uk",
    de = "cont-de",
    fr = "cont-fr",
    nl = "cont-nl",
    cz = "cont-cz",
    it = "cont-it",
    ro = "cont-ro",
    pe = "cont-pe",
}

scripts.context.defaultformats  = {
    "cont-en",
    "cont-nl",
--  "mptopdf", -- todo: mak emkiv variant
--  "metatex", -- will show up soon
--  "metafun", -- todo: mp formats
--  "plain"
}

local function analyze(filename) -- only files on current path
    local f = io.open(file.addsuffix(filename,"tex"))
    if f then
        local t = { }
        local line = f:read("*line") or ""
        -- there can be an utf bomb in front: \254\255 or \255\254
        -- a template line starts with % or %% (used in asciimode) followed by one or more spaces
        local preamble = match(line,"^[\254\255]*%%%%?%s+(.+)$")
        if preamble then
            for key, value in gmatch(preamble,"(%S+)%s*=%s*(%S+)") do
                t[key] = value
            end
            t.type = "tex"
        elseif line:find("^<?xml ") then
            t.type = "xml"
        end
        if t.nofruns then
            scripts.context.multipass.nofruns = t.nofruns
        end
        if not t.engine then
            t.engine = 'luatex'
        end
        f:close()
        return t
    end
end

local function makestub(wrap,template,filename,prepname)
    local stubname = file.replacesuffix(file.basename(filename),'run')
    local f = io.open(stubname,'w')
    if f then
        if wrap then
            f:write("\\starttext\n")
        end
        f:write(format(template,prepname or filename),"\n")
        if wrap then
            f:write("\\stoptext\n")
        end
        f:close()
        filename = stubname
    end
    return filename
end

--~ function scripts.context.openpdf(name)
--~     os.spawn(format('pdfopen --file "%s" 2>&1', file.replacesuffix(name,"pdf")))
--~ end
--~ function scripts.context.closepdf(name)
--~     os.spawn(format('pdfclose --file "%s" 2>&1', file.replacesuffix(name,"pdf")))
--~ end

local pdfview -- delayed loading

function scripts.context.openpdf(name,method)
    pdfview = pdfview or dofile(resolvers.findfile("l-pdfview.lua","tex"))
    pdfview.setmethod(method)
    report(pdfview.status())
    pdfview.open(file.replacesuffix(name,"pdf"))
end

function scripts.context.closepdf(name,method)
    pdfview = pdfview or dofile(resolvers.findfile("l-pdfview.lua","tex"))
    pdfview.setmethod(method)
    pdfview.close(file.replacesuffix(name,"pdf"))
end

function scripts.context.run(ctxdata,filename)
    -- filename overloads environment.files
    local files = (filename and { filename }) or environment.files
    if ctxdata then
        -- todo: interface
        for k,v in next, ctxdata.flags do
            environment.setargument(k,v)
        end
    end
    if #files > 0 then
        --
        local interface = environment.argument("interface")
        -- todo: environment.argument("interface","en")
        interface = (type(interface) == "string" and interface) or "en"
        --
        local formatname = scripts.context.interfaces[interface] or "cont-en"
        local formatfile, scriptfile = resolvers.locateformat(formatname)
        -- this catches the command line
        if not formatfile or not scriptfile then
            report("warning: no format found, forcing remake (commandline driven)")
            scripts.context.make(formatname)
            formatfile, scriptfile = resolvers.locateformat(formatname)
        end
        --
        if formatfile and scriptfile then
            for i=1,#files do
                local filename = files[i]
                local basename, pathname = file.basename(filename), file.dirname(filename)
                local jobname = file.removesuffix(basename)
                if pathname == "" and not environment.argument("global") then
                    filename = "./" .. filename
                end
                -- look at the first line
                local a = analyze(filename)
                if a and (a.engine == 'pdftex' or a.engine == 'xetex' or environment.argument("pdftex") or environment.argument("xetex")) then
                    if false then
                        -- we need to write a top etc too and run mp etc so it's not worth the
                        -- trouble, so it will take a while before the next is finished
                        --
                        -- require "mtx-texutil.lua"
                    else
                        local texexec = resolvers.findfile("texexec.rb") or ""
                        if texexec ~= "" then
                            os.setenv("RUBYOPT","")
                            local options = environment.reconstructcommandline(environment.arguments_after)
                            options = gsub(options,"--purge","")
                            options = gsub(options,"--purgeall","")
                            local command = format("ruby %s %s",texexec,options)
                            if environment.argument("purge") then
                                os.execute(command)
                                scripts.context.purge_job(filename,false,true)
                            elseif environment.argument("purgeall") then
                                os.execute(command)
                                scripts.context.purge_job(filename,true,true)
                            else
                                os.exec(command)
                            end
                        end
                    end
                else
                    if a and a.interface and a.interface ~= interface then
                        formatname = scripts.context.interfaces[a.interface] or formatname
                        formatfile, scriptfile = resolvers.locateformat(formatname)
                    end
                    -- this catches the command line
                    if not formatfile or not scriptfile then
                        report("warning: no format found, forcing remake (source driven)")
                        scripts.context.make(formatname)
                        formatfile, scriptfile = resolvers.locateformat(formatname)
                    end
                    if formatfile and scriptfile then
                        -- we default to mkiv xml !
                        -- the --prep argument might become automatic (and noprep)
                        local suffix = file.extname(filename) or "?"
                        if scripts.context.xmlsuffixes[suffix] or environment.argument("forcexml") then
                            if environment.argument("mkii") then
                                filename = makestub(true,"\\processXMLfilegrouped{%s}",filename)
                            else
                                filename = makestub(true,"\\xmlprocess{\\xmldocument}{%s}{}",filename)
                            end
                        elseif scripts.context.cldsuffixes[suffix] or environment.argument("forcecld") then
                            -- self contained cld files need to have a starttext/stoptext (less fontloading)
                            filename = makestub(false,"\\ctxlua{context.runfile('%s')}",filename)
                        elseif scripts.context.luasuffixes[suffix] or environment.argument("forcelua") then
                            filename = makestub(true,"\\ctxlua{dofile('%s')}",filename)
                        elseif environment.argument("prep") then
                            -- we need to keep the original jobname
                            filename = makestub(true,"\\readfile{%s}{}{}",filename,ctxrunner.preppedfile(ctxdata,filename))
                        end
                        --
                        -- todo: also other stubs
                        --
                        local suffix, resultname = environment.argument("suffix"), environment.argument("result")
                        if type(suffix) == "string" then
                            resultname = file.removesuffix(jobname) .. suffix
                        end
                        local oldbase, newbase = "", ""
                        if type(resultname) == "string" then
                            oldbase = file.removesuffix(jobname)
                            newbase = file.removesuffix(resultname)
                            if oldbase ~= newbase then
                                if environment.argument("purgeresult") then
                                    for _, suffix in next, scripts.context.aftersuffixes do
                                        local oldname = file.addsuffix(oldbase,suffix)
                                        local newname = file.addsuffix(newbase,suffix)
                                        os.remove(newname)
                                        os.remove(oldname)
                                    end
                                else
                                    for _, suffix in next, scripts.context.beforesuffixes do
                                        local oldname = file.addsuffix(oldbase,suffix)
                                        local newname = file.addsuffix(newbase,suffix)
                                        local tmpname = "keep-"..oldname
                                        os.remove(tmpname)
                                        os.rename(oldname,tmpname)
                                        os.remove(oldname)
                                        os.rename(newname,oldname)
                                    end
                                end
                            else
                                resultname = nil
                            end
                        else
                            resultname = nil
                        end
                        --
                        local pdfview = environment.argument("autopdf") or environment.argument("closepdf")
                        if pdfview then
                            scripts.context.closepdf(filename,pdfview)
                            if resultname then
                                scripts.context.closepdf(resultname,pdfview)
                            end
                        end
                        --
                        local okay = statistics.checkfmtstatus(formatfile)
                        if okay ~= true then
                            report("warning: %s, forcing remake",tostring(okay))
                            scripts.context.make(formatname)
                        end
                        --
                        local flags = { }
                        if environment.argument("batchmode") or environment.argument("batch") then
                            flags[#flags+1] = "--interaction=batchmode"
                        end
                        if environment.argument("synctex") then
                            -- this should become a directive
                            report("warning: synctex is enabled") -- can add upto 5% runtime
                            flags[#flags+1] = "--synctex=1"
                        end
                        flags[#flags+1] = "--fmt=" .. quote(formatfile)
                        flags[#flags+1] = "--lua=" .. quote(scriptfile)
                        --
                        -- We pass these directly.
                        --

--~                         local silent     = environment.argument("silent")
--~                         local noconsole  = environment.argument("noconsole")
--~                         local directives = environment.argument("directives")
--~                         local trackers   = environment.argument("trackers")
--~                         if silent == true then
--~                             silent = "*"
--~                         end
--~                         if type(silent) == "string" then
--~                             if type(directives) == "string" then
--~                                 directives = format("%s,logs.blocked={%s}",directives,silent)
--~                             else
--~                                 directives = format("logs.blocked={%s}",silent)
--~                             end
--~                         end
--~                         if noconsole then
--~                             if type(directives) == "string" then
--~                                 directives = format("%s,logs.target=file",directives)
--~                             else
--~                                 directives = format("logs.target=file")
--~                             end
--~                         end

                        local directives  = environment.directives
                        local trackers    = environment.trackers
                        local experiments = environment.experiments

                        --
                        if type(directives) == "string" then
                            flags[#flags+1] = format('--directives="%s"',directives)
                        end
                        if type(trackers) == "string" then
                            flags[#flags+1] = format('--trackers="%s"',trackers)
                        end
                        --
                        local backend = environment.argument("backend")
                        if type(backend) ~= "string" then
                            backend = "pdf"
                        end
                        flags[#flags+1] = format('--backend="%s"',backend)
                        --
                        local command = format("luatex %s %s \\stoptext", concat(flags," "), quote(filename))
                        local oldhash, newhash = scripts.context.multipass.hashfiles(jobname), { }
                        local once = environment.argument("once")
                        local maxnofruns = (once and 1) or scripts.context.multipass.nofruns
                        local arrange = environment.argument("arrange")
                        for i=1,maxnofruns do
                            -- 1:first run, 2:successive run, 3:once, 4:last of maxruns
                            local kindofrun = (once and 3) or (i==1 and 1) or (i==maxnofruns and 4) or 2
                            scripts.context.multipass.makeoptionfile(jobname,ctxdata,kindofrun,i,false) -- kindofrun, currentrun, final
                            report("run %s: %s",i,command)
--~                             print("\n") -- cleaner, else continuation on same line
                            print("") -- cleaner, else continuation on same line
                            local returncode, errorstring = os.spawn(command)
                        --~ if returncode == 3 then
                        --~     scripts.context.make(formatname)
                        --~     returncode, errorstring = os.spawn(command)
                        --~     if returncode == 3 then
                        --~         report("ks: return code 3, message: %s",errorstring or "?")
                        --~         os.exit(1)
                        --~     end
                        --~ end
                            if not returncode then
                                report("fatal error: no return code, message: %s",errorstring or "?")
                                os.exit(1)
                                break
                            elseif returncode > 0 then
                                report("fatal error: return code: %s",returncode or "?")
                                os.exit(returncode)
                                break
                            else
                                scripts.context.multipass.copyluafile(jobname)
                            --  scripts.context.multipass.copytuifile(jobname)
                                newhash = scripts.context.multipass.hashfiles(jobname)
                                if scripts.context.multipass.changed(oldhash,newhash) then
                                    oldhash = newhash
                                else
                                    break
                                end
                            end
                        end
                        --
                        if arrange then
                            local kindofrun = 3
                            scripts.context.multipass.makeoptionfile(jobname,ctxdata,kindofrun,i,true) -- kindofrun, currentrun, final
                            report("arrange run: %s",command)
                            local returncode, errorstring = os.spawn(command)
                            if not returncode then
                                report("fatal error: no return code, message: %s",errorstring or "?")
                                os.exit(1)
                            elseif returncode > 0 then
                                report("fatal error: return code: %s",returncode or "?")
                                os.exit(returncode)
                            end
                        end
                        --
                        if environment.argument("purge") then
                            scripts.context.purge_job(jobname)
                        elseif environment.argument("purgeall") then
                            scripts.context.purge_job(jobname,true)
                        end
                        --
                        os.remove(jobname..".top")
                        --
                        if resultname then
                            if environment.argument("purgeresult") then
                                -- so, if there is no result then we don't get the old one, but
                                -- related files (log etc) are still there for tracing purposes
                                for _, suffix in next, scripts.context.aftersuffixes do
                                    local oldname = file.addsuffix(oldbase,suffix)
                                    local newname = file.addsuffix(newbase,suffix)
                                    os.remove(newname) -- to be sure
                                    os.rename(oldname,newname)
                                end
                            else
                                for _, suffix in next, scripts.context.aftersuffixes do
                                    local oldname = file.addsuffix(oldbase,suffix)
                                    local newname = file.addsuffix(newbase,suffix)
                                    local tmpname = "keep-"..oldname
                                    os.remove(newname)
                                    os.rename(oldname,newname)
                                    os.rename(tmpname,oldname)
                                end
                            end
                            report("result renamed to: %s",newbase)
                        end
                        --
                        if environment.argument("purge") then
                            scripts.context.purge_job(resultname)
                        elseif environment.argument("purgeall") then
                            scripts.context.purge_job(resultname,true)
                        end
                        --
                        local pdfview = environment.argument("autopdf")
                        if pdfview then
                            scripts.context.openpdf(resultname or filename,pdfview)
                        end
                        --
                        if environment.argument("timing") then
                            report()
                            report("you can process (timing) statistics with:",jobname)
                            report()
                            report("context --extra=timing '%s'",jobname)
                            report("mtxrun --script timing --xhtml [--launch --remove] '%s'",jobname)
                            report()
                        end
                    else
                        if formatname then
                            report("error, no format found with name: %s, skipping",formatname)
                        else
                            report("error, no format found (provide formatname or interface)")
                        end
                        break
                    end
                end
            end
        else
            if formatname then
                report("error, no format found with name: %s, aborting",formatname)
            else
                report("error, no format found (provide formatname or interface)")
            end
        end
    end
end

function scripts.context.pipe()
    -- context --pipe
    -- context --pipe --purge --dummyfile=whatever.tmp
    local interface = environment.argument("interface")
    interface = (type(interface) == "string" and interface) or "en"
    local formatname = scripts.context.interfaces[interface] or "cont-en"
    local formatfile, scriptfile = resolvers.locateformat(formatname)
    if not formatfile or not scriptfile then
        report("warning: no format found, forcing remake (commandline driven)")
        scripts.context.make(formatname)
        formatfile, scriptfile = resolvers.locateformat(formatname)
    end
    if formatfile and scriptfile then
        local okay = statistics.checkfmtstatus(formatfile)
        if okay ~= true then
            report("warning: %s, forcing remake",tostring(okay))
            scripts.context.make(formatname)
        end
        local flags = {
            "--interaction=scrollmode",
            "--fmt=" .. quote(formatfile),
            "--lua=" .. quote(scriptfile),
            "--backend=pdf",
        }
        local filename = environment.argument("dummyfile") or ""
        if filename == "" then
            filename = "\\relax"
            report("entering scrollmode, end job with \\end")
        else
            filename = file.addsuffix(filename,"tmp")
            io.savedata(filename,"\\relax")
            scripts.context.multipass.makeoptionfile(filename,{ flags = flags },3,1,false) -- kindofrun, currentrun, final
            report("entering scrollmode using '%s' with optionfile, end job with \\end",filename)
        end
        local command = format("luatex %s %s", concat(flags," "), quote(filename))
        os.spawn(command)
        if environment.argument("purge") then
            scripts.context.purge_job(filename)
        elseif environment.argument("purgeall") then
            scripts.context.purge_job(filename,true)
            os.remove(filename)
        end
    else
        if formatname then
            report("error, no format found with name: %s, aborting",formatname)
        else
            report("error, no format found (provide formatname or interface)")
        end
    end
end

local make_mkiv_format = environment.make_format

local function make_mkii_format(name,engine)
    if environment.argument(engine) then
        local command = format("mtxrun texexec.rb --make --%s %s",name,engine)
        report("running command: %s",command)
        os.spawn(command)
    end
end

function scripts.context.generate()
    resolvers.instance.renewcache = true
    trackers.enable("resolvers.locating")
    resolvers.load()
end

function scripts.context.make(name)
    if not environment.argument("fast") then -- as in texexec
        scripts.context.generate()
    end
    local list = (name and { name }) or (environment.files[1] and environment.files) or scripts.context.defaultformats
    for i=1,#list do
        local name = list[i]
        name = scripts.context.interfaces[name] or name or ""
        if name ~= "" then
            make_mkiv_format(name)
            make_mkii_format(name,"pdftex")
            make_mkii_format(name,"xetex")
        end
    end
end

function scripts.context.ctx()
    local ctxdata = ctxrunner.new()
    ctxdata.jobname = environment.files[1]
    ctxrunner.manipulate(ctxdata,environment.argument("ctx"))
    scripts.context.run(ctxdata)
end

function scripts.context.autoctx()
    local ctxdata = nil
    local files = (filename and { filename }) or environment.files
    local firstfile = #files > 0 and files[1]
    if firstfile and file.extname(firstfile) == "xml" then
        local f = io.open(firstfile)
        if f then
            local chunk = f:read(512) or ""
            f:close()
            local ctxname = match(chunk,"<%?context%-directive%s+job%s+ctxfile%s+([^ ]-)%s*?>")
            if ctxname then
                ctxdata = ctxrunner.new()
                ctxdata.jobname = firstfile
                ctxrunner.manipulate(ctxdata,ctxname)
            end
        end
    end
    scripts.context.run(ctxdata)
end

local template = [[
\starttext
    \directMPgraphic{%s}{input "%s"}
\stoptext
]]

local loaded = false

function scripts.context.metapost()
    local filename = environment.files[1] or ""
    if not loaded then
        dofile(resolvers.findfile("mlib-run.lua"))
        loaded = true
        commands = commands or { }
        commands.writestatus = report -- no longer needed
    end
    local formatname = environment.argument("format") or "metafun"
    if formatname == "" or type(formatname) == "boolean" then
        formatname = "metafun"
    end
    if environment.argument("pdf") then
        local basename = file.removesuffix(filename)
        local resultname = environment.argument("result") or basename
        local jobname = "mtx-context-metapost"
        local tempname = file.addsuffix(jobname,"tex")
        io.savedata(tempname,format(template,"metafun",filename))
        environment.files[1] = tempname
        environment.setargument("result",resultname)
        environment.setargument("once",true)
        scripts.context.run()
        scripts.context.purge_job(jobname,true)
        scripts.context.purge_job(resultname,true)
    elseif environment.argument("svg") then
        metapost.directrun(formatname,filename,"svg")
    else
        metapost.directrun(formatname,filename,"mps")
    end
end

function scripts.context.version()
    local name = resolvers.findfile("context.mkiv")
    if name ~= "" then
        report("main context file: %s",name)
        local data = io.loaddata(name)
        if data then
            local version = match(data,"\\edef\\contextversion{(.-)}")
            if version then
                report("current version: %s",version)
            else
                report("context version: unknown, no timestamp found")
            end
        else
            report("context version: unknown, load error")
        end
    else
        report("main context file: unknown, 'context.mkiv' not found")
    end
end

local generic_files = {
    "texexec.tex", "texexec.tui", "texexec.tuo",
    "texexec.tuc", "texexec.tua",
    "texexec.ps", "texexec.pdf", "texexec.dvi",
    "cont-opt.tex", "cont-opt.bak"
}

local obsolete_results = {
    "dvi",
}

local temporary_runfiles = {
    "tui", "tua", "tup", "ted", "tes", "top",
    "log", "tmp", "run", "bck", "rlg",
    "mpt", "mpx", "mpd", "mpo", "mpb", "ctl",
    "synctex.gz", "pgf"
}

local persistent_runfiles = {
    "tuo", "tub", "top", "tuc"
}

local special_runfiles = {
--~     "-mpgraph*", "-mprun*", "-temp-*" -- hm, wasn't this escaped?
    "-mpgraph", "-mprun", "-temp-"
}

local function purge_file(dfile,cfile)
    if cfile and lfs.isfile(cfile) then
        if os.remove(dfile) then
            return file.basename(dfile)
        end
    elseif dfile then
        if os.remove(dfile) then
            return file.basename(dfile)
        end
    end
end

local function remove_special_files(pattern)
end

function scripts.context.purge_job(jobname,all,mkiitoo)
    if jobname and jobname ~= "" then
        jobname = file.basename(jobname)
        local filebase = file.removesuffix(jobname)
        if mkiitoo then
            scripts.context.purge(all,filebase,true) -- leading "./"
        else
            local deleted = { }
            for i=1,#obsolete_results do
                deleted[#deleted+1] = purge_file(filebase.."."..obsolete_results[i],filebase..".pdf")
            end
            for i=1,#temporary_runfiles do
                deleted[#deleted+1] = purge_file(filebase.."."..temporary_runfiles[i])
            end
            if all then
                for i=1,#persistent_runfiles do
                    deleted[#deleted+1] = purge_file(filebase.."."..persistent_runfiles[i])
                end
            end
            if #deleted > 0 then
                report("purged files: %s", concat(deleted,", "))
            end
        end
    end
end

function scripts.context.purge(all,pattern,mkiitoo)
    local all = all or environment.argument("all")
    local pattern = environment.argument("pattern") or (pattern and (pattern.."*")) or "*.*"
    local files = dir.glob(pattern)
    local obsolete = table.tohash(obsolete_results)
    local temporary = table.tohash(temporary_runfiles)
    local persistent = table.tohash(persistent_runfiles)
    local generic = table.tohash(generic_files)
    local deleted = { }
    for i=1,#files do
        local name = files[i]
        local suffix = file.extname(name)
        local basename = file.basename(name)
        if obsolete[suffix] or temporary[suffix] or persistent[suffix] or generic[basename] then
            deleted[#deleted+1] = purge_file(name)
        elseif mkiitoo then
            for i=1,#special_runfiles do
                if find(name,special_runfiles[i]) then
                    deleted[#deleted+1] = purge_file(name)
                end
            end
        end
    end
    if #deleted > 0 then
        report("purged files: %s", concat(deleted,", "))
    end
end

local function touch(name,pattern)
    local name = resolvers.findfile(name)
    local olddata = io.loaddata(name)
    if olddata then
        local oldversion, newversion = "", os.date("%Y.%m.%d %H:%M")
        local newdata, ok = olddata:gsub(pattern,function(pre,mid,post)
            oldversion = mid
            return pre .. newversion .. post
        end)
        if ok > 0 then
            local backup = file.replacesuffix(name,"tmp")
            os.remove(backup)
            os.rename(name,backup)
            io.savedata(name,newdata)
            return true, oldversion, newversion, name
        else
            return false
        end
    end
end

local function touchfiles(suffix)
    local done, oldversion, newversion, foundname = touch(file.addsuffix("context",suffix),"(\\edef\\contextversion{)(.-)(})")
    if done then
        report("old version : %s", oldversion)
        report("new version : %s", newversion)
        report("touched file: %s", foundname)
        local ok, _, _, foundname = touch(file.addsuffix("cont-new",suffix), "(\\newcontextversion{)(.-)(})")
        if ok then
            report("touched file: %s", foundname)
        end
    end
end

function scripts.context.touch()
    if environment.argument("expert") then
        touchfiles("mkii")
        touchfiles("mkiv")
        touchfiles("mkvi")
    end
end

-- modules

local labels = { "title", "comment", "status" }
local cards  = { "*.mkvi", "*.mkiv", "*.tex" }

function scripts.context.modules(pattern)
    local list = { }
    local found = resolvers.findfile("context.mkiv")
    if not pattern or pattern == "" then
        -- official files in the tree
        for _, card in ipairs(cards) do
            resolvers.findwildcardfiles(card,list)
        end
        -- my dev path
        for _, card in ipairs(cards) do
            dir.glob(file.join(file.dirname(found),card),list)
        end
    else
        resolvers.findwildcardfiles(pattern,list)
        dir.glob(file.join(file.dirname(found,pattern)),list)
    end
    local done = { } -- todo : sort
    for i=1,#list do
        local v = list[i]
        local base = file.basename(v)
        if not done[base] then
            done[base] = true
            local suffix = file.suffix(base)
            if suffix == "tex" or suffix == "mkiv" or suffix == "mkvi" then
                local prefix = match(base,"^([xmst])%-")
                if prefix then
                    v = resolvers.findfile(base) -- so that files on my dev path are seen
                    local data = io.loaddata(v) or ""
                    data = match(data,"%% begin info(.-)%% end info")
                    if data then
                        local info = { }
                        for label, text in gmatch(data,"%% +([^ ]+) *: *(.-)[\n\r]") do
                            info[label] = text
                        end
                        report()
                        report("%-7s : %s","module",base)
                        report()
                        for i=1,#labels do
                            local l = labels[i]
                            if info[l] then
                                report("%-7s : %s",l,info[l])
                            end
                        end
                        report()
                    end
                end
            end
        end
    end
end

-- extras

function scripts.context.extras(pattern)
    -- only in base path, i.e. only official ones
    if type(pattern) ~= "string" then
        pattern = "*"
    end
    local found = resolvers.findfile("context.mkiv")
    if found ~= "" then
        pattern = file.join(dir.expandname(file.dirname(found)),format("mtx-context-%s.tex",pattern or "*"))
        local list = dir.glob(pattern)
        for i=1,#list do
            local v = list[i]
            local data = io.loaddata(v) or ""
            data = match(data,"%% begin help(.-)%% end help")
            if data then
                report()
                report("extra: %s (%s)",(gsub(v,"^.*mtx%-context%-(.-)%.tex$","%1")),v)
                for s in gmatch(data,"%% *(.-)[\n\r]") do
                    report(s)
                end
                report()
            end
        end
    end
end

function scripts.context.extra()
    local extra = environment.argument("extra")
    if type(extra) == "string" then
        if environment.argument("help") then
            scripts.context.extras(extra)
        else
            local fullextra = extra
            if not find(fullextra,"mtx%-context%-") then
                fullextra = "mtx-context-" .. extra
            end
            local foundextra = resolvers.findfile(fullextra)
            if foundextra == "" then
                scripts.context.extras()
                return
            else
                report("processing extra: %s", foundextra)
            end
            environment.setargument("purgeall",true)
            local result = environment.setargument("result") or ""
            if result == "" then
                environment.setargument("result","context-extra")
            end
            scripts.context.run(nil,foundextra)
        end
    else
        scripts.context.extras()
    end
end

-- todo: we need to do a dummy run

function scripts.context.trackers()
    environment.files = { resolvers.findfile("m-trackers.mkiv") }
    scripts.context.multipass.nofruns = 1
    environment.setargument("purgeall",true)
    scripts.context.run()
end

function scripts.context.directives()
    environment.files = { resolvers.findfile("m-directives.mkiv") }
    scripts.context.multipass.nofruns = 1
    environment.setargument("purgeall",true)
    scripts.context.run()
end

function scripts.context.logcategories()
    environment.files = { resolvers.findfile("m-logcategories.mkiv") }
    scripts.context.multipass.nofruns = 1
    environment.setargument("purgeall",true)
    scripts.context.run()
end

function scripts.context.timed(action)
    statistics.timed(action)
end

local zipname     = "cont-tmf.zip"
local mainzip     = "http://www.pragma-ade.com/context/latest/" .. zipname
local validtrees  = { "texmf-local", "texmf-context" }
local selfscripts = { "mtxrun.lua" } -- was: { "luatools.lua", "mtxrun.lua" }

function zip.loaddata(zipfile,filename) -- should be in zip lib
    local f = zipfile:open(filename)
    if f then
        local data = f:read("*a")
        f:close()
        return data
    end
    return nil
end

function scripts.context.update()
    local force = environment.argument("force")
    local socket = require("socket")
    local http   = require("socket.http")
    local basepath = resolvers.findfile("context.mkiv") or ""
    if basepath == "" then
        report("quiting, no 'context.mkiv' found")
        return
    end
    local basetree = basepath.match(basepath,"^(.-)tex/context/base/context.mkiv$") or ""
    if basetree == "" then
        report("quiting, no proper tds structure (%s)",basepath)
        return
    end
    local function is_okay(basetree)
        for _, tree in next, validtrees do
            local pattern = gsub(tree,"%-","%%-")
            if basetree:find(pattern) then
                return tree
            end
        end
        return false
    end
    local okay = is_okay(basetree)
    if not okay then
        report("quiting, tree '%s' is protected",okay)
        return
    else
        report("updating tree '%s'",okay)
    end
    if not lfs.chdir(basetree) then
        report("quiting, unable to change to '%s'",okay)
        return
    end
    report("fetching '%s'",mainzip)
    local latest = http.request(mainzip)
    if not latest then
        report("context tree '%s' can be updated, use --force",okay)
        return
    end
    io.savedata("cont-tmf.zip",latest)
    if false then
        -- variant 1
        os.execute("mtxrun --script unzip cont-tmf.zip")
    else
        -- variant 2
        local zipfile = zip.open(zipname)
        if not zipfile then
            report("quiting, unable to open '%s'",zipname)
            return
        end
        local newfile = zip.loaddata(zipfile,"tex/context/base/context.mkiv")
        if not newfile then
            report("quiting, unable to open '%s'","context.mkiv")
            return
        end
        local oldfile = io.loaddata(resolvers.findfile("context.mkiv")) or ""
        local function versiontonumber(what,str)
            local version = match(str,"\\edef\\contextversion{(.-)}") or ""
            local year, month, day, hour, minute = match(str,"\\edef\\contextversion{(%d+)%.(%d+)%.(%d+) *(%d+)%:(%d+)}")
            if year and minute then
                local time = os.time { year=year,month=month,day=day,hour=hour,minute=minute}
                report("%s version: %s (%s)",what,version,time)
                return time
            else
                report("%s version: %s (unknown)",what,version)
                return nil
            end
        end
        local oldversion = versiontonumber("old",oldfile)
        local newversion = versiontonumber("new",newfile)
        if not oldversion or not newversion then
            report("quiting, version cannot be determined")
            return
        elseif oldversion == newversion then
            report("quiting, your current version is up-to-date")
            return
        elseif oldversion > newversion then
            report("quiting, your current version is newer")
            return
        end
        for k in zipfile:files() do
            local filename = k.filename
            if filename:find("/$") then
                lfs.mkdir(filename)
            else
                local data = zip.loaddata(zipfile,filename)
                if data then
                    if force then
                        io.savedata(filename,data)
                    end
                    report(filename)
                end
            end
        end
        for _, scriptname in next, selfscripts do
            local oldscript = resolvers.findfile(scriptname) or ""
            if oldscript ~= "" and is_okay(oldscript) then
                local newscript = "./scripts/context/lua/" .. scriptname
                local data = io.loaddata(newscript) or ""
                if data ~= "" then
                    report("replacing script '%s' by '%s'",oldscript,newscript)
                    if force then
                        io.savedata(oldscript,data)
                    end
                end
            else
                report("keeping script '%s'",oldscript)
            end
        end
        if force then
            scripts.context.make()
        end
    end
    if force then
        report("context tree '%s' has been updated",okay)
    else
        report("context tree '%s' can been updated (use --force)",okay)
    end
end

do

    local silent = environment.argument("silent")
    if type(silent) == "string" then
        directives.enable(format("logs.blocked={%s}",silent))
    elseif silent then
        directives.enable("logs.blocked")
    end

end

if environment.argument("once") then
    scripts.context.multipass.nofruns = 1
elseif environment.argument("runs") then
    scripts.context.multipass.nofruns = tonumber(environment.argument("runs")) or nil
end

if environment.argument("profile") then
    os.setenv("MTX_PROFILE_RUN","YES")
end

if environment.argument("run") then
--  scripts.context.timed(scripts.context.run)
    scripts.context.timed(scripts.context.autoctx)
elseif environment.argument("make") then
    scripts.context.timed(function() scripts.context.make() end)
elseif environment.argument("generate") then
    scripts.context.timed(function() scripts.context.generate() end)
elseif environment.argument("ctx") then
    scripts.context.timed(scripts.context.ctx)
elseif environment.argument("mp") or environment.argument("metapost") then
    scripts.context.timed(scripts.context.metapost)
elseif environment.argument("version") then
    scripts.context.version()
elseif environment.argument("touch") then
    scripts.context.touch()
elseif environment.argument("update") then
    scripts.context.update()
elseif environment.argument("expert") then
    application.help("expert", "special")
elseif environment.argument("modules") then
    scripts.context.modules()
elseif environment.argument("extras") then
    scripts.context.extras(environment.files[1] or environment.argument("extras"))
elseif environment.argument("extra") then
    scripts.context.extra()
elseif environment.argument("help") then
    if environment.files[1] == "extras" then
        scripts.context.extras()
    else
        application.help("basic")
    end
elseif environment.argument("showtrackers") or environment.argument("trackers") == true then
    scripts.context.trackers()
elseif environment.argument("showdirectives") or environment.argument("directives") == true then
    scripts.context.directives()
elseif environment.argument("showlogcategories") then
    scripts.context.logcategories()
elseif environment.argument("track") and type(environment.argument("track")) == "boolean" then -- for old times sake, will go
    scripts.context.trackers()
elseif environment.files[1] then
--  scripts.context.timed(scripts.context.run)
    scripts.context.timed(scripts.context.autoctx)
elseif environment.argument("pipe") then
    scripts.context.timed(scripts.context.pipe)
elseif environment.argument("purge") then
    -- only when no filename given, supports --pattern
    scripts.context.purge()
elseif environment.argument("purgeall") then
    -- only when no filename given, supports --pattern
    scripts.context.purge(true,nil,true)
else
    application.help("basic")
end

if environment.argument("profile") then
    os.setenv("MTX_PROFILE_RUN","NO")
end

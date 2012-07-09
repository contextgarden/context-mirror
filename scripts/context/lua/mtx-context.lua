if not modules then modules = { } end modules ['mtx-context'] = {
    version   = 1.001,
    comment   = "companion to mtxrun.lua",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- todo: more local functions
-- todo: pass jobticket/ctxdata table around

local format, gmatch, match, gsub, find = string.format, string.gmatch, string.match, string.gsub, string.find
local quote, validstring = string.quote, string.valid
local concat = table.concat
local settings_to_array = utilities.parsers.settings_to_array
local appendtable = table.append
local lpegpatterns, lpegmatch, Cs, P = lpeg.patterns, lpeg.match, lpeg.Cs, lpeg.P

local getargument = environment.getargument or environment.argument
local setargument = environment.setargument

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

--forcexml            force xml stub
--forcecld            force cld (context lua document) stub

--arrange             run extra imposition pass, given that the style sets up imposition
--noarrange           ignore imposition specifications in the style

--once                only run once (no multipass data file is produced)
--batchmode           run without stopping and don't show messages on the console
--nonstopmode         run without stopping

--generate            generate file database etc. (as luatools does)
--paranoid            don't descend to .. and ../..
--version             report installed context version

--global              assume given file present elsewhere
--nofile              use dummy file as jobname

--expert              expert options
]]

local expertinfo = [[
expert options:

--touch               update context version number (remake needed afterwards, also provide --expert)
--nostatistics        omit runtime statistics at the end of the run
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
--mkii                process file with texexec

--pipe                don't check for file and enter scroll mode (--dummyfile=whatever.tmp)
]]

local application = logs.application {
    name     = "mtx-context",
    banner   = "ConTeXt Process Management 0.60",
    helpinfo = {
        basic  = basicinfo,
        extra  = extrainfo,
        expert = expertinfo,
    }
}

-- local luatexflags = {
--     ["8bit"]                        = true, -- ignored, input is assumed to be in UTF-8 encoding
--     ["default-translate-file"]      = true, -- ignored, input is assumed to be in UTF-8 encoding
--     ["translate-file"]              = true, -- ignored, input is assumed to be in UTF-8 encoding
--     ["etex"]                        = true, -- ignored, the etex extensions are always active
--
--     ["credits"]                     = true, -- display credits and exit
--     ["debug-format"]                = true, -- enable format debugging
--     ["disable-write18"]             = true, -- disable \write18{SHELL COMMAND}
--     ["draftmode"]                   = true, -- switch on draft mode (generates no output PDF)
--     ["enable-write18"]              = true, -- enable \write18{SHELL COMMAND}
--     ["file-line-error"]             = true, -- enable file:line:error style messages
--     ["file-line-error-style"]       = true, -- aliases of --file-line-error
--     ["no-file-line-error"]          = true, -- disable file:line:error style messages
--     ["no-file-line-error-style"]    = true, -- aliases of --no-file-line-error
--     ["fmt"]                         = true, -- load the format file FORMAT
--     ["halt-on-error"]               = true, -- stop processing at the first error
--     ["help"]                        = true, -- display help and exit
--     ["ini"]                         = true, -- be iniluatex, for dumping formats
--     ["interaction"]                 = true, -- set interaction mode (STRING=batchmode/nonstopmode/scrollmode/errorstopmode)
--     ["jobname"]                     = true, -- set the job name to STRING
--     ["kpathsea-debug"]              = true, -- set path searching debugging flags according to the bits of NUMBER
--     ["lua"]                         = true, -- load and execute a lua initialization script
--     ["mktex"]                       = true, -- enable mktexFMT generation (FMT=tex/tfm)
--     ["no-mktex"]                    = true, -- disable mktexFMT generation (FMT=tex/tfm)
--     ["nosocket"]                    = true, -- disable the lua socket library
--     ["output-comment"]              = true, -- use STRING for DVI file comment instead of date (no effect for PDF)
--     ["output-directory"]            = true, -- use existing DIR as the directory to write files in
--     ["output-format"]               = true, -- use FORMAT for job output; FORMAT is 'dvi' or 'pdf'
--     ["parse-first-line"]            = true, -- enable parsing of the first line of the input file
--     ["no-parse-first-line"]         = true, -- disable parsing of the first line of the input file
--     ["progname"]                    = true, -- set the program name to STRING
--     ["recorder"]                    = true, -- enable filename recorder
--     ["safer"]                       = true, -- disable easily exploitable lua commands
--     ["shell-escape"]                = true, -- enable \write18{SHELL COMMAND}
--     ["no-shell-escape"]             = true, -- disable \write18{SHELL COMMAND}
--     ["shell-restricted"]            = true, -- restrict \write18 to a list of commands given in texmf.cnf
--     ["synctex"]                     = true, -- enable synctex
--     ["version"]                     = true, -- display version and exit
--     ["luaonly"]                     = true, -- run a lua file, then exit
--     ["luaconly"]                    = true, -- byte-compile a lua file, then exit
-- }

local report = application.report

scripts         = scripts         or { }
scripts.context = scripts.context or { }

-- constants

local usedfiles = {
    nop = "cont-nop.mkiv",
    yes = "cont-yes.mkiv",
}

local usedsuffixes = {
    before = {
        "tuc"
    },
    after = {
        "pdf", "tuc", "log"
    },
    keep = {
        "log"
    },
}

local formatofinterface = {
    en = "cont-en",
    uk = "cont-uk",
    de = "cont-de",
    fr = "cont-fr",
    nl = "cont-nl",
    cs = "cont-cs",
    it = "cont-it",
    ro = "cont-ro",
    pe = "cont-pe",
}

local defaultformats = {
    "cont-en",
    "cont-nl",
}

-- process information

local ctxrunner = { } -- namespace will go

local ctx_locations = { '..', '../..' }

function ctxrunner.new()
    return {
        ctxname   = "",
        jobname   = "",
        flags     = { },
    }
end

function ctxrunner.checkfile(ctxdata,ctxname,defaultname)

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

    -- no further test if qualified path

    if not found then
        for _, path in next, ctx_locations do
            local fullname = file.join(path,ctxdata.ctxname)
            if lfs.isfile(fullname) then
                usedname = fullname
                found    = true
                break
            end
        end
    end

    if not found then
        usedname = resolvers.findfile(ctxdata.ctxname,"tex")
        found    = usedname ~= ""
    end

    if not found and defaultname and defaultname ~= "" and lfs.isfile(defaultname) then
        usedname = defaultname
        found    = true
    end

    if not found then
        return
    end

    local xmldata = xml.load(usedname)

    if not xmldata then
        return
    else
        -- test for valid, can be text file
    end

    local ctxpaths = table.append({'.', file.dirname(ctxdata.ctxname)}, ctx_locations)

    xml.include(xmldata,'ctx:include','name', ctxpaths)

    local flags = ctxdata.flags

    for e in xml.collected(xmldata,"/ctx:job/ctx:flags/ctx:flag") do
        local flag = xml.text(e) or ""
        local key, value = match(flag,"^(.-)=(.+)$")
        if key and value then
            flags[key] = value
        else
            flags[flag] = true
        end
    end

end

function ctxrunner.checkflags(ctxdata)
    if ctxdata then
        for k,v in next, ctxdata.flags do
            if getargument(k) == nil then
                setargument(k,v)
            end
        end
    end
end

-- multipass control

local multipass_suffixes = { ".tuc" }
local multipass_nofruns  = 8 -- or 7 to test oscillation

local function multipass_hashfiles(jobname)
    local hash = { }
    for i=1,#multipass_suffixes do
        local suffix = multipass_suffixes[i]
        local full = jobname .. suffix
        hash[full] = md5.hex(io.loaddata(full) or "unknown")
    end
    return hash
end

local function multipass_changed(oldhash, newhash)
    for k,v in next, oldhash do
        if v ~= newhash[k] then
            return true
        end
    end
    return false
end

local function multipass_copyluafile(jobname)
    local tuaname, tucname = jobname..".tua", jobname..".tuc"
    if lfs.isfile(tuaname) then
        os.remove(tucname)
        os.rename(tuaname,tucname)
    end
end

--

local pattern = lpegpatterns.utfbom^-1 * (P("%% ") + P("% ")) * Cs((1-lpegpatterns.newline)^1)

local function preamble_analyze(filename) -- only files on current path
    local t = { }
    local line = io.loadlines(file.addsuffix(filename,"tex"))
    if line then
        local preamble = lpegmatch(pattern,line)
        if preamble then
            for key, value in gmatch(preamble,"(%S+)%s*=%s*(%S+)") do
                t[key] = value
            end
            t.type = "tex"
        elseif find(line,"^<?xml ") then
            t.type = "xml"
        end
        if t.nofruns then
            multipass_nofruns = t.nofruns
        end
        if not t.engine then
            t.engine = 'luatex'
        end
    end
    return t
end

-- automatically opening and closing pdf files

local pdfview -- delayed

local function pdf_open(name,method)
    pdfview = pdfview or dofile(resolvers.findfile("l-pdfview.lua","tex"))
    pdfview.setmethod(method)
    report(pdfview.status())
    pdfview.open(file.replacesuffix(name,"pdf"))
end

local function pdf_close(name,method)
    pdfview = pdfview or dofile(resolvers.findfile("l-pdfview.lua","tex"))
    pdfview.setmethod(method)
    pdfview.close(file.replacesuffix(name,"pdf"))
end

-- result file handling

local function result_push_purge(oldbase,newbase)
    for _, suffix in next, usedsuffixes.after do
        local oldname = file.addsuffix(oldbase,suffix)
        local newname = file.addsuffix(newbase,suffix)
        os.remove(newname)
        os.remove(oldname)
    end
end

local function result_push_keep(oldbase,newbase)
    for _, suffix in next, usedsuffixes.before do
        local oldname = file.addsuffix(oldbase,suffix)
        local newname = file.addsuffix(newbase,suffix)
        local tmpname = "keep-"..oldname
        os.remove(tmpname)
        os.rename(oldname,tmpname)
        os.remove(oldname)
        os.rename(newname,oldname)
    end
end

local function result_save_error(oldbase,newbase)
    for _, suffix in next, usedsuffixes.keep do
        local oldname = file.addsuffix(oldbase,suffix)
        local newname = file.addsuffix(newbase,suffix)
        os.remove(newname) -- to be sure
        os.rename(oldname,newname)
    end
end

local function result_save_purge(oldbase,newbase)
    for _, suffix in next, usedsuffixes.after do
        local oldname = file.addsuffix(oldbase,suffix)
        local newname = file.addsuffix(newbase,suffix)
        os.remove(newname) -- to be sure
        os.rename(oldname,newname)
    end
end

local function result_save_keep(oldbase,newbase)
    for _, suffix in next, usedsuffixes.after do
        local oldname = file.addsuffix(oldbase,suffix)
        local newname = file.addsuffix(newbase,suffix)
        local tmpname = "keep-"..oldname
        os.remove(newname)
        os.rename(oldname,newname)
        os.rename(tmpname,oldname)
    end
end

-- executing luatex

local function flags_to_string(flags,prefix) -- context flags get prepended by c:
    local t = { }
    for k, v in table.sortedhash(flags) do
        if prefix then
            k = format("c:%s",k)
        end
        if not v or v == "" or v == '""' then
            -- no need to flag false
        elseif v == true then
            t[#t+1] = format('--%s',k)
        elseif type(v) == "string" then
            t[#t+1] = format('--%s=%s',k,quote(v))
        else
            t[#t+1] = format('--%s=%s',k,tostring(v))
        end
    end
    return concat(t," ")
end

local function luatex_command(l_flags,c_flags,filename)
    return format('luatex %s %s "%s"',
        flags_to_string(l_flags),
        flags_to_string(c_flags,true),
        filename
    )
end

local function run_texexec(filename,a_purge,a_purgeall)
    if false then
        -- we need to write a top etc too and run mp etc so it's not worth the
        -- trouble, so it will take a while before the next is finished
        --
        -- context --extra=texutil --convert myfile
    else
        local texexec = resolvers.findfile("texexec.rb") or ""
        if texexec ~= "" then
            os.setenv("RUBYOPT","")
            local options = environment.reconstructcommandline(environment.arguments_after)
            options = gsub(options,"--purge","")
            options = gsub(options,"--purgeall","")
            local command = format("ruby %s %s",texexec,options)
            if a_purge then
                os.execute(command)
                scripts.context.purge_job(filename,false,true)
            elseif a_purgeall then
                os.execute(command)
                scripts.context.purge_job(filename,true,true)
            else
                os.exec(command)
            end
        end
    end
end

--

function scripts.context.run(ctxdata,filename)
    --
    local a_nofile = getargument("nofile")
    --
    local files    = environment.files or { }
    --
    local filelist, mainfile
    --
    if filename then
        -- the given forced name is processed, the filelist is passed to context
        mainfile = filename
        filelist = { filename }
     -- files    = files
    elseif a_nofile then
        -- the list of given files is processed using the dummy file
        mainfile = usedfiles.nop
        filelist = { usedfiles.nop }
     -- files    = { }
    elseif #files > 0 then
        -- the list of given files is processed using the stub file
        mainfile = usedfiles.yes
        filelist = files
        files    = { }
    else
        return
    end
    --
    local interface = validstring(getargument("interface")) or "en"
    local formatname = formatofinterface[interface] or "cont-en"
    local formatfile, scriptfile = resolvers.locateformat(formatname)
    if not formatfile or not scriptfile then
        report("warning: no format found, forcing remake (commandline driven)")
        scripts.context.make(formatname)
        formatfile, scriptfile = resolvers.locateformat(formatname)
    end
    if formatfile and scriptfile then
        -- okay
    elseif formatname then
        report("error, no format found with name: %s, aborting",formatname)
        return
    else
        report("error, no format found (provide formatname or interface)")
        return
    end
    --
    local a_mkii        = getargument("mkii") or getargument("pdftex") or getargument("xetex")
    local a_purge       = getargument("purge")
    local a_purgeall    = getargument("purgeall")
    local a_purgeresult = getargument("purgeresult")
    local a_global      = getargument("global")
    local a_timing      = getargument("timing")
    local a_batchmode   = getargument("batchmode")
    local a_nonstopmode = getargument("nonstopmode")
    local a_once        = getargument("once")
    local a_synctex     = getargument("synctex")
    local a_backend     = getargument("backend")
    local a_arrange     = getargument("arrange")
    local a_noarrange   = getargument("noarrange")
    --
    for i=1,#filelist do
        --
        local filename = filelist[i]
        local basename = file.basename(filename)
        local pathname = file.dirname(filename)
        local jobname  = file.removesuffix(basename)
        local ctxname  = ctxdata and ctxdata.ctxname
        --
        if pathname == "" and not a_global and filename ~= usedfiles.nop then
            filename = "./" .. filename
        end
        --
        local analysis = preamble_analyze(filename)
        --
        if a_mkii or analysis.engine == 'pdftex' or analysis.engine == 'xetex' then
            run_texexec(filename,a_purge,a_purgeall)
        else
            if analysis.interface and analysis.interface ~= interface then
                formatname = formatofinterface[analysis.interface] or formatname
                formatfile, scriptfile = resolvers.locateformat(formatname)
            end
            if not formatfile or not scriptfile then
                report("warning: no format found, forcing remake (source driven)")
                scripts.context.make(formatname)
                formatfile, scriptfile = resolvers.locateformat(formatname)
            end
            if formatfile and scriptfile then
                --
                local suffix     = validstring(getargument("suffix"))
                local resultname = validstring(getargument("result"))
                if suffix then
                    resultname = file.removesuffix(jobname) .. suffix
                end
                local oldbase = ""
                local newbase = ""
                if resultname then
                    oldbase = file.removesuffix(jobname)
                    newbase = file.removesuffix(resultname)
                    if oldbase ~= newbase then
                        if a_purgeresult then
                            result_push_purge(oldbase,newbase)
                        else
                            result_push_keep(oldbase,newbase)
                        end
                    else
                        resultname = nil
                    end
                end
                --
                local pdfview = getargument("autopdf") or getargument("closepdf")
                if pdfview then
                    pdf_close(filename,pdfview)
                    if resultname then
                        pdf_close(resultname,pdfview)
                    end
                end
                --
                local okay = statistics.checkfmtstatus(formatfile)
                if okay ~= true then
                    report("warning: %s, forcing remake",tostring(okay))
                    scripts.context.make(formatname)
                end
                --
                local oldhash    = multipass_hashfiles(jobname)
                local newhash    = { }
                local maxnofruns = once and 1 or multipass_nofruns
                --
                local c_flags = {
                    directives  = validstring(environment.directives),   -- gets passed via mtxrun
                    trackers    = validstring(environment.trackers),     -- gets passed via mtxrun
                    experiments = validstring(environment.experiments),  -- gets passed via mtxrun
                    --
                    result      = validstring(resultname),
                    input       = validstring(filename),
                    files       = concat(files,","),
                    ctx         = validstring(ctxname),
                }
                --
                for k, v in next, environment.arguments do
                    if c_flags[k] == nil then
                        c_flags[k] = v
                    end
                end
                --
                local l_flags = {
                    ["interaction"]         = (a_batchmode and "batchmode") or (a_nonstopmode and "nonstopmode") or nil,
                    ["synctex"]             = a_synctex and 1 or nil,
                    ["no-parse-first-line"] = true,
                 -- ["no-mktex"]            = true,
                 -- ["file-line-error-style"]     = true,
                    ["fmt"]                 = formatfile,
                    ["lua"]                 = scriptfile,
                    ["jobname"]             = jobname,
                }
                --
                if a_synctex then
                    report("warning: synctex is enabled") -- can add upto 5% runtime
                end
                --
                -- kindofrun: 1:first run, 2:successive run, 3:once, 4:last of maxruns
                --
                for currentrun=1,maxnofruns do
                    --
                    c_flags.final      = false
                    c_flags.kindofrun  = (a_once and 3) or (currentrun==1 and 1) or (currentrun==maxnofruns and 4) or 2
                    c_flags.currentrun = currentrun
                    c_flags.noarrange  = a_noarrange or a_arrange or nil
                    --
                    local command = luatex_command(l_flags,c_flags,mainfile)
                    --
                    report("run %s: %s",i,command)
                    print("") -- cleaner, else continuation on same line
                    local returncode, errorstring = os.spawn(command)
                    if not returncode then
                        report("fatal error: no return code, message: %s",errorstring or "?")
                        if resultname then
                            result_save_error(oldbase,newbase)
                        end
                        os.exit(1)
                        break
                    elseif returncode == 0 then
                        multipass_copyluafile(jobname)
                        newhash = multipass_hashfiles(jobname)
                        if multipass_changed(oldhash,newhash) then
                            oldhash = newhash
                        else
                            break
                        end
                    else
                        report("fatal error: return code: %s",returncode or "?")
                        if resultname then
                            result_save_error(oldbase,newbase)
                        end
                        os.exit(1) -- (returncode)
                        break
                    end
                    --
                end
                --
                if a_arrange then
                    --
                    c_flags.final      = true
                    c_flags.kindofrun  = 3
                    c_flags.currentrun = c_flags.currentrun + 1
                    c_flags.noarrange  = nil
                    --
                    local command = luatex_command(l_flags,c_flags,mainfile)
                    --
                    report("arrange run: %s",command)
                    local returncode, errorstring = os.spawn(command)
                    if not returncode then
                        report("fatal error: no return code, message: %s",errorstring or "?")
                        os.exit(1)
                    elseif returncode > 0 then
                        report("fatal error: return code: %s",returncode or "?")
                        os.exit(returncode)
                    end
                    --
                end
                --
                if a_purge then
                    scripts.context.purge_job(jobname)
                elseif a_purgeall then
                    scripts.context.purge_job(jobname,true)
                end
                --
                if resultname then
                    if a_purgeresult then
                        -- so, if there is no result then we don't get the old one, but
                        -- related files (log etc) are still there for tracing purposes
                        result_save_purge(oldbase,newbase)
                    else
                        result_save_keep(oldbase,newbase)
                    end
                    report("result renamed to: %s",newbase)
                end
                --
                if purge then
                    scripts.context.purge_job(resultname)
                elseif purgeall then
                    scripts.context.purge_job(resultname,true)
                end
                --
                local pdfview = getargument("autopdf")
                if pdfview then
                    pdf_open(resultname or jobname,pdfview)
                end
                --
                if a_timing then
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
    --
end

function scripts.context.pipe() -- still used?
    -- context --pipe
    -- context --pipe --purge --dummyfile=whatever.tmp
    local interface = getargument("interface")
    interface = (type(interface) == "string" and interface) or "en"
    local formatname = formatofinterface[interface] or "cont-en"
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
        local l_flags = {
            interaction = "scrollmode",
            fmt         = formatfile,
            lua         = scriptfile,
        }
        local c_flags = {
            backend     = "pdf",
            final       = false,
            kindofrun   = 3,
            currentrun  = 1,
        }
        local filename = getargument("dummyfile") or ""
        if filename == "" then
            filename = "\\relax"
            report("entering scrollmode, end job with \\end")
        else
            filename = file.addsuffix(filename,"tmp")
            io.savedata(filename,"\\relax")
            report("entering scrollmode using '%s' with optionfile, end job with \\end",filename)
        end
        local command = luatex_command(l_flags,c_flags,filename)
        os.spawn(command)
        if getargument("purge") then
            scripts.context.purge_job(filename)
        elseif getargument("purgeall") then
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
    local command = format("mtxrun texexec.rb --make --%s %s",name,engine)
    report("running command: %s",command)
    os.spawn(command)
end

function scripts.context.generate()
    resolvers.instance.renewcache = true
    trackers.enable("resolvers.locating")
    resolvers.load()
end

function scripts.context.make(name)
    if not getargument("fast") then -- as in texexec
        scripts.context.generate()
    end
    local list = (name and { name }) or (environment.files[1] and environment.files) or defaultformats
    local engine = getargument("engine") or "luatex"
    for i=1,#list do
        local name = list[i]
        name = formatofinterface[name] or name or ""
        if name == "" then
            -- nothing
        elseif engine == "luatex" then
            make_mkiv_format(name)
        elseif engine == "pdftex" or engine == "xetex" then
            make_mkii_format(name,engine)
        end
    end
end

function scripts.context.ctx()
    local ctxdata = ctxrunner.new()
    ctxdata.jobname = environment.files[1]
    ctxrunner.checkfile(ctxdata,getargument("ctx"))
    ctxrunner.checkflags(ctxdata)
    scripts.context.run(ctxdata)
end

function scripts.context.autoctx()
    local ctxdata = nil
    local files = environment.files
    local firstfile = #files > 0 and files[1]
    if firstfile then
        local suffix = file.suffix(firstfile)
        if suffix == "xml" then
            local chunk = io.loadchunk(firstfile) -- 1024
            if chunk then
                local ctxname = match(chunk,"<%?context%-directive%s+job%s+ctxfile%s+([^ ]-)%s*?>")
                if ctxname then
                    ctxdata = ctxrunner.new()
                    ctxdata.jobname = firstfile
                    ctxrunner.checkfile(ctxdata,ctxname)
                    ctxrunner.checkflags(ctxdata)
                end
            end
        elseif suffix == "tex" then
            -- maybe but we scan the preamble later too
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
    local formatname = getargument("format") or "metafun"
    if formatname == "" or type(formatname) == "boolean" then
        formatname = "metafun"
    end
    if getargument("pdf") then
        local basename = file.removesuffix(filename)
        local resultname = getargument("result") or basename
        local jobname = "mtx-context-metapost"
        local tempname = file.addsuffix(jobname,"tex")
        io.savedata(tempname,format(template,"metafun",filename))
        environment.files[1] = tempname
        setargument("result",resultname)
        setargument("once",true)
        scripts.context.run()
        scripts.context.purge_job(jobname,true)
        scripts.context.purge_job(resultname,true)
    elseif getargument("svg") then
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

-- purging files

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
    "synctex.gz", "pgf",
    "prep",
}

local persistent_runfiles = {
    "tuo", "tub", "top", "tuc"
}

local special_runfiles = {
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
    local all = all or getargument("all")
    local pattern = getargument("pattern") or (pattern and (pattern.."*")) or "*.*"
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

-- touching files (signals regeneration of formats)

local function touch(name,pattern)
    local name = resolvers.findfile(name)
    local olddata = io.loaddata(name)
    if olddata then
        local oldversion, newversion = "", os.date("%Y.%m.%d %H:%M")
        local newdata, ok = gsub(olddata,pattern,function(pre,mid,post)
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
    if getargument("expert") then
        touchfiles("mkii")
        touchfiles("mkiv")
        touchfiles("mkvi")
    else
        report("touching needs --expert")
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
        for i=1,#cards do
            resolvers.findwildcardfiles(cards[i],list)
        end
        -- my dev path
        for i=1,#cards do
            dir.glob(file.join(file.dirname(found),cards[i]),list)
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
    local extra = getargument("extra")
    if type(extra) ~= "string" then
        scripts.context.extras()
    elseif getargument("help") then
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
        setargument("purgeall",true)
        local result = getargument("result") or ""
        if result == "" then
            setargument("result","context-extra")
        end
        scripts.context.run(nil,foundextra)
    end
end

-- todo: we need to do a dummy run

function scripts.context.trackers()
    environment.files = { resolvers.findfile("m-trackers.mkiv") }
    multipass_nofruns = 1
    setargument("purgeall",true)
    scripts.context.run()
end

function scripts.context.directives()
    environment.files = { resolvers.findfile("m-directives.mkiv") }
    multipass_nofruns = 1
    setargument("purgeall",true)
    scripts.context.run()
end

function scripts.context.logcategories()
    environment.files = { resolvers.findfile("m-logcategories.mkiv") }
    multipass_nofruns = 1
    setargument("purgeall",true)
    scripts.context.run()
end

-- updating (often one will use mtx-update instead)

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
    local force = getargument("force")
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
            if find(basetree,pattern) then
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
            if find(filename,"/$") then
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

-- getting it done

if getargument("nostats") then
    setargument("nostatistics",true)
    setargument("nostat",nil)
end

if getargument("batch") then
    setargument("batchmode",true)
    setargument("batch",nil)
end

if getargument("nonstop") then
    setargument("nonstopmode",true)
    setargument("nonstop",nil)
end

do

    local silent = getargument("silent")
    if type(silent) == "string" then
        directives.enable(format("logs.blocked={%s}",silent))
    elseif silent then
        directives.enable("logs.blocked")
    end

end

if getargument("once") then
    multipass_nofruns = 1
elseif getargument("runs") then
    multipass_nofruns = tonumber(getargument("runs")) or nil
end

if getargument("profile") then
    os.setenv("MTX_PROFILE_RUN","YES")
end

if getargument("run") then
    scripts.context.timed(scripts.context.autoctx)
elseif getargument("make") then
    scripts.context.timed(function() scripts.context.make() end)
elseif getargument("generate") then
    scripts.context.timed(function() scripts.context.generate() end)
elseif getargument("ctx") then
    scripts.context.timed(scripts.context.ctx)
elseif getargument("mp") or getargument("metapost") then
    scripts.context.timed(scripts.context.metapost)
elseif getargument("version") then
    application.identify()
    scripts.context.version()
elseif getargument("touch") then
    scripts.context.touch()
elseif getargument("update") then
    scripts.context.update()
elseif getargument("expert") then
    application.help("expert", "special")
elseif getargument("modules") then
    scripts.context.modules()
elseif getargument("extras") then
    scripts.context.extras(environment.files[1] or getargument("extras"))
elseif getargument("extra") then
    scripts.context.extra()
elseif getargument("help") then
    if environment.files[1] == "extras" then
        scripts.context.extras()
    else
        application.help("basic")
    end
elseif getargument("showtrackers") or getargument("trackers") == true then
    scripts.context.trackers()
elseif getargument("showdirectives") or getargument("directives") == true then
    scripts.context.directives()
elseif getargument("showlogcategories") then
    scripts.context.logcategories()
elseif environment.files[1] or getargument("nofile") then
    scripts.context.timed(scripts.context.autoctx)
elseif getargument("pipe") then
    scripts.context.timed(scripts.context.pipe)
elseif getargument("purge") then
    -- only when no filename given, supports --pattern
    scripts.context.purge()
elseif getargument("purgeall") then
    -- only when no filename given, supports --pattern
    scripts.context.purge(true,nil,true)
else
    application.help("basic")
end

if getargument("profile") then
    os.setenv("MTX_PROFILE_RUN","NO")
end

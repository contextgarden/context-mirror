dofile(input.find_file(instance,"luat-log.lua"))

texmf.instance = instance -- we need to get rid of this / maybe current instance in global table

scripts         = scripts         or { }
scripts.context = scripts.context or { }

function io.copydata(fromfile,tofile)
    io.savedata(tofile,io.loaddata(fromfile) or "")
end

function input.locate_format(name) -- move this to core / luat-xxx
    local barename, fmtname = name:gsub("%.%a+$",""), ""
    if input.usecache then
        local path = file.join(cache.setpath(instance,"formats")) -- maybe platform
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

function scripts.context.multipass.makeoptionfile(jobname)
    local f = io.open(jobname..".top","w")
    if f then
        local finalrun, kindofrun, currentrun = false, 0, 0
        local function setvalue(flag,format,hash,default)
            local a = environment.argument(flag)
            a = a or default
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
            local a = environment.argument(flag)
            if a and a ~= "" then
                for _, v in a:gmatch("([^,]+)") do
                    f:write(format:format(v),"\n")
                end
            end
        end
        local function setfixed(flag,format,...)
            if environment.argument(flag) then
                f:write(format:format(...),"\n")
            end
        end
        local function setalways(format,...)
            f:write(format:format(...),"\n")
        end
        setalways("\\unprotect")
        setvalue('output'      , "\\setupoutput[%s]", scripts.context.backends, 'pdftex')
        setalways(               "\\setupsystem[\\c!n=%s,\\c!m=%s]", kindofrun, currentrun)
        setalways(               "\\setupsystem[\\c!type=%s]",os.platform)
        setfixed ("batchmode"  , "\\batchmode")
        setfixed ("nonstopmode", "\\nonstopmode")
        setfixed ("paranoid"   , "\\def\\maxreadlevel{1}")
        setvalue ("modefile"   , "\\readlocfile{%s}{}{}")
        setvalue ("result"     , "\\setupsystem[file=%s]")
        setvalue("path"        , "\\usepath[%s]")
        setfixed("color"       , "\\setupcolors[\\c!state=\\v!start]")
        setfixed("nompmode"    , "\\runMPgraphicsfalse") -- obsolete, we assume runtime mp graphics
        setfixed("nomprun"     , "\\runMPgraphicsfalse") -- obsolete, we assume runtime mp graphics
        setfixed("automprun"   , "\\runMPgraphicsfalse") -- obsolete, we assume runtime mp graphics
        setfixed("fast"        , "\\fastmode\n")
        setfixed("silentmode"  , "\\silentmode\n")
        setvalue("separation"  , "\\setupcolors[\\c!split=%s]")
        setvalue("setuppath"   , "\\setupsystem[\\c!directory={%s}]")
        setfixed("noarrange"   , "\\setuparranging[\\v!disable]")
        if environment.argument('arrange') and not finalrun then
            setalways(           "\\setuparranging[\\v!disable]")
        end
        setvalue("modes"       , "\\enablemode[%s]")
        setvalue("mode"        , "\\enablemode[%s]")
        setvalue("arguments"   , "\\setupenv[%s]")
        setvalue("randomseed"  , "\\setupsystem[\\c!random=%s]")
        setvalue("filters"     , "\\useXMLfilter[%s]")
        setvalue("usemodules"  , "\\usemodule[%s]")
        setvalue("environments", "\\environment %s ")
        setalways(               "\\protect")
        setalways(               "\\endinput")
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
                g:write((line:gsub("^c ","")),"\n")
            end
        end
        f:close()
        g:close()
    end
end

function scripts.context.run()
    -- todo: interface
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
                if pathname ~= "" and pathname ~= "." then
                    filename = "./" .. filename
                end
                local command = "luatex --fmt=" .. string.quote(formatfile) .. " --lua=" .. string.quote(scriptfile) .. " " .. string.quote(filename)
                local oldhash, newhash = scripts.context.multipass.hashfiles(jobname), { }
                scripts.context.multipass.makeoptionfile(jobname)
                for i=1, scripts.context.multipass.nofruns do
                    input.report(string.format("run %s: %s",i,command))
                    local returncode = os.execute(command)
                    input.report("return code: " .. returncode)
                    if returncode > 0 then
                        input.reportr("fatal error, run aborted")
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
            end
        else
            input.error("no format found with name " .. formatname)
        end
    end
end

function scripts.context.make()
    -- hack, should also be a shared function
    for _, name in ipairs( { "cont-en", "cont-nl", "mptopdf" } ) do
        local command = "luatools --make --compile " .. name
        input.report("running command: " .. command)
        os.execute(command)
    end
end

banner = banner .. " | context tools "

messages.help = [[
--run                 process (one or more) files
--make                generate formats
]]

input.verbose = true
input.start_timing(scripts.context)

if environment.argument("run") then
    scripts.context.run()
elseif environment.argument("make") then
    scripts.context.make()
else
    input.help(banner,messages.help)
end

input.stop_timing(scripts.context)
input.report("total runtime: " .. input.elapsedtime(scripts.context))

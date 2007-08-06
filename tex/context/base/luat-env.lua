-- filename : luat-env.lua
-- comment  : companion to luat-env.tex
-- author   : Hans Hagen, PRAGMA-ADE, Hasselt NL
-- copyright: PRAGMA ADE / ConTeXt Development Team
-- license  : see context related readme files

-- here we don't assume any extra libraries

if not versions then versions = { } end versions['luat-env'] = 1.001

-- environment

if not environment then environment = { } end

environment.useluc = false -- for testing
--~ environment.silent = true  -- for testing

if environment.silent == nil then environment.silent  = false end
if environment.useluc == nil then environment.useluc  = true  end

-- kpse is overloaded by this time

if environment.formatname  == nil then environment.formatname = tex.formatname                              end
if environment.formatpath  == nil then environment.formatpath = kpse.find_file(tex.formatname,"fmt") or "." end
if environment.jobname     == nil then environment.jobname    = tex.jobname                                 end
if environment.progname    == nil then environment.progname   = os.getenv("progname")    or "luatex"        end
if environment.engine      == nil then environment.engine     = os.getenv("engine")      or "context"       end
if environment.enginepath  == nil then environment.enginepath = os.getenv("SELFAUTOLOC") or "."             end
if environment.initex      == nil then environment.initex     = tex.formatname == ""                        end

environment.formatpath = string.gsub(environment.formatpath:gsub("\\","/"),"/([^/]-)$","")
environment.enginepath = string.gsub(environment.enginepath:gsub("\\","/"),"/([^/]-)$","")

if environment.formatname == ""  then environment.formatpath = "cont-en" end
if environment.formatpath == ""  then environment.formatpath = '.'       end
if environment.enginepath == ""  then environment.enginepath = '.'       end
if environment.version    == nil then environment.version    = "unknown" end

function environment.get(name)
    return os.getenv(name) or ""
end

function environment.cleanname(filename)
    if filename and filename ~= "" then
        return filename:gsub( "\\", "/")
    else -- leave nil and empty untouched
        return filename
    end
end

function environment.texfile(filename)
    return environment.cleanname(input.find_file(texmf.instance,filename,'tex'))
end

function environment.ctxfile(filename)
    return environment.cleanname(input.find_file(texmf.instance,filename,'tex'))
end

function environment.luafile(filename)
    return environment.cleanname(input.find_file(texmf.instance,filename,'tex') or input.find_file(texmf.instance,filename,'texmfscripts'))
end

function environment.showmessage(...) -- todo, cleaner
    if not environment.silent then
        if input and input.report then
            input.report(table.concat({...}," "))
        elseif texio and texio.write_nl then
            texio.write_nl("[[" .. table.concat({...}," ") .. "]]")
        else
            print("[[" .. table.concat({...}," ") .. "]]")
        end
    end
end

if not environment.jobname then environment.jobname  = "unknown" end

function environment.setlucpath()
    if environment.initex then
        environment.lucpath = nil
    else
        environment.lucpath = environment.formatpath .. "/lua/" .. environment.progname
    end
end

function environment.luafilechunk(filename)
    local filename = filename:gsub("%.%a+$", "") .. ".lua"
    local fullname = environment.luafile(filename)
    if fullname and fullname ~= "" then
        environment.showmessage("loading file", fullname)
        return loadfile(fullname)
    else
        environment.showmessage("unknown file", filename)
        return nil
    end
end

-- the next ones can use the previous ones

function environment.loadluafile(filename,register)
    filename = filename:gsub("%.%a+$", "") .. ".lua"
    local fullname = environment.luafile(filename)
    if fullname and fullname ~= "" then
        environment.showmessage("loading", fullname)
        if register then
            if not environment.regfil then
                environment.regfil = io.open('luafiles.tmp', 'w')
            end
            if environment.regfil then
                environment.regfil:write(fullname .."\n")
            end
        end
        dofile(fullname)
    else
        environment.showmessage("unknown file", filename)
    end
end

function environment.loadlucfile(filename,version)
    local filename = filename:gsub("%.%a+$", "")
    local fullname = nil
    if environment.initex or not environment.useluc then
        environment.loadluafile(filename,environment.initex)
    else
        if environment.lucpath and environment.lucpath ~= "" then
            fullname = environment.lucpath .. "/" .. filename .. ".luc"
            local chunk = loadfile(fullname) -- this way we don't need a file exists check
            if chunk then
                environment.showmessage("loading", fullname)
                assert(chunk)()
                if version then
--~                     if modules and modules[filename] and modules[filename].version ~= version then
--~                         environment.showmessage("version mismatch", filename,"lua=" .. modules[filename].version, "luc=" ..version)
--~                         environment.loadluafile(filename)
--~                     elseif versions and versions[filename] and versions[filename] ~= version then
--~                         environment.showmessage("version mismatch", filename,"lua=" .. versions[filename], "luc=" ..version)
--~                         environment.loadluafile(filename)
--~                     end
                    local v = version -- can be nil
                    if modules and modules[filename] then
                        v = modules[filename].version -- new
                    elseif versions and versions[filename] then
                        v = versions[filename]        -- old
                    end
                    if v ~= version then
                        environment.showmessage("version mismatch", filename,"lua=" .. v, "luc=" ..version)
                        environment.loadluafile(filename)
                    end

                end
            else
                environment.loadluafile(filename)
            end
        else
            environment.loadluafile(filename)
        end
    end
end

function environment.loadedctxfile(filename)
    local fullname = environment.ctxfile(filename)
    local i = io.open(fullname)
    if i then
        local data = i:read('*all')
        i:close()
        return data
    else
        environment.showmessage("missing",filename)
        return ""
    end
end

environment.setlucpath()

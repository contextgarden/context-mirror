-- filename : luat-zip.lua
-- comment  : companion to luat-lib.tex
-- author   : Hans Hagen, PRAGMA-ADE, Hasselt NL
-- copyright: PRAGMA ADE / ConTeXt Development Team
-- license  : see context related readme files

if not versions then versions = { } end versions['luat-zip'] = 1.001

local format = string.format

if zip and input then
    zip.supported = true
else
    zip           = { }
    zip.supported = false
end

if not zip.supported then

    if not input then input = { } end -- will go away

    function zip.openarchive        (...) return nil end -- needed ?
    function zip.closenarchive      (...)            end -- needed ?
    function input.usezipfile       (...)            end -- needed ?

else

    -- zip:///oeps.zip?name=bla/bla.tex
    -- zip:///oeps.zip?tree=tex/texmf-local

    local function validzip(str)
        if not str:find("^zip://") then
            return "zip:///" .. str
        else
            return str
        end
    end

    zip.archives        = { }
    zip.registeredfiles = { }

    function zip.openarchive(name)
        if not name or name == "" then
            return nil
        else
            local arch = zip.archives[name]
            if arch then
                return arch
            else
               local full = input.find_file(name) or ""
               local arch = (full ~= "" and zip.open(full)) or false
               zip.archives[name] = arch
               return arch
            end
        end
    end

    function zip.closearchive(name)
        if not name or name == "" and zip.archives[name] then
            zip.close(zip.archives[name])
            zip.archives[name] = nil
        end
    end

    -- zip:///texmf.zip?tree=/tex/texmf
    -- zip:///texmf.zip?tree=/tex/texmf-local
    -- zip:///texmf-mine.zip?tree=/tex/texmf-projects

    function input.locators.zip(specification) -- where is this used? startup zips (untested)
        specification = input.splitmethod(specification)
        local zipfile = specification.path
        local zfile = zip.openarchive(name) -- tricky, could be in to be initialized tree
        if input.trace > 0 then
            if zfile then
                input.logger('! zip locator, found: %s',specification.original)
            else
                input.logger('? zip locator, not found: %s',specification.original)
            end
        end
    end

    function input.hashers.zip(tag,name)
        input.report("loading zip file %s as %s",name,tag)
        input.usezipfile(tag .."?tree=" .. name)
    end

    function input.concatinators.zip(tag,path,name)
        if not path or path == "" then
            return tag .. '?name=' .. name
        else
            return tag .. '?name=' .. path .. "/" .. name
        end
    end

    function input.is_readable.zip(name)
        return true
    end

    function input.finders.zip(specification,filetype)
        specification = input.splitmethod(specification)
        if specification.path then
            local q = url.query(specification.query)
            if q.name then
                local zfile = zip.openarchive(specification.path)
                if zfile then
                    if input.trace > 0 then
                        input.logger('! zip finder, path: %s',specification.path)
                    end
                    local dfile = zfile:open(q.name)
                    if dfile then
                        dfile = zfile:close()
                        if input.trace > 0 then
                            input.logger('+ zip finder, name: %s',q.name)
                        end
                        return specification.original
                    end
                elseif input.trace > 0 then
                    input.logger('? zip finder, path %s',specification.path)
                end
            end
        end
        if input.trace > 0 then
            input.logger('- zip finder, name: %s',filename)
        end
        return unpack(input.finders.notfound)
    end

    function input.openers.zip(specification)
        local zipspecification = input.splitmethod(specification)
        if zipspecification.path then
            local q = url.query(zipspecification.query)
            if q.name then
                local zfile = zip.openarchive(zipspecification.path)
                if zfile then
                    if input.trace > 0 then
                        input.logger('+ zip starter, path: %s',zipspecification.path)
                    end
                    local dfile = zfile:open(q.name)
                    if dfile then
                        input.show_open(specification)
                        return input.openers.text_opener(specification,dfile,'zip')
                    end
                elseif input.trace > 0 then
                    input.logger('- zip starter, path %s',zipspecification.path)
                end
            end
        end
        if input.trace > 0 then
            input.logger('- zip opener, name: %s',filename)
        end
        return unpack(input.openers.notfound)
    end

    function input.loaders.zip(specification)
        specification = input.splitmethod(specification)
        if specification.path then
            local q = url.query(specification.query)
            if q.name then
                local zfile = zip.openarchive(specification.path)
                if zfile then
                    if input.trace > 0 then
                        input.logger('+ zip starter, path: %s',specification.path)
                    end
                    local dfile = zfile:open(q.name)
                    if dfile then
                        input.show_load(filename)
                        if input.trace > 0 then
                            input.logger('+ zip loader, name: %s',filename)
                        end
                        local s = dfile:read("*all")
                        dfile:close()
                        return true, s, #s
                    end
                elseif input.trace > 0 then
                    input.logger('- zip starter, path: %s',specification.path)
                end
            end
        end
        if input.trace > 0 then
            input.logger('- zip loader, name: %s',filename)
        end
        return unpack(input.openers.notfound)
    end

    -- zip:///somefile.zip
    -- zip:///somefile.zip?tree=texmf-local -> mount

    function input.usezipfile(zipname)
        zipname = validzip(zipname)
        if input.trace > 0 then
            input.logger('! zip use, file: %s',zipname)
        end
        local specification = input.splitmethod(zipname)
        local zipfile = specification.path
        if zipfile and not zip.registeredfiles[zipname] then
            local tree = url.query(specification.query).tree or ""
            if input.trace > 0 then
                input.logger('! zip register, file: %s',zipname)
            end
            local z = zip.openarchive(zipfile)
            if z then
                local instance = input.instance
                if input.trace > 0 then
                    input.logger("= zipfile, registering: %s",zipname)
                end
                input.starttiming(instance)
                input.aux.prepend_hash('zip',zipname,zipfile)
                input.aux.extend_texmf_var(zipname) -- resets hashes too
                zip.registeredfiles[zipname] = z
                instance.files[zipname] = input.aux.register_zip_file(z,tree or "")
                input.stoptiming(instance)
            elseif input.trace > 0 then
                input.logger("? zipfile, unknown: %s",zipname)
            end
        elseif input.trace > 0 then
            input.logger('! zip register, no file: %s',zipname)
        end
    end

    function input.aux.register_zip_file(z,tree)
        local files, filter = { }, ""
        if tree == "" then
            filter = "^(.+)/(.-)$"
        else
            filter = "^"..tree.."/(.+)/(.-)$"
        end
        if input.trace > 0 then
            input.logger('= zip filter: %s',filter)
        end
        local register, n = input.aux.register_file, 0
        for i in z:files() do
            local path, name = i.filename:match(filter)
            if path then
                if name and name ~= '' then
                    register(files, name, path)
                    n = n + 1
                else
                    -- directory
                end
            else
                register(files, i.filename, '')
                n = n + 1
            end
        end
        input.logger('= zip entries: %s',n)
        return files
    end

end

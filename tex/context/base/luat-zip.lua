-- filename : luat-zip.lua
-- comment  : companion to luat-lib.tex
-- author   : Hans Hagen, PRAGMA-ADE, Hasselt NL
-- copyright: PRAGMA ADE / ConTeXt Development Team
-- license  : see context related readme files

if not versions then versions = { } end versions['luat-zip'] = 1.001

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

    function zip.openarchive(instance,name)
        if not name or name == "" then
            return nil
        else
            local arch = zip.archives[name]
            if arch then
                return arch
            else
               local full = input.find_file(instance,name) or ""
               local arch = (full ~= "" and zip.open(full)) or false
               zip.archives[name] = arch
               return arch
            end
        end
    end

    function zip.closearchive(instance,name)
        if not name or name == "" and zip.archives[name] then
            zip.close(zip.archives[name])
            zip.archives[name] = nil
        end
    end

    -- zip:///texmf.zip?tree=/tex/texmf
    -- zip:///texmf.zip?tree=/tex/texmf-local
    -- zip:///texmf-mine.zip?tree=/tex/texmf-projects

    function input.locators.zip(instance,specification) -- where is this used? startup zips (untested)
        specification = input.splitmethod(specification)
        local zipfile = specification.path
        local zfile = zip.openarchive(instance,name) -- tricky, could be in to be initialized tree
        if zfile then
            input.logger('! zip locator', specification.original ..' found')
        else
            input.logger('? zip locator', specification.original ..' not found')
        end
    end

    function input.hashers.zip(instance,tag,name)
        input.report("loading zip file",name,"as",tag)
        input.usezipfile(instance,tag .."?tree=" .. name)
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

    function input.finders.zip(instance,specification,filetype)
        specification = input.splitmethod(specification)
        if specification.path then
            local q = url.query(specification.query)
            if q.name then
                local zfile = zip.openarchive(instance,specification.path)
                if zfile then
                    input.logger('! zip finder',specification.path)
                    local dfile = zfile:open(q.name)
                    if dfile then
                        dfile = zfile:close()
                        input.logger('+ zip finder',q.name)
                        return specification.original
                    end
                else
                    input.logger('? zip finder',specification.path)
                end
            end
        end
        input.logger('- zip finder',filename)
        return unpack(input.finders.notfound)
    end

    function input.openers.zip(instance,specification)
        local zipspecification = input.splitmethod(specification)
        if zipspecification.path then
            local q = url.query(zipspecification.query)
            if q.name then
                local zfile = zip.openarchive(instance,zipspecification.path)
                if zfile then
                    input.logger('+ zip starter',zipspecification.path)
                    local dfile = zfile:open(q.name)
                    if dfile then
                        input.show_open(specification)
                        return input.openers.text_opener(specification,dfile,'zip')
                    end
                else
                    input.logger('- zip starter',zipspecification.path)
                end
            end
        end
        input.logger('- zip opener',filename)
        return unpack(input.openers.notfound)
    end

    function input.loaders.zip(instance,specification)
        specification = input.splitmethod(specification)
        if specification.path then
            local q = url.query(specification.query)
            if q.name then
                local zfile = zip.openarchive(instance,specification.path)
                if zfile then
                    input.logger('+ zip starter',specification.path)
                    local dfile = zfile:open(q.name)
                    if dfile then
                        input.show_load(filename)
                        input.logger('+ zip loader',filename)
                        local s = dfile:read("*all")
                        dfile:close()
                        return true, s, #s
                    end
                else
                    input.logger('- zip starter',specification.path)
                end
            end
        end
        input.logger('- zip loader',filename)
        return unpack(input.openers.notfound)
    end

    -- zip:///somefile.zip
    -- zip:///somefile.zip?tree=texmf-local -> mount

    function input.usezipfile(instance,zipname)
        zipname = validzip(zipname)
        input.logger('! zip use','file '..zipname)
        local specification = input.splitmethod(zipname)
        local zipfile = specification.path
        if zipfile and not zip.registeredfiles[zipname] then
            local tree = url.query(specification.query).tree or ""
            input.logger('! zip register','file '..zipname)
            local z = zip.openarchive(instance,zipfile)
            if z then
                input.logger("= zipfile","registering "..zipname)
                input.starttiming(instance)
                input.aux.prepend_hash(instance,'zip',zipname,zipfile)
                input.aux.extend_texmf_var(instance,zipname) -- resets hashes too
                zip.registeredfiles[zipname] = z
                instance.files[zipname] = input.aux.register_zip_file(z,tree or "")
                input.stoptiming(instance)
            else
                input.logger("? zipfile","unknown "..zipname)
            end
        else
            input.logger('! zip register','no file '..zipname)
        end
    end

    function input.aux.register_zip_file(z,tree)
        local files, filter = { }, ""
        if tree == "" then
            filter = "^(.+)/(.-)$"
        else
            filter = "^"..tree.."/(.+)/(.-)$"
        end
        input.logger('= zip filter',filter)
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
        input.report('= zip entries',n)
        return files
    end

end

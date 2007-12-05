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
    function input.registerzipfile  (...)            end -- needed ?
    function input.usezipfile       (...)            end -- needed ?

else

    function input.locators.zip(instance,specification)
        local name, spec = specification:match("^(.-)##(.-)$")
        local f = io.open(name or specification)
        if f then -- todo: reuse code
            input.logger('! zip locator', specification..' found')
            if name and spec then
                input.aux.append_hash(instance,'zip',"zip##"..specification,name)
                input.aux.extend_texmf_var(instance, "zip##"..specification)
            else
                input.aux.append_hash(instance,'zip',"zip##"..specification.."##",specification)
                input.aux.extend_texmf_var(instance, "zip##"..specification.."##")
            end
            f:close()
        else
            input.logger('? zip locator', specification..' not found')
        end
    end

    function input.hashers.zip(instance,tag,name)
        input.report("loading zip file",name,"as",tag)
        input.registerzipfile(instance,name,tag)
    end

    function input.concatinators.zip(tag,path,name)
        return tag .. path .. '/' .. name
    end

    function input.is_readable.zip(name)
        return true
    end

    function input.finders.zip(instance,filename,filetype)
        local archive, dataname = filename:match("^(.+)##/*(.+)$")
        if archive and dataname then
            local zfile = zip.openarchive(archive)
            if not zfile then
               archive = input.find_file(instance,archive,filetype)
               zfile = zip.openarchive(archive)
            end
            if zfile then
                input.logger('! zip finder',archive)
                local dfile = zfile:open(dataname)
                if dfile then
                    dfile = zfile:close()
                    input.logger('+ zip finder',filename)
                    return 'zip##' .. filename
                end
            else
                input.logger('? zip finder',archive)
            end
        end
        input.logger('- zip finder',filename)
        return unpack(input.finders.notfound)
    end

    function input.openers.zip(instance,filename)
        if filename and filename ~= "" then
            local archive, dataname = filename:match("^(.-)##/*(.+)$")
            if archive and dataname then
                local zfile= zip.openarchive(archive)
                if zfile then
                    input.logger('+ zip starter',archive)
                    local dfile = zfile:open(dataname)
                    if dfile then
                        input.show_open(filename)
                        return input.openers.text_opener(filename,dfile,'zip')
                    end
                else
                    input.logger('- zip starter',archive)
                end
            end
        end
        input.logger('- zip opener',filename)
        return unpack(input.openers.notfound)
    end

    function input.loaders.zip(instance, filename) -- we could use input.openers.zip
        if filename and filename ~= "" then
            input.logger('= zip loader',filename)
            local archive, dataname = filename:match("^(.+)##/*(.+)$")
            if archive and dataname then
                local zfile = zip.openarchive(archive)
                if zfile then
                    input.logger('= zip starter',archive)
                    local dfile = zfile:open(dataname)
                    if dfile then
                        input.show_load(filename)
                        input.logger('+ zip loader',filename)
                        local s = dfile:read("*all")
                        dfile:close()
                        return true, s, #s
                    end
                else
                    input.logger('- zip starter',archive)
                end
            end
        end
        input.logger('- zip loader',filename)
        return unpack(input.loaders.notfound)
    end

    zip.archives        = { }
    zip.registeredfiles = { }

    function zip.openarchive(name)
        if name and name ~= "" and not zip.archives[name] then
            zip.archives[name] = zip.open(name)
        end
        return zip.archives[name]
    end

    function zip.closearchive(name)
        if zip.archives[name] then
            zip.close(archives[name])
            zip.archives[name] = nil
        end
    end

    -- aparte register maken voor user (register tex / zip), runtime tree register
    -- todo: alleen url syntax toestaan
    -- user function: also handle zip::name::path

    function input.usezipfile(instance,zipname) -- todo zip://
        zipname = input.normalize_name(zipname)
        if not zipname:find("^zip##") then
            zipname = "zip##"..zipname
        end
        input.logger('! zip user','file '..zipname)
        if not zipname:find("^zip##(.+)##(.-)$") then
            zipname = zipname .. "##" -- dummy spec
        end
        local tag = zipname
        local name = zipname:match("zip##(.+)##.-")
        input.aux.prepend_hash(instance,'zip',tag,name)
        input.aux.extend_texmf_var(instance, tag)
        input.registerzipfile(instance,name,tag)
    end

    function input.registerzipfile(instance,zipname,tag)
        if not zip.registeredfiles[zipname] then
            input.starttiming(instance)
            local z = zip.open(zipname)
            if not z then
                zipname = input.find_file(instance,zipname)
                z = zip.open(zipname)
            end
            if z then
                input.logger("= zipfile","registering "..zipname)
                zip.registeredfiles[zipname] = z
                input.aux.register_zip_file(instance,zipname,tag)
            else
                input.logger("? zipfile","unknown "..zipname)
            end
            input.stoptiming(instance)
        end
    end

    function input.aux.register_zip_file(instance,zipname,tagname)
        if zip.registeredfiles[zipname] then
            if not tagname:find("^zip##") then
                tagname = "zip##" .. tagname
            end
            local path, name, n = nil, nil, 0
            if not instance.files[tagname] then
                instance.files[tagname] = { }
            end
            local files, filter = instance.files[tagname], ""
            local subtree = tagname:match("^zip##.+##(.+)$")
            if subtree then
                filter = "^"..subtree.."/(.+)/(.-)$"
            else
                filter = "^(.+)/(.-)$"
            end
            input.logger('= zip filter',filter)
            -- we can consider putting a files.luc in the file
            local register = input.aux.register_file
            for i, _ in zip.registeredfiles[zipname]:files() do
                path, name = i.filename:match(filter)
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
            input.report(n, 'entries in', zipname)
        end
    end

end

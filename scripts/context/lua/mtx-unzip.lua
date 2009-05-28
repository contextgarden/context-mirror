-- maybe --pattern

logs.extendbanner("Simple Unzipper 0.10")

messages.help = [[
--list                list files in archive
--junk                flatten unzipped directory structure
--extract             extract files
]]

scripts          = scripts          or { }
scripts.unzipper = scripts.unzipper or { }

function scripts.unzipper.help()
    logs.help(messages.help)
end

function scripts.unzipper.opened()
    local filename = environment.files[1]
    if filename and filename ~= "" then
        filename = file.addsuffix(filename,'zip')
        local zipfile = zip.open(filename)
        if zipfile then
            return zipfile
        end
    end
    logs.report("unzip", "no zip file: " .. filename)
    return false
end

function scripts.unzipper.list()
    local zipfile = scripts.unzipper.opened()
    if zipfile then
        local n = 0
        for k in zipfile:files() do
            if #k.filename > n then n = #k.filename end
        end
        local files, paths, compressed, uncompressed = 0, 0, 0, 0
        for k in zipfile:files() do
            if k.filename:find("/$") then
                paths = paths + 1
                print(string.format("%s", k.filename:rpadd(n," ")))
            else
                files = files + 1
                local cs, us = k.compressed_size, k.uncompressed_size
                if cs > compressed then
                    compressed = cs
                end
                if us > uncompressed then
                    uncompressed = us
                end
                print(string.format("%s  % 9i  % 9i", k.filename:rpadd(n," "),cs,us))
            end
        end
        print(string.format("\n%s  % 9i  % 9i", (files .. " files, " .. paths .. " directories"):rpadd(n," "),compressed,uncompressed))
    end
end

function zip.loaddata(zipfile,filename)
    local f = zipfile:open(filename)
    if f then
        local data = f:read("*a")
        f:close()
        return data
    end
    return nil
end

function scripts.unzipper.extract()
    local zipfile = scripts.unzipper.opened()
    if zipfile then
        local junk = environment.arguments["j"] or environment.arguments["junk"]
        for k in zipfile:files() do
            local filename = k.filename
            if filename:find("/$") then
                if not junk then
                    lfs.mkdir(filename)
                end
            else
                local data = zip.loaddata(zipfile,filename)
                if data then
                    if junk then
                        filename = file.basename(filename)
                    end
                    io.savedata(filename,data)
                    print(filename)
                end
            end
        end
    end
end

if environment.arguments["h"] or environment.arguments["help"] then
    scripts.unzipper.help()
elseif environment.arguments["l"] or environment.arguments["list"] then
    scripts.unzipper.list(zipfile)
elseif environment.files[1] then -- implicit --extract
    scripts.unzipper.extract(zipfile)
else
    scripts.unzipper.help()
end

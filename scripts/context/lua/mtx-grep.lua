if not modules then modules = { } end modules ['mtx-babel'] = {
    version   = 1.001,
    comment   = "companion to mtxrun.lua",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

scripts      = scripts      or { }
scripts.grep = scripts.grep or { }

banner = banner .. " | simple grepper "

function scripts.grep.find(pattern, files, offset)
    if pattern and pattern ~= "" then
        local format = string.format
        input.starttiming(scripts.grep)
        local count, nofmatches, noffiles, nofmatchedfiles = environment.argument("count"), 0, 0, 0
        local function grep(name)
            local data = io.loaddata(name)
            if data then
                noffiles = noffiles + 1
                local n, m = 0, 0
                for line in data:gmatch("[^\n]+") do -- faster than loop over lines
                    n = n + 1
                    if line:find(pattern) then
                        m = m + 1
                        if not count then
                            input.log(format("%s %s: %s",name,n,line))
                            io.flush()
                        end
                    end
                end
                if count and m > 0 then
                    nofmatches = nofmatches + m
                    nofmatchedfiles = nofmatchedfiles + 1
                    input.log(format("%s: %s",name,m))
                    io.flush()
                end
            end
        end
--~         for i=offset or 1, #files do
--~             local filename = files[i]
--~             if filename:find("%*") then
--~                 for _, name in ipairs(dir.glob(filename)) do
--~                     grep(name)
--~                 end
--~             else
--~                 grep(filename)
--~             end
--~         end
        for i=offset or 1, #files do
            for _, name in ipairs(dir.glob(files[i])) do
                grep(name)
            end
        end
        input.stoptiming(scripts.grep)
        if count and nofmatches > 0 then
            input.log(format("\nfiles: %s, matches: %s, matched files: %s, runtime: %0.3f seconds",noffiles,nofmatches,nofmatchedfiles,input.loadtime(scripts.grep)))
        end
    end
end

messages.help = [[
--pattern             search for pattern (optional)
--count               count matches only
]]

input.verbose = true

local pattern = environment.argument("pattern")
local files   = environment.files and #environment.files > 0 and environment.files

if pattern and files then
    scripts.grep.find(pattern, files)
elseif files then
    scripts.grep.find(files[1], files, 2)
else
    input.help(banner,messages.help)
end

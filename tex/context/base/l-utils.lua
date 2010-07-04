if not modules then modules = { } end modules ['l-utils'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- hm, quite unreadable

local gsub, format = string.gsub, string.format
local concat = table.concat
local type, next = type, next

if not utils        then utils        = { } end
if not utils.merger then utils.merger = { } end
if not utils.lua    then utils.lua    = { } end

utils.report = utils.report or print

local merger = utils.merger

merger.strip_comment = true

local m_begin_merge   = "begin library merge"
local m_end_merge     = "end library merge"
local m_begin_closure = "do -- create closure to overcome 200 locals limit"
local m_end_closure   = "end -- of closure"

local m_pattern =
    "%c+" ..
    "%-%-%s+" .. m_begin_merge ..
    "%c+(.-)%c+" ..
    "%-%-%s+" .. m_end_merge ..
    "%c+"

local m_format =
    "\n\n-- " .. m_begin_merge ..
    "\n%s\n" ..
    "-- " .. m_end_merge .. "\n\n"

local m_faked =
    "-- " .. "created merged file" .. "\n\n" ..
    "-- " .. m_begin_merge .. "\n\n" ..
    "-- " .. m_end_merge .. "\n\n"

local function self_fake()
    return m_faked
end

local function self_nothing()
    return ""
end

local function self_load(name)
    local data = io.loaddata(name) or ""
    if data == "" then
        utils.report("merge: unknown file %s",name)
    else
        utils.report("merge: inserting %s",name)
    end
    return data or ""
end

local function self_save(name, data)
    if data ~= "" then
        if merger.strip_comment then
            -- saves some 20K
            local n = #data
            data = gsub(data,"%-%-~[^\n\r]*[\r\n]","")
            utils.report("merge: %s bytes of comment stripped, %s bytes of code left",n-#data,#data)
        end
        io.savedata(name,data)
        utils.report("merge: saving %s",name)
    end
end

local function self_swap(data,code)
    return data ~= "" and (gsub(data,m_pattern, function() return format(m_format,code) end, 1)) or ""
end

local function self_libs(libs,list)
    local result, f, frozen, foundpath = { }, nil, false, nil
    result[#result+1] = "\n"
    if type(libs) == 'string' then libs = { libs } end
    if type(list) == 'string' then list = { list } end
    for i=1,#libs do
        local lib = libs[i]
        for j=1,#list do
            local pth = gsub(list[j],"\\","/") -- file.clean_path
            utils.report("merge: checking library path %s",pth)
            local name = pth .. "/" .. lib
            if lfs.isfile(name) then
                foundpath = pth
            end
        end
        if foundpath then break end
    end
    if foundpath then
        utils.report("merge: using library path %s",foundpath)
        local right, wrong = { }, { }
        for i=1,#libs do
            local lib = libs[i]
            local fullname = foundpath .. "/" .. lib
            if lfs.isfile(fullname) then
                utils.report("merge: using library %s",fullname)
                right[#right+1] = lib
                result[#result+1] = m_begin_closure
                result[#result+1] = io.loaddata(fullname,true)
                result[#result+1] = m_end_closure
            else
                utils.report("merge: skipping library %s",fullname)
                wrong[#wrong+1] = lib
            end
        end
        if #right > 0 then
            utils.report("merge: used libraries: %s",concat(right," "))
        end
        if #wrong > 0 then
            utils.report("merge: skipped libraries: %s",concat(wrong," "))
        end
    else
        utils.report("merge: no valid library path found")
    end
    return concat(result, "\n\n")
end

function merger.selfcreate(libs,list,target)
    if target then
        self_save(target,self_swap(self_fake(),self_libs(libs,list)))
    end
end

function merger.selfmerge(name,libs,list,target)
    self_save(target or name,self_swap(self_load(name),self_libs(libs,list)))
end

function merger.selfclean(name)
    self_save(name,self_swap(self_load(name),self_nothing()))
end

function utils.lua.compile(luafile,lucfile,cleanup,strip) -- defaults: cleanup=false strip=true
    utils.report("lua: compiling %s into %s",luafile,lucfile)
    os.remove(lucfile)
    local command = "-o " .. string.quote(lucfile) .. " " .. string.quote(luafile)
    if strip ~= false then
        command = "-s " .. command
    end
    local done = os.spawn("texluac " .. command) == 0 or os.spawn("luac " .. command) == 0
    if done and cleanup == true and lfs.isfile(lucfile) and lfs.isfile(luafile) then
        utils.report("lua: removing %s",luafile)
        os.remove(luafile)
    end
    return done
end


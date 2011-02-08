if not modules then modules = { } end modules ['util-mrg'] = {
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

utilities        = utilities or {}
utilities.merger = utilities.merger or { } -- maybe mergers
utilities.report = logs and logs.reporter("system") or print

local merger     = utilities.merger

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
        utilities.report("merge: unknown file %s",name)
    else
        utilities.report("merge: inserting %s",name)
    end
    return data or ""
end

local function self_save(name, data)
    if data ~= "" then
        if merger.strip_comment then
            -- saves some 20K
            local n = #data
            data = gsub(data,"%-%-~[^\n\r]*[\r\n]","")
            utilities.report("merge: %s bytes of comment stripped, %s bytes of code left",n-#data,#data)
        end
        io.savedata(name,data)
        utilities.report("merge: saving %s",name)
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
            utilities.report("merge: checking library path %s",pth)
            local name = pth .. "/" .. lib
            if lfs.isfile(name) then
                foundpath = pth
            end
        end
        if foundpath then break end
    end
    if foundpath then
        utilities.report("merge: using library path %s",foundpath)
        local right, wrong = { }, { }
        for i=1,#libs do
            local lib = libs[i]
            local fullname = foundpath .. "/" .. lib
            if lfs.isfile(fullname) then
                utilities.report("merge: using library %s",fullname)
                right[#right+1] = lib
                result[#result+1] = m_begin_closure
                result[#result+1] = io.loaddata(fullname,true)
                result[#result+1] = m_end_closure
            else
                utilities.report("merge: skipping library %s",fullname)
                wrong[#wrong+1] = lib
            end
        end
        if #right > 0 then
            utilities.report("merge: used libraries: %s",concat(right," "))
        end
        if #wrong > 0 then
            utilities.report("merge: skipped libraries: %s",concat(wrong," "))
        end
    else
        utilities.report("merge: no valid library path found")
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

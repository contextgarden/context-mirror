if not modules then modules = { } end modules ['util-sql'] = {
    version   = 1.001,
    comment   = "companion to m-sql.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local format = string.format
local P, V, Ct, Cs, Cc, Cg, Cf, patterns, lpegmatch = lpeg.P, lpeg.V, lpeg.Ct, lpeg.Cs, lpeg.Cc, lpeg.Cg, lpeg.Cf, lpeg.patterns, lpeg.match

local trace_sql  = false  trackers.register("sql.trace",function(v) trace_sql = v end)
local report_state = logs.reporter("sql")

utilities.sql = utilities.sql or { }
local sql     = utilities.sql

local inifile = ""

-- todo:

if os.platform == "mswin" then
    inifile = "C:\\Program Files\\MySQL\\MySQL Server 5.5\\ld-test.ini"
else
    inifile = "/etc/mysql/ld-test.ini"
end

local separator = P("\t")
local newline   = patterns.newline
local entry     = Cs((1-separator-newline)^1)
local empty     = Cc("")

local getfirst  = Ct( entry * (separator * (entry+empty))^0) + newline
local skipfirst = (1-newline)^1 * newline

-- -- faster but less flexible:
--
-- local splitter  = Ct ( (getfirst)^1 )
--
-- local function splitdata(data)
--     return lpegmatch(splitter,data) or { }
-- end

local function splitdata(data)
    if data == "" then
        if trace_sql then
            report_state("no data")
        end
        return { }
    end
    local t = lpegmatch(getfirst,data) or { }
    if #t == 0 then
        if trace_sql then
            report_state("no banner")
        end
        return { }
    end
    -- quite generic, could be a helper
    local p = nil
    for i=1,#t do
        local ti = t[i]
        if trace_sql then
            report_state("field %s has name %q",i,ti)
        end
        local s = Cg(Cc(ti) * entry)
        if p then
            p = p * s
        else
            p = s
        end
        if i < #t then
            p = p * separator
        end
    end
    p = Cf(Ct("") * p,rawset) * newline^0
    local d = lpegmatch(skipfirst * Ct(p^0),data)
    return d or { }
end

local function preparedata(sqlfile,templatefile,mapping)
    local query = utilities.templates.load(templatefile,mapping)
    io.savedata(sqlfile,query)
end

local function fetchdata(sqlfile,datfile)
    local command
    if inifile ~= "" then
        command = format([[mysql --defaults-extra-file="%s" < %s > %s]],inifile,sqlfile,datfile)
    else
        command = format([[[mysql < %s > %s]],sqlfile,datfile)
    end
    if trace_sql then
        local t = os.clock()
        os.execute(command)
        report_state("fetchtime: %.3f sec",os.clock()-t) -- not okay under linux
    else
        os.execute(command)
    end
end

local function loaddata(datfile)
    if trace_sql then
        local t = os.clock()
        local data = io.loaddata(datfile) or ""
        report_state("datasize: %.3f MB",#data/1024/1024)
        report_state("loadtime: %.3f sec",os.clock()-t)
        return data
    else
        return io.loaddata(datfile) or ""
    end
end

local function convertdata(data)
    if trace_sql then
        local t = os.clock()
        data = splitdata(data)
        report_state("converttime: %.3f",os.clock()-t)
        report_state("entries: %s ",#data) -- #data-1 if indexed
    else
        return splitdata(data)
    end
end

-- todo: new, etc

function sql.fetch(templatefile,mapping)
    local sqlfile = file.nameonly(templatefile) .. "-temp.sql"
    local datfile = file.nameonly(templatefile) .. "-temp.dat"
    preparedata(sqlfile,templatefile,mapping)
    fetchdata(sqlfile,datfile)
    local data = loaddata(datfile)
    data = convertdata(data)
    return data
end

function sql.reuse(templatefile)
    local datfile = file.nameonly(templatefile) .. "-temp.dat"
    local data = loaddata(datfile)
    data = convertdata(data)
    return data
end

-- tex specific

if tex then

    function sql.prepare(sqlfile,mapping)
        if tex.systemmodes["first"] then
            return utilities.sql.fetch(sqlfile,mapping)
        else
            return utilities.sql.reuse(sqlfile)
        end
    end

else

    sql.prepare = utilities.sql.fetch

end

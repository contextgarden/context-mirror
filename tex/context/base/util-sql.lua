if not modules then modules = { } end modules ['util-sql'] = {
    version   = 1.001,
    comment   = "companion to m-sql.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- Of course we could use a library but we don't want another depedency and
-- there is a bit of flux in these libraries. Also, we want the data back in
-- a way that we like.

-- buffer template

local format = string.format
local rawset, setmetatable = rawset, setmetatable
local P, V, C, Ct, Cc, Cg, Cf, patterns, lpegmatch = lpeg.P, lpeg.V, lpeg.C, lpeg.Ct, lpeg.Cc, lpeg.Cg, lpeg.Cf, lpeg.patterns, lpeg.match

local osclock = os.clock or os.time

local trace_sql    = false  trackers.register("sql.trace",function(v) trace_sql = v end)
local report_state = logs.reporter("sql")

utilities.sql      = utilities.sql or { }
local sql          = utilities.sql

local separator    = P("\t")
local newline      = patterns.newline
local entry        = C((1-separator-newline)^1) -- C 10% faster than C
local empty        = Cc("")

local getfirst     = Ct( entry * (separator * (entry+empty))^0) + newline
local skipfirst    = (1-newline)^1 * newline

local defaults     = { __index =
    {
        resultfile     = "result.dat",
        templatefile   = "template.sql",
        queryfile      = "query.sql",
        variables      = { },
        username       = "default",
        password       = "default",
        host           = "localhost",
        port           = 3306,
        database       = "default",
    },
}

local engine  = "mysql"

local runners = { -- --defaults-extra-file="%inifile"
    mysql = [[mysql --user="%username%" --password="%password%" --host="%host%" --port=%port% --database="%database%" < "%queryfile%" > "%resultfile%"]]
}

-- Experiments with an p/action demonstrated that there is not much gain. We could do a runtime
-- capture but creating all the small tables is not faster and it doesn't work well anyway.

local function splitdata(data)
    if data == "" then
        if trace_sql then
            report_state("no data")
        end
        return { }, { }
    end
    local keys = lpegmatch(getfirst,data) or { }
    if #keys == 0 then
        if trace_sql then
            report_state("no banner")
        end
        return { }, { }
    end
    -- quite generic, could be a helper
    local p = nil
    local n = #keys
--     for i=1,n do
--         local key = keys[i]
--         if trace_sql then
--             report_state("field %s has name %q",i,key)
--         end
--         local s = Cg(Cc(key) * entry)
--         if p then
--             p = p * s
--         else
--             p = s
--         end
--         if i < n then
--             p = p * separator
--         end
--     end
    for i=1,n do
        local key = keys[i]
        if trace_sql then
            report_state("field %s has name %q",i,key)
        end
        local s = Cg(Cc(key) * entry)
        if p then
            p = p * separator * s
        else
            p = s
        end
    end
    p = Cf(Ct("") * p,rawset) * newline^0
    local entries = lpegmatch(skipfirst * Ct(p^0),data)
    return entries or { }, keys
end

-- I will add a bit more checking.

local function validspecification(specification)
    local presets = specification.presets
    if type(presets) == "string" then
        presets = dofile(presets)
    end
    if type(presets) == "table" then
        setmetatable(presets,defaults)
        setmetatable(specification,{ __index = presets })
    else
        setmetatable(specification,defaults)
    end
    local templatefile = specification.templatefile
    local queryfile    = specification.queryfile  or file.nameonly(templatefile) .. "-temp.sql"
    local resultfile   = specification.resultfile or file.nameonly(templatefile) .. "-temp.dat"
    specification.queryfile  = queryfile
    specification.resultfile = resultfile
    if trace_sql then
        report_state("template file: %q",templatefile)
        report_state("query file: %q",queryfile)
        report_state("result file: %q",resultfile)
    end
    return true
end

local function dataprepared(specification)
    local query = false
    if specification.template then
        query = utilities.templates.replace(specification.template,specification.variables)
    elseif specification.templatefile then
        query = utilities.templates.load(specification.templatefile,specification.variables)
    end
    if query then
        io.savedata(specification.queryfile,query)
        return true
    else
        -- maybe push an error
        os.remove(specification.queryfile)
    end
end

local function datafetched(specification)
    local command = utilities.templates.replace(runners[engine],specification)
    if trace_sql then
        local t = osclock()
        report_state("command: %s",command)
        os.execute(command)
        report_state("fetchtime: %.3f sec",osclock()-t) -- not okay under linux
    else
        os.execute(command)
    end
    return true
end

local function dataloaded(specification)
    if trace_sql then
        local t = osclock()
        local data = io.loaddata(specification.resultfile) or ""
        report_state("datasize: %.3f MB",#data/1024/1024)
        report_state("loadtime: %.3f sec",osclock()-t)
        return data
    else
        return io.loaddata(specification.resultfile) or ""
    end
end

local function dataconverted(data)
    if trace_sql then
        local t = osclock()
        local data, keys = splitdata(data)
        report_state("converttime: %.3f",osclock()-t)
        report_state("keys: %s ",#keys)
        report_state("entries: %s ",#data)
        return data, keys
    else
        return splitdata(data)
    end
end

-- todo: new, etc

function sql.fetch(specification)
    if trace_sql then
        report_state("fetching")
    end
    if not validspecification(specification) then
        report("error in specification")
        return
    end
    if not dataprepared(specification) then
        report("error in preparation")
        return
    end
    if not datafetched(specification) then
        report("error in fetching")
        return
    end
    local data = dataloaded(specification)
    if not data then
        report("error in loading")
        return
    end
    local data, keys = dataconverted(data)
    if not data then
        report("error in converting")
        return
    end
    return data, keys
end

function sql.reuse(specification)
    if trace_sql then
        report_state("reusing")
    end
    if not validspecification(specification) then
        report("error in specification")
        return
    end
    local data = dataloaded(specification)
    if not data then
        report("error in loading")
        return
    end
    local data, keys = dataconverted(data)
    if not data then
        report("error in converting")
        return
    end
    return data, keys
end

sql.splitdata = splitdata

-- -- --

-- local data = utilities.sql.prepare {
--     templatefile = "ld-003.sql",
--     variables    = { },
--     host         = "...",
--     username     = "...",
--     password     = "...",
--     database     = "...",
-- }

-- local presets = {
--     host     = "...",
--     username = "...",
--     password = "...",
--     database = "...",
-- }
--
-- local data = utilities.sql.prepare {
--     templatefile = "ld-003.sql",
--     variables    = { },
--     presets      = presets,
-- }

-- local data = utilities.sql.prepare {
--     templatefile = "ld-003.sql",
--     variables    = { },
--     presets      = dofile(...),
-- }

-- local data = utilities.sql.prepare {
--     templatefile = "ld-003.sql",
--     variables    = { },
--     presets      = "...",
-- }

-- -- --

if tex and tex.systemmodes then

    function sql.prepare(specification)
        if tex.systemmodes["first"] then
            return sql.fetch(specification)
        else
            return sql.reuse(specification)
        end
    end

else

    sql.prepare = sql.fetch

end

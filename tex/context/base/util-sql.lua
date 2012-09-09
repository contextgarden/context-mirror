if not modules then modules = { } end modules ['util-sql'] = {
    version   = 1.001,
    comment   = "companion to m-sql.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- Of course we could use a library but we don't want another depedency and there is
-- a bit of flux in these libraries. Also, we want the data back in a way that we
-- like.
--
-- This is the first of set of sql related modules that are providing functionality
-- for a web based framework that we use for typesetting (related) services. We're
-- talking of session management, job ticket processing, storage, (xml) file processing
-- and dealing with data from databases (often ambitiously called database publishing).
--
-- There is no generic solution for such services, but from our perspective, as we use
-- context in a regular tds tree (the standard distribution) it makes sense to put shared
-- code in the context distribution. That way we don't need to reinvent wheels every time.

local format = string.format
local random = math.random
local rawset, setmetatable, loadstring, type = rawset, setmetatable, loadstring, type
local P, S, V, C, Cs, Ct, Cc, Cg, Cf, patterns, lpegmatch = lpeg.P, lpeg.S, lpeg.V, lpeg.C, lpeg.Cs, lpeg.Ct, lpeg.Cc, lpeg.Cg, lpeg.Cf, lpeg.patterns, lpeg.match
local concat = table.concat

local osuuid          = os.uuid
local osclock         = os.clock or os.time

local trace_sql       = false  trackers.register("sql.trace",  function(v) trace_sql     = v end)
local trace_queries   = false  trackers.register("sql.queries",function(v) trace_queries = v end)
local report_state    = logs.reporter("sql")

utilities.sql         = utilities.sql or { }
local sql             = utilities.sql

local replacetemplate = utilities.templates.replace
local loadtemplate    = utilities.templates.load

local methods         = { }
sql.methods           = methods

sql.serialize         = table.fastserialize
sql.deserialize       = table.deserialize

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

-- Experiments with an p/action demonstrated that there is not much gain. We could do a runtime
-- capture but creating all the small tables is not faster and it doesn't work well anyway.

local separator    = P("\t")
local newline      = patterns.newline
local empty        = Cc("")

local entry        = C((1-separator-newline)^0) -- C 10% faster than Cs

local unescaped    = P("\\n")  / "\n"
                   + P("\\t")  / "\t"
                   + P("\\\\") / "\\"

local entry        = Cs((unescaped + (1-separator-newline))^0) -- C 10% faster than Cs but Cs needed due to nesting

local getfirst     = Ct( entry * (separator * (entry+empty))^0) + newline
local skipfirst    = (1-newline)^1 * newline
local getfirstline = C((1-newline)^0)

local cache = { }

local function splitdata(data) -- todo: hash on first line
    if data == "" then
        if trace_sql then
            report_state("no data")
        end
        return { }, { }
    end
    local first = lpegmatch(getfirstline,data)
    if not first then
        if trace_sql then
            report_state("no data")
        end
        return { }, { }
    end
    local p = cache[first]
    if p then
     -- report_state("reusing: %s",first)
        local entries = lpegmatch(p.parser,data)
        return entries or { }, p.keys
    elseif p == false then
        return { }, { }
    elseif p == nil then
        local keys = lpegmatch(getfirst,first) or { }
        if #keys == 0 then
            if trace_sql then
                report_state("no banner")
            end
            cache[first] = false
            return { }, { }
        end
        -- quite generic, could be a helper
        local n = #keys
        if n == 0 then
            report_state("no fields")
            cache[first] = false
            return { }, { }
        end
        if n == 1 then
            local key = keys[1]
            if trace_sql then
                report_state("one field with name",key)
            end
            p = Cg(Cc(key) * entry)
        else
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
        end
        p = Cf(Ct("") * p,rawset) * newline^1
        p = skipfirst * Ct(p^0)
        cache[first] = { parser = p, keys = keys }
        local entries = lpegmatch(p,data)
        return entries or { }, keys
    end
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
        report_state("template file: %q",templatefile or "<none>")
        report_state("query file: %q",queryfile)
        report_state("result file: %q",resultfile)
    end
    return true
end

local function preparetemplate(specification)
    local template = specification.template
    if template then
        local query = replacetemplate(template,specification.variables,'sql')
        if not query then
            report_state("error in template: %s",template)
        elseif trace_queries then
            report_state("query from template: %s",query)
        end
        return query
    end
    local templatefile = specification.templatefile
    if templatefile then
        local query = loadtemplate(templatefile,specification.variables,'sql')
        if not query then
            report_state("error in template file %q",templatefile)
        elseif trace_queries then
            report_state("query from template file %q: %s",templatefile,query)
        end
        return query
    end
    report_state("no query template or templatefile")
end


local function dataprepared(specification)
    local query = preparetemplate(specification)
    if query then
        io.savedata(specification.queryfile,query)
        os.remove(specification.resultfile)
        if trace_queries then
            report_state("query: %s",query)
        end
        return true
    else
        -- maybe push an error
        os.remove(specification.queryfile)
        os.remove(specification.resultfile)
    end
end

local function datafetched(specification,runner)
    local command = replacetemplate(runner,specification)
    if trace_sql then
        local t = osclock()
        report_state("command: %s",command)
        local okay = os.execute(command)
        report_state("fetchtime: %.3f sec",osclock()-t) -- not okay under linux
        return okay == 0
    else
        return os.execute(command) == 0
    end
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

sql.splitdata = splitdata

-- todo: new, etc

local function execute(specification)
    if trace_sql then
        report_state("executing")
    end
    if not validspecification(specification) then
        report_state("error in specification")
        return
    end
    if not dataprepared(specification) then
        report_state("error in preparation")
        return
    end
    if not datafetched(specification,methods.client.runner) then
        report_state("error in fetching, query: %s",string.collapsespaces(io.loaddata(specification.queryfile)))
        return
    end
    local data = dataloaded(specification)
    if not data then
        report_state("error in loading")
        return
    end
    local data, keys = dataconverted(data)
    if not data then
        report_state("error in converting")
        return
    end
    return data, keys
end

methods.client = {
    runner      = [[mysql --batch --user="%username%" --password="%password%" --host="%host%" --port=%port% --database="%database%" < "%queryfile%" > "%resultfile%"]],
    execute     = execute,
    serialize   = serialize,
    deserialize = deserialize,
}

local function dataloaded(specification)
    if trace_sql then
        local t = osclock()
        local data = table.load(specification.resultfile)
        report_state("loadtime: %.3f sec",osclock()-t)
        return data
    else
        return table.load(specification.resultfile)
    end
end

local function dataconverted(data)
    if trace_sql then
        local data, keys = data.data, data.keys
        report_state("keys: %s ",#keys)
        report_state("entries: %s ",#data)
        return data, keys
    else
        return data.data, data.keys
    end
end

local function execute(specification)
    if trace_sql then
        report_state("executing")
    end
    if not validspecification(specification) then
        report_state("error in specification")
        return
    end
    if not dataprepared(specification) then
        report_state("error in preparation")
        return
    end
    if not datafetched(specification,methods.lmxsql.runner) then
        report_state("error in fetching, query: %s",string.collapsespaces(io.loaddata(specification.queryfile)))
        return
    end
    local data = dataloaded(specification)
    if not data then
        report_state("error in loading")
        return
    end
    local data, keys = dataconverted(data)
    if not data then
        report_state("error in converting")
        return
    end
    return data, keys
end

methods.lmxsql = {
    runner      = [[lmx-sql %host% %port% "%username%" "%password%" "%database%" "%queryfile%" "%resultfile%"]],
    execute     = execute,
    serialize   = serialize,
    deserialize = deserialize,
}

local mysql = nil
local cache = { }

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
    return true
end

local dataprepared = preparetemplate

local function connect(session,specification)
    return session:connect(
        specification.database or "",
        specification.username or "",
        specification.password or "",
        specification.host     or "",
        specification.port
    )
end

local whitespace = patterns.whitespace^0
local separator  = P(";")
local escaped    = patterns.escaped
local dquote     = patterns.dquote
local squote     = patterns.squote
local dsquote    = squote * squote
----  quoted     = patterns.quoted
local quoted     = dquote * (escaped + (1-dquote))^0 * dquote
                 + squote * (escaped + dsquote + (1-squote))^0 * squote
local query      = whitespace
                 * Cs((quoted + 1 - separator)^1 * Cc(";"))
                 * whitespace
local splitter   = Ct(query * (separator * query)^0)

local function datafetched(specification,query)
    local id = specification.id
    local session, connection
    if id then
        local c = cache[id]
        if c then
            session    = c.session
            connection = c.connection
        end
        if not connection then
            session = mysql()
            connection = connect(session,specification)
            cache[id] = { session = session, connection = connection }
        end
    else
        session = mysql()
        connection = connect(session,specification)
    end
    if not connection then
        return { }, { }
    end
    query = lpegmatch(splitter,query)
    local result, message
    for i=1,#query do
        local q = query[i]
        result, message = connection:execute(q)
        if message then
            report_state("error in query: %s",string.collapsespaces(q))
        end
    end
    if not result and id then
        if session then
            session:close()
        end
        if connection then
            connection:close()
        end
        session = mysql() -- maybe not needed
        connection = connect(session,specification)
        cache[id] = { session = session, connection = connection }
        for i=1,#query do
            local q = query[i]
            result, message = connection:execute(q)
            if message then
                report_state("error in query: %s",string.collapsespaces(q))
            end
        end
    end
    local data, keys
    if result and type(result) ~= "number" then
        keys = result:getcolnames()
        if keys then
            local n = result:numrows() or 0
            if n == 0 then
                data = { }
            elseif n == 1 then
                data = { result:fetch({},"a") }
            else
                data = { }
                for i=1,n do
                    data[i] = result:fetch({},"a")
                end
            end
        end
        result:close()
    elseif message then
        report_state("message %s",message)
    end
    if not keys then
        keys = { }
    end
    if not data then
        data = { }
    end
    if not id then
        connection:close()
        session:close()
    end
    return data, keys
end

local function execute(specification)
    if not mysql then
        local lib = require("luasql.mysql")
        if lib then
            mysql = lib.mysql
        else
            report_state("error in loading luasql.mysql")
        end
    end
    if trace_sql then
        report_state("executing")
    end
    if not validspecification(specification) then
        report_state("error in specification")
        return
    end
    local query = dataprepared(specification)
    if not query then
        report_state("error in preparation")
        return
    end
    local data, keys = datafetched(specification,query)
    if not data then
        report_state("error in fetching")
        return
    end
    return data, keys
end

methods.library = {
    runner      = function() end, -- never called
    execute     = execute,
    serialize   = serialize,
    deserialize = deserialize,
}

-- -- --

local currentmethod

function sql.setmethod(method)
    local m = methods[method]
    if m then
        currentmethod = method
        sql.execute = m.execute
        return m
    else
        return methods[currentmethod]
    end
end

sql.setmethod("client")

-- local data = utilities.sql.prepare {
--     templatefile = "test.sql",
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
--     templatefile = "test.sql",
--     variables    = { },
--     presets      = presets,
-- }

-- local data = utilities.sql.prepare {
--     templatefile = "test.sql",
--     variables    = { },
--     presets      = dofile(...),
-- }

-- local data = utilities.sql.prepare {
--     templatefile = "test.sql",
--     variables    = { },
--     presets      = "...",
-- }

sql.tokens = {
    length = 42,
    new    = function()
        return format("%s+%05x",osuuid(),random(1,0xFFFFF)) -- 36 + 1 + 5 = 42
    end,
}

-- -- --

if tex and tex.systemmodes then

    local droptable = table.drop
    local threshold = 16 * 1024 -- use slower but less memory hungry variant

    function sql.prepare(specification,tag)
        -- could go into tuc if needed
        -- todo: serialize per column
        local filename = format("%s-sql-result-%s.tuc",tex.jobname,tag or "last")
        if tex.systemmodes["first"] then
            local data, keys = sql.execute(specification)
            if not data then
                data = { }
            end
            if not keys then
                keys = { }
            end
            io.savedata(filename,droptable({ data = data, keys = keys },#keys*#data>threshold))
            return data, keys
        else
            local result = table.load(filename)
            return result.data, result.keys
        end
    end

else

    sql.prepare = sql.execute

end

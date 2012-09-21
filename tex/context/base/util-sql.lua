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

-- For some reason the sql lib partially fails in luatex when creating hashed row. So far
-- we couldn't figure it out (some issue with adapting the table that is passes as first
-- argument in the fetch routine. Apart from this it looks like the mysql binding has some
-- efficiency issues (like creating a keys and types table for each row) but that could be
-- optimized. Anyhow, fecthing results can be done as follows:

-- We use the template mechanism from util-tpl which inturn is just using the dos cq
-- windows convention of %whatever% variables that I've used for ages.

-- local function collect_1(r)
--     local t = { }
--     for i=1,r:numrows() do
--         t[#t+1] = r:fetch({},"a")
--     end
--     return t
-- end
--
-- local function collect_2(r)
--     local keys   = r:getcolnames()
--     local n      = #keys
--     local t      = { }
--     for i=1,r:numrows() do
--         local v = { r:fetch() }
--         local r = { }
--         for i=1,n do
--             r[keys[i]] = v[i]
--         end
--         t[#t+1] = r
--     end
--     return t
-- end
--
-- local function collect_3(r)
--     local keys   = r:getcolnames()
--     local n      = #keys
--     local t      = { }
--     for i=1,r:numrows() do
--         local v = r:fetch({},"n")
--         local r = { }
--         for i=1,n do
--             r[keys[i]] = v[i]
--         end
--         t[#t+1] = r
--     end
--     return t
-- end
--
-- On a large table with some 8 columns (mixed text and numbers) we get the following
-- timings (the 'a' alternative is already using the more efficient variant in the
-- binding).
--
-- collect_1 : 1.31
-- collect_2 : 1.39
-- collect_3 : 1.75
--
-- Some, as a workaround for this 'bug' the second alternative can be used.

local format, match = string.format, string.match
local random = math.random
local rawset, setmetatable, getmetatable, loadstring, type = rawset, setmetatable, getmetatable, loadstring, type
local P, S, V, C, Cs, Ct, Cc, Cg, Cf, patterns, lpegmatch = lpeg.P, lpeg.S, lpeg.V, lpeg.C, lpeg.Cs, lpeg.Ct, lpeg.Cc, lpeg.Cg, lpeg.Cf, lpeg.patterns, lpeg.match
local concat = table.concat

local osuuid          = os.uuid
local osclock         = os.clock or os.time
local ostime          = os.time

local trace_sql       = false  trackers.register("sql.trace",  function(v) trace_sql     = v end)
local trace_queries   = false  trackers.register("sql.queries",function(v) trace_queries = v end)
local report_state    = logs.reporter("sql")

-- trace_sql     = true
-- trace_queries = true

utilities.sql         = utilities.sql or { }
local sql             = utilities.sql

local replacetemplate = utilities.templates.replace
local loadtemplate    = utilities.templates.load

local methods         = { }
sql.methods           = methods

local serialize       = table.fastserialize
local deserialize     = table.deserialize

sql.serialize         = serialize
sql.deserialize       = deserialize

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
        local m = getmetatable(presets)
        if m then
            setmetatable(m,defaults)
        else
            setmetatable(presets,defaults)
        end
        setmetatable(specification,{ __index = presets })
    else
        setmetatable(specification,defaults)
    end
    local templatefile = specification.templatefile or "query"
    local queryfile    = specification.queryfile  or presets.queryfile  or file.nameonly(templatefile) .. "-temp.sql"
    local resultfile   = specification.resultfile or presets.resultfile or file.nameonly(templatefile) .. "-temp.dat"
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
        report_state("executing client")
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
    usesfiles   = true,
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
        report_state("executing lmxsql")
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
    usesfiles   = true,
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
local eol        = patterns.eol
local separator  = P(";")
local escaped    = patterns.escaped
local dquote     = patterns.dquote
local squote     = patterns.squote
local dsquote    = squote * squote
----  quoted     = patterns.quoted
local quoted     = dquote * (escaped + (1-dquote))^0 * dquote
                 + squote * (escaped + dsquote + (1-squote))^0 * squote
local comment    = P("--") * (1-eol) / ""
local query      = whitespace
                 * Cs((quoted + comment + 1 - separator)^1 * Cc(";"))
                 * whitespace
local splitter   = Ct(query * (separator * query)^0)

local function datafetched(specification,query,converter)
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
        report_state("error in connection: %s@%s to %s:%s",
                specification.database or "no database",
                specification.username or "no username",
                specification.host     or "no host",
                specification.port     or "no port"
            )
        return { }, { }
    end
    query = lpegmatch(splitter,query)
    local result, message, okay
    for i=1,#query do
        local q = query[i]
        local r, m = connection:execute(q)
        if m then
            report_state("error in query, stage 1: %s",string.collapsespaces(q))
            message = message and format("%s\n%s",message,m) or m
        end
        local t = type(r)
        if t == "userdata" then
            result = r
            okay = true
        elseif t == "number" then
            okay = true
        end
    end
    if not okay and id then
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
            local r, m = connection:execute(q)
            if m then
                report_state("error in query, stage 2: %s",string.collapsespaces(q))
                message = message and format("%s\n%s",message,m) or m
            end
            local t = type(r)
            if t == "userdata" then
                result = r
                okay = true
            elseif t == "number" then
                okay = true
            end
        end
    end
    local data, keys
    if result then
        if converter then
            data = converter(result,deserialize)
        else
            keys = result:getcolnames()
            if keys then
                local n = result:numrows() or 0
                if n == 0 then
                    data = { }
             -- elseif n == 1 then
             --  -- data = { result:fetch({},"a") }
                else
                    data = { }
                 -- for i=1,n do
                 --     data[i] = result:fetch({},"a")
                 -- end
                    local k = #keys
                    for i=1,n do
                        local v = { result:fetch() }
                        local d = { }
                        for i=1,k do
                            d[keys[i]] = v[i]
                        end
                        data[#data+1] = d
                    end
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
        report_state("executing library")
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
    local data, keys = datafetched(specification,query,specification.converter)
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
    usesfiles   = false,
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

-- helper:

local execute = sql.execute

function sql.usedatabase(presets,datatable)
    local name = datatable or presets.datatable
    if name then
        local method   = presets.method and sql.methods[presets.method] or sql.methods.client
        local base     = presets.database or "test"
        local basename = format("`%s`.`%s`",base,name)
        m_execute   = execute
        deserialize = deserialize
        serialize   = serialize
        if method then
            m_execute   = method.execute     or m_execute
            deserialize = method.deserialize or deserialize
            serialize   = method.serialize   or serialize
        end
        local execute
        if method.usesfiles then
            local queryfile   = presets.queryfile  or format("%s-temp.sql",name)
            local resultfile  = presets.resultfile or format("%s-temp.dat",name)
            execute = function(specification) -- variables template
                if not specification.presets    then specification.presets    = presets   end
                if not specification.queryfile  then specification.queryfile  = queryfile end
                if not specification.resultfile then specification.resultfile = queryfile end
                return m_execute(specification)
            end
        else
            execute = function(specification) -- variables template
                if not specification.presets then specification.presets = presets end
                return m_execute(specification)
            end
        end
        local function unpackdata(records,name)
            if records then
                name = name or "data"
                for i=1,#records do
                    local record = records[i]
                    local data = record[name]
                    if data then
                        record[name] = deserialize(data)
                    end
                end
            end
        end
        return {
            presets     = preset,
            base        = base,
            name        = name,
            basename    = basename,
            execute     = execute,
            serialize   = serialize,
            deserialize = deserialize,
            unpackdata  = unpackdata,
        }
    end
end


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

-- for i=1,10 do
--     local dummy = uuid() -- else same every time, don't ask
-- end

sql.tokens = {
    length = 42, -- but in practice we will reserve some 50 characters
    new    = function()
        return format("%s-%x05",osuuid(),random(0xFFFFF)) -- 36 + 1 + 5 = 42
    end,
}

-- -- --

local converters = { }

sql.converters = converters

local template = [[
local converters = utilities.sql.converters

local tostring   = tostring
local tonumber   = tonumber
local toboolean  = toboolean

%s

return function(result,deserialize)
    if not result then
        return { }
    end
    local nofrows = result:numrows() or 0
    if nofrows == 0 then
        return { }
    end
    local data = { }
    for i=1,nofrows do
        local v = { result:fetch() }
        data[#data+1] = {
            %s
        }
    end
    return data
end
]]

function sql.makeconverter(entries,deserialize)
    local shortcuts   = { }
    local assignments = { }
    for i=1,#entries do
        local entry = entries[i]
        local nam   = entry.name
        local typ   = entry.type
        if typ == "boolean" then
            assignments[i] = format("[%q] = toboolean(v[%s],true),",nam,i)
        elseif typ == "number" then
            assignments[i] = format("[%q] = tonumber(v[%s]),",nam,i)
        elseif type(typ) == "function" then
            local c = #converters + 1
            converters[c] = typ
            shortcuts[#shortcuts+1] = format("local fun_%s = converters[%s]",c,c)
            assignments[i] = format("[%q] = fun_%s(v[%s]),",nam,c,i)
        elseif type(typ) == "table" then
            local c = #converters + 1
            converters[c] = typ
            shortcuts[#shortcuts+1] = format("local tab_%s = converters[%s]",c,c)
            assignments[i] = format("[%q] = tab_%s[v[%s]],",nam,#converters,i)
        elseif typ == "deserialize" then
            assignments[i] = format("[%q] = deserialize(v[%s]),",nam,i)
        else
            assignments[i] = format("[%q] = v[%s],",nam,i)
        end
    end
    local code = string.format(template,table.concat(shortcuts,"\n"),table.concat(assignments,"\n            "))
    local func = loadstring(code)
    if type(func) == "function" then
        return func(), code
    else
        return false, code
    end
end

-- local func, code = sql.makeconverter {
--     { name = "a", type = "number" },
--     { name = "b", type = "string" },
--     { name = "c", type = "boolean" },
--     { name = "d", type = { x = "1" } },
--     { name = "e", type = os.fulltime },
-- }
--
-- print(code)

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

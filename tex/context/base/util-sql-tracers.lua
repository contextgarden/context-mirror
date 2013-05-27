if not modules then modules = { } end modules ['util-sql-tracers'] = {
    version   = 1.001,
    comment   = "companion to m-sql.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local sql     = utilities.sql
local tracers = { }
sql.tracers   = tracers

sql.setmethod("swiglib")

function sql.tracers.gettables(presets)
    local results, keys = sql.execute {
        presets   = presets,
        template  = "SHOW TABLES FROM `%database%`",
        variables = {
            database = presets.database,
        },
    }

    local key    = keys[1]
    local tables = { }

    for i=1,#results do
        local name = results[i][key]
        local results, keys = sql.execute {
            presets   = presets,
            template  = "SHOW FIELDS FROM `%database%`.`%table%` ",
            variables = {
                database = presets.database,
                table    = name
            },
        }
        if #results > 0 then
            for i=1,#results do
                results[i] = table.loweredkeys(results[i])
            end
            tables[name] = results
        else
            -- a view
        end
    end

    return tables
end

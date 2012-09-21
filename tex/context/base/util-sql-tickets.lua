if not modules then modules = { } end modules ['util-sql-tickets'] = {
    version   = 1.001,
    comment   = "companion to lmx-*",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- This is experimental code and currently part of the base installation simply
-- because it's easier to dirtribute this way. Eventually it will be documented
-- and the related scripts will show up as well.

local tonumber = tonumber
local format = string.format
local ostime, uuid, osfulltime = os.time, os.uuid, os.fulltime
local random = math.random
local concat = table.concat

local sql         = utilities.sql
local tickets     = { }
sql.tickets       = tickets

local trace_sql   = false  trackers.register("sql.tickets.trace", function(v) trace_sql = v end)
local report      = logs.reporter("sql","tickets")

local serialize   = sql.serialize
local deserialize = sql.deserialize
local execute     = sql.execute

tickets.newtoken  = sql.tokens.new

local statustags  = { [0] = -- beware index can be string or number, maybe status should be a string in the database
    "unknown",
    "pending",
    "busy",
    "finished",
    "error",
    "deleted",
}

local status = table.swapped(statustags)

tickets.status     = status
tickets.statustags = statustags

local function checkeddb(presets,datatable)
    return sql.usedatabase(presets,datatable or presets.datatable or "tickets")
end

tickets.usedb = checkeddb

local template =[[
    CREATE TABLE IF NOT EXISTS %basename% (
        `id`        int(11)     NOT NULL AUTO_INCREMENT,
        `token`     varchar(50) NOT NULL,
        `subtoken`  INT(11)     NOT NULL,
        `created`   int(11)     NOT NULL,
        `accessed`  int(11)     NOT NULL,
        `category`  int(11)     NOT NULL,
        `status`    int(11)     NOT NULL,
        `usertoken` varchar(50) NOT NULL,
        `data`      longtext    NOT NULL,
        `comment`   longtext    NOT NULL,

        PRIMARY KEY                     (`id`),
        UNIQUE INDEX `id_unique_index`  (`id` ASC),
        KEY          `token_unique_key` (`token`)
    )
    DEFAULT CHARSET = utf8 ;
]]

function tickets.createdb(presets,datatable)

    local db = checkeddb(presets,datatable)

    local data, keys = db.execute {
        template  = template,
        variables = {
            basename = db.basename,
        },
    }

    report("datatable %q created in %q",db.name,db.base)

    return db

end

local template =[[
    DROP TABLE IF EXISTS %basename% ;
]]

function tickets.deletedb(presets,datatable)

    local db = checkeddb(presets,datatable)

    local data, keys = db.execute {
        template  = template,
        variables = {
            basename = db.basename,
        },
    }

    report("datatable %q removed in %q",db.name,db.base)

end

local template =[[
    LOCK TABLES
        %basename%
    WRITE ;
    INSERT INTO %basename% (
        `token`,
        `subtoken`,
        `created`,
        `accessed`,
        `status`,
        `category`,
        `usertoken`,
        `data`,
        `comment`
    ) VALUES (
        '%token%',
         %subtoken%,
         %time%,
         %time%,
         %status%,
         %category%,
        '%usertoken%',
        '%[data]%',
        '%[comment]%'
    ) ;
    SELECT
        LAST_INSERT_ID() AS `id` ;
    UNLOCK TABLES ;
]]

function tickets.create(db,ticket)

    local token     = ticket.token or tickets.newtoken()
    local time      = ostime()
    local status    = ticket.status or 0
    local category  = ticket.category or 0
    local subtoken  = ticket.subtoken or 0
    local usertoken = ticket.usertoken or ""
    local comment   = ticket.comment or ""

    local result, message = db.execute {
        template  = template,
        variables = {
            basename  = db.basename,
            token     = token,
            subtoken  = subtoken,
            time      = time,
            status    = status,
            category  = category,
            usertoken = usertoken,
            data      = db.serialize(ticket.data or { },"return"),
            comment   = comment,
        },
    }

    if trace_sql then
        report("created: %s at %s",token,osfulltime(time))
    end

    local r = result and result[1]

    if r then

        return {
            id        = r.id,
            token     = token,
            subtoken  = subtoken,
            created   = time,
            accessed  = time,
            status    = status,
            category  = category,
            usertoken = usertoken,
            data      = data,
            comment   = comment,
        }

    end
end

local template =[[
    LOCK TABLES
        %basename%
    WRITE ;
    UPDATE %basename% SET
        `data` = '%[data]%',
        `status` = %status%,
        `accessed` = %time%
    WHERE
        `id` = %id% ;
    UNLOCK TABLES ;
]]

function tickets.save(db,ticket)

    local time     = ostime()
    local data     = db.serialize(ticket.data or { },"return")
    local status   = ticket.status or 0
    local id       = ticket.id

    if not status then
        status = 0
        ticket.status = 0
    end

    ticket.accessed = time

    db.execute {
        template  = template,
        variables = {
            basename = db.basename,
            id       = id,
            time     = ostime(),
            status   = status,
            data     = data,
        },
    }

    if trace_sql then
        report("saved: id %s, time %s",id,osfulltime(time))
    end

    return ticket
end

local template =[[
    UPDATE
        %basename%
    SET
        `accessed` = %time%
    WHERE
        `token` = '%token%' ;

    SELECT
        *
    FROM
        %basename%
    WHERE
        `id` = %id% ;
]]

function tickets.restore(db,id)

    local record, keys = db.execute {
        template  = template,
        variables = {
            basename = db.basename,
            id       = id,
            time     = ostime(),
        },
    }

    local record = record and record[1]

    if record then
        if trace_sql then
            report("restored: id %s",id)
        end
        record.data = db.deserialize(record.data or "")
        return record
    elseif trace_sql then
        report("unknown: id %s",id)
    end

end

local template =[[
    DELETE FROM
        %basename%
    WHERE
        `id` = %id% ;
]]

function tickets.remove(db,id)

    db.execute {
        template  = template,
        variables = {
            basename = db.basename,
            id       = id,
        },
    }

    if trace_sql then
        report("removed: id %s",id)
    end

end

local template_yes =[[
    SELECT
        *
    FROM
        %basename%
    ORDER BY
        `created` ;
]]

local template_nop =[[
    SELECT
        `created`,
        `usertoken`,
        `accessed`,
        `status`
    FROM
        %basename%
    ORDER BY
        `created` ;
]]

function tickets.collect(db,nodata)

    local records, keys = db.execute {
        template  = nodata and template_nop or template_yes,
        variables = {
            basename = db.basename,
            token    = token,
        },
    }

    if not nodata then
        db.unpackdata(records)
    end

    if trace_sql then
        report("collected: %s tickets",#records)
    end

    return records, keys

end

local template =[[
    DELETE FROM
        %basename%
    WHERE
        `accessed` < %time% OR `status` = 5 ;
]]

local template_cleanup_yes =[[
    SELECT
        *
    FROM
        %basename%
    WHERE
        `accessed` < %time%
    ORDER BY
        `created` ;
    DELETE FROM
        %basename%
    WHERE
        `accessed` < %time% OR `status` = 5 ;
]]

local template_cleanup_nop =[[
    SELECT
        `accessed`,
        `created`,
        `accessed`,
        `token`
        `usertoken`
    FROM
        %basename%
    WHERE
        `accessed` < %time%
    ORDER BY
        `created` ;
    DELETE FROM
        %basename%
    WHERE
        `accessed` < %time% OR `status` = 5 ;
]]

function tickets.cleanupdb(db,delta,nodata) -- maybe delta in db

    local time = delta and (ostime() - delta) or 0

    local records, keys = db.execute {
        template  = nodata and template_cleanup_nop or template_cleanup_yes,
        variables = {
            basename = db.basename,
            time     = time,
        },
    }

    if not nodata then
        db.unpackdata(records)
    end

    if trace_sql then
        report("cleaned: %s seconds before %s",delta,osfulltime(time))
    end

    return records, keys

end

-- status related functions

local template =[[
    SELECT
        `status`
    FROM
        %basename%
    WHERE
        `token` = '%token%' ;
]]

function tickets.getstatus(db,token)

    local record, keys = db.execute {
        template  = template,
        variables = {
            basename = db.basename,
            token    = token,
        },
    }

    local record = record and record[1]

    return record and record.status or 0

end

local template =[[
    SELECT
        `status`
    FROM
        %basename%
    WHERE
        `status` = 5 OR `accessed` < %time% ;
]]

function tickets.getobsolete(db,delta)

    local time = delta and (ostime() - delta) or 0

    local records = db.execute {
        template  = template,
        variables = {
            basename = db.basename,
            time     = time,
        },
    }

    db.unpackdata(records)

    return records

end

local template =[[
    SELECT
        `id`
    FROM
        %basename%
    WHERE
        `status` = %status%
    LIMIT
        1 ;
]]

function tickets.hasstatus(db,status)

    local record = db.execute {
        template  = template,
        variables = {
            basename = db.basename,
            status   = status or 0,
        },
    }

    return record and #record > 0 or false

end

local template =[[
    UPDATE
        %basename%
    SET
        `status` = %status%,
        `accessed` = %time%
    WHERE
        `id` = %id% ;
]]

function tickets.setstatus(db,id,status)

    local record, keys = db.execute {
        template  = template,
        variables = {
            basename = db.basename,
            id       = id,
            time     = ostime(),
            status   = status or 0,
        },
    }

end

local template =[[
    DELETE FROM
        %basename%
    WHERE
        `status` IN (%status%) ;
]]

function tickets.prunedb(db,status)

    if type(status) == "table" then
        status = concat(status,",")
    end

    local data, keys = db.execute {
        template  = template,
        variables = {
            basename = db.basename,
            status   = status or 0,
        },
    }

    if trace_sql then
        report("pruned: status %s removed",status)
    end

end

local template_a = [[
    LOCK TABLES
        %basename%
    WRITE ;
    SET
        @first_token = "?" ;
    SELECT
        `token`
    INTO
        @first_token
    FROM
        %basename%
    WHERE
        `status` = %status%
    ORDER BY
        `id`
    LIMIT 1 ;
    UPDATE
        %basename%
    SET
        `status` = %newstatus%,
        `accessed` = %time%
    WHERE
        `token` = @first_token ;
    SELECT
        *
    FROM
        %basename%
    WHERE
        `token` = @first_token
    ORDER BY
        `id` ;
    UNLOCK TABLES ;
]]

local template_b = [[
    SET
        @first_token = "?" ;
    SELECT
        `token`
    INTO
        @first_token
    FROM
        %basename%
    WHERE
        `status` = %status%
    ORDER BY
        `id`
    LIMIT 1 ;
    SELECT
        *
    FROM
        %basename%
    WHERE
        `token` = @first_token
    ORDER BY
        `id` ;
]]

function tickets.getfirstwithstatus(db,status,newstatus)

    local records

    if type(newstatus) == "number" then

        records = db.execute {
            template  = template_a,
            variables = {
                basename  = db.basename,
                status    = status or 0,
                newstatus = newstatus,
                time      = ostime(),
            },
        }


    else

        records = db.execute {
            template  = template_b,
            variables = {
                basename = db.basename,
                status   = status or 0,
            },
        }

    end

    if type(records) == "table" and #records > 0 then

        for i=1,#records do
            local record = records[i]
            record.data = db.deserialize(record.data or "")
            record.status = newstatus
        end

        return records

    end
end

local template =[[
    SELECT
        *
    FROM
        %basename%
    WHERE
        `usertoken` = '%usertoken%' AND `status` != 5
    ORDER BY
        `created` ;
]]

function tickets.getusertickets(db,usertoken)

    -- todo: update accessed
    -- todo: get less fields
    -- maybe only data for status changed (hard to check)

    local records, keys = db.execute {
        template  = template,
        variables = {
            basename  = db.basename,
            usertoken = usertoken,
        },
    }

    db.unpackdata(records)

    return records

end

local template =[[
    LOCK TABLES
        %basename%
    WRITE ;
    UPDATE %basename% SET
        `status` = 5
    WHERE
        `usertoken` = '%usertoken%' ;
    UNLOCK TABLES ;
]]

function tickets.removeusertickets(db,usertoken)

    db.execute {
        template  = template,
        variables = {
            basename  = db.basename,
            usertoken = usertoken,
        },
    }

    if trace_sql then
        report("removed: usertoken %s",usertoken)
    end

end

-- -- left-overs --

-- LOCK TABLES `m4alltickets` WRITE ;
-- CREATE TEMPORARY TABLE ticketset SELECT * FROM m4alltickets WHERE token = @first_token ;
-- DROP TABLE ticketset ;
-- UNLOCK TABLES ;

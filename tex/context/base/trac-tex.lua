if not modules then modules = { } end modules ['trac-tex'] = {
    version   = 1.001,
    comment   = "companion to trac-deb.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- moved from trac-deb.lua

local format = string.format

local texhashtokens = tex.hashtokens

local trackers = trackers

local saved = { }

function trackers.savehash()
    saved = texhashtokens()
end

function trackers.dumphashtofile(filename,delta)
    local list, hash, command_name = { }, texhashtokens(), token.command_name
    for name, token in next, hash do
        if not delta or not saved[name] then
            -- token: cmd, chr, csid -- combination cmd,chr determines name
            local category = command_name(token)
            local dk = list[category]
            if not dk then
                -- a bit funny names but this sorts better (easier to study)
                dk = { names = { }, found = 0, code = token[1] }
                list[category] = dk
            end
            dk.names[name] = { token[2], token[3] }
            dk.found = dk.found + 1
        end
    end
    io.savedata(filename or tex.jobname .. "-hash.log",table.serialize(list,true))
end

local delta = nil

local function dump_hash(wanteddelta)
    if delta == nil then
        saved = saved or texhashtokens() -- no need for trackers.dump_hash
        luatex.registerstopactions(1,function() dump_hash(nil,wanteddelta) end) -- at front
    end
    delta = wanteddelta
end

directives.register("system.dumphash",  function() dump_hash(false) end)
directives.register("system.dumpdelta", function() dump_hash(true ) end)

local report_dump = logs.reporter("resolvers","dump")

local function saveusedfilesintrees(format)
    local data = {
        jobname = environment.jobname or "?",
        version = environment.version or "?",
        files   = resolvers.instance.foundintrees
    }
    local filename = file.replacesuffix(environment.jobname or "context-job",'jlg')
    if format == "lua" then
        io.savedata(filename,table.serialize(data,true))
    else
        io.savedata(filename,table.toxml(data,"job"))
    end
end

directives.register("system.dumpfiles", function(v)
    luatex.registerstopactions(function() saveusedfilesintrees(v) end)
end)


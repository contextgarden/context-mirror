if not modules then modules = { } end modules ['trac-hsh'] = {
    version   = 1.001,
    comment   = "companion to trac-deb.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- moved from trac-deb.lua

local texhashtokens = tex.hashtokens

local trackers = trackers

local saved = { }

function trackers.save_hash()
    saved = texhashtokens()
end

function trackers.dumphashtofile(filename,delta)
    local list, hash, command_name = { }, texhashtokens(), token.command_name
    for name, token in next, hash do
        if not delta or not saved[name] then
            -- token: cmd, chr, csid -- combination cmd,chr determines name
            local kind = command_name(token)
            local dk = list[kind]
            if not dk then
                -- a bit funny names but this sorts better (easier to study)
                dk = { names = { }, found = 0, code = token[1] }
                list[kind] = dk
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

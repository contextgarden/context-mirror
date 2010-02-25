if not modules then modules = { } end modules ['trac-deb'] = {
    version   = 1.001,
    comment   = "companion to trac-deb.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

if not lmx           then lmx           = { } end
if not lmx.variables then lmx.variables = { } end

lmx.htmfile = function(name) return environment.jobname .. "-status.html" end
lmx.lmxfile = function(name) return resolvers.find_file(name,'tex') end

if not tracers         then tracers         = { } end
if not tracers.list    then tracers.list    = { } end
if not tracers.strings then tracers.strings = { } end

tracers.strings.undefined = "undefined"

local splitter = lpeg.splitat(":")
local lpegmatch = lpeg.match

function tracers.split(csname)
    return lpegmatch(splitter,csname)
end

function tracers.type(csname)
    tag, name = tracers.split(csname)
    if tag then return tag else return nil end
end

function tracers.name(csname)
    tag, name = tracers.split(csname)
    if tag then return name else return csname end
end

function tracers.cs(csname)
    tag, name = tracers.split(csname)
    if tracers.types[tag] then
        return tracers.types[tag](name)
    else
        return tracers.primitive(csname)
    end
end

function tracers.dimen(name)
    return (tex.dimen[name] and number.topoints(tex.dimen[name])) or tracers.strings.undefined
end

function tracers.count(name)
    return tex.count[name] or tracers.strings.undefined
end

function tracers.toks(name)
    return (tex.toks[name] and string.limit(tex.toks[name],40)) or tracers.strings.undefined
end

function tracers.primitive(name)
    return tex[name] or tracers.strings.undefined
end

tracers.types = {
    ['d'] = tracers.dimen,
    ['c'] = tracers.count,
    ['t'] = tracers.toks,
    ['p'] = tracers.primitive
}

function tracers.knownlist(name)
    return tracers.list[name] and #tracers.list[name] > 0
end

function tracers.showdebuginfo()
    local variables = {
        ['title']                = 'ConTeXt Debug Information',
        ['color-background-one'] = lmx.get('color-background-green'),
        ['color-background-two'] = lmx.get('color-background-blue'),
    }
    lmx.show('context-debug.lmx',variables)
end

function tracers.showerror()
    local filename = status.filename
    local linenumber = tonumber(status.linenumber or "0")
    local variables = {
        ['title']                = 'ConTeXt Error Information',
        ['errormessage']         = status.lasterrorstring,
        ['linenumber']           = status.linenumber,
        ['color-background-one'] = lmx.get('color-background-yellow'),
        ['color-background-two'] = lmx.get('color-background-purple'),
    }
    if not filename then
        variables.filename, variables.errorcontext = 'unknown', 'error in filename'
    elseif type(filename) == "number" then
        variables.filename, variables.errorcontext = "<read " .. filename .. ">", 'unknown error'
    elseif io.exists(filename) then
        -- todo: use an input opener so that we also catch utf16 an reencoding
        lines = io.lines(filename)
        if lines then
            local context = { }
            n, m = 1, linenumber
            b, e = m-10, m+10
            s = string.len(tostring(e))
            for line in lines do
                if n > e then
                    break
                elseif n > b then
                    if n == m then
                        context[#context+1] = string.format("%" .. s .. "d",n) .. " >>  " .. line
                    else
                        context[#context+1] = string.format("%" .. s .. "d",n) .. "     " .. line
                    end
                end
                n = n + 1
            end
            variables.filename, variables.errorcontext = filename, table.concat(context,"\n")
        else
            variables.filename, variables.errorcontext = filename, ""
        end
    else
        variables.filename, variables.errorcontext = filename, 'file not found'
    end
    lmx.show('context-error.lmx',variables)
end

function tracers.overloaderror()
    callback.register('show_error_hook', tracers.showerror)
end

tracers.list['scratch'] = {
    0, 2, 4, 6, 8
}

tracers.list['internals'] = {
    'p:hsize', 'p:parindent', 'p:leftskip','p:rightskip',
    'p:vsize', 'p:parskip', 'p:baselineskip', 'p:lineskip', 'p:topskip'
}

tracers.list['context'] = {
    'd:lineheight',
    'c:realpageno', 'c:pageno', 'c:subpageno'
}

-- dumping the hash

-- \starttext
--     \ctxlua{tracers.dump_hash()}
-- \stoptext

local saved = { }

function tracers.save_hash()
    saved = tex.hashtokens()
end

function tracers.dump_hash(filename,delta)
    filename = filename or tex.jobname .. "-hash.log"
    local list = { }
    local hash = tex.hashtokens()
    local command_name = token.command_name
    for name, token in pairs(hash) do
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
    io.savedata(filename,table.serialize(list,true))
end

function tracers.register_dump_hash(delta)
    if delta then
        tracers.save_hash()
    end
    main.register_stop_actions(1,function() tracers.dump_hash(nil,true) end) -- at front
end

directives.register("system.dumphash",  function() tracers.register_dump_hash(false) end)
directives.register("system.dumpdelta", function() tracers.register_dump_hash(true ) end)

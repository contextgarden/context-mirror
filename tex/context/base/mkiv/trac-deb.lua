if not modules then modules = { } end modules ['trac-deb'] = {
    version   = 1.001,
    comment   = "companion to trac-deb.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- This is an old mechanism, a result of some experiments in the early days of
-- luatex and mkiv, but still nice anyway.

local status = status

local tonumber, tostring, type = tonumber, tostring, type
local format, concat, match, find, gsub = string.format, table.concat, string.match, string.find, string.gsub

local report_nl     = logs.newline
local report_str    = logs.writer

tracers             = tracers or { }
local tracers       = tracers
local implement     = interfaces.implement

local savedluaerror = nil
local usescitelexer = nil
local quitonerror   = true

local function errorreporter(luaerror)
    local category = luaerror and "lua error" or "tex error"
    local report = logs.reporter(category)
    logs.enable(category)
    return report
end

function tracers.showlines(filename,linenumber,offset,luaerrorline)
    local data = io.loaddata(filename)
    if not data or data == "" then
        local hash = url.hashed(filename)
        if not hash.noscheme then
            local ok, d, n = resolvers.loaders.byscheme(hash.scheme,filename)
            if ok and n > 0 then
                data = d
            end
        end
    end
    local scite = usescitelexer and require("util-sci")
    if scite then
        return utilities.scite.tohtml(data,"tex",linenumber or true,false)
    else
        local lines = data and string.splitlines(data)
        if lines and #lines > 0 then
            if luaerrorline and luaerrorline > 0 then
                -- lua error: linenumber points to last line
                local start = "\\startluacode"
                local stop  = "\\stopluacode"
                local n = linenumber
                for i=n,1,-1 do
                    local line = lines[i]
                    if not line then
                        break
                    elseif find(line,start) then
                        n = i + luaerrorline - 1
                        if n <= linenumber then
                            linenumber = n
                        end
                        break
                    end
                end
            end
            offset = tonumber(offset) or 10
            linenumber = tonumber(linenumber) or 10
            local start = math.max(linenumber - offset,1)
            local stop = math.min(linenumber + offset,#lines)
            if stop > #lines then
                return "<linenumber past end of file>"
            else
                local result, fmt = { }, "%" .. #tostring(stop) .. "d %s  %s"
                for n=start,stop do
                    result[#result+1] = format(fmt,n,n == linenumber and ">>" or "  ",lines[n])
                end
                return concat(result,"\n")
            end
        else
            return "<empty file>"
        end
    end
end

-- this will work ok in >=0.79

-- todo: last tex error has ! prepended
-- todo: some nested errors have two line numbers
-- todo: collect errorcontext in string (after code cleanup)
-- todo: have a separate status.lualinenumber
-- todo: \starttext bla \blank[foo] bla \stoptext

local nop = function() end
local resetmessages = status.resetmessages or nop

local function processerror(offset,eof)
    local filename     = status.filename
    local linenumber   = tonumber(status.linenumber) or 0
    local lastcontext  = status.lasterrorcontext
    local lasttexerror = status.lasterrorstring or "?"
    local lastluaerror = status.lastluaerrorstring or "?" -- lasttexerror
    local luaerrorline = match(lastluaerror,[[lua%]?:.-(%d+)]]) or (lastluaerror and find(lastluaerror,"?:0:",1,true) and 0)
    local lastmpserror = match(lasttexerror,[[^.-mp%serror:%s*(.*)$]])
    resetmessages()
    lastluaerror = gsub(lastluaerror,"%[\\directlua%]","[ctxlua]")
    tracers.printerror {
        filename     = filename,
        linenumber   = linenumber,
        offset       = tonumber(offset) or 10,
        lasttexerror = lasttexerror,
        lastmpserror = lastmpserror,
        lastluaerror = lastluaerror, -- can be the same as lasttexerror
        luaerrorline = luaerrorline,
        lastcontext  = lastcontext,
        lasttexhelp  = tex.gethelptext and tex.gethelptext() or nil,
        endoffile    = eof,
    }
    if job and type(job.disablesave) == "function" then
        job.disablesave()
    end
end

directives.register("system.quitonerror",function(v)
    quitonerror = toboolean(v)
end)

directives.register("system.usescitelexer",function(v)
    usescitelexer = toboolean(v)
end)

local busy = false

function tracers.printerror(specification)
    if not busy then
        busy = true
        local filename     = specification.filename
        local linenumber   = specification.linenumber
        local lasttexerror = specification.lasttexerror
        local lastmpserror = specification.lastmpserror
        local lastluaerror = specification.lastluaerror
        local lastcontext  = specification.lasterrorcontext
        local luaerrorline = specification.luaerrorline
        local errortype    = specification.errortype
        local offset       = specification.offset
        local endoffile    = specification.endoffile
        local report       = errorreporter(luaerrorline)
        if endoffile then
            report("runaway error: %s",lasttexerror or "-")
            if not quitonerror and texio.terminal then
                texio.terminal() -- not well tested
            end
        elseif not filename then
            report("fuzzy error:")
            report("  tex: %s",lasttexerror or "-")
            report("  lua: %s",lastluaerror or "-")
            report("  mps: %s",lastmpserror or "-")
        elseif type(filename) == "number" then
            report("error on line %s of filehandle %s: %s ...",linenumber,lasttexerror)
        else
            report_nl()
            if luaerrorline then
                if linenumber == 0 or not filename or filename == "" then
                    print("\nfatal lua error:\n\n",lastluaerror,"\n")
                    luatex.abort()
                    return
                else
                    report("lua error on line %s in file %s:\n\n%s",linenumber,filename,lastluaerror)
                end
            elseif lastmpserror then
                report("mp error on line %s in file %s:\n\n%s",linenumber,filename,lastmpserror)
            else
                report("tex error on line %s in file %s: %s",linenumber,filename,lasttexerror)
                if lastcontext then
                    report_nl()
                    report_str(lastcontext)
                    report_nl()
                elseif tex.show_context then
                    report_nl()
                    tex.show_context()
                end
                if lastluaerror and not match(lastluaerror,"^%s*[%?]*%s*$") then
                    print("\nlua error:\n\n",lastluaerror,"\n")
                    quitonerror = true
                end
            end
            report_nl()
            report_str(tracers.showlines(filename,linenumber,offset,tonumber(luaerrorline)))
            report_nl()
        end
        local errname = file.addsuffix(tex.jobname .. "-error","log")
        if quitonerror then
            table.save(errname,specification)
            local help = specification.lasttexhelp
            if help and #help > 0 then
                report_nl()
                report_str(help)
                report_nl()
                report_nl()
            end
            luatex.abort()
        end
        busy = false
    end
end

luatex.wrapup(function() os.remove(file.addsuffix(tex.jobname .. "-error","log")) end)

local function processwarning(offset)
    local lastwarning  = status.lastwarningstring or "?"
    local lastlocation = status.lastwarningtag or "?"
    resetmessages()
    tracers.printwarning {
        lastwarning  = lastwarning ,
        lastlocation = lastlocation,
    }
end

function tracers.printwarning(specification)
    logs.report("luatex warning","%s: %s",specification.lastlocation,specification.lastwarning)
end

directives.register("system.errorcontext", function(v)
    local register = callback.register
    if v then
        register('show_error_message',  nop)
        register('show_warning_message',function()         processwarning(v)   end)
        register('show_error_hook',     function(eof)      processerror(v,eof) end)
        register('show_lua_error_hook', function()         processerror(v)     end)
    else
        register('show_error_message',  nil)
        register('show_error_hook',     nil)
        register('show_warning_message',nil)
        register('show_lua_error_hook', nil)
    end
end)

-- this might move

lmx = lmx or { }

lmx.htmfile = function(name) return environment.jobname .. "-status.html" end
lmx.lmxfile = function(name) return resolvers.findfile(name,'tex') end

local function reportback(lmxname,default,variables)
    if lmxname == false then
        return variables
    else
        local name = lmx.show(type(lmxname) == "string" and lmxname or default,variables)
        if name then
            logs.report("context report","file: %s",name)
        end
    end
end

local function showerror(lmxname)
    local filename, linenumber, errorcontext = status.filename, tonumber(status.linenumber) or 0, ""
    if not filename then
        filename, errorcontext = 'unknown', 'error in filename'
    elseif type(filename) == "number" then
        filename, errorcontext = format("<read %s>",filename), 'unknown error'
    else
        errorcontext = tracers.showlines(filename,linenumber,offset)
    end
    local variables = {
        ['title']                = 'ConTeXt Error Information',
        ['errormessage']         = status.lasterrorstring,
        ['linenumber']           = linenumber,
        ['color-background-one'] = lmx.get('color-background-yellow'),
        ['color-background-two'] = lmx.get('color-background-purple'),
        ['filename']             = filename,
        ['errorcontext']         = errorcontext,
    }
    reportback(lmxname,"context-error.lmx",variables)
    luatex.abort()
end

lmx.showerror = showerror

function lmx.overloaderror(v)
    if v == "scite" then
        usescitelexer = true
    end
    callback.register('show_error_hook',     function() showerror() end) -- prevents arguments being passed
    callback.register('show_lua_error_hook', function() showerror() end) -- prevents arguments being passed
    callback.register('show_tex_error_hook', function() showerror() end) -- prevents arguments being passed
end

directives.register("system.showerror", lmx.overloaderror)

-- local debugger = utilities.debugger
--
-- local function trace_calls(n)
--     debugger.enable()
--     luatex.registerstopactions(function()
--         debugger.disable()
--         debugger.savestats(tex.jobname .. "-luacalls.log",tonumber(n))
--     end)
--     trace_calls = function() end
-- end
--
-- directives.register("system.tracecalls", function(n)
--     trace_calls(n)
-- end) -- indirect is needed for nilling

-- Obsolete ... not that usefull as normally one runs from an editor and
-- when run unattended it makes no sense either.

-- local editor = [[scite "-open:%filename%" -goto:%linenumber%]]
--
-- directives.register("system.editor",function(v)
--     editor = v
-- end)
--
-- callback.register("call_edit",function(filename,linenumber)
--     if editor then
--         editor = gsub(editor,"%%s",filename)
--         editor = gsub(editor,"%%d",linenumber)
--         editor = gsub(editor,"%%filename%%",filename)
--         editor = gsub(editor,"%%linenumber%%",linenumber)
--         logs.report("system","starting editor: %s",editor)
--         os.execute(editor)
--     end
-- end)

implement { name = "showtrackers",       actions = trackers.show }
implement { name = "enabletrackers",     actions = trackers.enable,     arguments = "string" }
implement { name = "disabletrackers",    actions = trackers.disable,    arguments = "string" }
implement { name = "resettrackers",      actions = trackers.reset }

implement { name = "showdirectives",     actions = directives.show }
implement { name = "enabledirectives",   actions = directives.enable,   arguments = "string" }
implement { name = "disabledirectives",  actions = directives.disable,  arguments = "string" }

implement { name = "showexperiments",    actions = experiments.show }
implement { name = "enableexperiments",  actions = experiments.enable,  arguments = "string" }
implement { name = "disableexperiments", actions = experiments.disable, arguments = "string" }

implement { name = "overloaderror",      actions = lmx.overloaderror }
implement { name = "showlogcategories",  actions = logs.show }

local debugger = utilities.debugger

directives.register("system.profile",function(n)
    luatex.registerstopactions(function()
        debugger.disable()
        debugger.savestats("luatex-profile.log",tonumber(n) or 0)
        report_nl()
        logs.report("system","profiler stopped, log saved in %a","luatex-profile.log")
        report_nl()
    end)
    logs.report("system","profiler started")
    debugger.enable()
end)

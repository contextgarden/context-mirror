if not modules then modules = { } end modules ['trac-deb'] = {
    version   = 1.001,
    comment   = "companion to trac-deb.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local lpeg, status = lpeg, status

local lpegmatch = lpeg.match
local format, concat, match, find, gsub = string.format, table.concat, string.match, string.find, string.gsub
local tonumber, tostring = tonumber, tostring

-- maybe tracers -> tracers.tex (and tracers.lua for current debugger)

----- report_tex  = logs.reporter("tex error")
----- report_lua  = logs.reporter("lua error")
local report_nl   = logs.newline
local report_str  = logs.writer

tracers           = tracers or { }
local tracers     = tracers

tracers.lists     = { }
local lists       = tracers.lists

tracers.strings   = { }
local strings     = tracers.strings

local texgetdimen = tex.getdimen
local texgettoks  = tex.gettoks
local texgetcount = tex.getcount

local implement   = interfaces.implement

strings.undefined = "undefined"

lists.scratch = {
    0, 2, 4, 6, 8
}

lists.internals = {
    'p:hsize', 'p:parindent', 'p:leftskip','p:rightskip',
    'p:vsize', 'p:parskip', 'p:baselineskip', 'p:lineskip', 'p:topskip'
}

lists.context = {
    'd:lineheight',
    'c:realpageno', 'c:userpageno', 'c:pageno', 'c:subpageno'
}

local types = {
    ['d'] = tracers.dimen,
    ['c'] = tracers.count,
    ['t'] = tracers.toks,
    ['p'] = tracers.primitive
}

local splitboth = lpeg.splitat(":")
local splittype = lpeg.firstofsplit(":")
local splitname = lpeg.secondofsplit(":")

function tracers.type(csname)
    return lpegmatch(splittype,csname)
end

function tracers.name(csname)
    return lpegmatch(splitname,csname) or csname
end

function tracers.cs(csname)
    local tag, name = lpegmatch(splitboth,csname)
    if name and types[tag] then
        return types[tag](name)
    else
        return tracers.primitive(csname)
    end
end

function tracers.dimen(name)
    local d = texgetdimen(name)
    return d and number.topoints(d) or strings.undefined
end

function tracers.count(name)
    return texgetcount(name) or strings.undefined
end

function tracers.toks(name,limit)
    local t = texgettoks(name)
    return t and string.limit(t,tonumber(limit) or 40) or strings.undefined
end

function tracers.primitive(name)
    return tex[name] or strings.undefined
end

function tracers.knownlist(name)
    local l = lists[name]
    return l and #l > 0
end

local savedluaerror = nil

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

-- this will work ok in >=0.79

-- todo: last tex error has ! prepended
-- todo: some nested errors have two line numbers
-- todo: collect errorcontext in string (after code cleanup)
-- todo: have a separate status.lualinenumber

-- todo: \starttext bla \blank[foo] bla \stoptext

local nop = function() end
local resetmessages = status.resetmessages() or nop

local function processerror(offset)
 -- print("[[ last tex error: " .. tostring(status.lasterrorstring     or "<unset>") .. " ]]")
 -- print("[[ last lua error: " .. tostring(status.lastluaerrorstring  or "<unset>") .. " ]]")
 -- print("[[ last warning  : " .. tostring(status.lastwarningstring   or "<unset>") .. " ]]")
 -- print("[[ last location : " .. tostring(status.lastwarninglocation or "<unset>") .. " ]]")
 -- print("[[ last context  : " .. tostring(status.lasterrorcontext    or "<unset>") .. " ]]")

    local inputstack   = resolvers.inputstack
    local filename     = inputstack[#inputstack] or status.filename
    local linenumber   = tonumber(status.linenumber) or 0
    local lastcontext  = status.lasterrorcontext
    local lasttexerror = status.lasterrorstring or "?"
    local lastluaerror = status.lastluaerrorstring or lasttexerror
    local luaerrorline = match(lastluaerror,[[lua%]?:.-(%d+)]]) or (lastluaerror and find(lastluaerror,"?:0:",1,true) and 0)
    resetmessages()
    lastluaerror = gsub(lastluaerror,"%[\\directlua%]","[ctxlua]")
    tracers.printerror {
        filename     = filename,
        linenumber   = linenumber,
        offset       = tonumber(offset) or 10,
        lasttexerror = lasttexerror,
        lastluaerror = lastluaerror,
        luaerrorline = luaerrorline,
        lastcontext  = lastcontext,
    }
end

-- so one can overload the printer if (really) needed

function tracers.printerror(specification)
    local filename     = specification.filename
    local linenumber   = specification.linenumber
    local lasttexerror = specification.lasttexerror
    local lastluaerror = specification.lastluaerror
    local lastcontext  = specification.lasterrorcontext
    local luaerrorline = specification.luaerrorline
    local offset       = specification.offset
    local report       = errorreporter(luaerrorline)
    if not filename then
        report("error not related to input file: %s ...",lasttexerror)
    elseif type(filename) == "number" then
        report("error on line %s of filehandle %s: %s ...",linenumber,lasttexerror)
    else
        report_nl()
        if luaerrorline then
            report("lua error on line %s in file %s:\n\n%s",linenumber,filename,lastluaerror)
         -- report("error on line %s in file %s:\n\n%s",linenumber,filename,lasttexerror)
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
        end
        report_nl()
        report_str(tracers.showlines(filename,linenumber,offset,tonumber(luaerrorline)))
        report_nl()
    end
end

local function processwarning(offset)
 -- local inputstack   = resolvers.inputstack
 -- local filename     = inputstack[#inputstack] or status.filename
 -- local linenumber   = tonumber(status.linenumber) or 0
    local lastwarning  = status.lastwarningstring or "?"
    local lastlocation = status.lastwarningtag or "?"
    resetmessages()
    tracers.printwarning {
     -- filename     = filename,
     -- linenumber   = linenumber,
     -- offset       = tonumber(offset) or 10,
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
        register('show_warning_message',function() processwarning(v) end)
        register('show_error_hook',     function() processerror(v) end)
        register('show_lua_error_hook', nop)
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

function lmx.showdebuginfo(lmxname)
    local variables = {
        ['title']                = 'ConTeXt Debug Information',
        ['color-background-one'] = lmx.get('color-background-green'),
        ['color-background-two'] = lmx.get('color-background-blue'),
    }
    if lmxname == false then
        return variables
    else
        lmx.show(lmxname or 'context-debug.lmx',variables)
    end
end

function lmx.showerror(lmxname)
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
    if lmxname == false then
        return variables
    else
        lmx.show(lmxname or 'context-error.lmx',variables)
    end
end

function lmx.overloaderror()
    callback.register('show_error_hook', function() lmx.showerror() end) -- prevents arguments being passed
end

directives.register("system.showerror", lmx.overloaderror)

local debugger = utilities.debugger

local function trace_calls(n)
    debugger.enable()
    luatex.registerstopactions(function()
        debugger.disable()
        debugger.savestats(tex.jobname .. "-luacalls.log",tonumber(n))
    end)
    trace_calls = function() end
end

if LUATEXVERSION > 0.98 then

    local editor = [[scite "-open:%filename%" -goto:%linenumber%]]

    directives.register("system.editor",function(v)
        editor = v
    end)

    callback.register("call_edit",function(filename,linenumber)
        if editor then
            editor = gsub(editor,"%%s",filename)
            editor = gsub(editor,"%%d",linenumber)
            editor = gsub(editor,"%%filename%%",filename)
            editor = gsub(editor,"%%linenumber%%",linenumber)
            logs.report("system","starting editor: %s",editor)
            os.execute(editor)
        end
    end)

end

directives.register("system.tracecalls", function(n) trace_calls(n) end) -- indirect is needed for nilling

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

implement { name = "showdebuginfo",      actions = lmx.showdebuginfo }
implement { name = "overloaderror",      actions = lmx.overloaderror }
implement { name = "showlogcategories",  actions = logs.show }

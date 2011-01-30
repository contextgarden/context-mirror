if not modules then modules = { } end modules ['buff-ver'] = {
    version   = 1.001,
    comment   = "companion to buff-ver.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- The default visualizers have reserved names starting with v-*. Users are
-- supposed to use different names for their own variants.

local type, next, rawset, rawget, setmetatable, getmetatable = type, next, rawset, rawget, setmetatable, getmetatable
local format, lower, upper,match, find, sub = string.format, string.lower, string.upper, string.match, string.find, string.sub
local splitlines = string.splitlines
local concat = table.concat
local C, P, R, V, Carg, Cc, Cs = lpeg.C, lpeg.P, lpeg.R, lpeg.V, lpeg.Carg, lpeg.Cc, lpeg.Cs
local patterns, lpegmatch, is_lpeg = lpeg.patterns, lpeg.match, lpeg.is_lpeg

local tabtospace = utilities.strings.tabtospace
local variables = interfaces.variables
local settings_to_array = utilities.parsers.settings_to_array

local trace_visualize = false  trackers.register("buffers.visualize", function(v) trace_visualize = v end)

local report_buffers = logs.new("buffers")

visualizers = visualizers or { }

local specifications = { }  visualizers.specifications = specifications

local verbatim = context.verbatim
local variables = interfaces.variables
local findfile = resolvers.findfile
local addsuffix = file.addsuffix

local v_auto = variables.auto
local v_yes  = variables.yes

-- beware, these all get an argument (like newline)

local doinlineverbatimnewline    = context.doinlineverbatimnewline
local doinlineverbatimbeginline  = context.doinlineverbatimbeginline
local doinlineverbatimemptyline  = context.doinlineverbatimemptyline
local doinlineverbatimstart      = context.doinlineverbatimstart
local doinlineverbatimstop       = context.doinlineverbatimstop

local dodisplayverbatimnewline   = context.dodisplayverbatimnewline
local dodisplayverbatimbeginline = context.dodisplayverbatimbeginline
local dodisplayverbatimemptyline = context.dodisplayverbatimemptyline
local dodisplayverbatimstart     = context.dodisplayverbatimstart
local dodisplayverbatimstop      = context.dodisplayverbatimstop

local doverbatimspace            = context.doverbatimspace

local CargOne = Carg(1)

local function f_emptyline(s,settings)
    if settings and settings.nature == "inline" then
        doinlineverbatimemptyline()
    else
        dodisplayverbatimemptyline()
    end
end

local function f_beginline(s,settings)
    if settings and settings.nature == "inline" then
        doinlineverbatimbeginline()
    else
        dodisplayverbatimbeginline()
    end
end

local function f_newline(s,settings)
    if settings and settings.nature == "inline" then
        doinlineverbatimnewline()
    else
        dodisplayverbatimnewline()
    end
end

local function f_start(s,settings)
    if settings and settings.nature == "inline" then
        doinlineverbatimstart()
    else
        dodisplayverbatimstart()
    end
end

local function f_stop(s,settings)
    if settings and settings.nature == "inline" then
        doinlineverbatimstop()
    else
        dodisplayverbatimstop()
    end
end

local function f_default(s) -- (s,settings)
    verbatim(s)
end

local function f_space() -- (s,settings)
    doverbatimspace()
end

local function f_signal() -- (s,settings)
    -- we use these for special purposes
end

local signal = "\000"

visualizers.signal        = signal
visualizers.signalpattern = P(signal)

local functions = { __index = {
        emptyline = f_emptyline,
        newline   = f_newline,
        default   = f_default,
        beginline = f_beginline,
        space     = f_space,
        start     = f_start,
        stop      = f_stop,
        signal    = f_signal,
    }
}

local handlers = { }

function visualizers.newhandler(name,data)
    local tname, tdata = type(name), type(data)
    if tname == "table" then -- (data)
        setmetatable(name,getmetatable(name) or functions)
        return name
    elseif tname == "string" then
        if tdata == "string" then -- ("name","parent")
            local result = { }
            setmetatable(result,getmetatable(handlers[data]) or functions)
            handlers[name] = result
            return result
        elseif tdata == "table" then -- ("name",data)
            setmetatable(data,getmetatable(data) or functions)
            handlers[name] = data
            return data
        else -- ("name")
            local result = { }
            setmetatable(result,functions)
            handlers[name] = result
            return result
        end
    else -- ()
        local result = { }
        setmetatable(result,functions)
        return result
    end
end

function visualizers.newgrammar(name,t)
    name = lower(name)
    t = t or { }
    local g = visualizers.specifications[name]
    g = g and g.grammar
    if g then
        if trace_visualize then
            report_buffers("cloning grammar '%s'",name)
        end
        for k,v in next, g do
            if not t[k] then
                t[k] = v
            end
            if is_lpeg(v) then
                t[name..":"..k] = v
            end
        end
    end
    return t
end

local function getvisualizer(method,nature)
    method = lower(method)
    local m = specifications[method] or specifications.default
    if nature then
        if trace_visualize then
            report_buffers("getting visualizer '%s' with nature '%s'",method,nature)
        end
        return m and (m[nature] or m.parser) or nil
    else
        if trace_visualize then
            report_buffers("getting visualizer '%s'",method)
        end
        return m and m.parser or nil
    end
end

local fallback = context.verbatim

local function makepattern(visualizer,kind,pattern)
    if not pattern then
        logs.simple("error in visualizer: %s",kind)
        return patterns.alwaystrue
    else
        if type(visualizer) == "table" and type(kind) == "string" then
            kind = visualizer[kind] or fallback
        else
            kind = fallback
        end
        return (C(pattern) * CargOne) / kind
    end
end

local function makenested(handler,how,start,stop)
    local b, e, f = P(start), P(stop), how
    if type(how) == "string" then
        f = function(s) getvisualizer(how,"direct")(s) end
    end
    return makepattern(handler,"name",b)
         * ((1-e)^1/f)
         * makepattern(handler,"name",e)
end

visualizers.pattern     = makepattern
visualizers.makepattern = makepattern
visualizers.makenested  = makenested

function visualizers.load(name)
    name = lower(name)
    if rawget(specifications,name) == nil then
        name = lower(name)
        local texname = findfile(format("v-%s.mkiv",name))
        local luaname = findfile(format("v-%s.lua" ,name))
        if texname == "" or luaname == "" then
            -- assume a user specific file
            luaname = findfile(addsuffix(name,"mkiv"))
            texname = findfile(addsuffix(name,"lua" ))
        end
        if texname == "" or luaname == "" then
            if trace_visualize then
                report_buffers("unknown visualizer '%s'",name)
            end
        else
            if trace_visualize then
                report_buffers("loading visualizer '%s'",name)
            end
            lua.registercode(luaname)
            context.input(texname)
        end
        if rawget(specifications,name) == nil then
            rawset(specifications,name,false)
        end
    end
end

function commands.doifelsevisualizer(name)
    commands.testcase(specifications[lower(name)])
end

function visualizers.register(name,specification)
    name = lower(name)
    if trace_visualize then
        report_buffers("registering visualizer '%s'",name)
    end
    specifications[name] = specification
    local parser, handler = specification.parser, specification.handler
    local displayparser = specification.display or parser
    local inlineparser = specification.inline or parser
    local isparser = is_lpeg(parser)
    local start, stop
    if isparser then
        start = makepattern(handler,"start",patterns.alwaysmatched)
        stop = makepattern(handler,"stop",patterns.alwaysmatched)
    end
    if handler then
        if isparser then
            specification.display = function(content,settings)
                if handler.startdisplay then handler.startdisplay(settings) end
                lpegmatch(start * displayparser * stop,content,1,settings)
                if handler.stopdisplay then handler.stopdisplay(settings) end
            end
            specification.inline = function(content,settings)
                if handler.startinline then handler.startinline(settings) end
                lpegmatch(start * inlineparser * stop,content,1,settings)
                if handler.stopinline then handler.stopinline(settings) end
            end
            specification.direct = function(content,settings)
                lpegmatch(parser,content,1,settings)
            end
        elseif parser then
            specification.display = function(content,settings)
                if handler.startdisplay then handler.startdisplay(settings) end
                parser(content,settings)
                if handler.stopdisplay then handler.stopdisplay(settings) end
            end
            specification.inline  = function(content,settings)
                if handler.startinline then handler.startinline(settings) end
                parser(content,settings)
                if handler.stopinline then handler.stopinline(settings) end
            end
            specification.direct = parser
        end
    elseif isparser then
        specification.display = function(content,settings)
            lpegmatch(start * displayparser * stop,content,1,settings)
        end
        specification.inline  = function(content,settings)
            lpegmatch(start * inlineparser * stop,content,1,settings)
        end
        specification.direct = function(content,settings)
            lpegmatch(parser,content,1,settings)
        end
    elseif parser then
        specification.display = parser
        specification.inline  = parser
        specification.direct  = parser
    end
    return specification
end

local escapepatterns = { } visualizers.escapepatterns = escapepatterns

local function texmethod(s)
    context.bgroup()
    context(s)
    context.egroup()
end

local function texcommand(s)
    context[s]()
end

local function defaultmethod(s,settings)
    lpegmatch(getvisualizer("default"),lower(s),1,settings)
end

-- we can consider using a nested instead

local space_pattern = patterns.space^0
local name_pattern  = R("az","AZ")^1

local function hack(pattern)
    return Cs(pattern * Cc(signal)) -- hack to retain newlines
end

function visualizers.registerescapepattern(name,before,after,normalmethod,escapemethod)
    local escapepattern = escapepatterns[name]
    if not escapepattern then
        if trace_visualize then
            report_buffers("registering escape pattern, name: '%s', before: '%s', after: '%s'",name,before,after)
        end
        before, after = P(before) * space_pattern, space_pattern * P(after)
        escapepattern = (
            (before / "")
          * ((1 - after)^0 / (escapemethod or texmethod))
          * (after / "")
       -- + hack((1 - before)^1) / (normalmethod or defaultmethod)
          + ((1 - before)^1) / (normalmethod or defaultmethod)
        )^0
        escapepatterns[name] = escapepattern
    end
    return escapepattern
end

function visualizers.registerescapecommand(name,token,normalmethod,escapecommand)
    local escapepattern = escapepatterns[name]
    if not escapepattern then
        if trace_visualize then
            report_buffers("registering escape token, name: '%s', token: '%s'",name,token)
        end
        token = P(token)
        local notoken = hack((1 - token)^1)
        local cstoken = name_pattern * space_pattern
        escapepattern = (
            (token / "")
          * (cstoken / (escapecommand or texcommand))
          + (notoken / (normalmethod or defaultmethod))
        )^0
        escapepatterns[name] = escapepattern
    end
    return escapepattern
end

local escapedvisualizers = { }

local function visualize(content,settings) -- maybe also method in settings
    if content and content ~= "" then
        local method = lower(settings.method or "default")
        local m
        local e = settings.escape
        if e and e ~= "" then
            local newname = format("%s-%s",e,method)
            local newspec = specifications[newname]
            if newspec then
                m = newspec
            else
                local start, stop
                if e == v_yes then
                    start, stop = "/BTEX", "/ETEX"
                else
                    start, stop = match(e,"^(.-),(.-)$") -- todo: lpeg
                end
                local oldvisualizer = specifications[method] or specifications.default
                local oldparser = oldvisualizer.direct
                local newparser
                if start and stop then
                    newparser = visualizers.registerescapepattern(newname,start,stop,oldparser)
                else -- for old times sake: /em
                    newparser = visualizers.registerescapecommand(newname,e,oldparser)
                end
                m = visualizers.register(newname, {
                    parser  = newparser,
                    handler = oldvisualizer.handler,
                })
            end
        else
            m = specifications[method] or specifications.default
        end
        local nature = settings.nature or "display"
        local n = m and m[nature]
        if n then
            if trace_visualize then
                report_buffers("visualize using method '%s' and nature '%s'",method,nature)
            end
            n(content,settings)
        else
            if trace_visualize then
                report_buffers("visualize using method '%s'",method)
            end
            fallback(content,1,settings)
        end
    end
end

visualizers.visualize     = visualize
visualizers.getvisualizer = getvisualizer

local function checkedsettings(settings,nature)
    if not settings then
        return { nature = nature }
    else
        if not settings.nature then
            settings.nature = nature
        end
        return settings
    end
end

function visualizers.visualizestring(content,settings)
    visualize(content,checkedsettings(settings,"inline"))
end

function visualizers.visualizefile(name,settings)
    visualize(resolvers.loadtexfile(name),checkedsettings(settings,"display"))
end

function visualizers.visualizebuffer(name,settings)
    visualize(buffers.getcontent(name),checkedsettings(settings,"display"))
end

-- --

local space     = C(patterns.space)       * CargOne / f_space
local newline   = C(patterns.newline)     * CargOne / f_newline
local emptyline = C(patterns.emptyline)   * CargOne / f_emptyline
local beginline = C(patterns.beginline)   * CargOne / f_beginline
local anything  = C(patterns.somecontent) * CargOne / f_default

----- verbosed  = (space + newline * (emptyline^0) * beginline + anything)^0
local verbosed  = (space + newline * (emptyline^0) * beginline + emptyline + newline + anything)^0

local function write(s,settings) -- bad name
    lpegmatch(verbosed,s,1,settings or false)
end

visualizers.write          = write
visualizers.writenewline   = f_newline
visualizers.writeemptyline = f_emptyline
visualizers.writespace     = f_space
visualizers.writedefault   = f_default

function visualizers.writeargument(...)
    context("{")  -- If we didn't have tracing then we could
    write(...)    -- use a faster print to tex variant for the
    context("}")  -- { } tokens as they always have ctxcatcodes.
end

-- helpers

local function realign(lines,forced_n) -- no, auto, <number>
    forced_n = (forced_n == v_auto and huge) or tonumber(forced_n)
    if forced_n then
        local n = 0
        for i=1, #lines do
            local spaces = find(lines[i],"%S")
            if not spaces then
                -- empty line
            elseif not n then
                n = spaces
            elseif spaces == 0 then
                n = 0
                break
            elseif n > spaces then
                n = spaces
            end
        end
        if n > 0 then
            if n > forced_n then
                n = forced_n
            end
            for i=1,#d do
                lines[i] = sub(lines[i],n)
            end
        end
    end
    return lines
end

local function getstrip(lines,first,last)
    local first, last = first or 1, last or #lines
    for i=first,last do
        local li = lines[i]
        if #li == 0 or find(li,"^%s*$") then
            first = first + 1
        else
            break
        end
    end
    for i=last,first,-1 do
        local li = lines[i]
        if #li == 0 or find(li,"^%s*$") then
            last = last - 1
        else
            break
        end
    end
    return first, last, last - first + 1
end

local function getrange(lines,first,last,range) -- 1,3 1,+3 fromhere,tothere
    local noflines = #lines
    local first, last = first or 1, last or noflines
    if last < 0 then
        last = noflines + last
    end
    local what = settings_to_array(range)
    local r_first, r_last = what[1], what[2]
    local f, l = tonumber(r_first), tonumber(r_last)
    if r_first then
        if f then
            if f > first then
                first = f
            end
        else
            for i=first,last do
                if find(lines[i],r_first) then
                    first = i + 1
                    break
                end
            end
        end
    end
    if r_last then
        if l then
            if l < 0 then
                l = noflines + l
            end
            if find(r_last,"^[%+]") then -- 1,+3
                l = first + l
            end
            if l < last then
                last = l
            end
        else
            for i=first,last do
                if find(lines[i],r_last) then
                    last = i - 1
                    break
                end
            end
        end
    end
    return first, last
end

local tablength = 7

local function dotabs(content,settings)
    local tab = settings.tab
    tab = tab and (tab == v_yes and tablength or tonumber(tab))
    if tab then
        return tabtospace(content,tab)
    else
        return content
    end
end

local function filter(lines,settings) -- todo: inline or display in settings
    local strip = settings.strip
    if strip == v_yes then
        lines = realign(lines,strip)
    end
    local line, n = 0, 0
    local first, last, m = getstrip(lines)
    if range then
        first, last = getrange(lines,first,last,range)
        first, last = getstrip(lines,first,last)
    end
    local content = concat(lines,(settings.nature == "inline" and " ") or "\r",first,last) -- was \n
    return content, m
end

-- main functions

local getlines = buffers.getlines

function commands.typebuffer(settings)
    local lines = getlines(settings.name)
    if lines then
        local content, m = filter(lines,settings)
        if content and content ~= "" then
            content = dotabs(content,settings)
            visualize(content,checkedsettings(settings,"display"))
        end
    end
end

function commands.processbuffer(settings)
    local lines = getlines(settings.name)
    if lines then
        local content, m = filter(lines,settings)
        if content and content ~= "" then
            content = dotabs(content,settings)
            visualize(content,checkedsettings(settings,"direct"))
        end
    end
end

-- not really buffers but it's closely related

function commands.typestring(settings)
    local content = settings.data
    if content and content ~= "" then
     -- content = dotabs(content,settings)
        visualize(content,checkedsettings(settings,"inline"))
    end
end

function commands.typefile(settings)
    local filename = settings.name
    local foundname = resolvers.findtexfile(filename)
    if foundname and foundname ~= "" then
        local str = resolvers.loadtexfile(foundname)
        if str and str ~= "" then
            local regime = settings.regime
            if regime and regime ~= "" then
                regimes.load(regime)
                str = regimes.translate(str,regime)
            end
            if str and str~= "" then
                local lines = splitlines(str)
                local content, m = filter(lines,settings)
                if content and content ~= "" then
                    content = dotabs(content,settings)
                    visualize(content,checkedsettings(settings,"display"))
                end
            end
        end
    end
end

if not modules then modules = { } end modules ['buff-ver'] = {
    version   = 1.001,
    comment   = "companion to buff-ver.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- The default visualizers have reserved names starting with v-*. Users are
-- supposed to use different names for their own variants.

local type, rawset, rawget, setmetatable, getmetatable = type, rawset, rawget, setmetatable, getmetatable
local format, lower, match = string.format, string.lower, string.match
local C, P, V, Carg = lpeg.C, lpeg.P, lpeg.V, lpeg.Carg
local patterns, lpegmatch, lpegtype = lpeg.patterns, lpeg.match, lpeg.type

local function is_lpeg(p)
    return p and lpegtype(p) == "pattern"
end

visualizers = visualizers or { }

local specifications = { }  visualizers.specifications = specifications

local verbatim = context.verbatim
local variables = interfaces.variables
local findfile = resolvers.findfile
local addsuffix = file.addsuffix

local v_yes = variables.yes

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
    if settings and settings.currentnature == "inline" then
        doinlineverbatimemptyline()
    else
        dodisplayverbatimemptyline()
    end
end

local function f_beginline(s,settings)
    if settings and settings.currentnature == "inline" then
        doinlineverbatimbeginline()
    else
        dodisplayverbatimbeginline()
    end
end

local function f_newline(s,settings)
    if settings and settings.currentnature == "inline" then
        doinlineverbatimnewline()
    else
        dodisplayverbatimnewline()
    end
end

local function f_start(s,settings)
    if settings and settings.currentnature == "inline" then
        doinlineverbatimstart()
    else
        dodisplayverbatimstart()
    end
end

local function f_stop(s,settings)
    if settings and settings.currentnature == "inline" then
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

local functions = { __index = {
        emptyline = f_emptyline,
        newline   = f_newline,
        default   = f_default,
        beginline = f_beginline,
        space     = f_space,
        start     = f_start,
        stop      = f_stop,
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
    t = t or { }
    local g = visualizers.specifications[name]
    g = g and g.grammar
    if g then
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

visualizers.pattern = makepattern
visualizers.makepattern = makepattern

function visualizers.load(name)
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
            -- error message
        else
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

local function getvisualizer(method,nature)
    local m = specifications[method] or specifications.default
    if nature then
        return m and (m[nature] or m.parser) or nil
    else
        return m and m.parser or nil
    end
end

local escapepatterns = { } visualizers.escapepatterns = escapepatterns

local function texmethod(s)
    context.bgroup()
    context(s)
    context.egroup()
end

local function defaultmethod(s,settings)
    lpegmatch(getvisualizer("default"),s,1,settings)
end

function visualizers.registerescapepattern(name,before,after,normalmethod,escapemethod)
    local escapepattern = escapepatterns[name]
    if not escapepattern then
        before, after = P(before) * patterns.space^0, patterns.space^0 * P(after)
        escapepattern = (
            (before / "")
          * ((1 - after)^0 / (escapemethod or texmethod))
          * (after / "")
          + ((1 - before)^1) / (normalmethod or defaultmethod)
        )^0
        escapepatterns[name] = escapepattern
    end
    return escapepattern
end

local escapedvisualizers = { }

local function visualize(method,nature,content,settings) -- maybe also method and nature in settings
    if content and content ~= "" then
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
                    start,stop = match(e,"^(.-),(.-)$") -- todo: lpeg
                end
                if start and stop then
                    local oldvisualizer = specifications[method] or specifications.default
                    local oldparser = oldvisualizer.direct
                    local newparser = visualizers.registerescapepattern(newname,start,stop,oldparser)
                    m = visualizers.register(newname, {
                        parser  = newparser,
                        handler = oldvisualizer.handler,
                    })
                else
                 -- visualizers.register(newname,n)
                    specifications[newname] = m -- old spec so that we have one lookup only
                end
            end
        else
            m = specifications[method] or specifications.default
        end
        local n = m and m[nature]
        settings.currentnature = nature or settings.nature or "display" -- tricky ... why sometimes no nature
        if n then
            n(content,settings)
        else
            fallback(content,1,settings)
        end
    end
end

visualizers.visualize     = visualize
visualizers.getvisualizer = getvisualizer

function visualizers.visualizestring(method,content,settings)
    visualize(method,"inline",content)
end

function visualizers.visualizefile(method,name,settings)
    visualize(method,"display",resolvers.loadtexfile(name),settings)
end

function visualizers.visualizebuffer(method,name,settings)
    visualize(method,"display",buffers.content(name),settings)
end

-- --

local space     = C(patterns.space)         * CargOne / f_space
local newline   = C(patterns.newline)       * CargOne / f_newline
local emptyline = C(patterns.emptyline)     * CargOne / f_emptyline
local beginline = C(patterns.beginline)     * CargOne / f_beginline
local anything  = C(patterns.somecontent^1) * CargOne / f_default

local verbosed  = (space + newline * (emptyline^0) * beginline + anything)^0

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

if not modules then modules = { } end modules ['mult-cld'] = {
    version   = 1.001,
    comment   = "companion to mult-cld.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- This is an experiment: generating context code at the lua end. After all
-- it is surprisingly simple to implement due to metatables. I was wondering
-- if there was a more natural way to deal with commands at the lua end.
-- Of course it's a bit slower but often more readable when mixed with lua
-- code. It can also be handy when generating documents from databases or
-- when constructing large tables or so.
--
-- Todo: optional checking against interface
-- Todo: coroutine trickery
-- Todo: maybe use txtcatcodes

-- tflush needs checking ... sort of weird that it's not a table

context       = context or { }
local context = context

local format, concat = string.format, table.concat
local next, type, tostring, setmetatable = next, type, tostring, setmetatable
local insert, remove = table.insert, table.remove

local tex = tex

local texsprint    = tex.sprint
local textprint    = tex.tprint
local texprint     = tex.print
local texiowrite   = texio.write
local texcount     = tex.count

local isnode       = node.is_node
local writenode    = node.write

local ctxcatcodes  = tex.ctxcatcodes
local prtcatcodes  = tex.prtcatcodes
local texcatcodes  = tex.texcatcodes
local txtcatcodes  = tex.txtcatcodes
local vrbcatcodes  = tex.vrbcatcodes
local xmlcatcodes  = tex.xmlcatcodes

local flush         = texsprint

local trace_context = logs.new("context") -- here
local report_cld    = logs.new("cld")

local _stack_, _n_ = { }, 0

local function _store_(ti)
    _n_ = _n_ + 1
    _stack_[_n_] = ti
    return _n_
end

local function _flush_(n)
    local sn = _stack_[n]
    if not sn then
        report_cld("data with id %s cannot be found on stack",n)
    elseif not sn() and texcount["@@trialtypesetting"] == 0 then  -- @@trialtypesetting is private!
        _stack_[n] = nil
    else
        -- keep, beware, that way the stack can grow
    end
end

function context.restart()
    _stack_, _n_ = { }, 0
end

context._stack_ = _stack_
context._store_ = _store_
context._flush_ = _flush_

-- Should we keep the catcodes with the function?

local catcodestack    = { }
local currentcatcodes = ctxcatcodes

local catcodes = {
    ctx = ctxcatcodes, ctxcatcodes = ctxcatcodes, context  = ctxcatcodes,
    prt = prtcatcodes, prtcatcodes = prtcatcodes, protect  = prtcatcodes,
    tex = texcatcodes, texcatcodes = texcatcodes, plain    = texcatcodes,
    txt = txtcatcodes, txtcatcodes = txtcatcodes, text     = txtcatcodes,
    vrb = vrbcatcodes, vrbcatcodes = vrbcatcodes, verbatim = vrbcatcodes,
    xml = xmlcatcodes, xmlcatcodes = xmlcatcodes,
}

function context.pushcatcodes(c)
    insert(catcodestack,currentcatcodes)
    currentcatcodes = (c and catcodes[c] or tonumber(c)) or currentcatcodes
end

function context.popcatcodes()
    currentcatcodes = remove(catcodestack) or currentcatcodes
end

function context.unprotect()
    insert(catcodestack,currentcatcodes)
    currentcatcodes = prtcatcodes
end

function context.protect()
    currentcatcodes = remove(catcodestack) or currentcatcodes
end

function tex.fprint(...) -- goodie
    texsprint(currentcatcodes,format(...))
end

local function writer(command,first,...)
--~     if first == nil then -- we can move the first test to the caller (twice: direct and boolean)
--~         flush(currentcatcodes,command)
--~     else
        local t = { first, ... }
        flush(currentcatcodes,command) -- todo: ctx|prt|texcatcodes
        local direct = false
        for i=1,#t do
            local ti = t[i]
            local typ = type(ti)
            if direct then
                if typ == "string" or typ == "number" then
                    flush(currentcatcodes,ti)
                else
                    trace_context("error: invalid use of direct in '%s', only strings and numbers can be flushed directly, not '%s'",command,typ)
                end
                direct = false
            elseif ti == nil then
                -- nothing
            elseif typ == "string" then
                if ti == "" then
                    flush(currentcatcodes,"{}")
                else
                    flush(currentcatcodes,"{",ti,"}")
                end
            elseif typ == "number" then
                flush(currentcatcodes,"{",ti,"}")
            elseif typ == "table" then
                local tn = #ti
                if tn == 0 then
                    local done = false
                    for k, v in next, ti do
                        if done then
                            if v == "" then
                                flush(currentcatcodes,",",k,'=')
                            else
                                flush(currentcatcodes,",",k,'=',v)
                            end
                        else
                            if v == "" then
                                flush(currentcatcodes,"[",k,'=')
                            else
                                flush(currentcatcodes,"[",k,'=',v)
                            end
                            done = true
                        end
                    end
                    flush(currentcatcodes,"]")
                elseif tn == 1 then -- some 20% faster than the next loop
                    local tj = ti[1]
                    if type(tj) == "function" then
                        flush(currentcatcodes,"[\\mkivflush{",_store_(tj),"}]")
                    else
                        flush(currentcatcodes,"[",tj,"]")
                    end
                else -- is concat really faster than flushes here? probably needed anyway (print artifacts)
                    for j=1,tn do
                        local tj = ti[j]
                        if type(tj) == "function" then
                            ti[j] = "\\mkivflush{" .. _store_(tj) .. "}"
                        end
                    end
                    flush(currentcatcodes,"[",concat(ti,","),"]")
                end
            elseif typ == "function" then
                flush(currentcatcodes,"{\\mkivflush{",_store_(ti),"}}") -- todo: ctx|prt|texcatcodes
            elseif typ == "boolean" then
                if ti then
                    flush(currentcatcodes,"^^M")
                else
                    direct = true
                end
            elseif typ == "thread" then
                trace_context("coroutines not supported as we cannot yield across boundaries")
            elseif isnode(ti) then
                writenode(ti)
            else
                trace_context("error: '%s' gets a weird argument '%s'",command,tostring(ti))
            end
        end
        if direct then
            trace_context("error: direct flushing used in '%s' without following argument",command)
        end
--~     end
end

local function indexer(t,k)
    local c = "\\" .. k
    local f = function(first,...)
        if first == nil then
            flush(currentcatcodes,c)
        else
            return writer(c,first,...)
        end
    end
    t[k] = f
    return f
end

local function caller(t,f,a,...)
    if not t then
        -- so we don't need to test in the calling (slower but often no issue)
    elseif f ~= nil then
        local typ = type(f)
        if typ == "string" then
            if a then
                flush(currentcatcodes,format(f,a,...))
            else
                flush(currentcatcodes,f)
            end
        elseif typ == "number" then
            if a then
                flush(currentcatcodes,f,a,...)
            else
                flush(currentcatcodes,f)
            end
        elseif typ == "function" then
            -- ignored: a ...
            flush(currentcatcodes,"{\\mkivflush{",_store_(f),"}}") -- todo: ctx|prt|texcatcodes
        elseif typ == "boolean" then
            -- ignored: a ...
            if f then
                flush(currentcatcodes,"^^M")
            elseif a ~= nil then
                writer("",a,...)
            end
        elseif typ == "thread" then
            trace_context("coroutines not supported as we cannot yield across boundaries")
        elseif isnode(f) then
            writenode(f)
        else
            trace_context("error: 'context' gets a weird argument '%s'",tostring(f))
        end
    end
end

setmetatable(context, { __index = indexer, __call = caller } )

-- logging

local trace_stack   = { }

local normalflush   = flush
local normalwriter  = writer
local currenttrace  = nil
local nofwriters    = 0
local nofflushes    = 0

statistics.register("traced context", function()
    if nofwriters > 0 or nofflushes > 0 then
        return format("writers: %s, flushes: %s, maxstack: %s",nofwriters,nofflushes,_n_)
    end
end)

local tracedwriter = function(...)
    nofwriters = nofwriters + 1
    local t, f, n = { "w : " }, flush, 0
    flush = function(...)
        n = n + 1
        t[n] = concat({...},"",2)
        normalflush(...)
    end
    normalwriter(...)
    flush = f
    currenttrace(concat(t))
end

local tracedflush = function(...)
    nofflushes = nofflushes + 1
    normalflush(...)
    local t = { ... }
    t[1] = "f : " -- replaces the catcode
    currenttrace(concat(t))
end

local function pushlogger(trace)
    insert(trace_stack,currenttrace)
    currenttrace = trace
    flush, writer = tracedflush, tracedwriter
end

local function poplogger()
    currenttrace = remove(trace_stack)
    if not currenttrace then
        flush, writer = normalflush, normalwriter
    end
end

local function settracing(v)
    if v then
        pushlogger(trace_context)
    else
        poplogger()
    end
end

trackers.register("context.trace",settracing)

context.pushlogger = pushlogger
context.poplogger  = poplogger
context.settracing = settracing

local trace_cld = false  trackers.register("context.files", function(v) trace_cld = v end)

function context.runfile(filename)
    local foundname = resolvers.findtexfile(file.addsuffix(filename,"cld")) or ""
    if foundname ~= "" then
        local ok = dofile(foundname)
        if type(ok) == "function" then
            if trace_cld then
                trace_context("begin of file '%s' (function call)",foundname)
            end
            ok()
            if trace_cld then
                trace_context("end of file '%s' (function call)",foundname)
            end
        elseif ok then
            trace_context("file '%s' is processed and returns true",foundname)
        else
            trace_context("file '%s' is processed and returns nothing",foundname)
        end
    else
        trace_context("unknown file '%s'",filename)
    end
end

-- some functions

function context.direct(first,...)
    if first ~= nil then
        return writer("",first,...)
    end
end

-- todo: use flush directly

function context.char(k) -- todo: if catcode == letter or other then just the utf
    if type(k) == "table" then
        for i=1,#k do
            context(format([[\char%s\relax]],k[i]))
        end
    elseif k then
        context(format([[\char%s\relax]],k))
    end
end

function context.utfchar(k)
    context(utfchar(k))
end

function context.chardef(cs,u)
    context(format([[\chardef\%s=%s\relax]],k))
end

function context.par()
    context([[\par]]) -- no need to add {} there
end

function context.bgroup()
    context("{")
end

function context.egroup()
    context("}")
end

function context.verbatim(...)
    flush(vrbcatcodes,...)
end

-- context.delayed

local delayed = { } context.delayed = delayed -- maybe also store them

local function indexer(t,k)
    local f = function(...)
        local a = { ... }
        return function()
            return context[k](unpack(a))
        end
    end
    t[k] = f
    return f
end

local function caller(t,...)
    local a = { ... }
    return function()
        return context(unpack(a))
    end
end

setmetatable(delayed, { __index = indexer, __call = caller } )

-- context.nested

local nested = { } context.nested = nested

local function indexer(t,k)
    local f = function(...)
        local t, savedflush, n = { }, flush, 0
        flush = function(c,f,s,...) -- catcodes are ignored
            n = n + 1
            t[n] = s and concat{f,s,...} or f -- optimized for #args == 1
        end
        context[k](...)
        flush = savedflush
        return concat(t)
    end
    t[k] = f
    return f
end

local function caller(t,...)
    local t, savedflush, n = { }, flush, 0
    flush = function(c,f,s,...) -- catcodes are ignored
        n = n + 1
        t[n] = s and concat{f,s,...} or f -- optimized for #args == 1
    end
    context(...)
    flush = savedflush
    return concat(t)
end

setmetatable(nested, { __index = indexer, __call = caller } )

-- metafun

local metafun = { } context.metafun = metafun

local mpdrawing = "\\MPdrawing"

local function caller(t,f,a,...)
    if not t then
        -- skip
    elseif f then
        local typ = type(f)
        if typ == "string" then
            if a then
                flush(currentcatcodes,mpdrawing,"{",format(f,a,...),"}")
            else
                flush(currentcatcodes,mpdrawing,"{",f,"}")
            end
        elseif typ == "number" then
            if a then
                flush(currentcatcodes,mpdrawing,"{",f,a,...,"}")
            else
                flush(currentcatcodes,mpdrawing,"{",f,"}")
            end
        elseif typ == "function" then
            -- ignored: a ...
            flush(currentcatcodes,mpdrawing,"{\\mkivflush{",store_(f),"}}")
        elseif typ == "boolean" then
            -- ignored: a ...
            if f then
                flush(currentcatcodes,mpdrawing,"{^^M}")
            else
                trace_context("warning: 'metafun' gets argument 'false' which is currently unsupported")
            end
        else
            trace_context("error: 'metafun' gets a weird argument '%s'",tostring(f))
        end
    end
end

setmetatable(metafun, { __call = caller } )

function metafun.start()
    context.resetMPdrawing()
end

function metafun.stop()
    context.MPdrawingdonetrue()
    context.getMPdrawing()
end

function metafun.color(name)
    return format([[\MPcolor{%s}]],name)
end

-- metafun.delayed

local delayed = { } metafun.delayed = delayed

local function indexer(t,k)
    local f = function(...)
        local a = { ... }
        return function()
            return metafun[k](unpack(a))
        end
    end
    t[k] = f
    return f
end


local function caller(t,...)
    local a = { ... }
    return function()
        return metafun(unpack(a))
    end
end

setmetatable(delayed, { __index = indexer, __call = caller } )

--~ Not that useful yet. Maybe something like this when the main loop
--~ is a coroutine. It also does not help taking care of nested calls.
--~ Even worse, it interferes with other mechanisms using context calls.
--~
--~ local create, yield, resume = coroutine.create, coroutine.yield, coroutine.resume
--~ local getflush, setflush = context.getflush, context.setflush
--~ local texsprint, ctxcatcodes = tex.sprint, tex.ctxcatcodes
--~
--~ function context.getflush()
--~     return flush
--~ end
--~
--~ function context.setflush(newflush)
--~     local oldflush = flush
--~     flush = newflush or flush
--~     return oldflush
--~ end
--~
--~ function context.direct(f)
--~     local routine = create(f)
--~     local oldflush = getflush()
--~     function newflush(...)
--~         oldflush(...)
--~         yield(true)
--~     end
--~     setflush(newflush)
--~
--~  -- local function resumecontext()
--~  --     local done = resume(routine)
--~  --     if not done then
--~  --         return
--~  --     end
--~  --     resumecontext() -- stack overflow ... no tail recursion
--~  -- end
--~  -- context.resume = resumecontext
--~  -- texsprint(ctxcatcodes,"\\ctxlua{context.resume()}")
--~
--~     local function resumecontext()
--~         local done = resume(routine)
--~         if not done then
--~             return
--~         end
--~      -- texsprint(ctxcatcodes,"\\exitloop")
--~         texsprint(ctxcatcodes,"\\ctxlua{context.resume()}") -- can be simple macro call
--~     end
--~     context.resume = resumecontext
--~  -- texsprint(ctxcatcodes,"\\doloop{\\ctxlua{context.resume()}}") -- can be fast loop at the tex end
--~     texsprint(ctxcatcodes,"\\ctxlua{context.resume()}")
--~
--~ end
--~
--~ function something()
--~     context("\\setbox0")
--~     context("\\hbox{hans hagen xx}")
--~     context("\\the\\wd0/\\box0")
--~ end
--~
--~ context.direct(something)

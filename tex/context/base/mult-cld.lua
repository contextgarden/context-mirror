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

-- tflush needs checking ... sort of weird that it's not a table

context       = context or { }
local context = context

local format, concat = string.format, table.concat
local next, type, tostring = next, type, tostring
local insert, remove = table.insert, table.remove

local tex = tex

local texsprint   = tex.sprint
local textprint   = tex.tprint
local texprint    = tex.print
local texiowrite  = texio.write
local texcount    = tex.count
local ctxcatcodes = tex.ctxcatcodes
local prtcatcodes = tex.prtcatcodes
local vrbcatcodes = tex.vrbcatcodes

local flush = texsprint

local report_cld = logs.new("cld")

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
    elseif not sn() and texcount.trialtypesettingmode == 0 then
        _stack_[n] = nil
    else
        -- keep, beware, that way the stack can grow
    end
end

context._stack_ = _stack_
context._store_ = _store_
context._flush_ = _flush_

-- Should we keep the catcodes with the function?

local catcodestack    = { }
local currentcatcodes = ctxcatcodes

function context.pushcatcodes(c)
    insert(catcodestack,currentcatcodes)
    currentcatcodes = c
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

--~ function context.direct(...)
--~     context.flush(...)
--~ end

--~ function context.verbose(...)
--~     context.flush(vrbcatcodes,...)
--~ end

local trace_context = logs.new("context") -- here

function context.trace(intercept)
    local normalflush = flush
    flush = function(...)
        trace_context(concat({...},"",2))
        if not intercept then
            normalflush(...)
        end
    end
    context.trace = function() end
end

function context.getflush()
    return flush
end

function context.setflush(newflush)
    local oldflush = flush
    flush = newflush or flush
    return oldflush
end

trackers.register("context.flush",     function(v) if v then context.trace()     end end)
trackers.register("context.intercept", function(v) if v then context.trace(true) end end)

--~ context.trace()

-- beware, we had command as part of the flush and made it "" afterwards so that we could
-- keep it there (...,command,...) but that really confuses the tex machinery

local function writer(command,first,...) -- 5% faster than just ... and separate flush of command
    if not command then
        -- error
    elseif not first then
        flush(currentcatcodes,command)
    else
        local t = { first, ... }
        flush(currentcatcodes,command)
        for i=1,#t do
            local ti = t[i]
            local typ = type(ti)
            if ti == nil then
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
                flush(currentcatcodes,"{\\mkivflush{",_store_(ti),"}}")
        --  elseif typ == "boolean" then
        --      flush(currentcatcodes,"\n")
            elseif ti == true then
                flush(currentcatcodes,"\n")
            elseif typ == false then
            --  if force == "direct" then
                flush(currentcatcodes,tostring(ti))
            --  end
            elseif typ == "thread" then
                trace_context("coroutines not supported as we cannot yield across boundaries")
            else
                trace_context("error: %s gets a weird argument %s",command,tostring(ti))
            end
        end
    end
end

--~ experiments.register("context.writer",function()
--~     writer = newwriter
--~ end)
local function indexer(t,k)
    local c = "\\" .. k .. " "
    local f = function(...) return writer(c,...) end
    t[k] = f
    return f
end

local function caller(t,f,a,...)
    if not t then
        -- so we don't need to test in the calling (slower but often no issue)
    elseif a then
        flush(currentcatcodes,format(f,a,...))
    elseif type(f) == "function" then
        flush(currentcatcodes,"{\\mkivflush{" .. _store_(f) .. "}}")
    elseif f then
        flush(currentcatcodes,f)
    else
        flush(currentcatcodes,"\n")
    end
end

setmetatable(context, { __index = indexer, __call = caller } )

-- the only non macro:

local trace_cld = false

function context.runfile(filename)
    filename = resolvers.findtexfile(filename) or ""
    if filename ~= "" then
        local ok = dofile(filename)
        if type(ok) == "function" then
            if trace_cld then
                commands.writestatus("cld","begin of file '%s' (function call)",filename)
            end
            ok()
            if trace_cld then
                commands.writestatus("cld","end of file '%s' (function call)",filename)
            end
        elseif ok then
            commands.writestatus("cld","file '%s' is processed and returns true",filename)
        else
            commands.writestatus("cld","file '%s' is processed and returns nothing",filename)
        end
    else
        commands.writestatus("cld","unknown file '%s'",filename)
    end
end

-- tracking is using the regular mechanism; we need to define
-- these 'macro' functions explictly as otherwise they are are
-- delayed (as all commands print back to tex, so that tracing
-- would be enabled afterwards)

trackers.register("cld.print", function(v)
    trace_cld = v
    if v then
        flush = function(c,...)
            texiowrite(...)
            texsprint(c,...)
        end
    else
        flush = texsprint
    end
end)

function context.enabletrackers (str) trackers.enable (str) end
function context.disabletrackers(str) trackers.disable(str) end

-- see demo-cld.cld for an example

-- context.starttext(true)
-- context.chapter({ "label" }, "title", true)
-- context.chapter(function() return { "label" } end, "title", true)
--
-- context.startchapter({ title = "test" }, { more = "oeps" }, true)
--
-- context.bTABLE(true)
-- for i=1,10 do
--     context.bTR()
--     for i=1,10 do
--         context.bTD()
--         context("%#2i",math.random(99))
--         context.eTD()
--     end
--     context.eTR(true)
-- end
-- context.eTABLE(true)
--
-- context.stopchapter(true)
--
-- context.stoptext(true)

--~ Not that useful yet. Maybe something like this when the main loop
--~ is a coroutine. It also does not help taking care of nested calls.
--~ Even worse, it interferes with other mechanisms usign context calls.
--~
--~ local create, yield, resume = coroutine.create, coroutine.yield, coroutine.resume
--~ local getflush, setflush = context.getflush, context.setflush
--~ local texsprint, ctxcatcodes = tex.sprint, tex.ctxcatcodes
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

-- this might be generalized: register some primitives as: accepting this or that
-- we can also speed this up

function context.char(k)
    if type(k) == "table" then
        for i=1,#k do
            context(format([[\char%s\relax]],k[i]))
        end
    elseif k then
        context(format([[\char%s\relax]],k))
    end
end

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

context = context or { }

local format, concat = string.format, table.concat
local next, type, tostring = next, type, tostring
local texsprint, texiowrite, texcount, ctxcatcodes = tex.sprint, texio.write, tex.count, tex.ctxcatcodes

local flush = texsprint or function(cct,...) print(concat{...}) end

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

function tex.fprint(...) -- goodie
    texsprint(ctxcatcodes,format(...))
end

function context.trace(intercept)
    local normalflush = flush
    flush = function(c,...)
        trace_context(concat({...}))
        if not intercept then
            normalflush(c,...)
        end
    end
    context.trace = function() end
end

trackers.register("context.flush",     function(v) if v then context.trace()     end end)
trackers.register("context.intercept", function(v) if v then context.trace(true) end end)

local trace_context = logs.new("context")

local function writer(k,...) -- we can optimize for 1 argument
    if k then
        flush(ctxcatcodes,k)
        local t = { ... }
        local nt = #t
        if nt > 0 then
            for i=1,nt do
                local ti = t[i]
                local typ = type(ti)
                if ti == nil then
                    -- next
                elseif typ == "string" or typ == "number" then
                    flush(ctxcatcodes,"{",ti,"}")
                elseif typ == "table" then
                    local tn = #ti
                    if tn > 0 then
                        for j=1,tn do
                            local tj = ti[j]
                            if type(tj) == "function" then
                                ti[j] = "\\mkivflush{" .. _store_(tj) .. "}"
                            end
                        end
                        flush(ctxcatcodes,"[",concat(ti,","),"]")
                    else
                        flush(ctxcatcodes,"[")
                        local done = false
                        for k, v in next, ti do
                            if done then
                                flush(ctxcatcodes,",",k,'=',v)
                            else
                                flush(ctxcatcodes,k,'=',v)
                                done = true
                            end
                        end
                        flush(ctxcatcodes,"]")
                    end
                elseif typ == "function" then
                    flush(ctxcatcodes,"{\\mkivflush{" .. _store_(ti) .. "}}")
            --  elseif typ == "boolean" then
            --      flush(ctxcatcodes,"\n")
                elseif ti == true then
                    flush(ctxcatcodes,"\n")
                elseif typ == false then
                --  if force == "direct" then
                    flush(ctxcatcodes,tostring(ti))
                --  end
                elseif typ == "thread" then
                    trace_context("coroutines not supported as we cannot yeild across boundaries")
                else
                    trace_context("error: %s gets a weird argument %s",k,tostring(ti))
                end
            end
        end
    end
end

local function newwriter(command,first,...) -- 5% faster than just ... and separate flush of command
    if not command then
        -- error
    elseif not first then
        flush(ctxcatcodes,command)
    else
        local t = { first, ... }
        for i=1,#t do
            if i == 2 then
                command = ""
            end
            local ti = t[i]
            local typ = type(ti)
            if ti == nil then
                flush(ctxcatcodes,command)
            elseif typ == "string" or typ == "number" then
                flush(ctxcatcodes,command,"{",ti,"}")
            elseif typ == "table" then
                local tn = #ti
                if tn == 0 then
                    local done = false
                    for k, v in next, ti do
                        if done then
                            flush(ctxcatcodes,",",k,'=',v)
                        else
                            flush(ctxcatcodes,command,"[",k,'=',v)
                            done = true
                        end
                    end
                    flush(ctxcatcodes,"]")
                elseif tn == 1 then -- some 20% faster than the next loop
                    local tj = ti[1]
                    if type(tj) == "function" then
                        flush(ctxcatcodes,command,"[\\mkivflush{",_store_(tj),"}]")
                    else
                        flush(ctxcatcodes,command,"[",tj,"]")
                    end
                else -- is concat really faster than flushes here?
                    for j=1,tn do
                        local tj = ti[j]
                        if type(tj) == "function" then
                            ti[j] = "\\mkivflush{" .. _store_(tj) .. "}"
                        end
                    end
                    flush(ctxcatcodes,command,"[",concat(ti,","),"]")
                end
            elseif typ == "function" then
                flush(ctxcatcodes,command,"{\\mkivflush{",_store_(ti),"}}")
        --  elseif typ == "boolean" then
        --      flush(ctxcatcodes,"\n")
            elseif ti == true then
                flush(ctxcatcodes,command,"\n")
            elseif typ == false then
            --  if force == "direct" then
                flush(ctxcatcodes,command,tostring(ti))
            --  end
            elseif typ == "thread" then
                flush(ctxcatcodes,command)
                trace_context("coroutines not supported as we cannot yeild across boundaries")
            else
                flush(ctxcatcodes,command)
                trace_context("error: %s gets a weird argument %s",command,tostring(ti))
            end
        end
    end
end

experiments.register("context.writer",function()
    writer = newwriter
end)

-- -- --

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
        flush(ctxcatcodes,format(f,a,...))
    elseif type(f) == "function" then
        flush(ctxcatcodes,"{\\mkivflush{" .. _store_(f) .. "}}")
    elseif f then
        flush(ctxcatcodes,f)
    else
        flush(ctxcatcodes,"\n")
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

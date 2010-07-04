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
local next, type = next, type
local texsprint, texiowrite, ctxcatcodes = tex.sprint, texio.write, tex.ctxcatcodes

local flush = texsprint or function(cct,...) print(table.concat{...}) end

local _stack_, _n_ = { }, 0

local function _store_(ti)
    _n_ = _n_ + 1
    _stack_[_n_] = ti
    return _n_
end

local function _flush_(n)
    if not _stack_[n]() then
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
        logs.report("context",concat({...}))
        if not intercept then
            normalflush(c,...)
        end
    end
    context.trace = function() end
end

trackers.register("context.flush",     function(v) if v then context.trace()     end end)
trackers.register("context.intercept", function(v) if v then context.trace(true) end end)

local function writer(k,...)
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
                elseif typ == "function" then
                    flush(ctxcatcodes,"{\\mkivflush{" .. _store_(ti) .. "}}")
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
            --  elseif typ == "boolean" then
            --      flush(ctxcatcodes,"\n")
                elseif ti == true then
                    flush(ctxcatcodes,"\n")
                elseif typ == false then
                --  if force == "direct" then
                    flush(ctxcatcodes,tostring(ti))
                --  end
                elseif typ == "thread" then
                    logs.report("interfaces","coroutines not supported as we cannot yeild across boundaries")
                else
                    logs.report("interfaces","error: %s gets a weird argument %s",k,tostring(ti))
                end
            end
        end
    end
end

-- -- --

local function indexer(t,k)
    local c = "\\" .. k .. " "
    local f = function(...) return writer(c,...) end
    t[k] = f
    return f
end

local function caller(t,f,a,...)
    if a then
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

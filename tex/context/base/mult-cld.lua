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
-- Todo: optional checking against interface!

context = context or { }

local format, concat = string.format, table.concat
local next, type = next, type
local texsprint, texiowrite, ctxcatcodes = tex.sprint, texio.write, tex.ctxcatcodes

local flush = texsprint
local cache

function tex.fprint(...) -- goodie
    texsprint(ctxcatcodes,format(...))
end

local function cached_flush(c,...)
    local tt = { ... }
    for i=1,#tt do
        cache[#cache+1] = tt[i]
    end
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

local function writer(k,...)
    flush(ctxcatcodes,k)
    local t = { ... }
    if next(t) then
        for i=1,#t do
            local ti = t[i]
            local typ, force = type(ti), nil
            local saved_flush = flush
            flush = cached_flush
            while typ == "function" do
                cache = { }
                ti, force = ti()
                if force then
                    typ = false -- force special cases
                else
                    typ = type(ti)
                    if typ == "nil" then
                        typ = "string"
                        ti = concat(cache)
                    elseif typ == "string" then
                        ti = concat(cache)
                    end
                end
            end
            flush = saved_flush
            if ti == nil then
                -- next
            elseif typ == "string" or typ == "number" then
                flush(ctxcatcodes,"{",ti,"}")
            elseif typ == "table" then
                flush(ctxcatcodes,"[")
                local c = concat(ti,",")
                if c ~= "" then
                    flush(ctxcatcodes,c)
                else
                    local done = false
                    for k, v in next, ti do
                        if done then
                            flush(ctxcatcodes,",",k,'=',v)
                        else
                            flush(ctxcatcodes,k,'=',v)
                            done = true
                        end
                    end
                end
                flush(ctxcatcodes,"]")
        --  elseif typ == "boolean" then
        --      flush(ctxcatcodes,"\n")
            elseif ti == true then
                flush(ctxcatcodes,"\n")
            elseif typ == false then
                if force == "direct" then
                    flush(ctxcatcodes,tostring(ti))
                end
            else
                logs.report("interfaces","error: %s gets a weird argument %s",k,tostring(ti))
            end
        end
    end
end

local function indexer(t,k)
    local f = function(...) return writer("\\"..k.." ",...) end -- building the cs here saves time
    t[k] = f
    return f
end

local function caller(t,f,...)
    if f then
        flush(ctxcatcodes,format(f,...))
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
        if ok then
            if trace_cld then
                commands.writestatus("cld","begin of file '%s'",filename)
            end
            ok()
            if trace_cld then
                commands.writestatus("cld","end of file '%s'",filename)
            end
        else
            commands.writestatus("cld","invalid file '%s'",filename)
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

-- see demo-lud.lud for an example

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

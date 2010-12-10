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

-- __flushlines is an experiment and rather ugly so it will go away

context       = context or { }
local context = context

local format, find, gmatch, splitlines = string.format, string.find, string.gmatch, string.splitlines
local next, type, tostring, setmetatable = next, type, tostring, setmetatable
local insert, remove, concat = table.insert, table.remove, table.concat
local lpegmatch = lpeg.match

local tex = tex

local texsprint    = tex.sprint
local textprint    = tex.tprint
local texprint     = tex.print
local texiowrite   = texio.write
local texcount     = tex.count

local isnode       = node.is_node -- after 0.65 just node.type
local writenode    = node.write
local copynodelist = node.copylist

local ctxcatcodes  = tex.ctxcatcodes
local prtcatcodes  = tex.prtcatcodes
local texcatcodes  = tex.texcatcodes
local txtcatcodes  = tex.txtcatcodes
local vrbcatcodes  = tex.vrbcatcodes
local xmlcatcodes  = tex.xmlcatcodes

local flush         = texsprint

local trace_context = logs.new("context") -- here
local report_cld    = logs.new("cld")

local processlines  = false  experiments.register("context.processlines", function(v) processlines = v end)

-- for tracing it's easier to have two stacks

local _stack_f_, _n_f_ = { }, 0
local _stack_n_, _n_n_ = { }, 0

local function _store_f_(ti)
    _n_f_ = _n_f_ + 1
    _stack_f_[_n_f_] = ti
    return _n_f_
end

local function _store_n_(ti)
    _n_n_ = _n_n_ + 1
    _stack_n_[_n_n_] = ti
    return _n_n_
end

local function _flush_f_(n)
    local sn = _stack_f_[n]
    if not sn then
        report_cld("data with id %s cannot be found on stack",n)
    else
        local tn = type(sn)
        if tn == "function" then
            if not sn() and texcount["@@trialtypesetting"] == 0 then  -- @@trialtypesetting is private!
                _stack_f_[n] = nil
            else
                -- keep, beware, that way the stack can grow
            end
        else
            if texcount["@@trialtypesetting"] == 0 then  -- @@trialtypesetting is private!
                writenode(sn)
                _stack_f_[n] = nil
            else
                writenode(copynodelist(sn))
                -- keep, beware, that way the stack can grow
            end
        end
    end
end

local function _flush_n_(n)
    local sn = _stack_n_[n]
    if not sn then
        report_cld("data with id %s cannot be found on stack",n)
    elseif texcount["@@trialtypesetting"] == 0 then  -- @@trialtypesetting is private!
        writenode(sn)
        _stack_n_[n] = nil
    else
        writenode(copynodelist(sn))
        -- keep, beware, that way the stack can grow
    end
end

function context.restart()
    _stack_f_, _n_f_ = { }, 0
    _stack_n_, _n_n_ = { }, 0
end

context._stack_f_ = _stack_f_
context._store_f_ = _store_f_
context._flush_f_ = _flush_f_  cldff = _flush_f_

context._stack_n_ = _stack_n_
context._store_n_ = _store_n_
context._flush_n_ = _flush_n_  cldfn = _flush_n_

-- Should we keep the catcodes with the function?

local catcodestack    = { }
local currentcatcodes = ctxcatcodes
local contentcatcodes = ctxcatcodes

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
    contentcatcodes = currentcatcodes
end

function context.popcatcodes()
    currentcatcodes = remove(catcodestack) or currentcatcodes
    contentcatcodes = currentcatcodes
end

function context.unprotect()
    insert(catcodestack,currentcatcodes)
    currentcatcodes = prtcatcodes
    contentcatcodes = currentcatcodes
end

function context.protect()
    currentcatcodes = remove(catcodestack) or currentcatcodes
    contentcatcodes = currentcatcodes
end

function tex.fprint(...) -- goodie
    texsprint(currentcatcodes,format(...))
end

-- -- --

local newline    = lpeg.patterns.newline
local space      = lpeg.patterns.spacer
local spacing    = newline * space^0
local content    = lpeg.C((1-spacing)^1)
local emptyline  = space^0 * newline^2
local endofline  = space^0 * newline * space^0
local simpleline = endofline * lpeg.P(-1)

local function n_content(s)
    flush(contentcatcodes,s)
end

local function n_endofline()
    texsprint(" ")
end

local function n_emptyline()
    texprint("")
end

local function n_simpleline()
    texprint("")
end

function lpeg.texlinesplitter(f_content,f_endofline,f_emptyline,f_simpleline)
    local splitlines =
        simpleline / (f_simpleline or n_simpleline)
      + (
            emptyline / (f_emptyline or n_emptyline)
          + endofline / (f_endofline or n_emptyline)
          + content   / (f_content or n_content)
        )^0
    return function(str) return lpegmatch(splitlines,str) end
end

local flushlines = lpeg.texlinesplitter(n_content,n_endofline,n_emptyline,n_simpleline)

context.__flushlines = flushlines       -- maybe context.helpers.flushtexlines
context.__flush      = flush

local printlines_ctx = (
    (newline)     / function()  texprint("") end +
    (1-newline)^1 / function(s) texprint(ctxcatcodes,s) end * newline^-1
)^0

local printlines_raw = (
    (newline)     / function()  texprint("") end +
    (1-newline)^1 / function(s) texprint(s)  end * newline^-1
)^0

function context.printlines(str,raw)
    if raw then
        lpegmatch(printlines_raw,str)
    else
        lpegmatch(printlines_ctx,str)
    end
end

-- -- --

local methodhandler = resolvers.methodhandler

function context.viafile(data)
    -- this is the only way to deal with nested buffers
    -- and other catcode sensitive data
    local filename = resolvers.savers.byscheme("virtual","viafile",data)
    context.input(filename)
end

-- -- --

local function writer(parent,command,first,...)
    local t = { first, ... }
    flush(currentcatcodes,command) -- todo: ctx|prt|texcatcodes
    local direct = false
    for i=1,#t do
        local ti = t[i]
        local typ = type(ti)
        if direct then
            if typ == "string" or typ == "number" then
                flush(currentcatcodes,ti)
            else -- node.write
                trace_context("error: invalid use of direct in '%s', only strings and numbers can be flushed directly, not '%s'",command,typ)
            end
            direct = false
        elseif ti == nil then
            -- nothing
        elseif ti == "" then
            flush(currentcatcodes,"{}")
        elseif typ == "string" then
            if processlines and find(ti,"\n") then -- we can check for ti == "\n"
                flush(currentcatcodes,"{")
                local flushlines = parent.__flushlines or flushlines
                flushlines(ti)
                flush(currentcatcodes,"}")
            elseif currentcatcodes == contentcatcodes then
                flush(currentcatcodes,"{",ti,"}")
            else
                flush(currentcatcodes,"{")
                flush(contentcatcodes,ti)
                flush(currentcatcodes,"}")
            end
        elseif typ == "number" then
            -- numbers never have funny catcodes
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
                    flush(currentcatcodes,"[\\cldff{",_store_f_(tj),"}]")
                else
                    flush(currentcatcodes,"[",tj,"]")
                end
            else -- is concat really faster than flushes here? probably needed anyway (print artifacts)
                for j=1,tn do
                    local tj = ti[j]
                    if type(tj) == "function" then
                        ti[j] = "\\cldff{" .. _store_f_(tj) .. "}"
                    end
                end
                flush(currentcatcodes,"[",concat(ti,","),"]")
            end
        elseif typ == "function" then
            flush(currentcatcodes,"{\\cldff{",_store_f_(ti),"}}") -- todo: ctx|prt|texcatcodes
        elseif typ == "boolean" then
            if ti then
             -- flush(currentcatcodes,"^^M")
                texprint("")
            else
                direct = true
            end
        elseif typ == "thread" then
            trace_context("coroutines not supported as we cannot yield across boundaries")
        elseif isnode(ti) then -- slow
            flush(currentcatcodes,"{\\cldfn{",_store_n_(ti),"}}")
        else
            trace_context("error: '%s' gets a weird argument '%s'",command,tostring(ti))
        end
    end
end

local generics = { }  context.generics = generics

local function indexer(parent,k)
    local c = "\\" .. tostring(generics[k] or k)
    local f = function(first,...)
        if first == nil then
            flush(currentcatcodes,c)
        else
            return writer(parent,c,first,...)
        end
    end
    parent[k] = f
    return f
end

local function caller(parent,f,a,...)
    if not parent then
        -- so we don't need to test in the calling (slower but often no issue) (will go)
    elseif f ~= nil then
        local typ = type(f)
        if typ == "string" then
            if a then
                flush(contentcatcodes,format(f,a,...)) -- was currentcatcodes
            elseif processlines and find(f,"\n") then
                local flushlines = parent.__flushlines or flushlines
                flushlines(f)
            else
                flush(contentcatcodes,f)
            end
        elseif typ == "number" then
            if a then
                flush(currentcatcodes,f,a,...)
            else
                flush(currentcatcodes,f)
            end
        elseif typ == "function" then
            -- ignored: a ...
            flush(currentcatcodes,"{\\cldff{",_store_f_(f),"}}") -- todo: ctx|prt|texcatcodes
        elseif typ == "boolean" then
            if f then
                if a ~= nil then
                    local flushlines = parent.__flushlines or flushlines
                    flushlines(f)
                    -- ignore ... maybe some day
                else
                 -- flush(currentcatcodes,"^^M")
                    texprint("")
                end
            else
                if a ~= nil then
                    -- no command, same as context(a,...)
                    writer(parent,"",a,...)
                else
                    -- ignored
                end
            end
        elseif typ == "thread" then
            trace_context("coroutines not supported as we cannot yield across boundaries")
        elseif isnode(f) then -- slow
         -- writenode(f)
            flush(currentcatcodes,"\\cldfn{",_store_n_(f),"}")
        else
            trace_context("error: 'context' gets a weird argument '%s'",tostring(f))
        end
    end
end

local defaultcaller = caller

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
        return format("writers: %s, flushes: %s, maxstack: %s",nofwriters,nofflushes,_n_f_)
    end
end)

local tracedwriter = function(parent,...)
    nofwriters = nofwriters + 1
    local t, f, n = { "w : " }, flush, 0
    flush = function(...)
        n = n + 1
        t[n] = concat({...},"",2)
        normalflush(...)
    end
    normalwriter(parent,...)
    flush = f
    currenttrace(concat(t))
end

local tracedflush = function(...)
    nofflushes = nofflushes + 1
    normalflush(...)
    local t = { ... }
    t[1] = "f : " -- replaces the catcode
    for i=2,#t do
        local ti = t[i]
        local tt = type(ti)
        if tt == "string" then
            -- ok
        elseif tt == "number" then
            -- ok
        else
            t[i] = format("<%s>",tostring(ti))
        end
    --  currenttrace(format("%02i: %s",i-1,tostring(t[i])))
    end
    currenttrace(concat(t))
end

local function pushlogger(trace)
    insert(trace_stack,currenttrace)
    currenttrace = trace
    flush, writer = tracedflush, tracedwriter
    context.__flush = flush
end

local function poplogger()
    currenttrace = remove(trace_stack)
    if not currenttrace then
        flush, writer = normalflush, normalwriter
        context.__flush = flush
    end
end

local function settracing(v)
    if v then
        pushlogger(trace_context)
    else
        poplogger()
    end
end

-- todo: share flushers so that we can define in other files

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
        return writer(context,"",first,...)
    end
end

-- context.delayed (todo: lines)

local delayed = { } context.delayed = delayed -- maybe also store them

local function indexer(parent,k)
    local f = function(...)
        local a = { ... }
        return function()
            return context[k](unpack(a))
        end
    end
    parent[k] = f
    return f
end

local function caller(parent,...) -- todo: nodes
    local a = { ... }
    return function()
        return context(unpack(a))
    end
end

setmetatable(delayed, { __index = indexer, __call = caller } )

-- context.nested (todo: lines)

local nested = { } context.nested = nested

local function indexer(parent,k)
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
    parent[k] = f
    return f
end

local function caller(parent,...)
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

-- verbatim

local verbatim = { } context.verbatim = verbatim

local function indexer(parent,k)
    local command = context[k]
    local f = function(...)
        local savedcatcodes = contentcatcodes
        contentcatcodes = vrbcatcodes
        command(...)
        contentcatcodes = savedcatcodes
    end
    parent[k] = f
    return f
end

local function caller(parent,...)
    local savedcatcodes = contentcatcodes
    contentcatcodes = vrbcatcodes
    defaultcaller(parent,...)
    contentcatcodes = savedcatcodes
end

setmetatable(verbatim, { __index = indexer, __call = caller } )

-- metafun

local metafun = { } context.metafun = metafun

local mpdrawing = "\\MPdrawing"

local function caller(parent,f,a,...)
    if not parent then
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
            flush(currentcatcodes,mpdrawing,"{\\cldff{",store_(f),"}}")
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

local function indexer(parent,k)
    local f = function(...)
        local a = { ... }
        return function()
            return metafun[k](unpack(a))
        end
    end
    parent[k] = f
    return f
end


local function caller(parent,...)
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

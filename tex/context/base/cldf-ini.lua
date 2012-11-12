if not modules then modules = { } end modules ['cldf-ini'] = {
    version   = 1.001,
    comment   = "companion to cldf-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- This started as an experiment: generating context code at the lua end. After all
-- it is surprisingly simple to implement due to metatables. I was wondering if
-- there was a more natural way to deal with commands at the lua end. Of course it's
-- a bit slower but often more readable when mixed with lua code. It can also be handy
-- when generating documents from databases or when constructing large tables or so.
--
-- maybe optional checking against interface
-- currently no coroutine trickery
-- we could always use prtcatcodes (context.a_b_c) but then we loose protection
-- tflush needs checking ... sort of weird that it's not a table
-- __flushlines is an experiment and rather ugly so it will go away
--
-- tex.print == line with endlinechar appended

local tex = tex

context       = context or { }
local context = context

local format, find, gmatch, gsub, validstring = string.format, string.find, string.gmatch, string.gsub, string.valid
local next, type, tostring, tonumber, setmetatable = next, type, tostring, tonumber, setmetatable
local insert, remove, concat = table.insert, table.remove, table.concat
local lpegmatch, lpegC, lpegS, lpegP, lpegCc = lpeg.match, lpeg.C, lpeg.S, lpeg.P, lpeg.Cc

local texsprint         = tex.sprint
local textprint         = tex.tprint
local texprint          = tex.print
local texwrite          = tex.write
local texcount          = tex.count

local isnode            = node.is_node -- after 0.65 just node.type
local writenode         = node.write
local copynodelist      = node.copy_list

local catcodenumbers    = catcodes.numbers

local ctxcatcodes       = catcodenumbers.ctxcatcodes
local prtcatcodes       = catcodenumbers.prtcatcodes
local texcatcodes       = catcodenumbers.texcatcodes
local txtcatcodes       = catcodenumbers.txtcatcodes
local vrbcatcodes       = catcodenumbers.vrbcatcodes
local xmlcatcodes       = catcodenumbers.xmlcatcodes

local flush             = texsprint
local flushdirect       = texprint
local flushraw          = texwrite

local report_context    = logs.reporter("cld","tex")
local report_cld        = logs.reporter("cld","stack")

local processlines      = true -- experiments.register("context.processlines", function(v) processlines = v end)

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
context._flush_f_ = _flush_f_  _cldf_ = _flush_f_

context._stack_n_ = _stack_n_
context._store_n_ = _store_n_
context._flush_n_ = _flush_n_  _cldn_ = _flush_n_

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

local function pushcatcodes(c)
    insert(catcodestack,currentcatcodes)
    currentcatcodes = (c and catcodes[c] or tonumber(c)) or currentcatcodes
    contentcatcodes = currentcatcodes
end

local function popcatcodes()
    currentcatcodes = remove(catcodestack) or currentcatcodes
    contentcatcodes = currentcatcodes
end

context.pushcatcodes = pushcatcodes
context.popcatcodes  = popcatcodes

-- -- --

--~     local capture  = (
--~         space^0 * newline^2  * lpeg.Cc("")            / texprint  +
--~         space^0 * newline    * space^0 * lpeg.Cc(" ") / texsprint +
--~         content                                       / texsprint
--~     )^0

local newline       = lpeg.patterns.newline
local space         = lpeg.patterns.spacer
local spacing       = newline * space^0
local content       = lpegC((1-spacing)^1)            -- texsprint
local emptyline     = space^0 * newline^2             -- texprint("")
local endofline     = space^0 * newline * space^0     -- texsprint(" ")
local simpleline    = endofline * lpegP(-1)           --

local verbose       = lpegC((1-space-newline)^1)
local beginstripper = (lpegS(" \t")^1 * newline^1) / ""
local endstripper   = beginstripper * lpegP(-1)

local justaspace    = space * lpegCc("")
local justanewline  = newline * lpegCc("")

local function n_content(s)
    flush(contentcatcodes,s)
end

local function n_verbose(s)
    flush(vrbcatcodes,s)
end

local function n_endofline()
    flush(currentcatcodes," \r")
end

local function n_emptyline()
    flushdirect(currentcatcodes,"\r")
end

local function n_simpleline()
    flush(currentcatcodes," \r")
end

local n_exception = ""

-- better a table specification

function context.newtexthandler(specification) -- can also be used for verbose
    specification = specification or { }
    --
    local s_catcodes   = specification.catcodes
    --
    local f_before     = specification.before
    local f_after      = specification.after
    --
    local f_endofline  = specification.endofline  or n_endofline
    local f_emptyline  = specification.emptyline  or n_emptyline
    local f_simpleline = specification.simpleline or n_simpleline
    local f_content    = specification.content    or n_content
    local f_space      = specification.space
    --
    local p_exception  = specification.exception
    --
    if s_catcodes then
        f_content = function(s)
            flush(s_catcodes,s)
        end
    end
    --
    local pattern
    if f_space then
        if p_exception then
            local content = lpegC((1-spacing-p_exception)^1)
            pattern =
              (
                    justaspace   / f_space
                  + justanewline / f_endofline
                  + p_exception
                  + content      / f_content
                )^0
        else
            local content = lpegC((1-space-endofline)^1)
            pattern =
                (
                    justaspace   / f_space
                  + justanewline / f_endofline
                  + content      / f_content
                )^0
        end
    else
        if p_exception then
            local content = lpegC((1-spacing-p_exception)^1)
            pattern =
                simpleline / f_simpleline
              +
              (
                    emptyline  / f_emptyline
                  + endofline  / f_endofline
                  + p_exception
                  + content    / f_content
                )^0
        else
            local content = lpegC((1-spacing)^1)
            pattern =
                simpleline / f_simpleline
                +
                (
                    emptyline / f_emptyline
                  + endofline / f_endofline
                  + content   / f_content
                )^0
        end
    end
    --
    if f_before then
        pattern = (P(true) / f_before) * pattern
    end
    --
    if f_after then
        pattern = pattern * (P(true) / f_after)
    end
    --
    return function(str) return lpegmatch(pattern,str) end, pattern
end

function context.newverbosehandler(specification) -- a special variant for e.g. cdata in lxml-tex
    specification = specification or { }
    --
    local f_line    = specification.line    or function() flushdirect("\r") end
    local f_space   = specification.space   or function() flush(" ") end
    local f_content = specification.content or n_verbose
    local f_before  = specification.before
    local f_after   = specification.after
    --
    local pattern =
        justanewline / f_line    -- so we get call{}
      + verbose      / f_content
      + justaspace   / f_space   -- so we get call{}
    --
    if specification.strip then
        pattern = beginstripper^0 * (endstripper + pattern)^0
    else
        pattern = pattern^0
    end
    --
    if f_before then
        pattern = (lpegP(true) / f_before) * pattern
    end
    --
    if f_after then
        pattern = pattern * (lpegP(true) / f_after)
    end
    --
    return function(str) return lpegmatch(pattern,str) end, pattern
end

local flushlines = context.newtexthandler {
    content    = n_content,
    endofline  = n_endofline,
    emptyline  = n_emptyline,
    simpleline = n_simpleline,
}

context.__flushlines  = flushlines       -- maybe context.helpers.flushtexlines
context.__flush       = flush
context.__flushdirect = flushdirect

-- The next variant is only used in rare cases (buffer to mp):

local printlines_ctx = (
    (newline)     / function()  texprint("") end +
    (1-newline)^1 / function(s) texprint(ctxcatcodes,s) end * newline^-1
)^0

local printlines_raw = (
    (newline)     / function()  texprint("") end +
    (1-newline)^1 / function(s) texprint(s)  end * newline^-1
)^0

function context.printlines(str,raw)     -- todo: see if via file is useable
    if raw then
        lpegmatch(printlines_raw,str)
    else
        lpegmatch(printlines_ctx,str)
    end
end

-- This is the most reliable way to deal with nested buffers and other
-- catcode sensitive data.

local methodhandler = resolvers.methodhandler

function context.viafile(data,tag)
    if data and data ~= "" then
        local filename = resolvers.savers.byscheme("virtual",validstring(tag,"viafile"),data)
     -- context.startregime { "utf" }
        context.input(filename)
     -- context.stopregime()
    end
end

-- -- --

local function writer(parent,command,first,...) -- already optimized before call
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
                report_context("error: invalid use of direct in '%s', only strings and numbers can be flushed directly, not '%s'",command,typ)
            end
            direct = false
        elseif ti == nil then
            -- nothing
        elseif ti == "" then
            flush(currentcatcodes,"{}")
        elseif typ == "string" then
            -- is processelines seen ?
            if processlines and find(ti,"[\n\r]") then -- we can check for ti == "\n"
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
                            flush(currentcatcodes,",",k,"={",v,"}")
                        end
                    else
                        if v == "" then
                            flush(currentcatcodes,"[",k,"=")
                        else
                            flush(currentcatcodes,"[",k,"={",v,"}")
                        end
                        done = true
                    end
                end
                if done then
                    flush(currentcatcodes,"]")
                else
                    flush(currentcatcodes,"[]")
                end
            elseif tn == 1 then -- some 20% faster than the next loop
                local tj = ti[1]
                if type(tj) == "function" then
                    flush(currentcatcodes,"[\\cldf{",_store_f_(tj),"}]")
                else
                    flush(currentcatcodes,"[",tj,"]")
                end
            else -- is concat really faster than flushes here? probably needed anyway (print artifacts)
                for j=1,tn do
                    local tj = ti[j]
                    if type(tj) == "function" then
                        ti[j] = "\\cldf{" .. _store_f_(tj) .. "}"
                    end
                end
                flush(currentcatcodes,"[",concat(ti,","),"]")
            end
        elseif typ == "function" then
            flush(currentcatcodes,"{\\cldf{",_store_f_(ti),"}}") -- todo: ctx|prt|texcatcodes
        elseif typ == "boolean" then
            if ti then
                flushdirect(currentcatcodes,"\r")
            else
                direct = true
            end
        elseif typ == "thread" then
            report_context("coroutines not supported as we cannot yield across boundaries")
        elseif isnode(ti) then -- slow
            flush(currentcatcodes,"{\\cldn{",_store_n_(ti),"}}")
        else
            report_context("error: '%s' gets a weird argument '%s'",command,tostring(ti))
        end
    end
end

local generics = { }  context.generics = generics

local function indexer(parent,k)
    if type(k) == "string" then
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
    else
        return context -- catch
    end
end

-- Potential optimization: after the first call we know if there will be an
-- argument. Of course there is the side effect that for instance abuse like
-- context.NC(str) fails as well as optional arguments. So, we don't do this
-- in practice. We just keep the next trick commented. The gain on some
-- 100000 calls is not that large: 0.100 => 0.95 which is neglectable.
--
-- local function constructor(parent,k,c,first,...)
--     if first == nil then
--         local f = function()
--             flush(currentcatcodes,c)
--         end
--         parent[k] = f
--         return f()
--     else
--         local f = function(...)
--             return writer(parent,c,...)
--         end
--         parent[k] = f
--         return f(first,...)
--     end
-- end
--
-- local function indexer(parent,k)
--     local c = "\\" .. tostring(generics[k] or k)
--     local f = function(...)
--         return constructor(parent,k,c,...)
--     end
--     parent[k] = f
--     return f
-- end

-- only for internal usage:

function context.constructcsonly(k) -- not much faster than the next but more mem efficient
    local c = "\\" .. tostring(generics[k] or k)
    rawset(context, k, function()
        flush(prtcatcodes,c)
    end)
end

function context.constructcs(k)
    local c = "\\" .. tostring(generics[k] or k)
    rawset(context, k, function(first,...)
        if first == nil then
            flush(prtcatcodes,c)
        else
            return writer(context,c,first,...)
        end
    end)
end

local function caller(parent,f,a,...)
    if not parent then
        -- so we don't need to test in the calling (slower but often no issue)
    elseif f ~= nil then
        local typ = type(f)
        if typ == "string" then
            if a then
                flush(contentcatcodes,format(f,a,...)) -- was currentcatcodes
            elseif processlines and find(f,"[\n\r]") then
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
            flush(currentcatcodes,"{\\cldf{",_store_f_(f),"}}") -- todo: ctx|prt|texcatcodes
        elseif typ == "boolean" then
            if f then
                if a ~= nil then
                    local flushlines = parent.__flushlines or flushlines
                    flushlines(f)
                    -- ignore ... maybe some day
                else
                    flushdirect(currentcatcodes,"\r")
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
            report_context("coroutines not supported as we cannot yield across boundaries")
        elseif isnode(f) then -- slow
         -- writenode(f)
            flush(currentcatcodes,"\\cldn{",_store_n_(f),"}")
        else
            report_context("error: 'context' gets a weird argument '%s'",tostring(f))
        end
    end
end

local defaultcaller = caller

setmetatable(context, { __index = indexer, __call = caller } )

-- now we tweak unprotect and protect

function context.unprotect()
    -- at the lua end
    insert(catcodestack,currentcatcodes)
    currentcatcodes = prtcatcodes
    contentcatcodes = currentcatcodes
    -- at the tex end
    flush("\\unprotect")
end

function context.protect()
    -- at the tex end
    flush("\\protect")
    -- at the lua end
    currentcatcodes = remove(catcodestack) or currentcatcodes
    contentcatcodes = currentcatcodes
end

function context.sprint(...) -- takes catcodes as first argument
    flush(...)
end

function context.fprint(catcodes,fmt,first,...)
    if type(catcodes) == "number" then
        if first then
            flush(catcodes,format(fmt,first,...))
        else
            flush(catcodes,fmt)
        end
    else
        if fmt then
            flush(format(catodes,fmt,first,...))
        else
            flush(catcodes)
        end
    end
end

function tex.fprint(fmt,first,...) -- goodie
    if first then
        flush(currentcatcodes,format(fmt,first,...))
    else
        flush(currentcatcodes,fmt)
    end
end

-- logging

local trace_stack   = { }

local normalflush       = flush
local normalflushdirect = flushdirect
local normalflushraw    = flushraw
local normalwriter      = writer
local currenttrace      = nil
local nofwriters        = 0
local nofflushes        = 0

statistics.register("traced context", function()
    if nofwriters > 0 or nofflushes > 0 then
        return format("writers: %s, flushes: %s, maxstack: %s",nofwriters,nofflushes,_n_f_)
    end
end)

local tracedwriter = function(parent,...) -- also catcodes ?
    nofwriters = nofwriters + 1
    local savedflush       = flush
    local savedflushdirect = flushdirect -- unlikely to be used here
    local t, n = { "w : - : " }, 1
    local traced = function(normal,catcodes,...) -- todo: check for catcodes
        local s = concat({...})
        s = gsub(s,"\r","<<newline>>") -- unlikely
        n = n + 1
        t[n] = s
        normal(catcodes,...)
    end
    flush       = function(...) traced(normalflush,      ...) end
    flushdirect = function(...) traced(normalflushdirect,...) end
    normalwriter(parent,...)
    flush       = savedflush
    flushdirect = savedflushdirect
    currenttrace(concat(t))
end

-- we could reuse collapsed

local traced = function(normal,one,two,...)
    nofflushes = nofflushes + 1
    if two then
        -- only catcodes if 'one' is number
        normal(one,two,...)
        local catcodes = type(one) == "number" and one
        local arguments = catcodes and { two, ... } or { one, two, ... }
        local collapsed, c = { format("f : %s : ", catcodes or '-') }, 1
        for i=1,#arguments do
            local argument = arguments[i]
            local argtype = type(argument)
            c = c + 1
            if argtype == "string" then
                collapsed[c] = gsub(argument,"\r","<<newline>>")
            elseif argtype == "number" then
                collapsed[c] = argument
            else
                collapsed[c] = format("<<%s>>",tostring(argument))
            end
        end
        currenttrace(concat(collapsed))
    else
        -- no catcodes
        normal(one)
        local argtype = type(one)
        if argtype == "string" then
            currenttrace(format("f : - : %s",gsub(one,"\r","<<newline>>")))
        elseif argtype == "number" then
            currenttrace(format("f : - : %s",one))
        else
            currenttrace(format("f : - : <<%s>>",tostring(one)))
        end
    end
end

local tracedflush       = function(...) traced(normalflush,      ...) end
local tracedflushdirect = function(...) traced(normalflushdirect,...) end

local function pushlogger(trace)
    trace = trace or report_context
    insert(trace_stack,currenttrace)
    currenttrace = trace
    --
    flush       = tracedflush
    flushdirect = tracedflushdirect
    writer      = tracedwriter
    --
    context.__flush       = flush
    context.__flushdirect = flushdirect
    --
    return flush, writer, flushdirect
end

local function poplogger()
    currenttrace = remove(trace_stack)
    if not currenttrace then
        flush       = normalflush
        flushdirect = normalflushdirect
        writer      = normalwriter
        --
        context.__flush       = flush
        context.__flushdirect = flushdirect
    end
    return flush, writer, flushdirect
end

local function settracing(v)
    if v then
        return pushlogger(report_context)
    else
        return poplogger()
    end
end

-- todo: share flushers so that we can define in other files

trackers.register("context.trace",settracing)

context.pushlogger  = pushlogger
context.poplogger   = poplogger
context.settracing  = settracing

-- -- untested, no time now:
--
-- local tracestack, tracestacktop = { }, false
--
-- function context.pushtracing(v)
--     insert(tracestack,tracestacktop)
--     if type(v) == "function" then
--         pushlogger(v)
--         v = true
--     else
--         pushlogger()
--     end
--     tracestacktop = v
--     settracing(v)
-- end
--
-- function context.poptracing()
--     poplogger()
--     tracestacktop = remove(tracestack) or false
--     settracing(tracestacktop)
-- end

function context.getlogger()
    return flush, writer, flush_direct
end

local trace_cld = false  trackers.register("context.files", function(v) trace_cld = v end)

function context.runfile(filename)
    local foundname = resolvers.findtexfile(file.addsuffix(filename,"cld")) or ""
    if foundname ~= "" then
        local ok = dofile(foundname)
        if type(ok) == "function" then
            if trace_cld then
                report_context("begin of file '%s' (function call)",foundname)
            end
            ok()
            if trace_cld then
                report_context("end of file '%s' (function call)",foundname)
            end
        elseif ok then
            report_context("file '%s' is processed and returns true",foundname)
        else
            report_context("file '%s' is processed and returns nothing",foundname)
        end
    else
        report_context("unknown file '%s'",filename)
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

-- metafun (this will move to another file)

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
            flush(currentcatcodes,mpdrawing,"{\\cldf{",store_(f),"}}")
        elseif typ == "boolean" then
            -- ignored: a ...
            if f then
                flush(currentcatcodes,mpdrawing,"{^^M}")
            else
                report_context("warning: 'metafun' gets argument 'false' which is currently unsupported")
            end
        else
            report_context("error: 'metafun' gets a weird argument '%s'",tostring(f))
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

-- helpers:

function context.concat(...)
    context(concat(...))
end

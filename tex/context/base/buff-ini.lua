if not modules then modules = { } end modules ['buff-ini'] = {
    version   = 1.001,
    comment   = "companion to buff-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local trace_run       = false  trackers.register("buffers.run",       function(v) trace_run       = v end)
local trace_grab      = false  trackers.register("buffers.grab",      function(v) trace_grab      = v end)
local trace_visualize = false  trackers.register("buffers.visualize", function(v) trace_visualize = v end)

local report_buffers  = logs.reporter("buffers","usage")
local report_grabbing = logs.reporter("buffers","grabbing")

local context, commands = context, commands

local concat = table.concat
local type, next, load = type, next, load
local sub, format = string.sub, string.format
local splitlines, validstring = string.splitlines, string.valid
local P, Cs, patterns, lpegmatch = lpeg.P, lpeg.Cs, lpeg.patterns, lpeg.match

local variables         = interfaces.variables
local settings_to_array = utilities.parsers.settings_to_array
local formatters        = string.formatters

local v_yes             = variables.yes

local catcodenumbers    = catcodes.numbers

local ctxcatcodes       = catcodenumbers.ctxcatcodes
local txtcatcodes       = catcodenumbers.txtcatcodes

buffers       = buffers or { }
local buffers = buffers

local cache = { }

local function erase(name)
    cache[name] = nil
end

local function assign(name,str,catcodes)
    cache[name] = { data = str, catcodes = catcodes }
end

local function append(name,str)
    local buffer = cache[name]
    if buffer then
        buffer.data = buffer.data .. str
    else
        cache[name] = { data = str }
    end
end

local function exists(name)
    return cache[name]
end

local function getcontent(name)
    local buffer = name and cache[name]
    return buffer and buffer.data or ""
end

local function getlines(name)
    local buffer = name and cache[name]
    return buffer and splitlines(buffer.data)
end

local function collectcontent(names,separator) -- no print
    if type(names) == "string" then
        names = settings_to_array(names)
    end
    local nnames = #names
    if nnames == 0 then
        return getcontent("") -- default buffer
    elseif nnames == 1 then
        return getcontent(names[1])
    else
        local t, n = { }, 0
        for i=1,nnames do
            local c = getcontent(names[i])
            if c ~= "" then
                n = n + 1
                t[n] = c
            end
        end
        return concat(t,separator or "\n") -- was \r
    end
end

local function loadcontent(names) -- no print
    if type(names) == "string" then
        names = settings_to_array(names)
    end
    local nnames = #names
    local ok = false
    if nnames == 0 then
        ok = load(getcontent("")) -- default buffer
    elseif nnames == 1 then
        ok = load(getcontent(names[1]))
    else
        -- lua 5.2 chunked load
        local i = 0
        ok = load(function()
            while true do
                i = i + 1
                if i > nnames then
                    return nil
                end
                local c = getcontent(names[i])
                if c == "" then
                    -- would trigger end of load
                else
                    return c
                end
            end
        end)
    end
    if ok then
        return ok()
    elseif nnames == 0 then
        report_buffers("invalid lua code in default buffer")
    else
        report_buffers("invalid lua code in buffer %a",concat(names,","))
    end
end


buffers.raw            = getcontent
buffers.erase          = erase
buffers.assign         = assign
buffers.append         = append
buffers.exists         = exists
buffers.getcontent     = getcontent
buffers.getlines       = getlines
buffers.collectcontent = collectcontent
buffers.loadcontent    = loadcontent

-- the context interface

commands.erasebuffer  = erase
commands.assignbuffer = assign

local anything      = patterns.anything
local alwaysmatched = patterns.alwaysmatched

local function countnesting(b,e)
    local n
    local g = P(b) / function() n = n + 1 end
            + P(e) / function() n = n - 1 end
            + anything
    local p = alwaysmatched / function() n = 0 end
            * g^0
            * alwaysmatched / function() return n end
    return p
end

local counters   = { }
local nesting    = 0
local autoundent = true
local continue   = false

-- Beware: the first character of bufferdata has to be discarded as it's there to
-- prevent gobbling of newlines in the case of nested buffers. The last one is
-- a newlinechar and is removed too.
--
-- An \n is unlikely to show up as \r is the endlinechar but \n is more generic
-- for us.

-- This fits the way we fetch verbatim: the indentatio before the sentinel
-- determines the stripping.

-- str = [[
--     test test test test test test test
--       test test test test test test test
--     test test test test test test test
--
--     test test test test test test test
--       test test test test test test test
--     test test test test test test test
--     ]]

-- local function undent(str)
--     local margin = match(str,"[\n\r]( +)[\n\r]*$") or ""
--     local indent = #margin
--     if indent > 0 then
--         local lines = splitlines(str)
--         local ok = true
--         local pattern = "^" .. margin
--         for i=1,#lines do
--             local l = lines[i]
--             if find(l,pattern) then
--                 lines[i] = sub(l,indent+1)
--             else
--                 ok = false
--                 break
--             end
--         end
--         if ok then
--             return concat(lines,"\n")
--         end
--     end
--     return str
-- end

-- how about tabs

local getmargin = (Cs(P(" ")^1)*P(-1)+1)^1
local eol       = patterns.eol
local whatever  = (P(1)-eol)^0 * eol^1

local strippers = { }

local function undent(str) -- new version, needs testing
    local margin = lpegmatch(getmargin,str)
    if type(margin) ~= "string" then
        return str
    end
    local indent = #margin
    if indent == 0 then
        return str
    end
    local stripper = strippers[indent]
    if not stripper then
        stripper = Cs((P(margin)/"" * whatever + eol^1)^1)
        strippers[indent] = stripper
    end
    return lpegmatch(stripper,str) or str
end

function commands.grabbuffer(name,begintag,endtag,bufferdata,catcodes) -- maybe move \\ to call
    local dn = getcontent(name)
    if dn == "" then
        nesting = 0
        continue = false
    end
    if trace_grab then
        if #bufferdata > 30 then
            report_grabbing("%s => |%s..%s|",name,sub(bufferdata,1,10),sub(bufferdata,-10,#bufferdata))
        else
            report_grabbing("%s => |%s|",name,bufferdata)
        end
    end
    local counter = counters[begintag]
    if not counter then
        counter = countnesting(begintag,endtag)
        counters[begintag] = counter
    end
    nesting = nesting + lpegmatch(counter,bufferdata)
    local more = nesting > 0
    if more then
        dn = dn .. sub(bufferdata,2,-1) .. endtag
        nesting = nesting - 1
        continue = true
    else
        if continue then
            dn = dn .. sub(bufferdata,2,-2) -- no \r, \n is more generic
        elseif dn == "" then
            dn = sub(bufferdata,2,-2)
        else
            dn = dn .. "\n" .. sub(bufferdata,2,-2) -- no \r, \n is more generic
        end
        local last = sub(dn,-1)
        if last == "\n" or last == "\r" then -- \n is unlikely as \r is the endlinechar
            dn = sub(dn,1,-2)
        end
        if autoundent then
            dn =  undent(dn)
        end
    end
    assign(name,dn,catcodes)
    commands.doifelse(more)
end

-- The optional prefix hack is there for the typesetbuffer feature and
-- in mkii we needed that (this hidden feature is used in a manual).

local function prepared(name,list,prefix) -- list is optional
    if not list or list == "" then
        list = name
    end
    if not name or name == "" then
        name = list
    end
    local content = collectcontent(list,nil) or ""
    if content == "" then
        content = "empty buffer"
    end
    if prefix then
        local name = file.addsuffix(name,"tmp")
        return tex.jobname .. "-" .. name, content
    else
        return name, content
    end
end

local capsule = "\\starttext\n%s\n\\stoptext\n"
local command = "context %s"

function commands.runbuffer(name,list,encapsulate)
    local name, content = prepared(name,list)
    if encapsulate then
        content = format(capsule,content)
    end
    local data = io.loaddata(name)
    if data ~= content then
        if trace_run then
            report_buffers("changes in %a, processing forced",name)
        end
        io.savedata(name,content)
        os.execute(format(command,name))
    elseif trace_run then
        report_buffers("no changes in %a, not processed",name)
    end
end

function commands.savebuffer(list,name,prefix) -- name is optional
    local name, content = prepared(name,list,prefix==v_yes)
    io.savedata(name,content)
end

function commands.getbuffer(name)
    local str = getcontent(name)
    if str ~= "" then
        context.viafile(str,formatters["buffer.%s"](validstring(name,"noname")))
    end
end

function commands.getbuffermkvi(name) -- rather direct !
    context.viafile(resolvers.macros.preprocessed(getcontent(name)),formatters["buffer.%s.mkiv"](validstring(name,"noname")))
end

function commands.gettexbuffer(name)
    local buffer = name and cache[name]
    if buffer and buffer.data ~= "" then
        context.pushcatcodetable()
        if buffer.catcodes == txtcatcodes then
            context.setcatcodetable(txtcatcodes)
        else
            context.setcatcodetable(ctxcatcodes)
        end
     -- context(function() context.viafile(buffer.data) end)
        context.getbuffer { name } -- viafile flushes too soon
        context.popcatcodetable()
    end
end

commands.getbufferctxlua = loadcontent

function commands.doifelsebuffer(name)
    commands.doifelse(exists(name))
end

-- This only used for mp buffers and is a kludge. Don't change the
-- texprint into texsprint as it fails because "p<nl>enddef" becomes
-- "penddef" then.

-- function commands.feedback(names)
--     texprint(ctxcatcodes,splitlines(collectcontent(names)))
-- end

function commands.feedback(names) -- bad name, maybe rename to injectbuffercontent
    context.printlines(collectcontent(names))
end

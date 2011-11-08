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

local concat = table.concat
local type, next = type, next
local sub, format, match, find = string.sub, string.format, string.match, string.find
local count, splitlines = string.count, string.splitlines

local variables = interfaces.variables
local settings_to_array = utilities.parsers.settings_to_array

local ctxcatcodes = tex.ctxcatcodes
local txtcatcodes = tex.txtcatcodes

buffers = { }

local buffers = buffers
local context = context

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

buffers.raw            = getcontent
buffers.erase          = erase
buffers.assign         = assign
buffers.append         = append
buffers.exists         = exists
buffers.getcontent     = getcontent
buffers.getlines       = getlines
buffers.collectcontent = collectcontent

-- the context interface

commands.erasebuffer  = erase
commands.assignbuffer = assign

local P, patterns, lpegmatch = lpeg.P, lpeg.patterns, lpeg.match

local function countnesting(b,e)
    local n
    local g = P(b) / function() n = n + 1 end
            + P(e) / function() n = n - 1 end
            + patterns.anything
    local p = patterns.alwaysmatched / function() n = 0 end
            * g^0
            * patterns.alwaysmatched / function() return n end
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
        else
            if dn == "" then
                dn = sub(bufferdata,2,-2)
            else
                dn = dn .. "\n" .. sub(bufferdata,2,-2) -- no \r, \n is more generic
            end
        end
        local last = sub(dn,-1)
        if last == "\n" or last == "\r" then -- \n is unlikely as \r is the endlinechar
            dn = sub(dn,1,-2)
        end
        if autoundent then
            local margin = match(dn,"[\n\r]( +)[\n\r]*$") or ""
            local indent = #margin
            if indent > 0 then
                local lines = splitlines(dn)
                local ok = true
                local pattern = "^" .. margin
                for i=1,#lines do
                    local l = lines[i]
                    if find(l,pattern) then
                        lines[i] = sub(l,indent+1)
                    else
                        ok = false
                        break
                    end
                end
                if ok then
                    dn = concat(lines,"\n")
                end
            end
        end
    end
    assign(name,dn,catcodes)
    commands.testcase(more)
end

-- The optional prefix hack is there for the typesetbuffer feature and
-- in mkii we needed that (this hidden feature is used in a manual).

local function prepared(name,list) -- list is optional
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
    return tex.jobname .. "-" .. name .. ".tmp", content
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
            report_buffers("changes in '%s', processing forced",name)
        end
        io.savedata(name,content)
        os.execute(format(command,name))
    elseif trace_run then
        report_buffers("no changes in '%s', not processed",name)
    end
end

function commands.savebuffer(list,name) -- name is optional
    local name, content = prepared(name,list)
    io.savedata(name,content)
end

function commands.getbuffer(name)
    local str = getcontent(name)
    if str ~= "" then
        context.viafile(str)
    end
end

function commands.getbuffermkvi(name) -- rather direct !
    context.viafile(resolvers.macros.preprocessed(getcontent(name)))
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

function commands.getbufferctxlua(name)
    local ok = loadstring(getcontent(name))
    if ok then
        ok()
    else
        report_buffers("invalid lua code in buffer '%s'",name)
    end
end

function commands.doifelsebuffer(name)
    commands.testcase(exists(name))
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

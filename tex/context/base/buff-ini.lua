if not modules then modules = { } end modules ['buff-ini'] = {
    version   = 1.001,
    comment   = "companion to buff-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local trace_run       = false  trackers.register("buffers.run",       function(v) trace_run       = v end)
local trace_visualize = false  trackers.register("buffers.visualize", function(v) trace_visualize = v end)

local report_buffers = logs.new("buffers")

local concat = table.concat
local type, next = type, next
local sub, format, count, splitlines = string.sub, string.format, string.count, string.splitlines

local variables = interfaces.variables
local settings_to_array = utilities.parsers.settings_to_array
local texprint, ctxcatcodes = tex.print, tex.ctxcatcodes

buffers = { }

local buffers = buffers
local context = context

local data = { }

function buffers.raw(name)
    return data[name] or ""
end

local function erase(name)
    data[name] = nil
end

local function assign(name,str)
    data[name] = str
end

local function append(name,str)
    data[name] = (data[name] or "") .. str
end

local function exists(name)
    return data[name] ~= nil
end

local function getcontent(name) -- == raw
    return data[name] or ""
end

local function getlines(name)
    local d = name and data[name]
    return d and splitlines(d)
end

local function collectcontent(names,separator) -- no print
    if type(names) == "string" then
        names = settings_to_array(names)
    end
    if #names == 1 then
        return getcontent(names[1])
    else
        local t, n = { }, 0
        for i=1,#names do
            local c = getcontent(names[i])
            if c ~= "" then
                n = n + 1
                t[n] = c
            end
        end
        return concat(t,separator or "\r") -- "\n" is safer due to comments and such
    end
end

buffers.erase          = erase
buffers.assign         = assign
buffers.append         = append
buffers.exists         = exists
buffers.getcontent     = getcontent
buffers.getlines       = getlines
buffers.collectcontent = collect

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

local counters = { }
local nesting  = 0

function commands.grabbuffer(name,begintag,endtag,bufferdata) -- maybe move \\ to call
    local dn = getcontent(name)
    if dn == "" then
        nesting = 0
    end
 -- nesting = nesting + count(bufferdata,"\\"..begintag) - count(bufferdata,"\\"..endtag)
    local counter = counters[begintag]
    if not counter then
        counter = countnesting(begintag,endtag)
        counters[begintag] = counter
    end
    nesting = nesting + lpegmatch(counter,bufferdata)
    local more = nesting > 0
    if more then
        dn = dn .. bufferdata .. endtag
        nesting = nesting - 1
    else
        if dn == "" then
            dn = sub(bufferdata,1,-2)
        else
            dn = dn .. "\n" .. sub(bufferdata,1,-2)
        end
        local last = sub(dn,-1)
        if last == "\n" or last == "\r" then
            dn = sub(dn,1,-2)
        end
    end
    assign(name,dn)
    commands.testcase(more)
end

-- The optional prefix hack is there for the typesetbuffer feature and
-- in mkii we needed that (this hidden feature is used in a manual).

local function prepared(name,list) -- list is optional
    if not list or list == "" then
        list = name
    end
    if not name or name == "" then
        name = tex.jobname .. "-" .. list .. ".tmp"
    end
    local content = collectcontent(list,nil) or ""
    if content == "" then
        content = "empty buffer"
    end
    return name, content
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
            commands.writestatus("buffers","changes in '%s', processing forced",name)
        end
        io.savedata(name,content)
        os.execute(format(command,name))
    elseif trace_run then
        commands.writestatus("buffers","no changes in '%s', not processed",name)
    end
end

function commands.savebuffer(list,name) -- name is optional
    local name, content = prepared(name,list)
    io.savedata(name,content)
end

function commands.getbuffer(name)
    context.viafile(data[name])
end

function commands.getbuffermkvi(name)
    context.viafile(resolvers.macros.preprocessed(getcontent(name)))
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

-- This only used for mp buffers and is a kludge. Don't
-- change the texprint into texsprint as it fails because
-- "p<nl>enddef" becomes "penddef" then.

function commands.feedback(names)
    texprint(ctxcatcodes,splitlines(collectcontent(names)))
end

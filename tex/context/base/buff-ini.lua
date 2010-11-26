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

local utf = unicode.utf8

-- todo: weed the next list

local concat, texprint, texwrite = table.concat, tex.print, tex.write
local utfbyte, utffind, utfgsub = utf.byte, utf.find, utf.gsub
local type, next = type, next
local huge = math.huge
local byte, sub, find, char, gsub, rep, lower, format, gmatch, match, count = string.byte, string.sub, string.find, string.char, string.gsub, string.rep, string.lower, string.format, string.gmatch, string.match, string.count
local splitlines, escapedpattern = string.splitlines, string.escapedpattern
local utfcharacters, utfvalues = string.utfcharacters, string.utfvalues
local ctxcatcodes = tex.ctxcatcodes
local variables = interfaces.variables
local lpegmatch = lpeg.match
local settings_to_array = utilities.parsers.settings_to_array
local allocate = utilities.storage.allocate
local tabtospace = utilities.strings.tabtospace

buffers = {
    data  = allocate(),
    flags = { },
}

local buffers = buffers
local context = context

local data  = buffers.data
local flags = buffers.flags

function buffers.raw(name)
    return data[name] or { }
end

function buffers.erase(name)
    data[name] = nil
end

function buffers.set(name, str)
    data[name] = { str } -- CHECK THIS
end

function buffers.append(name, str)
    data[name] = (data[name] or "") .. str
end

buffers.flags.storeastable = true

-- to be sorted out: crlf + \ ; slow now

local n = 0

function buffers.grab(name,begintag,endtag,bufferdata)
    local dn = data[name] or ""
    if dn == "" then
        buffers.level = 0
    end
    buffers.level = buffers.level + count(bufferdata,"\\"..begintag) - count(bufferdata,"\\"..endtag)
    local more = buffers.level > 0
    if more then
        dn = dn .. bufferdata .. endtag
        buffers.level = buffers.level - 1
    else
        if dn == "" then
            dn = sub(bufferdata,1,#bufferdata-1)
        else
            dn = dn .. "\n" .. sub(bufferdata,1,#bufferdata-1)
        end
        dn = gsub(dn,"[\010\013]$","")
        if flags.storeastable then
            dn = splitlines(dn)
        end
    end
    data[name] = dn
    commands.testcase(more)
end

function buffers.exists(name)
    return data[name] ~= nil
end

function buffers.doifelsebuffer(name)
    commands.testcase(data[name] ~= nil)
end

function buffers.strip(lines,first,last)
    local first, last = first or 1, last or #lines
    for i=first,last do
        local li = lines[i]
        if #li == 0 or find(li,"^%s*$") then
            first = first + 1
        else
            break
        end
    end
    for i=last,first,-1 do
        local li = lines[i]
        if #li == 0 or find(li,"^%s*$") then
            last = last - 1
        else
            break
        end
    end
    return first, last, last - first + 1
end

function buffers.range(lines,first,last,range) -- 1,3 1,+3 fromhere,tothere
    local first, last = first or 1, last or #lines
    if last < 0 then
        last = #lines + last
    end
    local what = settings_to_array(range)
    local r_first, r_last = what[1], what[2]
    local f, l = tonumber(r_first), tonumber(r_last)
    if r_first then
        if f then
            if f > first then
                first = f
            end
        else
            for i=first,last do
                if find(lines[i],r_first) then
                    first = i + 1
                    break
                end
            end
        end
    end
    if r_last then
        if l then
            if l < 0 then
                l = #lines + l
            end
            if find(r_last,"^[%+]") then -- 1,+3
                l = first + l
            end
            if l < last then
                last = l
            end
        else
            for i=first,last do
                if find(lines[i],r_last) then
                    last = i - 1
                    break
                end
            end
        end
    end
    return first, last
end

-- this will go to buff-ver.lua

-- there is some overlap in the following

flags.tablength = 7

local function flush(content,method,settings)
    local tab = settings.tab
    tab = tab and (tab == variables.yes and flags.tablength or tonumber(tab))
    if tab then
        content = utilities.strings.tabtospace(content,tab)
    end
    local visualizer = settings.visualizer
    if visualizer and visualizer ~= "" then
        visualizers.visualize(visualizer,method,content,settings)
    else -- todo:
        visualizers.visualize("",method,content,settings)
    end
end

local function filter(lines,settings) -- todo: inline or display in settings
    local strip = settings.strip
    if strip then
        lines = buffers.realign(lines,strip)
    end
    local line, n = 0, 0
    local first, last, m = buffers.strip(lines)
    if range then
        first, last = buffers.range(lines,first,last,range)
        first, last = buffers.strip(lines,first,last)
    end
    local content = concat(lines,(settings.nature == "inline" and " ") or "\n",first,last)
    return content, m
end

function buffers.typestring(settings) -- todo: settings.nature = "inline"
    local content = settings.data
    if content and content ~= "" then
        flush(content,"inline",settings)
    end
end

function buffers.typebuffer(settings) -- todo: settings.nature = "display"
    local name = settings.name
    local lines = name and data[name]
    if lines then
        if type(lines) == "string" then
            lines = splitlines(lines)
            data[name] = lines
        end
        local content, m = filter(lines,settings)
        if content and content ~= "" then
            flush(content,"display",settings)
        end
    end
end

function buffers.typefile(settings) -- todo: settings.nature = "display"
    local name = settings.name
    local str = buffers.loaddata(name)
    if str and str ~= "" then
        local regime = settings.regime
        if regime and regime ~= "" then
            regimes.load(regime)
            str = regimes.translate(str,regime)
        end
        if str and str~= "" then
            local lines = splitlines(str)
            local content, m = filter(lines,settings)
            if content and content ~= "" then
                flush(content,"display",settings)
            end
        end
    end
end

function buffers.loaddata(filename) -- this one might go away or become local
    local foundname = resolvers.findtexfile(filename) or ""
    if foundname == ""  then
        foundname = resolvers.findtexfile(file.addsuffix(filename,'tex')) or ""
    end
    if foundname == "" then
        return ""
    else
        return resolvers.loadtexfile(foundname)
    end
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
    local content = buffers.collect(list,nil) or ""
    if content == "" then
        content = "empty buffer"
    end
    return name, content
end

local capsule = "\\starttext\n%s\n\\stoptext\n"
local command = "context %s"

function buffers.save(name,list,encapsulate) -- list is optional
    local name, content = prepared(name,list)
    io.savedata(name, (encapsulate and format(capsule,content)) or content)
end

function commands.savebuffer(list,name) -- name is optional
    buffers.save(name,list)
end

function buffers.run(name,list,encapsulate)
    local name, content = prepared(name,list)
    local data = io.loaddata(name)
    content = (encapsulate and format(capsule,content)) or content
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

local printer = (lpeg.patterns.textline/texprint)^0 -- not the right one, we can use context(b)

function buffers.get(name)
    local b = data[name]
    if b then
        if type(b) == "table" then
            for i=1,#b do
                texprint(b[i])
            end
        else
            lpegmatch(printer,b)
        end
    end
end

local function content(name,separator) -- no print
    local b = data[name]
    if b then
        if type(b) == "table" then
            return concat(b,separator or "\n")
        else
            return b
        end
    else
        return ""
    end
end

buffers.content = content

function buffers.evaluate(name)
    local ok = loadstring(content(name))
    if ok then
        ok()
    else
        report_buffers("invalid lua code in buffer '%s'",name)
    end
end

function buffers.collect(names,separator) -- no print
    -- maybe we should always store a buffer as table so
    -- that we can pass it directly
    if type(names) == "string" then
        names = settings_to_array(names)
    end
    local t, n = { }, 0
    for i=1,#names do
        local c = content(names[i],separator)
        if c ~= "" then
            n = n + 1
            t[n] = c
        end
    end
    return concat(t,separator or "\r") -- "\n" is safer due to comments and such
end

function buffers.feedback(names,separator) -- we can use cld
    -- don't change the texprint into texsprint as it fails on mp buffers
    -- because (p<nl>enddef) becomes penddef then
    texprint(ctxcatcodes,splitlines(buffers.collect(names,separator)))
end

local function tobyte(c)
    return " [" .. utfbyte(c) .. "] "
end

function buffers.inspect(name)
    local b = data[name]
    if b then
        if type(b) == "table" then
            for k=1,#b do
                local v = b[k]
                context(v == "" and "[crlf]" or gsub(v,"(.)",tobyte))
                par()
            end
        else
            context((gsub(b,"(.)",tobyte)))
        end
    end
end

function buffers.realign(name,forced_n) -- no, auto, <number>
    local n, d
    if type(name) == "string" then
        d = data[name]
        if type(d) == "string" then
            d = splitlines(d)
        end
    else
        d = name -- already a buffer
    end
    forced_n = (forced_n == variables.auto and huge) or tonumber(forced_n)
    if forced_n then
        for i=1, #d do
            local spaces = find(d[i],"%S")
            if not spaces then
                -- empty line
            elseif not n then
                n = spaces
            elseif spaces == 0 then
                n = 0
                break
            elseif n > spaces then
                n = spaces
            end
        end
        if n > 0 then
            if n > forced_n then
                n = forced_n
            end
            for i=1,#d do
                d[i] = sub(d[i],n)
            end
        end
    end
    return d
end

-- escapes: buffers.setescapepair("tex","/BTEX","/ETEX")

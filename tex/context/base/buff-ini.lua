if not modules then modules = { } end modules ['buff-ini'] = {
    version   = 1.001,
    comment   = "companion to core-buf.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- todo: deal with jobname here, or actually, "" is valid as well

-- ctx lua reference model / hooks and such
-- to be optimized

-- redefine buffers.get

-- if needed we can make 'm local

local trace_run       = false  trackers.register("buffers.run",       function(v) trace_run       = v end)
local trace_visualize = false  trackers.register("buffers.visualize", function(v) trace_visualize = v end)

local report_buffers = logs.new("buffers")

local utf = unicode.utf8

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

buffers = {
    data        = allocate(),
    hooks       = { },
    flags       = { },
    commands    = { },
    visualizers = { },
}

local buffers = buffers
local context = context

local data        = buffers.data
local flags       = buffers.flags
local hooks       = buffers.hooks
local visualizers = buffers.visualizers

visualizers.defaultname = variables.typing

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

-- handy helpers
--
-- \sop[color] switch_of_pretty
-- \bop[color] begin_of_pretty
-- \eop        end_of_pretty
-- \obs        obeyedspace
-- \char <n>   special characters

local sop    = context.sop
local bop    = context.bop
local eop    = context.eop
local obs    = context.obs
local par    = context.par
local chr    = context.char

local bgroup = context.bgroup
local egroup = context.egroup

flags.optimizeverbatim = true
flags.countemptylines  = false

local doverbatimnobreak   = context.doverbatimnobreak
local doverbatimgoodbreak = context.doverbatimgoodbreak

function buffers.verbatimbreak(n,m)
    if flags.optimizeverbatim then
        if n == 2 or n == m then
            doverbatimnobreak()
        elseif n > 1 then
            doverbatimgoodbreak()
        end
    end
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

function buffers.type(name,realign,range)
    local lines = data[name]
    local action = buffers.typeline
    if lines then
        if type(lines) == "string" then
            lines = splitlines(lines)
            data[name] = lines
        end
        if realign then
            lines = buffers.realign(lines,realign)
        end
        local line, n = 0, 0
        local first, last, m = buffers.strip(lines)
        if range then
            first, last = buffers.range(lines,first,last,range)
            first, last = buffers.strip(lines,first,last)
        end
        hooks.begin_of_display()
        for i=first,last do
            n, line = action(lines[i], n, m, line)
        end
        hooks.end_of_display()
    end
end

function buffers.loaddata(filename) -- this one might go away
    -- this will be cleaned up when we have split supp-fil completely
    -- instead of half-half
    local ok, str, n = resolvers.loaders.tex(filename)
    if not str then
        ok, str, n = resolvers.loaders.tex(file.addsuffix(filename,'tex'))
    end
end

function buffers.loaddata(filename) -- this one might go away
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

function buffers.typefile(name,realign,range,regime) -- still somewhat messy, since name can be be suffixless
    local str = buffers.loaddata(name)
    if regime and regime ~= "" then
        regimes.load(regime)
        str = regimes.translate(str,regime)
    end
    if str and str~= "" then
        local lines = splitlines(str)
        if realign then
            lines = buffers.realign(lines,realign)
        end
        local line, n, action = 0, 0, buffers.typeline
        local first, last, m = buffers.strip(lines)
        hooks.begin_of_display()
        if range then
            first, last = buffers.range(lines,first,last,range)
            first, last = buffers.strip(lines,first,last)
        end
        for i=first,last do
            n, line = action(lines[i], n, m, line)
        end
        hooks.end_of_display()
    end
end

function buffers.typeline(str,n,m,line)
    n = n + 1
    buffers.verbatimbreak(n,m)
    if find(str,"%S") then
        line = line + 1
        hooks.begin_of_line(line)
        hooks.flush_line(hooks.line(str))
        hooks.end_of_line()
    else
        if flags.countemptylines then
            line = line + 1
        end
        hooks.empty_line(line)
    end
    return n, line
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

local printer = (lpeg.patterns.textline/texprint)^0

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

function buffers.feedback(names,separator)
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

-- maybe just line(n,str) empty(n,str)

visualizers.tablength = 7
visualizers.enabletab = true -- false
visualizers.obeyspace = true

function buffers.settablength(tablength)
    visualizers.tablength = tablength and tonumber(tablength) or 7
end

visualizers.handlers  = visualizers.handlers or { }

local handlers = visualizers.handlers

function buffers.newvisualizer(name)
    name = lower(name)
    local handler = { }
    handlers[name] = handler
    return handler
end

function buffers.getvisualizer(name)
    name = lower(name)
    return handlers[name] or buffers.loadvisualizer(name)
end

function buffers.loadvisualizer(name)
    name = lower(name)
    local hn = handlers[name]
    if hn then
        return hn
    else
        environment.loadluafile("pret-" .. name)
        local hn = handlers[name]
        if not hn then
        --  hn = buffers.newvisualizer(name)
            hn = handlers[visualizers.defaultname]
            handlers[name] = hn
            if trace_visualize then
                report_buffers("mapping '%s' visualizer onto '%s'",name,visualizers.defaultname)
            end
        elseif trace_visualize then
            report_buffers("loading '%s' visualizer",name)
        end
        return hn
    end
end

-- was "default", should be set at tex end (todo)

local default = buffers.newvisualizer(visualizers.defaultname)

default.begin_of_display = context.doverbatimbeginofdisplay
default.end_of_display   = context.doverbatimendofdisplay
default.begin_of_inline  = context.doverbatimbeginofinline
default.end_of_inline    = context.doverbatimendofinline
default.begin_of_line    = context.doverbatimbeginofline
default.end_of_line      = context.doverbatimendofline
default.empty_line       = context.doverbatimemptyline

--~ print(variables.typing) os.exit()

-- will become cleaner

local currentvisualizer, currenthandler

function buffers.setvisualizer(str)
    currentvisualizer = lower(str)
    currenthandler = handlers[currentvisualizer]
    if currenthandler then
    --  if trace_visualize then
    --      report_buffers("enabling specific '%s' visualizer",currentvisualizer)
    --  end
    else
        currentvisualizer = visualizers.defaultname
        currenthandler = handlers.default
    --  if trace_visualize then
    --      report_buffers("enabling default visualizer '%s'",currentvisualizer)
    --  end
    end
    if currenthandler.reset then
        currenthandler.reset()
    end
end

function buffers.resetvisualizer()
    currentvisualizer = visualizers.defaultname
    currenthandler = handlers.default
    if currenthandler.reset then
        currenthandler.reset()
    end
end

buffers.setvisualizer(visualizers.defaultname)

function visualizers.reset()
end

function buffers.doifelsevisualizer(str)
    commands.testcase((str ~= "") and (handlers[lower(str)] ~= nil))
end

-- calling routines, don't change

function hooks.begin_of_display()
    (currenthandler.begin_of_display or default.begin_of_display)(currentvisualizer)
end

function hooks.end_of_display()
    (currenthandler.end_of_display or default.end_of_display)()
end

function hooks.begin_of_inline()
    (currenthandler.begin_of_inline or default.begin_of_inline)(currentvisualizer)
end

function hooks.end_of_inline()
    (currenthandler.end_of_inline or default.end_of_inline)()
end

function hooks.flush_line(str,nesting)
    local fl = currenthandler.flush_line
    if fl then
        str = gsub(str," *[\n\r]+ *"," ") ; -- semi colon needed
        fl(str,nesting)
    else
        -- gsub done later
        default.flush_line(str,nesting)
    end
end

function hooks.flush_inline(str,nesting)
    hooks.begin_of_inline()
    hooks.flush_line(str,nesting)
    hooks.end_of_inline()
end

function hooks.begin_of_line(n)
    (currenthandler.begin_of_line or default.begin_of_line)(n)
end

function hooks.end_of_line()
    (currenthandler.end_of_line or default.end_of_line)()
end

function hooks.empty_line()
    (currenthandler.empty_line or default.empty_line)()
end

function hooks.line(str)
    if visualizers.enabletab then
        str = string.tabtospace(str,visualizers.tablength)
    else
        str = gsub(str,"\t"," ")
    end
    return (currenthandler.line or default.line)(str)
end

buffers.currentcolors = { } -- todo: registercurrentcolor and preset sop then ... faster or at least precreate tables

function buffers.changestate(n, state)
    if n then
        if state ~= n then
            if state > 0 then
                sop { buffers.currentcolors[n] }
            else
                bop { buffers.currentcolors[n] }
            end
            return n
        end
    elseif state > 0 then
        eop()
        return 0
    end
    return state
end

function default.line(str)
    return str
end

function default.flush_line(str)
    str = gsub(str," *[\n\r]+ *"," ")
    if visualizers.obeyspace then
        for c in utfcharacters(str) do
            if c == " " then
                obs()
            else
                texwrite(c)
            end
        end
    else
        texwrite(str)
    end
end

-- special one

buffers.commands.nested = "\\switchslantedtype "

function visualizers.flushnested(str, enable) -- todo: no utf, vrb catcodes, kind of obsolete mess
    str = gsub(str," *[\n\r]+ *"," ")
    local c, nested, i = "", 0, 1
    local commands = buffers.commands -- otherwise wrong commands
    while i < #str do -- slow
        c = sub(str,i,i+1)
        if c == "<<" then
            nested = nested + 1
            bgroup()
            if enable then
                context(commands.nested)
            end
            i = i + 2
        elseif c == ">>" then
            if nested > 0 then
                nested = nested - 1
                egroup()
            end
            i = i + 2
        else
            c = sub(str,i,i)
            if c == " " then
                obs()
            elseif find(c,"%a") then
                context(c)
            else
                chr(byte(c))
            end
            i = i + 1
        end
    end
    chr(byte(sub(str,i,i)))
    for i=1,#nested do
        egroup()
    end
end

function buffers.finishstate(state)
    if state > 0 then
        eop()
        return 0
    else
        return state
    end
end

local opennested  = rep("\\char"..byte('<').." ",2)
local closenested = rep("\\char"..byte('>').." ",2)

function buffers.replacenested(result)
    result = gsub(result,opennested, "{")
    result = gsub(result,closenested,"}")
    return result
end

function buffers.flushresult(result,nested)
    if nested then
        context(buffers.replacenested(concat(result)))
    else
        context(concat(result))
    end
end

-- new

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

local function flush_escaped_line(str,pattern,flushline)
    while true do
        local a, b, c = match(str,pattern)
        if a and a ~= "" then
            flushline(a)
        end
        if b and b ~= "" then
            context(b)
        end
        if c then
            if c == "" then
                break
            else
                str = c
            end
        else
            flushline(str)
            break
        end
    end
end

function buffers.setescapepair(name,pair)
    if pair and pair ~= "" then
        local visualizer = buffers.getvisualizer(name)
        visualizer.normal_flush_line = visualizer.normal_flush_line or visualizer.flush_line
        if pair == variables.no then
            visualizer.flush_line = visualizer.normal_flush_line or visualizer.flush_line
            if trace_visualize then
                report_buffers("resetting escape range for visualizer '%s'",name)
            end
        else
            local start, stop
            if pair == variables.yes then
                start, stop = "/BTEX", "/ETEX"
            else
                pair = string.split(pair,",")
                start, stop = escapedpattern(pair[1] or ""), escapedpattern(pair[2] or "")
            end
            if start ~= "" then
                local pattern
                if stop == "" then
                    pattern = "^(.-)" .. start .. "(.*)(.*)$"
                else
                    pattern = "^(.-)" .. start .. "(.-)" .. stop .. "(.*)$"
                end
                function visualizer.flush_line(str)
                    flush_escaped_line(str,pattern,visualizer.normal_flush_line)
                end
                if trace_visualize then
                    report_buffers("setting escape range for visualizer '%s' to %s -> %s",name,start,stop)
                end
            elseif trace_visualize then
                report_buffers("problematic escape specification '%s' for visualizer '%s'",pair,name)
            end
        end
    end
end

-- THIS WILL BECOME A FRAMEWORK: the problem with prety printing is that
-- we deal with snippets and therefore we need tolerant parsing

--~ local type = type

--~ visualizers = visualizers or { }

--~ local function fallback(s) return s end

--~ function visualizers.visualize(visualizer,kind,pattern)
--~     if type(visualizer) == "table" and type(kind) == "string" then
--~         kind = visualizer[kind] or visualizer.default or fallback
--~     else
--~         kind = fallback
--~     end
--~     return (lpeg.C(pattern))/kind
--~ end

--~ local flusher = texio.write
--~ local format = string.format

--~ local visualizer = {
--~     word    = function(s) return flusher(format("\\bold{%s}",s)) end,
--~     number  = function(s) return flusher(format("\\slanted{%s}",s)) end,
--~     default = function(s) return flusher(s) end,
--~ }

--~ local word   = lpeg.R("AZ","az")^1
--~ local number = lpeg.R("09")^1
--~ local any    = lpeg.P(1)

--~ local pattern = lpeg.P { "start",
--~     start = (
--~         visualizers.visualize(visualizer,"word",word) +
--~         visualizers.visualize(visualizer,"number",number) +
--~         visualizers.visualize(visualizer,"default",any)
--~     )^1
--~ }

--~ str = [[test 123 test $oeps$]]

--~ lpegmatch(pattern,str)

buffers.obsolete = buffers.obsolete or { }
local obsolete = buffers.obsolete

buffers.finish_state = buffers.finishstate   obsolete.finish_state = buffers.finishstate
buffers.change_state = buffers.finishstate   obsolete.change_state = buffers.finishstate

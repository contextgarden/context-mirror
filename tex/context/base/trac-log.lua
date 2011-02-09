if not modules then modules = { } end modules ['trac-log'] = {
    version   = 1.001,
    comment   = "companion to trac-log.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- todo: less categories, more subcategories (e.g. nodes)

--~ io.stdout:setvbuf("no")
--~ io.stderr:setvbuf("no")

local write_nl, write = texio and texio.write_nl or print, texio and texio.write or io.write
local format, gmatch, find = string.format, string.gmatch, string.find
local concat, insert, remove = table.concat, table.insert, table.remove
local escapedpattern = string.escapedpattern
local texcount = tex and tex.count
local next, type = next, type

--[[ldx--
<p>This is a prelude to a more extensive logging module. We no longer
provide <l n='xml'/> based logging a sparsing is relatively easy anyway.</p>
--ldx]]--

logs       = logs or { }
local logs = logs

local moreinfo = [[
More information about ConTeXt and the tools that come with it can be found at:

maillist : ntg-context@ntg.nl / http://www.ntg.nl/mailman/listinfo/ntg-context
webpage  : http://www.pragma-ade.nl / http://tex.aanhet.net
wiki     : http://contextgarden.net
]]

-- basic loggers

local function ignore() end

setmetatable(logs, { __index = function(t,k) t[k] = ignore ; return ignore end })

local report, subreport, status, settarget, setformatter

local direct, subdirect, writer

if tex and tex.jobname or tex.formatname then

    local valueiskey   = { __index = function(t,k) t[k] = k return k end } -- will be helper

    local target       = "term and log"

    local formats      = { } setmetatable(formats,     valueiskey)
    local translations = { } setmetatable(translations,valueiskey)

    writer = function(...)
        write_nl(target,...)
    end

    report = function(a,b,c,...)
        if c then
            write_nl(target,format("%-15s > %s\n",translations[a],format(formats[b],c,...)))
        elseif b then
            write_nl(target,format("%-15s > %s\n",translations[a],formats[b]))
        elseif a then
            write_nl(target,format("%-15s >\n",   translations[a]))
        else
            write_nl(target,"\n")
        end
    end

    direct = function(a,b,c,...)
        if c then
            return format("%-15s > %s",translations[a],format(formats[b],c,...))
        elseif b then
            return format("%-15s > %s",translations[a],formats[b])
        elseif a then
            return format("%-15s >",   translations[a])
        else
            return ""
        end
    end

    subreport = function(a,s,b,c,...)
        if c then
            write_nl(target,format("%-15s > %s > %s\n",translations[a],translations[s],format(formats[b],c,...)))
        elseif b then
            write_nl(target,format("%-15s > %s > %s\n",translations[a],translations[s],formats[b]))
        elseif a then
            write_nl(target,format("%-15s > %s >\n",   translations[a],translations[s]))
        else
            write_nl(target,"\n")
        end
    end

    subdirect = function(a,s,b,c,...)
        if c then
            return format("%-15s > %s > %s",translations[a],translations[s],format(formats[b],c,...))
        elseif b then
            return format("%-15s > %s > %s",translations[a],translations[s],formats[b])
        elseif a then
            return format("%-15s > %s >",   translations[a],translations[s])
        else
            return ""
        end
    end

    status = function(a,b,c,...)
        if c then
            write_nl(target,format("%-15s : %s\n",translations[a],format(formats[b],c,...)))
        elseif b then
            write_nl(target,format("%-15s : %s\n",translations[a],formats[b]))
        elseif a then
            write_nl(target,format("%-15s :\n",   translations[a]))
        else
            write_nl(target,"\n")
        end
    end

    local targets = {
        logfile  = "log",
        log      = "log",
        file     = "log",
        console  = "term",
        terminal = "term",
        both     = "term and log",
    }

    settarget = function(whereto)
        target = targets[whereto or "both"] or targets.both
    end

    local stack = { }

    pushtarget = function(newtarget)
        insert(stack,target)
        settarget(newtarget)
    end

    poptarget = function()
        if #stack > 0 then
            settarget(remove(stack))
        end
    end

    setformats = function(f)
        formats = f
    end

    settranslations = function(t)
        translations = t
    end

else

    writer = write_nl

    report = function(a,b,c,...)
        if c then
            write_nl(format("%-15s | %s",a,format(b,c,...)))
        elseif b then
            write_nl(format("%-15s | %s",a,b))
        elseif a then
            write_nl(format("%-15s |",   a))
        else
            write_nl("")
        end
    end

    subreport = function(a,sub,b,c,...)
        if c then
            write_nl(format("%-15s | %s | %s",a,sub,format(b,c,...)))
        elseif b then
            write_nl(format("%-15s | %s | %s",a,sub,b))
        elseif a then
            write_nl(format("%-15s | %s |",   a,sub))
        else
            write_nl("")
        end
    end

    status = function(a,b,c,...) -- not to be used in lua anyway
        if c then
            write_nl(format("%-15s : %s\n",a,format(b,c,...)))
        elseif b then
            write_nl(format("%-15s : %s\n",a,b)) -- b can have %'s
        elseif a then
            write_nl(format("%-15s :\n",   a))
        else
            write_nl("\n")
        end
    end

    direct          = ignore
    subdirect       = ignore

    settarget       = ignore
    pushtarget      = ignore
    poptarget       = ignore
    setformats      = ignore
    settranslations = ignore

end

logs.report          = report
logs.subreport       = subreport
logs.status          = status
logs.settarget       = settarget
logs.pushtarget      = pushtarget
logs.poptarget       = poptarget
logs.setformats      = setformats
logs.settranslations = settranslations

logs.direct          = direct
logs.subdirect       = subdirect
logs.writer          = writer

-- installer

-- todo: renew (un) locks when a new one is added and wildcard

local data, states = { }, nil

function logs.reporter(category,subcategory)
    local logger = data[category]
    if not logger then
        local state = false
        if states == true then
            state = true
        elseif type(states) == "table" then
            for c, _ in next, states do
                if find(category,c) then
                    state = true
                    break
                end
            end
        end
        logger = {
            reporters = { },
            state = state,
        }
        data[category] = logger
    end
    local reporter = logger.reporters[subcategory or "default"]
    if not reporter then
        if subcategory then
            reporter = function(...)
                if not logger.state then
                    subreport(category,subcategory,...)
                end
            end
            logger.reporters[subcategory] = reporter
        else
            local tag = category
            reporter = function(...)
                if not logger.state then
                    report(category,...)
                end
            end
            logger.reporters.default = reporter
        end
    end
    return reporter
end

logs.new = logs.reporter -- for old times sake

-- context specicific: this ends up in the macro stream

local ctxreport = logs.writer

function logs.setmessenger(m)
    ctxreport = m
end

function logs.messenger(category,subcategory)
    -- we need to avoid catcode mess (todo: fast context)
    if subcategory then
        return function(...)
            ctxreport(subdirect(category,subcategory,...))
        end
    else
        return function(...)
            ctxreport(direct(category,...))
        end
    end
end

-- so far

local function doset(category,value)
    if category == true then
        -- lock all
        category, value = "*", true
    elseif category == false then
        -- unlock all
        category, value = "*", false
    elseif value == nil then
        -- lock selective
        value = true
    end
    if category == "*" then
        states = value
        for k, v in next, data do
            v.state = value
        end
    else
        states = utilities.parsers.settings_to_hash(category)
        for c, _ in next, states do
            if data[c] then
                v.state = value
            else
                c = escapedpattern(c,true)
                for k, v in next, data do
                    if find(k,c) then
                        v.state = value
                    end
                end
            end
        end
    end
end

function logs.disable(category,value)
    doset(category,value == nil and true or value)
end

function logs.enable(category)
    doset(category,false)
end

function logs.categories()
    return table.sortedkeys(data)
end

function logs.show()
    local n, c, s, max = 0, 0, 0, 0
    for category, v in table.sortedpairs(data) do
        n = n + 1
        local state = v.state
        local reporters = v.reporters
        local nc = #category
        if nc > c then
            c = nc
        end
        for subcategory, _ in next, reporters do
            local ns = #subcategory
            if ns > c then
                s = ns
            end
            local m = nc + ns
            if m > max then
                max = m
            end
        end
        local subcategories = concat(table.sortedkeys(reporters),", ")
        if state == true then
            state = "disabled"
        elseif state == false then
            state = "enabled"
        else
            state = "unknown"
        end
        -- no new here
        report("logging","category: '%s', subcategories: '%s', state: '%s'",category,subcategories,state)
    end
    report("logging","categories: %s, max category: %s, max subcategory: %s, max combined: %s",n,c,s,max)
end

directives.register("logs.blocked", function(v)
    doset(v,true)
end)

-- tex specific loggers (might move elsewhere)

local report_pages = logs.reporter("pages") -- not needed but saves checking when we grep for it

local real, user, sub

function logs.start_page_number()
    real, user, sub = texcount.realpageno, texcount.userpageno, texcount.subpageno
end

function logs.stop_page_number()
    if real > 0 then
        if user > 0 then
            if sub > 0 then
                report_pages("flushing realpage %s, userpage %s, subpage %s",real,user,sub)
            else
                report_pages("flushing realpage %s, userpage %s",real,user)
            end
        else
            report_pages("flushing realpage %s",real)
        end
    else
        report_pages("flushing page")
    end
    io.flush()
end

logs.report_job_stat = statistics and statistics.showjobstat

local report_files = logs.reporter("files")

local nesting   = 0
local verbose   = false
local hasscheme = url.hasscheme

-- we don't have show_open and show_close callbacks yet

function logs.show_open(name)
 -- if hasscheme(name) ~= "virtual" then
 --     if verbose then
 --         nesting = nesting + 1
 --         report_files("level %s, opening %s",nesting,name)
 --     else
 --         write(format("(%s",name)) -- tex adds a space
 --     end
 -- end
end

function logs.show_close(name)
 -- if hasscheme(name) ~= "virtual" then
 --     if verbose then
 --         report_files("level %s, closing %s",nesting,name)
 --         nesting = nesting - 1
 --     else
 --         write(")") -- tex adds a space
 --     end
 -- end
end

function logs.show_load(name)
 -- if hasscheme(name) ~= "virtual" then
 --     if verbose then
 --         report_files("level %s, loading %s",nesting+1,name)
 --     else
 --         write(format("(%s)",name))
 --     end
 -- end
end

-- there may be scripts out there using this:

local simple = logs.reporter("comment")

logs.simple     = simple
logs.simpleline = simple

-- obsolete

function logs.setprogram  () end -- obsolete
function logs.extendbanner() end -- obsolete
function logs.reportlines () end -- obsolete
function logs.reportbanner() end -- obsolete
function logs.reportline  () end -- obsolete
function logs.simplelines () end -- obsolete
function logs.help        () end -- obsolete

-- applications

local function reportlines(t,str)
    if str then
        for line in gmatch(str,"(.-)[\n\r]") do
            t.report(line)
        end
    end
end

local function reportbanner(t)
    local banner = t.banner
    if banner then
        t.report(banner)
        t.report()
    end
end

local function reporthelp(t,...)
    local helpinfo = t.helpinfo
    if type(helpinfo) == "string" then
        reportlines(t,helpinfo)
    elseif type(helpinfo) == "table" then
        local tags = { ... }
        for i=1,#tags do
            reportlines(t,t.helpinfo[tags[i]])
            if i < #tags then
                t.report()
            end
        end
    end
end

local function reportinfo(t)
    t.report()
    reportlines(t,moreinfo)
end

function logs.application(t)
    t.name     = t.name   or "unknown"
    t.banner   = t.banner
    t.report   = logs.reporter(t.name)
    t.help     = function(...) reportbanner(t) ; reporthelp(t,...) ; reportinfo(t) end
    t.identify = function() reportbanner(t) end
    return t
end

-- somewhat special

-- logging to a file

--~ local syslogname = "oeps.xxx"
--~
--~ for i=1,10 do
--~     logs.system(syslogname,"context","test","fonts","font %s recached due to newer version (%s)","blabla","123")
--~ end

function logs.system(whereto,process,jobname,category,...)
    local message = format("%s %s => %s => %s => %s\r",os.date("%d/%m/%y %H:%m:%S"),process,jobname,category,format(...))
    for i=1,10 do
        local f = io.open(whereto,"a") -- we can consider keepint the file open
        if f then
            f:write(message)
            f:close()
            break
        else
            sleep(0.1)
        end
    end
end

local report_system = logs.reporter("system","logs")

function logs.obsolete(old,new)
    local o = loadstring("return " .. new)()
    if type(o) == "function" then
        return function(...)
            report_system("function %s is obsolete, use %s",old,new)
            loadstring(old .. "=" .. new  .. " return ".. old)()(...)
        end
    elseif type(o) == "table" then
        local t, m = { }, { }
        m.__index = function(t,k)
            report_system("table %s is obsolete, use %s",old,new)
            m.__index, m.__newindex = o, o
            return o[k]
        end
        m.__newindex = function(t,k,v)
            report_system("table %s is obsolete, use %s",old,new)
            m.__index, m.__newindex = o, o
            o[k] = v
        end
        if libraries then
            libraries.obsolete[old] = t -- true
        end
        setmetatable(t,m)
        return t
    end
end

if utilities then
    utilities.report = report_system
end

if tex and tex.error then
    function logs.texerrormessage(...) -- for the moment we put this function here
        tex.error(format(...), { })
    end
else
    function logs.texerrormessage(...)
        print(format(...))
    end
end

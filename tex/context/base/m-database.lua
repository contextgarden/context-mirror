if not modules then modules = { } end modules ['m-database'] = {
    version   = 1.001,
    comment   = "companion to m-database.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local sub, gmatch, format = string.sub, string.gmatch, string.format
local concat = table.concat
local lpegpatterns, lpegmatch, lpegsplitat = lpeg.patterns, lpeg.match, lpeg.splitat
local lpegP, lpegC, lpegS, lpegCt = lpeg.P, lpeg.C, lpeg.S, lpeg.Ct
local sprint, ctxcatcodes = tex.sprint, tex.ctxcatcodes

local trace_flush = false  trackers.register("module.database.flush", function(v) trace_flush = v end)

local report_database = logs.new("database")

buffers.database = buffers.database or { }

local separators = { -- not interfaced
    tab    = lpegpatterns.tab,
    tabs   = lpegpatterns.tab^1,
    comma  = lpegpatterns.comma,
    space  = lpegpatterns.space,
    spaces = lpegpatterns.space^1,
}

local function tracedsprint(c,str)
    report_database("snippet: %s",str)
    sprint(c,str)
end

function buffers.database.process(settings)
    local data
    local sprint = trace_flush and tracedsprint or sprint
    if settings.type == "file" then
        local filename = resolvers.finders.byscheme("any",settings.database)
        data = filename ~= "" and io.loaddata(filename)
        data = data and string.splitlines(data)
    else
        data = buffers.getlines(settings.database)
    end
    if data and #data > 0 then
        local separatorchar, quotechar, commentchar = settings.separator, settings.quotechar, settings.commentchar
        local before, after = settings.before or "", settings.after or ""
        local first, last = settings.first or "", settings.last or ""
        local left, right = settings.left or "", settings.right or ""
        local setups = settings.setups or ""
        local command = settings.command
        separatorchar = (not separatorchar and ",") or separators[separatorchar] or separatorchar
        local separator = type(separatorchar) == "string" and lpegS(separatorchar) or separatorchar
        local whatever  = lpegC((1 - separator)^0)
        if quotechar and quotechar ~= "" then
            local quotedata = nil
            for chr in gmatch(quotechar,".") do
                local quotechar = lpegP(chr)
                local quoteword = quotechar * lpeg.C((1 - quotechar)^0) * quotechar
                if quotedata then
                    quotedata = quotedata + quoteword
                else
                    quotedata = quoteword
                end
            end
            whatever = quotedata + whatever
        end
        local checker = commentchar ~= "" and lpeg.S(commentchar)
        local splitter = lpegCt(whatever * (separator * whatever)^0)
        local found = false
        for i=1,#data do
            local line = data[i]
            if line ~= "" and (not checker or not lpegmatch(checker,line)) then
                local result, r = { }, 0 -- we collect as this is nicer in tracing
                local list = lpegmatch(splitter,line)
                if not found then
                    if setups ~= "" then
                        sprint(ctxcatcodes,format("\\begingroup\\setups[%s]",setups))
                    end
                    sprint(ctxcatcodes,before)
                    found = true
                end
                r = r + 1 ; result[r] = first
                for j=1,#list do
                    r = r + 1 ; result[r] = left
                    if command == "" then
                        r = r + 1 ; result[r] = list[j]
                    else
                        r = r + 1 ; result[r] = command
                        r = r + 1 ; result[r] = "{"
                        r = r + 1 ; result[r] = list[j]
                        r = r + 1 ; result[r] = "}"
                    end
                    r = r + 1 ; result[r] = right
                end
                r = r + 1 ; result[r] = last
                sprint(ctxcatcodes,concat(result))
            end
        end
        if found then
            sprint(ctxcatcodes,after)
            if setups ~= "" then
                sprint(ctxcatcodes,"\\endgroup")
            end
        end
    else
        -- message
    end
end

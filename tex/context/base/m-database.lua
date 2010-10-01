if not modules then modules = { } end modules ['m-database'] = {
    version   = 1.001,
    comment   = "companion to m-database.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local sub, gmatch = string.sub, string.gmatch
local lpegpatterns, lpegmatch, lpegsplitat = lpeg.patterns, lpeg.match, lpeg.splitat
local lpegP, lpegC, lpegS, lpegCt = lpeg.P, lpeg.C, lpeg.S, lpeg.Ct
local sprint, ctxcatcodes = tex.sprint, tex.ctxcatcodes

buffers.database = buffers.database or { }

local separators = { -- not interfaced
    tab    = lpegpatterns.tab,
    tabs   = lpegpatterns.tab^1,
    comma  = lpegpatterns.comma,
    space  = lpegpatterns.space,
    spaces = lpegpatterns.space^1,
}

function buffers.database.process(settings)
 -- table.print(settings)
    local data
    if settings.type == "file" then
        local filename = resolvers.finders.any(settings.database)
        data = filename ~= "" and io.loaddata(filename)
        data = data and string.splitlines(data)
    else
        data = buffers.raw(settings.database)
    end
local function sprint(c,...)
    tex.sprint(tex.ctxcatcodes,[[\tt\bgroup]])
    tex.sprint(tex.vrbcatcodes,...)
    tex.sprint(tex.ctxcatcodes,[[\egroup\crlf]])
end

    if data and #data > 0 then
        local separatorchar, quotechar, commentchar = settings.separator, settings.quotechar, settings.commentchar
        local before, after = settings.before or "", settings.after or ""
        local first, last = settings.first or "", settings.last or ""
        local left, right = settings.left or "", settings.right or ""
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
                local result = { } -- we collect as this is nicer in tracing
                local list = lpegmatch(splitter,line)
                if not found then
                    local setups = settings.setups or ""
                    if setups == "" then
                        sprint(ctxcatcodes,"\\begingroup")
                    else
                        sprint(ctxcatcodes,"\\begingroup\\setups[",setups,"]")
                    end
                    sprint(ctxcatcodes,before)
                    found = true
                end
                result[#result+1] = first
                for j=1,#list do
                    result[#result+1] = left
                    if command == "" then
                        result[#result+1] = list[j]
                    else
                        result[#result+1] = command
                        result[#result+1] = "{"
                        result[#result+1] = list[j]
                        result[#result+1] = "}"
                    end
                    result[#result+1] = right
                end
                result[#result+1] = last
                sprint(ctxcatcodes,result)
            end
        end
        if found then
            sprint(ctxcatcodes,after)
            sprint(ctxcatcodes,"\\endgroup")
        end
    else
        -- message
    end
end

if not modules then modules = { } end modules ['syst-lua'] = {
    version   = 1.001,
    comment   = "companion to syst-lua.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local format, find, match, rep = string.format, string.find, string.match, string.rep
local tonumber = tonumber
local S, lpegmatch, lpegtsplitat = lpeg.S, lpeg.match, lpeg.tsplitat

local context = context

commands = commands or { }

function commands.writestatus(...) logs.status(...) end -- overloaded later

local firstoftwoarguments  = context.firstoftwoarguments  -- context.constructcsonly("firstoftwoarguments" )
local secondoftwoarguments = context.secondoftwoarguments -- context.constructcsonly("secondoftwoarguments")
local firstofoneargument   = context.firstofoneargument   -- context.constructcsonly("firstofoneargument"  )
local gobbleoneargument    = context.gobbleoneargument    -- context.constructcsonly("gobbleoneargument"   )

-- contextsprint(prtcatcodes,[[\ui_fo]]) -- firstofonearguments
-- contextsprint(prtcatcodes,[[\ui_go]]) -- gobbleonearguments
-- contextsprint(prtcatcodes,[[\ui_ft]]) -- firstoftwoarguments
-- contextsprint(prtcatcodes,[[\ui_st]]) -- secondoftwoarguments

function commands.doifelse(b)
    if b then
        firstoftwoarguments()
    else
        secondoftwoarguments()
    end
end

function commands.doif(b)
    if b then
        firstofoneargument()
    else
        gobbleoneargument()
    end
end

function commands.doifnot(b)
    if b then
        gobbleoneargument()
    else
        firstofoneargument()
    end
end

commands.testcase = commands.doifelse -- obsolete

function commands.boolcase(b)
    context(b and 1 or 0)
end

function commands.doifelsespaces(str)
    if find(str,"^ +$") then
        firstoftwoarguments()
    else
        secondoftwoarguments()
    end
end

local s = lpegtsplitat(",")
local h = { }

function commands.doifcommonelse(a,b) -- often the same test
    local ha = h[a]
    local hb = h[b]
    if not ha then
        ha = lpegmatch(s,a)
        h[a] = ha
    end
    if not hb then
        hb = lpegmatch(s,b)
        h[b] = hb
    end
    local na = #ha
    local nb = #hb
    for i=1,na do
        for j=1,nb do
            if ha[i] == hb[j] then
                firstoftwoarguments()
                return
            end
        end
    end
    secondoftwoarguments()
end

function commands.doifinsetelse(a,b)
    local hb = h[b]
    if not hb then hb = lpegmatch(s,b) h[b] = hb end
    for i=1,#hb do
        if a == hb[i] then
            firstoftwoarguments()
            return
        end
    end
    secondoftwoarguments()
end

local pattern = lpeg.patterns.validdimen

function commands.doifdimenstringelse(str)
    if lpegmatch(pattern,str) then
        firstoftwoarguments()
    else
        secondoftwoarguments()
    end
end

function commands.firstinset(str)
    local first = match(str,"^([^,]+),")
    context(first or str)
end

function commands.ntimes(str,n)
    context(rep(str,n or 1))
end

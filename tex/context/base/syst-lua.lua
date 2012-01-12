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

-- todo: use shorter names i.e. less tokenization, like prtcatcodes + f_o_t_a

local firstoftwoarguments  = context.firstoftwoarguments  -- context.constructcsonly("firstoftwoarguments" )
local secondoftwoarguments = context.secondoftwoarguments -- context.constructcsonly("secondoftwoarguments")
local firstofoneargument   = context.firstofoneargument   -- context.constructcsonly("firstofoneargument"  )
local gobbleoneargument    = context.gobbleoneargument    -- context.constructcsonly("gobbleoneargument"   )

local function testcase(b)
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

commands.testcase = testcase
commands.doifelse = testcase

function commands.boolcase(b)
    context(b and 1 or 0)
end

function commands.doifelsespaces(str)
    return testcase(find(str,"^ +$"))
end

local s = lpegtsplitat(",")
local h = { }

function commands.doifcommonelse(a,b)
    local ha = h[a]
    local hb = h[b]
    if not ha then ha = lpegmatch(s,a) h[a] = ha end
    if not hb then hb = lpegmatch(s,b) h[b] = hb end
    for i=1,#ha do
        for j=1,#hb do
            if ha[i] == hb[j] then
                return testcase(true)
            end
        end
    end
    return testcase(false)
end

function commands.doifinsetelse(a,b)
    local hb = h[b]
    if not hb then hb = lpegmatch(s,b) h[b] = hb end
    for i=1,#hb do
        if a == hb[i] then
            return testcase(true)
        end
    end
    return testcase(false)
end

local pattern = lpeg.patterns.validdimen

function commands.doifdimenstringelse(str)
    testcase(lpegmatch(pattern,str))
end

function commands.firstinlist(str)
    local first = match(str,"^([^,]+),")
    context(first or str)
end

function commands.ntimes(str,n)
    context(rep(str,n or 1))
end

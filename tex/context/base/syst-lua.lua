if not modules then modules = { } end modules ['syst-lua'] = {
    version   = 1.001,
    comment   = "companion to syst-lua.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local texsprint, texprint, texwrite, texiowrite_nl = tex.sprint, tex.print, tex.write, texio.write_nl
local format, find = string.format, string.find
local tonumber = tonumber
local S, Ct, lpegmatch, lpegsplitat = lpeg.S, lpeg.Ct, lpeg.match, lpeg.splitat

local ctxcatcodes = tex.ctxcatcodes

commands = commands or { } -- cs = commands -- shorter, maybe some day, not used now

function commands.writestatus(...) logs.status(...) end -- overloaded later

-- todo: use shorter names i.e. less tokenization

local function testcase(b)
    if b then -- looks faster with if than with expression
        texsprint(ctxcatcodes,"\\firstoftwoarguments")
    else
        texsprint(ctxcatcodes,"\\secondoftwoarguments")
    end
end

commands.testcase = testcase
commands.doifelse = testcase

function commands.doif(b)
    if b then
        texsprint(ctxcatcodes,"\\firstofoneargument")
    else
        texsprint(ctxcatcodes,"\\gobbleoneargument")
    end
end

function commands.doifnot(b)
    if b then
        texsprint(ctxcatcodes,"\\gobbleoneargument")
    else
        texsprint(ctxcatcodes,"\\firstofoneargument")
    end
end

function commands.boolcase(b)
    if b then texwrite(1) else texwrite(0) end
end

function commands.doifelsespaces(str)
    return commands.doifelse(find(str,"^ +$"))
end

local s = Ct(lpegsplitat(","))
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

local splitter = lpegsplitat(S(". "))

function commands.doifolderversionelse(one,two) -- one >= two
    if not two then
        one, two = environment.version, one
    elseif one == "" then
        one = environment.version
    end
    local y_1, m_1, d_1 = lpegmatch(splitter,one)
    local y_2, m_2, d_2 = lpegmatch(splitter,two)
    commands.testcase (
        (tonumber(y_1) or 0) >= (tonumber(y_2) or 0) and
        (tonumber(m_1) or 0) >= (tonumber(m_2) or 0) and
        (tonumber(d_1) or 0) >= (tonumber(d_1) or 0)
    )
end

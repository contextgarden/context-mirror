if not modules then modules = { } end modules ['syst-lua'] = {
    version   = 1.001,
    comment   = "companion to syst-lua.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local texsprint, texprint, texwrite, texiowrite_nl = tex.sprint, tex.print, tex.write, texio.write_nl
local format, find = string.format, string.find
local lpegmatch = lpeg.match

local ctxcatcodes = tex.ctxcatcodes

commands = commands or { } cs = commands -- shorter

function commands.writestatus(a,b,c,...)
    if c then
        texiowrite_nl(format("%-16s: %s\n",a,format(b,c,...)))
    else
        texiowrite_nl(format("%-16s: %s\n",a,b)) -- b can have %'s
    end
end
function commands.writedebug(a,b,c,...)
    if c then
        texiowrite_nl(format("%-16s| %s\n",a,format(b,c,...)))
    else
        texiowrite_nl(format("%-16s| %s\n",a,b)) -- b can have %'s
    end
end

function commands.report(s,t,...)
    commands.writestatus("!"..s,format(t,...))
end

local function testcase(b)
    if b then -- faster with if than with expression
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

local s = lpeg.Ct(lpeg.splitat(","))
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

function commands. def   (cs,value) texsprint(ctxcatcodes,format( "\\def\\%s{%s}",cs,value)) end
function commands.edef   (cs,value) texsprint(ctxcatcodes,format("\\edef\\%s{%s}",cs,value)) end
function commands.gdef   (cs,value) texsprint(ctxcatcodes,format("\\gdef\\%s{%s}",cs,value)) end
function commands.xdef   (cs,value) texsprint(ctxcatcodes,format("\\xdef\\%s{%s}",cs,value)) end
function commands.chardef(cs,value) texsprint(ctxcatcodes,format("\\chardef\\%s=%s\\relax",cs,value)) end

local pattern = lpeg.patterns.validdimen

function commands.doifdimenstringelse(str)
    testcase(lpegmatch(pattern,str))
end

if not modules then modules = { } end modules ['luat-mac'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local P, V, S, R, C, Cs, Cmt, Carg = lpeg.P, lpeg.V, lpeg.S, lpeg.R, lpeg.C, lpeg.Cs, lpeg.Cmt, lpeg.Carg
local lpegmatch, patterns = lpeg.match, lpeg.patterns

local insert, remove = table.insert, table.remove
local rep, sub = string.rep, string.sub
local setmetatable = setmetatable

local pushtarget, poptarget = logs.pushtarget, logs.poptarget

local report_macros = logs.reporter("interface","macros")

local stack, top, n, hashes = { }, nil, 0, { }

local function set(s)
    if top then
        n = n + 1
        if n > 9 then
            report_macros("number of arguments > 9, ignoring %s",s)
        else
            local ns = #stack
            local h = hashes[ns]
            if not h then
                h = rep("#",ns)
                hashes[ns] = h
            end
            m = h .. n
            top[s] = m
            return m
        end
    end
end

local function get(s)
    if not top then
        report_macros("keeping #%s, no stack",s)
        return "#" .. s -- can be lua
    end
    local m = top[s]
    if m then
        return m
    else
        report_macros("keeping #%s, not on stack",s)
        return "#" .. s -- quite likely an error
    end
end

local function push()
    top = { }
    n = 0
    local s = stack[#stack]
    if s then
        setmetatable(top,{ __index = s })
    end
    insert(stack,top)
end

local function pop()
    top = remove(stack)
end

local leftbrace   = P("{")   -- will be in patterns
local rightbrace  = P("}")
local escape      = P("\\")

local space       = patterns.space
local spaces      = space^1
local newline     = patterns.newline
local nobrace     = 1 - leftbrace - rightbrace

local longleft       = leftbrace  -- P("(")
local longright      = rightbrace -- P(")")
local nolong         = 1 - longleft - longright

local name           = R("AZ","az")^1
local csname         = (R("AZ","az") + S("@?!_"))^1
local longname       = (longleft/"") * (nolong^1) * (longright/"")
local variable       = P("#") * Cs(name + longname)
local escapedname    = escape * csname
local definer        = escape * (P("def") + P("egx") * P("def"))                  -- tex
local setter         = escape * P("set") * (P("u")^-1 * P("egx")^-1) * P("value") -- context specific
---                  + escape * P("install") * (1-P("handler"))^1 * P("handler")  -- context specific
local startcode      = P("\\starttexdefinition")                                  -- context specific
local stopcode       = P("\\stoptexdefinition")                                   -- context specific
local anything       = patterns.anything
local always         = patterns.alwaysmatched

-- The comment nilling can become an option but it nicely compensates the Lua
-- parsing here with less parsing at the TeX end. We keep lines so the errors
-- get reported all right, but comments are never seen there anyway. We keep
-- comment that starts inline as it can be something special with a % (at some
-- point we can do that as well, esp if we never use \% or `% somewhere
-- unpredictable). We need to skip comments anyway. Hm, too tricky, this
-- stripping as we can have Lua code etc.

local commenttoken   = P("%")
local crorlf         = S("\n\r")
local commentline    = commenttoken * ((Carg(1) * C((1-crorlf)^0))/function(strip,s) return strip and "" or s end)
local commentline    = commenttoken * ((1-crorlf)^0)
local leadingcomment = (commentline * crorlf^1)^1
local furthercomment = (crorlf^1 * commentline)^1

local pushlocal      = always   / push
local poplocal       = always   / pop
local declaration    = variable / set
local identifier     = variable / get

local argument       = leftbrace * ((identifier + (1-rightbrace))^0) * rightbrace

local function matcherror(str,pos)
    report_macros("runaway definition at: %s",sub(str,pos-30,pos))
end

local grammar = { "converter",
    texcode     = pushlocal
                * startcode
                * spaces
                * (name * spaces)^1 -- new: multiple
             -- * (declaration + furthercomment + (1 - newline - space))^0
                * ((declaration * (space^0/""))^1 + furthercomment + (1 - newline - space))^0 -- accepts #a #b #c
                * V("texbody")
                * stopcode
                * poplocal,
    texbody     = (   V("definition")
                    + identifier
                    + V("braced")
                    + (1 - stopcode)
                  )^0,
    definition  = pushlocal
                * definer
                * escapedname
                * (declaration + furthercomment + commentline + (1-leftbrace))^0
                * V("braced")
                * poplocal,
    setcode     = pushlocal
                * setter
                * argument
                * (declaration + furthercomment + commentline + (1-leftbrace))^0
                * V("braced")
                * poplocal,
    braced      = leftbrace
                * (   V("definition")
                    + identifier
                    + V("setcode")
                    + V("texcode")
                    + V("braced")
                    + furthercomment
                    + nobrace
                  )^0
             -- * rightbrace^-1, -- the -1 catches errors
                * (rightbrace + Cmt(always,matcherror)),

    pattern     = leadingcomment
                + V("definition")
                + V("setcode")
                + V("texcode")
                + furthercomment
                + anything,

    converter   = V("pattern")^1,
}

local parser = Cs(grammar)

local checker = P("%") * (1 - newline - P("macros"))^0
              * P("macros") * space^0 * P("=") * space^0 * C(patterns.letter^1)

-- maybe namespace

local macros = { } resolvers.macros = macros

function macros.preprocessed(str,strip)
    return lpegmatch(parser,str,1,strip)
end

function macros.convertfile(oldname,newname) -- beware, no testing on oldname == newname
    local data = resolvers.loadtexfile(oldname)
    data = interfaces.preprocessed(data) or ""
    io.savedata(newname,data)
end

function macros.version(data)
    return lpegmatch(checker,data)
end

function macros.processmkvi(str,filename)
    if (filename and file.suffix(filename) == "mkvi") or lpegmatch(checker,str) == "mkvi" then
        local result = lpegmatch(parser,str,1,true) or str
        pushtarget("log")
        report_macros("processed file '%s', delta %s",filename,#str-#result)
        poptarget("log")
        return result
    else
        return str
    end
end

if resolvers.schemes then

    local function handler(protocol,name,cachename)
        local hashed = url.hashed(name)
        local path = hashed.path
        if path and path ~= "" then
            local str = resolvers.loadtexfile(path)
            if file.suffix(path) == "mkvi" or lpegmatch(checker,str) == "mkvi" then
                -- already done automatically
                io.savedata(cachename,str)
            else
                local result = lpegmatch(parser,str,1,true) or str
                pushtarget("log")
                report_macros("processed scheme '%s', delta %s",filename,#str-#result)
                poptarget("log")
                io.savedata(cachename,result)
            end
        end
        return cachename
    end

    resolvers.schemes.install('mkvi',handler,1) -- this will cache !

    utilities.sequencers.appendaction(resolvers.openers.helpers.textfileactions,"system","resolvers.macros.processmkvi")
 -- utilities.sequencers.disableaction(resolvers.openers.helpers.textfileactions,"resolvers.macros.processmkvi")

end

-- print(macros.preprocessed(
-- [[
--     \starttexdefinition unexpanded test #aa #bb #cc
--         test
--     \stoptexdefinition
-- ]]))

-- print(macros.preprocessed([[\def\bla#bla{bla#{bla}}]]))
-- print(macros.preprocessed([[\def\bla#bla{#{bla}bla}]]))
-- print(macros.preprocessed([[\def\blä#{blá}{blà:#{blá}}]]))
-- print(macros.preprocessed([[\def\blä#bla{blà:#bla}]]))
-- print(macros.preprocessed([[\setvalue{xx}#bla{blà:#bla}]]))
-- print(macros.preprocessed([[\def\foo#bar{\setvalue{xx#bar}{#bar}}]]))
-- print(macros.preprocessed([[\def\bla#bla{bla:#{bla}}]]))
-- print(macros.preprocessed([[\def\bla_bla#bla{bla:#bla}]]))
-- print(macros.preprocessed([[\def\test#oeps{test:#oeps}]]))
-- print(macros.preprocessed([[\def\test_oeps#oeps{test:#oeps}]]))
-- print(macros.preprocessed([[\def\test#oeps{test:#{oeps}}]]))
-- print(macros.preprocessed([[\def\test#{oeps:1}{test:#{oeps:1}}]]))
-- print(macros.preprocessed([[\def\test#{oeps}{test:#oeps}]]))
-- print(macros.preprocessed([[\def\test#{oeps}{test:#oeps \halign{##\cr #oeps\cr}]]))
-- print(macros.preprocessed([[\def\test#{oeps}{test:#oeps \halign{##\cr #oeps\cr}}]]))
-- print(macros.preprocessed([[% test
-- \def\test#oeps{#oeps} % {test}
-- % test
--
-- % test
-- two
-- %test]]))
-- print(macros.preprocessed([[
-- \def\scrn_button_make_normal#namespace#current#currentparameter#text%
--   {\ctxlua{structures.references.injectcurrentset(nil,nil)}%
-- %    \hbox attr \referenceattribute \lastreferenceattribute {\localframed[#namespace:#current]{#text}}}
--    \hbox attr \referenceattribute \lastreferenceattribute {\directlocalframed[#namespace:#current]{#text}}}
-- ]]))
--
-- print(macros.preprocessed([[
-- \def\definefoo[#name]%
--  {\setvalue{start#name}{\dostartfoo{#name}}}
-- \def\dostartfoo#name%
--   {\def\noexpand\next#content\expandafter\noexpand\csname stop#name\endcsname{#name : #content}%
--   \next}
-- \def\dostartfoo#name%
--  {\normalexpanded{\def\noexpand\next#content\expandafter\noexpand\csname stop#name\endcsname}{#name : #content}%
--   \next}
-- ]]))

-- Just an experiment:
--
-- \catcode\numexpr"10FF25=\commentcatcode %% > 110000 is invalid
--
-- We could have a push/pop mechanism but binding to txtcatcodes
-- is okay too.

local txtcatcodes   = false -- also signal and yet unknown

local commentsignal = utf.char(0x10FF25)

local encodecomment = P("%%") / commentsignal --
----- encodepattern = Cs(((1-encodecomment)^0 * encodecomment)) -- strips but not nice for verbatim
local encodepattern = Cs((encodecomment + 1)^0)
local decodecomment = P(commentsignal) / "%%%%" -- why doubles here?
local decodepattern = Cs((decodecomment + 1)^0)

function resolvers.macros.encodecomment(str)
    if txtcatcodes and tex.catcodetable == txtcatcodes then
        return lpegmatch(encodepattern,str) or str
    else
        return str
    end
end

function resolvers.macros.decodecomment(str) -- normally not needed
    return txtcatcodes and lpegmatch(decodepattern,str) or str
end

-- resolvers.macros.commentsignal        = commentsignal
-- resolvers.macros.encodecommentpattern = encodepattern
-- resolvers.macros.decodecommentpattern = decodepattern

function resolvers.macros.enablecomment(thecatcodes)
    if not txtcatcodes then
        txtcatcodes = thecatcodes or catcodes.numbers.txtcatcodes
        utilities.sequencers.appendaction(resolvers.openers.helpers.textlineactions,"system","resolvers.macros.encodecomment")
    end
end

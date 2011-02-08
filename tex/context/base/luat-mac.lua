if not modules then modules = { } end modules ['luat-mac'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local P, V, S, R, C, Cs, Cmt = lpeg.P, lpeg.V, lpeg.S, lpeg.R, lpeg.C, lpeg.Cs, lpeg.Cmt
local lpegmatch, patterns = lpeg.match, lpeg.patterns

local insert, remove = table.insert, table.remove
local rep, sub = string.rep, string.sub
local setmetatable = setmetatable

local report_macros = logs.new("interface","macros")

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
    local m = top and top[s] or s
    return m
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

local longleft    = leftbrace  -- P("(")
local longright   = rightbrace -- P(")")
local nolong      = 1 - longleft - longright

local name        = R("AZ","az")^1 -- @?! -- utf?
local longname    = (longleft/"") * (nolong^1) * (longright/"")
local variable    = P("#") * Cs(name + longname)
local escapedname = escape * name
local definer     = escape * (P("def") + P("egdx") * P("def"))
local startcode   = P("\\starttexdefinition")
local stopcode    = P("\\stoptexdefinition")
local anything    = patterns.anything
local always      = patterns.alwaysmatched

local pushlocal   = always   / push
local poplocal    = always   / pop
local declaration = variable / set
local identifier  = variable / get

local function matcherror(str,pos)
    report_macros("runaway definition at: %s",sub(str,pos-30,pos))
end

local grammar = { "converter",
    texcode     = pushlocal
                * startcode
                * spaces
                * name
                * spaces
                * (declaration + (1 - newline - space))^0
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
                * (declaration + (1-leftbrace))^0
                * V("braced")
                * poplocal,
    braced      = leftbrace
                * (   V("definition")
                    + identifier
                    + V("texcode")
                    + V("braced")
                    + nobrace
                  )^0
             -- * rightbrace^-1, -- the -1 catches errors
                * (rightbrace + Cmt(always,matcherror)),

    pattern     = V("definition") + V("texcode") + anything,

    converter   = V("pattern")^1,
}

local parser = Cs(grammar)

local checker = P("%") * (1 - newline - P("macros"))^0
              * P("macros") * space^0 * P("=") * space^0 * C(patterns.letter^1)

-- maybe namespace

local macros = { } resolvers.macros = macros

function macros.preprocessed(str)
    return lpegmatch(parser,str)
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
        return lpegmatch(parser,str) or str
    else
        return str
    end
end

if resolvers.schemes then

    local function handler(protocol,name,cachename)
        local hashed = url.hashed(name)
        local path = hashed.path
        if path and path ~= "" then
            local data = resolvers.loadtexfile(path)
            data = lpegmatch(parser,data) or ""
            io.savedata(cachename,data)
        end
        return cachename
    end

    resolvers.schemes.install('mkvi',handler,1) -- this will cache !

    utilities.sequencers.appendaction(resolvers.openers.helpers.textfileactions,"system","resolvers.macros.processmkvi")
 -- utilities.sequencers.disableaction(resolvers.openers.helpers.textfileactions,"resolvers.macros.processmkvi")

end

--~ print(macros.preprocessed([[\def\blä#{blá}{blà:#{blá}}]]))
--~ print(macros.preprocessed([[\def\blä#bla{blà:#bla}]]))
--~ print(macros.preprocessed([[\def\bla#bla{bla:#bla}]]))
--~ print(macros.preprocessed([[\def\test#oeps{test:#oeps}]]))
--~ print(macros.preprocessed([[\def\test#oeps{test:#{oeps}}]]))
--~ print(macros.preprocessed([[\def\test#{oeps:1}{test:#{oeps:1}}]]))
--~ print(macros.preprocessed([[\def\test#{oeps}{test:#oeps}]]))
--~ macros.preprocessed([[\def\test#{oeps}{test:#oeps \halign{##\cr #oeps\cr}]])
--~ print(macros.preprocessed([[\def\test#{oeps}{test:#oeps \halign{##\cr #oeps\cr}}]]))

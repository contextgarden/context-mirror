if not modules then modules = { } end modules ['v-lua'] = {
    version   = 1.001,
    comment   = "companion to v-lua.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- borrowed from scite
--
-- depricated:
--
-- gcinfo unpack getfenv setfenv loadlib
-- table.maxn table.getn table.setn
-- math.log10 math.mod math.modf math.fmod

local format, tohash = string.format, table.tohash
local P, S, V, patterns = lpeg.P, lpeg.S, lpeg.V, lpeg.patterns
local C, Cs, Cg, Cb, Cmt, Carg = lpeg.C, lpeg.Cs, lpeg.Cg, lpeg.Cb, lpeg.Cmt, lpeg.Carg

local core = tohash {
    "and", "break", "do", "else", "elseif", "end", "false", "for", "function",
    "if", "in", "local", "nil", "not", "or", "repeat", "return", "then",
    "true", "until", "while"
}

local base = tohash {
    "assert", "collectgarbage", "dofile", "error", "loadfile",
    "loadstring", "print", "rawget", "rawset", "require", "tonumber",
    "tostring", "type", "_G", "getmetatable", "ipairs", "next", "pairs",
    "pcall", "rawequal", "setmetatable", "xpcall", "module", "select",
}

local libraries = {
    coroutine = tohash {
        "create", "resume", "status", "wrap", "yield", "running",
    },
    package = tohash{
        "cpath", "loaded", "loadlib", "path", "config", "preload", "seeall",
    },
    io = tohash{
        "close", "flush", "input", "lines", "open", "output", "read", "tmpfile",
        "type", "write", "stdin", "stdout", "stderr", "popen",
    },
    math = tohash{
        "abs", "acos", "asin", "atan", "atan2", "ceil", "cos", "deg", "exp",
        "floor ", "ldexp", "log", "max", "min", "pi", "pow", "rad", "random",
        "randomseed", "sin", "sqrt", "tan", "cosh", "sinh", "tanh", "huge",
    },
    string = tohash{
        "byte", "char", "dump", "find", "len", "lower", "rep", "sub", "upper",
        "format", "gfind", "gsub", "gmatch", "match", "reverse",
    },
    table = tohash{
        "concat", "foreach", "foreachi", "sort", "insert", "remove", "pack",
        "unpack",
    },
    os = tohash{
        "clock", "date", "difftime", "execute", "exit", "getenv", "remove",
        "rename", "setlocale", "time", "tmpname",
    },
    lpeg = tohash{
        "print", "match", "locale", "type", "version", "setmaxstack",
        "P", "R", "S", "C", "V", "Cs", "Ct", "Cs", "Cp", "Carg",
        "Cg", "Cb", "Cmt", "Cf", "B",
    },
    -- bit
    -- debug
}

local context                 = context
local verbatim                = context.verbatim
local makepattern             = visualizers.makepattern

local LuaSnippet              = context.LuaSnippet
local startLuaSnippet         = context.startLuaSnippet
local stopLuaSnippet          = context.stopLuaSnippet

local LuaSnippetBoundary      = verbatim.LuaSnippetBoundary
local LuaSnippetSpecial       = verbatim.LuaSnippetSpecial
local LuaSnippetComment       = verbatim.LuaSnippetComment
local LuaSnippetNameCore      = verbatim.LuaSnippetNameCore
local LuaSnippetNameBase      = verbatim.LuaSnippetNameBase
local LuaSnippetNameLibraries = verbatim.LuaSnippetNameLibraries
local LuaSnippetName          = verbatim.LuaSnippetName

local namespace

local function visualizename_a(s)
    if core[s] then
        namespace = nil
        LuaSnippetNameCore(s)
    elseif base[s] then
        namespace = nil
        LuaSnippetNameBase(s)
    else
        namespace = libraries[s]
        if namespace then
            LuaSnippetNameLibraries(s)
        else
            LuaSnippetName(s)
        end
    end
end

local function visualizename_b(s)
    if namespace and namespace[s] then
        namespace = nil
        LuaSnippetNameLibraries(s)
    else
        LuaSnippetName(s)
    end
end

local function visualizename_c(s)
    LuaSnippetName(s)
end

local handler = visualizers.newhandler {
    startinline  = function() LuaSnippet(false,"{") end,
    stopinline   = function() context("}") end,
    startdisplay = function() startLuaSnippet() end,
    stopdisplay  = function() stopLuaSnippet() end ,
    boundary     = function(s) LuaSnippetBoundary(s) end,
    special      = function(s) LuaSnippetSpecial (s) end,
    comment      = function(s) LuaSnippetComment (s) end,
    period       = function(s) verbatim(s) end,
    name_a       = visualizename_a,
    name_b       = visualizename_b,
    name_c       = visualizename_c,
}

local space       = patterns.space
local anything    = patterns.anything
local newline     = patterns.newline
local emptyline   = patterns.emptyline
local beginline   = patterns.beginline
local somecontent = patterns.somecontent

local comment     = P("--")
local name        = (patterns.letter + patterns.underscore)
                  * (patterns.letter + patterns.underscore + patterns.digit)^0
local boundary    = S('()[]{}')
local special     = S("-+/*^%=#") + P("..")

-- The following longstring parser is taken from Roberto's documentation
-- that can be found at http://www.inf.puc-rio.br/~roberto/lpeg/lpeg.html.

local equals      = P("=")^0
local open        = P("[") * Cg(equals, "init") * P("[") * P("\n")^-1
local close       = P("]") * C(equals) * P("]")
local closeeq     = Cmt(close * Cb("init"), function(s,i,a,b) return a == b end)
local longstring  = open * Cs((P(1) - closeeq)^0) * close * Carg(1)

--~ local simple = P ( -- here we hook into the handler but it is default so we could use that
--~     makepattern(handler,"space",space)
--~   + makepattern(handler,"newline",newline)
--~   * makepattern(handler,"emptyline",emptyline)
--~   * makepattern(handler,"beginline",beginline)
--~   + makepattern(handler,"default",anything)
--~ )^0

local function long(content,equals,settings)
    handler.boundary(format("[%s[",equals or ""))
    visualizers.write(content,settings) -- unhandled
    handler.boundary(format("]%s]",equals or ""))
end

local grammar = visualizers.newgrammar("default", { "visualizer",
--~     emptyline =
--~         makepattern(handler,"emptyline",emptyline),
--~     beginline =
--~         makepattern(handler,"beginline",beginline),
--~     newline =
--~         makepattern(handler,"newline",newline),
--~     space =
--~         makepattern(handler,"space",space),
--~     default =
--~         makepattern(handler,"default",anything),
--~     line =
--~         V("newline") * V("emptyline")^0 * V("beginline"),
--~     whitespace =
--~         (V("space") + V("line"))^1,
--~     optionalwhitespace =
--~         (V("space") + V("line"))^0,
--~     content =
--~         makepattern(handler,"default",somecontent),

    sstring =
        makepattern(handler,"string",patterns.dquote)
      * (V("whitespace") + makepattern(handler,"default",1-patterns.dquote))^0
      * makepattern(handler,"string",patterns.dquote),
    dstring =
        makepattern(handler,"string",patterns.squote)
      * (V("whitespace") + makepattern(handler,"default",1-patterns.squote))^0
      * makepattern(handler,"string",patterns.squote),
    longstring =
        longstring / long,
    comment =
        makepattern(handler,"comment",comment)
      * (V("space") + V("content"))^0,
    longcomment =
        makepattern(handler,"comment",comment)
      * longstring / long,
    name =
        makepattern(handler,"name_a",name)
      * (   V("optionalwhitespace")
          * makepattern(handler,"default",patterns.period)
          * V("optionalwhitespace")
          * makepattern(handler,"name_b",name)
        )^-1
      * (   V("optionalwhitespace")
          * makepattern(handler,"default",patterns.period)
          * V("optionalwhitespace")
          * makepattern(handler,"name_c",name)
        )^0,

    pattern =
        V("longcomment")
      + V("comment")
      + V("longstring")
      + V("dstring")
      + V("sstring")
      + V("name")
      + makepattern(handler,"boundary",boundary)
      + makepattern(handler,"special",special)

      + V("space")
      + V("line")
      + V("default"),

    visualizer =
        V("pattern")^1
} )

local parser = P(grammar)

visualizers.register("lua", { parser = parser, handler = handler, grammar = grammar } )

-- filename : type-lua.lua
-- comment  : companion to core-buf.tex
-- author   : Hans Hagen, PRAGMA-ADE, Hasselt NL
-- copyright: PRAGMA ADE / ConTeXt Development Team
-- license  : see context related readme files

-- BROKEN : result is now table



if not buffers                 then buffers                 = { } end
if not buffers.visualizers     then buffers.visualizers     = { } end
if not buffers.visualizers.lua then buffers.visualizers.lua = { } end

buffers.visualizers.lua.identifiers = { }

-- borrowed from scite

buffers.visualizers.lua.identifiers.core = {
    "and", "break", "do", "else", "elseif", "end", "false", "for", "function",
    "if", "in", "local", "nil", "not", "or", "repeat", "return", "then",
    "true", "until", "while"
}

buffers.visualizers.lua.identifiers.base = {
    "assert", "collectgarbage", "dofile", "error", "gcinfo", "loadfile",
    "loadstring", "print", "rawget", "rawset", "require", "tonumber",
    "tostring", "type", "unpack",
}

buffers.visualizers.lua.identifiers.five = {
    "_G", "getfenv", "getmetatable", "ipairs", "loadlib", "next", "pairs",
    "pcall", "rawequal", "setfenv", "setmetatable", "xpcall", "string", "table",
    "math", "coroutine", "io", "os", "debug", "load", "module", "select"
}

buffers.visualizers.lua.identifiers.libs = {
    -- coroutine
    "coroutine.create", "coroutine.resume", "coroutine.status", "coroutine.wrap",
    "coroutine.yield", "coroutine.running",
    -- package
    "package.cpath", "package.loaded", "package.loadlib", "package.path",
    -- io
    "io.close", "io.flush", "io.input", "io.lines", "io.open", "io.output",
    "io.read", "io.tmpfile", "io.type", "io.write", "io.stdin", "io.stdout",
    "io.stderr", "io.popen",
    -- math
    "math.abs", "math.acos", "math.asin", "math.atan", "math.atan2", "math.ceil",
    "math.cos", "math.deg", "math.exp", "math.floor math.", "math.ldexp",
    "math.log", "math.log10", "math.max", "math.min math.mod math.pi", "math.pow",
    "math.rad", "math.random", "math.randomseed", "math.sin", "math.sqrt",
    "math.tan", "math.cosh", "math.fmod", "math.modf", "math.sinh", "math.tanh",
    "math.huge",
    -- string
    "string.byte", "string.char", "string.dump", "string.find", "string.len",
    "string.lower", "string.rep", "string.sub", "string.upper", "string.format",
    "string.gfind", "string.gsub", "string.gmatch", "string.match", "string.reverse",
    -- table
    "table.maxn", "table.concat", "table.foreach", "table.foreachi", "table.getn",
    "table.sort", "table.insert", "table.remove", "table.setn",
    -- os
    "os.clock", "os.date", "os.difftime", "os.execute", "os.exit", "os.getenv",
    "os.remove", "os.rename", "os.setlocale", "os.time", "os.tmpname",
    -- package
    "package.preload", "package.seeall"
}

buffers.visualizers.lua.words = { }

for k,v in pairs(buffers.visualizers.lua.identifiers) do
    for _,w in pairs(v) do
        buffers.visualizers.lua.words[w] = k
    end
end

buffers.visualizers.lua.styles = { }

buffers.visualizers.lua.styles.core = ""
buffers.visualizers.lua.styles.base = "\\sl "
buffers.visualizers.lua.styles.five = "\\sl "
buffers.visualizers.lua.styles.libs = "\\sl "

-- btex .. etex

buffers.visualizers.lua.colors = {
    "prettyone",
    "prettytwo",
    "prettythree",
    "prettyfour",
}

buffers.visualizers.lua.states = {
    ['1']=1, ['2']=1, ['3']=1, ['4']=1, ['5']=1, ['6']=1, ['7']=1, ['8']=1, ['9']=1, ['0']=1,
    ['--']=4,
    ['"']=3, ["'"]=3,
    ['+']=1, ['-']=1, ['*']=1, ['/']=1, ['%']=1, ['^']=1,
}

buffers.visualizers.lua.options = { }

buffers.visualizers.lua.options.colorize_strings  = false
buffers.visualizers.lua.options.colorize_comments = false

function buffers.flush_lua_word(state, word, result)
    if #word>0 then
        local id = buffers.visualizers.lua.words[word]
        if id then
            state, result = buffers.change_state(2, state, result)
            if buffers.visualizers.lua.styles[id] then
                state, result = buffers.finish_state(state,result .. buffers.visualizers.lua.styles[id] .. word)
            else
                state, result = buffers.finish_state(state,result .. word)
            end
            return state, result
        else
            state, result = buffers.finish_state(state,result)
            return state, result .. buffers.escaped(word) -- cmp mp
        end
    else
        state, result = buffers.finish_state(state,result)
        return state, result
    end
end

buffers.visualizers.lua.states.incomment = false

-- to be sped up

function buffers.visualizers.lua.flush_line(str, nested)
    local result, state = { }, 0
    local instr, inesc, incom = false, false, false
    local c, p
    local sb, ss, sf = string.byte, string.sub, string.find
    local code, comment
--~     buffers.currentcolors = buffers.visualizers.lua.colors
--~     if sf(str,"^%-%-%[") then
--~         buffers.visualizers.lua.states.incomment = true
--~         code, comment, incom = "", str, true
--~     elseif sf(str,"^%]%-%-") then
--~         buffers.visualizers.lua.states.incomment = false
--~         code, comment, incom = "", str, true
--~     elseif buffers.visualizers.lua.states.incomment then
--~         code, comment, incom = "", str, true
--~     else
--~         code, comment = string.match(str,"^(.-)%-%-(.*)$")
--~         if not code then
--~             code, comment = str, ""
--~         end
--~     end
--~     -- bla bla1 bla.bla
--~     for c in string.utfcharacters(code) do
--~         if instr then
--~             if c == s then
--~                 if inesc then
--~                     result = result .. "\\char" .. sb(c) .. " "
--~                     inesc = false
--~                 else
--~                     state, result = buffers.change_state(buffers.visualizers.lua.states[c], state, result)
--~                     instr = false
--~                     result = result .. "\\char" .. sb(c) .. " "
--~                     state, result = buffers.finish_state(state,result)
--~                 end
--~             elseif c == "\\" then
--~                 inesc = not inesc
--~                 result = result .. buffers.escaped_chr(c)
--~             else
--~                 inesc = false
--~                 result = result .. buffers.escaped_chr(c)
--~             end
--~         elseif sf(c,"^([\'\"])$") then
--~             s, instr = c, true
--~             state, result = buffers.change_state(buffers.visualizers.lua.states[c], state, result)
--~             result = result .. "\\char" .. sb(c) .. " "
--~             if not buffers.visualizers.lua.options.colorize_strings then
--~                 state, result = buffers.finish_state(state,result)
--~             end
--~         elseif c == " " then
--~             state, result = buffers.flush_lua_word(state, word, result)
--~             word = ""
--~             result =  result .. "\\obs "
--~         elseif sf(c,"^[%a]$") then
--~             state, result = buffers.finish_state(state,result)
--~             word = word .. c
--~         elseif (#word > 1) and sf(c,"^[%d%.%_]$") then
--~             word = word .. c
--~         else
--~             state, result = buffers.flush_lua_word(state, word, result)
--~             word = ""
--~             state, result = buffers.change_state(buffers.visualizers.lua.states[c], state, result)
--~             result = result .. "\\char" .. sb(c) .. " "
--~             instr = (c == '"')
--~         end
--~     end
--~     state, result = buffers.flush_lua_word(state, word, result)
--~     if comment ~= "" then
--~         state, result = buffers.change_state(buffers.visualizers.lua.states['--'], state, result)
--~         if not incom then
--~             result = result .. buffers.escaped("--")
--~         end
--~         if buffers.visualizers.lua.options.colorize_comments then
--~             state, result = buffers.finish_state(state,result)
--~             result = result .. buffers.escaped(comment)
--~         else
--~             result = result .. buffers.escaped(comment)
--~             state, result = buffers.finish_state(state,result)
--~         end
--~     else
--~         state, result = buffers.finish_state(state,result)
--~     end
--~     tex.sprint(tex.ctxcatcodes,result)
    return "not yet finished"
end

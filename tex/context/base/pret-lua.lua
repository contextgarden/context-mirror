if not modules then modules = { } end modules ['pret-lua'] = {
    version   = 1.001,
    comment   = "companion to buff-ver.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- this is not a real parser as we also want to typeset wrong output
-- and a real parser would choke on that

local utf = unicode.utf8

local utfcharacters, utfvalues = string.utfcharacters, string.utfvalues
local utfbyte, utffind = utf.byte, utf.find
local byte, sub, find, match = string.byte, string.sub, string.find, string.match
local texsprint, texwrite = tex.sprint, tex.write
local ctxcatcodes = tex.ctxcatcodes

local visualizer = buffers.newvisualizer("lua")

visualizer.identifiers = { }

-- borrowed from scite

visualizer.identifiers.core = {
    "and", "break", "do", "else", "elseif", "end", "false", "for", "function",
    "if", "in", "local", "nil", "not", "or", "repeat", "return", "then",
    "true", "until", "while"
}

visualizer.identifiers.base = {
    "assert", "collectgarbage", "dofile", "error", "gcinfo", "loadfile",
    "loadstring", "print", "rawget", "rawset", "require", "tonumber",
    "tostring", "type", "unpack",
}

visualizer.identifiers.five = {
    "_G", "getmetatable", "ipairs", "loadlib", "next", "pairs",
    "pcall", "rawequal", "setmetatable", "xpcall", "string", "table",
    "math", "coroutine", "io", "os", "debug", "load", "module", "select",
    -- depricated
    "getfenv", "setfenv",
}

visualizer.identifiers.libs = {
    -- coroutine
    "coroutine.create", "coroutine.resume", "coroutine.status", "coroutine.wrap",
    "coroutine.yield", "coroutine.running",
    -- package
    "package.cpath", "package.loaded", "package.loadlib", "package.path", "package.config",
    -- io
    "io.close", "io.flush", "io.input", "io.lines", "io.open", "io.output",
    "io.read", "io.tmpfile", "io.type", "io.write", "io.stdin", "io.stdout",
    "io.stderr", "io.popen",
    -- math
    "math.abs", "math.acos", "math.asin", "math.atan", "math.atan2", "math.ceil",
    "math.cos", "math.deg", "math.exp", "math.floor math.", "math.ldexp",
    "math.log", "math.max", "math.min", "math.mod", "math.pi", "math.pow",
    "math.rad", "math.random", "math.randomseed", "math.sin", "math.sqrt",
    "math.tan", "math.cosh", "math.fmod", "math.modf", "math.sinh", "math.tanh",
    "math.huge",
    -- string
    "string.byte", "string.char", "string.dump", "string.find", "string.len",
    "string.lower", "string.rep", "string.sub", "string.upper", "string.format",
    "string.gfind", "string.gsub", "string.gmatch", "string.match", "string.reverse",
    -- table
    "table.concat", "table.foreach", "table.foreachi", "table.getn",
    "table.sort", "table.insert", "table.remove", "table.setn",
    "table.pack", "table.unpack",
    -- os
    "os.clock", "os.date", "os.difftime", "os.execute", "os.exit", "os.getenv",
    "os.remove", "os.rename", "os.setlocale", "os.time", "os.tmpname",
    -- package
    "package.preload", "package.seeall",
    -- depricated
    "math.log10", "table.maxn",
}

local known_words = { }

for k,v in pairs(visualizer.identifiers) do
    for _,w in pairs(v) do
        known_words[w] = k
    end
end

visualizer.styles = {
    core = "",
    base = "\\sl ",
    five = "\\sl ",
    libs = "\\sl ",
}

local styles = visualizer.styles

local colors = {
    "prettyone",
    "prettytwo",
    "prettythree",
    "prettyfour",
}

local states = {
    ['"']=1, ["'"]=1, ["[["] = 1, ["]]"] = 1,
    ['+']=1, ['-']=1, ['*']=1, ['/']=1, ['%']=1, ['^']=1,
    ["("] = 3, [")"] = 3, ["["] = 3, ["]"] = 3,
    ['--']=4,
}

local change_state, finish_state = buffers.change_state, buffers.finish_state

local function flush_lua_word(state, word)
    if word then
        local id = known_words[word]
        if id then
            state = change_state(2,state)
            if styles[id] then
                texsprint(ctxcatcodes,styles[id])
            end
            texwrite(word)
            state = finish_state(state)
        else
            state = finish_state(state) -- ?
            texwrite(word)
        end
    else
        state = finish_state(state)
    end
    return state
end

local incomment, inlongstring = false, false

function visualizer.reset()
    incomment, inlongstring = false, false -- needs to be hooked into flusher
end

-- we will also provide a proper parser based pretty printer although normaly
-- a pretty printer should handle faulty code too (educational purposes)

local function written(state,c,i)
    if c == " " then
        state = finish_state(state)
        texsprint(ctxcatcodes,"\\obs")
    elseif c == "\t" then
        state = finish_state(state)
        texsprint(ctxcatcodes,"\\obs")
        if buffers.visualizers.enabletab then
            texsprint(ctxcatcodes,rep("\\obs ",i%buffers.visualizers.tablength))
        end
    else
        texwrite(c)
    end
    return state, 0
end

function visualizer.flush_line(str, nested)
    local state, instr, inesc, word = 0, false, false, nil
    buffers.currentcolors = colors
    local code, comment = match(str,"^(.-)%-%-%[%[(.*)$")
    if comment then
        -- process the code and then flush the comment
    elseif incomment then
        comment, code = match(str,"^(.-)%]%](.*)$")
        if comment then
            -- flush the comment and then process the code
            for c in utfcharacters(comment) do
                if c == " " then texsprint(ctxcatcodes,"\\obs") else texwrite(c) end
            end
            state = change_state(states['--'], state)
            texwrite("]]")
            state = finish_state(state)
            incomment = false
        else
            for c in utfcharacters(str) do
                if c == " " then texsprint(ctxcatcodes,"\\obs") else texwrite(c) end
            end
        end
        comment = nil
    else
        code = str
    end
    if code and code ~= "" then
        local pre, post = match(code,"^(.-)%-%-(.*)$")
        if pre then
            code = pre
        end
        local p, s, i = nil, nil, 0
        for c in utfcharacters(code) do
            i = i + 1
            if instr then
                if p then
                    texwrite(p)
                    p = nil
                end
                if c == s then
                    if inesc then
                        texwrite(c)
                        inesc = false
                    else
                        state = change_state(states[c],state)
                        instr = false
                        texwrite(c)
                        state = finish_state(state)
                    end
                    s = nil
                else
                    if c == "\\" then
                        inesc = not inesc
                    else
                        inesc = false
                    end
                    state, i = written(state,c,i)
                end
            elseif c == "[" then
                if word then
                    texwrite(word)
                    word = nil
                end
                if p == "[" then
                    inlongstring = true
                    state = change_state(states["[["],state)
                    texwrite(p,c)
                    state = finish_state(state)
                    p = nil
                else
                    if p then
                        state, i = written(state,p,i)
                    end
                    p = c
                end
            elseif c == "]" then
                if word then
                    texwrite(word)
                    word = nil
                end
                if p == "]" then
                    inlongstring = false
                    state = change_state(states["]]"],state)
                    texwrite(p,c)
                    state = finish_state(state)
                    p = nil
                else
                    if p then
                        state, i = written(state,p,i)
                    end
                    p = c
                end
            else
                if p then
                    state = change_state(states[p],state)
                    texwrite(p)
                    state = finish_state(state)
                    p = nil
                end
                if c == " " or c == "\t" then
                    if word then
                        state = flush_lua_word(state,word)
                        word = nil
                    end
                    state, i = written(state,c,i)
                elseif inlongstring then
                    state, i = written(state,c,i)
                elseif c == '"' or c == "'" then
                    instr = true
                    state = change_state(states[c],state)
                    state, i = written(state,c,i)
                    state = finish_state(state)
                    s = c
                elseif find(c,"^[%a]$") then
                    state = finish_state(state)
                    if word then word = word .. c else word = c end
                elseif word and (#word > 1) and find(c,"^[%d%.%_]$") then
                    if word then word = word .. c else word = c end
                else
                    state = flush_lua_word(state,word)
                    word = nil
                    state = change_state(states[c],state)
                    texwrite(c)
                    instr = (c == '"')
                end
            end
        end
        if p then
            texwrite(p)
            -- state, i = written(state,p,i)
            p = nil
        end
        state = flush_lua_word(state,word)
        if post then
            state = change_state(states['--'], state)
            texwrite("--")
            state = finish_state(state)
            for c in utfcharacters(post) do
                state, i = written(state,c,i)
            end
        end
    end
    if comment then
        incomment = true
        state = change_state(states['--'], state)
        texwrite("[[")
        state = finish_state(state)
     -- texwrite(comment) -- maybe also split and
        for c in utfcharacters(comment) do
            state, i = written(state,c,i)
        end
    end
    state = finish_state(state)
end

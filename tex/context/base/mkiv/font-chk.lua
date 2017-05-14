if not modules then modules = { } end modules ['font-chk'] = {
    version   = 1.001,
    comment   = "companion to font-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- possible optimization: delayed initialization of vectors
-- move to the nodes namespace

local next = next

local formatters           = string.formatters
local bpfactor             = number.dimenfactors.bp
local fastcopy             = table.fastcopy

local report_fonts         = logs.reporter("fonts","checking") -- replace

local allocate             = utilities.storage.allocate

local fonts                = fonts

fonts.checkers             = fonts.checkers or { }
local checkers             = fonts.checkers

local fonthashes           = fonts.hashes
local fontdata             = fonthashes.identifiers
local fontcharacters       = fonthashes.characters

local helpers              = fonts.helpers

local addprivate           = helpers.addprivate
local hasprivate           = helpers.hasprivate
local getprivateslot       = helpers.getprivateslot
local getprivatecharornode = helpers.getprivatecharornode

local otffeatures          = fonts.constructors.features.otf
local afmfeatures          = fonts.constructors.features.afm

local registerotffeature   = otffeatures.register
local registerafmfeature   = afmfeatures.register

local is_character         = characters.is_character
local chardata             = characters.data

local tasks                = nodes.tasks
local enableaction         = tasks.enableaction
local disableaction        = tasks.disableaction

local implement            = interfaces.implement

local glyph_code           = nodes.nodecodes.glyph

local new_special          = nodes.pool.special
local hpack_node           = node.hpack

local nuts                 = nodes.nuts
local tonut                = nuts.tonut
local tonode               = nuts.tonode

local getfont              = nuts.getfont
local getchar              = nuts.getchar

local setfield             = nuts.setfield
local setchar              = nuts.setchar

local traverse_id          = nuts.traverse_id
local remove_node          = nuts.remove
local insert_node_after    = nuts.insert_after

-- maybe in fonts namespace
-- deletion can be option

local action = false

-- to tfmdata.properties ?

local function onetimemessage(font,char,message) -- char == false returns table
    local tfmdata = fontdata[font]
    local shared = tfmdata.shared
    local messages = shared.messages
    if not messages then
        messages = { }
        shared.messages = messages
    end
    local category = messages[message]
    if not category then
        category = { }
        messages[message] = category
    end
    if char == false then
        return table.sortedkeys(category)
    elseif not category[char] then
        report_fonts("char %C in font %a with id %a: %s",char,tfmdata.properties.fullname,font,message)
        category[char] = true
    end
end

fonts.loggers.onetimemessage = onetimemessage

local mapping = allocate { -- this is just an experiment to illustrate some principles elsewhere
    lu = "placeholder uppercase red",
    ll = "placeholder lowercase red",
    lt = "placeholder uppercase red",
    lm = "placeholder lowercase red",
    lo = "placeholder lowercase red",
    mn = "placeholder mark green",
    mc = "placeholder mark green",
    me = "placeholder mark green",
    nd = "placeholder lowercase blue",
    nl = "placeholder lowercase blue",
    no = "placeholder lowercase blue",
    pc = "placeholder punctuation cyan",
    pd = "placeholder punctuation cyan",
    ps = "placeholder punctuation cyan",
    pe = "placeholder punctuation cyan",
    pi = "placeholder punctuation cyan",
    pf = "placeholder punctuation cyan",
    po = "placeholder punctuation cyan",
    sm = "placeholder lowercase magenta",
    sc = "placeholder lowercase yellow",
    sk = "placeholder lowercase yellow",
    so = "placeholder lowercase yellow",
}

table.setmetatableindex(mapping,
    function(t,k)
        v = "placeholder unknown gray"
        t[k] = v
        return v
    end
)

local fakes = allocate {
    {
        name   = "lowercase",
        code   = ".025 -.175 m .425 -.175 l .425 .525 l .025 .525 l .025 -.175 l .025 0 l .425 0 l .025 -.175 m h S",
        width  = .45,
        height = .55,
        depth  = .20,
    },
    {
        name   = "uppercase",
        code   = ".025 -.225 m .625 -.225 l .625 .675 l .025 .675 l .025 -.225 l .025 0 l .625 0 l .025 -.225 m h S",
        width  = .65,
        height = .70,
        depth  = .25,
    },
    {
        name   = "mark",
        code   = ".025  .475 m .125  .475 l .125 .675 l .025 .675 l .025  .475 l h B",
        width  = .15,
        height = .70,
        depth  = -.50,
    },
    {
        name   = "punctuation",
        code   = ".025 -.175 m .125 -.175 l .125 .525 l .025 .525 l .025 -.175 l h B",
        width  = .15,
        height = .55,
        depth  = .20,
    },
    {
        name   = "unknown",
        code   = ".025 0 m .425 0 l .425 .175 l .025 .175 l .025 0 l h B",
        width  = .45,
        height = .20,
        depth  = 0,
    },
}

local variants = allocate {
    { tag = "gray",    r = .6, g = .6, b = .6 },
    { tag = "red",     r = .6, g =  0, b =  0 },
    { tag = "green",   r =  0, g = .6, b =  0 },
    { tag = "blue",    r =  0, g =  0, b = .6 },
    { tag = "cyan",    r =  0, g = .6, b = .6 },
    { tag = "magenta", r = .6, g =  0, b = .6 },
    { tag = "yellow",  r = .6, g = .6, b =  0 },
}

local pdf_blob = "pdf: q %0.6F 0 0 %0.6F 0 0 cm %s %s %s rg %s %s %s RG 10 M 1 j 1 J 0.05 w %s Q"

local cache = { } -- saves some tables but not that impressive

local function missingtonode(tfmdata,character)
    local commands  = character.commands
    local fake  = hpack_node(new_special(commands[1][2]))
    fake.width  = character.width
    fake.height = character.height
    fake.depth  = character.depth
    return fake
end

local function addmissingsymbols(tfmdata) -- we can have an alternative with rules
    local characters = tfmdata.characters
    local properties = tfmdata.properties
    local size       = tfmdata.parameters.size
    local scale      = size * bpfactor
    local tonode     = properties.finalized and missingtonode or nil
    for i=1,#variants do
        local v = variants[i]
        local tag, r, g, b = v.tag, v.r, v.g, v.b
        for i =1, #fakes do
            local fake = fakes[i]
            local name = fake.name
            local privatename = formatters["placeholder %s %s"](name,tag)
            if not hasprivate(tfmdata,privatename) then
                local hash = formatters["%s_%s_%s_%s_%s_%s"](name,tag,r,g,b,size)
                local char = cache[hash]
                if not char then
                    char = {
                        tonode   = tonode,
                        width    = size*fake.width,
                        height   = size*fake.height,
                        depth    = size*fake.depth,
                        -- bah .. low level pdf ... should be a rule or plugged in
                        commands = { { "special", formatters[pdf_blob](scale,scale,r,g,b,r,g,b,fake.code) } }
                    }
                    cache[hash] = char
                end
                addprivate(tfmdata, privatename, char)
            end
        end
    end
end

registerotffeature {
    name        = "missing",
    description = "missing symbols",
    manipulators = {
        base = addmissingsymbols,
        node = addmissingsymbols,
    }
}

fonts.loggers.add_placeholders        = function(id) addmissingsymbols(fontdata[id or true]) end
fonts.loggers.category_to_placeholder = mapping

function commands.getplaceholderchar(name)
    local id = font.current()
    addmissingsymbols(fontdata[id])
    context(getprivatenode(fontdata[id],name))
end

-- todo in luatex: option to add characters (just slots, no kerns etc)

local function placeholder(font,char)
    local tfmdata  = fontdata[font]
    local category = chardata[char].category
    local fakechar = mapping[category]
    local slot = getprivateslot(font,fakechar)
    if not slot then
        addmissingsymbols(tfmdata)
        slot = getprivateslot(font,fakechar)
    end
    return getprivatecharornode(tfmdata,fakechar)
end

checkers.placeholder = placeholder

function checkers.missing(head)
    local lastfont, characters, found = nil, nil, nil
    head = tonut(head)
    for n in traverse_id(glyph_code,head) do -- faster than while loop so we delay removal
        local font = getfont(n)
        local char = getchar(n)
        if font ~= lastfont then
            characters = fontcharacters[font]
            lastfont = font
        end
        if not characters[char] and is_character[chardata[char].category] then
            if action == "remove" then
                onetimemessage(font,char,"missing (will be deleted)")
            elseif action == "replace" then
                onetimemessage(font,char,"missing (will be flagged)")
            else
                onetimemessage(font,char,"missing")
            end
            if not found then
                found = { n }
            else
                found[#found+1] = n
            end
        end
    end
    if not found then
        -- all well
    elseif action == "remove" then
        for i=1,#found do
            head = remove_node(head,found[i],true)
        end
    elseif action == "replace" then
        for i=1,#found do
            local node = found[i]
            local kind, char = placeholder(getfont(node),getchar(node))
            if kind == "node" then
                insert_node_after(head,node,tonut(char))
                head = remove_node(head,node,true)
            elseif kind == "char" then
                setchar(node,char)
            else
                -- error
            end
        end
    else
        -- maye write a report to the log
    end
    return tonode(head), false
end

local relevant = {
    "missing (will be deleted)",
    "missing (will be flagged)",
    "missing"
}

local function getmissing(id)
    if id then
        local list = getmissing(font.current())
        if list then
            local _, list = next(getmissing(font.current()))
            return list
        else
            return { }
        end
    else
        local t = { }
        for id, d in next, fontdata do
            local shared = d.shared
            local messages = shared.messages
            if messages then
                local tf = t[d.properties.filename] or { }
                for i=1,#relevant do
                    local tm = messages[relevant[i]]
                    if tm then
                        tf = table.merged(tf,tm)
                    end
                end
                if next(tf) then
                    t[d.properties.filename] = tf
                end
            end
        end
        for k, v in next, t do
            t[k] = table.sortedkeys(v)
        end
        return t
    end
end

checkers.getmissing = getmissing

local tracked = false

trackers.register("fonts.missing", function(v)
    if v then
        enableaction("processors","fonts.checkers.missing")
        tracked = true
    else
        disableaction("processors","fonts.checkers.missing")
    end
    if v == "replace" then
        otffeatures.defaults.missing = true
    end
    action = v
end)

local report_characters = logs.reporter("fonts","characters")
local report_character  = logs.reporter("missing")

local logsnewline       = logs.newline
local logspushtarget    = logs.pushtarget
local logspoptarget     = logs.poptarget

luatex.registerstopactions(function()
    if tracked then
        local collected = checkers.getmissing()
        if next(collected) then
            logspushtarget("logfile")
            for filename, list in table.sortedhash(collected) do
                logsnewline()
                report_characters("start missing characters: %s",filename)
                logsnewline()
                for i=1,#list do
                    local u = list[i]
                    report_character("%U  %c  %s",u,u,chardata[u].description)
                end
                logsnewline()
                report_characters("stop missing characters")
                logsnewline()
            end
            logspoptarget()
        end
    end
end)

-- for the moment here

local function expandglyph(characters,index,done)
    done = done or { }
    if not done[index] then
        local data = characters[index]
        if data then
            done[index] = true
            local d = fastcopy(data)
            local n = d.next
            if n then
                d.next = expandglyph(characters,n,done)
            end
            local h = d.horiz_variants
            if h then
                for i=1,#h do
                    h[i].glyph = expandglyph(characters,h[i].glyph,done)
                end
            end
            local v = d.vert_variants
            if v then
                for i=1,#v do
                    v[i].glyph = expandglyph(characters,v[i].glyph,done)
                end
            end
            return d
        end
    end
end

helpers.expandglyph = expandglyph

-- should not be needed as we add .notdef in the engine

local dummyzero = {
 -- width    = 0,
 -- height   = 0,
 -- depth    = 0,
    commands = { { "special", "" } },
}

local function adddummysymbols(tfmdata)
    local characters = tfmdata.characters
    if not characters[0] then
        characters[0] = dummyzero
    end
 -- if not characters[1] then
 --     characters[1] = dummyzero -- test only
 -- end
end

local dummies_specification = {
    name        = "dummies",
    description = "dummy symbols",
    default     = true,
    manipulators = {
        base = adddummysymbols,
        node = adddummysymbols,
    }
}

registerotffeature(dummies_specification)
registerafmfeature(dummies_specification)

-- callback.register("char_exists",function(f,c) -- to slow anyway as called often so we should flag in tfmdata
--     return true
-- end)

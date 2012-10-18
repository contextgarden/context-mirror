if not modules then modules = { } end modules ['font-chk'] = {
    version   = 1.001,
    comment   = "companion to font-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- possible optimization: delayed initialization of vectors
-- move to the nodes namespace

local format             = string.format
local bpfactor           = number.dimenfactors.bp

local report_fonts       = logs.reporter("fonts","checking")

local fonts              = fonts

fonts.checkers           = fonts.checkers or { }
local checkers           = fonts.checkers

local fonthashes         = fonts.hashes
local fontdata           = fonthashes.identifiers
local fontcharacters     = fonthashes.characters

local addprivate         = fonts.helpers.addprivate
local hasprivate         = fonts.helpers.hasprivate
local getprivatenode     = fonts.helpers.getprivatenode

local otffeatures        = fonts.constructors.newfeatures("otf")
local registerotffeature = otffeatures.register

local is_character       = characters.is_character
local chardata           = characters.data

local tasks              = nodes.tasks
local enableaction       = tasks.enableaction
local disableaction      = tasks.disableaction

local glyph_code         = nodes.nodecodes.glyph
local traverse_id        = node.traverse_id
local remove_node        = nodes.remove
local insert_node_after  = node.insert_after

-- maybe in fonts namespace
-- deletion can be option

local action = false

-- to tfmdata.properties ?

local function onetimemessage(font,char,message)
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
    if not category[char] then
        report_fonts("char U+%05X in font '%s' with id %s: %s",char,tfmdata.properties.fullname,font,message)
        category[char] = true
    end
end

fonts.loggers.onetimemessage = onetimemessage

local mapping = { -- this is just an experiment to illustrate some principles elsewhere
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

table.setmetatableindex(mapping,function(t,k) v = "placeholder unknown gray" t[k] = v return v end)

local fakes = {
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

local variants = {
    { tag = "gray",    r = .6, g = .6, b = .6 },
    { tag = "red",     r = .6, g =  0, b =  0 },
    { tag = "green",   r =  0, g = .6, b =  0 },
    { tag = "blue",    r =  0, g =  0, b = .6 },
    { tag = "cyan",    r =  0, g = .6, b = .6 },
    { tag = "magenta", r = .6, g =  0, b = .6 },
    { tag = "yellow",  r = .6, g = .6, b =  0 },
}

local package = "q %0.6f 0 0 %0.6f 0 0 cm %s %s %s rg %s %s %s RG 10 M 1 j 1 J 0.05 w %s Q"

local cache = { } -- saves some tables but not that impressive

local function addmissingsymbols(tfmdata)
    local characters = tfmdata.characters
    local size       = tfmdata.parameters.size
    local privates   = tfmdata.properties.privates
    local scale      = size * bpfactor
    for i=1,#variants do
        local v = variants[i]
        local tag, r, g, b = v.tag, v.r, v.g, v.b
        for i =1, #fakes do
            local fake = fakes[i]
            local name = fake.name
            local privatename = format("placeholder %s %s",name,tag)
            if not hasprivate(tfmdata,privatename) then
                local hash = format("%s_%s_%s_%s_%s_%s",name,tag,r,g,b,size)
                local char = cache[hash]
                if not char then
                    char = {
                        width    = size*fake.width,
                        height   = size*fake.height,
                        depth    = size*fake.depth,
                        commands = { { "special", "pdf: " .. format(package,scale,scale,r,g,b,r,g,b,fake.code) } }
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

fonts.loggers.category_to_placeholder = mapping

function checkers.missing(head)
    local lastfont, characters, found = nil, nil, nil
    for n in traverse_id(glyph_code,head) do -- faster than while loop so we delay removal
        local font = n.font
        local char = n.char
        if font ~= lastfont then
            characters = fontcharacters[font]
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
            local n = found[i]
            local font = n.font
            local char = n.char
            local tfmdata = fontdata[font]
            local properties = tfmdata.properties
            local privates = properties.privates
            local category = chardata[char].category
            local fakechar = mapping[category]
            local p = privates and privates[fakechar]
            if not p then
                addmissingsymbols(tfmdata)
                p = properties.privates[fakechar]
            end
            if properties.lateprivates then -- .frozen
                -- bad, we don't have them at the tex end
                local fake = getprivatenode(tfmdata,fakechar)
                insert_node_after(head,n,fake)
                head = remove_node(head,n,true)
            else
                -- good, we have \definefontfeature[default][default][missing=yes]
                n.char = p
            end
        end
    else
        -- maye write a report to the log
    end
    return head, false
end

trackers.register("fonts.missing", function(v)
    if v then
        enableaction("processors","fonts.checkers.missing")
    else
        disableaction("processors","fonts.checkers.missing")
    end
    if v == "replace" then
        otffeatures.defaults.missing = true
    end
    action = v
end)

function commands.checkcharactersinfont()
    enableaction("processors","fonts.checkers.missing")
end

function commands.removemissingcharacters()
    enableaction("processors","fonts.checkers.missing")
    action = "remove"
end

function commands.replacemissingcharacters()
    enableaction("processors","fonts.checkers.missing")
    action = "replace"
    otffeatures.defaults.missing = true
end

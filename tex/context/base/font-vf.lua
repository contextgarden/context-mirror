if not modules then modules = { } end modules ['font-vf'] = {
    version   = 1.001,
    comment   = "companion to font-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

--[[ldx--
<p>This is very experimental code! Not yet adapted to recent
changes. This will change.</p>
--ldx]]--

local next = next
local fastcopy = table.fastcopy

local allocate = utilities.storage.allocate

local fonts = fonts
local vf    = fonts.vf
local tfm   = fonts.tfm

fonts.definers   = fonts.definers or { }
local definers   = fonts.definers

definers.methods = definers.methods or { }
local methods    = definers.methods

methods.variants = allocate()
local variants   = methods.variants

vf.combinations = vf.combinations or { }
vf.aux          = vf.aux          or { }
vf.aux.combine  = vf.aux.combine  or { }
local combine   = vf.aux.combine

function methods.install(tag, rules)
    vf.combinations[tag] = rules
    variants[tag] = function(specification)
        return vf.combine(specification,tag)
    end
end

local function combine_load(g,name)
    return tfm.readanddefine(name or g.specification.name,g.specification.size)
end

local function combine_assign(g, name, from, to, start, force)
    local f, id = combine_load(g,name)
    if f and id then
        -- optimize for whole range, then just g = f
        if not from  then from, to = 0, 0xFF00 end
        if not to    then to       = from      end
        if not start then start    = from      end
        local fc, gc = f.characters, g.characters
        local fd, gd = f.descriptions, g.descriptions
        local hn = #g.fonts+1
        g.fonts[hn] = { id = id } -- no need to be sparse
        for i=from,to do
            if fc[i] and (force or not gc[i]) then
                gc[i] = fastcopy(fc[i]) -- can be optimized
                gc[i].commands = { { 'slot', hn, start } }
                gd[i] = fd[i]
            end
            start = start + 1
        end
        if not g.parameters and #g.fonts > 0 then -- share this code !
            g.parameters  = fastcopy(f.parameters)
            g.italicangle = f.italicangle
            g.ascender    = f.ascender
            g.descender   = f.descender
            g.factor      = f.factor -- brrr
        end
    end
end

local function combine_process(g,list)
    if list then
        for _,v in next, list do
            (combine.commands[v[1]] or nop)(g,v)
        end
    end
end

local function combine_names(g,name,force)
    local f, id = tfm.readanddefine(name,g.specification.size)
    if f and id then
        local fc, gc = f.characters, g.characters
        local fd, gd = f.descriptions, g.descriptions
        g.fonts[#g.fonts+1] = { id = id } -- no need to be sparse
        local hn = #g.fonts
        for k, v in next, fc do
            if force or not gc[k] then
                gc[k] = fastcopy(v)
                gc[k].commands = { { 'slot', hn, k } }
                gd[i] = fd[i]
            end
        end
        if not g.parameters and #g.fonts > 0 then -- share this code !
            g.parameters  = fastcopy(f.parameters)
            g.italicangle = f.italicangle
            g.ascender    = f.ascender
            g.descender   = f.descender
            g.factor      = f.factor -- brrr
        end
    end
end

local combine_feature = function(g,v)
    local key, value = v[2], v[3]
    if key then
        if value == nil then
            value = true
        end
        local specification = g.specification
        if specification then
            local normalfeatures = specification.features.normal
            if normalfeatures then
                normalfeatures[key] = value -- otf?
            end
        end
    end
end

--~ combine.load    = combine_load
--~ combine.assign  = combine_assign
--~ combine.process = combine_process
--~ combine.names   = combine_names
--~ combine.feature = combine_feature

combine.commands = allocate {
    ["initialize"]      = function(g,v) combine_assign    (g,g.name) end,
    ["include-method"]  = function(g,v) combine_process   (g,vf.combinations[v[2]])  end, -- name
 -- ["copy-parameters"] = function(g,v) combine_parameters(g,v[2]) end, -- name
    ["copy-range"]      = function(g,v) combine_assign    (g,v[2],v[3],v[4],v[5],true) end, -- name, from-start, from-end, to-start
    ["copy-char"]       = function(g,v) combine_assign    (g,v[2],v[3],v[3],v[4],true) end, -- name, from, to
    ["fallback-range"]  = function(g,v) combine_assign    (g,v[2],v[3],v[4],v[5],false) end, -- name, from-start, from-end, to-start
    ["fallback-char"]   = function(g,v) combine_assign    (g,v[2],v[3],v[3],v[4],false) end, -- name, from, to
    ["copy-names"]      = function(g,v) combine_names     (g,v[2],true) end,
    ["fallback_names"]  = function(g,v) combine_names     (g,v[2],false) end,
    ["feature"]         =               combine_feature,
}

function vf.combine(specification,tag)
    local g = {
        name          = specification.name,
    --  type          = 'virtual',
        virtualized   = true,
        fonts         = { },
        characters    = { },
        descriptions  = { },
        specification = fastcopy(specification),
    }
    combine_process(g,vf.combinations[tag])
    return g
end

-- simple example with features

methods.install(
    "ligatures", {
        { "feature", "liga" } ,
        { "feature", "dlig" } ,
        { "initialize" } ,
    }
)

--~ methods.install (
--~     "ligatures-x", {
--~         { "feature", "liga" } ,
--~         { "feature", "dlig" } ,
--~         { "initialize" } ,
--~         { "lineheight" }
--~     }
--~ )

--~ methods.install(
--~     "lmsymbol10", {
--~         { "fallback_names", "lmsy10.afm" } ,
--~         { "fallback_names", "msam10.afm" } ,
--~         { "fallback_names", "msbm10.afm" }
--~     }
--~ )
--~ \font\TestFont=dummy@lmsymbol10 at 24pt

-- docu case

--~ methods.install(
--~     "weird", {
--~         { "copy-range", "lmroman10-regular" } ,
--~         { "copy-char", "lmroman10-regular", 65, 66 } ,
--~         { "copy-range", "lmsans10-regular", 0x0100, 0x01FF } ,
--~         { "copy-range", "lmtypewriter10-regular", 0x0200, 0xFF00 } ,
--~         { "fallback-range", "lmtypewriter10-regular", 0x0000, 0x0200 }
--~     }
--~ )

-- demo case -> move to module

-- todo: interface tables in back-ini

variants["demo-1"] = function(specification)
    local name = specification.name          -- symbolic name
    local size = specification.size          -- given size
    local f, id = tfm.readanddefine('lmroman10-regular',size)
    if f and id then
        local capscale, digscale = 0.85, 0.75
    --  f.name, f.type = name, 'virtual'
        f.name, f.virtualized = name, true
        f.fonts = {
            { id = id },
            { name = 'lmsans10-regular'      , size = size*capscale }, -- forced extra name
            { name = 'lmtypewriter10-regular', size = size*digscale }  -- forced extra name
        }
        local i_is_of_category = characters.i_is_of_category
        local characters, descriptions = f.characters, f.descriptions
        local vfspecials = backends.tables.vfspecials
        local red, green, blue, black = vfspecials.red, vfspecials.green, vfspecials.blue, vfspecials.black
        for u,v in next, characters do
            if u and i_is_of_category(u,'lu') then
                v.width = capscale*v.width
                v.commands = { red, { 'slot', 2, u }, black }
            elseif u and i_is_of_category(u,'nd') then
                v.width = digscale*v.width
                v.commands = { blue, { 'slot', 3, u }, black }
            else
                v.commands = { green, { 'slot', 1, u }, black }
            end
        end
    end
    return f
end

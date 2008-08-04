if not modules then modules = { } end modules ['font-vf'] = {
    version   = 1.001,
    comment   = "companion to font-ini.tex",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

--[[ldx--
<p>This is very experimental code! Not yet adapted to recent
changes. This will change.</p>
--ldx]]--

-- define.methods elsewhere !

fonts    = fonts    or { }
fonts.vf = fonts.vf or { }

local vf  = fonts.vf
local tfm = fonts.tfm

fonts.define          = fonts.define          or { }
fonts.define.methods  = fonts.define.methods  or { }

vf.combinations = vf.combinations or { }
vf.aux          = vf.aux          or { }
vf.aux.combine  = vf.aux.combine  or { }

function fonts.define.methods.install(tag, rules)
    vf.combinations[tag] = rules
    fonts.define.methods[tag] = function(specification)
        return vf.combine(specification,tag)
    end
end

function vf.aux.combine.assign(g, name, from, to, start, force)
    local f, id = vf.aux.combine.load(g,name)
    if f and id then
        -- optimize for whole range, then just g = f
        if not from  then from, to = 0, 0xFF00 end
        if not to    then to       = from      end
        if not start then start    = from      end
        local fc, gc = f.characters, g.characters
        g.fonts[#g.fonts+1] = { id = id } -- no need to be sparse
        local hn = #g.fonts
        for i=from,to do
            if fc[i] and (force or not gc[i]) then
                gc[i] = table.fastcopy(fc[i])
                gc[i].commands = { { 'slot', hn, start } }
            end
            start = start + 1
        end
        if not g.parameters and #g.fonts > 0 then -- share this code !
            g.parameters  = table.fastcopy(f.parameters)
            g.italicangle = f.italicangle
            g.ascender    = f.ascender
            g.descender   = f.descender
        end
    end
end

function vf.aux.combine.process(g,list)
    if list then
        for _,v in pairs(list) do
            (vf.aux.combine.commands[v[1]] or nop)(g,v)
        end
    end
end

function vf.aux.combine.load(g,name)
    return tfm.read_and_define(name or g.specification.name,g.specification.size)
end

function vf.aux.combine.names(g,name,force)
    local f, id = tfm.read_and_define(name,g.specification.size)
    if f and id then
        local fc, gc = f.characters, g.characters
        g.fonts[#g.fonts+1] = { id = id } -- no need to be sparse
        local hn = #g.fonts
        for k, v in pairs(fc) do
            if force or not gc[k] then
                gc[k] = table.fastcopy(v)
                gc[k].commands = { { 'slot', hn, k } }
            end
        end
        if not g.parameters and #g.fonts > 0 then -- share this code !
            g.parameters  = table.fastcopy(f.parameters)
            g.italicangle = f.italicangle
            g.ascender    = f.ascender
            g.descender   = f.descender
        end
    end
end

vf.aux.combine.commands = {
    ["initialize"]      = function(g,v) vf.aux.combine.assign    (g,g.name) end,
    ["include-method"]  = function(g,v) vf.aux.combine.process   (g,vf.combinations[v[2]])  end, -- name
    ["copy-parameters"] = function(g,v) vf.aux.combine.parameters(g,v[2]) end, -- name
    ["copy-range"]      = function(g,v) vf.aux.combine.assign    (g,v[2],v[3],v[4],v[5],true) end, -- name, from-start, from-end, to-start
    ["copy-char"]       = function(g,v) vf.aux.combine.assign    (g,v[2],v[3],v[3],v[4],true) end, -- name, from, to
    ["fallback-range"]  = function(g,v) vf.aux.combine.assign    (g,v[2],v[3],v[4],v[5],false) end, -- name, from-start, from-end, to-start
    ["fallback-char"]   = function(g,v) vf.aux.combine.assign    (g,v[2],v[3],v[3],v[4],false) end, -- name, from, to
    ["copy_names"]      = function(g,v) vf.aux.combine.names     (g,v[2],true) end,
    ["fallback_names"]  = function(g,v) vf.aux.combine.names     (g,v[2],false) end,
}

function vf.combine(specification,tag)
    local g = {
        name = specification.name,
        type = 'virtual',
        fonts = { },
        characters = { },
        specification = table.fastcopy(specification)
    }
    vf.aux.combine.process(g,vf.combinations[tag])
    return g
end

vf.aux.combine.commands["feature"] = function(g,v)
    local key, value = v[2], v[3]
    if key then
        if value == nil then
            value = true
        end
        if g.specification and g.specification.features.normal then
            g.specification.features.normal[key] = value -- otf?
        end
    end
end

-- simple example with features

fonts.define.methods.install(
    "ligatures", {
        { "feature", "liga" } ,
        { "feature", "dlig" } ,
        { "initialize" } ,
    }
)

--~ fonts.define.methods.install (
--~     "ligatures-x", {
--~         { "feature", "liga" } ,
--~         { "feature", "dlig" } ,
--~         { "initialize" } ,
--~         { "lineheight" }
--~     }
--~ )

--~ fonts.define.methods.install(
--~     "lmsymbol10", {
--~         { "fallback_names", "lmsy10.afm" } ,
--~         { "fallback_names", "msam10.afm" } ,
--~         { "fallback_names", "msbm10.afm" }
--~     }
--~ )
--~ \font\TestFont=dummy@lmsymbol10 at 24pt

-- docu case

--~ fonts.define.methods.install(
--~     "weird", {
--~         { "copy-range", "lmroman10-regular" } ,
--~         { "copy-char", "lmroman10-regular", 65, 66 } ,
--~         { "copy-range", "lmsans10-regular", 0x0100, 0x01FF } ,
--~         { "copy-range", "lmtypewriter10-regular", 0x0200, 0xFF00 } ,
--~         { "fallback-range", "lmtypewriter10-regular", 0x0000, 0x0200 }
--~     }
--~ )

-- demo case -> move to module

fonts.define.methods["demo-1"] = function(specification)
    local name = specification.name          -- symbolic name
    local size = specification.size          -- given size
--~     specification.name = 'lmroman10-regular' -- forced base name
--~     specification.features.vtf = { }
    local f, id = tfm.read_and_define('lmroman10-regular',size)
    if f and id then
        local capscale, digscale = 0.85, 0.75
        f.name, f.type = name, 'virtual'
        f.fonts = {
            {id=id},
            {name='lmsans10-regular'      , size=size*capscale}, -- forced extra name
            {name='lmtypewriter10-regular', size=size*digscale}  -- forced extra name
        }
        for k,v in pairs(f.characters) do
            local u = v.unicode
            if u and characters.i_is_of_category(u,'lu') then
                v.width = capscale*v.width
                v.commands = {
                    {'special','pdf: 1 0 0 rg'},
                    {'slot',2, k},
                    {'special','pdf: 0 g'},
                }
            elseif u and characters.i_is_of_category(u,'nd') then
                v.width  = digscale*v.width
                v.commands = {
                    {'special','pdf: 0 0 1 rg'},
                    {'slot',3,k},
                    {'special','pdf: 0 g'},
                }
            else
                v.commands = {
                    {'special','pdf: 0 1 0 rg'},
                    {'slot',1,k},
                    {'special','pdf: 0 g'},
                }
            end
        end
    end
    return f
end

-- keep as example, now tfm feature

--~ vf.aux.combine.commands["lineheight"] = function(g,v)
--~     if g.ascender and g.descender then
--~         local ht, dp = g.ascender or 0, g.descender or 0
--~         if v[2] == "none" then
--~             for _,v in pairs(g.characters) do
--~                 v.height = 0
--~                 v.depth  = 0
--~             end
--~         else
--~             if v[2] == "height" then
--~                 dp = 0
--~             elseif v[2] == "depth" then
--~                 ht = 0
--~             end
--~             if ht > 0 then
--~                 if dp > 0 then
--~                     for _,v in pairs(g.characters) do
--~                         v.height = ht
--~                         v.depth  = dp
--~                     end
--~                 else
--~                     for _,v in pairs(g.characters) do
--~                         v.height = ht
--~                     end
--~                 end
--~             elseif dp > 0 then
--~                 for _,v in pairs(g.characters) do
--~                     v.depth  = dp
--~                 end
--~             end
--~         end
--~     end
--~ end

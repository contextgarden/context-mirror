if not modules then modules = { } end modules ['meta-fnt'] = {
    version   = 1.001,
    comment   = "companion to meta-fnt.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local concat     = table.concat
local format     = string.format
local formatters = string.formatters
local chardata   = characters.data
local fontdata   = fonts.hashes.identifiers

local vffonts    = fonts.handlers.vf

local mpfonts    = fonts.mp or { }
fonts.mp         = mpfonts

mpfonts.version  = mpfonts.version or 1.20
mpfonts.inline   = true
mpfonts.cache    = containers.define("fonts", "mp", mpfonts.version, true)

metapost.fonts = metapost.fonts or { }

-- a few glocals

local characters, descriptions = { }, { }
local factor, code, slot, width, height, depth, total, variants = 100, { }, 0, 0, 0, 0, 0, 0, true

-- A next version of mplib will provide the tfm font information which
-- gives better glyph dimensions, plus additional kerning information.

local flusher = {
    startfigure = function(chrnum,llx,lly,urx,ury)
        code   = { }
        slot   = chrnum
        width  = urx - llx
        height = ury
        depth  = -lly
        total  = total + 1
        inline = mpfonts.inline
    end,
    flushfigure = function(t)
        for i=1,#t do
            code[#code+1] = t[i]
        end
    end,
    stopfigure = function()
        local cd = chardata[n]
        descriptions[slot] = {
        --  unicode     = slot,
            name        = cd and cd.adobename,
            width       = width * 100,
            height      = height * 100,
            depth       = depth * 100,
            boundingbox = { 0, -depth, width, height },
        }
        if inline then
            characters[slot] = {
                commands = {
                    { "special", "pdf: " .. concat(code," ") },
                }
            }
        else
            characters[slot] = {
                commands = {
                    {
                        "image",
                        {
                            stream = concat(code," "),
                            bbox   = { 0, -depth * 65536, width * 65536, height * 65536 }
                        },
                    },
                }
            }
        end
    end
}

local function process(mpxformat,name,instances,scalefactor)
    statistics.starttiming(metapost.fonts)
    scalefactor = scalefactor or 1
    instances = instances or metapost.fonts.instances or 1
    local fontname = file.removesuffix(file.basename(name))
    local hash  = file.robustname(formatters["%s %05i %03i"](fontname,scalefactor*1000,instances))
    local lists = containers.read(mpfonts.cache,hash)
    if not lists or lists.version ~= version then
        statistics.starttiming(flusher)
        local data = io.loaddata(resolvers.findfile(name))
        metapost.reset(mpxformat)
        metapost.setoutercolor(2) -- no outer color and no reset either
        lists = { }
        for i=1,instances do
            characters   = { }
            descriptions = { }
            metapost.process(
                mpxformat,
                {
                    formatters["randomseed := %s ;"](i*10),
                    formatters["charscale  := %s ;"](scalefactor),
                    data,
                },
                false,
                flusher,
                false,
                false,
                "all"
            )
            lists[i] = {
                characters   = characters,
                descriptions = descriptions,
                parameters   = {
                    designsize    = 655360,
                    slant         =      0,
                    space         =    333   * scalefactor,
                    space_stretch =    166.5 * scalefactor,
                    space_shrink  =    111   * scalefactor,
                    x_height      =    431   * scalefactor,
                    quad          =   1000   * scalefactor,
                    extra_space   =      0,
                },
                properties  = {
                    name          = formatters["%s-%03i"](hash,i),
                    virtualized   = true,
                    spacer        = "space",
                }
            }
        end
--         inspect(lists)
        lists.version = metapost.variables.fontversion or "1.000"
        metapost.reset(mpxformat) -- saves memory
        lists = containers.write(mpfonts.cache, hash, lists)
        statistics.stoptiming(flusher)
    end
    variants = variants + #lists
    statistics.stoptiming(metapost.fonts)
    return lists
end

metapost.fonts.flusher   = flusher
metapost.fonts.instances = 1
metapost.fonts.process   = process

local function build(g,v)
    local size = g.specification.size
    local data = process(v[2],v[3],v[4],size/655360,v[6])
    local list = { }
    local t = { }
    for d=1,#data do
        t = fonts.constructors.scale(data[d],-1000)
        local id = font.nextid()
        t.fonts = { { id = id } }
        fontdata[id] = t
        if v[5] then
            vffonts.helpers.composecharacters(t)
        end
        list[d] = font.define(t)
    end
    for k, v in next, t do -- last t
        g[k] = v -- kind of replace, when not present, make nil
    end
    g.properties.virtualized = true
    g.variants = list
end

vffonts.combiner.commands.metapost = build
vffonts.combiner.commands.metafont = build

statistics.register("metapost font generation", function()
    local time = statistics.elapsedtime(flusher)
    if total > 0 then
        return format("%i glyphs, %.3f seconds runtime, %i glyphs/second", total, time, total/time)
    else
        return format("%i glyphs, %.3f seconds runtime", total, time)
    end
end)

statistics.register("metapost font loading",function()
    local time = statistics.elapsedtime(metapost.fonts)
    if variants > 0 then
        return format("%.3f seconds, %i instances, %0.3f instances/second", time, variants, variants/time)
    else
        return format("%.3f seconds, %i instances", time, variants)
    end
end)

-- fonts.definers.methods.install( "bidi", {
--     {
--         "metapost",    -- method
--         "metafun",     -- format
--         "fontoeps.mp", -- filename
--         1,             -- instances
--         false,         -- compose
--     },
-- } )

local report = logs.reporter("metapost","fonts")

function metapost.fonts.define(specification)
    local fontname = specification.fontname or ""
    local filename = specification.filename or ""
    local format   = specification.format   or "metafun"
    if fontname == "" then
        report("no fontname given")
        return
    end
    if filename == "" then
        report("no filename given for %a",fontname)
        return
    end
    local fullname = resolvers.findfile(filename)
    if fullname == "" then
        report("unable to locate file %a",filename)
        return
    end
    report("generating font %a using format %a and file %a",fontname,format,filename)
    fonts.definers.methods.install(fontname, {
        {
            specification.engine    or "metapost",
            format,
            filename,
            specification.instances or 1,
            specification.compose   or false,
        },
    } )
end

commands.definemetafont = metapost.fonts.define

-- metapost.fonts.define {
--     fontname = "bidi",
--     filename = "bidi-symbols.mp",
-- }

if not modules then modules = { } end modules['s-fonts-shapes'] = {
    version   = 1.001,
    comment   = "companion to s-fonts-shapes.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

moduledata.fonts        = moduledata.fonts        or { }
moduledata.fonts.shapes = moduledata.fonts.shapes or { }

local fontdata = fonts.hashes.identifiers

local NC, NR = context.NC, context.NR
local space, dontleavehmode, glyph = context.space, context.dontleavehmode, context.glyph

function moduledata.fonts.shapes.showlist(specification) -- todo: ranges
    specification = interfaces.checkedspecification(specification)
    local id = tonumber(specification.number) or font.current()
    local chrs = fontdata[id].characters
    function char(k)
        dontleavehmode()
        glyph(id,k)
    end
    local function special(v)
        local specials = v.specials
        if specials and #specials > 1 then
            context("%s:",specials[1])
            for i=2,#specials do
                space()
                char(specials[i])
            end
        end
    end
    context.begingroup()
    context.tt()
    context.starttabulate { "|l|c|c|c|c|l|l|" }
        context.FL()
            NC() context.bold("unicode")
            NC() context.bold("glyph")
            NC() context.bold("shape")
            NC() context.bold("lower")
            NC() context.bold("upper")
            NC() context.bold("specials")
            NC() context.bold("description")
            NC() NR()
        context.TL()
        for k, v in next, characters.data do
            if chrs[k] then
                NC() context("0x%05X",k)
                NC() char(k)
                NC() char(v.shcode)
                NC() char(v.lccode or k)
                NC() char(v.uccode or k)
                NC() special(v)
                NC() context.tx(v.description)
                NC() NR()
            end
        end
    context.stoptabulate()
    context.endgroup()
end

if not modules then modules = { } end modules['s-math-characters'] = {
    version   = 1.001,
    comment   = "companion to s-math-characters.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- This is one of the oldest cld files but I'm not going to clean it up.

moduledata.math            = moduledata.math            or { }
moduledata.math.characters = moduledata.math.characters or { }

local concat = table.concat
local lower = string.lower
local utfchar = utf.char
local round = math.round
local setmetatableindex = table.setmetatableindex
local sortedhash = table.sortedhash

local context        = context

local fontdata       = fonts.hashes.identifiers
local chardata       = characters.data
local blocks         = characters.blocks

local no_description = "no description, private to font"

local limited        = true
local fillinthegaps  = true
local upperlimit     = 0x0007F
local upperlimit     = 0xF0000

local f_unicode      = string.formatters["%U"]
local f_slot         = string.formatters["%s/%0X"]

function moduledata.math.characters.showlist(specification)
    specification     = interfaces.checkedspecification(specification)
    local id          = specification.number -- or specification.id
    local list        = specification.list
    local showvirtual = specification.virtual == "all"
    local check       = specification.check == "yes"
    if not id then
        id = font.current()
    end
    if list == "" then
        list = nil
    end
    local tfmdata      = fontdata[id]
    local characters   = tfmdata.characters
    local descriptions = tfmdata.descriptions
    local resources    = tfmdata.resources
    local lookuptypes  = resources.lookuptypes
    local virtual      = tfmdata.properties.virtualized
    local names        = { }
    local gaps         = mathematics.gaps
    local sorted       = { }
    if type(list) == "string" then
        sorted = utilities.parsers.settings_to_array(list)
        for i=1,#sorted do
            sorted[i] = tonumber(sorted[i])
        end
    elseif type(list) == "table" then
        sorted = list
        for i=1,#sorted do
            sorted[i] = tonumber(sorted[i])
        end
    elseif fillinthegaps then
        sorted = table.keys(characters)
        for k, v in next, gaps do
            if characters[v] then
                sorted[#sorted+1] = k
            end
        end
        table.sort(sorted)
    else
        sorted = table.sortedkeys(characters)
    end
    if virtual then
        local fonts = tfmdata.fonts
        for i=1,#fonts do
            local id = fonts[i].id
            local name = fontdata[id].properties.name
            names[i] = (name and file.basename(name)) or id
        end
    end
    if check then
        for k, v in table.sortedhash(blocks) do
            if v.math then
                local first = v.first
                local last  = v.last
                local f, l  = 0, 0
                if first and last then
                    for unicode=first,last do
                        local code = gaps[unicode] or unicode
                        local char = characters[code]
                        if char and not (char.commands and not showvirtual) then
                            f = unicode
                            break
                        end
                    end
                    for unicode=last,first,-1 do
                        local code = gaps[unicode] or unicode
                        local char = characters[code]
                        if char and not (char.commands and not showvirtual) then
                            l = unicode
                            break
                        end
                    end
                    context.showmathcharacterssetrange(k,f,l)
                end
            end
        end
    else

        local function collectalllookups(tfmdata,script,language)
            local all     = setmetatableindex(function(t,k) local v = setmetatableindex("table") t[k] = v return v end)
            local shared  = tfmdata.shared
            local rawdata = shared and shared.rawdata
            if rawdata then
                local features = rawdata.resources.features
                if features.gsub then
                    for kind, feature in next, features.gsub do
                        local validlookups, lookuplist = fonts.handlers.otf.collectlookups(rawdata,kind,script,language)
                        if validlookups then
                            for i=1,#lookuplist do
                                local lookup = lookuplist[i]
                                local steps  = lookup.steps
                                for i=1,lookup.nofsteps do
                                    local coverage = steps[i].coverage
                                    if coverage then
                                        for k, v in next, coverage do
                                            all[k][lookup.type][kind] = v
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
            return all
        end

        local alllookups = collectalllookups(tfmdata,"math","dflt")

        local luametatex = LUATEXENGINE == "luametatex"

        context.showmathcharactersstart()
        for _, unicode in next, sorted do
            if not limited or unicode < upperlimit then
                local code = gaps[unicode] or unicode
                local char = characters[code]
                local desc = descriptions[code]
                local info = chardata[code]
                if char then
                    local commands    = char.commands
                    if commands and not showvirtual then
                        -- skip
                    else
                        local next_sizes  = char.next
                        local vparts      = char.vparts or char.vert_variants
                        local hparts      = char.hparts or char.horiz_variants
                        local mathclass   = info.mathclass
                        local mathspec    = info.mathspec
                        local mathsymbol  = info.mathsymbol
                        local description = info.description or no_description
                        context.showmathcharactersstartentry(
                        )
                        context.showmathcharactersreference(
                            f_unicode(unicode)
                        )
                        context.showmathcharactersentryhexdectit(
                            f_unicode(code),
                            code,
                            lower(description)
                        )
                        if luametatex then
                            context.showmathcharactersentrywdhtdpicta(
                                code
                            )
                        else
                            context.showmathcharactersentrywdhtdpicta(
                                round(char.width     or 0),
                                round(char.height    or 0),
                                round(char.depth     or 0),
                                round(char.italic    or 0),
                                round(char.topaccent or 0)
                            )
                        end
                        if virtual and commands then
                            local t = { }
                            for i=1,#commands do
                                local ci = commands[i]
                                if ci[1] == "slot" then
                                    local fnt, idx = ci[2], ci[3]
                                    t[#t+1] = f_slot(names[fnt] or fnt,idx)
                                end
                            end
                            if #t > 0 then
                                context.showmathcharactersentryresource(concat(t,", "))
                            end
                        end
                        if mathclass or mathspec then
                            context.showmathcharactersstartentryclassspec()
                            if mathclass then
                                context.showmathcharactersentryclassname(mathclass,info.mathname or "no name")
                            end
                            if mathspec then
                                for i=1,#mathspec do
                                    local mi = mathspec[i]
                                    context.showmathcharactersentryclassname(mi.class,mi.name or "no name")
                                end
                            end
                            context.showmathcharactersstopentryclassspec()
                        end
                        if mathsymbol then
                            context.showmathcharactersentrysymbol(f_unicode(mathsymbol),mathsymbol)
                        end
                        if next_sizes then
                            local n, done = 0, { }
                            context.showmathcharactersstartnext()
                            while next_sizes do
                                n = n + 1
                                if done[next_sizes] then
                                    context.showmathcharactersnextcycle(n)
                                    break
                                else
                                    done[next_sizes] = true
                                    context.showmathcharactersnextentry(n,f_unicode(next_sizes),next_sizes)
                                    next_sizes = characters[next_sizes]
                                    vparts = next_sizes.vparts or next_sizes.vert_variants  or vparts
                                    hparts = next_sizes.hparts or next_sizes.horiz_variants or hparts
                                    if next_sizes then
                                        next_sizes = next_sizes.next
                                    end
                                end
                            end
                            context.showmathcharactersstopnext()
                            if vparts or hparts then
                                context.showmathcharactersbetweennextandvariants()
                            end
                        end
                        if vparts then
                            context.showmathcharactersstartvparts()
                            for i=1,#vparts do -- we might go top-down in the original
                                local vi = vparts[i]
                                context.showmathcharactersvpartsentry(i,f_unicode(vi.glyph),vi.glyph)
                            end
                            context.showmathcharactersstopvparts()
                        end
                        if hparts then
                            context.showmathcharactersstarthparts()
                            for i=1,#hparts do
                                local hi = hparts[#hparts-i+1]
                                context.showmathcharactershpartsentry(i,f_unicode(hi.glyph),hi.glyph)
                            end
                            context.showmathcharactersstophparts()
                        end
                        local lookups = alllookups[unicode]
                        if lookups then
                            local variants   = { }
                            local singles    = lookups.gsub_single
                            local alternates = lookups.gsub_alternate
                            if singles then
                                for lookupname, code in next, singles do
                                    variants[code] = lookupname
                                end
                            end
                            if singles then
                                for lookupname, codes in next, alternates do
                                    for i=1,#codes do
                                        variants[codes[i]] = lookupname .. " : " .. i
                                    end
                                end
                            end
                            context.showmathcharactersstartlookupvariants()
                            local i = 0
                            for variant, lookuptype in sortedhash(variants) do
                                i = i + 1
                                context.showmathcharacterslookupvariant(i,f_unicode(variant),variant,lookuptype)
                            end
                            context.showmathcharactersstoplookupvariants()
                        end
                        context.showmathcharactersstopentry()
                    end
                end
            end
        end
        context.showmathcharactersstop()
    end
end

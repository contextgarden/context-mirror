if not modules then modules = { } end modules ['font-enc'] = {
    version   = 1.001,
    comment   = "companion to font-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- this module is obsolete

local match, gmatch, gsub = string.match, string.gmatch, string.gsub

--[[ldx--
<p>Because encodings are going to disappear, we don't bother defining
them in tables. But we may do so some day, for consistency.</p>
--ldx]]--

fonts.enc = fonts.enc or { }
local enc = fonts.enc

enc.version = 1.03
enc.cache   = containers.define("fonts", "enc", fonts.enc.version, true)

enc.known = utilities.storage.allocate { -- sort of obsolete
    texnansi = true,
    ec       = true,
    qx       = true,
    t5       = true,
    t2a      = true,
    t2b      = true,
    t2c      = true,
    unicode  = true,
}

function enc.is_known(encoding)
    return containers.is_valid(enc.cache,encoding)
end

--[[ldx--
<p>An encoding file looks like this:</p>

<typing>
/TeXnANSIEncoding [
/.notdef
/Euro
...
/ydieresis
] def
</typing>

<p>Beware! The generic encoding files don't always apply to the ones that
ship with fonts. This has to do with the fact that names follow (slightly)
different standards. However, the fonts where this applies to (for instance
Latin Modern or <l n='tex'> Gyre) come in OpenType variants too, so these
will be used.</p>
--ldx]]--

local enccodes = characters.enccodes

function enc.load(filename)
    local name = file.removesuffix(filename)
    local data = containers.read(enc.cache,name)
    if data then
        return data
    end
    if name == "unicode" then
        data = enc.make_unicode_vector() -- special case, no tex file for this
    end
    if data then
        return data
    end
    local vector, tag, hash, unicodes = { }, "", { }, { }
    local foundname = resolvers.findfile(filename,'enc')
    if foundname and foundname ~= "" then
        local ok, encoding, size = resolvers.loadbinfile(foundname)
        if ok and encoding then
            encoding = gsub(encoding,"%%(.-)\n","")
            local tag, vec = match(encoding,"/(%w+)%s*%[(.*)%]%s*def")
            local i = 0
            for ch in gmatch(vec,"/([%a%d%.]+)") do
                if ch ~= ".notdef" then
                    vector[i] = ch
                    if not hash[ch] then
                        hash[ch] = i
                    else
                        -- duplicate, play safe for tex ligs and take first
                    end
                    if enccodes[ch] then
                        unicodes[enccodes[ch]] = i
                    end
                end
                i = i + 1
            end
        end
    end
    local data = {
        name     = name,
        tag      = tag,
        vector   = vector,
        hash     = hash,
        unicodes = unicodes
    }
    return containers.write(enc.cache, name, data)
end

--[[ldx--
<p>There is no unicode encoding but for practical purposed we define
one.</p>
--ldx]]--

-- maybe make this a function:

function enc.make_unicode_vector()
    local vector, hash = { }, { }
    for code, v in next, characters.data do
        local name = v.adobename
        if name then
            vector[code], hash[name] = name, code
        else
            vector[code] = '.notdef'
        end
    end
    for name, code in next, characters.synonyms do
        vector[code], hash[name] = name, code
    end
    return containers.write(enc.cache, 'unicode', { name='unicode', tag='unicode', vector=vector, hash=hash })
end

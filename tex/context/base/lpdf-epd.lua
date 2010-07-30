if not modules then modules = { } end modules ['lpdf-epd'] = {
    version   = 1.001,
    comment   = "companion to lpdf-epa.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- This is an experimental layer around the epdf library. Because that
-- library is not yet finished and will get a clear api (independent of
-- the underlying pdf library which has an instable api) it will take
-- a while before this module is completed. Also, some integration with
-- other lpdf code might happen (i.e. we might generate lpdf objects).

local setmetatable, rawset = setmetatable, rawset

-- used:
--
-- arrayGet arrayGetNF dictLookup getTypeName arrayGetLength
-- getNum getString getBool getName getRef
-- getResourceDict getMediaBox getCropBox getBleedBox getTrimBox getArtBox
-- getPageRef getKindName findDestgetNumPages getDests getPage getCatalog getAnnots

-- -- -- helpers -- -- --

local cache_lookups = false

local checked_access

local array_access = {
    __index = function(t,k)
        local d = t.__data__
        if tonumber(k) then
            return checked_access(t,k,d:arrayGetNF(k))
        elseif k == "all" then
            local result = { }
            for i=1,t.size do
                result[i] = checked_access(t,k,d:arrayGetNF(i))
            end
            return result
        elseif k == "width" then
            return checked_access(t,k,d:arrayGetNF(3)) - checked_access(t,k,d:arrayGetNF(1))
        elseif k == "height" then
            return checked_access(t,k,d:arrayGetNF(4)) - checked_access(t,k,d:arrayGetNF(2))
        end
    end,
}

local dictionary_access = {
    __index = function(t,k)
        return checked_access(t,k,t.__data__:dictLookup(k))
    end
}

checked_access = function(tab,key,v)
    local n = v:getTypeName()
--~ print("!!!!!!!!!!!!!!",n)
    if n == "array" then
        local t = { __data__ = v, size = v:arrayGetLength() }
        setmetatable(t,array_access)
        if cache_lookups then rawset(tab,key,t) end
        return t
    elseif n == "dictionary" then
        local t = { __data__ = v, }
        setmetatable(t,dictionary_access)
        if cache_lookups then rawset(tab,key,t) end
        return t
    elseif n == "real" or n == "integer" then
        return v:getNum()
    elseif n == "string" then
        return v:getString()
    elseif n == "boolean" then
        return v:getBool()
    elseif n == "name" then
        return v:getName()
    elseif n == "ref" then
        return v:getRef(v.num,v.gen)
    else
        return v
    end
end

local basic_annots_access = {
    __index = function(t,k)
        local a = {
            __data__ = t.__data__:arrayGet(k),
        }
        setmetatable(a,dictionary_access)
        if cache_lookups then rawset(t,k,a) end
        return a
    end
}

local basic_resources_access = { -- == dictionary_access
    __index = function(t,k)
--~ local d = t.__data__
--~ print(d)
--~ print(d:getTypeName())
        return checked_access(t,k,t.__data__:dictLookup(k))
    end
}

local basic_box_access = {
    __index = function(t,k)
        local d = t.__data__
        if     k == "all"    then return { d.x1, d.y1, d.x2, d.y2 }
        elseif k == "width"  then return d.x2 - d.x1
        elseif k == "height" then return d.y2 - d.y1
        elseif k == 1        then return d.x1
        elseif k == 2        then return d.y1
        elseif k == 3        then return d.x2
        elseif k == 4        then return d.y2
        else                      return 0 end
    end
}

-- -- -- pages -- -- --

local page_access = {
    __index = function(t,k)
        local d = t.__data__
        if k == "Annots" then
            local annots = d:getAnnots()
            local a = {
                __data__ = annots,
                size = annots:arrayGetLength()
            }
            setmetatable(a,basic_annots_access)
            rawset(t,k,a)
            return a
        elseif k == "Resources" then
            local r = {
                __data__ = d:getResourceDict(),
            }
            setmetatable(r,basic_resources_access)
            rawset(t,k,r)
            return r
        elseif k == "MediaBox" or k == "TrimBox" or k == "CropBox" or k == "ArtBox" or k == "BleedBox" then
            local b = {
             -- __data__ = d:getMediaBox(),
                __data__ = d["get"..k](d),
            }
            setmetatable(b,basic_box_access)
            rawset(t,k,b)
            return b
        end
    end
}

-- -- -- catalog -- -- --

local destination_access = {
    __index = function(t,k)
        if k == "D" then
            local d = t.__data__
            local p = {
                d:getPageRef(k), d:getKindName(k)
            }
            if cache_lookups then rawset(t,k,p) end -- not needed
            return p
        end
    end
}

local destinations_access = {
    __index = function(t,k)
        local d = t.__catalog__
        local p = {
            __data__  = d:findDest(k),
        }
        setmetatable(p,destination_access)
        if cache_lookups then rawset(t,k,p) end
        return p
    end
}

local catalog_access = {
    __index = function(t,k)
        local c = t.__catalog__
        if k == "Pages" then
            local s = c:getNumPages()
            local r = {
            }
            local p = {
                __catalog__ = c,
                size        = s,
                references  = r,
            }
         -- we load all pages as we need to resolve refs
            for i=1,s do
                local di, ri = c:getPage(i), c:getPageRef(i)
                local pi = {
                    __data__  = di,
                    reference = ri,
                    number    = i,
                }
                setmetatable(pi,page_access)
                p[i], r[ri.num] = pi, i
            end
         -- setmetatable(p,pages_access)
            rawset(t,k,p)
            return p
        elseif k == "Destinations" or k == "Dest" then
            local d = c:getDests()
            local p = {
                __catalog__ = c,
            }
            setmetatable(p,destinations_access)
            rawset(t,k,p)
            return p
        elseif k == "Metadata" then
            local m = c:readMetadata()
            local p = { -- we fake a stream dictionary
                __catalog__ = c,
                stream      = m,
                Type        = "Metadata",
                Subtype     = "XML",
                Length      = #m,
            }
         -- rawset(t,k,p)
            return p
        end
    end
}

local document_access = {
    __index = function(t,k)
        if k == "Catalog" then
            local c = {
                __catalog__ = t.__root__:getCatalog(),
            }
            setmetatable(c,catalog_access)
            rawset(t,k,c)
            return c
        end
    end
}

function lpdf.load(filename)
    local document = {
        __root__ = epdf.open(filename),
        filename = filename,
    }
    setmetatable(document,document_access)
    return document
end

if not modules then modules = { } end modules ['lxml-ini'] = {
    version   = 1.001,
    comment   = "companion to lxml-ini.tex",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

document     = document or { }
document.xml = document.xml or { }

lxml         = { }
lxml.loaded  = { }

function lxml.root(id)
    return lxml.loaded[id]
end

function lxml.load(id,filename)
    lxml.loaded[id] = xml.load(filename)
end

function lxml.first(id,pattern)
    tex.sprint(xml.tostring(xml.first_text(lxml.loaded[id],pattern)))
end

function lxml.last(id,pattern)
    tex.sprint(xml.tostring(xml.last_text (lxml.loaded[id],pattern)))
end

function lxml.index(id,pattern,i)
    tex.sprint(xml.tostring(xml.index_text(lxml.loaded[id],pattern,i)))
end

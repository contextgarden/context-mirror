if not modules then modules = { } end modules ['strc-mat'] = {
    version   = 1.001,
    comment   = "companion to strc-mat.tex",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

structure                 = structure                 or { }
structure.helpers         = structure.helpers         or { }
structure.lists           = structure.lists           or { }
structure.lists.enhancers = structure.lists.enhancers or { }
structure.sections        = structure.sections        or { }
structure.helpers         = structure.helpers         or { }
structure.formulas        = structure.formulas        or { }

local lists     = structure.lists
local sections  = structure.sections
local floats    = structure.floats
local helpers   = structure.helpers
local formulas  = structure.formulas

-- maybe we want to do clever things with formulas, the store might go away

local formuladata = { }

function formulas.store(data)
    formuladata[#formuladata+1] = data
    tex.write(#formuladata)
end

function formulas.current()
    return formuladata[#formuladata]
end

function helpers.formulanumber(data,spec)
    if data then
        local formulanumber = data.formulanumber
        if formulanumber then
            sections.number(data,spec,"formulanumber","formulanumber",'number')
        end
    end
end

function formulas.simplify(entry)
    return helpers.simplify(table.copy(entry or formuladata[#formuladata]))
end

function lists.formulanumber(name,n,spec)
    helpers.formulanumber(lists.result[n])
end

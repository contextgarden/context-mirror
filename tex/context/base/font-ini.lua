if not modules then modules = { } end modules ['font-ini'] = {
    version   = 1.001,
    comment   = "companion to font-ini.tex",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

--[[ldx--
<p>Not much is happening here.</p>
--ldx]]--

-- vtf comes first
-- fix comes last

fonts = fonts or { }

fonts.trace = false -- true
fonts.mode  = 'base'

fonts.methods = {
    base = { tfm = { }, afm = { }, otf = { }, vtf = { }, fix = { } },
    node = { tfm = { }, afm = { }, otf = { }, vtf = { }, fix = { }  },
}

fonts.initializers = {
    base = { tfm = { }, afm = { }, otf = { }, vtf = { }, fix = { }  },
    node = { tfm = { }, afm = { }, otf = { }, vtf = { }, fix = { }  }
}

fonts.triggers = {
    'mode',
    'language',
    'script'
}

-- tracing

do

    fonts.color = fonts.color or { }

    fonts.color.trace = false

    local attribute = attributes.numbers['color'] or 4 -- we happen to know this -)
    local mapping   = attributes.list[attribute]

    local set_attribute   = node.set_attribute
    local unset_attribute = node.unset_attribute

    function fonts.color.set(n,c)
    --  local mc = mapping[c] if mc then unset_attribute((n,attribute) else set_attribute(n,attribute,mc) end
        set_attribute(n,attribute,mapping[c] or -1) -- also handles -1 now
    end
    function fonts.color.reset(n)
        unset_attribute(n,attribute)
    end

end

if not modules then modules = { } end modules ['strc-tag'] = {
    version   = 1.001,
    comment   = "companion to strc-tag.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- This is rather experimental code.

local insert, remove, unpack, concat = table.insert, table.remove, table.unpack, table.concat
local gsub, find, topattern, format = string.gsub, string.find, string.topattern, string.format
local lpegmatch = lpeg.match
local texattribute, texsprint, ctxcatcodes = tex.attribute, tex.sprint, tex.ctxcatcodes
local allocate = utilities.storage.allocate
local settings_to_hash = utilities.parsers.settings_to_hash

local trace_tags = false  trackers.register("structures.tags", function(v) trace_tags = v end)

local report_tags = logs.new("tags")

local attributes, structures = attributes, structures

local a_tagged       = attributes.private('tagged')

local unsetvalue     = attributes.unsetvalue
local codeinjections = backends.codeinjections

local taglist    = allocate()
local properties = allocate()
local labels     = allocate()
local stack      = { }
local chain      = { }
local ids        = { }
local enabled    = false

local tags       = structures.tags
tags.taglist     = taglist -- can best be hidden
tags.labels      = labels

local properties = allocate {

    document           = { pdf = "Div",        nature = "display" },

    division           = { pdf = "Div",        nature = "display" },
    paragraph          = { pdf = "P",          nature = "mixed"   },
    construct          = { pdf = "Span",       nature = "inline"  },

    section            = { pdf = "Sect",       nature = "display" },
    sectiontitle       = { pdf = "H",          nature = "mixed"   },
    sectionnumber      = { pdf = "H",          nature = "mixed"   },
    sectioncontent     = { pdf = "Div",        nature = "display" },

    itemgroup          = { pdf = "L",          nature = "display" },
    item               = { pdf = "Li",         nature = "display" },
    itemtag            = { pdf = "Lbl",        nature = "mixed"   },
    itemcontent        = { pdf = "LBody",      nature = "mixed"   },

    description        = { pdf = "Div",        nature = "display" },
    descriptiontag     = { pdf = "Div",        nature = "mixed"   },
    descriptioncontent = { pdf = "Div",        nature = "mixed"   },
    descriptionsymbol  = { pdf = "Span",       nature = "inline"  }, -- note reference

    verbatimblock      = { pdf = "Code",       nature = "display" },
    verbatimline       = { pdf = "Code",       nature = "display" },
    verbatim           = { pdf = "Code",       nature = "inline"  },

    register           = { pdf = "Div",        nature = "display" },
    registersection    = { pdf = "Div",        nature = "display" },
    registertag        = { pdf = "Span",       nature = "mixed"   },
    registerentries    = { pdf = "Div",        nature = "display" },
    registerentry      = { pdf = "Span",       nature = "mixed"   },
    registersee        = { pdf = "Span",       nature = "mixed"   },
    registerpages      = { pdf = "Span",       nature = "mixed"   },
    registerpage       = { pdf = "Span",       nature = "inline"  },

    table              = { pdf = "Table",      nature = "display" },
    tablerow           = { pdf = "TR",         nature = "display" },
    tablecell          = { pdf = "TD",         nature = "mixed"   },
    tabulate           = { pdf = "Table",      nature = "display" },
    tabulaterow        = { pdf = "TR",         nature = "display" },
    tabulatecell       = { pdf = "TD",         nature = "mixed"   },

    list               = { pdf = "TOC",        nature = "display" },
    listitem           = { pdf = "TOCI",       nature = "display" },
    listtag            = { pdf = "Lbl",        nature = "mixed"   },
    listcontent        = { pdf = "P",          nature = "mixed"   },
    listdata           = { pdf = "P",          nature = "mixed"   },
    listpage           = { pdf = "Reference",  nature = "mixed"   },

    delimitedblock     = { pdf = "BlockQuote", nature = "display" },
    delimited          = { pdf = "Quote",      nature = "inline"  },
    subsentence        = { pdf = "Span",       nature = "inline"  },

    float              = { pdf = "Div",        nature = "display" }, -- Figure
    floatcaption       = { pdf = "Caption",    nature = "display" },
    floattag           = { pdf = "Span",       nature = "mixed"   },
    floattext          = { pdf = "Span",       nature = "mixed"   },
    floatcontent       = { pdf = "P",          nature = "mixed"   },

    image              = { pdf = "P",          nature = "mixed"   },
    mpgraphic          = { pdf = "P",          nature = "mixed"   },

    formulaset         = { pdf = "Div",        nature = "display" },
    formula            = { pdf = "Div",        nature = "display" }, -- Formula
    formulatag         = { pdf = "Span",       nature = "mixed"   },
    formulacontent     = { pdf = "P",          nature = "display" },
    subformula         = { pdf = "Div",        nature = "display" },

    link               = { pdf = "Link",       nature = "inline"  },

    margintextblock    = { pdf = "Span",       nature = "inline"  },
    margintext         = { pdf = "Span",       nature = "inline"  },

    math               = { pdf = "Div",        nature = "display" },
    mn                 = { pdf = "Span",       nature = "mixed"   },
    mi                 = { pdf = "Span",       nature = "mixed"   },
    mo                 = { pdf = "Span",       nature = "mixed"   },
    ms                 = { pdf = "Span",       nature = "mixed"   },
    mrow               = { pdf = "Span",       nature = "display" },
    msubsup            = { pdf = "Span",       nature = "display" },
    msub               = { pdf = "Span",       nature = "display" },
    msup               = { pdf = "Span",       nature = "display" },
    merror             = { pdf = "Span",       nature = "mixed"   },
    munderover         = { pdf = "Span",       nature = "display" },
    munder             = { pdf = "Span",       nature = "display" },
    mover              = { pdf = "Span",       nature = "display" },
    mtext              = { pdf = "Span",       nature = "mixed"   },
    mfrac              = { pdf = "Span",       nature = "display" },
    mroot              = { pdf = "Span",       nature = "display" },
    msqrt              = { pdf = "Span",       nature = "display" },

}

tags.properties = properties

function tags.settagproperty(tag,key,value)
    local p = properties[tag]
    if p then
        p[key] = value
    else
        properties[tag] = { [key] = value }
    end
end

local lasttags = { }
local userdata = { }

tags.userdata = userdata

function tags.start(tag,specification)
    local label = specification.label
    local detail = specification.detail
    local user = specification.userdata
    if not enabled then
        codeinjections.enabletags()
        enabled = true
    end
    labels[tag] = label ~= "" and label or tag
    local fulltag
    if detail and detail ~= "" then
        fulltag = tag .. ":" .. detail
    else
        fulltag = tag
    end
    local t = #taglist + 1
    local n = (ids[fulltag] or 0) + 1
    ids[fulltag] = n
    lasttags[tag] = n
--~ print("SETTING",tag,n)
    local completetag = fulltag .. "-" .. n
    chain[#chain+1] = completetag -- insert(chain,tag .. ":" .. n)
    stack[#stack+1] = t -- insert(stack,t)
    taglist[t] = { unpack(chain) } -- we can add key values for alt and actualtext if needed
    if user and user ~= "" then
        -- maybe we should merge this into taglistor or whatever ... anyway there is room to optimize
        -- taglist.userdata = settings_to_hash(user)
        userdata[completetag] = settings_to_hash(user)
    end
    texattribute[a_tagged] = t
    return t
end

function tags.stop()
    local t = stack[#stack] stack[#stack] = nil -- local t = remove(stack)
    if not t then
        if trace_tags then
            report_tags("ignoring end tag, previous chain: %s",#chain > 0 and concat(chain[#chain]) or "none")
        end
        t = unsetvalue
    else
        chain[#chain] = nil -- remove(chain)
    end
    texattribute[a_tagged] = t
    return t
end

function tags.last(tag)
    return lasttags[tag] -- or false
end

function structures.atlocation(str)
    local location = gsub(concat(taglist[texattribute[a_tagged]],"-"),"%-%d+","")
    return find(location,topattern(str)) ~= nil
end

function tags.handler(head)  -- we need a dummy
    return head, false
end

statistics.register("structure elements", function()
    if enabled then
        return format("%s element chains identified",#taglist)
    else
        return nil
    end
end)

directives.register("backend.addtags", function(v)
    if not enabled then
        codeinjections.enabletags()
        enabled = true
    end
end)

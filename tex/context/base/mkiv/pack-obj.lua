if not modules then modules = { } end modules ['pack-obj'] = {
    version   = 1.001,
    comment   = "companion to pack-obj.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

--[[ldx--
<p>We save object references in the main utility table. jobobjects are
reusable components.</p>
--ldx]]--

local context         = context
local codeinjections  = backends.codeinjections

local ctx_doifelse    = commands.doifelse

local nuts            = nodes.nuts

local setlink         = nuts.setlink
local getlist         = nuts.getlist
local setbox          = nuts.setbox

local new_latelua     = nuts.pool.latelua

local settexdimen     = tokens.setters.dimen

local gettexbox       = tokens.getters.box
local gettexdimen     = tokens.getters.dimen
local gettexcount     = tokens.getters.count

local implement       = interfaces.implement
local setmacro        = interfaces.setmacro

local allocate        = utilities.storage.allocate

local collected       = allocate()
local tobesaved       = allocate()

local jobobjects      = {
    collected = collected,
    tobesaved = tobesaved,
}

job.objects           = jobobjects

local function initializer()
    collected = jobobjects.collected
    tobesaved = jobobjects.tobesaved
end

job.register('job.objects.collected', tobesaved, initializer, nil)

local function saveobject(tag,number,page)
    local t = { number, page }
    tobesaved[tag], collected[tag] = t, t
end

local function setobject(tag,number,page)
    collected[tag] = { number, page }
end

local function getobject(tag)
    return collected[tag] or tobesaved[tag]
end

local function getobjectnumber(tag,default)
    local o = collected[tag] or tobesaved[tag]
    return o and o[1] or default
end

local function getobjectpage(tag,default)
    local o = collected[tag] or tobesaved[tag]
    return o and o[2] or default
end

jobobjects.save   = saveobject
jobobjects.set    = setobject
jobobjects.get    = getobject
jobobjects.number = getobjectnumber
jobobjects.page   = getobjectpage

-- implement {
--     name      = "saveobject",
--     actions   = saveobject
-- }
--
-- implement {
--     name      = "setobject",
--     actions   = setobject,
--     arguments = { "string", "integer", "integer" }
-- }
--
-- implement {
--     name      = "objectnumber",
--     actions   = { getobjectnumber, context },
--     arguments = { "string", "string" },
-- }
--
-- implement {
--     name      = "objectpage",
--     actions   = { getobjectpage, context },
--     arguments = { "string", "string" },
-- }
--
-- implement {
--     name      = "doifelseobjectreferencefound",
--     actions   = { getobject, commands.doifelse },
--     arguments = "string"
-- }

-- if false then
--     -- we can flush the inline ref ourselves now if we want
--     local flush = new_latelua("pdf.flushxform("..index..")")
--     flush.next = list
--     next.prev = flush
-- end

local data = table.setmetatableindex("table")

objects = {
    data = data,
    n    = 0,
}

function objects.register(ns,id,b,referenced)
    objects.n = objects.n + 1
    nodes.handlers.finalize(gettexbox(b))
    data[ns][id] = {
        codeinjections.registerboxresource(b), -- a box number
        gettexdimen("objectoff"),
        referenced
    }
end

function objects.restore(ns,id)
    local d = data[ns][id]
    if d then
        local index  = d[1]
        local offset = d[2]
        local status = d[3]
        local hbox   = codeinjections.restoreboxresource(index) -- a nut !
        if status then
            local list = getlist(hbox)
            local page = new_latelua(function()
                saveobject(ns .. "::" .. id,index,gettexcount("realpageno"))
            end)
            setlink(list,page)
        end
        setbox("objectbox",hbox)
        settexdimen("objectoff",offset)
    else
        setbox("objectbox",nil)
        settexdimen("objectoff",0)
    end
end

function objects.dimensions(index)
    local d = data[ns][id]
    if d then
        return codeinjections.boxresourcedimensions(d[1])
    else
        return 0, 0, 0
    end
end

function objects.reference(ns,id)
    local d = data[ns][id]
    if d then
        return d[1]
    else
        return getobjectnumber(ns .."::" .. id,0)
    end
end

function objects.page(ns,id)
    return getobjectpage(ns .."::" .. id,gettexcount("realpageno"))
end

function objects.found(ns,id)
    return data[ns][id]
end

implement {
    name      = "registerreferencedobject",
    arguments = { "string", "string", "integer", true },
    actions   = objects.register,
}

implement {
    name      = "registerobject",
    arguments = { "string", "string", "integer" },
    actions   = objects.register,
}

implement {
    name      = "restoreobject",
    arguments = { "string", "string" },
    actions   = objects.restore,
}

implement {
    name      = "doifelseobject",
    arguments = { "string", "string" },
    actions   = function(ns,id)
        ctx_doifelse(data[ns][id])
     -- ctx_doifelse(objects.reference(ns,id))
    end,
}

implement {
    name      = "doifelseobjectreference",
    arguments = { "string", "string" },
    actions   = function(ns,id)
     -- ctx_doifelse(data[ns][id])
        ctx_doifelse(objects.reference(ns,id))
    end,
}

implement {
    name      = "getobjectreference",
    arguments = { "string", "string", "csname" },
    actions   = function(ns,id,target)
        setmacro(target,objects.reference(ns,id),"global")
    end
}

implement {
    name      = "getobjectreferencepage",
    arguments = { "string", "string", "csname" },
    actions   = function(ns,id,target)
        setmacro(target,objects.page(ns,id),"global")
    end
}

implement {
    name      = "getobjectdimensions",
    arguments = { "string", "string" },
    actions   = function(ns,id)
        local o = data[ns][id]
        local w, h, d = 0, 0, 0
        if d then
            w, h, d = codeinjections.boxresourcedimensions(o[1])
        end
        settexdimen("objectwd",w or 0)
        settexdimen("objectht",h or 0)
        settexdimen("objectdp",d or 0)
        settexdimen("objectoff",o[2])
    end
}

-- for the moment here:

implement {
    name      = "registerbackendsymbol",
    arguments = { "string", "integer" },
    actions   = function(...)
        codeinjections.registersymbol(...)
    end
}

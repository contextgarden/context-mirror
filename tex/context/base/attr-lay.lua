if not modules then modules = { } end modules ['attr-lay'] = {
    version   = 1.001,
    comment   = "companion to attr-lay.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- layers (ugly code, due to no grouping and such); currently we use exclusive layers
-- but when we need it stacked layers might show up too; the next function based
-- approach can be replaced by static (metatable driven) resolvers

local type = type
local format = string.format
local insert, remove = table.insert, table.remove

local allocate = utilities.storage.allocate

local report_viewerlayers = logs.reporter("viewerlayers")

-- todo: document this but first reimplement this as it reflects the early
-- days of luatex / mkiv and we have better ways now

-- nb: attributes: color etc is much slower than normal (marks + literals) but ...
-- nb. too many "0 g"s
-- nb: more local tables

local attributes, nodes = attributes, nodes

attributes.viewerlayers = attributes.viewerlayers or { }
local viewerlayers      = attributes.viewerlayers

local variables         = interfaces.variables
local v_local           = variables["local"]
local v_global          = variables["global"]

local a_viewerlayer     = attributes.private("viewerlayer")

viewerlayers            = viewerlayers            or { }
viewerlayers.data       = allocate()
viewerlayers.registered = viewerlayers.registered or { }
viewerlayers.values     = viewerlayers.values     or { }
viewerlayers.scopes     = viewerlayers.scopes     or { }
viewerlayers.listwise   = allocate()
viewerlayers.attribute  = a_viewerlayer
viewerlayers.supported  = true
viewerlayers.hasorder   = true

local states            = attributes.states
local tasks             = nodes.tasks
local nodeinjections    = backends.nodeinjections
local codeinjections    = backends.codeinjections

local texsetattribute   = tex.setattribute
local texgetattribute   = tex.getattribute
local texsettokenlist   = tex.settoks
local unsetvalue        = attributes.unsetvalue

storage.register("attributes/viewerlayers/registered", viewerlayers.registered, "attributes.viewerlayers.registered")
storage.register("attributes/viewerlayers/values",     viewerlayers.values,     "attributes.viewerlayers.values")
storage.register("attributes/viewerlayers/scopes",     viewerlayers.scopes,     "attributes.viewerlayers.scopes")

local data       = viewerlayers.data
local values     = viewerlayers.values
local listwise   = viewerlayers.listwise
local registered = viewerlayers.registered
local scopes     = viewerlayers.scopes
local template   = "%s"

-- stacked

local function extender(viewerlayers,key)
    if viewerlayers.supported and key == "none" then
        local d = nodeinjections.stoplayer()
        viewerlayers.none = d
        return d
    end
end

local function reviver(data,n)
    if viewerlayers.supported then
        local v = values[n]
        if v then
            local d = nodeinjections.startlayer(v)
            data[n] = d
            return d
        else
            report_viewerlayers("error, unknown reference '%s'",tostring(n))
        end
    end
end

setmetatable(viewerlayers,      { __index = extender })
setmetatable(viewerlayers.data, { __index = reviver  })

local function initializer(...)
    return states.initialize(...)
end

local function register(name,lw) -- if not inimode redefine data[n] in first call
    local stamp = format(template,name)
    local n = registered[stamp]
    if not n then
        n = #values + 1
        values[n] = name
        registered[stamp] = n
        listwise[n] = lw or false
    end
    return registered[stamp] -- == n
end

viewerlayers.register = register

attributes.viewerlayers.handler = nodes.installattributehandler {
    name        = "viewerlayer",
    namespace   = viewerlayers,
    initializer = initializer,
    finalizer   = states.finalize,
    processor   = states.stacked,
}

function viewerlayers.enable(value)
    if value == false or not viewerlayers.supported then
        tasks.disableaction("shipouts","attributes.viewerlayers.handler")
    else
        tasks.enableaction("shipouts","attributes.viewerlayers.handler")
    end
end

function viewerlayers.forcesupport(value)
    viewerlayers.supported = value
    report_viewerlayers("viewerlayers are %ssupported",value and "" or "not ")
    viewerlayers.enable(value)
end

function viewerlayers.setfeatures(hasorder)
    viewerlayers.hasorder = hasorder
end

local stack, enabled, global = { }, false, false

function viewerlayers.start(name)
    if not enabled then
        viewerlayers.enable(true)
    end
    insert(stack,texgetattribute(a_viewerlayer))
    local a = register(name) or unsetvalue
    if global or scopes[name] == v_global then
        scopes[a] = v_global -- messy but we don't know the attributes yet
        texsetattribute("global",a_viewerlayer,a)
    else
        texsetattribute(a_viewerlayer,a)
    end
    texsettokenlist("currentviewerlayertoks",name)
end

function viewerlayers.stop()
    local a = remove(stack)
    if a >= 0 then
        if global or scopes[a] == v_global then
            texsetattribute("global",a_viewerlayer,a)
        else
            texsetattribute(a_viewerlayer,a)
        end
        texsettokenlist("currentviewerlayertoks",values[a])
    else
        if global or scopes[a] == v_global then
            texsetattribute("global",a_viewerlayer,unsetvalue)
        else
            texsetattribute(a_viewerlayer,unsetvalue)
        end
        texsettokenlist("currentviewerlayertoks","")
    end
end

function viewerlayers.define(settings)
    local tag = settings.tag
    if not tag or tag == "" then
        -- error
    else
        local title = settings.title
        if not title or title == "" then
            settings.title = tag
        end
        scopes[tag] = settings.scope or v_local
        codeinjections.defineviewerlayer(settings)
    end
end

commands.defineviewerlayer = viewerlayers.define

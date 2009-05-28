if not modules then modules = { } end modules ['node-par'] = {
    version   = 1.001,
    comment   = "companion to node-par.lua",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

parbuilders              = parbuilders or { }
parbuilders.constructors = parbuilders.constructors or { }
parbuilders.names        = parbuilders.names or { }
parbuilders.attribute    = attributes.numbers['parbuilder'] or 999

storage.register("parbuilders.names", parbuilders.names, "parbuilders.names")

-- store parbuilders.names

function parbuilders.register(name,attribute)
    parbuilders.names[attribute] = name
end

function parbuilders.main(head,interupted_by_display)
    local attribute = node.has_attribute(head,parbuilders.attribute)
    if attribute then
        local constructor = parbuilders.names[attribute]
        if constructor then
            return parbuilders.constructors[constructor](head,interupted_by_display)
        end
    end
    return false
end

-- just for testing

function parbuilders.constructors.default(head,ibd)
    return false
end

-- also for testing (no surrounding spacing done)

function parbuilders.constructors.oneline(head,ibd)
    return node.hpack(head)
end

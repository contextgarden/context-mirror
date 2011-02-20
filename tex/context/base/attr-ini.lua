if not modules then modules = { } end modules ['attr-ini'] = {
    version   = 1.001,
    comment   = "companion to attr-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local next, type = next, type

--[[ldx--
<p>We start with a registration system for atributes so that we can use the
symbolic names later on.</p>
--ldx]]--

attributes = attributes or { }

local attributes, nodes = attributes, nodes

-- todo: local and then gobals ... first loaded anyway

attributes.names      = attributes.names    or { }
attributes.numbers    = attributes.numbers  or { }
attributes.list       = attributes.list     or { }
attributes.states     = attributes.states   or { }
attributes.handlers   = attributes.handlers or { }
attributes.unsetvalue = -0x7FFFFFFF

local names, numbers, list = attributes.names, attributes.numbers, attributes.list

storage.register("attributes/names",   names,   "attributes.names")
storage.register("attributes/numbers", numbers, "attributes.numbers")
storage.register("attributes/list",    list,    "attributes.list")

function attributes.define(name,number) -- at the tex end
    if not numbers[name] then
        numbers[name], names[number], list[number] = number, name, { }
    end
end

--[[ldx--
<p>We can use the attributes in the range 127-255 (outside user space). These
are only used when no attribute is set at the \TEX\ end which normally
happens in <l n='context'/>.</p>
--ldx]]--

storage.shared.attributes_last_private = storage.shared.attributes_last_private or 127

-- to be considered (so that we can use an array access):
--
-- local private = { } attributes.private = private
--
-- setmetatable(private, {
--     __index = function(t,name)
--         local number = storage.shared.attributes_last_private or 127
--         if number < 1023 then -- tex.count.minallocatedattribute - 1
--             number = number + 1
--             storage.shared.attributes_last_private = number
--         end
--         numbers[name], names[number], list[number] = number, name, { }
--         private[name] = number
--         return number
--     end,
--     __call = function(t,name)
--         return t[name]
--     end
-- } )

function attributes.private(name) -- at the lua end (hidden from user)
    local number = numbers[name]
    if not number then
        local last = storage.shared.attributes_last_private or 127
        if last < 1023 then -- tex.count.minallocatedattribute - 1
            last = last + 1
            storage.shared.attributes_last_private = last
        else
            report_attribute("no more room for private attributes") -- fatal
            os.exit()
        end
        number = last
        numbers[name], names[number], list[number] = number, name, { }
    end
    return number
end

-- new (actually a tracer)

function attributes.ofnode(n)
    local a = n.attr
    if a then
        a = a.next
        while a do
            local number, value = a.number, a.value
            texio.write_nl(format("%s : attribute %3i, value %4i, name %s",tostring(n),number,value,names[number] or '?'))
            a = a.next
        end
   end
end

-- interface

commands.defineattribute = attributes.define

function commands.getprivateattribute(name)
    context(attributes.private(name))
end

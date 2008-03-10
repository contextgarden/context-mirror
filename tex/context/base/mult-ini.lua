if not modules then modules = { } end modules ['mult-ini'] = {
    version   = 1.001,
    comment   = "companion to mult-ini.tex",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

interfaces           = interfaces           or { }
interfaces.messages  = interfaces.messages  or { }
interfaces.constants = interfaces.constants or { }
interfaces.variables = interfaces.variables or { }

input.storage.register(false,"interfaces/messages",  interfaces.messages,  "interfaces.messages" )
input.storage.register(false,"interfaces/constants", interfaces.constants, "interfaces.constants")
input.storage.register(false,"interfaces/variables", interfaces.variables, "interfaces.variables")

function interfaces.setmessage(category,str)
    local m = interfaces.messages[category] or { }
    for k, v in str:gmatch("(%S+) *: *(.-) *[\n\r]") do
        m[k] = v:gsub("%-%-","%%s")
    end
    interfaces.messages[category] = m
end

function interfaces.getmessage(category,tag)
    local m = interfaces.messages[category]
    return (m and m[tag]) or "unknown message"
end

function interfaces.makemessage(category,tag,arguments)
    local m = interfaces.messages[category]
    m = (m and m[tag] ) or "unknown message"
    if not m then
        return m .. " " .. tag
    elseif not arguments then
        return m
    elseif arguments:find(",") then
        return string.format(m,unpack(arguments:split(",")))
    else
        return string.format(m,arguments)
    end
end

function interfaces.showmessage(category,tag,arguments)
    local m = interfaces.messages[category]
    ctx.writestatus((m and m.title) or "unknown title",interfaces.makemessage(category,tag,arguments))
end

function interfaces.setvariable(variable,given)
    interfaces.variables[given] = variable
end

function interfaces.setconstant(constant,given)
    interfaces.constants[given] = constant
end

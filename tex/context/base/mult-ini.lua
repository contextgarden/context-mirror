if not modules then modules = { } end modules ['mult-ini'] = {
    version   = 1.001,
    comment   = "companion to mult-ini.tex",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local format, gmatch, gsub = string.format, string.gmatch, string.gsub

interfaces           = interfaces           or { }
interfaces.messages  = interfaces.messages  or { }
interfaces.constants = interfaces.constants or { }
interfaces.variables = interfaces.variables or { }

storage.register("interfaces/messages",  interfaces.messages,  "interfaces.messages" )
storage.register("interfaces/constants", interfaces.constants, "interfaces.constants")
storage.register("interfaces/variables", interfaces.variables, "interfaces.variables")

local messages, constants, variables = interfaces.messages, interfaces.constants, interfaces.variables

function interfaces.setmessages(category,str)
    local m = messages[category] or { }
    for k, v in gmatch(str,"(%S+) *: *(.-) *[\n\r]") do
        m[k] = gsub(v,"%-%-","%%s")
    end
    messages[category] = m
end

function interfaces.setmessage(category,tag,message)
    local m = messages[category]
    if not m then
        m = { }
        messages[category] = m
    end
    m[tag] = message:gsub("%-%-","%%s")
end

function interfaces.getmessage(category,tag)
    local m = messages[category]
    return (m and m[tag]) or "unknown message"
end

local messagesplitter = lpeg.splitat(",")

function interfaces.makemessage(category,tag,arguments)
    local m = messages[category]
    m = (m and m[tag] ) or format("unknown message, category '%s', tag '%s'",category,tag)
    if not m then
        return m .. " " .. tag
    elseif not arguments then
        return m
    else
        return format(m,messagesplitter:match(arguments))
    end
end

function interfaces.showmessage(category,tag,arguments)
    local m = messages[category]
    commands.writestatus((m and m.title) or "unknown title",interfaces.makemessage(category,tag,arguments))
end

function interfaces.setvariable(variable,given)
--~     variables[given] = variable
    variables[variable] = given
end

function interfaces.setconstant(constant,given)
    constants[given] = constant
end

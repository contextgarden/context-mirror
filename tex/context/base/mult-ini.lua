if not modules then modules = { } end modules ['mult-ini'] = {
    version   = 1.001,
    comment   = "companion to mult-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local format, gmatch, gsub = string.format, string.gmatch, string.gsub
local lpegmatch = lpeg.match
local serialize = table.serialize

local texsprint = tex.sprint

local report_interface = logs.new("interface","initialization")

interfaces           = interfaces           or { }
interfaces.messages  = interfaces.messages  or { }
interfaces.constants = interfaces.constants or { }
interfaces.variables = interfaces.variables or { }
interfaces.elements  = interfaces.elements  or { }

storage.register("interfaces/messages",  interfaces.messages,  "interfaces.messages")
storage.register("interfaces/constants", interfaces.constants, "interfaces.constants")
storage.register("interfaces/variables", interfaces.variables, "interfaces.variables")
storage.register("interfaces/elements",  interfaces.elements,  "interfaces.elements")

interfaces.interfaces = {
    "cs", "de", "en", "fr", "it", "nl", "ro", "pe",
}

storage.shared.currentinterface = storage.shared.currentinterface or "en"
storage.shared.currentresponse  = storage.shared.currentresponse  or "en"

local currentinterface = storage.shared.currentinterface
local currentresponse  = storage.shared.currentresponse

local complete = { } interfaces.complete = complete

setmetatable(complete, { __index = function(t,k)
    report_interface("loading interface definitions from 'mult-def.lua'")
    complete = dofile(resolvers.findfile("mult-def.lua"))
    report_interface("loading interface messages from 'mult-mes.lua'")
    complete.messages = dofile(resolvers.findfile("mult-mes.lua"))
    interfaces.complete = complete
    return complete[k]
end } )

local messages  = interfaces.messages
local constants = interfaces.constants
local variables = interfaces.variables
local elements  = interfaces.elements
local reporters = { } -- just an optimization

local valueiskey = { __index = function(t,k) t[k] = k return k end }

setmetatable(variables,valueiskey)
setmetatable(constants,valueiskey)
setmetatable(elements, valueiskey)

setmetatable(messages,  { __index = function(t,k) local v = { }         ; t[k] = v ; return v end })
setmetatable(reporters, { __index = function(t,k) local v = logs.new(k) ; t[k] = v ; return v end })

for category, m in next, messages do
    -- We pre-create reporters for already defined messages
    -- because otherwise listing is incomplete and we want
    -- to use that for checking so delaying makes not much
    -- sense there.
    local r = reporters[m.title or category]
end

function interfaces.setmessages(category,str)
    local m = messages[category]
    for k, v in gmatch(str,"(%S+) *: *(.-) *[\n\r]") do
        m[k] = gsub(v,"%-%-","%%s")
    end
    messages[category] = m
end

function interfaces.setmessage(category,tag,message)
    local m = messages[category]
    m[tag] = gsub(message,"%-%-","%%s")
end

function interfaces.getmessage(category,tag,default)
    local m = messages[category]
    return (m and m[tag]) or default or "unknown message"
end

function interfaces.doifelsemessage(category,tag)
    local m = messages[category]
    return commands.testcase(m and m[tag])
end

local messagesplitter = lpeg.splitat(",")

local function makemessage(category,tag,arguments)
    local m = messages[category]
    m = (m and (m[tag] or m[tostring(tag)])) or format("unknown message, category '%s', tag '%s'",category,tag)
    if not m then
        return m .. " " .. tag
    elseif not arguments then
        return m
    else
        return format(m,lpegmatch(messagesplitter,arguments))
    end
end

interfaces.makemessage = makemessage

function interfaces.showmessage(category,tag,arguments)
    local m = messages[category]
    local t = m and m.title or category
    local r = reporters[t]
    r(makemessage(category,tag,arguments))
end

function interfaces.setvariable(variable,given)
    variables[given] = variable
end

function interfaces.setconstant(constant,given)
    constants[given] = constant
end

function interfaces.setelement(element,given)
    elements[given] = element
end

-- status

function commands.writestatus(category,message)
    local r = reporters[category]
    r(message)
end

-- initialization

function interfaces.setuserinterface(interface,response)
 -- texsprint(format("\\input{mult-%s}", interface))
 -- texsprint(format("\\input{mult-m%s}", response))
    storage.shared.currentinterface, currentinterface = interface, interface
    storage.shared.currentresponse, currentresponse  = response, response
    if environment.initex then
        local nofconstants = 0
        for given, constant in next, complete.constants do
            constant = constant[interface] or constant.en or given
            constants[constant] = given -- breedte -> width
            texsprint("\\do@sicon{",given,"}{",constant,"}")
            nofconstants = nofconstants + 1
        end
        local nofvariables = 0
        for given, variable in next, complete.variables do
            variable = variable[interface] or variable.en or given
            variables[given] = variable -- ja -> yes
            texsprint("\\do@sivar{",given,"}{",variable,"}")
            nofvariables = nofvariables + 1
        end
        local nofelements = 0
        for given, element in next, complete.elements do
            element = element[interface] or element.en or given
            elements[element] = given
            texsprint("\\do@siele{",given,"}{",element,"}")
            nofelements = nofelements + 1
        end
        local nofcommands = 0
        for given, command in next, complete.commands do
            command = command[interface] or command.en or given
            if command ~= given then
                texsprint("\\do@sicom{",given,"}{",command,"}")
            end
            nofcommands = nofcommands + 1
        end
        local nofmessages = 0
        for category, message in next, complete.messages do
            local m = messages[category]
            for tag, set in next, message do
                if tag ~= "files" then
                    m[tag] = set[interface] or set.en -- there are no --'s any longer in the lua file
                end
            end
            nofmessages = nofmessages + 1
        end
        report_interface("definitions: %s constants, %s variables, %s elements, %s commands, %s message groups",
            nofconstants,nofvariables,nofelements,nofcommands,nofmessages)
    end
end

-- it's nicer to have numbers as reference than a hash

interfaces.cachedsetups = interfaces.cachedsetups or { }
interfaces.hashedsetups = interfaces.hashedsetups or { }

storage.register("interfaces/cachedsetups", interfaces.cachedsetups, "interfaces.cachedsetups")
storage.register("interfaces/hashedsetups", interfaces.hashedsetups, "interfaces.hashedsetups")

local cachedsetups = interfaces.cachedsetups
local hashedsetups = interfaces.hashedsetups

function interfaces.cachesetup(t)
    local hash = serialize(t)
    local done = hashedsetups[hash]
    if done then
        return cachedsetups[done]
    else
        done = #cachedsetups + 1
        cachedsetups[done] = t
        hashedsetups[hash] = done
        return t
    end
end

function interfaces.is_command(str)
    return (str and str ~= "" and token.csname_name(token.create(str)) ~= "") or false -- there will be a proper function for this
end

function interfaces.interfacedcommand(name)
    local command = complete.commands[name]
    return command and command[currentinterface] or name
end

if not modules then modules = { } end modules ['mult-ini'] = {
    version   = 1.001,
    comment   = "companion to mult-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local format, gmatch, gsub, match = string.format, string.gmatch, string.gsub, string.match
local lpegmatch = lpeg.match
local serialize = table.serialize

local allocate          = utilities.storage.allocate
local mark              = utilities.storage.mark
local contextsprint     = context.sprint
local setmetatableindex = table.setmetatableindex

local report_interface  = logs.reporter("interface","initialization")

interfaces                = interfaces                     or { }
interfaces.constants      = mark(interfaces.constants      or { })
interfaces.variables      = mark(interfaces.variables      or { })
interfaces.elements       = mark(interfaces.elements       or { })
interfaces.formats        = mark(interfaces.formats        or { })
interfaces.translations   = mark(interfaces.translations   or { })
interfaces.corenamespaces = mark(interfaces.corenamespaces or { })

storage.register("interfaces/constants",      interfaces.constants,      "interfaces.constants")
storage.register("interfaces/variables",      interfaces.variables,      "interfaces.variables")
storage.register("interfaces/elements",       interfaces.elements,       "interfaces.elements")
storage.register("interfaces/formats",        interfaces.formats,        "interfaces.formats")
storage.register("interfaces/translations",   interfaces.translations,   "interfaces.translations")
storage.register("interfaces/corenamespaces", interfaces.corenamespaces, "interfaces.corenamespaces")

interfaces.interfaces = {
    "cs", "de", "en", "fr", "it", "nl", "ro", "pe",
}

storage.shared.currentinterface = storage.shared.currentinterface or "en"
storage.shared.currentresponse  = storage.shared.currentresponse  or "en"

local currentinterface = storage.shared.currentinterface
local currentresponse  = storage.shared.currentresponse

local complete      = allocate()
interfaces.complete = complete

local function resolve(t,k) -- one access needed to get loaded
    report_interface("loading interface definitions from 'mult-def.lua'")
    complete = dofile(resolvers.findfile("mult-def.lua"))
    report_interface("loading interface messages from 'mult-mes.lua'")
    complete.messages = dofile(resolvers.findfile("mult-mes.lua"))
    interfaces.complete = complete
    return rawget(complete,k)
end

setmetatableindex(complete, resolve)

local constants      = interfaces.constants
local variables      = interfaces.variables
local elements       = interfaces.elements
local formats        = interfaces.formats
local translations   = interfaces.translations
local corenamespaces = interfaces.corenamespaces
local reporters      = { } -- just an optimization

local function valueiskey(t,k) -- will be helper
    t[k] = k
    return k
end

setmetatableindex(variables,    valueiskey)
setmetatableindex(constants,    valueiskey)
setmetatableindex(elements,     valueiskey)
setmetatableindex(formats,      valueiskey)
setmetatableindex(translations, valueiskey)

function commands.registernamespace(n,namespace)
    corenamespaces[n] = namespace
end

local function resolve(t,k)
    local v = logs.reporter(k)
    t[k] = v
    return v
end

function commands.showassignerror(namespace,key,value,line)
    local ns, instance = match(namespace,"^(%d+)[^%a]+(%a+)")
    if ns then
        namespace = corenamespaces[tonumber(ns)] or ns
    end
    if instance then
        context.writestatus("setup",format("error in line %s, namespace %q, instance %q, key %q",line,namespace,instance,key))
    else
        context.writestatus("setup",format("error in line %s, namespace %q, key %q",line,namespace,key))
    end
end

setmetatableindex(reporters, resolve)

for category, _ in next, translations do
    -- We pre-create reporters for already defined messages
    -- because otherwise listing is incomplete and we want
    -- to use that for checking so delaying makes not much
    -- sense there.
    local r = reporters[category]
end

-- adding messages

local function add(target,tag,values)
    local t = target[tag]
    if not f then
        target[tag] = values
    else
        for k, v in next, values do
            if f[k] then
                -- error
            else
                f[k] = v
            end
        end
    end
end

function interfaces.settranslation(tag,values)
    add(translations,tag,values)
end

function interfaces.setformat(tag,values)
    add(formats,tag,values)
end

-- the old method:

local function fulltag(category,tag)
    tag = gsub(tag,"%-%-","%%s")
    return format("%s:%s",category,tag)
end

function interfaces.setmessages(category,str)
    for tag, message in gmatch(str,"(%S+) *: *(.-) *[\n\r]") do
        if tag == "title" then
            translations[tag] = translations[tag] or tag
        else
            formats[fulltag(category,tag)] = gsub(message,"%-%-","%%s")
        end
    end
end

function interfaces.setmessage(category,tag,message)
    formats[fulltag(category,tag)] = gsub(message,"%-%-","%%s")
end

function interfaces.getmessage(category,tag,default)
    return formats[fulltag(category,tag)] or default or "unknown message"
end

function interfaces.doifelsemessage(category,tag)
    return commands.testcase(formats[fulltag(category,tag)])
end

local splitter = lpeg.splitat(",")

function interfaces.showmessage(category,tag,arguments)
    local r = reporters[category]
    local f = formats[fulltag(category,tag)]
    local t = type(arguments)
    if t == "string" and #arguments > 0 then
        r(f,lpegmatch(splitter,arguments))
    elseif t == "table" then
        r(f,unpack(arguments))
    elseif arguments then
        r(f,arguments)
    else
        r(f)
    end
end

-- till here

function interfaces.setvariable(variable,given)
    variables[given] = variable
end

function interfaces.setconstant(constant,given)
    constants[given] = constant
end

function interfaces.setelement(element,given)
    elements[given] = element
end

-- the real thing:

logs.setmessenger(context.verbatim.ctxreport)

-- status

function commands.writestatus(category,message,...)
    local r = reporters[category]
    r(message,...)
end

-- initialization

function interfaces.setuserinterface(interface,response)
    storage.shared.currentinterface, currentinterface = interface, interface
    storage.shared.currentresponse, currentresponse  = response, response
    if environment.initex then
        local nofconstants = 0
        for given, constant in next, complete.constants do
            constant = constant[interface] or constant.en or given
            constants[constant] = given -- breedte -> width
            contextsprint("\\do@sicon{",given,"}{",constant,"}")
            nofconstants = nofconstants + 1
        end
        local nofvariables = 0
        for given, variable in next, complete.variables do
            variable = variable[interface] or variable.en or given
            variables[given] = variable -- ja -> yes
            contextsprint("\\do@sivar{",given,"}{",variable,"}")
            nofvariables = nofvariables + 1
        end
        local nofelements = 0
        for given, element in next, complete.elements do
            element = element[interface] or element.en or given
            elements[element] = given
            contextsprint("\\do@siele{",given,"}{",element,"}")
            nofelements = nofelements + 1
        end
        local nofcommands = 0
        for given, command in next, complete.commands do
            command = command[interface] or command.en or given
            if command ~= given then
                contextsprint("\\do@sicom{",given,"}{",command,"}")
            end
            nofcommands = nofcommands + 1
        end
        local nofformats = 0
        for given, format in next, complete.messages.formats do
            formats[given] = format[interface] or format.en or given
            nofformats = nofformats + 1
        end
        local noftranslations = 0
        for given, translation in next, complete.messages.translations do
            translations[given] = translation[interface] or translation.en or given
            noftranslations = noftranslations + 1
        end
        report_interface("definitions: %s constants, %s variables, %s elements, %s commands, %s formats, %s translations",
            nofconstants,nofvariables,nofelements,nofcommands,nofformats,noftranslations)
    end
end

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

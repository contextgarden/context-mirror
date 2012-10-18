if not modules then modules = { } end modules ['file-job'] = {
    version   = 1.001,
    comment   = "companion to file-job.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- in retrospect dealing it's not that bad to deal with the nesting
-- and push/poppign at the tex end

local format, gsub, match = string.format, string.gsub, string.match
local insert, remove, concat = table.insert, table.remove, table.concat

local commands, resolvers, context = commands, resolvers, context

local trace_jobfiles  = false  trackers.register("system.jobfiles", function(v) trace_jobfiles = v end)

local report_jobfiles = logs.reporter("system","jobfiles")

local texsetcount    = tex.setcount
local elements       = interfaces.elements
local variables      = interfaces.variables
local logsnewline    = logs.newline
local logspushtarget = logs.pushtarget
local logspoptarget  = logs.poptarget

local v_outer        = variables.outer
local v_text         = variables.text
local v_project      = variables.project
local v_environment  = variables.environment
local v_product      = variables.product
local v_component    = variables.component
local c_prefix       = variables.prefix

-- main code .. there is some overlap .. here we have loc://

local function findctxfile(name) -- loc ? any ?
    if file.is_qualified_path(name) then -- maybe when no suffix do some test for tex
        return name
    elseif not url.hasscheme(name) then
        return resolvers.finders.byscheme("loc",name) or ""
    else
        return resolvers.findtexfile(name) or ""
    end
end

resolvers.findctxfile = findctxfile

function commands.processfile(name)
    name = findctxfile(name)
    if name ~= "" then
        context.input(name)
    end
end

function commands.doifinputfileelse(name)
    commands.doifelse(findctxfile(name) ~= "")
end

function commands.locatefilepath(name)
    context(file.dirname(findctxfile(name)))
end

function commands.usepath(paths)
    resolvers.registerextrapath(paths)
end

function commands.usesubpath(subpaths)
    resolvers.registerextrapath(nil,subpaths)
end

function commands.allinputpaths()
    context(concat(resolvers.instance.extra_paths or { },","))
end

function commands.usezipfile(name,tree)
    if tree and tree ~= "" then
        resolvers.usezipfile(format("zip:///%s?tree=%s",name,tree))
    else
        resolvers.usezipfile(format("zip:///%s",name))
    end
end

local report_system  = logs.reporter("system","options")
local report_options = logs.reporter("used options")

function commands.copyfiletolog(name)
    local f = io.open(name)
    if f then
        logspushtarget("logfile")
        logsnewline()
        report_system("start used options")
        logsnewline()
        for line in f:lines() do
            report_options(line)
        end
        logsnewline()
        report_system("stop used options")
        logsnewline()
        logspoptarget()
        f:close()
    end
end

-- moved from tex to lua:

local texpatterns = { "%s.mkvi", "%s.mkiv", "%s.tex" }
local luapatterns = { "%s.luc", "%s.lua" }
local cldpatterns = { "%s.cld" }
local xmlpatterns = { "%s.xml" }

local uselibrary = commands.uselibrary
local input      = context.input

-- status
--
-- these need to be synced with input stream:

local processstack   = { }
local processedfile  = ""
local processedfiles = { }

function commands.processedfile()
    context(processedfile)
end

function commands.processedfiles()
    context(concat(processedfiles,","))
end

function commands.dostarttextfile(name)
    insert(processstack,name)
    processedfile = name
    insert(processedfiles,name)
end

function commands.dostoptextfile()
    processedfile = remove(processstack) or ""
end

local function startprocessing(name,notext)
    if not notext then
     -- report_system("begin file %s at line %s",name,status.linenumber or 0)
        context.dostarttextfile(name)
    end
end

local function stopprocessing(notext)
    if not notext then
        context.dostoptextfile()
     -- report_system("end file %s at line %s",name,status.linenumber or 0)
    end
end

--

local action  = function(name,foundname) input(foundname) end
local failure = function(name,foundname) end

local function usetexfile(name,onlyonce,notext)
    startprocessing(name,notext)
    uselibrary {
        name     = name,
        patterns = texpatterns,
        action   = action,
        failure  = failure,
        onlyonce = onlyonce,
    }
    stopprocessing(notext)
end

local action  = function(name,foundname) dofile(foundname) end
local failure = function(name,foundname) end

local function useluafile(name,onlyonce,notext)
    uselibrary {
        name     = name,
        patterns = luapatterns,
        action   = action,
        failure  = failure,
        onlyonce = onlyonce,
    }
end

local action  = function(name,foundname) dofile(foundname) end
local failure = function(name,foundname) end

local function usecldfile(name,onlyonce,notext)
    startprocessing(name,notext)
    uselibrary {
        name     = name,
        patterns = cldpatterns,
        action   = action,
        failure  = failure,
        onlyonce = onlyonce,
    }
    stopprocessing(notext)
end

local action  = function(name,foundname) context.xmlprocess(foundname,"main","") end
local failure = function(name,foundname) end

local function usexmlfile(name,onlyonce,notext)
    startprocessing(name,notext)
    uselibrary {
        name     = name,
        patterns = xmlpatterns,
        action   = action,
        failure  = failure,
        onlyonce = onlyonce,
    }
    stopprocessing(notext)
end

commands.usetexfile = usetexfile
commands.useluafile = useluafile
commands.usecldfile = usecldfile
commands.usexmlfile = usexmlfile

local suffixes = {
    mkvi = usetexfile,
    mkiv = usetexfile,
    tex  = usetexfile,
    luc  = useluafile,
    lua  = useluafile,
    cld  = usecldfile,
    xml  = usexmlfile,
    [""] = usetexfile,
}

local function useanyfile(name,onlyonce)
    local s = suffixes[file.suffix(name)]
    if s then
        s(file.removesuffix(name),onlyonce)
    else
        usetexfile(name,onlyonce) -- e.g. ctx file
--~         resolvers.readfilename(name)
    end
end

commands.useanyfile = useanyfile

function resolvers.jobs.usefile(name,onlyonce,notext)
    local s = suffixes[file.suffix(name)]
    if s then
        s(file.removesuffix(name),onlyonce,notext)
    end
end

-- document structure

local report_system = logs.reporter("system")

local textlevel = 0 -- inaccessible for user, we need to define counter textlevel at the tex end

local function dummyfunction() end

local function startstoperror()
    report_system("invalid \\%s%s ... \\%s%s structure",elements.start,v_text,elements.stop,v_text)
    startstoperror = dummyfunction
end

local function starttext()
    if textlevel == 0 then
        if trace_jobfiles then
            report_jobfiles("starting text")
        end
     -- registerfileinfo[begin]jobfilename
        context.dostarttext()
    end
    textlevel = textlevel + 1
    texsetcount("global","textlevel",textlevel)
end

local function stoptext()
    if textlevel == 0 then
        startstoperror()
    elseif textlevel > 0 then
        textlevel = textlevel - 1
    end
    texsetcount("global","textlevel",textlevel)
    if textlevel <= 0 then
        if trace_jobfiles then
            report_jobfiles("stopping text")
        end
        context.dostoptext()
        -- registerfileinfo[end]jobfilename
        context.finalend()
        commands.stoptext = dummyfunction
    end
end

commands.starttext = starttext
commands.stoptext  = stoptext

function commands.forcequitjob(reason)
    if reason then
        report_system("forcing quit: %s",reason)
    else
        report_system("forcing quit")
    end
    context.batchmode()
    while textlevel >= 0 do
        context.stoptext()
    end
end

function commands.forceendjob()
    report_system([[don't use \end to finish a document]])
    context.stoptext()
end

function commands.autostarttext()
    if textlevel == 0 then
        report_system([[auto \starttext ... \stoptext]])
    end
    context.starttext()
end

commands.autostoptext = stoptext

-- project structure

function commands.processfilemany(name)
    useanyfile(name,false)
end

function commands.processfileonce(name)
    useanyfile(name,true)
end

function commands.processfilenone(name)
    -- skip file
end

--

local typestack          = { }
local pathstack          = { }

local currenttype        = v_text
local currentpath        = "."

local tree               = { type = "text", name = "", branches = { } }
local treestack          = { }
local top                = tree.branches
local root               = tree

local project_stack      = { }
local product_stack      = { }
local component_stack    = { }
local environment_stack  = { }

local stacks = {
    [v_project    ] = project_stack,
    [v_product    ] = product_stack,
    [v_component  ] = component_stack,
    [v_environment] = environment_stack,
}

--

local report_system    = logs.reporter("system","structure")
local report_structure = logs.reporter("used structure")

local function pushtree(what,name)
    local t = { }
    top[#top+1] = { type = what, name = name, branches = t }
    insert(treestack,top)
    top = t
end

local function poptree()
    top = remove(treestack)
 -- inspect(top)
end

local function log_tree(top,depth)
    report_structure("%s%s: %s",depth,top.type,top.name)
    local branches = top.branches
    if #branches > 0 then
        depth = depth .. "  "
        for i=1,#branches do
            log_tree(branches[i],depth)
        end
    end
end

local function logtree()
    logspushtarget("logfile")
    logsnewline()
    report_system("start used structure")
    logsnewline()
    root.name = environment.jobname
    log_tree(root,"")
    logsnewline()
    report_system("stop used structure")
    logsnewline()
    logspoptarget()
end

luatex.registerstopactions(logtree)

job.structure            = job.structure or { }
job.structure.collected  = job.structure.collected or { }
job.structure.tobesaved  = root
job.structure.components = { }

local function initialize()
    local function collect(root,result)
        local branches = root.branches
        if branches then
            for i=1,#branches do
                local branch = branches[i]
                if branch.type == "component" then
                    result[#result+1] = branch.name
                end
                collect(branch,result)
            end
        end
        return result
    end
    job.structure.components = collect(job.structure.collected,{})
end

job.register('job.structure.collected',root,initialize)

-- component: small unit, either or not components itself
-- product  : combination of components

local processors = utilities.storage.allocate {
 -- [v_outer] = {
 --     [v_text]        = { "many", context.processfilemany },
 --     [v_project]     = { "once", context.processfileonce },
 --     [v_environment] = { "once", context.processfileonce },
 --     [v_product]     = { "many", context.processfileonce },
 --     [v_component]   = { "many", context.processfilemany },
 -- },
    [v_text] = {
        [v_text]        = { "many", context.processfilemany },
        [v_project]     = { "none", context.processfileonce }, -- none
        [v_environment] = { "once", context.processfileonce }, -- once
        [v_product]     = { "none", context.processfileonce }, -- none
        [v_component]   = { "many", context.processfilemany }, -- many
    },
    [v_project] = {
        [v_text]        = { "many", context.processfilemany },
        [v_project]     = { "none", context.processfilenone }, -- none
        [v_environment] = { "once", context.processfileonce }, -- once
        [v_product]     = { "once", context.processfilenone }, -- once
        [v_component]   = { "none", context.processfilenone }, -- many *
    },
    [v_environment] = {
        [v_text]        = { "many", context.processfilemany },
        [v_project]     = { "none", context.processfilenone }, -- none
        [v_environment] = { "once", context.processfileonce }, -- once
        [v_product]     = { "none", context.processfilenone }, -- none
        [v_component]   = { "none", context.processfilenone }, -- none
    },
    [v_product] = {
        [v_text]        = { "many", context.processfilemany },
        [v_project]     = { "once", context.processfileonce }, -- once
        [v_environment] = { "once", context.processfileonce }, -- once
        [v_product]     = { "none", context.processfilemany }, -- none
        [v_component]   = { "many", context.processfilemany }, -- many
    },
    [v_component] = {
        [v_text]        = { "many", context.processfilemany },
        [v_project]     = { "once", context.processfileonce }, -- once
        [v_environment] = { "once", context.processfileonce }, -- once
        [v_product]     = { "none", context.processfilenone }, -- none
        [v_component]   = { "many", context.processfilemany }, -- many
    }
}

local start = {
    [v_text]        = nil,
    [v_project]     = nil,
    [v_environment] = context.startreadingfile,
    [v_product]     = context.starttext,
    [v_component]   = context.starttext,
}

local stop = {
    [v_text]        = nil,
    [v_project]     = nil,
    [v_environment] = context.stopreadingfile,
    [v_product]     = context.stoptext,
    [v_component]   = context.stoptext,
}

resolvers.jobs.processors = processors

local function topofstack(what)
    local stack = stacks[what]
    return stack and stack[#stack] or environment.jobname
end

local function productcomponent() -- only when in product
    local product = product_stack[#product_stack]
    if product and product ~= "" then
        local component = component_stack[1]
        if component and component ~= "" then
            return component
        end
    end
end

local function justacomponent()
    local product = product_stack[#product_stack]
    if not product or product == "" then
        local component = component_stack[1]
        if component and component ~= "" then
            return component
        end
    end
end

resolvers.jobs.productcomponent = productcomponent
resolvers.jobs.justacomponent   = justacomponent

function resolvers.jobs.currentproject    () return topofstack(v_project    ) end
function resolvers.jobs.currentproduct    () return topofstack(v_product    ) end
function resolvers.jobs.currentcomponent  () return topofstack(v_component  ) end
function resolvers.jobs.currentenvironment() return topofstack(v_environment) end

local done     = { }
local tolerant = false -- too messy, mkii user with the wrong sructure should adapt

local function process(what,name)
    local depth = #typestack
    local process
--  if not tolerant then
        -- okay, would be best but not compatible with mkii
        process = processors[currenttype][what]
--  elseif depth == 0 then
--      -- could be a component, product or (brr) project
--      if trace_jobfiles then
--          report_jobfiles("%s : %s > %s (case 1)",depth,currenttype,v_outer)
--      end
--      process = processors[v_outer][what]
--  elseif depth == 1 and typestack[1] == v_text then
--      -- we're still not doing a component or product
--      if trace_jobfiles then
--          report_jobfiles("%s : %s > %s (case 2)",depth,currenttype,v_outer)
--      end
--      process = processors[v_outer][what]
--  else
--      process = processors[currenttype][what]
--  end
    if process then
        local method = process[1]
        if method == "none" then
            if trace_jobfiles then
                report_jobfiles("%s : %s : ignoring %s '%s' in %s '%s'",depth,method,what,name,currenttype,topofstack(currenttype))
            end
        elseif method == "once" and done[name] then
            if trace_jobfiles then
                report_jobfiles("%s : %s : skipping %s '%s' in %s '%s'",depth,method,what,name,currenttype,topofstack(currenttype))
            end
        else
            -- keep in mind that we also handle "once" at the file level
            -- so there is a double catch
            done[name] = true
            local before = start[what]
            local after  = stop [what]
            if trace_jobfiles then
                report_jobfiles("%s : %s : processing %s '%s' in %s '%s'",depth,method,what,name,currenttype,topofstack(currenttype))
            end
            if before then
                before()
            end
            process[2](name)
            if after then
                after()
            end
        end
    else
        if trace_jobfiles then
            report_jobfiles("%s : ? : ignoring %s '%s' in %s '%s'",depth,what,name,currenttype,topofstack(currenttype))
        end
    end
end

function commands.useproject    (name) process(v_project,    name) end
function commands.useenvironment(name) process(v_environment,name) end
function commands.useproduct    (name) process(v_product,    name) end
function commands.usecomponent  (name) process(v_component,  name) end

-- todo: setsystemmode to currenttype
-- todo: make start/stop commands at the tex end

local start = {
    [v_project]     = context.startprojectindeed,
    [v_product]     = context.startproductindeed,
    [v_component]   = context.startcomponentindeed,
    [v_environment] = context.startenvironmentindeed,
}

local stop = {
    [v_project]     = context.stopprojectindeed,
    [v_product]     = context.stopproductindeed,
    [v_component]   = context.stopcomponentindeed,
    [v_environment] = context.stopenvironmentindeed,
}

local function gotonextlevel(what,name) -- todo: something with suffix name
    insert(stacks[what],name)
    insert(typestack,currenttype)
    insert(pathstack,currentpath)
    currenttype = what
    currentpath = file.dirname(name)
    pushtree(what,name)
    if start[what] then
        start[what]()
    end
end

local function gotopreviouslevel(what)
    if stop[what] then
        stop[what]()
    end
    poptree()
    currentpath = remove(pathstack) or "."
    currenttype = remove(typestack) or v_text
    remove(stacks[what]) -- not currenttype ... weak recovery
 -- context.endinput() -- does not work
    context.signalendofinput(what)
end

function commands.startproject    (name) gotonextlevel(v_project,    name) end
function commands.startproduct    (name) gotonextlevel(v_product,    name) end
function commands.startcomponent  (name) gotonextlevel(v_component,  name) end
function commands.startenvironment(name) gotonextlevel(v_environment,name) end

function commands.stopproject    () gotopreviouslevel(v_project    ) end
function commands.stopproduct    () gotopreviouslevel(v_product    ) end
function commands.stopcomponent  () gotopreviouslevel(v_component  ) end
function commands.stopenvironment() gotopreviouslevel(v_environment) end

function commands.currentproject    () context(topofstack(v_project    )) end
function commands.currentproduct    () context(topofstack(v_product    )) end
function commands.currentcomponent  () context(topofstack(v_component  )) end
function commands.currentenvironment() context(topofstack(v_environment)) end

-- -- -- this will move -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --
--
--  <?xml version='1.0' standalone='yes'?>
--  <exa:variables xmlns:exa='htpp://www.pragma-ade.com/schemas/exa-variables.rng'>
--      <exa:variable label='mode:pragma'>nee</exa:variable>
--      <exa:variable label='mode:variant'>standaard</exa:variable>
--  </exa:variables>
--
-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

local report_examodes = logs.reporter("system","examodes")

local function convertexamodes(str)
    local x = xml.convert(str)
    for e in xml.collected(x,"exa:variable") do
        local label = e.at and e.at.label
        if label and label ~= "" then
            local data = xml.text(e)
            local mode = match(label,"^mode:(.+)$")
            if mode then
                context.enablemode { format("%s:%s",mode,data) }
            end
            context.setvariable("exa:variables",label,(gsub(data,"([{}])","\\%1")))
        end
    end
end

function commands.loadexamodes(filename)
    if not filename or filename == "" then
        filename = file.removesuffix(tex.jobname)
    end
    filename = resolvers.findfile(file.addsuffix(filename,'ctm')) or ""
    if filename ~= "" then
        report_examodes("loading %s",filename) -- todo: message system
        convertexamodes(io.loaddata(filename))
    else
        report_examodes("no mode file %s",filename) -- todo: message system
    end
end

if not modules then modules = { } end modules ['strc-ref'] = {
    version   = 1.001,
    comment   = "companion to strc-ref.tex",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local format, gmatch, texsprint, texwrite, count = string.format, string.gmatch, tex.sprint, tex.write, tex.count

local ctxcatcodes = tex.ctxcatcodes

-- beware, this is a first step in the rewrite (just getting rid of
-- the tuo file); later all access and parsing will also move to lua

jobreferences           = jobreferences or { }
jobreferences.tobesaved = jobreferences.tobesaved or { }
jobreferences.collected = jobreferences.collected or { }
jobreferences.documents = jobreferences.documents or { }
jobreferences.defined   = jobreferences.defined   or { } -- indirect ones
jobreferences.derived   = jobreferences.derived   or { } -- taken from lists
jobreferences.specials  = jobreferences.specials  or { } -- system references
jobreferences.runners   = jobreferences.runners   or { }
jobreferences.internals = jobreferences.internals or { }

storage.register("jobreferences/defined", jobreferences.defined, "jobreferences.defined")

local tobesaved, collected = jobreferences.tobesaved, jobreferences.collected
local defined, derived, specials, runners = jobreferences.defined, jobreferences.derived, jobreferences.specials, jobreferences.runners

local currentreference = nil

jobreferences.initializers = jobreferences.initializers or { }

function jobreferences.registerinitializer(func) -- we could use a token register instead
    jobreferences.initializers[#jobreferences.initializers+1] = func
end

local function initializer()
    tobesaved, collected = jobreferences.tobesaved, jobreferences.collected
    for k,v in ipairs(jobreferences.initializers) do
        v(tobesaved,collected)
    end
end

if job then
    job.register('jobreferences.collected', jobreferences.tobesaved, initializer)
end

function jobreferences.set(kind,prefix,tag,data)
    for ref in gmatch(tag,"[^,]+") do
        local p, r = ref:match("^(%-):(.-)$")
        if p and r then
            prefix, ref = p, r
        else
            prefix = ""
        end
        if ref ~= "" then
            local pd = tobesaved[prefix]
            if not pd then
                pd = { }
                tobesaved[prefix] = pd
            end
            pd[ref] = data
            texsprint(ctxcatcodes,format("\\dofinish%sreference{%s}{%s}",kind,prefix,ref))
        end
    end
end

function jobreferences.enhance(prefix,tag,spec)
    local l = tobesaved[prefix][tag]
    if l then
        l.references.realpage = tex.count[0]
    end
end

-- this reference parser is just an lpeg version of the tex based one

local result = { }

local lparent, rparent, lbrace, rbrace, dcolon = lpeg.P("("), lpeg.P(")"), lpeg.P("{"), lpeg.P("}"), lpeg.P("::")

local reset     = lpeg.P("")                          / function (s) result           = { } end
local outer     = (1-dcolon-lparent-lbrace        )^1 / function (s) result.outer     = s   end
local operation = (1-rparent-rbrace-lparent-lbrace)^1 / function (s) result.operation = s   end
local arguments = (1-rbrace                       )^0 / function (s) result.arguments = s   end
local special   = (1-lparent-lbrace-lparent-lbrace)^1 / function (s) result.special   = s   end
local inner     = (1-lparent-lbrace               )^1 / function (s) result.inner     = s   end

local outer_reference    = (outer * dcolon)^0

operation = outer_reference * operation -- special case: page(file::1) and file::page(1)

local optional_arguments = (lbrace  * arguments * rbrace)^0
local inner_reference    = inner * optional_arguments
local special_reference  = special * lparent * (operation * optional_arguments + operation^0) * rparent

local scanner = (reset * outer_reference * (special_reference + inner_reference)^-1 * -1) / function() return result end

function jobreferences.analyse(str)
    return scanner:match(str)
end

local splittemplate = "\\setreferencevariables{%s}{%s}{%s}{%s}{%s}" -- will go away

function jobreferences.split(str)
    local t = scanner:match(str or "")
    texsprint(ctxcatcodes,format(splittemplate,t.special or "",t.operation or "",t.arguments or "",t.outer or "",t.inner or ""))
    return t
end

--~ print(table.serialize(jobreferences.analyse("")))
--~ print(table.serialize(jobreferences.analyse("inner")))
--~ print(table.serialize(jobreferences.analyse("special(operation{argument,argument})")))
--~ print(table.serialize(jobreferences.analyse("special(operation)")))
--~ print(table.serialize(jobreferences.analyse("special()")))
--~ print(table.serialize(jobreferences.analyse("inner{argument}")))
--~ print(table.serialize(jobreferences.analyse("outer::")))
--~ print(table.serialize(jobreferences.analyse("outer::inner")))
--~ print(table.serialize(jobreferences.analyse("outer::special(operation{argument,argument})")))
--~ print(table.serialize(jobreferences.analyse("outer::special(operation)")))
--~ print(table.serialize(jobreferences.analyse("outer::special()")))
--~ print(table.serialize(jobreferences.analyse("outer::inner{argument}")))
--~ print(table.serialize(jobreferences.analyse("special(outer::operation)")))

-- -- -- related to strc-ini.lua -- -- --

jobreferences.resolvers = jobreferences.resolvers or { }

function jobreferences.resolvers.section(var)
    local vi = structure.lists.collected[var.i[2]]
    if vi then
        var.i = vi
        var.r = (vi.references and vi.references.realpage) or 1
    else
        var.i = nil
        var.r = 1
    end
end

jobreferences.resolvers.float       = jobreferences.resolvers.section
jobreferences.resolvers.description = jobreferences.resolvers.section
jobreferences.resolvers.formula     = jobreferences.resolvers.section
jobreferences.resolvers.note        = jobreferences.resolvers.section

function jobreferences.resolvers.reference(var)
    local vi = var.i[2]
    if vi then
        var.i = vi
        var.r = (vi.references and vi.references.realpage) or 1
    else
        var.i = nil
        var.r = 1
    end
end

local function register_from_lists(collected,derived)
    for i=1,#collected do
        local entry = collected[i]
        local m, r = entry.metadata, entry.references
        if m and r then
            local prefix, reference = r.referenceprefix or "", r.reference or ""
            if reference ~= "" then
                local kind, realpage = m.kind, r.realpage
                if kind and realpage then
                    local d = derived[prefix] if not d then d = { } derived[prefix] = d end
                    d[reference] = { kind, i }
                end
            end
        end
    end
end

jobreferences.registerinitializer(function() register_from_lists(structure.lists.collected,derived) end)

-- urls

jobreferences.urls      = jobreferences.urls      or { }
jobreferences.urls.data = jobreferences.urls.data or { }

local urls = jobreferences.urls.data

function jobreferences.urls.define(name,url,file,description)
    if name and name ~= "" then
        urls[name] = { url or "", file or "", description or url or file or ""}
    end
end

function jobreferences.urls.get(name,method,space) -- method: none, before, after, both, space: yes/no
    local u = urls[name]
    if u then
        local url, file = u[1], u[2]
        if file ~= "" then
            texsprint(ctxcatcodes,url,"/",file)
        else
            texsprint(ctxcatcodes,url)
        end
    end
end

-- files

jobreferences.files      = jobreferences.files      or { }
jobreferences.files.data = jobreferences.files.data or { }

local files = jobreferences.files.data

function jobreferences.files.define(name,file,description)
    if name and name ~= "" then
        files[name] = { file or "", description or file or ""}
    end
end

function jobreferences.files.get(name,method,space) -- method: none, before, after, both, space: yes/no
    local f = files[name]
    if f then
        texsprint(ctxcatcodes,f[1])
    end
end

-- programs

jobreferences.programs      = jobreferences.programs      or { }
jobreferences.programs.data = jobreferences.programs.data or { }

local programs = jobreferences.programs.data

function jobreferences.programs.define(name,file,description)
    if name and name ~= "" then
        programs[name] = { file or "", description or file or ""}
    end
end

function jobreferences.programs.get(name)
    local f = programs[name]
    if f then
        texsprint(ctxcatcodes,f[1])
    end
end

-- shared by urls and files

function jobreferences.from(name,method,space)
    local u = urls[name]
    if u then
        local url, file, description = u[1], u[2], u[3]
        if description ~= "" then
            texsprint(ctxcatcodes,description)
        elseif file then
            texsprint(ctxcatcodes,url,"/",file)
        else
            texsprint(ctxcatcodes,url)
        end
    else
        local f = files[name]
        if f then
            local description, file = f[1], f[2]
            if description ~= "" then
                texsprint(ctxcatcodes,description)
            else
                texsprint(ctxcatcodes,file)
            end
        end
    end
end

function jobreferences.load(name)
    if name then
        local jdn = jobreferences.documents[name]
        if not jdn then
            jdn = { }
            local fn = files[name]
            if fn then
                jdn.filename = fn[1]
                local data = io.loaddata(file.replacesuffix(fn[1],"tuc")) or ""
                if data ~= "" then
                    -- quick and dirty, assume sane { } usage inside strings
                    local lists = data:match("structure%.lists%.collected=({.-[\n\r]+})[\n\r]")
                    if lists and lists ~= "" then
                        lists = loadstring("return" .. lists)
                        if lists then
                            jdn.lists = lists()
                            jdn.derived = { }
                            register_from_lists(jdn.lists,jdn.derived)
                        else
                            commands.writestatus("error","invalid structure data in %s",filename)
                        end
                    end
                    local references = data:match("jobreferences%.collected=({.-[\n\r]+})[\n\r]")
                    if references and references ~= "" then
                        references = loadstring("return" .. references)
                        if references then
                            jdn.references = references()
                        else
                            commands.writestatus("error","invalid reference data in %s",filename)
                        end
                    end
                end
            end
            jobreferences.documents[name] = jdn
        end
        return jdn
    else
        return nil
    end
end

function jobreferences.define(prefix,reference,list)
    local d = defined[prefix] if not d then d = { } defined[prefix] = d end
    d[reference] = { "defined", list }
end

--~ function jobreferences.registerspecial(name,action,...)
--~     specials[name] = { action, ... }
--~ end

function jobreferences.reset(prefix,reference)
    local d = defined[prefix]
    if d then
        d[reference] = nil
    end
end

-- \primaryreferencefoundaction
-- \secondaryreferencefoundaction
-- \referenceunknownaction

-- t.special t.operation t.arguments t.outer t.inner

local settings_to_array = aux.settings_to_array

local function resolve(prefix,reference,args,set) -- we start with prefix,reference
    if reference and reference ~= "" then
        set = set or { }
        local r = settings_to_array(reference)
        for i=1,#r do
            local ri = r[i]
            local d = defined[prefix][ri] or defined[""][ri]
            if d then
                resolve(prefix,d[2],nil,set)
            else
                local var = scanner:match(ri)
                if var then
                    var.reference = ri
                    if not var.outer and var.inner then
                        local d = defined[prefix][var.inner] or defined[""][var.inner]
                        if d then
                            resolve(prefix,d[2],var.arguments,set) -- args can be nil
                        else
                            if args then var.arguments = args end
                            set[#set+1] = var
                        end
                    else
                        if args then var.arguments = args end
                        set[#set+1] = var
                    end
                else
                --  logs.report("references","funny pattern: %s",ri or "?")
                end
            end
        end
        return set
    else
        return { }
    end
end

-- prefix == "" is valid prefix which saves multistep lookup

local function identify(prefix,reference)
    local set = resolve(prefix,reference)
    local bug = false
    for i=1,#set do
        local var = set[i]
        local special, inner, outer, arguments, operation = var.special, var.inner, var.outer, var.arguments, var.operation
        if special then
            local s = specials[special]
--~ print(table.serialize(specials))
            if s then
                if outer then
                    if operation then
                        -- special(outer::operation)
                        var.kind = "special outer with operation"
                    else
                        -- special()
                        var.kind = "special outer"
                    end
                elseif operation then
                    if arguments then
                        -- special(operation{argument,argument})
                        var.kind = "special operation with arguments"
                    else
                        -- special(operation)
                        var.kind = "special operation"
                    end
                else
                    -- special()
                    var.kind = "special"
                end
            else
                var.error = "unknown special"
            end
        elseif outer then
            local e = jobreferences.load(outer)
            if e then
                local f = e.filename
                if f then
                    if inner then
                        local r = e.references
                        if r then
                            r = r[prefix]
                            if r then
                                r = r[inner]
                                if r then
                                    if arguments then
                                        -- outer::inner{argument}
                                        var.kind = "outer with inner with arguments"
                                    else
                                        -- outer::inner
                                        var.kind = "outer with inner"
                                    end
                                    var.i = { "reference", r }
                                    jobreferences.resolvers.reference(var)
                                    var.f = f
                                end
                            end
                        end
                        if not r then
                            r = e.derived
                            if r then
                                r = r[prefix]
                                if r then
                                    r = r[inner]
                                    if r then
                                        -- outer::inner
                                        if arguments then
                                            -- outer::inner{argument}
                                            var.kind = "outer with inner with arguments"
                                        else
                                            -- outer::inner
                                            var.kind = "outer with inner"
                                        end
                                        var.i = r
                                        jobreferences.resolvers[r[1]](var)
                                        var.f = f
                                    end
                                end
                            end
                        end
                        if not r then
                            var.error = "unknown outer"
                        end
                    elseif special then
                        local s = specials[special]
                        if s then
                            if operation then
                                if arguments then
                                    -- outer::special(operation{argument,argument})
                                    var.kind = "outer with special and operation and arguments"
                                else
                                    -- outer::special(operation)
                                    var.kind = "outer with special and operation"
                                end
                            else
                                -- outer::special()
                                var.kind = "outer with special"
                            end
                            var.f = f
                        else
                            var.error = "unknown outer with special"
                        end
                    else
                        -- outer::
                        var.kind = "outer"
                        var.f = f
                    end
                else
                    var.error = "unknown outer"
                end
            else
                var.error = "unknown outer"
            end
        else
            if arguments then
                local s = specials[inner]
                if s then
                    -- inner{argument}
                    var.kind = "special with arguments"
                else
                    var.error = "unknown inner or special"
                end
            else
                -- inner
--~                 local i = tobesaved[prefix]
                local i = collected[prefix]
                i = i and i[inner]
                if i then
                    var.i = { "reference", i }
                    jobreferences.resolvers.reference(var)
                    var.kind = "inner"
                    var.p = prefix
                else
                    i = derived[prefix]
                    i = i and i[inner]
                    if i then
                        var.kind = "inner"
                        var.i = i
                        jobreferences.resolvers[i[1]](var)
                        var.p = prefix
                    else
                        i = collected[prefix]
                        i = i and i[inner]
                        if i then
                            var.kind = "inner"
                            var.i = { "reference", i }
                            jobreferences.resolvers.reference(var)
                            var.p = prefix
                        else
                            local s = specials[inner]
                            if s then
                                var.kind = "special"
                            else
--~                                 i = (tobesaved[""] and tobesaved[""][inner]) or
--~                                     (derived  [""] and derived  [""][inner]) or
--~                                     (collected[""] and collected[""][inner])
                                i = (collected[""] and collected[""][inner]) or
                                    (derived  [""] and derived  [""][inner]) or
                                    (tobesaved[""] and tobesaved[""][inner])
                                if i then
                                    var.kind = "inner"
                                    var.i = { "reference", i }
                                    jobreferences.resolvers.reference(var)
                                    var.p = ""
                                else
                                    var.error = "unknown inner or special"
                                end
                            end
                        end
                    end
                end
            end
        end
        bug = bug or var.error
        set[i] = var
    end
--~ print(prefix,reference,table.serialize(set))
    return set, bug
end

jobreferences.identify = identify

function jobreferences.doifelse(prefix,reference)
    local set, bug = identify(prefix,reference)
    local unknown = bug or #set == 0
    if unknown then
        currentreference = nil
    else
        currentreference = set[1]
    end
    commands.doifelse(not unknown)
end

function jobreferences.analysis(prefix,reference)
    local set, bug = identify(prefix,reference)
    local unknown = bug or #set == 0
    if unknown then
        currentreference = nil
        texwrite(0) -- unknown
    else
        currentreference = set[1]
        texwrite(1) -- whatever
--~         texwrite(2) -- forward, following page
--~         texwrite(3) -- backward, preceding page
--~         texwrite(4) -- forward, same page
--~         texwrite(5) -- backward, same page
    end
end

function jobreferences.handle(prefix,reference) -- todo: use currentreference is possible
    local set, bug = identify(prefix,reference)
    if bug or #set == 0 then
        texsprint(ctxcatcodes,"\\referenceunknownaction")
    else
        for i=2,#set do
            local s = set[i]
currentreference = s
            -- not that needed, but keep it for a while
            texsprint(ctxcatcodes,format(splittemplate,s.special or "",s.operation or "",s.arguments or "",s.outer or "",s.inner or ""))
            --
            if s.error then
                texsprint(ctxcatcodes,"\\referenceunknownaction")
            else
                local runner = runners[s.kind]
                if runner then
                    texsprint(ctxcatcodes,runner(s,"\\secondaryreferencefoundaction"))
                end
            end
        end
        local s = set[1]
currentreference = s
        -- not that needed, but keep it for a while
        texsprint(ctxcatcodes,format(splittemplate,s.special or "",s.operation or "",s.arguments or "",s.outer or "",s.inner or ""))
        --
        if s.error then
            texsprint(ctxcatcodes,"\\referenceunknownaction")
        else
            local runner = runners[s.kind]
            if runner then
                texsprint(ctxcatcodes,runner(s,"\\primaryreferencefoundaction"))
            end
        end
    end
end

local thisdestinationyes = "\\thisisdestination{%s:%s}"
local thisdestinationnop = "\\thisisdestination{%s}"
local thisdestinationaut = "\\thisisdestination{aut:%s}"

function jobreferences.setinternalreference(prefix,tag,internal)
    if tag then
        for ref in gmatch(tag,"[^,]+") do
            if not prefix or prefix == "" then
                texsprint(ctxcatcodes,format(thisdestinationnop,ref))
            else
                texsprint(ctxcatcodes,format(thisdestinationyes,prefix,ref))
            end
        end
    end
    texsprint(ctxcatcodes,format(thisdestinationaut,internal))
 -- texsprint(ctxcatcodes,"[["..internal.."]]")
end

--

jobreferences.filters = jobreferences.filters or { }

local filters  = jobreferences.filters
local helpers  = structure.helpers
local sections = structure.sections

function jobreferences.filter(name) -- number page title ...
    local data = currentreference and currentreference.i
    if data then
        local kind = data.metadata and data.metadata.kind
        if kind then
            local filter = filters[kind] or filters.generic
            filter = filter and (filter[name] or filters.generic[name])
            if filter then
                filter(data)
            end
        end
    end
end

filters.generic = { }

function filters.generic.title(data)
    if data then
        local titledata = data.titledata
        if titledata then
            helpers.title(titledata.title or "?",data.metadata)
        end
    end
end

function filters.generic.number(data) -- todo: spec and then no stopper
    if data then
        helpers.prefix(data)
        local numberdata = data.numberdata
        if numberdata then
            sections.typesetnumber(numberdata,"number",numberdata or false)
        end
    end
end

function filters.generic.page(data,prefixspec,pagespec)
    helpers.prefixpage(data,prefixspec,pagespec)
end

filters.text = { }

function filters.text.title(data)
--  texsprint(ctxcatcodes,"[text title]")
    helpers.title(data.entries.text or "?",data.metadata)
end

function filters.text.number(data)
--  texsprint(ctxcatcodes,"[text number]")
    helpers.title(data.entries.text or "?",data.metadata)
end

function filters.text.page(data,prefixspec,pagespec)
    helpers.prefixpage(data,prefixspec,pagespec)
end

--~ filters.section = { }

--~ filters.section.title  = filters.generic.title
--~ filters.section.number = filters.generic.number
--~ filters.section.page   = filters.generic.page

--~ filters.float = { }

--~ filters.float.title  = filters.generic.title
--~ filters.float.number = filters.generic.number
--~ filters.float.page   = filters.generic.page

-- each method gets its own call, so that we can later move completely to lua

local gotoinner             = "\\gotoinner{%s}{%s}{%s}{%s}"              -- prefix inner page data
local gotoouterfilelocation = "\\gotoouterfilelocation{%s}{%s}{%s}{%s}"  -- file location page data
local gotoouterfilepage     = "\\gotoouterfilepage{%s}{%s}{%s}"          -- file page data
local gotoouterurl          = "\\gotoouterurl{%s}{%s}{%s}"               -- url args data
local gotoinnerpage         = "\\gotoinnerpage{%s}{%s}"                  -- page data
local gotospecial           = "\\gotospecial{%s}{%s}{%s}{%s}{%s}"        -- action, special, operation, arguments, data

runners["inner"] = function(var,content)
    -- inner
    currentreference = var
    local r = var.r
    return (r and format(gotoinner,var.p or "",var.inner,r,content)) or "error"
end

runners["inner with arguments"] = function(var,content)
    -- inner{argument}
    currentreference = var
    return "todo: " .. var.kind or "?"
end

runners["outer"] = function(var,content)
    -- outer::
    -- todo: resolve url/file name
    currentreference = var
    local url = ""
    local file = var.o
    return format(gotoouterfilepage,url,file,1,content)
end

runners["outer with inner"] = function(var,content)
    -- outer::inner
    -- todo: resolve url/file name
    currentreference = var
    local r = var.r
    return (r and format(gotoouterfilelocation,var.f,var.inner,r,content)) or "error"
end

runners["special outer with operation"] = function(var,content)
    -- special(outer::operation)
    currentreference = var
    return "todo: " .. var.kind or "?"
end

runners["special outer"] = function(var,content)
    -- special()
    currentreference = var
    return "todo: " .. var.kind or "?"
end

runners["special"] = function(var,content)
    -- special(operation)
    currentreference = var
    local handler = specials[var.special]
    if handler then
        return handler(var,content) -- var.special wegwerken
    else
        return ""
    end
end

runners["outer with inner with arguments"] = function(var,content)
    -- outer::inner{argument}
    currentreference = var
    return "todo: " .. var.kind or "?"
end

runners["outer with special and operation and arguments"] = function(var,content)
    -- outer::special(operation{argument,argument})
    currentreference = var
    return "todo: " .. var.kind or "?"
end

runners["outer with special"] = function(var,content)
    -- outer::special()
    currentreference = var
    return "todo: " .. var.kind or "?"
end

runners["outer with special and operation"] = function(var,content)
    -- outer::special(operation)
    currentreference = var
    return "todo: " .. var.kind or "?"
end

runners["special operation"]                = runners["special"]
runners["special operation with arguments"] = runners["special"]

local gotoactionspecial     = "\\gotoactionspecial{%s}{%s}{%s}{%s}"
local gotopagespecial       = "\\gotopagespecial{%s}{%s}{%s}{%s}"
local gotourlspecial        = "\\gotourlspecial{%s}{%s}{%s}{%s}"
local gotofilespecial       = "\\gotofilespecial{%s}{%s}{%s}{%s}"
local gotoprogramspecial    = "\\gotoprogramspecial{%s}{%s}{%s}{%s}"
local gotojavascriptspecial = "\\gotojavascriptspecial{%s}{%s}{%s}{%s}"

function specials.action(var,content)
    return format(gotoactionspecial,var.special,var.operation,var.arguments or "",content)
end

function specials.page(var,content)
    -- we need to deal with page(inner) and page(outer::1) and outer::page(1)
    return format(gotopagespecial,var.special,var.operation,var.arguments or "",content)
end

function specials.url(var,content)
    local url = var.operation
    if url then
        local u = urls[url]
        if u then
            local u, f = u[1], u[2]
            if f and f ~= "" then
                url = u .. "/" .. f
            else
                url = u
            end
        end
    end
    return format(gotourlspecial,var.special,url,var.arguments or "",content)
end

function specials.file(var,content)
    local file = var.operation
    if file then
        local f = files[file]
        if f then
            file = f[1]
        end
    end
    return format(gotofilespecial,var.special,file,var.arguments or "",content)
end

function specials.program(var,content)
    local program = var.operation
    if program then
        local p = programs[program]
        if p then
            programs = p[1]
        end
    end
    return format(gotoprogramspecial,var.special,program,var.arguments or "",content)
end

function specials.javascript(var,content)
    -- todo: store js code in lua
    return format(gotojavascriptspecial,var.special,var.operation,var.arguments or "",content)
end

specials.JS = specials.javascript

structure.references = structure.references or { }
structure.helpers    = structure.helpers    or { }

local references = structure.references
local helpers    = structure.helpers

function references.sectiontitle(n)
    helpers.sectiontitle(lists.collected[tonumber(n) or 0])
end

function references.sectionnumber(n)
    helpers.sectionnumber(lists.collected[tonumber(n) or 0])
end

function references.sectionpage(n,prefixspec,pagespec)
    helpers.prefixedpage(lists.collected[tonumber(n) or 0],prefixspec,pagespec)
end


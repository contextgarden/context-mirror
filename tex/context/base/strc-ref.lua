if not modules then modules = { } end modules ['strc-ref'] = {
    version   = 1.001,
    comment   = "companion to strc-ref.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local format, find, gmatch, match, concat = string.format, string.find, string.gmatch, string.match, table.concat
local lpegmatch, lpegP, lpegCs = lpeg.match, lpeg.P, lpeg.Cs
local texcount, texsetcount = tex.count, tex.setcount
local allocate, mark = utilities.storage.allocate, utilities.storage.mark
local setmetatable, rawget = setmetatable, rawget

local allocate = utilities.storage.allocate

local trace_referencing = false  trackers.register("structures.referencing", function(v) trace_referencing = v end)

local report_references = logs.reporter("structure","references")

local variables   = interfaces.variables
local constants   = interfaces.constants
local context     = context

local settings_to_array = utilities.parsers.settings_to_array
local unsetvalue        = attributes.unsetvalue

-- beware, this is a first step in the rewrite (just getting rid of
-- the tuo file); later all access and parsing will also move to lua

-- the useddata and pagedata names might change
-- todo: pack exported data

local structures      = structures
local helpers         = structures.helpers
local sections        = structures.sections
local references      = structures.references
local lists           = structures.lists
local counters        = structures.counters

-- some might become local

references.defined   = references.defined or allocate()

local defined        = references.defined
local derived        = allocate()
local specials       = { } -- allocate()
local runners        = { } -- allocate()
local internals      = allocate()
local exporters      = allocate()
local imported       = allocate()
local filters        = allocate()
local executers      = allocate()
local handlers       = allocate()
local tobesaved      = allocate()
local collected      = allocate()
local tobereferred   = allocate()
local referred       = allocate()

references.derived      = derived
references.specials     = specials
references.runners      = runners
references.internals    = internals
references.exporters    = exporters
references.imported     = imported
references.filters      = filters
references.executers    = executers
references.handlers     = handlers
references.tobesaved    = tobesaved
references.collected    = collected
references.tobereferred = tobereferred
references.referred     = referred

storage.register("structures/references/defined", references.defined, "structures.references.defined")

local currentreference = nil

local initializers = { }
local finalizers   = { }

function references.registerinitializer(func) -- we could use a token register instead
    initializers[#initializers+1] = func
end
function references.registerfinalizer(func) -- we could use a token register instead
    finalizers[#finalizers+1] = func
end

local function initializer() -- can we use a tobesaved as metatable for collected?
    tobesaved = mark(references.tobesaved)
    collected = mark(references.collected)
    for i=1,#initializers do
        initializers[i](tobesaved,collected)
    end
end

local function finalizer()
 -- tobesaved = mark(references.tobesaved)
    for i=1,#finalizers do
        finalizers[i](tobesaved)
    end
end

job.register('structures.references.collected', tobesaved, initializer, finalizer)

local maxreferred = 1

local function initializer() -- can we use a tobesaved as metatable for collected?
    tobereferred = mark(references.tobereferred)
    referred     = mark(references.referred)

    function get(t,n)    -- catch sparse, a bit slow but who cares
        for i=n,1,-1 do  -- we could make a tree ... too much work
            local p = rawget(t,i)
            if p then
                return p
            end
        end
    end
    setmetatable(referred, { __index = get })
end

local function finalizer() -- make sparse
    local last
    for i=1,maxreferred do
        local r = tobereferred[i]
        if not last then
            last = r
        elseif r == last then
            tobereferred[i] = nil
        else
            last = r
        end
    end
end

function references.referredpage(n)
    return referred[n] or referred[n] or texcount.realpageno
end

function references.checkedpage(n,page)
    local r, p = referred[n] or texcount.realpageno, tonumber(page)
    if not p then
        -- sorry
    elseif p > r then
        texcount.referencepagestate = 3
    elseif p < r then
        texcount.referencepagestate = 2
    else
        texcount.referencepagestate = 1
    end
    return p
end

function references.registerpage(n)
    if not tobereferred[n] then
        if n > maxreferred then
            maxreferred = n
        end
        tobereferred[n] = texcount.realpageno
    end
end

job.register('structures.references.referred', tobereferred, initializer, finalizer)

-- todo: delay split till later as in destinations we split anyway

local orders, lastorder = { }, 0

local function setnextorder(kind,name)
    lastorder = 0
    if kind and name then
        local ok = orders[kind]
        if not ok then
            ok = { }
            orders[kind] = ok
        end
        lastorder = (ok[name] or 0) + 1
        ok[name] = lastorder
    end
    texsetcount("global","locationorder",lastorder)
end

references.setnextorder = setnextorder

function references.setnextinternal(kind,name)
    setnextorder(kind,name) -- always incremented with internal
    texsetcount("global","locationcount",texcount.locationcount + 1)
end

function references.currentorder(kind,name)
    context(orders[kind] and orders[kind][name] or lastorder)
end

function references.set(kind,prefix,tag,data)
    for ref in gmatch(tag,"[^,]+") do
        local p, r = match(ref,"^(%-):(.-)$")
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
            context.dofinishsomereference(kind,prefix,ref)
        end
    end
end

function references.setandgetattribute(kind,prefix,tag,data,view) -- maybe do internal automatically here
    references.set(kind,prefix,tag,data)
    texcount.lastdestinationattribute = references.setinternalreference(prefix,tag,nil,view) or -0x7FFFFFFF
end

function references.enhance(prefix,tag,spec)
    local l = tobesaved[prefix][tag]
    if l then
        l.references.realpage = texcount.realpageno
    end
end

-- this reference parser is just an lpeg version of the tex based one

local result = { }

local lparent, rparent, lbrace, rbrace, dcolon, backslash = lpegP("("), lpegP(")"), lpegP("{"), lpegP("}"), lpegP("::"), lpegP("\\")

local reset     = lpegP("") / function()  result = { } end
local b_token   = backslash  / function(s) result.has_tex = true return s end

local o_token   = 1 - rparent - rbrace - lparent - lbrace
local a_token   = 1 - rbrace
local s_token   = 1 - lparent - lbrace - lparent - lbrace
local i_token   = 1 - lparent - lbrace
local f_token   = 1 - lparent - lbrace - dcolon

local outer     =        (f_token          )^1  / function (s) result.outer     = s   end
local operation = lpegCs((b_token + o_token)^1) / function (s) result.operation = s   end
local arguments = lpegCs((b_token + a_token)^0) / function (s) result.arguments = s   end
local special   =        (s_token          )^1  / function (s) result.special   = s   end
local inner     =        (i_token          )^1  / function (s) result.inner     = s   end

local outer_reference    = (outer * dcolon)^0

operation = outer_reference * operation -- special case: page(file::1) and file::page(1)

local optional_arguments = (lbrace  * arguments * rbrace)^0
local inner_reference    = inner * optional_arguments
local special_reference  = special * lparent * (operation * optional_arguments + operation^0) * rparent

local scanner = (reset * outer_reference * (special_reference + inner_reference)^-1 * -1) / function() return result end

--~ function references.analyze(str) -- overloaded
--~     return lpegmatch(scanner,str)
--~ end

function references.split(str)
    return lpegmatch(scanner,str or "")
end

--~ print(table.serialize(references.analyze("")))
--~ print(table.serialize(references.analyze("inner")))
--~ print(table.serialize(references.analyze("special(operation{argument,argument})")))
--~ print(table.serialize(references.analyze("special(operation)")))
--~ print(table.serialize(references.analyze("special()")))
--~ print(table.serialize(references.analyze("inner{argument}")))
--~ print(table.serialize(references.analyze("outer::")))
--~ print(table.serialize(references.analyze("outer::inner")))
--~ print(table.serialize(references.analyze("outer::special(operation{argument,argument})")))
--~ print(table.serialize(references.analyze("outer::special(operation)")))
--~ print(table.serialize(references.analyze("outer::special()")))
--~ print(table.serialize(references.analyze("outer::inner{argument}")))
--~ print(table.serialize(references.analyze("special(outer::operation)")))

-- -- -- related to strc-ini.lua -- -- --

references.resolvers = references.resolvers or { }

function references.resolvers.section(var)
    local vi = lists.collected[var.i[2]]
    if vi then
        var.i = vi
        var.r = (vi.references and vi.references.realpage) or (vi.pagedata and vi.pagedata.realpage) or 1
    else
        var.i = nil
        var.r = 1
    end
end

references.resolvers.float       = references.resolvers.section
references.resolvers.description = references.resolvers.section
references.resolvers.formula     = references.resolvers.section
references.resolvers.note        = references.resolvers.section

function references.resolvers.reference(var)
    local vi = var.i[2]
    if vi then
        var.i = vi
        var.r = (vi.references and vi.references.realpage) or (vi.pagedata and vi.pagedata.realpage) or 1
    else
        var.i = nil
        var.r = 1
    end
end

local function register_from_lists(collected,derived)
    local g = derived[""] if not g then g = { } derived[""] = g end -- global
    for i=1,#collected do
        local entry = collected[i]
        local m, r = entry.metadata, entry.references
        if m and r then
            local prefix, reference = r.referenceprefix or "", r.reference or ""
            if reference ~= "" then
                local kind, realpage = m.kind, r.realpage
                if kind and realpage then
                    local d = derived[prefix] if not d then d = { } derived[prefix] = d end
                    local t = { kind, i }
                    for s in gmatch(reference,"%s*([^,]+)") do
                        if trace_referencing then
                            report_references("list entry %s provides %s reference '%s' on realpage %s",i,kind,s,realpage)
                        end
                        d[s] = d[s] or t -- share them
                        g[s] = g[s] or t -- first wins
                    end
                end
            end
        end
    end
end

references.registerinitializer(function() register_from_lists(lists.collected,derived) end)

-- urls

references.urls      = references.urls      or { }
references.urls.data = references.urls.data or { }

local urls = references.urls.data

function references.urls.define(name,url,file,description)
    if name and name ~= "" then
        urls[name] = { url or "", file or "", description or url or file or ""}
    end
end

local pushcatcodes, popcatcodes, txtcatcodes = context.pushcatcodes, context.popcatcodes, tex.txtcatcodes

function references.urls.get(name,method,space) -- method: none, before, after, both, space: yes/no
    local u = urls[name]
    if u then
        local url, file = u[1], u[2]
        pushcatcodes(txtcatcodes)
        if file and file ~= "" then
            context("%s/%s",url,file)
        else
            context(url)
        end
        popcatcodes()
    end
end

function commands.doifurldefinedelse(name)
    commands.doifelse(urls[name])
end

-- files

references.files      = references.files      or { }
references.files.data = references.files.data or { }

local files = references.files.data

function references.files.define(name,file,description)
    if name and name ~= "" then
        files[name] = { file or "", description or file or ""}
    end
end

function references.files.get(name,method,space) -- method: none, before, after, both, space: yes/no
    local f = files[name]
    if f then
        context(f[1])
    end
end

function commands.doiffiledefinedelse(name)
    commands.doifelse(files[name])
end

-- helpers

function references.checkedfile(whatever) -- return whatever if not resolved
    if whatever then
        local w = files[whatever]
        if w then
            return w[1]
        else
            return whatever
        end
    end
end

function references.checkedurl(whatever) -- return whatever if not resolved
    if whatever then
        local w = urls[whatever]
        if w then
            local u, f = w[1], w[2]
            if f and f ~= "" then
                return u .. "/" .. f
            else
                return u
            end
        else
            return whatever
        end
    end
end

function references.checkedfileorurl(whatever,default) -- return nil, nil if not resolved
    if whatever then
        local w = files[whatever]
        if w then
            return w[1], nil
        else
            local w = urls[whatever]
            if w then
                local u, f = w[1], w[2]
                if f and f ~= "" then
                    return nil, u .. "/" .. f
                else
                    return nil, u
                end
            end
        end
    end
    return default
end

-- programs

references.programs      = references.programs      or { }
references.programs.data = references.programs.data or { }

local programs = references.programs.data

function references.programs.define(name,file,description)
    if name and name ~= "" then
        programs[name] = { file or "", description or file or ""}
    end
end

function references.programs.get(name)
    local f = programs[name]
    if f then
        context(f[1])
    end
end

function references.checkedprogram(whatever) -- return whatever if not resolved
    if whatever then
        local w = programs[whatever]
        if w then
            return w[1]
        else
            return whatever
        end
    end
end

-- shared by urls and files

function references.whatfrom(name)
    context((urls[name] and variables.url) or (files[name] and variables.file) or variables.unknown)
end

--~ function references.from(name)
--~     local u = urls[name]
--~     if u then
--~         local url, file, description = u[1], u[2], u[3]
--~         if description ~= "" then
--~             context.dofromurldescription(description)
--~             -- ok
--~         elseif file and file ~= "" then
--~             context.dofromurlliteral(url .. "/" .. file)
--~         else
--~             context(dofromurlliteral,url)
--~         end
--~     else
--~         local f = files[name]
--~         if f then
--~             local description, file = f[1], f[2]
--~             if description ~= "" then
--~                 context.dofromfiledescription(description)
--~             else
--~                 context.dofromfileliteral(file)
--~             end
--~         end
--~     end
--~ end

function references.from(name)
    local u = urls[name]
    if u then
        local url, file, description = u[1], u[2], u[3]
        if description ~= "" then
            context.dofromurldescription(description)
            -- ok
        elseif file and file ~= "" then
            context.dofromurlliteral(url .. "/" .. file)
        else
            context.dofromurlliteral(url)
        end
    else
        local f = files[name]
        if f then
            local description, file = f[1], f[2]
            if description ~= "" then
                context.dofromfiledescription(description)
            else
                context.dofromfileliteral(file)
            end
        end
    end
end

-- export

exporters.references = exporters.references or { }
exporters.lists      = exporters.lists      or { }

function exporters.references.generic(data)
    local useddata = {}
    local entries, userdata = data.entries, data.userdata
    if entries then
        for k, v in next, entries do
            useddata[k] = v
        end
    end
    if userdata then
        for k, v in next, userdata do
            useddata[k] = v
        end
    end
    return useddata
end

function exporters.lists.generic(data)
    local useddata = { }
    local titledata, numberdata = data.titledata, data.numberdata
    if titledata then
        useddata.title = titledata.title
    end
    if numberdata then
        local numbers = numberdata.numbers
        local t, tn = { }, 0
        for i=1,#numbers do
            local n = numbers[i]
            if n ~= 0 then
                tn = tn + 1
                t[tn] = n
            end
        end
        useddata.number = concat(t,".")
    end
    return useddata
end

local function referencer(data)
    local references = data.references
    local realpage = references.realpage
    local numberdata = jobpages.tobesaved[realpage]
    local specification = numberdata.specification
    return {
        realpage = references.realpage,
        number = numberdata.number,
        conversion = specification.conversion,
     -- prefix = only makes sense when bywhatever
    }
end

-- Exported and imported references ... not yet used but don't forget it
-- and redo it.

function references.export(usedname)
    local exported = { }
    local e_references, e_lists = exporters.references, exporters.lists
    local g_references, g_lists = e_references.generic, e_lists.generic
    -- todo: pagenumbers
    -- todo: some packing
    for prefix, references in next, references.tobesaved do
        local pe = exported[prefix] if not pe then pe = { } exported[prefix] = pe end
        for key, data in next, references do
            local metadata = data.metadata
            local exporter = e_references[metadata.kind] or g_references
            if exporter then
                pe[key] = {
                    metadata = {
                        kind = metadata.kind,
                        catcodes = metadata.catcodes,
                        coding = metadata.coding, -- we can omit "tex"
                    },
                    useddata = exporter(data),
                    pagedata = referencer(data),
                }
            end
        end
    end
    local pe = exported[""] if not pe then pe = { } exported[""] = pe end
    for n, data in next, lists.tobesaved do
        local metadata = data.metadata
        local exporter = e_lists[metadata.kind] or g_lists
        if exporter then
            local result = {
                metadata = {
                    kind = metadata.kind,
                    catcodes = metadata.catcodes,
                    coding = metadata.coding, -- we can omit "tex"
                },
                useddata = exporter(data),
                pagedata = referencer(data),
            }
            for key in gmatch(data.references.reference,"[^,]+") do
                pe[key] = result
            end
        end
    end
    local e = {
        references = exported,
        version = 1.00,
    }
    io.savedata(file.replacesuffix(usedname or tex.jobname,"tue"),table.serialize(e,true))
end

function references.import(usedname)
    if usedname then
        local jdn = imported[usedname]
        if not jdn then
            local filename = files[usedname]
            if filename then -- only registered files
                filename = filename[1]
            else
                filename = usedname
            end
            local data = io.loaddata(file.replacesuffix(filename,"tue")) or ""
            if data == "" then
                interfaces.showmessage("references",24,filename)
                data = nil
            else
                data = loadstring(data)
                if data then
                    data = data()
                end
                if data then
                    -- version check
                end
                if not data then
                    interfaces.showmessage("references",25,filename)
                end
            end
            if data then
                interfaces.showmessage("references",26,filename)
                jdn = data
                jdn.filename = filename
            else
                jdn = { filename = filename, references = { }, version = 1.00 }
            end
            imported[usedname] = jdn
            imported[filename] = jdn
        end
        return jdn
    else
        return nil
    end
end

function references.load(usedname)
    -- gone
end

function references.define(prefix,reference,list)
    local d = defined[prefix] if not d then d = { } defined[prefix] = d end
    d[reference] = { "defined", list }
end

--~ function references.registerspecial(name,action,...)
--~     specials[name] = { action, ... }
--~ end

function references.reset(prefix,reference)
    local d = defined[prefix]
    if d then
        d[reference] = nil
    end
end

-- \primaryreferencefoundaction
-- \secondaryreferencefoundaction
-- \referenceunknownaction

-- t.special t.operation t.arguments t.outer t.inner

-- to what extend do we check the non prefixed variant

local strict = false

local function resolve(prefix,reference,args,set) -- we start with prefix,reference
    texcount.referencehastexstate = 0
    if reference and reference ~= "" then
        if not set then
            set = { prefix = prefix, reference = reference }
        else
            set.reference = set.reference or reference
            set.prefix    = set.prefix    or prefix
        end
        local r = settings_to_array(reference)
        for i=1,#r do
            local ri = r[i]
            local d
            if strict then
                d = defined[prefix] or defined[""]
                d = d and d[ri]
            else
                d = defined[prefix]
                d = d and d[ri]
                if not d then
                    d = defined[""]
                    d = d and d[ri]
                end
            end
            if d then
                resolve(prefix,d[2],nil,set)
            else
                local var = lpegmatch(scanner,ri)
                if var then
                    var.reference = ri
                    local vo, vi = var.outer, var.inner
                    if not vo and vi then
                        -- to be checked
                        if strict then
                            d = defined[prefix] or defined[""]
                            d = d and d[vi]
                        else
                            d = defined[prefix]
                            d = d and d[vi]
                            if not d then
                                d = defined[""]
                                d = d and d[vi]
                            end
                        end
                        --
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
                    if var.has_tex then
                        set.has_tex = true
                    end
                else
                --  report_references("funny pattern: %s",ri or "?")
                end
            end
        end
        if set.has_tex then
            texcount.referencehastexstate = 1
        end
--~ table.print(set)
        return set
    else
        return { }
    end
end

-- prefix == "" is valid prefix which saves multistep lookup

references.currentset = nil

local b, e = "\\ctxlua{local jc = structures.references.currentset;", "}"
local o, a = 'jc[%s].operation=[[%s]];', 'jc[%s].arguments=[[%s]];'

function references.expandcurrent() -- todo: two booleans: o_has_tex& a_has_tex
    local currentset = references.currentset
    if currentset and currentset.has_tex then
        local done = false
        for i=1,#currentset do
            local ci = currentset[i]
            local operation = ci.operation
            if operation then
                if find(operation,"\\") then -- if o_has_tex then
                    if not done then
                        context(b)
                        done = true
                    end
                    context(o,i,operation)
                end
            end
            local arguments = ci.arguments
            if arguments then
                if find(arguments,"\\") then -- if a_has_tex then
                    if not done then
                        context(b)
                        done = true
                    end
                    context(a,i,arguments)
                end
            end
        end
        if done then
            context(e)
        end
    end
end

--~ local uo = urls[outer]
--~ if uo then
--~     special, operation, argument = "url", uo[1], inner or uo[2] -- maybe more is needed
--~ else
--~     local fo = files[outer]
--~     if fo then
--~         special, operation, argument = "file", fo[1], inner -- maybe more is needed
--~     end
--~ end

local prefixsplitter = lpegCs(lpegP((1-lpegP(":"))^1 * lpegP(":"))) * lpegCs(lpegP(1)^1)

-- todo: add lots of tracing here

local n = 0

local function identify(prefix,reference)
    local set = resolve(prefix,reference)
    local bug = false
n = n + 1
set.n = n
    for i=1,#set do
        local var = set[i]
        local special, inner, outer, arguments, operation = var.special, var.inner, var.outer, var.arguments, var.operation
        if special then
            local s = specials[special]
            if s then
                if outer then
                    if operation then
                        -- special(outer::operation)
                        var.kind = "special outer with operation"
                    else
                        -- special()
                        var.kind = "special outer"
                    end
                    var.f = outer
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
            local e = references.import(outer)
            if e then
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
                                references.resolvers.reference(var)
                                var.f = outer
                                var.e = true -- external
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
                                    references.resolvers[r[1]](var)
                                    var.f = outer
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
                        var.f = outer
                    else
                        var.error = "unknown outer with special"
                    end
                else
                    -- outer::
                    var.kind = "outer"
                    var.f = outer
                end
            else
                if inner then
                    if arguments then
                        -- outer::inner{argument}
                        var.kind = "outer with inner with arguments"
                    else
                        -- outer::inner
                        var.kind = "outer with inner"
                    end
                    var.i = { "reference", inner }
                    references.resolvers.reference(var)
                    var.f = outer
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
                        var.f = outer
                    else
                        var.error = "unknown outer with special"
                    end
                else
                    -- outer::
                    var.kind = "outer"
                    var.f = outer
                end
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
                -- inner ... we could move the prefix logic into the parser so that we have 'm for each entry
                -- foo:bar -> foo == prefix (first we try the global one)
                -- -:bar   -> ignore prefix
                local p, i = prefix, nil
                local splitprefix, splitinner = lpegmatch(prefixsplitter,inner)
                -- these are taken from other anonymous references
                if splitprefix and splitinner then
                    if splitprefix == "-" then
                        i = collected[""]
                        i = i and i[splitinner]
                        if i then
                            p = ""
                        end
                    else
                        i = collected[splitprefix]
                        i = i and i[splitinner]
                        if i then
                            p = splitprefix
                        end
                    end
                end
                -- todo: strict here
                if not i then
                    i = collected[prefix]
                    i = i and i[inner]
                    if i then
                        p = prefix
                    end
                end
                if not i and prefix ~= "" then
                    i = collected[""]
                    i = i and i[inner]
                    if i then
                        p = ""
                    end
                end
                if i then
                    var.i = { "reference", i }
                    references.resolvers.reference(var)
                    var.kind = "inner"
                    var.p = p
                else
                    -- these are taken from other data structures (like lists)
--~ print("!!!!!!!!!!!!!!",splitprefix,splitinner)
--~ table.print(derived)
                    if splitprefix and splitinner then
                        if splitprefix == "-" then
                            i = derived[""]
                            i = i and i[splitinner]
                            if i then
                                p = ""
                            end
                        else
                            i = derived[splitprefix]
                            i = i and i[splitinner]
                            if i then
                                p = splitprefix
                            end
                        end
                    end
                    if not i then
                        i = derived[prefix]
                        i = i and i[inner]
                        if i then
                            p = prefix
                        end
                    end
                    if not i and prefix ~= "" then
                        i = derived[""]
                        i = i and i[inner]
                        if i then
                            p = ""
                        end
                    end
                    if i then
                        var.kind = "inner"
                        var.i = i
                        references.resolvers[i[1]](var)
                        var.p = p
                    else
                        -- no prefixes here
                        local s = specials[inner]
                        if s then
                            var.kind = "special"
                        else
                            i = (collected[""] and collected[""][inner]) or
                                (derived  [""] and derived  [""][inner]) or
                                (tobesaved[""] and tobesaved[""][inner])
                            if i then
                                var.kind = "inner"
                                var.i = { "reference", i }
                                references.resolvers.reference(var)
                                var.p = ""
                            else
                                var.error = "unknown inner or special"
                            end
                        end
                    end
                end
            end
        end
        bug = bug or var.error
        set[i] = var
    end
    references.currentset = set
--~ table.print(set,tostring(bug))
    return set, bug
end

references.identify = identify

local unknowns, nofunknowns = { }, 0

function references.doifelse(prefix,reference,highlight,newwindow,layer)
    local set, bug = identify(prefix,reference)
    local unknown = bug or #set == 0
    if unknown then
        currentreference = nil -- will go away
        local str = format("[%s][%s]",prefix,reference)
        local u = unknowns[str]
        if not u then
            interfaces.showmessage("references",1,str) -- 1 = unknown, 4 = illegal
            unknowns[str] = 1
            nofunknowns = nofunknowns + 1
        else
            unknowns[str] = u + 1
        end
    else
        set.highlight, set.newwindow,set.layer = highlight, newwindow, layer
        currentreference = set[1]
    end
    -- we can do the expansion here which saves a call
--~     print("!!!!!!",not unknown)
    commands.doifelse(not unknown)
end

function references.reportproblems() -- might become local
    if nofunknowns > 0 then
        interfaces.showmessage("references",5,nofunknowns) -- 5 = unknown, 6 = illegal
     -- -- we need a proper logger specific for the log file
     -- texio.write_nl("log",format("%s unknown references",nofunknowns))
     -- for k, v in table.sortedpairs(unknowns) do
     --     texio.write_nl("log",format("%s (n=%s)",k,v))
     -- end
     -- texio.write_nl("log","")
    end
end

luatex.registerstopactions(references.reportproblems)

local innermethod = "names"

function references.setinnermethod(m)
    if m then
        if m == "page" or m == "mixed" or m == "names" then
            innermethod = m
        elseif m == true or m == variables.yes then
            innermethod = "page"
        end
    end
    function references.setinnermethod()
        report_references("inner method is already set and frozen to '%s'",innermethod)
    end
end

function references.getinnermethod()
    return innermethod or "names"
end

directives.register("references.linkmethod", function(v) -- page mixed names
    references.setinnermethod(v)
end)

function references.setinternalreference(prefix,tag,internal,view)
    if innermethod == "page" then
        return unsetvalue
    else
        local t, tn = { }, 0 -- maybe add to current
        if tag then
            if prefix and prefix ~= "" then
                prefix = prefix .. ":"
                for ref in gmatch(tag,"[^,]+") do
                    tn = tn + 1
                    t[tn] = prefix .. ref
                end
            else
                for ref in gmatch(tag,"[^,]+") do
                    tn = tn + 1
                    t[tn] = ref
                end
            end
        end
        if internal and innermethod == "names" then -- mixed or page
            tn = tn + 1
            t[tn] = "aut:" .. internal
        end
        local destination = references.mark(t,nil,nil,view) -- returns an attribute
        texcount.lastdestinationattribute = destination
        return destination
    end
end

function references.getinternalreference(n) -- n points into list (todo: registers)
    local l = lists.collected[n]
    context(l and l.references.internal or n)
end

--

function references.getcurrentmetadata(tag)
    local data = currentreference and currentreference.i
    data = data and data.metadata and data.metadata[tag]
    if data then
        context(data)
    end
end

local function currentmetadata(tag)
    local data = currentreference and currentreference.i
    return data and data.metadata and data.metadata[tag]
end

references.currentmetadata = currentmetadata

function references.getcurrentprefixspec(default) -- todo: message
    context.getreferencestructureprefix(currentmetadata("kind") or "?",currentmetadata("name") or "?",default or "?")
end

function references.filter(name,...) -- number page title ...
    local data = currentreference and currentreference.i
    if data then
        local kind = data.metadata and data.metadata.kind
        if kind then
            local filter = filters[kind] or filters.generic
            filter = filter and (filter[name] or filter.unknown or filters.generic[name] or filters.generic.unknown)
            if filter then
                if trace_referencing then
                    report_references("name '%s', kind '%s', using dedicated filter",name,kind)
                end
                filter(data,name,...)
            elseif trace_referencing then
                report_references("name '%s', kind '%s', using generic filter",name,kind)
            end
        elseif trace_referencing then
            report_references("name '%s', unknown kind",name)
        end
    elseif trace_referencing then
        report_references("name '%s', no reference",name)
    end
end

filters.generic = { }

function filters.generic.title(data)
    if data then
        local titledata = data.titledata or data.useddata
        if titledata then
            helpers.title(titledata.title or "?",data.metadata)
        end
    end
end

function filters.generic.text(data)
    if data then
        local entries = data.entries or data.useddata
        if entries then
            helpers.title(entries.text or "?",data.metadata)
        end
    end
end

function filters.generic.number(data,what,prefixspec) -- todo: spec and then no stopper
    if data then
        local numberdata = data.numberdata
        if numberdata then
--~ print(table.serialize(prefixspec))
            helpers.prefix(data,prefixspec)
            sections.typesetnumber(numberdata,"number",numberdata)
        else
            local useddata = data.useddata
            if useddata and useddsta.number then
                context(useddata.number)
            end
        end
    end
end

filters.generic.default = filters.generic.text

function filters.generic.page(data,prefixspec,pagespec)
    local pagedata = data.pagedata
    if pagedata then -- imported
        local number, conversion = pagedata.number, pagedata.conversion
        if not number then
            -- error
        elseif conversion then
            context.convertnumber(conversion,number)
        else
            context(number)
        end
    else
        helpers.prefixpage(data,prefixspec,pagespec)
    end
end

filters.user = { }

function filters.user.unknown(data,name)
    if data then
        local userdata = data.userdata
        local userkind = userdata and userdata.kind
        if userkind then
            local filter = filters[userkind] or filters.generic
            filter = filter and (filter[name] or filter.unknown)
            if filter then
                filter(data,name)
                return
            end
        end
        local namedata = userdata and userdata[name]
        if namedata then
            context(namedata)
        end
    end
end

filters.text = { }

function filters.text.title(data)
    helpers.title(data.entries.text or "?",data.metadata)
end

function filters.text.number(data)
    helpers.title(data.entries.text or "?",data.metadata)
end

function filters.text.page(data,prefixspec,pagespec)
    helpers.prefixpage(data,prefixspec,pagespec)
end

filters.section = { }

function filters.section.number(data,what,prefixspec)
    if data then
        local numberdata = data.numberdata
        if numberdata then
            sections.typesetnumber(numberdata,"number",prefixspec,numberdata)
        else
            local useddata = data.useddata
            if useddata and useddata.number then
                context(useddata.number)
            end
        end
    end
end

filters.section.title   = filters.generic.title
filters.section.page    = filters.generic.page
filters.section.default = filters.section.number

filters.note        = { default = filters.generic.number }
filters.formula     = { default = filters.generic.number }
filters.float       = { default = filters.generic.number }
filters.description = { default = filters.generic.number }
filters.item        = { default = filters.generic.number }

function references.sectiontitle(n)
    helpers.sectiontitle(lists.collected[tonumber(n) or 0])
end

function references.sectionnumber(n)
    helpers.sectionnumber(lists.collected[tonumber(n) or 0])
end

function references.sectionpage(n,prefixspec,pagespec)
    helpers.prefixedpage(lists.collected[tonumber(n) or 0],prefixspec,pagespec)
end

-- analyze

references.testrunners  = references.testrunners  or { }
references.testspecials = references.testspecials or { }

local runners  = references.testrunners
local specials = references.testspecials

function references.analyze(actions)
    actions = actions or references.currentset
    if not actions then
        actions = { realpage = 0 }
    elseif actions.realpage then
        -- already analyzed
    else
        -- we store some analysis data alongside the indexed array
        -- at this moment only the real reference page is analyzed
        -- normally such an analysis happens in the backend code
        texcount.referencepagestate = 0
        local nofactions = #actions
        if nofactions > 0 then
            for i=1,nofactions do
                local a = actions[i]
                local what = runners[a.kind]
                if what then
                    what = what(a,actions)
                end
            end
            references.checkedpage(actions.n,actions.realpage)
        end
    end
    return actions
end

function references.realpage() -- special case, we always want result
    local cs = references.analyze()
    context(cs.realpage or 0)
end

local plist

function realpageofpage(p)
    if not plist then
        local pages = structures.pages.collected
        plist = { }
        for rp=1,#pages do
            plist[pages[rp].number] = rp
        end
    end
    return plist[p]
end

references.realpageofpage = realpageofpage

--

references.pages = allocate {
    [variables.firstpage]       = function() return counters.record("realpage")["first"]    end,
    [variables.previouspage]    = function() return counters.record("realpage")["previous"] end,
    [variables.nextpage]        = function() return counters.record("realpage")["next"]     end,
    [variables.lastpage]        = function() return counters.record("realpage")["last"]     end,

    [variables.firstsubpage]    = function() return counters.record("subpage" )["first"]    end,
    [variables.previoussubpage] = function() return counters.record("subpage" )["previous"] end,
    [variables.nextsubpage]     = function() return counters.record("subpage" )["next"]     end,
    [variables.lastsubpage]     = function() return counters.record("subpage" )["last"]     end,

    [variables.forward]         = function() return counters.record("realpage")["forward"]  end,
    [variables.backward]        = function() return counters.record("realpage")["backward"] end,
}

-- maybe some day i will merge this in the backend code with a testmode (so each
-- runner then implements a branch)

runners["inner"] = function(var,actions)
    local r = var.r
    if r then
        actions.realpage = r
    end
end

runners["special"] = function(var,actions)
    local handler = specials[var.special]
    return handler and handler(var,actions)
end

runners["special operation"]                = runners["special"]
runners["special operation with arguments"] = runners["special"]

function specials.internal(var,actions)
    local v = references.internals[tonumber(var.operation)]
    local r = v and v.references.realpage
    if r then
        actions.realpage = r
    end
end

specials.i = specials.internal

-- weird, why is this code here and in lpdf-ano

local pages = references.pages

function specials.page(var,actions) -- is this ok?
    local p = pages[var.operation]
    if type(p) == "function" then
        p = p()
    end
    if p then
        actions.realpage = p
    end
end

function specials.realpage(var,actions) -- is this ok?
    actions.realpage = tonumber(var.operation)
end


function specials.userpage(var,actions) -- is this ok?
    actions.realpage = tonumber(realpageofpage(var.operation))
end

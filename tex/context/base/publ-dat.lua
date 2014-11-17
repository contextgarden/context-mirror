if not modules then modules = { } end modules ['publ-dat'] = {
    version   = 1.001,
    comment   = "this module part of publication support",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- todo: strip the @ in the lpeg instead of on do_definition and do_shortcut
-- todo: store bibroot and bibrootdt
-- todo: dataset = datasets[dataset] => current = datasets[dataset]
-- todo: maybe split this file

--[[ldx--
<p>This is a prelude to integrated bibliography support. This file just loads
bibtex files and converts them to xml so that the we access the content
in a convenient way. Actually handling the data takes place elsewhere.</p>
--ldx]]--

if not characters then
    dofile(resolvers.findfile("char-utf.lua"))
    dofile(resolvers.findfile("char-tex.lua"))
end

local chardata  = characters.data
local lowercase = characters.lower

local lower, find = string.lower, string.find
local concat, copy = table.concat, table.copy
local next, type, rawget = next, type, rawget
local utfchar = utf.char
local lpegmatch, lpegpatterns = lpeg.match, lpeg.patterns
local textoutf = characters and characters.tex.toutf
local settings_to_hash, settings_to_array = utilities.parsers.settings_to_hash, utilities.parsers.settings_to_array
local formatters = string.formatters
local sortedkeys, sortedhash = table.sortedkeys, table.sortedhash
local xmlcollected, xmltext, xmlconvert = xml.collected, xml.text, xml.convert
local setmetatableindex = table.setmetatableindex

-- todo: more allocate

local P, R, S, V, C, Cc, Cs, Ct, Carg, Cmt = lpeg.P, lpeg.R, lpeg.S, lpeg.V, lpeg.C, lpeg.Cc, lpeg.Cs, lpeg.Ct, lpeg.Carg, lpeg.Cmt

local p_whitespace      = lpegpatterns.whitespace

local trace             = false  trackers.register("publications",            function(v) trace = v end)
local trace_duplicates  = true   trackers.register("publications.duplicates", function(v) trace = v end)

local report            = logs.reporter("publications")
local report_duplicates = logs.reporter("publications","duplicates")

local allocate          = utilities.storage.allocate

publications            = publications or { }
local publications      = publications

local datasets          = publications.datasets or { }
publications.datasets   = datasets

local writers           = publications.writers or { }
publications.writers    = writers

local tables            = publications.tables or { }
publications.tables     = tables

publications.statistics = publications.statistics or { }
local publicationsstats = publications.statistics

local loaders           = publications.loaders or { }
publications.loaders    = loaders

local casters           = { }
publications.casters    = casters

local sorters           = { }
publications.sorters    = sorters

local indexers          = { }
publications.indexers   = indexers

local components        = { }
publications.components = components -- register components

local enhancers         = publications.enhancers or { }
publications.enhancers  = enhancers

local enhancer          = publications.enhancer or utilities.sequencers.new { arguments = "dataset" }
publications.enhancer   = enhancer

utilities.sequencers.appendgroup(enhancer,"system") -- private

publicationsstats.nofbytes       = 0
publicationsstats.nofdefinitions = 0
publicationsstats.nofshortcuts   = 0
publicationsstats.nofdatasets    = 0

local privates = allocate {
    category      = true,
    tag           = true,
    index         = true,
    suffix        = true,
    specification = true,
}

local specials = allocate {
    key      = true,
    crossref = true,
    keywords = true,
    language = true,
    comment  = true,
}

local implicits = allocate {
    category = "implicit",
    tag      = "implicit",
    key      = "implicit",
    keywords = "implicit",
    language = "implicit",
    crossref = "implicit",
}

local origins = allocate {
    "optional",
    "extra",
    "required",
    "virtual",
}

local virtuals = allocate {
    "authoryear",
    "authoryears",
    "authornum",
    "num",
    "suffix",
}

local defaulttypes = allocate {
    author    = "author",
    editor    = "author",
    publisher = "author",
    page      = "pagenumber",
    pages     = "pagenumber",
    keywords  = "keyword",
}

tables.implicits = implicits
tables.origins   = origins
tables.virtuals  = virtuals
tables.types     = defaulttypes
tables.privates  = privates
tables.specials  = specials

local variables  = interfaces and interfaces.variables or setmetatableindex("self")

local v_all      = variables.all
local v_standard = variables.standard

if not publications.usedentries then
    function publications.usedentries()
        return { }
    end
end

local xmlplaceholder = "<?xml version='1.0' standalone='yes'?>\n<bibtex></bibtex>"

local defaultshortcuts = allocate {
    jan =  "1",
    feb =  "2",
    mar =  "3",
    apr =  "4",
    may =  "5",
    jun =  "6",
    jul =  "7",
    aug =  "8",
    sep =  "9",
    oct = "10",
    nov = "11",
    dec = "12",
}

local space      = p_whitespace^0
local separator  = space * "+" * space
local l_splitter = lpeg.tsplitat(separator)
local d_splitter = lpeg.splitat (separator)

local unknownfield = function(t,k)
    local v = "extra"
    t[k] = v
    return v
end

local unknowncategory = function(t,k)
    local v = {
        required = false,
        optional = false,
        virtual  = false,
        fields   = setmetatableindex(unknownfield),
        types    = defaulttypes,
    }
    t[k] = v
    return v
end

local unknowntype = function(t,k)
    local v = "string"
    t[k] = v
    return v
end

local default = {
    name       = name,
    version    = "1.00",
    comment    = "unknown specification.",
    author     = "anonymous",
    copyright  = "no one",
    categories = setmetatableindex(unknowncategory),
    types      = setmetatableindex(defaulttypes,unknowntype),
}

-- maybe at some point we can han da handlers table with per field
-- a found, fetch, ... method

local function checkfield(specification,category,data)
    local list    = setmetatableindex({},implicits)
    data.fields   = list
    data.category = category
    local sets    = data.sets or { }
    for i=1,#origins do
        local t = origins[i]
        local d = data[t]
        if d then
            for i=1,#d do
                local di = d[i]
                di = sets[di] or di
                if type(di) == "table" then
                    for i=1,#di do
                        list[di[i]] = t
                    end
                else
                    list[di] = t
                end
            end
        else
            data[t] = { }
        end
    end
    return data
end

local specifications = setmetatableindex(function(t,name)
    if not name then
        return default -- initializer
    end
    local filename = formatters["publ-imp-%s.lua"](name)
    local fullname = resolvers.findfile(filename) or ""
    if fullname == "" then
        report("no data definition file %a for %a",filename,name)
        return default
    end
    local specification = table.load(fullname)
    if not specification then
        report("invalid data definition file %a for %a",fullname,name)
        return default
    end
    --
    local categories = specification.categories
    if not categories then
        categories = { }
        specification.categories = categories
    end
    setmetatableindex(categories,unknowncategory)
    --
    local types = specification.types
    if not types then
        types = defaulttypes
        specification.types = types
    end
    setmetatableindex(types,unknowntype)
    --
    local fields         = setmetatableindex(unknownfield)
    specification.fields = fields
    --
    local virtual         = specification.virtual
    if virtual == nil then -- so false is valid
        virtual = virtuals
        specification.virtual = virtual
    end
    --
    for category, data in next, categories do
        categories[category] = checkfield(specification,category,copy(data)) -- we make sure we have no clones
    end
    --
    t[name] = specification
    --
    return specification
end)

publications.specifications = specifications

function publications.setcategory(target,category,data)
    local specification = specifications[target]
    specification.categories[category] = checkfield(specification,category,data)
end

function publications.parenttag(dataset,tag)
    if not dataset or not tag then
        report("error in specification, dataset %a, tag %a",dataset,tag)
    elseif find(tag,"%+") then
        local tags    = lpegmatch(l_splitter,tag)
        local parent  = tags[1]
        local current = datasets[dataset]
        local luadata = current.luadata
        local first   = luadata[parent]
        if first then
            local combined = first.combined
            if not combined then
                combined = { }
                first.combined = combined
            end
            -- add new ones but only once
            for i=2,#tags do
                local tag = tags[i]
                for j=1,#combined do
                    if combined[j] == tag then
                        tag = false
                    end
                end
                if tag then
                    local entry = luadata[tag]
                    if entry then
                        combined[#combined+1] = tag
                    end
                end
            end
            return parent
        end
    end
    return tag or ""
end

function publications.new(name)
    publicationsstats.nofdatasets = publicationsstats.nofdatasets + 1
    local dataset = {
        name       = name or "dataset " .. publicationsstats.nofdatasets,
        nofentries = 0,
        shortcuts  = { },
        luadata    = { },
        suffixes   = { },
        xmldata    = xmlconvert(xmlplaceholder),
        details    = { },
        ordered    = { },
        nofbytes   = 0,
        entries    = nil, -- empty == all
        sources    = { },
        loaded     = { },
        fields     = { },
        userdata   = { },
        used       = { },
        commands   = { }, -- for statistical purposes
        status     = {
            resources = false,
            userdata  = false,
        },
        specifications = {
            -- used specifications
        },
    }
    -- we delay details till we need it (maybe we just delay the
    -- individual fields but that is tricky as there can be some
    -- depedencies)
    return dataset
end

setmetatableindex(datasets,function(t,k)
    if type(k) == "table" then
        return k -- so we can use this accessor as checker
    else
        local v = publications.new(k)
        datasets[k] = v
        return v
    end
end)

local function getindex(dataset,luadata,tag)
    local found = luadata[tag]
    if found then
        return found.index or 0
    else
        local index = dataset.nofentries + 1
        dataset.nofentries = index
        return index
    end
end

publications.getindex = getindex

do

    -- we apply some normalization

    local space    = S(" \t\n\r\f") -- / " "

    ----- command  = P("\\") * Cc("btxcmd{") * (R("az","AZ")^1) * Cc("}")
    ----- command  = P("\\") * (Carg(1) * C(R("az","AZ")^1) / function(list,c) list[c] = (list[c] or 0) + 1 return "btxcmd{" .. c .. "}" end)
    local command  = P("\\") * (Carg(1) * C(R("az","AZ")^1) * space^0 / function(list,c) list[c] = (list[c] or 0) + 1 return "btxcmd{" .. c .. "}" end)
    local somemath = P("$") * ((1-P("$"))^1) * P("$") -- let's not assume nested math
    local any      = P(1)
    local done     = P(-1)
    local one_l    = P("{")  / ""
    local one_r    = P("}")  / ""
    local two_l    = P("{{") / ""
    local two_r    = P("}}") / ""
    local special  = P("#")  / "\\letterhash"

    local filter_0 = S('\\{}')
    local filter_1 = (1-filter_0)^0 * filter_0
    local filter_2 = Cs(
    -- {{...}} ... {{...}}
    --     two_l * (command + special + any - two_r - done)^0 * two_r * done +
    --     one_l * (command + special + any - one_r - done)^0 * one_r * done +
                (somemath + command + special + any               )^0
    )

    -- Currently we expand shortcuts and for large ones (like the acknowledgements
    -- in tugboat.bib) this is not that efficient. However, eventually strings get
    -- hashed again.

    local function do_shortcut(key,value,dataset)
        publicationsstats.nofshortcuts = publicationsstats.nofshortcuts + 1
        dataset.shortcuts[key] = value
    end

    -- todo: categories : metatable that lowers and also counts
    -- todo: fields     : metatable that lowers

    local tags = table.setmetatableindex("table")

    local function do_definition(category,tag,tab,dataset)
        publicationsstats.nofdefinitions = publicationsstats.nofdefinitions + 1
        local fields  = dataset.fields
        local luadata = dataset.luadata
        if luadata[tag] then
            local t = tags[tag]
            local d = dataset.name
            local n = (t[n] or 0) + 1
            t[d] = n
            if trace_duplicates then
                local p = { }
                for k, v in sortedhash(t) do
                    p[#p+1] = formatters["%s:%s"](k,v)
                end
                report_duplicates("tag %a is present multiple times: % t",tag,p)
            end
        else
            local found   = luadata[tag]
            local index   = getindex(dataset,luadata,tag)
            local entries = {
                category = lower(category),
                tag      = tag,
                index    = index,
            }
            for i=1,#tab,2 do
                local original   = tab[i]
                local normalized = fields[original]
                if not normalized then
                    normalized = lower(original) -- we assume ascii fields
                    fields[original] = normalized
                end
             -- if entries[normalized] then
                if rawget(entries,normalized) then
                    if trace_duplicates then
                        report_duplicates("redundant field %a is ignored for tag %a in dataset %a",normalized,tag,dataset.name)
                    end
                else
                    local value = tab[i+1]
                    value = textoutf(value)
                    if lpegmatch(filter_1,value) then
                        value = lpegmatch(filter_2,value,1,dataset.commands) -- we need to start at 1 for { }
                    end
                    if normalized == "crossref" then
                        local parent = luadata[value]
                        if parent then
                            setmetatableindex(entries,parent)
                        else
                            -- warning
                        end
                    end
                    entries[normalized] = value
                end
            end
            luadata[tag] = entries
        end
    end

    local function resolve(s,dataset)
        return dataset.shortcuts[s] or defaultshortcuts[s] or s -- can be number
    end

    local pattern = p_whitespace^0
                  * C(P("message") + P("warning") + P("error") + P("comment")) * p_whitespace^0 * P(":")
                  * p_whitespace^0
                  * C(P(1)^1)

    local function do_comment(s,dataset)
        local how, what = lpegmatch(pattern,s)
        if how and what then
            local t = string.splitlines(utilities.strings.striplines(what))
            local b = file.basename(dataset.fullname or dataset.name or "unset")
            for i=1,#t do
                report("%s > %s : %s",b,how,t[i])
            end
        end
    end

    local percent    = P("%")
    local start      = P("@")
    local comma      = P(",")
    local hash       = P("#")
    local escape     = P("\\")
    local single     = P("'")
    local double     = P('"')
    local left       = P('{')
    local right      = P('}')
    local both       = left + right
    local lineending = S("\n\r")
    local space      = S(" \t\n\r\f") -- / " "
    local spacing    = space^0
    local equal      = P("=")
    ----- collapsed  = (space^1)/ " "
    local collapsed  = (p_whitespace^1)/" "

    ----- balanced   = lpegpatterns.balanced

    local balanced   = P {
    --     [1] = ((escape * (left+right)) + (collapsed + 1 - (left+right)) + V(2))^0,
        [1] = ((escape * (left+right)) + collapsed + (1 - (left+right))^1 + V(2))^0,
        [2] = left * V(1) * right,
    }

    local unbalanced = P {
        [1] = left * V(2) * right,
        [2] = ((escape * (left+right)) + collapsed + (1 - (left+right))^1 + V(1))^0,
    }

    local keyword    = C((R("az","AZ","09") + S("@_:-"))^1)
    local key        = C((1-space-equal)^1)
    local tag        = C((1-space-comma)^1)
    local reference  = keyword
    local category   = C((1-space-left)^1)
    local s_quoted   = ((escape*single) + collapsed + (1-single))^0
    local d_quoted   = ((escape*double) + collapsed + (1-double))^0

    local b_value    = (left  /"") * balanced * (right /"")
    local u_value    = (left  /"") * unbalanced * (right /"") -- get rid of outer { }
    local s_value    = (single/"") * (u_value + s_quoted) * (single/"")
    local d_value    = (double/"") * (u_value + d_quoted) * (double/"")
    local r_value    = reference * Carg(1) /resolve

    local somevalue  = d_value + b_value + s_value + r_value
    local value      = Cs((somevalue * ((spacing * hash * spacing)/"" * somevalue)^0))

    local forget     = percent^1 * (1-lineending)^0
    local spacing    = spacing * forget^0 * spacing
    local assignment = spacing * key * spacing * equal * spacing * value * spacing
    local definition = category * spacing * left * spacing * tag * spacing * comma * Ct((assignment * comma^0)^0) * spacing * right * Carg(1) / do_definition

    local crapword   = C((1-space-left)^1)
    local shortcut   = Cmt(crapword,function(_,p,s) return lower(s) == "string"  and p end) * spacing * left * ((assignment * Carg(1))/do_shortcut * comma^0)^0  * spacing * right
    local comment    = Cmt(crapword,function(_,p,s) return lower(s) == "comment" and p end) * spacing * lpegpatterns.argument * Carg(1) / do_comment

    local casecrap   = #S("sScC") * (shortcut + comment)

    local bibtotable = (space + forget + P("@") * (casecrap + definition) + 1)^0

    -- todo \%

    -- loadbibdata  -> dataset.luadata
    -- loadtexdata  -> dataset.luadata
    -- loadluadata  -> dataset.luadata

    -- converttoxml -> dataset.xmldata from dataset.luadata

    function publications.loadbibdata(dataset,content,source,kind)
        if not source then
            report("invalid source for dataset %a",dataset)
            return
        end
        local current = datasets[dataset]
        local size = #content
        if size == 0 then
            report("empty source %a for dataset %a",source,current.name)
        else
            report("adding bib data to set %a from source %a",current.name,source)
        end
        statistics.starttiming(publications)
        publicationsstats.nofbytes = publicationsstats.nofbytes + size
        current.nofbytes = current.nofbytes + size
        if source then
            table.insert(current.sources, { filename = source, checksum = md5.HEX(content) })
            current.loaded[source] = kind or true
        end
        current.newtags = #current.luadata > 0 and { } or current.newtags
        lpegmatch(bibtotable,content or "",1,current)
        statistics.stoptiming(publications)
    end

end

do

    -- we could use xmlescape again

    local cleaner_0 = S('<>&')
    local cleaner_1 = (1-cleaner_0)^0 * cleaner_0
    local cleaner_2 = Cs ( (
        P("<") / "&lt;" +
        P(">") / "&gt;" +
        P("&") / "&amp;" +
        P(1)
    )^0)

    local compact = false -- can be a directive but then we also need to deal with newlines ... not now

    function publications.converttoxml(dataset,nice,dontstore,usedonly) -- we have fields !
        local current = datasets[dataset]
        local luadata = current and current.luadata
        if luadata then
            statistics.starttiming(publications)
            --
            local result, r, n = { }, 0, 0
            local usedonly = usedonly and publications.usedentries()
            --
            r = r + 1 ; result[r] = "<?xml version='1.0' standalone='yes'?>"
            r = r + 1 ; result[r] = "<bibtex>"
            --
            if nice then
                local f_entry_start = formatters[" <entry tag='%s' category='%s' index='%s'>"]
                local s_entry_stop  = " </entry>"
                local f_field       = formatters["  <field name='%s'>%s</field>"]
                for tag, entry in sortedhash(luadata) do
                    if not usedonly or usedonly[tag] then
                        r = r + 1 ; result[r] = f_entry_start(tag,entry.category,entry.index)
                        for key, value in sortedhash(entry) do
                            if key ~= "tag" and key ~= "category" and key ~= "index" then
                                if lpegmatch(cleaner_1,value) then
                                    value = lpegmatch(cleaner_2,value)
                                end
                                if value ~= "" then
                                    r = r + 1 ; result[r] = f_field(key,value)
                                end
                            end
                        end
                        r = r + 1 ; result[r] = s_entry_stop
                        n = n + 1
                    end
                end
            else
                local f_entry_start = formatters["<entry tag='%s' category='%s' index='%s'>"]
                local s_entry_stop  = "</entry>"
                local f_field       = formatters["<field name='%s'>%s</field>"]
                for tag, entry in next, luadata do
                    if not usedonly or usedonly[tag] then
                        r = r + 1 ; result[r] = f_entry_start(entry.tag,entry.category,entry.index)
                        for key, value in next, entry do
                            if key ~= "tag" and key ~= "category" and key ~= "index" then
                                if lpegmatch(cleaner_1,value) then
                                    value = lpegmatch(cleaner_2,value)
                                end
                                if value ~= "" then
                                    r = r + 1 ; result[r] = f_field(key,value)
                                end
                            end
                        end
                        r = r + 1 ; result[r] = s_entry_stop
                        n = n + 1
                    end
                end
            end
            --
            r = r + 1 ; result[r] = "</bibtex>"
            --
            result = concat(result,nice and "\n" or nil)
            --
            if dontstore then
                -- indeed
            else
                statistics.starttiming(xml)
                current.xmldata = xmlconvert(result, {
                    resolve_entities            = true,
                    resolve_predefined_entities = true, -- in case we have escaped entities
                 -- unify_predefined_entities   = true, -- &#038; -> &amp;
                    utfize_entities             = true,
                } )
                statistics.stoptiming(xml)
                if lxml then
                    lxml.register(formatters["btx:%s"](current.name),current.xmldata)
                end
            end
            statistics.stoptiming(publications)
            return result, n
        end
    end

end

do

    local function resolvedname(dataset,filename)
        local current = datasets[dataset]
        if type(filename) ~= "string" then
            report("invalid filename %a",tostring(filename))
        end
        local fullname = resolvers.findfile(filename,"bib")
        if fullname == "" then
            fullname = resolvers.findfile(filename) -- let's not be too picky
        end
        if not fullname or fullname == "" then
            report("no file %a",filename)
            current.fullname = filename
            return current, false
        else
            current.fullname = fullname
            return current, fullname
        end
    end

    publications.resolvedname = resolvedname

    function loaders.bib(dataset,filename,kind)
        local dataset, fullname = resolvedname(dataset,filename)
        if not fullname then
            return
        end
        local data = io.loaddata(filename) or ""
        if data == "" then
            report("empty file %a, nothing loaded",fullname)
            return
        end
        if trace then
            report("loading file",fullname)
        end
        publications.loadbibdata(dataset,data,fullname,kind)
    end

    function loaders.lua(dataset,filename) -- if filename is a table we load that one
        local current, data, fullname
        if type(filename) == "table" then
            current = datasets[dataset]
            data    = filename
        else
            dataset, fullname = resolvedname(dataset,filename)
            if not fullname then
                return
            end
            current = datasets[dataset]
            data    = table.load(filename)
        end
        if data then
            local luadata = current.luadata
            for tag, entry in next, data do
                if type(entry) == "table" then
                    entry.index  = getindex(current,luadata,tag)
                    entry.tag    = tag
                    luadata[tag] = entry -- no cleaning yet
                end
            end
        end
    end

    function loaders.buffer(dataset,name) -- if filename is a table we load that one
        local current  = datasets[dataset]
        local barename = file.removesuffix(name)
        local data     = buffers.getcontent(barename) or ""
        if data == "" then
            report("empty buffer %a, nothing loaded",barename)
            return
        end
        if trace then
            report("loading buffer",barename)
        end
        publications.loadbibdata(current,data,barename,"bib")
    end

    function loaders.xml(dataset,filename)
        local dataset, fullname = resolvedname(dataset,filename)
        if not fullname then
            return
        end
        local current = datasets[dataset]
        local luadata = current.luadata
        local root    = xml.load(filename)
        for bibentry in xmlcollected(root,"/bibtex/entry") do
            local attributes = bibentry.at
            local tag        = attributes.tag
            local entry      = {
                category = attributes.category,
                tag      = tag, -- afterwards also set, to prevent overload
                index    = 0,   -- prelocated
            }
            for field in xmlcollected(bibentry,"/field") do
                entry[field.at.name] = field.dt[1] -- no cleaning yet | xmltext(field)
            end
            entry.index  = getindex(current,luadata,tag)
            entry.tag    = tag
            luadata[tag] = entry
        end
    end

    setmetatableindex(loaders,function(t,filetype)
        local v = function(dataset,filename)
            report("no loader for file %a with filetype %a",filename,filetype)
        end
        t[k] = v
        return v
    end)

    function publications.load(specification)
        local current  = datasets[specification.dataset or v_standard]
        local files    = settings_to_array(specification.filename)
        local kind     = specification.kind
        local dataspec = specification.specification
        statistics.starttiming(publications)
        for i=1,#files do
            local filetype, filename = string.splitup(files[i],"::")
            if not filename then
                filename = filetype
                filetype = file.suffix(filename)
            end
            if filename then
                if not filetype or filetype == "" then
                    filetype = "bib"
                end
                if file.suffix(filename) == "" then
                    file.addsuffix(filename,filetype)
                end
                loaders[filetype](current,filename)
                if kind then
                    current.loaded[current.fullname or filename] = kind
                end
                if dataspec then
                    current.specifications[dataspec] = true
                end
            end
        end
        local runner = enhancer.runner
        if runner then
            runner(current)
        end
        statistics.stoptiming(publications)
        return current
    end

end

do

    function enhancers.order(dataset)
        local luadata = dataset.luadata
        local ordered = sortedkeys(luadata)
        local total   = #ordered
        for i=1,total do
            ordered[i] = luadata[ordered[i]]
        end
        dataset.ordered = ordered
    end

    function enhancers.details(dataset)
        local luadata = dataset.luadata
        local details = dataset.details
        for tag, entry in next, luadata do
            if not details[tag] then
                details[tag] = { }
            end
        end
    end

    utilities.sequencers.appendaction(enhancer,"system","publications.enhancers.order")
    utilities.sequencers.appendaction(enhancer,"system","publications.enhancers.details")

end

do

    local checked  = function(s,d) d[s] = (d[s] or 0) + 1 end
    local checktex = ( (1-P("\\"))^1 + P("\\") * ((C(R("az","AZ")^1)  * Carg(1))/checked))^0

    function publications.analyze(dataset)
        local current    = datasets[dataset]
        local data       = current.luadata
        local categories = { }
        local fields     = { }
        local commands   = { }
        for k, v in next, data do
            categories[v.category] = (categories[v.category] or 0) + 1
            for k, v in next, v do
                fields[k] = (fields[k] or 0) + 1
                lpegmatch(checktex,v,1,commands)
            end
        end
        current.analysis = {
            categories = categories,
            fields     = fields,
            commands   = commands,
        }
    end

end

-- a helper:

function publications.concatstate(i,n)
    if i == 0 then
        return 0
    elseif i == 1 then
        return 1
    elseif i == 2 and n == 2 then
        return 4
    elseif i == n then
        return 3
    else
        return 2
    end
end

-- savers

do

    local savers = { }

    local s_preamble = [[
    % this is an export from context mkiv

    @preamble{
        \ifdefined\btxcmd
            % we're probably in context
        \else
            \def\btxcmd#1{\csname#1\endcsname}
        \fi
    }

    ]]

    function savers.bib(dataset,filename,usedonly)
        local current  = datasets[dataset]
        local luadata  = current.luadata or { }
        local usedonly = usedonly and publications.usedentries()
        local f_start  = formatters["@%s{%s,\n"]
        local f_field  = formatters["  %s = {%s},\n"]
        local s_stop   = "}\n\n"
        local result   = { s_preamble }
        local n, r = 0, 1
        for tag, data in sortedhash(luadata) do
            if not usedonly or usedonly[tag] then
                r = r + 1 ; result[r] = f_start(data.category or "article",tag)
                for key, value in sortedhash(data) do
                    if privates[key] then
                        -- skip
                    else
                        r = r + 1 ; result[r] = f_field(key,value)
                    end
                end
                r = r + 1 ; result[r] = s_stop
                n = n + 1
            end
        end
        report("%s entries from dataset %a saved in %a",n,dataset,filename)
        io.savedata(filename,concat(result))
    end

    function savers.lua(dataset,filename,usedonly)
        local current  = datasets[dataset]
        local luadata  = current.luadata or { }
        local usedonly = usedonly and publications.usedentries()
        if usedonly then
            local list = { }
            for k, v in next, luadata do
                if usedonly[k] then
                    list[k] = v
                end
            end
            luadata = list
        end
        report("%s entries from dataset %a saved in %a",table.count(luadata),dataset,filename)
        table.save(filename,luadata)
    end

    function savers.xml(dataset,filename,usedonly)
        local result, n = publications.converttoxml(dataset,true,true,usedonly)
        report("%s entries from dataset %a saved in %a",n,dataset,filename)
        io.savedata(filename,result)
    end

    function publications.save(dataset,filename,kind,usedonly)
        statistics.starttiming(publications)
        if not kind or kind == "" then
            kind = file.suffix(filename)
        end
        local saver = savers[kind]
        if saver then
            usedonly = usedonly ~= v_all
            saver(dataset,filename,usedonly)
        else
            report("unknown format %a for saving %a",kind,dataset)
        end
        statistics.stoptiming(publications)
        return dataset
    end

    commands.btxsavedataset = publications.save

end

-- casters

do

    publications.detailed = setmetatableindex(function(detailed,kind)
        local values = setmetatableindex(function(values,value)
            local caster = casters[kind]
            local cast   = caster and caster(value) or value
            values[value] = cast
            return cast
        end)
        detailed[kind] = values
        return values
    end)

    casters.keyword         = utilities.parsers.settings_to_set

    local pagessplitter     = lpeg.splitat(P("-")^1)

    casters.pagenumber      = function(str)
        local first, last = lpegmatch(pagessplitter,str)
        return first and last and { first, last } or str
    end

end

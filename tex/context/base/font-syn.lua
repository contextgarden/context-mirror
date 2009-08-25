if not modules then modules = { } end modules ['font-syn'] = {
    version   = 1.001,
    comment   = "companion to font-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local next = next
local gsub, lower, match, find, lower, upper = string.gsub, string.lower, string.match, string.find, string.lower, string.upper

local trace_names = false  trackers.register("fonts.names", function(v) trace_names = v end)

--[[ldx--
<p>This module implements a name to filename resolver. Names are resolved
using a table that has keys filtered from the font related files.</p>
--ldx]]--

local texsprint = (tex and tex.sprint) or print

fonts = fonts or { }
input = input or { }
texmf = texmf or { }

fonts.names            = fonts.names         or { }
fonts.names.filters    = fonts.names.filters or { }
fonts.names.data       = fonts.names.data    or { }

local names   = fonts.names
local filters = fonts.names.filters

names.version    = 1.08 -- when adapting this, also changed font-dum.lua
names.basename   = "names"
names.saved      = false
names.loaded     = false
names.be_clever  = true
names.enabled    = true
names.autoreload = toboolean(os.env['MTX.FONTS.AUTOLOAD'] or os.env['MTX_FONTS_AUTOLOAD'] or "no")
names.cache      = containers.define("fonts","data",names.version,true)

--[[ldx--
<p>It would make sense to implement the filters in the related modules,
but to keep the overview, we define them here.</p>
--ldx]]--

filters.otf   = fontloader.info
filters.ttf   = fontloader.info
filters.ttc   = fontloader.info
filters.dfont = fontloader.info

function filters.afm(name)
    -- we could parse the afm file as well, and then report an error but
    -- it's not worth the trouble
    local pfbname = resolvers.find_file(file.removesuffix(name)..".pfb","pfb") or ""
    if pfbname == "" then
        pfbname = resolvers.find_file(file.removesuffix(file.basename(name))..".pfb","pfb") or ""
    end
    if pfbname ~= "" then
        local f = io.open(name)
        if f then
            local hash = { }
            for line in f:lines() do
                local key, value = match(line,"^(.+)%s+(.+)%s*$")
                if key and #key > 0 then
                    hash[lower(key)] = value
                end
                if find(line,"StartCharMetrics") then
                    break
                end
            end
            f:close()
            return hash
        end
    end
    return nil, "no matching pfb file"
end

function filters.pfb(name)
    return fontloader.info(name)
end

--[[ldx--
<p>The scanner loops over the filters using the information stored in
the file databases. Watch how we check not only for the names, but also
for combination with the weight of a font.</p>
--ldx]]--

filters.list = {
    "otf", "ttf", "ttc", "dfont", "afm",
}

filters.fixes = {
    { "reg$", "regular", },
    { "ita$", "italic", },
    { "ital$", "italic", },
    { "cond$", "condensed", },
    { "book$", "", },
}

names.xml_configuration_file    = "fonts.conf" -- a bit weird format, bonus feature
names.environment_path_variable = "OSFONTDIR"  -- the official way, in minimals etc

filters.paths = { }
filters.names = { }

function names.getpaths(trace)
    local hash, result = { }, { }
    local function collect(t)
        for i=1, #t do
            local v = resolvers.clean_path(t[i])
            v = gsub(v,"/+$","")
            local key = lower(v)
            if not hash[key] then
                hash[key], result[#result+1] = true, v
            end
        end
    end
    local path = names.environment_path_variable or ""
    if path ~= "" then
        collect(resolvers.expanded_path_list(path))
    end
    if xml then
        local confname = names.xml_configuration_file or ""
        if confname ~= "" then
            -- first look in the tex tree
            local name = resolvers.find_file(confname,"other")
            if name == "" then
                -- after all, fontconfig is a unix thing
                name = file.join("/etc",confname)
                if not lfs.isfile(name) then
                    name = "" -- force quit
                end
            end
            if name ~= "" and lfs.isfile(name) then
                if trace then
                    logs.report("fontnames","loading fontconfig file: %s",name)
                end
                local xmldata = xml.load(name)
                -- begin of untested mess
                xml.include(xmldata,"include","",true,function(incname)
                    if not file.is_qualified_path(incname) then
                        local path = file.dirname(name) -- main name
                        if path ~= "" then
                            incname = file.join(path,incname)
                        end
                    end
                    if lfs.isfile(incname) then
                        if trace then
                            logs.report("fontnames","merging included fontconfig file: %s",incname)
                        end
                        return io.loaddata(incname)
                    elseif trace then
                        logs.report("fontnames","ignoring included fontconfig file: %s",incname)
                    end
                end)
                -- end of untested mess
                local fontdirs = xml.collect_texts(xmldata,"dir",true)
                if trace then
                    logs.report("fontnames","%s dirs found in fontconfig",#fontdirs)
                end
                collect(fontdirs)
            end
        end
    end
    function names.getpaths()
        return result
    end
    return result
end

function names.cleanname(name)
    return (gsub(lower(name),"[^%a%d]",""))
end

function names.identify(verbose) -- lsr is for kpse
    names.data = {
        version = names.version,
        mapping = { },
    --  sorted = { },
        fallback_mapping = { },
    --  fallback_sorted = { },
    }
    local done, mapping, fallback_mapping, nofread, nofok = { }, names.data.mapping, names.data.fallback_mapping, 0, 0
    local cleanname = names.cleanname
    local function check(result, filename, suffix, is_sub)
        local fontname = result.fullname
        if fontname then
            local n = cleanname(result.fullname)
            if not mapping[n] then
                mapping[n], nofok = { lower(suffix), fontname, filename, is_sub }, nofok + 1
            end
        end
        if result.fontname then
            fontname = fontname or result.fontname
            local n = cleanname(result.fontname)
            if not mapping[n] then
                mapping[n], nofok = { lower(suffix), fontname, filename, is_sub }, nofok + 1
            end
        end
        if result.familyname and result.weight and result.italicangle == 0 then
            local madename = result.familyname .. " " .. result.weight
            fontname = fontname or madename
            local n = cleanname(fontname)
            if not mapping[n] and not fallback_mapping[n] then
                fallback_mapping[n], nofok = { lower(suffix), fontname, filename, is_sub }, nofok + 1
            end
        end
    end
    local trace = verbose or trace_names
    local skip_paths = filters.paths
    local skip_names = filters.names
    local function identify(completename,name,suffix,storedname)
        if not done[name] and io.exists(completename) then
            nofread = nofread + 1
            if #skip_paths > 0 then
                local path = file.dirname(completename)
                for i=1,#skip_paths do
                    if find(path,skip_paths[i]) then
                        if trace then
                            logs.report("fontnames","rejecting path of %s font %s",suffix,completename)
                            logs.push()
                        end
                        return
                    end
                end
            end
            if #skip_names > 0 then
                local base = file.basename(completename)
                for i=1,#skip_paths do
                    if find(base,skip_names[i]) then
                        done[name] = true
                        if trace then
                            logs.report("fontnames","rejecting name of %s font %s",suffix,completename)
                            logs.push()
                        end
                        return
                    end
                end
            end
            if trace_names then
                logs.report("fontnames","identifying %s font %s",suffix,completename)
                logs.push()
            end
            local result, message = filters[lower(suffix)](completename)
            if trace then
                logs.pop()
            end
            if result then
                if not result[1] then
                    check(result,storedname,suffix,false) -- was name
                else
                    for r=1,#result do
                        check(result[r],storedname,suffix,true) -- was name
                    end
                end
                if message and message ~= "" then
                    logs.report("fontnames","warning when identifying %s font %s: %s",suffix,completename,message)
                end
            else
                logs.report("fontnames","error when identifying %s font %s: %s",suffix,completename,message or "unknown")
            end
            done[name] = true
        end
    end
    local totalread, totalok = 0, 0
    local function traverse(what, method)
        for n, suffix in ipairs(filters.list) do
            nofread, nofok  = 0, 0
            local t = os.gettimeofday() -- use elapser
            suffix = lower(suffix)
            logs.report("fontnames", "identifying %s font files with suffix %s",what,suffix)
            method(suffix)
            suffix = upper(suffix)
            logs.report("fontnames", "identifying %s font files with suffix %s",what,suffix)
            method(suffix)
            logs.report("fontnames", "%s %s files identified, %s hash entries added, runtime %0.3f seconds",nofread,what,nofok,os.gettimeofday()-t)
            totalread, totalok = totalread + nofread, totalok + nofok
        end
    end
    local function walk_tree(pathlist,suffix)
        if pathlist then
            for _, path in ipairs(pathlist) do
                path = resolvers.clean_path(path .. "/")
                path = gsub(path,"/+","/")
                local pattern = path .. "**." .. suffix -- ** forces recurse
                logs.report("fontnames", "globbing path %s",pattern)
                local t = dir.glob(pattern)
                for _, completename in pairs(t) do -- ipairs
                    identify(completename,file.basename(completename),suffix,completename)
                end
            end
        end
    end
    traverse("tree", function(suffix) -- TEXTREE only
        resolvers.with_files(".*%." .. suffix .. "$", function(method,root,path,name)
            if method == "file" then
                local completename = root .."/" .. path .. "/" .. name
                identify(completename,name,suffix,name,name)
            end
        end)
    end)
    if texconfig.kpse_init then
        -- we do this only for a stupid names run, not used for context itself,
        -- using the vars is to clumsy so we just stick to a full scan instead
        traverse("lsr", function(suffix) -- all trees
            local pathlist = resolvers.split_path(resolvers.show_path("ls-R") or "")
            walk_tree(pathlist,suffix)
        end)
    else
        traverse("system", function(suffix) -- OSFONTDIR cum suis
            walk_tree(names.getpaths(trace),suffix)
        end)
    end
    local t = { }
    for _, f in ipairs(filters.fixes) do
        local expression, replacement = f[1], f[2]
        for k,v in next, mapping do
            local fix, pos = gsub(k,expression,replacement)
            if pos > 0 and not mapping[fix] then
                t[fix] = v
            end
        end
    end
    local n = 0
    for k,v in next, t do
        mapping[k] = v
        n = n + 1
    end
    local rejected = 0
    for k, v in next, mapping do
        local kind, filename = v[1], v[3]
        if not file.is_qualified_path(filename) and resolvers.find_file(filename,kind) == "" then
            mapping[k] = nil
            rejected = rejected + 1
        end
    end
    if n > 0 then
        logs.report("fontnames", "%s files read, %s normal and %s extra entries added, %s rejected, %s valid",totalread,totalok,n,rejected,totalok+n-rejected)
    end
end

function names.is_permitted(name)
    return containers.is_usable(names.cache(), name)
end
function names.write_data(name,data)
    containers.write(names.cache(),name,data)
end
function names.read_data(name)
    return containers.read(names.cache(),name)
end

function names.load(reload,verbose)
    if not names.loaded then
        if reload then
            if names.is_permitted(names.basename) then
                names.identify(verbose)
                names.write_data(names.basename,names.data)
            else
                logs.report("font table", "unable to access database cache")
            end
            names.saved = true
        else
            names.data = names.read_data(names.basename)
            if not names.saved then
                if table.is_empty(names.data) or table.is_empty(names.data.mapping) then
                    names.load(true)
                end
                names.saved = true
            end
        end
        local data = names.data
        if data then
            data.sorted = table.sortedkeys(data.mapping or { }) or { }
            data.fallback_sorted = table.sortedkeys(data.fallback_mapping or { }) or { }
        else
            logs.report("font table", "accessing the data table failed")
        end
        names.loaded = true
    end
end

function names.list(pattern,reload)
    names.load(reload)
    if names.loaded then
        local t = { }
        local function list_them(mapping,sorted)
            if mapping[pattern] then
                t[pattern] = mapping[pattern]
            else
                for k,v in ipairs(sorted) do
                    if find(v,pattern) then
                        t[v] = mapping[v]
                    end
                end
            end
        end
        local data = names.data
        if data then
            list_them(data.mapping,data.sorted)
            list_them(data.fallback_mapping,data.fallback_sorted)
        end
        return t
    else
        return nil
    end
end

--[[ldx--
<p>The resolver also checks if the cached names are loaded. Being clever
here is for testing purposes only (it deals with names prefixed by an
encoding name).</p>
--ldx]]--

local function found_indeed(mapping,sorted,name)
    local mn = mapping[name]
    if mn then
        return mn[2], mn[3], mn[4]
    end
    if names.be_clever then -- this will become obsolete
        local encoding, tag = match(name,"^(.-)[%-%:](.+)$")
        local mt = mapping[tag]
        if tag and fonts.enc.is_known(encoding) and mt then
            return mt[1], encoding .. "-" .. mt[3], mt[4]
        end
    end
    -- name, type, file
    for k,v in next, mapping do
        if find(k,name) then
            return v[2], v[3], v[4]
        end
    end
    local condensed = gsub(name,"[^%a%d]","")
    local mc = mapping[condensed]
    if mc then
        return mc[2], mc[3], mc[4]
    end
    for k=1,#sorted do
        local v = sorted[k]
        if find(v,condensed) then
            v = mapping[v]
            return v[2], v[3], v[4]
        end
    end
    return nil, nil, nil
end

local function found(name)
    if name and name ~= "" and names.data then
        name = names.cleanname(name)
        local data = names.data
        local fontname, filename, is_sub = found_indeed(data.mapping, data.sorted, name)
        if not fontname or not filename then
            fontname, filename, is_sub = found_indeed(data.fallback_mapping, data.fallback_sorted, name)
        end
        return fontname, filename, is_sub
    else
        return nil, nil, nil
    end
end

local reloaded = false

function names.specification(askedname, sub)
    if askedname and askedname ~= "" and names.enabled then
        askedname = lower(askedname)
        names.load()
        local name, filename, is_sub = found(askedname)
        if not filename and not reloaded and names.autoreload then
            names.loaded = false
            reloaded = true
            io.flush()
            names.load(true)
            name, filename, is_sub = found(askedname)
        end
        return name, filename, is_sub
    end
end

function names.resolve(askedname, sub)
    local name, filename, is_sub = names.specification(askedname, sub)
    return filename, (is_sub and name) or sub
end

--[[ldx--
<p>Fallbacks, not permanent but a transition thing.</p>
--ldx]]--

names.new_to_old = {
    ["lmroman10-capsregular"]                = "lmromancaps10-oblique",
    ["lmroman10-capsoblique"]                = "lmromancaps10-regular",
    ["lmroman10-demi"]                       = "lmromandemi10-oblique",
    ["lmroman10-demioblique"]                = "lmromandemi10-regular",
    ["lmroman8-oblique"]                     = "lmromanslant8-regular",
    ["lmroman9-oblique"]                     = "lmromanslant9-regular",
    ["lmroman10-oblique"]                    = "lmromanslant10-regular",
    ["lmroman12-oblique"]                    = "lmromanslant12-regular",
    ["lmroman17-oblique"]                    = "lmromanslant17-regular",
    ["lmroman10-boldoblique"]                = "lmromanslant10-bold",
    ["lmroman10-dunhill"]                    = "lmromandunh10-oblique",
    ["lmroman10-dunhilloblique"]             = "lmromandunh10-regular",
    ["lmroman10-unslanted"]                  = "lmromanunsl10-regular",
    ["lmsans10-demicondensed"]               = "lmsansdemicond10-regular",
    ["lmsans10-demicondensedoblique"]        = "lmsansdemicond10-oblique",
    ["lmsansquotation8-bold"]                = "lmsansquot8-bold",
    ["lmsansquotation8-boldoblique"]         = "lmsansquot8-boldoblique",
    ["lmsansquotation8-oblique"]             = "lmsansquot8-oblique",
    ["lmsansquotation8-regular"]             = "lmsansquot8-regular",
    ["lmtypewriter8-regular"]                = "lmmono8-regular",
    ["lmtypewriter9-regular"]                = "lmmono9-regular",
    ["lmtypewriter10-regular"]               = "lmmono10-regular",
    ["lmtypewriter12-regular"]               = "lmmono12-regular",
    ["lmtypewriter10-italic"]                = "lmmono10-italic",
    ["lmtypewriter10-oblique"]               = "lmmonoslant10-regular",
    ["lmtypewriter10-capsoblique"]           = "lmmonocaps10-oblique",
    ["lmtypewriter10-capsregular"]           = "lmmonocaps10-regular",
    ["lmtypewriter10-light"]                 = "lmmonolt10-regular",
    ["lmtypewriter10-lightoblique"]          = "lmmonolt10-oblique",
    ["lmtypewriter10-lightcondensed"]        = "lmmonoltcond10-regular",
    ["lmtypewriter10-lightcondensedoblique"] = "lmmonoltcond10-oblique",
    ["lmtypewriter10-dark"]                  = "lmmonolt10-bold",
    ["lmtypewriter10-darkoblique"]           = "lmmonolt10-boldoblique",
    ["lmtypewritervarwd10-regular"]          = "lmmonoproplt10-regular",
    ["lmtypewritervarwd10-oblique"]          = "lmmonoproplt10-oblique",
    ["lmtypewritervarwd10-light"]            = "lmmonoprop10-regular",
    ["lmtypewritervarwd10-lightoblique"]     = "lmmonoprop10-oblique",
    ["lmtypewritervarwd10-dark"]             = "lmmonoproplt10-bold",
    ["lmtypewritervarwd10-darkoblique"]      = "lmmonoproplt10-boldoblique",
}

names.old_to_new = table.swapped(names.new_to_old)

function names.exists(name)
    local fna, found = names.autoreload, false
    names.autoreload = false
    for k,v in ipairs(filters.list) do
        found = (resolvers.find_file(name,v) or "") ~= ""
        if found then
            break
        end
    end
    found = found or (resolvers.find_file(name,"tfm") or "") ~= ""
    found = found or (names.resolve(name) or "") ~= ""
    names.autoreload = fna
    return found
end

if not modules then modules = { } end modules ['font-syn'] = {
    version   = 1.001,
    comment   = "companion to font-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- todo: subs in lookups requests

local next, tonumber = next, tonumber
local gsub, lower, match, find, lower, upper = string.gsub, string.lower, string.match, string.find, string.lower, string.upper
local find, gmatch = string.find, string.gmatch
local concat, sort, format = table.concat, table.sort, string.format

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

names.version    = 1.101
names.basename   = "names"
names.saved      = false
names.loaded     = false
names.be_clever  = true
names.enabled    = true
names.autoreload = toboolean(os.env['MTX.FONTS.AUTOLOAD'] or os.env['MTX_FONTS_AUTOLOAD'] or "no")
names.cache      = containers.define("fonts","data",names.version,true)

--[[ldx--
<p>A few helpers.</p>
--ldx]]--

local P, C, Cc, Cs, Carg = lpeg.P, lpeg.C, lpeg.Cc, lpeg.Cs, lpeg.Carg

-- what to do with 'thin'

local weights = Cs ( -- not extra
    P("demibold")
  + P("semibold")
  + P("mediumbold")
  + P("ultrabold")
  + P("extrabold")
  + P("ultralight")
  + P("bold")
  + P("demi")
  + P("semi")
  + P("light")
  + P("medium")
  + P("heavy")
  + P("ultra")
  + P("black")
  + P("bol")
  + P("regular")  / "normal"
)

local styles = Cs (
    P("reverseoblique") / "reverseitalic"
  + P("regular")        / "normal"
  + P("italic")
  + P("oblique")        / "italic"
  + P("slanted")
  + P("roman")          / "normal"
  + P("ital")           / "italic"
  + P("ita")            / "italic"
)

local widths = Cs(
    P("condensed")
  + P("thin")
  + P("expanded")
  + P("cond")     / "condensed"
  + P("normal")
  + P("book")     / "normal"
)

local any = P(1)

local analysed_table

local analyser = Cs (
    (
        weights / function(s) analysed_table[1] = s return "" end
      + styles  / function(s) analysed_table[2] = s return "" end
      + widths  / function(s) analysed_table[3] = s return "" end
      + any
    )^0
)

local splitter = lpeg.splitat("-")

function names.splitspec(askedname)
    local name, weight, style, width = splitter:match(askedname)
    weight = weight and weights:match(weight) or weight
    style  = style  and styles :match(style)  or style
    width  = width  and widths :match(width)  or width
    if trace_names then
        logs.report("fonts","requested name '%s' split in name '%s', weight '%s', style '%s' and width '%s'",askedname,name or '',weight or '',style or '',width or '')
    end
    if not weight or not weight or not width then
        weight, style, width = weight or "normal", style or "normal", width or "normal"
        if trace_names then
            logs.report("fonts","request '%s' normalized to '%s-%s-%s-%s'",askedname,name,weight,style,width)
        end
    end
    return name or askedname, weight, style, width
end

local function analysespec(somename)
    if somename then
        analysed_table = { }
        local name = analyser:match(somename)
        return name, analysed_table[1], analysed_table[2],analysed_table[3]
    end
end

--[[ldx--
<p>It would make sense to implement the filters in the related modules,
but to keep the overview, we define them here.</p>
--ldx]]--

filters.otf   = fontloader.info
filters.ttf   = fontloader.info
filters.ttc   = fontloader.info
filters.dfont = fontloader.info

function fontloader.fullinfo(...)
    local ff = fontloader.open(...)
    if ff then
        local d = ff and fontloader.to_table(ff)
        d.glyphs, d.subfonts, d.gpos, d.gsub, d.lookups = nil, nil, nil, nil, nil
        fontloader.close(ff)
        return d
    else
        return nil, "error in loading font"
    end
end

filters.otf   = fontloader.fullinfo

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
                if trace_names then
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
                        if trace_names then
                            logs.report("fontnames","merging included fontconfig file: %s",incname)
                        end
                        return io.loaddata(incname)
                    elseif trace_names then
                        logs.report("fontnames","ignoring included fontconfig file: %s",incname)
                    end
                end)
                -- end of untested mess
                local fontdirs = xml.collect_texts(xmldata,"dir",true)
                if trace_names then
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

local function cleanname(name)
    return (gsub(lower(name),"[^%a%d]",""))
end

names.cleanname = cleanname

local function check_names(result)
    local names = result.names
    if names then
        for i=1,#names do
            local name = names[i]
            if name.lang == "English (US)" then
                return name.names
            end
        end
    end
end

local function walk_tree(pathlist,suffix,identify)
    if pathlist then
        for _, path in ipairs(pathlist) do
            path = resolvers.clean_path(path .. "/")
            path = gsub(path,"/+","/")
            local pattern = path .. "**." .. suffix -- ** forces recurse
            logs.report("fontnames", "globbing path %s",pattern)
            local t = dir.glob(pattern)
            sort(t,sorter)
            for _, completename in ipairs(t) do -- ipairs
                identify(completename,file.basename(completename),suffix,completename)
            end
        end
    end
end

local function check_name(data,result,filename,suffix,subfont)
    -- shortcuts
    local specifications = data.specifications
    local families       = data.families
    -- prepare
    local names = check_names(result)
    -- fetch
    local familyname  = (names and names.preffamilyname) or result.familyname
    local fullname    = (names and names.fullname) or result.fullname
    local fontname    = result.fontname
    local subfamily   = (names and names.subfamily)
    local modifiers   = (names and names.prefmodifiers)
    local weight      = (names and names.weight) or result.weight
    local italicangle = tonumber(result.italicangle)
    local subfont     = subfont or nil
    local rawname     = fullname or fontname or familyname
    -- normalize
    familyname  = familyname and cleanname(familyname)
    fullname    = fullname   and cleanname(fullname)
    fontname    = fontname   and cleanname(fontname)
    subfamily   = subfamily  and cleanname(subfamily)
    modifiers   = modifiers  and cleanname(modifiers)
    weight      = weight     and cleanname(weight)
    italicangle = (italicangle == 0) and nil
    -- analyse
    local a_name, a_weight, a_style, a_width = analysespec(fullname or fontname or familyname)
    -- check
    local width = a_width
    local style = modifiers and gsub(modifiers,"[^%a]","")
    if not style and italicangle then
        style = "italic"
    end
    if not weight or weight == "" then
        weight = a_weight
    end
    if not style or style == ""  then
        style = a_style
    end
    if not familyname then
        familyname = a_name
    end
    fontname   = fontname   or fullname or familyname or basename
    fullname   = fullname   or fontname
    familyname = familyname or fontname
    -- register
    local index = #specifications + 1
    specifications[index] = {
        filename    = filename,
        format      = lower(suffix),
        subfont     = subfont,
        rawname     = rawname,
        familyname  = familyname,
        fullname    = fullname,
        fontname    = fontname,
        subfamily   = subfamily,
        modifiers   = modifiers,
        weight      = weight,
        style       = style,
        width       = width,
        minsize     = result.design_range_bottom or 0,
        maxsize     = result.design_range_top or 0,
        designsize  = result.design_size or 0,
    }
    local family = families[familyname]
    if not family then
        families[familyname] = { index }
    else
        family[#family+1] = index
    end
end

local function cleanupkeywords()
    local data = names.data
    local specifications = names.data.specifications
    if specifications then
        local weights, styles, widths, variants = { }, { }, { }, { }
        for i=1,#specifications do
            local s = specifications[i]
            -- fix (sofar styles are taken from the name, and widths from the specification)
            local b_variant, b_weight, b_style, b_width = analysespec(s.weight)
            local c_variant, c_weight, c_style, c_width = analysespec(s.style)
            local d_variant, d_weight, d_style, d_width = analysespec(s.width)
            local e_variant, e_weight, e_style, e_width = analysespec(s.fullname or "")
            local weight  = b_weight  or c_weight  or d_weight  or e_weight  or "normal"
            local style   = b_style   or c_style   or d_style   or e_style   or "normal"
            local width   = b_width   or c_width   or d_width   or e_width   or "normal"
            local variant = b_variant or c_variant or d_variant or e_variant or "normal"
            if weight  then weights [weight ] = (weights [weight ] or 0) + 1 end
            if style   then styles  [style  ] = (styles  [style  ] or 0) + 1 end
            if width   then widths  [width  ] = (widths  [width  ] or 0) + 1 end
            if variant then variants[variant] = (variants[variant] or 0) + 1 end
            if weight ~= s.weight then
                s.fontweight = s.weight
            end
            s.weight, s.style, s.width, s.variant = weight, style, width, variant
        end
        local stats = data.statistics
        stats.used_weights, stats.used_styles, stats.used_widths, stats.used_variants = weights, styles, widths, variants
    end
end

local function collectstatistics()
    local data = names.data
    local specifications = data.specifications
    if specifications then
        local weights, styles, widths = { }, { }, { }
        for i=1,#specifications do
            local s = specifications[i]
            local weight, style, width = s.weight, s.style, s.width
            if weight then weights[weight] = (weights[weight] or 0) + 1 end
            if style  then styles [style ] = (styles [style ] or 0) + 1 end
            if width  then widths [width ] = (widths [width ] or 0) + 1 end
        end
        local stats = data.statistics
        stats.weights, stats.styles, stats.widths, stats.fonts = weights, styles, widths, #specifications
    end
end

local function collecthashes()
    local data = names.data
    local mappings       = data.mappings
    local fallbacks      = data.fallbacks
    local specifications = data.specifications
    local nofmappings, noffallbacks = 0, 0
    if specifications then
        -- maybe multiple passes
        for index=1,#specifications do
            local s = specifications[index]
            local format, fullname, fontname, familyname, weight, subfamily = s.format, s.fullname, s.fontname, s.familyname, s.weight, s.subfamily
            local mf, ff = mappings[format], fallbacks[format]
            if fullname and not mf[fullname] then
                mf[fullname], nofmappings = index, nofmappings + 1
            end
            if fontname and not mf[fontname] then
                mf[fontname], nofmappings = index, nofmappings + 1
            end
            if familyname and weight then
                local madename = familyname .. weight
                if not mf[madename] and not ff[madename] then
                    ff[madename], noffallbacks = index, noffallbacks + 1
                end
            end
            if familyname and subfamily then
                local extraname = familyname .. subfamily
                if not mf[extraname] and not ff[extraname] then
                    ff[extraname], noffallbacks = index, noffallbacks + 1
                end
            end
            if familyname then
                if not mf[familyname] and not ff[familyname] then
                    ff[familyname], noffallbacks = index, noffallbacks + 1
                end
            end
        end
    end
    return nofmappings, noffallbacks
end

local function checkduplicate(mapping) -- fails on "Romantik" but that's a border case anyway
    local data = names.data
    local mapping = data[mapping]
    local specifications, loaded = data.specifications, { }
    if specifications and mapping then
        for _, m in next, mapping do
            for k, v in next, m do
                local s = specifications[v]
                local hash = format("%s-%s-%s-%s",s.familyname,s.weight or "*",s.style or "*",s.width or "*")
                local h = loaded[hash]
                if h then
                    local ok = true
                    local fn = s.filename
                    for i=1,#h do
                        local hn = s.filename
                        if h[i] == fn then
                            ok = false
                            break
                        end
                    end
                    if ok then
                        h[#h+1] = fn
                    end
                else
                    loaded[hash] = { s.filename }
                end
            end
        end
    end
    for k, v in table.sortedpairs(loaded) do
        if #v > 1 then
            logs.report("fontnames", "double lookup: %s => %s",k,concat(v," | "))
        end
    end
end

local function checkduplicates()
    checkduplicate("mappings")
    checkduplicate("fallbacks")
end

local sorter = function(a,b)
    return #a < #b and a < b
end

local function sorthashes()
    local data, list = names.data, filters.list
    local mappings, fallbacks, sorted_mappings, sorted_fallbacks = data.mappings, data.fallbacks, { }, { }
    data.sorted_mappings, data.sorted_fallbacks = sorted_mappings, sorted_fallbacks
    for i=1,#list do
        local l = list[i]
        sorted_mappings[l], sorted_fallbacks[l] = table.keys(mappings[l]), table.keys(fallbacks[l])
        sort(sorted_mappings[l],sorter)
        sort(sorted_fallbacks[l],sorter)
    end
    data.sorted_families = table.keys(data.families)
    sort(data.sorted_families,sorter)
end

local function unpackreferences()
    local data = names.data
    local specifications = data.specifications
    if specifications then
        for k, v in next, data.families do
            for i=1,#v do
                v[i] = specifications[v[i]]
            end
        end
    end
    local mappings = data.mappings
    if mappings then
        for _, m in next, mappings do
            for k, v in next, m do
                m[k] = specifications[v]
            end
        end
    end
    local fallbacks = data.fallbacks
    if fallbacks then
        for _, f in next, fallbacks do
            for k, v in next, f do
                f[k] = specifications[v]
            end
        end
    end
end

local function analysefiles()
    local data = names.data
    local done, totalnofread, totalnofskipped = { }, 0, 0
    local skip_paths, skip_names = filters.paths, filters.names
    local function identify(completename,name,suffix,storedname)
        local basename = file.basename(completename)
        local basepath = file.dirname(completename)
        if done[name] then
            -- already done (avoid otf afm clash)
        elseif not io.exists(completename) then
            -- weird error
        elseif not file.is_qualified_path(completename) and resolvers.find_file(completename,suffix) == "" then
            -- not locateble by backend anyway
        else
            nofread = nofread + 1
            if #skip_paths > 0 then
                for i=1,#skip_paths do
                    if find(basepath,skip_paths[i]) then
                        if trace_names then
                            logs.report("fontnames","rejecting path of %s font %s",suffix,completename)
                            logs.push()
                        end
                        return
                    end
                end
            end
            if #skip_names > 0 then
                for i=1,#skip_paths do
                    if find(basename,skip_names[i]) then
                        done[name] = true
                        if trace_names then
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
            if trace_names then
                logs.pop()
            end
            if result then
                if not result[1] then
                    local ok = check_name(data,result,storedname,suffix)
                    if not ok then
                        nofskipped = nofskipped + 1
                    end
                else
                    for r=1,#result do
                        local ok = check_name(data,result[r],storedname,suffix,r-1) -- subfonts start at zero
                        if not ok then
                            nofskipped = nofskipped + 1
                        end
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
    local function traverse(what, method)
        for n, suffix in ipairs(filters.list) do
            local t = os.gettimeofday() -- use elapser
            nofread, nofskipped = 0, 0
            suffix = lower(suffix)
            logs.report("fontnames", "identifying %s font files with suffix %s",what,suffix)
            method(suffix)
            suffix = upper(suffix)
            logs.report("fontnames", "identifying %s font files with suffix %s",what,suffix)
            method(suffix)
            totalnofread, totalnofskipped = totalnofread + nofread, totalnofskipped + nofskipped
            local elapsed = os.gettimeofday() - t
            logs.report("fontnames", "%s %s files identified, %s hash entries added, runtime %0.3f seconds",nofread,what,nofread-nofskipped,elapsed)
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
            walk_tree(pathlist,suffix,identify)
        end)
    else
        traverse("system", function(suffix) -- OSFONTDIR cum suis
            walk_tree(names.getpaths(trace),suffix,identify)
        end)
    end
    data.statistics.readfiles, data.statistics.skippedfiles = totalnofread, totalnofskipped
end

local function rejectclashes() -- just to be sure, so no explicit afm will be found then
    local specifications, used, okay = names.data.specifications, { }, { }
    for i=1,#specifications do
        local s = specifications[i]
        local f = s.fontname
        if f then
            local fnd, fnm = used[f], s.filename
            if fnd then
                logs.report("fontnames", "fontname '%s' clashes, rejecting '%s' in favor of '%s'",f,fnm,fnd)
            else
                used[f], okay[#okay+1] = fnm, s
            end
        else
            okay[#okay+1] = s
        end
    end
    local d = #specifications - #okay
    if d > 0 then
        logs.report("fontnames", "%s files rejected due to clashes",d)
    end
    names.data.specifications = okay
end

local function resetdata()
    local mappings, fallbacks = { }, { }
    for _, k in next, filters.list do
        mappings[k], fallbacks[k] = { }, { }
    end
    names.data = {
        version = names.version,
        mappings = mappings,
        fallbacks = fallbacks,
        specifications = { },
        families = { },
        statistics = { },
        data_state = resolvers.data_state(),
    }
end

function names.identify()
    resetdata()
    analysefiles()
    rejectclashes()
    collectstatistics()
    cleanupkeywords()
    collecthashes()
    checkduplicates()
 -- sorthashes() -- will be resorted when saved
 --~     logs.report("fontnames", "%s files read, %s normal and %s extra entries added, %s rejected, %s valid",totalread,totalok,added,rejected,totalok+added-rejected)
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
        end
        local data = names.read_data(names.basename)
        names.data = data
        if not names.saved then
            if not data or not next(data) or not data.specifications or not next(data.specifications) then
               names.load(true)
            end
            names.saved = true
        end
        if not data then
            logs.report("font table", "accessing the data table failed")
        else
            unpackreferences()
            sorthashes()
        end
        names.loaded = true
    end
end

local function list_them(mapping,sorted,pattern,t,all)
    if mapping[pattern] then
        t[pattern] = mapping[pattern]
    else
        for k=1,#sorted do
            local v = sorted[k]
            if not t[v] and find(v,pattern) then
                t[v] = mapping[v]
                if not all then
                    return
                end
            end
        end
    end
end

function names.list(pattern,reload,all) -- here?
    names.load(reload)
    if names.loaded then
        local t = { }
        local data = names.data
        if data then
            local list = filters.list
            local mappings, sorted_mappings = data.mappings, data.sorted_mappings
            local fallbacks, sorted_fallbacks = data.fallbacks, data.sorted_fallbacks
            for i=1,#list do
                local format = list[i]
                list_them(mappings[format],sorted_mappings[format],pattern,t,all)
                if next(t) and not all then
                    return t
                end
                list_them(fallbacks[format],sorted_fallbacks[format],pattern,t,all)
                if next(t) and not all then
                    return t
                end
            end
        end
        return t
    end
end

local reloaded = false

local function is_reloaded()
    if not reloaded then
        local data = names.data
        if names.autoreload then
            local c_status = table.serialize(resolvers.data_state())
            local f_status = table.serialize(data.data_state)
            if c_status == f_status then
                logs.report("fonts","font database matches configuration and file hashes")
                return
            else
                logs.report("fonts","font database does not match configuration and file hashes")
            end
        end
        names.loaded = false
        reloaded = true
        io.flush()
        names.load(true)
    end
end

--[[ldx--
<p>The resolver also checks if the cached names are loaded. Being clever
here is for testing purposes only (it deals with names prefixed by an
encoding name).</p>
--ldx]]--

-- if names.be_clever then -- this will become obsolete
--     local encoding, tag = match(name,"^(.-)[%-%:](.+)$")
--     local mt = mapping[tag]
--     if tag and fonts.enc.is_known(encoding) and mt then
--         return mt[1], encoding .. "-" .. mt[3], mt[4]
--     end
-- end

-- simple search

local function found(mapping,sorted,name,sub)
    local found = mapping[name]
    -- obsolete: old encoding test
    if not found then
        for k,v in next, mapping do
            if find(k,name) then
                found = v
                break
            end
        end
        if not found then
            local condensed = gsub(name,"[^%a%d]","")
            found = mapping[condensed]
            if not found then
                for k=1,#sorted do
                    local v = sorted[k]
                    if find(v,condensed) then
                        found = mapping[v]
                        break
                    end
                end
            end
        end
    end
    return found
end

local function foundname(name,sub)
    local data = names.data
    local mappings, sorted_mappings = data.mappings, data.sorted_mappings
    local fallbacks, sorted_fallbacks = data.fallbacks, data.sorted_fallbacks
    local list = filters.list
    for i=1,#list do
        local l = list[i]
        local okay = found(mappings[l],sorted_mappings[l],name,sub) or found(fallbacks[l],sorted_fallbacks[l],name,sub)
        if okay then
            return okay
        end
    end
end

function names.resolvedspecification(askedname,sub)
    if askedname and askedname ~= "" and names.enabled then
        askedname = cleanname(askedname)
        names.load()
        local found = foundname(askedname,sub)
        if not found and is_reloaded() then
            found = foundname(askedname,sub)
        end
        return found
    end
end

function names.resolve(askedname,sub)
    local found = names.resolvedspecification(askedname,sub)
    if found then
        return found.filename, found.subfont and found.rawname
    end
end

-- specified search

local function s_collect_weight_style_width(found,done,all,weight,style,width,family)
    if family then
        for i=1,#family do
            local f = family[i]
            if f and weight == f.weight and style == f.style and width == f.width then
                found[#found+1], done[f] = f, true
                if not all then return end
            end
        end
    end
end
local function m_collect_weight_style_width(found,done,all,weight,style,width,families,sorted,strictname)
    for i=1,#sorted do
        local k = sorted[i]
        local family = families[k]
        for i=1,#family do
            local f = family[i]
            if not done[f] and weight == f.weight and style == f.style and width == f.width and find(f.fontname,strictname) then
                found[#found+1], done[f] = f, true
                if not all then return end
            end
        end
    end
end

local function s_collect_weight_style(found,done,all,weight,style,family)
    if family then
        for i=1,#family do local f = family[i]
            if f and weight == f.weight and style == f.style then
                found[#found+1], done[f] = f, true
                if not all then return end
            end
        end
    end
end
local function m_collect_weight_style(found,done,all,weight,style,families,sorted,strictname)
    for i=1,#sorted do
        local k = sorted[i]
        local family = families[k]
        for i=1,#family do
            local f = family[i]
            if not done[f] and weight == f.weight and style == f.style and find(f.fontname,strictname) then
                found[#found+1], done[f] = f, true
                if not all then return end
            end
        end
    end
end

local function s_collect_style_width(found,done,all,style,width,family)
    if family then
        for i=1,#family do local f = family[i]
            if f and style == f.style and width == f.width then
                found[#found+1], done[f] = f, true
                if not all then return end
            end
        end
    end
end
local function m_collect_style_width(found,done,all,style,width,families,sorted,strictname)
    for i=1,#sorted do
        local k = sorted[i]
        local family = families[k]
        for i=1,#family do
            local f = family[i]
            if not done[f] and style == f.style and width == f.width and find(f.fontname,strictname) then
                found[#found+1], done[f] = f, true
                if not all then return end
            end
        end
    end
end

local function s_collect_weight(found,done,all,weight,family)
    if family then
        for i=1,#family do local f = family[i]
            if f and weight == f.weight then
                found[#found+1], done[f] = f, true
                if not all then return end
            end
        end
    end
end
local function m_collect_weight(found,done,all,weight,families,sorted,strictname)
    for i=1,#sorted do
        local k = sorted[i]
        local family = families[k]
        for i=1,#family do
            local f = family[i]
            if not done[f] and weight == f.weight and find(f.fontname,strictname) then
                found[#found+1], done[f] = f, true
                if not all then return end
            end
        end
    end
end

local function s_collect_style(found,done,all,style,family)
    if family then
        for i=1,#family do local f = family[i]
            if f and style == f.style then
                found[#found+1], done[f] = f, true
                if not all then return end
            end
        end
    end
end
local function m_collect_style(found,done,all,style,families,sorted,strictname)
    for i=1,#sorted do
        local k = sorted[i]
        local family = families[k]
        for i=1,#family do
            local f = family[i]
            if not done[f] and style == f.style and find(f.fontname,strictname) then
                found[#found+1], done[f] = f, true
                if not all then return end
            end
        end
    end
end

local function s_collect_width(found,done,all,width,family)
    if family then
        for i=1,#family do local f = family[i]
            if f and width == f.width then
                found[#found+1], done[f] = f, true
                if not all then return end
            end
        end
    end
end
local function m_collect_width(found,done,all,width,families,sorted,strictname)
    for i=1,#sorted do
        local k = sorted[i]
        local family = families[k]
        for i=1,#family do
            local f = family[i]
            if not done[f] and width == f.width and find(f.fontname,strictname) then
                found[#found+1], done[f] = f, true
                if not all then return end
            end
        end
    end
end

local function s_collect(found,done,all,family)
    if family then
        for i=1,#family do local f = family[i]
            if f then
                found[#found+1], done[f] = f, true
                if not all then return end
            end
        end
    end
end
local function m_collect(found,done,all,families,sorted,strictname)
    for i=1,#sorted do
        local k = sorted[i]
        local family = families[k]
        for i=1,#family do
            local f = family[i]
            if not done[f] and find(f.fontname,strictname) then
                found[#found+1], done[f] = f, true
                if not all then return end
            end
        end
    end
end

local function collect(stage,found,done,name,weight,style,width,all)
    local data = names.data
    local families, sorted = data.families, data.sorted_families
    strictname = "^".. name -- to be checked
    local family = families[name]
    if trace_names then
        logs.report("fonts","resolving name '%s', weight '%s', style '%s', width '%s'",name or "?",tostring(weight),tostring(style),tostring(width))
    end
    if weight and weight ~= "" then
        if style and style ~= "" then
            if width and width ~= "" then
                if trace_names then
                    logs.report("fonts","resolving stage %s, name '%s', weight '%s', style '%s', width '%s'",stage,name,weight,style,width)
                end
                s_collect_weight_style_width(found,done,all,weight,style,width,family)
                m_collect_weight_style_width(found,done,all,weight,style,width,families,sorted,strictname)
            else
                if trace_names then
                    logs.report("fonts","resolving stage %s, name '%s', weight '%s', style '%s'",stage,name,weight,style)
                end
                s_collect_weight_style(found,done,all,weight,style,family)
                m_collect_weight_style(found,done,all,weight,style,families,sorted,strictname)
            end
        else
            if trace_names then
                logs.report("fonts","resolving stage %s, name '%s', weight '%s'",stage,name,weight)
            end
            s_collect_weight(found,done,all,weight,family)
            m_collect_weight(found,done,all,weight,families,sorted,strictname)
        end
    elseif style and style ~= "" then
        if width and width ~= "" then
            if trace_names then
                logs.report("fonts","resolving stage %s, name '%s', style '%s', width '%s'",stage,name,style,width)
            end
            s_collect_style_width(found,done,all,style,width,family)
            m_collect_style_width(found,done,all,style,width,families,sorted,strictname)
        else
            if trace_names then
                logs.report("fonts","resolving stage %s, name '%s', style '%s'",stage,name,style)
            end
            s_collect_style(found,done,all,style,family)
            m_collect_style(found,done,all,style,families,sorted,strictname)
        end
    elseif width and width ~= "" then
        if trace_names then
            logs.report("fonts","resolving stage %s, name '%s', width '%s'",stage,name,width)
        end
        s_collect_width(found,done,all,width,family)
        m_collect_width(found,done,all,width,families,sorted,strictname)
    else
        if trace_names then
            logs.report("fonts","resolving stage %s, name '%s'",stage,name)
        end
        s_collect(found,done,all,family)
        m_collect(found,done,all,families,sorted,strictname)
    end
end

function heuristic(name,weight,style,width,all) -- todo: fallbacks
    local found, done = { }, { }
    weight, style = weight or "", style or ""
    name = cleanname(name)
    collect(1,found,done,name,weight,style,width,all)
    -- still needed ?
    if #found == 0 and width ~= "" then
        width = ""
        collect(2,found,done,name,weight,style,width,all)
    end
    if #found == 0 and weight ~= "" then -- not style
        weight = ""
        collect(3,found,done,name,weight,style,width,all)
    end
    if #found == 0 and style ~= "" then -- not weight
        style = ""
        collect(4,found,done,name,weight,style,width,all)
    end
    --
    local nf = #found
    if trace_names then
        if nf then
            local t = { }
            for i=1,nf do
                t[#t+1] = format("'%s'",found[i].fontname)
            end
            logs.report("fonts","name '%s' resolved to %s instances: %s",name,nf,concat(t," "))
        else
            logs.report("fonts","name '%s' unresolved",name)
        end
    end
    if all then
        return nf > 0 and found
    else
        return found[1]
    end
end

function names.specification(askedname,weight,style,width,reload,all)
    if askedname and askedname ~= "" and names.enabled then
        askedname = lower(askedname) -- or cleanname
        names.load(reload)
        local found = heuristic(askedname,weight,style,width,all)
        if not found and is_reloaded() then
            found = heuristic(askedname,weight,style,width,all)
            if not filename then
                found = foundname(askedname) -- old method
            end
        end
        return found
    end
end

function names.collect(askedname,weight,style,width,reload,all)
    if askedname and askedname ~= "" and names.enabled then
        askedname = lower(askedname) -- or cleanname
        names.load(reload)
        local list = heuristic(askedname,weight,style,width,true)
        if not list or #list == 0 and is_reloaded() then
            list = heuristic(askedname,weight,style,width,true)
        end
        return list
    end
end

function names.collectspec(askedname,reload,all)
    local name, weight, style, width = names.splitspec(askedname)
    return names.collect(name,weight,style,width,reload,all)
end

function names.resolvespec(askedname,sub)
    local found = names.specification(names.splitspec(askedname))
    if found then
        return found.filename, found.subfont and found.rawname
    end
end

function names.collectfiles(askedname,reload) -- no all
    if askedname and askedname ~= "" and names.enabled then
        askedname = lower(askedname) -- or cleanname
        names.load(reload)
        local list = { }
        local basename = file.basename
        local specifications = names.data.specifications
        for i=1,#specifications do
            local s = specifications[i]
            if find(lower(basename(s.filename)),askedname) then
                list[#list+1] = s
            end
        end
        return list
    end
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
    local found = false
    for k,v in ipairs(filters.list) do
        found = (resolvers.find_file(name,v) or "") ~= ""
        if found then
            return found
        end
    end
    return ((resolvers.find_file(name,"tfm") or "") ~= "") or ((names.resolve(name) or "") ~= "")
end

-- for i=1,fonts.names.lookup(pattern) do
--     texio.write_nl(fonts.names.getkey("filename",i))
-- end

local lastlookups, lastpattern = { }, ""

function names.lookup(pattern,name,reload) -- todo: find
    if lastpattern ~= pattern then
        names.load(reload)
        local specifications = names.data.specifications
        local families = names.data.families
        local lookups = specifications
        if name then
            lookups = families[name]
        elseif not find(pattern,"=") then
            lookups = families[pattern]
        end
        if trace_names then
            logs.report("fonts","starting with %s lookups for '%s'",#lookups,pattern)
        end
        if lookups then
            for key, value in gmatch(pattern,"([^=,]+)=([^=,]+)") do
                local t = { }
                for i=1,#lookups do
                    local s = lookups[i]
                    if s[key] == value then
                        t[#t+1] = lookups[i]
                    end
                end
                if trace_names then
                    logs.report("fonts","%s matches for key '%s' with value '%s'",#t,key,value)
                end
                lookups = t
            end
        end
        lastpattern = pattern
        lastlookups = lookups or { }
    end
    return #lastlookups
end

function names.getlookupkey(key,n)
    local l = lastlookups[n or 1]
    return (l and l[key]) or ""
end

function names.noflookups()
    return #lastlookups
end

function names.getlookups(pattern,name,reload)
    if pattern then
        names.lookup(pattern,name,reload)
    end
    return lastlookups
end

function table.formatcolumns(result)
    if result and #result > 0 then
        local widths = { }
        local first = result[1]
        local n = #first
        for i=1,n do
            widths[i] = 0
        end
        for i=1,#result do
            local r = result[i]
            for j=1,n do
                local w = #r[j]
                if w > widths[j] then
                    widths[j] = w
                end
            end
        end
        for i=1,n do
            widths[i] = "%-" .. widths[i] .. "s"
        end
        local template = concat(widths,"   ")
        for i=1,#result do
            local str = format(template,unpack(result[i]))
            result[i] = string.strip(str)
        end
    end
    return result
end

if not modules then modules = { } end modules ['font-syn'] = {
    version   = 1.001,
    comment   = "companion to font-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- todo: subs in lookups requests

local utf = unicode.utf8
local next, tonumber = next, tonumber
local sub, gsub, lower, match, find, lower, upper = string.sub, string.gsub, string.lower, string.match, string.find, string.lower, string.upper
local find, gmatch = string.find, string.gmatch
local concat, sort, format = table.concat, table.sort, string.format
local serialize = table.serialize
local lpegmatch = lpeg.match
local unpack = unpack or table.unpack

local allocate = utilities.storage.allocate
local sparse   = utilities.storage.sparse

local trace_names          = false  trackers.register("fonts.names",          function(v) trace_names          = v end)
local trace_warnings       = false  trackers.register("fonts.warnings",       function(v) trace_warnings       = v end)
local trace_specifications = false  trackers.register("fonts.specifications", function(v) trace_specifications = v end)

local report_names = logs.reporter("fonts","names")

--[[ldx--
<p>This module implements a name to filename resolver. Names are resolved
using a table that has keys filtered from the font related files.</p>
--ldx]]--

fonts            = fonts or { } -- also used elsewhere

local names      = font.names or allocate { }
fonts.names      = names

local filters    = names.filters or { }
names.filters    = filters

names.data       = names.data or allocate { }

names.version    = 1.110
names.basename   = "names"
names.saved      = false
names.loaded     = false
names.be_clever  = true
names.enabled    = true
names.cache      = containers.define("fonts","data",names.version,true)

local autoreload = true

directives.register("fonts.autoreload", function(v) autoreload = toboolean(v) end)

--[[ldx--
<p>A few helpers.</p>
--ldx]]--

local P, C, Cc, Cs = lpeg.P, lpeg.C, lpeg.Cc, lpeg.Cs

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
  + P("bol")   -- / "bold"
  + P("regular")  / "normal"
)

local normalized_weights = sparse {
    regular = "normal",
}

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

local normalized_styles = sparse {
    reverseoblique = "reverseitalic",
    regular        = "normal",
    oblique        = "italic",
}

local widths = Cs(
    P("condensed")
  + P("thin")
  + P("expanded")
  + P("cond")     / "condensed"
  + P("normal")
  + P("book")     / "normal"
)

local normalized_widths = sparse()

local variants = Cs( -- fax casual
    P("smallcaps")
  + P("oldstyle")
  + P("caps")      / "smallcaps"
)

local normalized_variants = sparse()

names.knownweights = {
    "black",
    "bold",
    "demi",
    "demibold",
    "extrabold",
    "heavy",
    "light",
    "medium",
    "mediumbold",
    "normal",
    "regular",
    "semi",
    "semibold",
    "ultra",
    "ultrabold",
    "ultralight",
}

names.knownstyles = {
    "italic",
    "normal",
    "oblique",
    "regular",
    "reverseitalic",
    "reverseoblique",
    "roman",
    "slanted",
}

names.knownwidths = {
  "book",
  "condensed",
  "expanded",
  "normal",
  "thin",
}

names.knownvariants = {
  "normal",
  "oldstyle",
  "smallcaps",
}

local any = P(1)

local analyzed_table

local analyzer = Cs (
    (
        weights  / function(s) analyzed_table[1] = s return "" end
      + styles   / function(s) analyzed_table[2] = s return "" end
      + widths   / function(s) analyzed_table[3] = s return "" end
      + variants / function(s) analyzed_table[4] = s return "" end
      + any
    )^0
)

local splitter = lpeg.splitat("-")

function names.splitspec(askedname)
    local name, weight, style, width, variant = lpegmatch(splitter,askedname)
    weight  = weight  and lpegmatch(weights, weight)  or weight
    style   = style   and lpegmatch(styles,  style)   or style
    width   = width   and lpegmatch(widths,  width)   or width
    variant = variant and lpegmatch(variants,variant) or variant
    if trace_names then
        report_names("requested name '%s' split in name '%s', weight '%s', style '%s', width '%s' and variant '%s'",
            askedname,name or '',weight or '',style or '',width or '',variant or '')
    end
    if not weight or not weight or not width or not variant then
        weight, style, width, variant = weight or "normal", style or "normal", width or "normal", variant or "normal"
        if trace_names then
            report_names("request '%s' normalized to '%s-%s-%s-%s-%s'",
                askedname,name,weight,style,width,variant)
        end
    end
    return name or askedname, weight, style, width, variant
end

local function analyzespec(somename)
    if somename then
        analyzed_table = { }
        local name = lpegmatch(analyzer,somename)
        return name, analyzed_table[1], analyzed_table[2], analyzed_table[3], analyzed_table[4]
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

filters.otf = fontloader.fullinfo

function filters.afm(name)
    -- we could parse the afm file as well, and then report an error but
    -- it's not worth the trouble
    local pfbname = resolvers.findfile(file.removesuffix(name)..".pfb","pfb") or ""
    if pfbname == "" then
        pfbname = resolvers.findfile(file.removesuffix(file.basename(name))..".pfb","pfb") or ""
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
--~   "ttc",  "otf", "ttf", "dfont", "afm",
}

names.fontconfigfile    = "fonts.conf" -- a bit weird format, bonus feature
names.osfontdirvariable = "OSFONTDIR"  -- the official way, in minimals etc

filters.paths = { }
filters.names = { }

function names.getpaths(trace)
    local hash, result, r = { }, { }, 0
    local function collect(t,where)
        for i=1, #t do
            local v = resolvers.cleanpath(t[i])
            v = gsub(v,"/+$","") -- not needed any more
            local key = lower(v)
            report_names("adding path from %s: %s",where,v)
            if not hash[key] then
                r = r + 1
                result[r] = v
                hash[key] = true
            end
        end
    end
    local path = names.osfontdirvariable or ""
    if path ~= "" then
        collect(resolvers.expandedpathlist(path),path)
    end
    if xml then
        local confname = resolvers.expansion("FONTCONFIG_FILE") or ""
        if confname == "" then
            confname = names.fontconfigfile or ""
        end
        if confname ~= "" then
            -- first look in the tex tree
            local name = resolvers.findfile(confname,"fontconfig files") or ""
            if name == "" then
                -- after all, fontconfig is a unix thing
                name = file.join("/etc",confname)
                if not lfs.isfile(name) then
                    name = "" -- force quit
                end
            end
            if name ~= "" and lfs.isfile(name) then
                if trace_names then
                    report_names("loading fontconfig file: %s",name)
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
                            report_names("merging included fontconfig file: %s",incname)
                        end
                        return io.loaddata(incname)
                    elseif trace_names then
                        report_names("ignoring included fontconfig file: %s",incname)
                    end
                end)
                -- end of untested mess
                local fontdirs = xml.collect_texts(xmldata,"dir",true)
                if trace_names then
                    report_names("%s dirs found in fontconfig",#fontdirs)
                end
                collect(fontdirs,"fontconfig file")
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

local function cleanfilename(fullname,defaultsuffix)
    local path, name, suffix = file.splitname(fullname)
    name = gsub(lower(name),"[^%a%d]","")
    if suffix and suffix ~= "" then
        return name .. ".".. suffix
    elseif defaultsuffix and defaultsuffix ~= "" then
        return name .. ".".. defaultsuffix
    else
        return name
    end
end

names.cleanname     = cleanname
names.cleanfilename = cleanfilename

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
        for i=1,#pathlist do
            local path = pathlist[i]
            path = resolvers.cleanpath(path .. "/")
            path = gsub(path,"/+","/")
            local pattern = path .. "**." .. suffix -- ** forces recurse
            report_names( "globbing path %s",pattern)
            local t = dir.glob(pattern)
            sort(t,sorter)
            for j=1,#t do
                local completename = t[j]
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
    -- analyze
    local a_name, a_weight, a_style, a_width, a_variant = analyzespec(fullname or fontname or familyname)
    -- check
    local width = a_width
    local variant = a_variant
    local style = modifiers and gsub(modifiers,"[^%a]","")
    if not style and italicangle then
        style = "italic"
    end
    if not variant or variant == "" then
        variant = "normal"
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
    fontname   = fontname   or fullname or familyname or file.basename(filename)
    fullname   = fullname   or fontname
    familyname = familyname or fontname
    specifications[#specifications + 1] = {
        filename    = filename, -- unresolved
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
        variant     = variant,
        minsize     = result.design_range_bottom or 0,
        maxsize     = result.design_range_top or 0,
        designsize  = result.design_size or 0,
    }
end

local function cleanupkeywords()
    local data = names.data
    local specifications = names.data.specifications
    if specifications then
        local weights, styles, widths, variants = { }, { }, { }, { }
        for i=1,#specifications do
            local s = specifications[i]
            -- fix (sofar styles are taken from the name, and widths from the specification)
            local _, b_weight, b_style, b_width, b_variant = analyzespec(s.weight)
            local _, c_weight, c_style, c_width, c_variant = analyzespec(s.style)
            local _, d_weight, d_style, d_width, d_variant = analyzespec(s.width)
            local _, e_weight, e_style, e_width, e_variant = analyzespec(s.variant)
            local _, f_weight, f_style, f_width, f_variant = analyzespec(s.fullname or "")
            local weight  = b_weight  or c_weight  or d_weight  or e_weight  or f_weight  or "normal"
            local style   = b_style   or c_style   or d_style   or e_style   or f_style   or "normal"
            local width   = b_width   or c_width   or d_width   or e_width   or f_width   or "normal"
            local variant = b_variant or c_variant or d_variant or e_variant or f_variant or "normal"
            if not weight  or weight  == "" then weight  = "normal" end
            if not style   or style   == "" then style   = "normal" end
            if not width   or width   == "" then width   = "normal" end
            if not variant or variant == "" then variant = "normal" end
            weights [weight ] = (weights [weight ] or 0) + 1
            styles  [style  ] = (styles  [style  ] or 0) + 1
            widths  [width  ] = (widths  [width  ] or 0) + 1
            variants[variant] = (variants[variant] or 0) + 1
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
        local weights, styles, widths, variants = { }, { }, { }, { }
        for i=1,#specifications do
            local s = specifications[i]
            local weight, style, width, variant = s.weight, s.style, s.width, s.variant
            if weight  then weights [weight ] = (weights [weight ] or 0) + 1 end
            if style   then styles  [style  ] = (styles  [style  ] or 0) + 1 end
            if width   then widths  [width  ] = (widths  [width  ] or 0) + 1 end
            if variant then variants[variant] = (variants[variant] or 0) + 1 end
        end
        local stats = data.statistics
        stats.weights, stats.styles, stats.widths, stats.variants, stats.fonts = weights, styles, widths, variants, #specifications
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
            if familyname and weight and weight ~= sub(familyname,#familyname-#weight+1,#familyname) then
                local madename = familyname .. weight
                if not mf[madename] and not ff[madename] then
                    ff[madename], noffallbacks = index, noffallbacks + 1
                end
            end
            if familyname and subfamily and subfamily ~= sub(familyname,#familyname-#subfamily+1,#familyname) then
                local extraname = familyname .. subfamily
                if not mf[extraname] and not ff[extraname] then
                    ff[extraname], noffallbacks = index, noffallbacks + 1
                end
            end
            if familyname and not mf[familyname] and not ff[familyname] then
                ff[familyname], noffallbacks = index, noffallbacks + 1
            end
        end
    end
    return nofmappings, noffallbacks
end

local function collectfamilies()
    local data = names.data
    local specifications = data.specifications
    local families = data.families
    for index=1,#specifications do
        local familyname = specifications[index].familyname
        local family = families[familyname]
        if not family then
            families[familyname] = { index }
        else
            family[#family+1] = index
        end
    end
end

local function checkduplicate(where) -- fails on "Romantik" but that's a border case anyway
    local data = names.data
    local mapping = data[where]
    local specifications, loaded = data.specifications, { }
    if specifications and mapping then
        for _, m in next, mapping do
            for k, v in next, m do
                local s = specifications[v]
                local hash = format("%s-%s-%s-%s-%s",s.familyname,s.weight or "*",s.style or "*",s.width or "*",s.variant or "*")
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
    local n = 0
    for k, v in table.sortedhash(loaded) do
        local nv = #v
        if nv > 1 then
            if trace_warnings then
                report_names( "double lookup: %s => %s",k,concat(v," | "))
            end
            n = n + nv
        end
    end
    report_names( "%s double lookups in %s",n,where)
end

local function checkduplicates()
    checkduplicate("mappings")
    checkduplicate("fallbacks")
end

local sorter = function(a,b)
    return a > b -- to be checked
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
end

local function analyzefiles()
    local data = names.data
    local done, totalnofread, totalnofskipped, totalnofduplicates, nofread, nofskipped, nofduplicates = { }, 0, 0, 0, 0, 0, 0
    local skip_paths, skip_names = filters.paths, filters.names
--~ local trace_warnings = true
    local function identify(completename,name,suffix,storedname)
        local basename = file.basename(completename)
        local basepath = file.dirname(completename)
        nofread = nofread + 1
        if done[name] then
            -- already done (avoid otf afm clash)
            if trace_names then
                report_names("%s font %s already done",suffix,completename)
            end
            nofduplicates = nofduplicates + 1
            nofskipped = nofskipped + 1
        elseif not io.exists(completename) then
            -- weird error
            if trace_names then
                report_names("%s font %s does not really exist",suffix,completename)
            end
            nofskipped = nofskipped + 1
        elseif not file.is_qualified_path(completename) and resolvers.findfile(completename,suffix) == "" then
            -- not locateble by backend anyway
            if trace_names then
                report_names("%s font %s cannot be found by backend",suffix,completename)
            end
            nofskipped = nofskipped + 1
        else
            if #skip_paths > 0 then
                for i=1,#skip_paths do
                    if find(basepath,skip_paths[i]) then
                        if trace_names then
                            report_names("rejecting path of %s font %s",suffix,completename)
                        end
                        nofskipped = nofskipped + 1
                        return
                    end
                end
            end
            if #skip_names > 0 then
                for i=1,#skip_paths do
                    if find(basename,skip_names[i]) then
                        done[name] = true
                        if trace_names then
                            report_names("rejecting name of %s font %s",suffix,completename)
                        end
                        nofskipped = nofskipped + 1
                        return
                    end
                end
            end
            if trace_names then
                report_names("identifying %s font %s",suffix,completename)
            end
            local result, message = filters[lower(suffix)](completename)
            if result then
                if result[1] then
                    for r=1,#result do
                        local ok = check_name(data,result[r],storedname,suffix,r-1) -- subfonts start at zero
                     -- if not ok then
                     --     nofskipped = nofskipped + 1
                     -- end
                    end
                else
                    local ok = check_name(data,result,storedname,suffix)
                 -- if not ok then
                 --     nofskipped = nofskipped + 1
                 -- end
                end
                if trace_warnings and message and message ~= "" then
                    report_names("warning when identifying %s font %s: %s",suffix,completename,message)
                end
            elseif trace_warnings then
                nofskipped = nofskipped + 1
                report_names("error when identifying %s font %s: %s",suffix,completename,message or "unknown")
            end
            done[name] = true
        end
        logs.flush() --  a bit overkill for each font, maybe not needed here
    end
    local function traverse(what, method)
        local list = filters.list
        for n=1,#list do
            local suffix = list[n]
            local t = os.gettimeofday() -- use elapser
            nofread, nofskipped, nofduplicates = 0, 0, 0
            suffix = lower(suffix)
            report_names( "identifying %s font files with suffix %s",what,suffix)
            method(suffix)
            suffix = upper(suffix)
            report_names( "identifying %s font files with suffix %s",what,suffix)
            method(suffix)
            totalnofread, totalnofskipped, totalnofduplicates = totalnofread + nofread, totalnofskipped + nofskipped, totalnofduplicates + nofduplicates
            local elapsed = os.gettimeofday() - t
            report_names( "%s %s files identified, %s skipped, %s duplicates, %s hash entries added, runtime %0.3f seconds",nofread,what,nofskipped,nofduplicates,nofread-nofskipped,elapsed)
        end
        logs.flush()
    end
    if not trace_warnings then
        report_names( "warnings are disabled (tracker 'fonts.warnings')")
    end
    traverse("tree", function(suffix) -- TEXTREE only
        resolvers.dowithfilesintree(".*%." .. suffix .. "$", function(method,root,path,name)
            if method == "file" or method == "tree" then
                local completename = root .."/" .. path .. "/" .. name
                completename = resolvers.resolve(completename) -- no shortcut
                identify(completename,name,suffix,name)
                return true
            end
        end, function(blobtype,blobpath,pattern)
            blobpath = resolvers.resolve(blobpath) -- no shortcut
            report_names( "scanning %s for %s files",blobpath,suffix)
        end, function(blobtype,blobpath,pattern,total,checked,done)
            blobpath = resolvers.resolve(blobpath) -- no shortcut
            report_names( "%s entries found, %s %s files checked, %s okay",total,checked,suffix,done)
        end)
    end)
    if texconfig.kpse_init then
        -- we do this only for a stupid names run, not used for context itself,
        -- using the vars is to clumsy so we just stick to a full scan instead
        traverse("lsr", function(suffix) -- all trees
            local pathlist = resolvers.splitpath(resolvers.showpath("ls-R") or "")
            walk_tree(pathlist,suffix,identify)
        end)
    else
        traverse("system", function(suffix) -- OSFONTDIR cum suis
            walk_tree(names.getpaths(trace),suffix,identify)
        end)
    end
    data.statistics.readfiles, data.statistics.skippedfiles, data.statistics.duplicatefiles = totalnofread, totalnofskipped, totalnofduplicates
end

local function addfilenames()
    local data = names.data
    local specifications = data.specifications
    local files =  { }
    for i=1,#specifications do
        local fullname = specifications[i].filename
        files[cleanfilename(fullname)] = fullname
    end
    data.files = files
end

local function rejectclashes() -- just to be sure, so no explicit afm will be found then
    local specifications, used, okay, o = names.data.specifications, { }, { }, 0
    for i=1,#specifications do
        local s = specifications[i]
        local f = s.fontname
        if f then
            local fnd, fnm = used[f], s.filename
            if fnd then
                if trace_warnings then
                    report_names( "fontname '%s' clashes, rejecting '%s' in favor of '%s'",f,fnm,fnd)
                end
            else
                used[f] = fnm
                o = o + 1
                okay[o] = s
            end
        else
            o = o + 1
            okay[o] = s
        end
    end
    local d = #specifications - #okay
    if d > 0 then
        report_names( "%s files rejected due to clashes",d)
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
        datastate = resolvers.datastate(),
    }
end

function names.identify()
    resetdata()
    analyzefiles()
    rejectclashes()
    collectfamilies()
    collectstatistics()
    cleanupkeywords()
    collecthashes()
    checkduplicates()
    addfilenames()
 -- sorthashes() -- will be resorted when saved
end

function names.is_permitted(name)
    return containers.is_usable(names.cache, name)
end
function names.writedata(name,data)
    containers.write(names.cache,name,data)
end
function names.readdata(name)
    return containers.read(names.cache,name)
end

function names.load(reload,verbose)
    if not names.loaded then
        if reload then
            if names.is_permitted(names.basename) then
                names.identify(verbose)
                names.writedata(names.basename,names.data)
            else
                report_names("unable to access database cache")
            end
            names.saved = true
        end
        local data = names.readdata(names.basename)
        names.data = data
        if not names.saved then
            if not data or not next(data) or not data.specifications or not next(data.specifications) then
               names.load(true)
            end
            names.saved = true
        end
        if not data then
            report_names("accessing the data table failed")
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
    names.load() -- todo reload
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
        if autoreload then
            local c_status = serialize(resolvers.datastate())
            local f_status = serialize(data.datastate)
            if c_status == f_status then
                if trace_names then
                    report_names("font database has matching configuration and file hashes")
                end
                return
            else
                report_names("font database has mismatching configuration and file hashes")
            end
        else
            report_names("font database is regenerated (controlled by directive 'fonts.autoreload')")
        end
        names.loaded = false
        reloaded = true
        logs.flush()
        names.load(true)
    end
end

--[[ldx--
<p>The resolver also checks if the cached names are loaded. Being clever
here is for testing purposes only (it deals with names prefixed by an
encoding name).</p>
--ldx]]--

local function fuzzy(mapping,sorted,name,sub)
    local condensed = gsub(name,"[^%a%d]","")
    for k=1,#sorted do
        local v = sorted[k]
        if find(v,condensed) then
            return mapping[v], v
        end
    end
end

-- we could cache a lookup .. maybe some day ... (only when auto loaded!)

local function foundname(name,sub) -- sub is not used currently
    local data = names.data
    local mappings, sorted_mappings = data.mappings, data.sorted_mappings
    local fallbacks, sorted_fallbacks = data.fallbacks, data.sorted_fallbacks
    local list = filters.list
    -- dilemma: we lookup in the order otf ttf ttc ... afm but now an otf fallback
    -- can come after an afm match ... well, one should provide nice names anyway
    -- and having two lists is not an option
    for i=1,#list do
        local l = list[i]
        local found = mappings[l][name]
        if found then
            if trace_names then
                report_names("resolved via direct name match: '%s'",name)
            end
            return found
        end
    end
    for i=1,#list do
        local l = list[i]
        local found, fname = fuzzy(mappings[l],sorted_mappings[l],name,sub)
        if found then
            if trace_names then
                report_names("resolved via fuzzy name match: '%s' => '%s'",name,fname)
            end
            return found
        end
    end
    for i=1,#list do
        local l = list[i]
        local found = fallbacks[l][name]
        if found then
            if trace_names then
                report_names("resolved via direct fallback match: '%s'",name)
            end
            return found
        end
    end
    for i=1,#list do
        local l = list[i]
        local found, fname = fuzzy(sorted_mappings[l],sorted_fallbacks[l],name,sub)
        if found then
            if trace_names then
                report_names("resolved via fuzzy fallback match: '%s' => '%s'",name,fname)
            end
            return found
        end
    end
    if trace_names then
        report_names("font with name '%s' cannot be found",name)
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

-- function names.getfilename(askedname,suffix) -- last resort, strip funny chars
--     names.load()
--     local files = names.data.files
--     askedname = files and files[cleanfilename(askedname,suffix)] or ""
--     if askedname == "" then
--         return ""
--     else -- never entered
--         return resolvers.findbinfile(askedname,suffix) or ""
--     end
-- end

function names.getfilename(askedname,suffix) -- last resort, strip funny chars
    names.load()
    local files = names.data.files
    local cleanname = cleanfilename(askedname,suffix)
    local found = files and files[cleanname] or ""
    if found == "" and is_reloaded() then
        files = names.data.files
        found = files and files[cleanname] or ""
    end
    if found and found ~= "" then
        return resolvers.findbinfile(found,suffix) or "" -- we still need to locate it
    end
end

-- specified search

local function s_collect_weight_style_width_variant(found,done,all,weight,style,width,variant,family)
    if family then
        for i=1,#family do
            local f = family[i]
            if f and weight == f.weight and style == f.style and width == f.width and variant == f.variant then
                found[#found+1], done[f] = f, true
                if not all then return end
            end
        end
    end
end
local function m_collect_weight_style_width_variant(found,done,all,weight,style,width,variant,families,sorted,strictname)
    for i=1,#sorted do
        local k = sorted[i]
        local family = families[k]
        for i=1,#family do
            local f = family[i]
            if not done[f] and weight == f.weight and style == f.style and width == f.width and variant == f.variant and find(f.fontname,strictname) then
                found[#found+1], done[f] = f, true
                if not all then return end
            end
        end
    end
end

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

local function collect(stage,found,done,name,weight,style,width,variant,all)
    local data = names.data
    local families, sorted = data.families, data.sorted_families
    strictname = "^".. name -- to be checked
    local family = families[name]
    if trace_names then
        report_names("resolving name '%s', weight '%s', style '%s', width '%s', variant '%s'",
            name or "?",tostring(weight),tostring(style),tostring(width),tostring(variant))
    end
    --~ print(name,serialize(family))
    if weight and weight ~= "" then
        if style and style ~= "" then
            if width and width ~= "" then
                if variant and variant ~= "" then
                    if trace_names then
                        report_names("resolving stage %s, name '%s', weight '%s', style '%s', width '%s', variant '%s'",stage,name,weight,style,width,variant)
                    end
                    s_collect_weight_style_width_variant(found,done,all,weight,style,width,variant,family)
                    m_collect_weight_style_width_variant(found,done,all,weight,style,width,variant,families,sorted,strictname)
                else
                    if trace_names then
                        report_names("resolving stage %s, name '%s', weight '%s', style '%s', width '%s'",stage,name,weight,style,width)
                    end
                    s_collect_weight_style_width(found,done,all,weight,style,width,family)
                    m_collect_weight_style_width(found,done,all,weight,style,width,families,sorted,strictname)
                end
            else
                if trace_names then
                    report_names("resolving stage %s, name '%s', weight '%s', style '%s'",stage,name,weight,style)
                end
                s_collect_weight_style(found,done,all,weight,style,family)
                m_collect_weight_style(found,done,all,weight,style,families,sorted,strictname)
            end
        else
            if trace_names then
                report_names("resolving stage %s, name '%s', weight '%s'",stage,name,weight)
            end
            s_collect_weight(found,done,all,weight,family)
            m_collect_weight(found,done,all,weight,families,sorted,strictname)
        end
    elseif style and style ~= "" then
        if width and width ~= "" then
            if trace_names then
                report_names("resolving stage %s, name '%s', style '%s', width '%s'",stage,name,style,width)
            end
            s_collect_style_width(found,done,all,style,width,family)
            m_collect_style_width(found,done,all,style,width,families,sorted,strictname)
        else
            if trace_names then
                report_names("resolving stage %s, name '%s', style '%s'",stage,name,style)
            end
            s_collect_style(found,done,all,style,family)
            m_collect_style(found,done,all,style,families,sorted,strictname)
        end
    elseif width and width ~= "" then
        if trace_names then
            report_names("resolving stage %s, name '%s', width '%s'",stage,name,width)
        end
        s_collect_width(found,done,all,width,family)
        m_collect_width(found,done,all,width,families,sorted,strictname)
    else
        if trace_names then
            report_names("resolving stage %s, name '%s'",stage,name)
        end
        s_collect(found,done,all,family)
        m_collect(found,done,all,families,sorted,strictname)
    end
end

local function heuristic(name,weight,style,width,variant,all) -- todo: fallbacks
    local found, done = { }, { }
--~ print(name,weight,style,width,variant)
    weight, style, width, variant = weight or "normal", style or "normal", width or "normal", variant or "normal"
    name = cleanname(name)
    collect(1,found,done,name,weight,style,width,variant,all)
    -- still needed ?
    if #found == 0 and variant ~= "normal" then -- not weight
        variant = "normal"
        collect(4,found,done,name,weight,style,width,variant,all)
    end
    if #found == 0 and width ~= "normal" then
        width = "normal"
        collect(2,found,done,name,weight,style,width,variant,all)
    end
    if #found == 0 and weight ~= "normal" then -- not style
        weight = "normal"
        collect(3,found,done,name,weight,style,width,variant,all)
    end
    if #found == 0 and style ~= "normal" then -- not weight
        style = "normal"
        collect(4,found,done,name,weight,style,width,variant,all)
    end
    --
    local nf = #found
    if trace_names then
        if nf then
            local t = { }
            for i=1,nf do
                t[i] = format("'%s'",found[i].fontname)
            end
            report_names("name '%s' resolved to %s instances: %s",name,nf,concat(t," "))
        else
            report_names("name '%s' unresolved",name)
        end
    end
    if all then
        return nf > 0 and found
    else
        return found[1]
    end
end

function names.specification(askedname,weight,style,width,variant,reload,all)
    if askedname and askedname ~= "" and names.enabled then
        askedname = cleanname(askedname) -- or cleanname
        names.load(reload)
        local found = heuristic(askedname,weight,style,width,variant,all)
        if not found and is_reloaded() then
            found = heuristic(askedname,weight,style,width,variant,all)
            if not filename then
                found = foundname(askedname) -- old method
            end
        end
        return found
    end
end

function names.collect(askedname,weight,style,width,variant,reload,all)
    if askedname and askedname ~= "" and names.enabled then
        askedname = cleanname(askedname) -- or cleanname
        names.load(reload)
        local list = heuristic(askedname,weight,style,width,variant,true)
        if not list or #list == 0 and is_reloaded() then
            list = heuristic(askedname,weight,style,width,variant,true)
        end
        return list
    end
end

function names.collectspec(askedname,reload,all)
    local name, weight, style, width, variant = names.splitspec(askedname)
    return names.collect(name,weight,style,width,variant,reload,all)
end

function names.resolvespec(askedname,sub) -- redefined later
    local found = names.specification(names.splitspec(askedname))
    if found then
        return found.filename, found.subfont and found.rawname
    end
end

function names.collectfiles(askedname,reload) -- no all
    if askedname and askedname ~= "" and names.enabled then
        askedname = cleanname(askedname) -- or cleanname
        names.load(reload)
        local list = { }
        local basename = file.basename
        local specifications = names.data.specifications
        for i=1,#specifications do
            local s = specifications[i]
            if find(cleanname(basename(s.filename)),askedname) then
                list[#list+1] = s
            end
        end
        return list
    end
end

--~ --[[ldx--
--~ <p>Fallbacks, not permanent but a transition thing.</p>
--~ --ldx]]--
--~
--~ names.new_to_old = allocate {
--~     ["lmroman10-capsregular"]                = "lmromancaps10-oblique",
--~     ["lmroman10-capsoblique"]                = "lmromancaps10-regular",
--~     ["lmroman10-demi"]                       = "lmromandemi10-oblique",
--~     ["lmroman10-demioblique"]                = "lmromandemi10-regular",
--~     ["lmroman8-oblique"]                     = "lmromanslant8-regular",
--~     ["lmroman9-oblique"]                     = "lmromanslant9-regular",
--~     ["lmroman10-oblique"]                    = "lmromanslant10-regular",
--~     ["lmroman12-oblique"]                    = "lmromanslant12-regular",
--~     ["lmroman17-oblique"]                    = "lmromanslant17-regular",
--~     ["lmroman10-boldoblique"]                = "lmromanslant10-bold",
--~     ["lmroman10-dunhill"]                    = "lmromandunh10-oblique",
--~     ["lmroman10-dunhilloblique"]             = "lmromandunh10-regular",
--~     ["lmroman10-unslanted"]                  = "lmromanunsl10-regular",
--~     ["lmsans10-demicondensed"]               = "lmsansdemicond10-regular",
--~     ["lmsans10-demicondensedoblique"]        = "lmsansdemicond10-oblique",
--~     ["lmsansquotation8-bold"]                = "lmsansquot8-bold",
--~     ["lmsansquotation8-boldoblique"]         = "lmsansquot8-boldoblique",
--~     ["lmsansquotation8-oblique"]             = "lmsansquot8-oblique",
--~     ["lmsansquotation8-regular"]             = "lmsansquot8-regular",
--~     ["lmtypewriter8-regular"]                = "lmmono8-regular",
--~     ["lmtypewriter9-regular"]                = "lmmono9-regular",
--~     ["lmtypewriter10-regular"]               = "lmmono10-regular",
--~     ["lmtypewriter12-regular"]               = "lmmono12-regular",
--~     ["lmtypewriter10-italic"]                = "lmmono10-italic",
--~     ["lmtypewriter10-oblique"]               = "lmmonoslant10-regular",
--~     ["lmtypewriter10-capsoblique"]           = "lmmonocaps10-oblique",
--~     ["lmtypewriter10-capsregular"]           = "lmmonocaps10-regular",
--~     ["lmtypewriter10-light"]                 = "lmmonolt10-regular",
--~     ["lmtypewriter10-lightoblique"]          = "lmmonolt10-oblique",
--~     ["lmtypewriter10-lightcondensed"]        = "lmmonoltcond10-regular",
--~     ["lmtypewriter10-lightcondensedoblique"] = "lmmonoltcond10-oblique",
--~     ["lmtypewriter10-dark"]                  = "lmmonolt10-bold",
--~     ["lmtypewriter10-darkoblique"]           = "lmmonolt10-boldoblique",
--~     ["lmtypewritervarwd10-regular"]          = "lmmonoproplt10-regular",
--~     ["lmtypewritervarwd10-oblique"]          = "lmmonoproplt10-oblique",
--~     ["lmtypewritervarwd10-light"]            = "lmmonoprop10-regular",
--~     ["lmtypewritervarwd10-lightoblique"]     = "lmmonoprop10-oblique",
--~     ["lmtypewritervarwd10-dark"]             = "lmmonoproplt10-bold",
--~     ["lmtypewritervarwd10-darkoblique"]      = "lmmonoproplt10-boldoblique",
--~ }
--~
--~ names.old_to_new = allocate(table.swapped(names.new_to_old))

--~ todo:
--~
--~ blacklisted = {
--~     ["cmr10.ttf"] = "completely messed up",
--~ }

function names.exists(name)
    local found = false
    local list = filters.list
    for k=1,#list do
        local v = list[k]
        found = (resolvers.findfile(name,v) or "") ~= ""
        if found then
            return found
        end
    end
    return ((resolvers.findfile(name,"tfm") or "") ~= "") or ((names.resolve(name) or "") ~= "")
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
            report_names("starting with %s lookups for '%s'",#lookups,pattern)
        end
        if lookups then
            for key, value in gmatch(pattern,"([^=,]+)=([^=,]+)") do
                local t, n = { }, 0
                if find(value,"*") then
                    value = string.topattern(value)
                    for i=1,#lookups do
                        local s = lookups[i]
                        if find(s[key],value) then
                            n = n + 1
                            t[n] = lookups[i]
                        end
                    end
                else
                    for i=1,#lookups do
                        local s = lookups[i]
                        if s[key] == value then
                            n = n + 1
                            t[n] = lookups[i]
                        end
                    end
                end
                if trace_names then
                    report_names("%s matches for key '%s' with value '%s'",#t,key,value)
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

-- The following is new ... watch the overload!

local specifications = allocate()
names.specifications = specifications

-- files = {
--     name = "antykwapoltawskiego",
--     list = {
--         ["AntPoltLtCond-Regular.otf"] = {
--          -- name   = "antykwapoltawskiego",
--             style  = "regular",
--             weight = "light",
--             width  = "condensed",
--         },
--     },
-- }

function names.register(files)
    if files then
        local list, commonname = files.list, files.name
        if list then
            local n, m = 0, 0
            for filename, filespec in next, list do
                local name = lower(filespec.name or commonname)
                if name and name ~= "" then
                    local style    = normalized_styles  [lower(filespec.style   or "normal")]
                    local width    = normalized_widths  [lower(filespec.width   or "normal")]
                    local weight   = normalized_weights [lower(filespec.weight  or "normal")]
                    local variant  = normalized_variants[lower(filespec.variant or "normal")]
                    local weights  = specifications[name  ] if not weights  then weights  = { } specifications[name  ] = weights  end
                    local styles   = weights       [weight] if not styles   then styles   = { } weights       [weight] = styles   end
                    local widths   = styles        [style ] if not widths   then widths   = { } styles        [style ] = widths   end
                    local variants = widths        [width ] if not variants then variants = { } widths        [width ] = variants end
                    variants[variant] = filename
                    n = n + 1
                else
                    m = m + 1
                end
            end
            if trace_specifications then
                report_names("%s filenames registered, %s filenames rejected",n,m)
            end
        end
    end
end

function names.registered(name,weight,style,width,variant)
    local ok = specifications[name]
    ok = ok and (ok[(weight  and weight  ~= "" and weight ) or "normal"] or ok.normal)
    ok = ok and (ok[(style   and style   ~= "" and style  ) or "normal"] or ok.normal)
    ok = ok and (ok[(width   and width   ~= "" and width  ) or "normal"] or ok.normal)
    ok = ok and (ok[(variant and variant ~= "" and variant) or "normal"] or ok.normal)
    --
    -- todo: same fallbacks as with database
    --
    if ok then
        return {
            filename = ok,
            subname  = "",
         -- rawname  = nil,
        }
    end
end

function names.resolvespec(askedname,sub) -- overloads previous definition
    local name, weight, style, width, variant = names.splitspec(askedname)
    if trace_specifications then
        report_names("resolving specification: %s -> name=%s, weight=%s, style=%s, width=%s, variant=%s",askedname,name,weight,style,width,variant)
    end
    local found = names.registered(name,weight,style,width,variant)
    if found and found.filename then
        if trace_specifications then
            report_names("resolved by registered names: %s -> %s",askedname,found.filename)
        end
        return found.filename, found.subname, found.rawname
    else
        found = names.specification(name,weight,style,width,variant)
        if found and found.filename then
            if trace_specifications then
                report_names("resolved by font database: %s -> %s",askedname,found.filename)
            end
            return found.filename, found.subfont and found.rawname
        end
    end
    if trace_specifications then
        report_names("unresolved: %s",askedname)
    end
end

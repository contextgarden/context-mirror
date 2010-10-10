if not modules then modules = { } end modules ['grph-inc'] = {
    version   = 1.001,
    comment   = "companion to grph-inc.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- figures -> managers.figures

-- lowercase types
-- mps tex tmp svg
-- partly qualified
-- dimensions
-- consult rlx

-- figures.boxnumber can go as we now can use names

--[[
The ConTeXt figure inclusion mechanisms are among the oldest code
in ConTeXt and evolve dinto a complex whole. One reason is that we
deal with backend in an abstract way. What complicates matters is
that we deal with internal graphics as well: TeX code, MetaPost code,
etc. Later on figure databases were introduced, which resulted in
a plug in model for locating images. On top of that runs a conversion
mechanism (with caching) and resource logging.

Porting that to Lua is not that trivial because quite some
status information is kept between al these stages. Of course, image
reuse also has some price, and so I decided to implement the graphics
inclusion in several layers: detection, loading, inclusion, etc.

Object sharing and scaling can happen at each stage, depending on the
way the resource is dealt with.

The TeX-Lua mix is suboptimal. This has to do with the fact that we cannot
run TeX code from within Lua. Some more functionality will move to Lua.
]]--

-- commands.writestatus -> report

local format, lower, find, match, gsub, gmatch = string.format, string.lower, string.find, string.match, string.gsub, string.gmatch
local texsprint, texbox = tex.sprint, tex.box
local contains = table.contains
local concat = table.concat
local todimen = string.todimen
local settings_to_array = utilities.parsers.settings_to_array
local allocate = utilities.storage.allocate

local ctxcatcodes    = tex.ctxcatcodes
local variables      = interfaces.variables
local codeinjections = backends.codeinjections
local nodeinjections = backends.nodeinjections

local trace_figures    = false  trackers.register("figures.locating",   function(v) trace_figures    = v end)
local trace_bases      = false  trackers.register("figures.bases",      function(v) trace_bases      = v end)
local trace_programs   = false  trackers.register("figures.programs",   function(v) trace_programs   = v end)
local trace_conversion = false  trackers.register("figures.conversion", function(v) trace_conversion = v end)
local trace_inclusion  = false  trackers.register("figures.inclusion",  function(v) trace_inclusion  = v end)

local report_graphics = logs.new("graphics")

--- some extra img functions ---

local img = img

local imgkeys = img.keys()

function img.totable(imgtable)
    local result = { }
    for k=1,#imgkeys do
        local key = imgkeys[k]
        result[key] = imgtable[key]
    end
    return result
end

function img.serialize(i)
    return table.serialize(img.totable(i))
end

function img.clone(i,data)
    i.width  = data.width  or i.width
    i.height = data.height or i.height
    -- attr etc
    return i
end

local validsizes = table.tohash(img.boxes())
local validtypes = table.tohash(img.types())

function img.checksize(size)
    if size then
        size = gsub(size,"box","")
        return (validsizes[size] and size) or "crop"
    else
        return "crop"
    end
end

local indexed = { }

function img.ofindex(n)
    return indexed[n]
end

--- we can consider an grph-ini file

figures                = figures or { }
local figures          = figures

figures.loaded         = allocate()
figures.used           = allocate()
figures.found          = allocate()
figures.suffixes       = allocate()
figures.patterns       = allocate()

figures.boxnumber      = figures.boxnumber or 0
figures.defaultsearch  = true
figures.defaultwidth   = 0
figures.defaultheight  = 0
figures.defaultdepth   = 0
figures.nofprocessed   = 0
figures.preferquality  = true -- quality over location

figures.existers    = allocate()   local existers    = figures.existers
figures.checkers    = allocate()   local checkers    = figures.checkers
figures.includers   = allocate()   local includers   = figures.includers
figures.converters  = allocate()   local converters  = figures.converters
figures.identifiers = allocate()   local identifiers = figures.identifiers
figures.programs    = allocate()   local programs    = figures.programs

figures.localpaths = allocate {
    ".", "..", "../.."
}
figures.cachepaths = allocate {
    prefix = "",
    path = ".",
    subpath = ".",
}

figures.paths  = allocate(table.copy(figures.localpaths))

figures.order =  allocate{
    "pdf", "mps", "jpg", "png", "jbig", "svg", "eps", "gif", "mov", "buffer", "tex",
}

figures.formats = allocate{
    ["pdf"]    = { list = { "pdf" } },
    ["mps"]    = { patterns = { "mps", "%d+" } },
    ["jpg"]    = { list = { "jpg", "jpeg" } },
    ["png"]    = { list = { "png" } },
    ["jbig"]   = { list = { "jbig", "jbig2", "jb2" } },
    ["svg"]    = { list = { "svg", "svgz" } },
    ["eps"]    = { list = { "eps", "ai" } },
    ["gif"]    = { list = { "gif" } },
    ["mov"]    = { list = { "mov", "flv", "mp4" } }, -- "avi" is not supported
    ["buffer"] = { list = { "tmp", "buffer", "buf" } },
    ["tex"]    = { list = { "tex" } },
}

function figures.setlookups()
    local fs, fp = allocate(), allocate()
    figures.suffixes, figures.patterns = fs, fp
    for _, format in next, figures.order do
        local data = figures.formats[format]
        local list = data.list
        if list then
            for i=1,#list do
                fs[list[i]] = format -- hash
            end
        else
            fs[format] = format
        end
        local patterns = data.patterns
        if patterns then
            for i=1,#patterns do
                fp[#fp+1] = { patterns[i], format } -- array
            end
        end
    end
end

figures.setlookups()

local function register(tag,target,what)
    local data = figures.formats[target] -- resolver etc
    if not data then
        data = { }
        figures.formats[target] = data
    end
    local d = data[tag] -- list or pattern
    if d and not contains(d,what) then
        d[#d+1] = what -- suffix or patternspec
    else
        data[tag] = { what }
    end
    if not contains(figures.order,target) then
        figures.order[#figures.order+1] = target
    end
    figures.setlookups()
end

function figures.registersuffix (suffix, target) register('list',   target,suffix ) end
function figures.registerpattern(pattern,target) register('pattern',target,pattern) end

local last_locationset, last_pathlist = last_locationset or nil, last_pathlist or nil

function figures.setpaths(locationset,pathlist)
    if last_locationset == locationset and last_pathlist == pathlist then
        -- this function can be called each graphic so we provide this optimization
        return
    end
    local iv, t, h = interfaces.variables, figures.paths, locationset:tohash()
    if last_locationset ~= locationset then
        -- change == reset (actually, a 'reset' would indeed reset
        if h[iv["local"]] then
            t = table.fastcopy(figures.localpaths or { })
        else
            t = { }
        end
        figures.defaultsearch = h[iv["default"]]
        last_locationset = locationset
    end
    if h[iv["global"]] then
     -- for s in gmatch(pathlist,",* *([^,]+)") do
        local list = settings_to_array(pathlist)
        for i=1,#list do
            local s = list[i]
            if not contains(t,s) then
                t[#t+1] = s
            end
        end
    end
    figures.paths, last_pathlist = t, pathlist
    if trace_figures then
        commands.writestatus("figures","locations: %s",last_locationset)
        commands.writestatus("figures","path list: %s",concat(figures.paths, " "))
    end
end

-- check conversions and handle it here

function figures.hash(data)
    return data.status.hash or tostring(data.status.private) -- the <img object>
--  return data.status.fullname .. "+".. (data.status.page or data.request.page or 1) -- img is still not perfect
end

-- interfacing to tex


local figuredata = { }
local callstack  = { }

function figures.new() -- we could use metatables status -> used -> request but it needs testing
    local request = {
        name       = false,
        label      = false,
        format     = false,
        page       = false,
        width      = false,
        height     = false,
        preview    = false,
        ["repeat"] = false,
        controls   = false,
        display    = false,
        conversion = false,
        resolution = false,
        cache      = false,
        prefix     = false,
        size       = false,
    }
    local used = {
        fullname   = false,
        format     = false,
        name       = false,
        path       = false,
        suffix     = false,
        width      = false,
        height     = false,
    }
    local status = {
        status     = 0,
        converted  = false,
        cached     = false,
        fullname   = false,
        format     = false,
    }
 -- setmetatable(status, { __index = used })
 -- setmetatable(used,   { __index = request })
    figuredata = {
        request = request,
        used    = used,
        status  = status,
    }
    return figuredata
end

function figures.push(request)
    local ncs = #callstack + 1
    if ncs == 1 then
        statistics.starttiming(figures)
    end
    local figuredata = figures.new()
    if request then
    local iv = interfaces.variables
    --  request.width/height are strings and are only used when no natural dimensions
    --  can be determined; at some point the handlers might set them to numbers instead
    --  local w, h = tonumber(request.width), tonumber(request.height)
        request.page       = math.max(tonumber(request.page) or 1,1)
        request.size       = img.checksize(request.size)
        request.object     = iv[request.object] == variables.yes
        request["repeat"]  = iv[request["repeat"]] == variables.yes
        request.preview    = iv[request.preview] == variables.yes
        request.cache      = request.cache ~= "" and request.cache
        request.prefix     = request.prefix ~= "" and request.prefix
        request.format     = request.format ~= "" and request.format
    --  request.width      = (w and w > 0) or false
    --  request.height     = (h and h > 0) or false
        table.merge(figuredata.request,request)
    end
    callstack[ncs] = figuredata
    return figuredata
end

function figures.pop()
    local ncs = #callstack
    figuredata = callstack[ncs]
    callstack[ncs] = nil
    if ncs == 1 then
        statistics.stoptiming(figures)
    end
end

-- maybe move texsprint to tex

function figures.get(category,tag,default)
    local value = figuredata[category]
    value = value and value[tag]
    if not value or value == "" or value == true then
        return default or ""
    else
        return value
    end
end

function figures.tprint(category,tag,default)
    texsprint(ctxcatcodes,figures.get(category,tag,default))
end

function figures.current()
    return callstack[#callstack]
end

local defaultformat = "pdf"
local defaultprefix = "m_k_i_v_"

local function register(askedname,specification)
    if specification then
        local format = specification.format
        if format then
            local conversion = specification.conversion
            local resolution = specification.resolution
            if conversion == "" then
                conversion = nil
            end
            if resolution == "" then
                resolution = nil
            end
            local newformat = conversion
            if not newformat or newformat == "" then
                newformat = defaultformat
            end
            if trace_conversion then
                report_graphics("checking conversion of '%s': old format '%s', new format '%s', conversion '%s', resolution '%s'",
                    askedname,format,newformat,conversion or "default",resolution or "default")
            end
            local converter = (newformat ~= format) and converters[format]
            if converter then
                if converter[newformat] then
                    converter = converter[newformat]
                else
                    newformat = defaultformat
                    if converter[newformat] then
                        converter = converter[newformat]
                    else
                        newformat = defaultformat
                    end
                end
            elseif trace_conversion then
                report_graphics("no converter for '%s' -> '%s'",format,newformat)
            end
            if converter then
                local oldname = specification.fullname
                local newpath = file.dirname(oldname)
                local oldbase = file.basename(oldname)
                local newbase = file.removesuffix(oldbase)
                local fc = specification.cache or figures.cachepaths.path
                if fc and fc ~= "" and fc ~= "." then
                    newpath = fc
                else
                    newbase = defaultprefix .. newbase
                end
                local subpath = specification.subpath or figures.cachepaths.subpath
                if subpath and subpath ~= "" and subpath ~= "."  then
                    newpath = newpath .. "/" .. subpath
                end
                local prefix = specification.prefix or figures.cachepaths.prefix
                if prefix and prefix ~= "" then
                    newbase = prefix .. newbase
                end
                if resolution and resolution ~= "" then -- the order might change
                    newbase = newbase .. "_" .. resolution
                end
                local newbase = file.addsuffix(newbase,newformat)
                local newname = file.join(newpath,newbase)
                dir.makedirs(newpath)
                oldname = file.collapse_path(oldname)
                newname = file.collapse_path(newname)
                local oldtime = lfs.attributes(oldname,'modification') or 0
                local newtime = lfs.attributes(newname,'modification') or 0
                if newtime == 0 or oldtime > newtime then
                    if trace_conversion then
                        report_graphics("converting '%s' from '%s' to '%s'",askedname,format,newformat)
                    end
                    converter(oldname,newname,resolution or "")
                else
                    if trace_conversion then
                        report_graphics("no need to convert '%s' from '%s' to '%s'",askedname,format,newformat)
                    end
                end
                if io.exists(newname) then
                    specification.foundname = oldname
                    specification.fullname  = newname
                    specification.prefix    = prefix
                    specification.subpath   = subpath
                    specification.converted = true
                    format = newformat
                elseif io.exists(oldname) then
                    specification.fullname  = newname
                    specification.converted = false
                end
            end
        end
        local found = figures.suffixes[format] -- validtypes[format]
        if not found then
            specification.found = false
            if trace_figures then
                commands.writestatus("figures","format not supported: %s",format)
            end
        else
            specification.found = true
            if trace_figures then
                if validtypes[format] then
                    commands.writestatus("figures","format natively supported by backend: %s",format)
                else
                    commands.writestatus("figures","format supported by output file format: %s",format)
                end
            end
        end
    else
        specification = { }
    end
    specification.foundname = specification.foundname or specification.fullname
    figures.found[askedname .. "->" .. (specification.conversion or "default") .. "->" .. (specification.resolution or "default")] = specification
    return specification
end

local resolve_too = true -- urls

local function locate(request) -- name, format, cache
    local askedname = resolvers.cleanpath(request.name)
    local foundname = figures.found[askedname .. "->" .. (request.conversion or "default") .. "->" .. (request.resolution or "default")]
    if foundname then
        return foundname
    end
    -- protocol check
    local hashed = url.hashed(askedname)
    if hashed then
        if hashed.scheme == "file" then
            local path = hashed.path
            if path and path ~= "" then
                askedname = path
            end
        else
            local foundname = resolvers.findbinfile(askedname)
            if foundname then
                askedname = foundname
            end
        end
    end
    -- we could use the hashed data instead
    local askedpath= file.is_rootbased_path(askedname)
    local askedbase = file.basename(askedname)
    local askedformat = (request.format ~= "" and request.format ~= "unknown" and request.format) or file.extname(askedname) or ""
    local askedcache = request.cache
    local askedconversion = request.conversion
    local askedresolution = request.resolution
    if askedformat ~= "" then
        if trace_figures then
            commands.writestatus("figures","strategy: forced format")
        end
        askedformat = lower(askedformat)
        local format = figures.suffixes[askedformat]
        if not format then
            local figurepatterns = figures.patterns
            for i=1,#figurepatterns do
                local pattern = figurepatterns[i]
                if find(askedformat,pattern[1]) then
                    format = pattern[2]
                    break
                end
            end
        end
        if format then
            local foundname = figures.exists(askedname,format,resolve_too) -- not askedformat
            if foundname then
                return register(askedname, {
                    askedname  = askedname,
                    fullname   = askedname,
                    format     = format,
                    cache      = askedcache,
                    foundname  = foundname,
                    conversion = askedconversion,
                    resolution = askedresolution,
                })
            end
        end
        if askedpath then
            -- path and type given, todo: strip pieces of path
            if figures.exists(askedname,askedformat,resolve_too) then
                return register(askedname, {
                    askedname  = askedname,
                    fullname   = askedname,
                    format     = askedformat,
                    cache      = askedcache,
                    conversion = askedconversion,
                    resolution = askedresolution,
                })
            end
        else
            -- type given
            local figurepaths = figures.paths
            for i=1,#figurepaths do
                local path = figurepaths[i]
                local check = path .. "/" .. askedname
             -- we pass 'true' as it can be an url as well, as the type
             -- is given we don't waste much time
                if figures.exists(check,askedformat,resolve_too) then
                    return register(check, {
                        askedname  = askedname,
                        fullname   = check,
                        format     = askedformat,
                        cache      = askedcache,
                        conversion = askedconversion,
                        resolution = askedresolution,
                    })
                end
            end
            if figures.defaultsearch then
                local check = resolvers.findfile(askedname)
                if check and check ~= "" then
                    return register(askedname, {
                        askedname  = askedname,
                        fullname   = check,
                        format     = askedformat,
                        cache      = askedcache,
                        conversion = askedconversion,
                        resolution = askedresolution,
                    })
                end
            end
        end
    elseif askedpath then
        if trace_figures then
            commands.writestatus("figures","strategy: rootbased path")
        end
        local figureorder = figures.order
        for i=1,#figureorder do
            local format = figureorder[i]
            local list = figures.formats[format].list or { format }
            for j=1,#list do
                local suffix = list[j]
                local check = file.addsuffix(askedname,suffix)
                if figures.exists(check,format,resolve_too) then
                    return register(askedname, {
                        askedname  = askedname,
                        fullname   = check,
                        format     = format,
                        cache      = askedcache,
                        conversion = askedconversion,
                        resolution = askedresolution,
                    })
                end
            end
        end
    else
        if figures.preferquality then
            if trace_figures then
                commands.writestatus("figures","strategy: unknown format, prefer quality")
            end
            local figurepaths = figures.paths
            local figureorder = figures.order
            for j=1,#figureorder do
                local format = figureorder[j]
                local list = figures.formats[format].list or { format }
                for k=1,#list do
                    local suffix = list[k]
                 -- local name = file.replacesuffix(askedbase,suffix)
                    local name = file.replacesuffix(askedname,suffix)
                    for i=1,#figurepaths do
                        local path = figurepaths[i]
                        local check = path .. "/" .. name
                        local isfile = url.hashed(check).scheme == "file"
                        if not isfile then
                            if trace_figures then
                                commands.writestatus("figures","warning: skipping path %s",path)
                            end
                        elseif figures.exists(check,format,true) then
                            return register(askedname, {
                                askedname  = askedname,
                                fullname   = check,
                                format     = format,
                                cache      = askedcache,
                                conversion = askedconversion,
                                resolution = askedresolution,
                            })
                        end
                    end
                end
            end
        else -- 'location'
            if trace_figures then
                commands.writestatus("figures","strategy: unknown format, prefer path")
            end
            local figurepaths = figures.paths
            local figureorder = figures.order
            for i=1,#figurepaths do
                local path = figurepaths[i]
                for j=1,#figureorder do
                    local format = figureorder[j]
                    local list = figures.formats[format].list or { format }
                    for k=1,#list do
                        local suffix = list[k]
                        local check = path .. "/" .. file.replacesuffix(askedbase,suffix)
                        if figures.exists(check,format,resolve_too) then
                            return register(askedname, {
                                askedname  = askedname,
                                fullname   = check,
                                format     = format,
                                cache      = askedcache,
                                conversion = askedconversion,
                                resolution = askedresolution,
                            })
                        end
                    end
                end
            end
        end
        if figures.defaultsearch then
            if trace_figures then
                commands.writestatus("figures","strategy: default tex path")
            end
            local figureorder = figures.order
            for j=1,#figureorder do
                local format = figureorder[j]
                local list = figures.formats[format].list or { format }
                for k=1,#list do
                    local suffix = list[k]
                    local check = resolvers.findfile(file.replacesuffix(askedname,suffix))
                    if check and check ~= "" then
                        return register(askedname, {
                            askedname  = askedname,
                            fullname   = check,
                            format     = format,
                            cache      = askedcache,
                            conversion = askedconversion,
                            resolution = askedresolution,
                        })
                    end
                end
            end
        end
    end
    return register(askedname)
end

-- -- -- plugins -- -- --

function identifiers.default(data)
    local dr, du, ds = data.request, data.used, data.status
    local l = locate(dr)
    local foundname = l.foundname
    local fullname  = l.fullname or foundname
    if fullname then
        du.format   = l.format or false
        du.fullname = fullname -- can be cached
        ds.fullname = foundname -- original
        ds.format   = l.format
        ds.status   = (l.found and 10) or 0
    end
    return data
end

function figures.identify(data)
    data = data or figures.current()
    local list = identifiers.list -- defined at the end
    for i=1,#list do
        local identifier = list[i]
        data = identifier(data)
        if data.status.status > 0 then
            break
        end
    end
    return data
end
function figures.exists(askedname,format,resolve)
    return (existers[format] or existers.generic)(askedname,resolve)
end
function figures.check(data)
    data = data or figures.current()
    local dr, du, ds = data.request, data.used, data.status
    return (checkers[ds.format] or checkers.generic)(data)
end
function figures.include(data)
    data = data or figures.current()
    local dr, du, ds = data.request, data.used, data.status
    return (includers[ds.format] or includers.generic)(data)
end
function figures.scale(data) -- will become lua code
    texsprint(ctxcatcodes,"\\doscalefigure")
    return data
end
function figures.done(data)
    figures.nofprocessed = figures.nofprocessed + 1
    data = data or figures.current()
--~ print(table.serialize(figures.current()))
    local dr, du, ds, nr = data.request, data.used, data.status, figures.boxnumber
    local box = texbox[nr]
    ds.width  = box.width
    ds.height = box.height
    ds.xscale = ds.width /(du.width  or 1)
    ds.yscale = ds.height/(du.height or 1)
    ds.page   = ds.page or du.page or dr.page -- sort of redundant but can be limited
--~ print(table.serialize(figures.current()))
    return data
end

function figures.dummy(data)
    data = data or figures.current()
    local dr, du, ds, nr = data.request, data.used, data.status, figures.boxnumber
    local box = node.hpack(node.new("hlist")) -- we need to set the dir (luatex 0.60 buglet)
    du.width  = du.width  or figures.defaultwidth
    du.height = du.height or figures.defaultheight
    du.depth  = du.depth  or figures.defaultdepth
 -- box.dir = "TLT"
    box.width  = du.width
    box.height = du.height
    box.depth  = du.depth
    texbox[nr] = box -- hm, should be global (to be checked for consistency)
end

-- -- -- generic -- -- --

function existers.generic(askedname,resolve)
    -- not findbinfile
    local result
    if lfs.isfile(askedname) then
        result = askedname
    elseif resolve then
        result = resolvers.findbinfile(askedname) or ""
        if result == "" then result = false end
    end
    if trace_figures then
        if result then
            commands.writestatus("figures","found: %s -> %s",askedname,result)
        else
            commands.writestatus("figures","not found: %s",askedname)
        end
    end
    return result
end
function checkers.generic(data)
    local dr, du, ds = data.request, data.used, data.status
    local name, page, size, color = du.fullname or "unknown generic", du.page or dr.page, dr.size or "crop", dr.color or "natural"
    local conversion = dr.conversion
    local resolution = dr.resolution
    if not conversion or conversion == "" then
        conversion = "unknown"
    end
    if not resolution or resolution == "" then
        resolution = "unknown"
    end
    local hash = name .. "->" .. page .. "->" .. size .. "->" .. color .. "->" .. conversion .. "->" .. resolution
    local figure = figures.loaded[hash]
    if figure == nil then
        figure = img.new { filename = name, page = page, pagebox = dr.size }
        codeinjections.setfigurecolorspace(data,figure)
        figure = (figure and img.scan(figure)) or false
        local f, d = codeinjections.setfigurealternative(data,figure)
        figure, data = f or figure, d or data
        figures.loaded[hash] = figure
        if trace_conversion then
            report_graphics("new graphic, hash: %s",hash)
        end
    else
        if trace_conversion then
            report_graphics("existing graphic, hash: %s",hash)
        end
    end
    if figure then
        du.width = figure.width
        du.height = figure.height
        du.pages = figure.pages
        ds.private = figure
        ds.hash = hash
    end
    return data
end
function includers.generic(data)
    local dr, du, ds = data.request, data.used, data.status
    -- here we set the 'natural dimensions'
    dr.width = du.width
    dr.height = du.height
    local hash = figures.hash(data)
    local figure = figures.used[hash]
    if figure == nil then
        figure = ds.private
        if figure then
            figure = img.copy(figure)
            figure = (figure and img.clone(figure,data.request)) or false
        end
        figures.used[hash] = figure
    end
    if figure then
        local nr = figures.boxnumber
        -- it looks like we have a leak in attributes here .. todo
        local box = node.hpack(img.node(figure)) -- img.node(figure) not longer valid
        indexed[figure.index] = figure
        box.width, box.height, box.depth = figure.width, figure.height, 0 -- new, hm, tricky, we need to do that in tex (yet)
        texbox[nr] = box
        ds.objectnumber = figure.objnum
        texsprint(ctxcatcodes,"\\relocateexternalfigure")
    end
    return data
end

-- -- -- nongeneric -- -- --

function checkers.nongeneric(data,command)
    local dr, du, ds = data.request, data.used, data.status
    local name = du.fullname or "unknown nongeneric"
    local hash = name
    if dr.object then
        -- hm, bugged
        if not job.objects.get("FIG::"..hash) then
            texsprint(ctxcatcodes,command)
            texsprint(ctxcatcodes,format("\\setobject{FIG}{%s}\\vbox{\\box\\foundexternalfigure}",hash))
        end
        texsprint(ctxcatcodes,format("\\global\\setbox\\foundexternalfigure\\vbox{\\getobject{FIG}{%s}}",hash))
    else
        texsprint(ctxcatcodes,command)
    end
    return data
end
function includers.nongeneric(data)
    return data
end

-- -- -- mov -- -- --

function checkers.mov(data)
    local dr, du, ds = data.request, data.used, data.status
    local width = todimen(dr.width or figures.defaultwidth)
    local height = todimen(dr.height or figures.defaultheight)
    local foundname = du.fullname
    dr.width, dr.height = width, height
    du.width, du.height, du.foundname = width, height, foundname
    if trace_inclusion then
        report_graphics("including movie '%s': width %s, height %s",foundname,width,height)
    end
    -- we need to push the node.write in between ... we could make a shared helper for this
    context.startfoundexternalfigure(width .. "sp",height .. "sp")
    context(function()
        nodeinjections.insertmovie {
            width      = width,
            height     = height,
            factor     = number.dimenfactors.bp,
            ["repeat"] = dr["repeat"],
            controls   = dr.controls,
            preview    = dr.preview,
            label      = dr.label,
            foundname  = foundname,
        }
    end)
    context.stopfoundexternalfigure()
    return data
end

includers.mov = includers.nongeneric

-- -- -- mps -- -- --

local function internal(askedname)
    local spec, mprun, mpnum = match(lower(askedname),"mprun(:?)(.-)%.(%d+)")
    if spec == ":" then
        return mprun, mpnum
    else
        return "", mpnum
    end
end

function existers.mps(askedname)
    local mprun, mpnum = internal(askedname)
    if mpnum then
        return askedname
    else
        return existers.generic(askedname)
    end
end
function checkers.mps(data)
    local mprun, mpnum = internal(data.used.fullname)
    if mpnum then
        return checkers.nongeneric(data,format("\\docheckfiguremprun{%s}{%s}",mprun,mpnum))
    else
        return checkers.nongeneric(data,format("\\docheckfiguremps{%s}",data.used.fullname))
    end
end
includers.mps = includers.nongeneric

-- -- -- buffer -- -- --

function existers.buffer(askedname)
    askedname = file.nameonly(askedname)
    return buffers.exists(askedname) and askedname
end
function checkers.buffer(data)
    return checkers.nongeneric(data,format("\\docheckfigurebuffer{%s}", file.nameonly(data.used.fullname)))
end
includers.buffers = includers.nongeneric

-- -- -- tex -- -- --

function existers.tex(askedname)
    askedname = resolvers.findfile(askedname)
    return (askedname ~= "" and askedname) or false
end
function checkers.tex(data)
    return checkers.nongeneric(data,format("\\docheckfiguretex{%s}", data.used.fullname))
end
includers.tex = includers.nongeneric

-- -- -- converters -- -- --

local function makeoptions(options)
    local to = type(options)
    return (to == "table" and concat(options," ")) or (to == "string" and options) or ""
end

local function runprogram(...)
    local command = format(...)
    if trace_conversion or trace_programs then
        report_graphics("running %s",command)
    end
    os.spawn(command)
end

-- -- -- eps -- -- --

local epsconverter     = { }
converters.eps = epsconverter

programs.gs = {
    resolutions = {
        [variables.low]    = "screen",
        [variables.medium] = "ebook",
        [variables.high]   = "prepress",
    },
    options = {
        "-dAutoRotatePages=/None",
        "-dPDFSETTINGS=/%s",
        "-dEPSCrop",
    },
    command = (os.type == "windows" and "gswin32c") or "gs"
}

function epsconverter.pdf(oldname,newname,resolution) -- the resolution interface might change
    local gs = programs.gs
    runprogram (
        '%s -q -sDEVICE=pdfwrite -dNOPAUSE -dNOCACHE -dBATCH %s -sOutputFile="%s" "%s" -c quit',
        gs.command,
        format(makeoptions(gs.options),gs.resolutions[resolution or ""] or "prepress"),
        newname,
        oldname
    )
end

epsconverter.default = epsconverter.pdf

-- -- -- svg -- -- --

local svgconverter      = { }
converters.svg  = svgconverter
converters.svgz = svgconverter

-- inkscape on windows only works with complete paths

programs.inkscape = {
    options = {
        "--export-dpi=600"
    },
    command = "inkscape"
}

function svgconverter.pdf(oldname,newname)
    local inkscape = programs.inkscape
    local oldname = dir.expandname(oldname)
    local newname = dir.expandname(newname)
    runprogram (
        '%s "%s" %s -A "%s"',
        inkscape.command, oldname, makeoptions(inkscape.options), newname
    )
end

function svgconverter.png(oldname,newname)
    local inkscape = programs.inkscape
    runprogram (
        '%s "%s" --export-png="%s" %s',
        inkscape.command, oldname, newname, makeoptions(inkscape.options)
    )
end

svgconverter.default = svgconverter.pdf

-- -- -- gif -- -- --

local gifconverter     = { }
converters.gif = gifconverter

programs.convert = {
    command = "convert"    -- imagemagick
 -- command = "gm convert" -- graphicmagick
}

function gifconverter.pdf(oldname,newname)
    local convert = programs.convert
    runprogram (
        "%s %s %s %s",
        convert.command, makeoptions(convert.options), oldname, newname
    )
end

gifconverter.default = gifconverter.pdf

-- todo: lowres

-- -- -- bases -- -- --

figures.bases         = { }
figures.bases.list    = { } -- index      => { basename, fullname, xmlroot }
figures.bases.used    = { } -- [basename] => { basename, fullname, xmlroot } -- pointer to list
figures.bases.found   = { }
figures.bases.enabled = false

local bases = figures.bases

function bases.use(basename)
    if basename == "reset" then
        bases.list, bases.used, bases.found, bases.enabled = { }, { }, { }, false
    else
        basename = file.addsuffix(basename,"xml")
        if not bases.used[basename] then
            local t = { basename, nil, nil }
            bases.used[basename] = t
            bases.list[#bases.list+1] = t
            if not bases.enabled then
                bases.enabled = true
                xml.registerns("rlx","http://www.pragma-ade.com/schemas/rlx") -- we should be able to do this per xml file
            end
            if trace_bases then
                commands.writestatus("figures","registering base '%s'",basename)
            end
        end
    end
end

function bases.find(basename,askedlabel)
    if trace_bases then
        commands.writestatus("figures","checking for '%s' in base '%s'",askedlabel,basename)
    end
    basename = file.addsuffix(basename,"xml")
    local t = bases.found[askedlabel]
    if t == nil then
        local base = bases.used[basename]
        local page = 0
        if base[2] == nil then
            -- no yet located
            local figurepaths = figures.paths
            for i=1,#figurepaths do
                local path = figurepaths[i]
                local xmlfile = path .. "/" .. basename
                if io.exists(xmlfile) then
                    base[2] = xmlfile
                    base[3] = xml.load(xmlfile)
                    if trace_bases then
                        commands.writestatus("figures","base '%s' loaded",xmlfile)
                    end
                    break
                end
            end
        end
        t = false
        if base[2] and base[3] then -- rlx:library
            for e in xml.collected(base[3],"/(*:library|figurelibrary)/*:figure/*:label") do
                page = page + 1
                if xml.text(e) == askedlabel then
                    t = {
                        base = file.replacesuffix(base[2],"pdf"),
                        format = "pdf",
                        name = xml.text(e,"../*:file"), -- to be checked
                        page = page,
                    }
                    bases.found[askedlabel] = t
                    if trace_bases then
                        commands.writestatus("figures","figure '%s' found in base '%s'",askedlabel,base[2])
                    end
                    return t
                end
            end
            if trace_bases and not t then
                commands.writestatus("figures","figure '%s' not found in base '%s'",askedlabel,base[2])
            end
        end
    end
    return t
end

-- we can access sequential or by name

function bases.locate(askedlabel)
    local list = bases.list
    for i=1,#list do
        local entry = list[i]
        local t = bases.find(entry[1],askedlabel)
        if t then
            return t
        end
    end
    return false
end

function identifiers.base(data)
    if bases.enabled then
        local dr, du, ds = data.request, data.used, data.status
        local fbl = bases.locate(dr.name or dr.label)
        if fbl then
            du.page = fbl.page
            du.format = fbl.format
            du.fullname = fbl.base
            ds.fullname = fbl.name
            ds.format = fbl.format
            ds.page = fbl.page
            ds.status = 10
        end
    end
    return data
end

identifiers.list = {
    identifiers.base,
    identifiers.default
}

-- tracing

statistics.register("graphics processing time", function()
    local nofprocessed = figures.nofprocessed
    if nofprocessed > 0 then
        return format("%s seconds including tex, %s processed images", statistics.elapsedtime(figures),nofprocessed)
    else
        return nil
    end
end)

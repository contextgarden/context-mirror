if not modules then modules = { } end modules ['grph-inc'] = {
    version   = 1.001,
    comment   = "companion to grph-inc.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- todo: empty filename or only suffix always false (not found)
-- lowercase types
-- mps tex tmp svg
-- partly qualified
-- dimensions
-- use metatables
-- figures.boxnumber can go as we now can use names
-- avoid push
-- move some to command namespace

--[[
The ConTeXt figure inclusion mechanisms are among the oldest code
in ConTeXt and evolved into a complex whole. One reason is that we
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

local format, lower, find, match, gsub, gmatch = string.format, string.lower, string.find, string.match, string.gsub, string.gmatch
local contains = table.contains
local concat, insert, remove = table.concat, table.insert, table.remove
local todimen = string.todimen
local collapsepath = file.collapsepath
local formatters = string.formatters
local longtostring = string.longtostring
local expandfilename = dir.expandname

local P, lpegmatch = lpeg.P, lpeg.match

local settings_to_array = utilities.parsers.settings_to_array
local settings_to_hash  = utilities.parsers.settings_to_hash
local allocate          = utilities.storage.allocate
local setmetatableindex = table.setmetatableindex
local replacetemplate   = utilities.templates.replace

local images            = img

local texgetbox         = tex.getbox
local texsetbox         = tex.setbox

local hpack             = node.hpack

local context           = context

local variables         = interfaces.variables
local codeinjections    = backends.codeinjections
local nodeinjections    = backends.nodeinjections

local trace_figures     = false  trackers.register("graphics.locating",   function(v) trace_figures    = v end)
local trace_bases       = false  trackers.register("graphics.bases",      function(v) trace_bases      = v end)
local trace_programs    = false  trackers.register("graphics.programs",   function(v) trace_programs   = v end)
local trace_conversion  = false  trackers.register("graphics.conversion", function(v) trace_conversion = v end)
local trace_inclusion   = false  trackers.register("graphics.inclusion",  function(v) trace_inclusion  = v end)

local report_inclusion  = logs.reporter("graphics","inclusion")

local f_hash_part = formatters["%s->%s->%s"]
local f_hash_full = formatters["%s->%s->%s->%s->%s->%s->%s"]

local v_yes     = variables.yes
local v_low     = variables.low
local v_medium  = variables.medium
local v_high    = variables.high
local v_global  = variables["global"]
local v_local   = variables["local"]
local v_default = variables.default

local maxdimen = 2^30-1

function images.check(figure)
    if figure then
        local width = figure.width
        local height = figure.height
        if height > width then
            if height > maxdimen then
                figure.height = maxdimen
                figure.width  = width * maxdimen/height
                report_inclusion("limiting natural dimensions of %a (%s)",figure.filename,"height")
            end
        elseif width > maxdimen then
            figure.width  = maxdimen
            figure.height = height * maxdimen/width
            report_inclusion("limiting natural dimensions of %a (%s)",figure.filename,"width")
        end
        return figure
    end
end

--- some extra img functions --- can become luat-img.lua

local allimagekeys = images.keys()

local function imagetotable(imgtable)
    local result = { }
    for k=1,#allimagekeys do
        local key = allimagekeys[k]
        result[key] = imgtable[key]
    end
    return result
end

images.totable = imagetotable

function images.serialize(i,...)
    return table.serialize(imagetotable(i),...)
end

function images.print(i,...)
    return table.print(imagetotable(i),...)
end

function images.clone(i,data)
    i.width  = data.width  or i.width
    i.height = data.height or i.height
    -- attr etc
    return i
end

local validsizes = table.tohash(images.boxes())
local validtypes = table.tohash(images.types())

function images.checksize(size)
    if size then
        size = gsub(size,"box","")
        return validsizes[size] and size or "crop"
    else
        return "crop"
    end
end

local indexed = { }

function images.ofindex(n)
    return indexed[n]
end

--- we can consider an grph-ini file

figures                 = figures or { }
local figures           = figures

figures.boxnumber       = figures.boxnumber or 0
figures.defaultsearch   = true
figures.defaultwidth    = 0
figures.defaultheight   = 0
figures.defaultdepth    = 0
figures.nofprocessed    = 0
figures.preferquality   = true -- quality over location

local figures_loaded    = allocate()   figures.loaded      = figures_loaded
local figures_used      = allocate()   figures.used        = figures_used
local figures_found     = allocate()   figures.found       = figures_found
local figures_suffixes  = allocate()   figures.suffixes    = figures_suffixes
local figures_patterns  = allocate()   figures.patterns    = figures_patterns
local figures_resources = allocate()   figures.resources   = figures_resources

local existers          = allocate()   figures.existers    = existers
local checkers          = allocate()   figures.checkers    = checkers
local includers         = allocate()   figures.includers   = includers
local converters        = allocate()   figures.converters  = converters
local identifiers       = allocate()   figures.identifiers = identifiers
local programs          = allocate()   figures.programs    = programs

local defaultformat     = "pdf"
local defaultprefix     = "m_k_i_v_"

figures.localpaths = allocate {
    ".", "..", "../.."
}

figures.cachepaths = allocate {
    prefix  = "",
    path    = ".",
    subpath = ".",
}

local figure_paths = allocate(table.copy(figures.localpaths))
figures.paths      = figure_paths

local figures_order =  allocate {
    "pdf", "mps", "jpg", "png", "jp2", "jbig", "svg", "eps", "tif", "gif", "mov", "buffer", "tex", "cld", "auto",
}

local figures_formats = allocate { -- magic and order will move here
    ["pdf"]    = { list = { "pdf" } },
    ["mps"]    = { patterns = { "mps", "%d+" } },
    ["jpg"]    = { list = { "jpg", "jpeg" } },
    ["png"]    = { list = { "png" } },
    ["jp2"]    = { list = { "jp2" } },
    ["jbig"]   = { list = { "jbig", "jbig2", "jb2" } },
    ["svg"]    = { list = { "svg", "svgz" } },
    ["eps"]    = { list = { "eps", "ai" } },
    ["gif"]    = { list = { "gif" } },
    ["tif"]    = { list = { "tif", "tiff" } },
    ["mov"]    = { list = { "mov", "flv", "mp4" } }, -- "avi" is not supported
    ["buffer"] = { list = { "tmp", "buffer", "buf" } },
    ["tex"]    = { list = { "tex" } },
    ["cld"]    = { list = { "cld" } },
    ["auto"]   = { list = { "auto" } },
}

local figures_magics = allocate {
    { format = "png", pattern = P("\137PNG\013\010\026\010") },                   -- 89 50 4E 47 0D 0A 1A 0A,
    { format = "jpg", pattern = P("\255\216\255") },                              -- FF D8 FF
    { format = "jp2", pattern = P("\000\000\000\012\106\080\032\032\013\010"), }, -- 00 00 00 0C 6A 50 20 20 0D 0A },
    { format = "gif", pattern = P("GIF") },
    { format = "pdf", pattern = (1 - P("%PDF"))^0 * P("%PDF") },
}

figures.formats = figures_formats -- frozen
figures.magics  = figures_magics  -- frozen
figures.order   = figures_order   -- frozen

-- We can set the order but only indirectly so that we can check for support.

function figures.setorder(list) -- can be table or string
    if type(list) == "string" then
        list = settings_to_array(list)
    end
    if list and #list > 0 then
        figures_order = allocate()
        figures.order = figures_order
        local done = { } -- just to be sure in case the list is generated
        for i=1,#list do
            local l = lower(list[i])
            if figures_formats[l] and not done[l] then
                figures_order[#figures_order+1] = l
                done[l] = true
            end
        end
        report_inclusion("lookup order % a",figures_order)
    else
        -- invalid list
    end
end

function figures.guess(filename)
    local f = io.open(filename,'rb')
    if f then
        local str = f:read(100)
        f:close()
        if str then
            for i=1,#figures_magics do
                local pattern = figures_magics[i]
                if lpegmatch(pattern.pattern,str) then
                    local format = pattern.format
                    if trace_figures then
                        report_inclusion("file %a has format %a",filename,format)
                    end
                    return format
                end
            end
        end
    end
end

local function setlookups() -- tobe redone .. just set locals
    figures_suffixes = allocate()
    figures_patterns = allocate()
    for _, format in next, figures_order do
        local data = figures_formats[format]
        local list = data.list
        if list then
            for i=1,#list do
                figures_suffixes[list[i]] = format -- hash
            end
        else
            figures_suffixes[format] = format
        end
        local patterns = data.patterns
        if patterns then
            for i=1,#patterns do
                figures_patterns[#figures_patterns+1] = { patterns[i], format } -- array
            end
        end
    end
    figures.suffixes = figures_suffixes
    figures.patterns = figures_patterns
end

setlookups()

figures.setlookups = setlookups

function figures.registerresource(t)
    local n = #figures_resources + 1
    figures_resources[n] = t
    return n
end

local function register(tag,target,what)
    local data = figures_formats[target] -- resolver etc
    if not data then
        data = { }
        figures_formats[target] = data
    end
    local d = data[tag] -- list or pattern
    if d and not contains(d,what) then
        d[#d+1] = what -- suffix or patternspec
    else
        data[tag] = { what }
    end
    if not contains(figures_order,target) then
        figures_order[#figures_order+1] = target
    end
    setlookups()
end

function figures.registersuffix (suffix, target) register('list',   target,suffix ) end
function figures.registerpattern(pattern,target) register('pattern',target,pattern) end

local last_locationset = last_locationset or nil
local last_pathlist    = last_pathlist    or nil

function figures.setpaths(locationset,pathlist)
    if last_locationset == locationset and last_pathlist == pathlist then
        -- this function can be called each graphic so we provide this optimization
        return
    end
    local t, h = figure_paths, settings_to_hash(locationset)
    if last_locationset ~= locationset then
        -- change == reset (actually, a 'reset' would indeed reset
        if h[v_local] then
            t = table.fastcopy(figures.localpaths or { })
        else
            t = { }
        end
        figures.defaultsearch = h[v_default]
        last_locationset = locationset
    end
    if h[v_global] then
        local list = settings_to_array(pathlist)
        for i=1,#list do
            local s = list[i]
            if not contains(t,s) then
                t[#t+1] = s
            end
        end
    end
    figure_paths  = t
    last_pathlist = pathlist
    figures.paths = figure_paths
    if trace_figures then
        report_inclusion("using locations %a",last_locationset)
        report_inclusion("using paths % a",figure_paths)
    end
end

-- check conversions and handle it here

function figures.hash(data)
    local status = data and data.status
    return (status and status.hash or tostring(status.private)) or "nohash" -- the <img object>
end

-- interfacing to tex

local function new() -- we could use metatables status -> used -> request but it needs testing
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
        mask       = false,
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
    -- this needs checking because we might check for nil, the test case
    -- is getfiguredimensions which then should return ~= 0
 -- setmetatableindex(status, used)
 -- setmetatableindex(used, request)
    return {
        request = request,
        used    = used,
        status  = status,
    }
end

-- use table.insert|remove

local lastfiguredata = nil -- will be topofstack or last so no { } (else problems with getfiguredimensions)
local callstack      = { }

function figures.initialize(request)
    local figuredata = new()
    if request then
        -- request.width/height are strings and are only used when no natural dimensions
        -- can be determined; at some point the handlers might set them to numbers instead
        local w = tonumber(request.width) or 0
        local h = tonumber(request.height) or 0
        request.width  = w > 0 and w or nil
        request.height = h > 0 and h or nil
        --
        request.page      = math.max(tonumber(request.page) or 1,1)
        request.size      = images.checksize(request.size)
        request.object    = request.object == v_yes
        request["repeat"] = request["repeat"] == v_yes
        request.preview   = request.preview == v_yes
        request.cache     = request.cache ~= "" and request.cache
        request.prefix    = request.prefix ~= "" and request.prefix
        request.format    = request.format ~= "" and request.format
        table.merge(figuredata.request,request)
    end
    return figuredata
end

function figures.push(request)
    statistics.starttiming(figures)
    local figuredata = figures.initialize(request)
    insert(callstack,figuredata)
    lastfiguredata = figuredata
    return figuredata
end

function figures.pop()
    lastfiguredata = remove(callstack) or lastfiguredata
    statistics.stoptiming(figures)
end

function figures.current()
    return callstack[#callstack] or lastfiguredata
end

local function get(category,tag,default)
    local value = lastfiguredata and lastfiguredata[category]
    value = value and value[tag]
    if not value or value == "" or value == true then
        return default or ""
    else
        return value
    end
end

figures.get = get

function commands.figurevariable(category,tag,default)
    context(get(category,tag,default))
end

function commands.figurestatus (tag,default) context(get("status", tag,default)) end
function commands.figurerequest(tag,default) context(get("request",tag,default)) end
function commands.figureused   (tag,default) context(get("used",   tag,default)) end

function commands.figurefilepath() context(file.dirname (get("used","fullname"))) end
function commands.figurefilename() context(file.nameonly(get("used","fullname"))) end
function commands.figurefiletype() context(file.extname (get("used","fullname"))) end

-- todo: local path or cache path

local function forbiddenname(filename)
    if not filename or filename == "" then
        return false
    end
    local expandedfullname = collapsepath(filename,true)
    local expandedinputname = collapsepath(file.addsuffix(environment.jobfilename,environment.jobfilesuffix),true)
    if expandedfullname == expandedinputname then
        report_inclusion("skipping graphic with same name as input filename %a, enforce suffix",expandedinputname)
        return true
    end
    local expandedoutputname = collapsepath(codeinjections.getoutputfilename(),true)
    if expandedfullname == expandedoutputname then
        report_inclusion("skipping graphic with same name as output filename %a, enforce suffix",expandedoutputname)
        return true
    end
end

local function register(askedname,specification)
    if not specification then
        specification = { }
    elseif forbiddenname(specification.fullname) then
        specification = { }
    else
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
                report_inclusion("checking conversion of %a, fullname %a, old format %a, new format %a, conversion %a, resolution %a",
                    askedname,specification.fullname,format,newformat,conversion or "default",resolution or "default")
            end
            -- quick hack
            local converter = (newformat ~= format or resolution) and converters[format]
            if converter then
                if converter[newformat] then
                    converter = converter[newformat]
                else
                    newformat = defaultformat
                    if converter[newformat] then
                        converter = converter[newformat]
                    else
                        converter = nil
                        newformat = defaultformat
                    end
                end
            elseif trace_conversion then
                report_inclusion("no converter for %a to %a",format,newformat)
            end
            if converter then
                local oldname = specification.fullname
                local newpath = file.dirname(oldname)
                local oldbase = file.basename(oldname)
                --
                -- problem: we can have weird filenames, like a.b.c (no suffix) and a.b.c.gif
                -- so we cannot safely remove a suffix (unless we do that for known suffixes)
                --
                -- local newbase = file.removesuffix(oldbase) -- assumes a known suffix
                --
                -- so we now have (also see *):
                --
                local newbase = oldbase
                --
                local fc = specification.cache or figures.cachepaths.path
                if fc and fc ~= "" and fc ~= "." then
                    newpath = fc
                else
                    newbase = defaultprefix .. newbase
                end
                if not file.is_writable(newpath) then
                    if trace_conversion then
                        report_inclusion("path %a is not writable, forcing conversion path %a",newpath,".")
                    end
                    newpath = "."
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
                --
                -- see *, we had:
                --
                -- local newbase = file.addsuffix(newbase,newformat)
                --
                -- but now have (result of Aditya's web image testing):
                --
                -- as a side effect we can now have multiple fetches with different
                -- original figures_formats, not that it matters much (apart from older conversions
                -- sticking around)
                --
                local newbase = newbase .. "." .. newformat
                --
                local newname = file.join(newpath,newbase)
                dir.makedirs(newpath)
                oldname = collapsepath(oldname)
                newname = collapsepath(newname)
                local oldtime = lfs.attributes(oldname,'modification') or 0
                local newtime = lfs.attributes(newname,'modification') or 0
                if newtime == 0 or oldtime > newtime then
                    if trace_conversion then
                        report_inclusion("converting %a (%a) from %a to %a",askedname,oldname,format,newformat)
                    end
                    converter(oldname,newname,resolution or "")
                else
                    if trace_conversion then
                        report_inclusion("no need to convert %a (%a) from %a to %a",askedname,oldname,format,newformat)
                    end
                end
                if io.exists(newname) and io.size(newname) > 0 then
                    specification.foundname = oldname
                    specification.fullname  = newname
                    specification.prefix    = prefix
                    specification.subpath   = subpath
                    specification.converted = true
                    format = newformat
                    if not figures_suffixes[format] then
                        -- maybe the new format is lowres.png (saves entry in suffixes)
                        -- so let's do thsi extra check
                        local suffix = file.suffix(newformat)
                        if figures_suffixes[suffix] then
                            if trace_figures then
                                report_inclusion("using suffix %a as format for %a",suffix,format)
                            end
                            format = suffix
                        end
                    end
                elseif io.exists(oldname) then
                    specification.fullname  = oldname -- was newname
                    specification.converted = false
                end
            end
        end
        local found = figures_suffixes[format] -- validtypes[format]
        if not found then
            specification.found = false
            if trace_figures then
                report_inclusion("format %a is not supported",format)
            end
        else
            specification.found = true
            if trace_figures then
                if validtypes[format] then -- format?
                    report_inclusion("format %a natively supported by backend",format)
                else
                    report_inclusion("format %a supported by output file format",format)
                end
            end
        end
    end
    specification.foundname = specification.foundname or specification.fullname
    local askedhash = f_hash_part(askedname,specification.conversion or "default",specification.resolution or "default")
    figures_found[askedhash] = specification
    return specification
end

local resolve_too = false -- true

local internalschemes = {
    file = true,
}

local function locate(request) -- name, format, cache
    -- not resolvers.cleanpath(request.name) as it fails on a!b.pdf and b~c.pdf
    -- todo: more restricted cleanpath
    local askedname = request.name
    local askedhash = f_hash_part(askedname,request.conversion or "default",request.resolution or "default")
    local foundname = figures_found[askedhash]
    if foundname then
        return foundname
    end
    --
    local askedcache      = request.cache
    local askedconversion = request.conversion
    local askedresolution = request.resolution
    --
    if request.format == "" or request.format == "unknown" then
        request.format = nil
    end
    -- protocol check
    local hashed = url.hashed(askedname)
    if not hashed then
        -- go on
    elseif internalschemes[hashed.scheme] then
        local path = hashed.path
        if path and path ~= "" then
            askedname = path
        end
    else
        local foundname = resolvers.findbinfile(askedname)
        if not foundname or not lfs.isfile(foundname) then -- foundname can be dummy
            if trace_figures then
                report_inclusion("unknown url %a",askedname)
            end
            -- url not found
            return register(askedname)
        end
        local askedformat = request.format or file.suffix(askedname) or ""
        local guessedformat = figures.guess(foundname)
        if askedformat ~= guessedformat then
            if trace_figures then
                report_inclusion("url %a has unknown format",askedname)
            end
            -- url found, but wrong format
            return register(askedname)
        else
            if trace_figures then
                report_inclusion("url %a is resolved to %a",askedname,foundname)
            end
            return register(askedname, {
                askedname  = askedname,
                fullname   = foundname,
                format     = askedformat,
                cache      = askedcache,
                conversion = askedconversion,
                resolution = askedresolution,
            })
        end
    end
    -- we could use the hashed data instead
    local askedpath= file.is_rootbased_path(askedname)
    local askedbase = file.basename(askedname)
    local askedformat = request.format or file.suffix(askedname) or ""
    if askedformat ~= "" then
        askedformat = lower(askedformat)
        if trace_figures then
            report_inclusion("forcing format %a",askedformat)
        end
        local format = figures_suffixes[askedformat]
        if not format then
            for i=1,#figures_patterns do
                local pattern = figures_patterns[i]
                if find(askedformat,pattern[1]) then
                    format = pattern[2]
                    if trace_figures then
                        report_inclusion("asked format %a matches %a",askedformat,pattern[1])
                    end
                    break
                end
            end
        end
        if format then
            local foundname, quitscanning, forcedformat = figures.exists(askedname,format,resolve_too) -- not askedformat
            if foundname then
                return register(askedname, {
                    askedname  = askedname,
                    fullname   = foundname, -- askedname,
                    format     = forcedformat or format,
                    cache      = askedcache,
                 -- foundname  = foundname, -- no
                    conversion = askedconversion,
                    resolution = askedresolution,
                })
            elseif quitscanning then
                return register(askedname)
            end
            askedformat = format -- new per 2013-08-05
        elseif trace_figures then
            report_inclusion("unknown format %a",askedformat)
        end
        if askedpath then
            -- path and type given, todo: strip pieces of path
            local foundname, quitscanning, forcedformat = figures.exists(askedname,askedformat,resolve_too)
            if foundname then
                return register(askedname, {
                    askedname  = askedname,
                    fullname   = foundname, -- askedname,
                    format     = forcedformat or askedformat,
                    cache      = askedcache,
                    conversion = askedconversion,
                    resolution = askedresolution,
                })
            end
        else
            -- type given
            for i=1,#figure_paths do
                local path = figure_paths[i]
                local check = path .. "/" .. askedname
             -- we pass 'true' as it can be an url as well, as the type
             -- is given we don't waste much time
                local foundname, quitscanning, forcedformat = figures.exists(check,askedformat,resolve_too)
                if foundname then
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
            report_inclusion("using rootbased path")
        end
        for i=1,#figures_order do
            local format = figures_order[i]
            local list = figures_formats[format].list or { format }
            for j=1,#list do
                local suffix = list[j]
                local check = file.addsuffix(askedname,suffix)
                local foundname, quitscanning, forcedformat = figures.exists(check,format,resolve_too)
                if foundname then
                    return register(askedname, {
                        askedname  = askedname,
                        fullname   = foundname, -- check,
                        format     = forcedformat or format,
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
                report_inclusion("unknown format, quality preferred")
            end
            for j=1,#figures_order do
                local format = figures_order[j]
                local list = figures_formats[format].list or { format }
                for k=1,#list do
                    local suffix = list[k]
                 -- local name = file.replacesuffix(askedbase,suffix)
                    local name = file.replacesuffix(askedname,suffix)
                    for i=1,#figure_paths do
                        local path = figure_paths[i]
                        local check = path .. "/" .. name
                        local isfile = url.hashed(check).scheme == "file"
                        if not isfile then
                            if trace_figures then
                                report_inclusion("warning: skipping path %a",path)
                            end
                        else
                            local foundname, quitscanning, forcedformat = figures.exists(check,format,resolve_too) -- true)
                            if foundname then
                                return register(askedname, {
                                    askedname  = askedname,
                                    fullname   = foundname, -- check
                                    format     = forcedformat or format,
                                    cache      = askedcache,
                                    conversion = askedconversion,
                                    resolution = askedresolution,
                                })
                            end
                        end
                    end
                end
            end
        else -- 'location'
            if trace_figures then
                report_inclusion("unknown format, using path strategy")
            end
            for i=1,#figure_paths do
                local path = figure_paths[i]
                for j=1,#figures_order do
                    local format = figures_order[j]
                    local list = figures_formats[format].list or { format }
                    for k=1,#list do
                        local suffix = list[k]
                        local check = path .. "/" .. file.replacesuffix(askedbase,suffix)
                        local foundname, quitscanning, forcedformat = figures.exists(check,format,resolve_too)
                        if foundname then
                            return register(askedname, {
                                askedname  = askedname,
                                fullname   = foudname, -- check,
                                format     = forcedformat or format,
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
                report_inclusion("using default tex path")
            end
            for j=1,#figures_order do
                local format = figures_order[j]
                local list = figures_formats[format].list or { format }
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
    return register(askedname, { -- these two are needed for hashing 'found'
        conversion = askedconversion,
        resolution = askedresolution,
    })
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
    data = data or callstack[#callstack] or lastfiguredata
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
    data = data or callstack[#callstack] or lastfiguredata
    return (checkers[data.status.format] or checkers.generic)(data)
end

function figures.include(data)
    data = data or callstack[#callstack] or lastfiguredata
    return (includers[data.status.format] or includers.generic)(data)
end

function figures.scale(data) -- will become lua code
    context.doscalefigure()
    return data
end

function figures.done(data)
    figures.nofprocessed = figures.nofprocessed + 1
    data = data or callstack[#callstack] or lastfiguredata
    local dr, du, ds, nr = data.request, data.used, data.status, figures.boxnumber
    local box = texgetbox(nr)
    ds.width  = box.width
    ds.height = box.height
    ds.xscale = ds.width /(du.width  or 1)
    ds.yscale = ds.height/(du.height or 1)
    ds.page   = ds.page or du.page or dr.page -- sort of redundant but can be limited
    return data
end

function figures.dummy(data)
    data = data or callstack[#callstack] or lastfiguredata
    local dr, du, nr = data.request, data.used, figures.boxnumber
    local box  = hpack(node.new("hlist")) -- we need to set the dir (luatex 0.60 buglet)
    du.width   = du.width  or figures.defaultwidth
    du.height  = du.height or figures.defaultheight
    du.depth   = du.depth  or figures.defaultdepth
 -- box.dir    = "TLT"
    box.width  = du.width
    box.height = du.height
    box.depth  = du.depth
    texsetbox(nr,box) -- hm, should be global (to be checked for consistency)
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
            report_inclusion("%a resolved to %a",askedname,result)
        else
            report_inclusion("%a cannot be resolved",askedname)
        end
    end
    return result
end

function checkers.generic(data)
    local dr, du, ds = data.request, data.used, data.status
    local name = du.fullname or "unknown generic"
    local page = du.page or dr.page
    local size = dr.size or "crop"
    local color = dr.color or "natural"
    local mask = dr.mask or "none"
    local conversion = dr.conversion
    local resolution = dr.resolution
    if not conversion or conversion == "" then
        conversion = "unknown"
    end
    if not resolution or resolution == "" then
        resolution = "unknown"
    end
    local hash = f_hash_full(name,page,size,color,conversion,resolution,mask)
    local figure = figures_loaded[hash]
    if figure == nil then
        figure = images.new {
            filename        = name,
            page            = page,
            pagebox         = dr.size,
         -- visiblefilename = "", -- this prohibits the full filename ending up in the file
        }
        codeinjections.setfigurecolorspace(data,figure)
        codeinjections.setfiguremask(data,figure)
        figure = figure and images.check(images.scan(figure)) or false
        local f, d = codeinjections.setfigurealternative(data,figure)
        figure, data = f or figure, d or data
        figures_loaded[hash] = figure
        if trace_conversion then
            report_inclusion("new graphic, using hash %a",hash)
        end
    else
        if trace_conversion then
            report_inclusion("existing graphic, using hash %a",hash)
        end
    end
    if figure then
        du.width       = figure.width
        du.height      = figure.height
        du.pages       = figure.pages
        du.depth       = figure.depth or 0
        du.colordepth  = figure.colordepth or 0
        du.xresolution = figure.xres or 0
        du.yresolution = figure.yres or 0
        du.xsize       = figure.xsize or 0
        du.ysize       = figure.ysize or 0
        ds.private     = figure
        ds.hash        = hash
    end
    return data
end

function includers.generic(data)
    local dr, du, ds = data.request, data.used, data.status
    -- here we set the 'natural dimensions'
    dr.width = du.width
    dr.height = du.height
    local hash = figures.hash(data)
    local figure = figures_used[hash]
 -- figures.registerresource {
 --     filename = du.fullname,
 --     width    = dr.width,
 --     height   = dr.height,
 -- }
    if figure == nil then
        figure = ds.private
        if figure then
            figure = images.copy(figure)
            figure = figure and images.clone(figure,data.request) or false
        end
        figures_used[hash] = figure
    end
    if figure then
        local nr = figures.boxnumber
        -- it looks like we have a leak in attributes here .. todo
        local box = hpack(images.node(figure)) -- images.node(figure) not longer valid
        indexed[figure.index] = figure
        box.width, box.height, box.depth = figure.width, figure.height, 0 -- new, hm, tricky, we need to do that in tex (yet)
        texsetbox(nr,box)
        ds.objectnumber = figure.objnum
        context.relocateexternalfigure()
    end
    return data
end

-- -- -- nongeneric -- -- --

local function checkers_nongeneric(data,command) -- todo: macros and context.*
    local dr, du, ds = data.request, data.used, data.status
    local name = du.fullname or "unknown nongeneric"
    local hash = name
    if dr.object then
        -- hm, bugged ... waiting for an xform interface
        if not job.objects.get("FIG::"..hash) then
            if type(command) == "function" then
                command()
            end
            context.dosetfigureobject(hash)
        end
        context.doboxfigureobject(hash)
    elseif type(command) == "function" then
        command()
    end
    return data
end

local function includers_nongeneric(data)
    return data
end

checkers.nongeneric  = checkers_nongeneric
includers.nongeneric = includers_nongeneric

-- -- -- mov -- -- --

function checkers.mov(data)
    local dr, du, ds = data.request, data.used, data.status
    local width = todimen(dr.width or figures.defaultwidth)
    local height = todimen(dr.height or figures.defaultheight)
    local foundname = du.fullname
    dr.width, dr.height = width, height
    du.width, du.height, du.foundname = width, height, foundname
    if trace_inclusion then
        report_inclusion("including movie %a, width %p, height %p",foundname,width,height)
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

internalschemes.mprun = true

local function internal(askedname)
    local spec, mprun, mpnum = match(lower(askedname),"mprun([:%.]?)(.-)%.(%d+)")
    if spec ~= "" then
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
        return checkers_nongeneric(data,function() context.docheckfiguremprun(mprun,mpnum) end)
    else
        return checkers_nongeneric(data,function() context.docheckfiguremps(data.used.fullname) end)
    end
end

includers.mps = includers.nongeneric

-- -- -- tex -- -- --

function existers.tex(askedname)
    askedname = resolvers.findfile(askedname)
    return askedname ~= "" and askedname or false
end

function checkers.tex(data)
    return checkers_nongeneric(data,function() context.docheckfiguretex(data.used.fullname) end)
end

includers.tex = includers.nongeneric

-- -- -- buffer -- -- --

function existers.buffer(askedname)
    local name = file.nameonly(askedname)
    local okay = buffers.exists(name)
    return okay and name, true -- always quit scanning
end

function checkers.buffer(data)
    return checkers_nongeneric(data,function() context.docheckfigurebuffer(file.nameonly(data.used.fullname)) end)
end

includers.buffers = includers.nongeneric

-- -- -- auto -- -- --

function existers.auto(askedname)
    local name = gsub(askedname, ".auto$", "")
    local format = figures.guess(name)
    if format then
        report_inclusion("format guess %a for %a",format,name)
    else
        report_inclusion("format guess for %a is not possible",name)
    end
    return format and name, true, format
end

checkers.auto  = checkers.generic
includers.auto = includers.generic

-- -- -- cld -- -- --

existers.cld = existers.tex

function checkers.cld(data)
    return checkers_nongeneric(data,function() context.docheckfigurecld(data.used.fullname) end)
end

includers.cld = includers.nongeneric

-- -- -- converters -- -- --

local function makeoptions(options)
    local to = type(options)
    return (to == "table" and concat(options," ")) or (to == "string" and options) or ""
end

-- programs.makeoptions = makeoptions

local function runprogram(binary,argument,variables)
    local binary = match(binary,"[%S]+") -- to be sure
    if type(argument) == "table" then
        argument = concat(argument," ") -- for old times sake
    end
    if not os.which(binary) then
        report_inclusion("program %a is not installed, not running command: %s",binary,command)
    elseif not argument or argument == "" then
        report_inclusion("nothing to run, unknown program %a",binary)
    else
        local command = format([["%s" %s]],binary,replacetemplate(longtostring(argument),variables))
        if trace_conversion or trace_programs then
            report_inclusion("running command: %s",command)
        end
        os.spawn(command)
    end
end

programs.run = runprogram

-- -- -- eps & pdf -- -- --
--
-- \externalfigure[cow.eps]
-- \externalfigure[cow.pdf][conversion=stripped]

local epsconverter = converters.eps or { }
converters.eps     = epsconverter
converters.ps      = epsconverter

local epstopdf = {
    resolutions = {
        [v_low]    = "screen",
        [v_medium] = "ebook",
        [v_high]   = "prepress",
    },
    command = os.type == "windows" and "gswin32c" or "gs",
    -- -dProcessDSCComments=false
    argument = [[
        -q
        -sDEVICE=pdfwrite
        -dNOPAUSE
        -dNOCACHE
        -dBATCH
        -dAutoRotatePages=/None
        -dPDFSETTINGS=/%presets%
        -dEPSCrop
        -sOutputFile=%newname%
        %oldname%
        -c quit
    ]],
}

programs.epstopdf = epstopdf
programs.gs       = epstopdf

function epsconverter.pdf(oldname,newname,resolution) -- the resolution interface might change
    local epstopdf = programs.epstopdf -- can be changed
    local presets = epstopdf.resolutions[resolution or ""] or epstopdf.resolutions.high
    runprogram(epstopdf.command, epstopdf.argument, {
        newname = newname,
        oldname = oldname,
        presets = presets,
    } )
end

epsconverter.default = epsconverter.pdf

local pdfconverter = converters.pdf or { }
converters.pdf     = pdfconverter

programs.pdftoeps = {
    command  = "pdftops",
    argument = [[-eps "%oldname%" "%newname%]],
}

pdfconverter.stripped = function(oldname,newname)
    local pdftoeps = programs.pdftoeps -- can be changed
    local epstopdf = programs.epstopdf -- can be changed
    local presets = epstopdf.resolutions[resolution or ""] or epstopdf.resolutions.high
    local tmpname = newname .. ".tmp"
    runprogram(pdftoeps.command, pdftoeps.argument, { oldname = oldname, newname = tmpname, presets = presets })
    runprogram(epstopdf.command, epstopdf.argument, { oldname = tmpname, newname = newname, presets = presets })
    os.remove(tmpname)
end

figures.registersuffix("stripped","pdf")

-- -- -- svg -- -- --

local svgconverter = { }
converters.svg     = svgconverter
converters.svgz    = svgconverter

-- inkscape on windows only works with complete paths

programs.inkscape = {
    command  = "inkscape",
    pdfargument = [[
        "%oldname%"
        --export-dpi=600
        -A
        "%newname%"
    ]],
    pngargument = [[
        "%oldname%"
        --export-dpi=600
        --export-png="%newname%"
    ]],
}

function svgconverter.pdf(oldname,newname)
    local inkscape = programs.inkscape -- can be changed
    runprogram(inkscape.command, inkscape.pdfargument, {
        newname = expandfilename(newname),
        oldname = expandfilename(oldname),
    } )
end

function svgconverter.png(oldname,newname)
    local inkscape = programs.inkscape
    runprogram(inkscape.command, inkscape.pngargument, {
        newname = expandfilename(newname),
        oldname = expandfilename(oldname),
    } )
end

svgconverter.default = svgconverter.pdf

-- -- -- gif -- -- --
-- -- -- tif -- -- --

local gifconverter = converters.gif or { }
local tifconverter = converters.tif or { }
local bmpconverter = converters.bmp or { }

converters.gif     = gifconverter
converters.tif     = tifconverter
converters.bmp     = bmpconverter

programs.convert = {
    command  = "gm", -- graphicmagick
    argument = [[convert "%oldname%" "%newname%"]],
}

local function converter(oldname,newname)
    local convert = programs.convert
    runprogram(convert.command, convert.argument, {
        newname = newname,
        oldname = oldname,
    } )
end

tifconverter.pdf = converter
gifconverter.pdf = converter
bmpconverter.pdf = converter

gifconverter.default = converter
tifconverter.default = converter
bmpconverter.default = converter

-- todo: lowres

-- -- -- bases -- -- --

local bases         = allocate()
figures.bases       = bases

local bases_list    =  nil -- index      => { basename, fullname, xmlroot }
local bases_used    =  nil -- [basename] => { basename, fullname, xmlroot } -- pointer to list
local bases_found   =  nil
local bases_enabled = false

local function reset()
    bases_list    = allocate()
    bases_used    = allocate()
    bases_found   = allocate()
    bases_enabled = false
    bases.list    = bases_list
    bases.used    = bases_used
    bases.found   = bases_found
end

reset()

function bases.use(basename)
    if basename == "reset" then
        reset()
    else
        basename = file.addsuffix(basename,"xml")
        if not bases_used[basename] then
            local t = { basename, nil, nil }
            bases_used[basename] = t
            bases_list[#bases_list+1] = t
            if not bases_enabled then
                bases_enabled = true
                xml.registerns("rlx","http://www.pragma-ade.com/schemas/rlx") -- we should be able to do this per xml file
            end
            if trace_bases then
                report_inclusion("registering base %a",basename)
            end
        end
    end
end

local function bases_find(basename,askedlabel)
    if trace_bases then
        report_inclusion("checking for %a in base %a",askedlabel,basename)
    end
    basename = file.addsuffix(basename,"xml")
    local t = bases_found[askedlabel]
    if t == nil then
        local base = bases_used[basename]
        local page = 0
        if base[2] == nil then
            -- no yet located
            for i=1,#figure_paths do
                local path = figure_paths[i]
                local xmlfile = path .. "/" .. basename
                if io.exists(xmlfile) then
                    base[2] = xmlfile
                    base[3] = xml.load(xmlfile)
                    if trace_bases then
                        report_inclusion("base %a loaded",xmlfile)
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
                    bases_found[askedlabel] = t
                    if trace_bases then
                        report_inclusion("figure %a found in base %a",askedlabel,base[2])
                    end
                    return t
                end
            end
            if trace_bases and not t then
                report_inclusion("figure %a not found in base %a",askedlabel,base[2])
            end
        end
    end
    return t
end

-- we can access sequential or by name

local function bases_locate(askedlabel)
    for i=1,#bases_list do
        local entry = bases_list[i]
        local t = bases_find(entry[1],askedlabel)
        if t then
            return t
        end
    end
    return false
end

function identifiers.base(data)
    if bases_enabled then
        local dr, du, ds = data.request, data.used, data.status
        local fbl = bases_locate(dr.name or dr.label)
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

bases.locate = bases_locate
bases.find   = bases_find

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

-- helper

function figures.applyratio(width,height,w,h) -- width and height are strings and w and h are numbers
    if not width or width == "" then
        if not height or height == "" then
            return figures.defaultwidth, figures.defaultheight
        else
            height = todimen(height)
            if w and h then
                return height * w/h, height
            else
                return figures.defaultwidth, height
            end
        end
    else
        width = todimen(width)
        if not height or height == "" then
            if w and h then
                return width, width * h/w
            else
                return width, figures.defaultheight
            end
        else
            return width, todimen(height)
        end
    end
end

-- example of simple plugins:
--
-- figures.converters.png = {
--     png = function(oldname,newname,resolution)
--         local command = string.format('gm convert -depth 1 "%s" "%s"',oldname,newname)
--         logs.report(string.format("running command %s",command))
--         os.execute(command)
--     end,
-- }

-- local fig = figures.push { name = pdffile }
-- figures.identify()
-- figures.check()
-- local nofpages = fig.used.pages
-- figures.pop()

-- interfacing

commands.setfigurelookuporder = figures.setorder

--

figures.images = images

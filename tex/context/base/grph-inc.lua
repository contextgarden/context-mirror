if not modules then modules = { } end modules ['grph-inc'] = {
    version   = 1.001,
    comment   = "companion to grph-inc.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- lowercase types
-- mps tex tmp svg
-- partly qualified
-- dimensions
-- consult rlx

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

local texsprint, format, lower, find, match = tex.sprint, string.format, string.lower, string.find, string.match

local ctxcatcodes = tex.ctxcatcodes
local variables = interfaces.variables

local trace_figures = false  trackers.register("figures.locating",function(v) trace_figures = v end)
local trace_bases   = false  trackers.register("figures.bases",   function(v) trace_bases   = v end)

--- some extra img functions ---

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

function img.check_size(size)
    if size then
        size = size:gsub("box","")
        return (validsizes[size] and size) or "crop"
    else
        return "crop"
    end
end

---

figures                = figures          or { }
figures.loaded         = figures.loaded   or { }
figures.used           = figures.used     or { }
figures.found          = figures.found    or { }
figures.suffixes       = figures.suffixes or { }
figures.patterns       = figures.patterns or { }
figures.boxnumber      = figures.boxid    or 0
figures.defaultsearch  = true
figures.defaultwidth   = 0
figures.defaultheight  = 0
figures.defaultdepth   = 0
figures.n              = 0
figures.prefer_quality = true -- quality over location

figures.localpaths = {
    ".", "..", "../.."
}
figures.cachepaths = {
    prefix = "",
    path = ".",
    subpath = ".",
}

figures.paths  = table.copy(figures.localpaths)

figures.order =  {
    "pdf", "mps", "jpg", "png", "jbig", "svg", "eps", "gif", "mov", "buffer", "tex",
}

figures.formats = {
    ["pdf"]    = { list = { "pdf" } },
    ["mps"]    = { patterns = { "mps", "%d+" } },
    ["jpg"]    = { list = { "jpg", "jpeg" } },
    ["png"]    = { list = { "png" } },
    ["jbig"]   = { list = { "jbig", "jbig2", "jb2" } },
    ["svg"]    = { list = { "svg", "svgz" } },
    ["eps"]    = { list = { "eps", "ai" } },
    ["gif"]    = { list = { "gif" } },
    ["mov"]    = { list = { "mov", "avi" } },
    ["buffer"] = { list = { "tmp", "buffer", "buf" } },
    ["tex"]    = { list = { "tex" } },
}

function figures.setlookups()
    figures.suffixes, figures.patterns = { }, { }
    for _, format in pairs(figures.order) do
        local data = figures.formats[format]
        local fs, fp = figures.suffixes, figures.patterns
        if data.list then
            for _, s in ipairs(data.list) do
                fs[s] = format -- hash
            end
        else
            fs[format] = format
        end
        if data.patterns then
            for _, s in ipairs(data.patterns) do
                fp[#fp+1] = { s, format } -- array
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
    if d and not table.contains(d,what) then
        d[#d+1] = what -- suffix or patternspec
    else
        data[tag] = { what }
    end
    if not table.contains(figures.order,target) then
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
        for s in pathlist:gmatch("([^, ]+)") do
            if not table.contains(t,s) then
                t[#t+1] = s
            end
        end
    end
    figures.paths, last_pathlist = t, pathlist
    if trace_figures then
        commands.writestatus("figures","locations: %s",last_locationset)
        commands.writestatus("figures","path list: %s",table.concat(figures.paths, " "))
    end
end

-- check conversions and handle it here

--~ local keys = img.keys()

--~ function figures.hash(data)
--~     local i = data.status.private
--~     local t = { }
--~     for _, v in ipairs(keys) do
--~         local iv = i[v]
--~         if iv then
--~             t[#t+1] = v .. '=' .. iv
--~         end
--~     end
--~     return table.concat(t,"+")
--~ end

function figures.hash(data)
    return data.status.hash or tostring(data.status.private) -- the <img object>
--  return data.status.fullname .. "+".. (data.status.page or data.request.page or 1) -- img is still not perfect
end

-- interfacing to tex

do

    local figuredata = { }
    local callstack  = { }

    function figures.new()
        figuredata = {
            request = {
                name = false,
                label = false,
                format = false,
                page = false,
                width = false,
                height = false,
                preview = false,
                ["repeat"] = false,
                controls = false,
                display = false,
                conversion = false,
                cache = false,
                prefix = false,
                size = false,
            },
            used = {
                fullname = false,
                format = false,
                name = false,
                path = false,
                suffix = false,
                width = false,
                height = false,
            },
            status = {
                status = 0,
                converted = false,
                cached = false,
                fullname = false,
                format = false,
            },
        }
        return figuredata
    end

    function figures.push(request)
        statistics.starttiming(figures)
        local figuredata = figures.new()
        if request then
        local iv = interfaces.variables
        --  request.width/height are strings and are only used when no natural dimensions
        --  can be determined; at some point the handlers might set them to numbers instead
        --  local w, h = tonumber(request.width), tonumber(request.height)
            request.page      = math.max(tonumber(request.page) or 1,1)
            request.size      = img.check_size(request.size)
            request.object    = iv[request.object] == variables.yes
            request["repeat"] = iv[request["repeat"]] == variables.yes
            request.preview   = iv[request.preview] == variables.yes
            request.cache     = request.cache  ~= "" and request.cache
            request.prefix    = request.prefix ~= "" and request.prefix
            request.format    = request.format ~= "" and request.format
        --  request.width     = (w and w > 0) or false
        --  request.height    = (h and h > 0) or false
            table.merge(figuredata.request,request)
        end
        callstack[#callstack+1] = figuredata
        return figuredata
    end
    function figures.pop()
        figuredata = callstack[#callstack]
        callstack[#callstack] = nil
        statistics.stoptiming(figures)
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

end

local function register(askedname,specification)
    if specification then
        local format = specification.format
        if format then
            local converter = figures.converters[format]
            if converter then
                local oldname = specification.fullname
                local newformat = "pdf" -- todo, other target than pdf
                local newpath = file.dirname(oldname)
                local newbase = file.replacesuffix(file.basename(oldname),newformat)
                local fc = specification.cache or figures.cachepaths.path
                if fc and fc ~= "" and fc ~= "." then
                    newpath = fc
                end
                local subpath = specification.subpath or figures.cachepaths.subpath
                if subpath and subpath ~= "" and subpath ~= "."  then
                    newpath = newpath .. "/" .. subpath
                end
                local prefix = specification.prefix or figures.cachepaths.prefix
                if prefix and prefix ~= "" then
                    newbase = prefix .. newbase
                end
                local newname = file.join(newpath,newbase)
                dir.makedirs(newpath)
                local oldtime = lfs.attributes(oldname,'modification') or 0
                local newtime = lfs.attributes(newname,'modification') or 0
                if oldtime > newtime then
                    converter(oldname,newname)
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
    figures.found[askedname] = specification
    return specification
end

local function locate(request) -- name, format, cache
    local askedname = resolvers.clean_path(request.name)
    local foundname = figures.found[askedname]
    if foundname then
        return foundname
    end
    -- protocol check
    local hashed = url.hashed(askedname)
    if hashed and hashed.scheme ~= "file" then
        local foundname = resolvers.findbinfile(askedname)
        if foundname then
            askedname = foundname
        end
    end
    -- we could use the hashed data instead
    local askedpath= file.is_rootbased_path(askedname)
    local askedbase = file.basename(askedname)
    local askedformat = (request.format ~= "" and request.format ~= "unknown" and request.format) or file.extname(askedname) or ""
    local askedcache = request.cache
    if askedformat ~= "" then
        if trace_figures then
            commands.writestatus("figures","strategy: forced format")
        end
        askedformat = lower(askedformat)
        local format = figures.suffixes[askedformat]
        if not format then
            for _, pattern in ipairs(figures.patterns) do
                if find(askedformat,pattern[1]) then
                    format = pattern[2]
                    break
                end
            end
        end
        if format then
            local foundname = figures.exists(askedname,format) -- not askedformat
            if foundname then
                return register(askedname, {
                    askedname = askedname,
                    fullname = askedname,
                    format = format,
                    cache = askedcache,
                    foundname = foundname,
                })
            end
        end
        if askedpath then
            -- path and type given, todo: strip pieces of path
            if figures.exists(askedname,askedformat) then
                return register(askedname, {
                    askedname = askedname,
                    fullname = askedname,
                    format = askedformat,
                    cache = askedcache,
                })
            end
        else
            -- type given
            for _, path in ipairs(figures.paths) do
                local check = path .. "/" .. askedname
                if figures.exists(check,askedformat) then
                    return register(check, {
                        askedname = askedname,
                        fullname = check,
                        format = askedformat,
                        cache = askedcache,
                    })
                end
            end
            if figures.defaultsearch then
                local check = resolvers.find_file(askedname)
                if check and check ~= "" then
                    return register(askedname, {
                        askedname = askedname,
                        fullname = check,
                        format = askedformat,
                        cache = askedcache,
                    })
                end
            end
        end
    elseif askedpath then
        if trace_figures then
            commands.writestatus("figures","strategy: rootbased path")
        end
        for _, format in ipairs(figures.order) do
            local list = figures.formats[format].list or { format }
            for _, suffix in ipairs(list) do
                local check = file.addsuffix(askedname,suffix)
                if figures.exists(check,format) then
                    return register(askedname, {
                        askedname = askedname,
                        fullname = check,
                        format = format,
                        cache = askedcache,
                    })
                end
            end
        end
    else
        if figures.prefer_quality then
            if trace_figures then
                commands.writestatus("figures","strategy: unknown format, prefer quality")
            end
            for _, format in ipairs(figures.order) do
                local list = figures.formats[format].list or { format }
                for _, suffix in ipairs(list) do
--~                     local name = file.replacesuffix(askedbase,suffix)
                    local name = file.replacesuffix(askedname,suffix)
                    for _, path in ipairs(figures.paths) do
                        local check = path .. "/" .. name
                        if figures.exists(check,format) then
                            return register(askedname, {
                                askedname = askedname,
                                fullname = check,
                                format = format,
                                cache = askedcache,
                            })
                        end
                    end
                end
            end
        else -- 'location'
            if trace_figures then
                commands.writestatus("figures","strategy: unknown format, prefer path")
            end
            for _, path in ipairs(figures.paths) do
                for _, format in ipairs(figures.order) do
                    local list = figures.formats[format].list or { format }
                    for _, suffix in ipairs(list) do
                        local check = path .. "/" .. file.replacesuffix(askedbase,suffix)
                        if figures.exists(check,format) then
                            return register(askedname, {
                                askedname = askedname,
                                fullname = check,
                                format = format,
                                cache = askedcache,
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
            for _, format in ipairs(figures.order) do
                local list = figures.formats[format].list or { format }
                for _, suffix in ipairs(list) do
                    local check = resolvers.find_file(file.replacesuffix(askedname,suffix))
                    if check and check ~= "" then
                        return register(askedname, {
                            askedname = askedname,
                            fullname = check,
                            format = format,
                            cache = askedcache,
                        })
                    end
                end
            end
        end
    end
    return register(askedname)
end

-- -- -- plugins -- -- --

figures.existers    = figures.existers    or { }
figures.checkers    = figures.checkers    or { }
figures.includers   = figures.includers   or { }
figures.converters  = figures.converters  or { }
figures.identifiers = figures.identifiers or { }

figures.identifiers.list = {
    figures.identifiers.default
}

function figures.identifiers.default(data)
    local dr, du, ds = data.request, data.used, data.status
    local l = locate(dr)
    local foundname = l.foundname
    local fullname = l.fullname or foundname
    if fullname then
        du.format = l.format or false
        du.fullname = fullname -- can be cached
        ds.fullname = foundname -- original
        ds.format = l.format
        ds.status = (l.found and 10) or 0
    end
    return data
end

function figures.identify(data)
    data = data or figures.current()
    for _, identifier in ipairs(figures.identifiers.list) do
        data = identifier(data)
        if data.status.status > 0 then
            break
        end
    end
    return data
end
function figures.exists(askedname,format)
    return (figures.existers[format] or figures.existers.generic)(askedname)
end
function figures.check(data)
    data = data or figures.current()
    local dr, du, ds = data.request, data.used, data.status
    return (figures.checkers[ds.format] or figures.checkers.generic)(data)
end
function figures.include(data)
    data = data or figures.current()
    local dr, du, ds = data.request, data.used, data.status
    return (figures.includers[ds.format] or figures.includers.generic)(data)
end
function figures.scale(data) -- will become lua code
    texsprint(ctxcatcodes,"\\doscalefigure")
    return data
end
function figures.done(data)
    figures.n = figures.n + 1
    data = data or figures.current()
    local dr, du, ds = data.request, data.used, data.status
    ds.width = tex.wd[figures.boxnumber]
    ds.height = tex.ht[figures.boxnumber]
    ds.xscale = ds.width/(du.width or 1)
    ds.yscale = ds.height/(du.height or 1)
    return data
end

function figures.dummy(data)
--~         data = data or figures.current()
--~         local dr, du, ds = data.request, data.used, data.status
--~         local r = node.new("rule")
--~         r.width  = du.width  or figures.defaultwidth
--~         r.height = du.height or figures.defaultheight
--~         r.depth  = du.depth  or figures.defaultdepth
--~         tex.box[figures.boxnumber] = node.hpack(node.write(r))
    texsprint(ctxcatcodes,"\\emptyfoundexternalfigure")
end

-- -- -- generic -- -- --

function figures.existers.generic(askedname,resolve)
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
function figures.checkers.generic(data)
    local dr, du, ds = data.request, data.used, data.status
    local name, page, size, color = du.fullname or "unknown generic", du.page or dr.page, dr.size or "crop", dr.color or "natural"
    local hash = name .. "->" .. page .. "->" .. size .. "->" .. color
    local figure = figures.loaded[hash]
    if figure == nil then
        figure = img.new { filename = name, page = page, pagebox = dr.size }
        backends.codeinjections.setfigurecolorspace(data,figure)
        figure = (figure and img.scan(figure)) or false
        local f, d = backends.codeinjections.setfigurealternative(data,figure)
        figure, data = f or figure, d or data
        figures.loaded[hash] = figure
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
function figures.includers.generic(data)
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
        local n = figures.boxnumber
        -- it looks like we have a leak in attributes here .. todo
        tex.box[n] = node.hpack(img.node(figure))
     -- tex.box[n] = img.node(figure) -- img.write(figure) -- assigning img.node directly no longer valid
        tex.wd[n], tex.ht[n], tex.dp[n] = figure.width, figure.height, 0 -- new, hm, tricky, we need to do that in tex (yet)
        ds.objectnumber = figure.objnum
        texsprint(ctxcatcodes,"\\relocateexternalfigure")
    end
    return data
end

-- -- -- nongeneric -- -- --

function figures.checkers.nongeneric(data,command)
    local dr, du, ds = data.request, data.used, data.status
    local name = du.fullname or "unknown nongeneric"
    local hash = name
    if dr.object then
        -- hm, bugged
        if not jobobjects.get("FIG::"..hash) then
            texsprint(ctxcatcodes,command)
            texsprint(ctxcatcodes,format("\\setobject{FIG}{%s}\\vbox{\\box\\foundexternalfigure}",hash))
        end
        texsprint(ctxcatcodes,format("\\global\\setbox\\foundexternalfigure\\vbox{\\getobject{FIG}{%s}}",hash))
    else
        texsprint(ctxcatcodes,command)
    end
    return data
end
function figures.includers.nongeneric(data)
    return data
end

-- -- -- mov -- -- --

function figures.checkers.mov(data)
    local dr, du, ds = data.request, data.used, data.status
    dr.width = (dr.width or figures.defaultwidth):todimen()
    dr.height = (dr.height or figures.defaultheight):todimen()
    du.width = dr.width
    du.height = dr.height
    du.foundname = du.fullname
    local code = backends.codeinjections.insertmovie {
        width      = du.width or dr.width,
        height     = du.height or dr.height,
        factor     = number.dimenfactors.bp,
        ["repeat"] = dr["repeat"],
        controls   = dr.controls,
        preview    = dr.preview,
        label      = dr.label,
        foundname  = du.foundname,
    }
    texsprint(ctxcatcodes,format("\\startfoundexternalfigure{%ssp}{%ssp}%s\\stopfoundexternalfigure",du.width,du.height,code))
    return data
end

figures.includers.mov = figures.includers.nongeneric

-- -- -- mps -- -- --

local function internal(askedname)
    local spec, mprun, mpnum = match(lower(askedname),"mprun(:?)(.-)%.(%d+)")
    if spec == ":" then
        return mprun, mpnum
    else
        return "", mpnum
    end
end

function figures.existers.mps(askedname)
    local mprun, mpnum = internal(askedname)
    if mpnum then
        return askedname
    else
        return figures.existers.generic(askedname)
    end
end
function figures.checkers.mps(data)
    local mprun, mpnum = internal(data.used.fullname)
    if mpnum then
        return figures.checkers.nongeneric(data,format("\\docheckfiguremprun{%s}{%s}",mprun,mpnum))
    else
        return figures.checkers.nongeneric(data,format("\\docheckfiguremps{%s}",data.used.fullname))
    end
end
figures.includers.mps = figures.includers.nongeneric

-- -- -- buffer -- -- --

function figures.existers.buffer(askedname)
    askedname = file.nameonly(askedname)
    return buffers.exists(askedname) and askedname
end
function figures.checkers.buffer(data)
    return figures.checkers.nongeneric(data,format("\\docheckfigurebuffer{%s}", file.nameonly(data.used.fullname)))
end
figures.includers.buffers = figures.includers.nongeneric

-- -- -- tex -- -- --

function figures.existers.tex(askedname)
    askedname = resolvers.find_file(askedname)
    return (askedname ~= "" and askedname) or false
end
function figures.checkers.tex(data)
    return figures.checkers.nongeneric(data,format("\\docheckfiguretex{%s}", data.used.fullname))
end
figures.includers.tex = figures.includers.nongeneric

-- -- -- eps -- -- --

function figures.converters.eps(oldname,newname)
    -- hack, we need a lua based converter script, or better, we should use
    -- rlx as alternative
    local outputpath = file.dirname(newname)
    local outputbase = file.basename(newname)
    if outputpath == "" then outputpath = "." end
    local command = format("mtxrun bin:pstopdf --outputpath=%s %s",outputpath,oldname)
    os.spawn(command)
end

figures.converters.svg = figures.converters.eps

function figures.converters.gif(oldname,newname)
    -- hack, we need a lua based converter script, or better, we should use
    -- rlx as alternative
    local command = format("mtxrun bin:convert %s %s",oldname,newname)
    os.spawn(command)
end

-- -- -- lowres -- -- --

--~ function figures.converters.pdf(oldname,newname)
--~     local outputpath = file.dirname(newname)
--~     local outputbase = file.basename(newname)
--~     local command = format("mtxrun bin:pstopdf --method=4 --outputpath=%s %s",outputpath,oldname)
--~     os.spawn(command)
--~ end

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
            for _, path in ipairs(figures.paths) do
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
    for _, entry in ipairs(bases.list) do
        local t = bases.find(entry[1],askedlabel)
        if t then
            return t
        end
    end
    return false
end

function figures.identifiers.base(data)
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

figures.identifiers.list = {
    figures.identifiers.base,
    figures.identifiers.default
}

-- tracing

statistics.register("graphics processing time", function()
    local n = figures.n
    if n > 0 then
        return format("%s seconds including tex, n=%s", statistics.elapsedtime(figures),n)
    else
        return nil
    end
end)

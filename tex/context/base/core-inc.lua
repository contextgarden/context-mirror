if not modules then modules = { } end modules ['core-inc'] = {
    version   = 1.001,
    comment   = "companion to core-inc.tex",
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

backends     = backends     or { }
backends.pdf = backends.pdf or { }

--~ function backends.pdf.startscaling(sx,sy)
--~     return nodes.pdfliteral(string.format("q %s 0 0 %s 0 0 cm",(sx ~= 0 and sx) or .0001,(sy ~= 0 and sy) or .0001))
--~ end
--~ function backends.pdf.stopscaling()
--~     return nodes.pdfliteral("%Q")
--~ end

function backends.pdf.insertmovie(data)
    data = data or figures.current()
    local dr, du, ds = data.request, data.used, data.status
    local width, height, factor = du.width or dr.width, du.height or dr.height, number.dimenfactors.bp
    local options, actions = "", ""
    if dr["repeat"] then
        actions = actions .. "/Mode /Repeat "
    end
    if dr.controls then
        actions = actions .. "/ShowControls true "
    else
        actions = actions .. "/ShowControls false "
    end
    if dr.preview then
        options = options .. "/Poster true "
    end
    if actions ~= "" then
        actions= "/A <<" .. actions .. ">>"
    end
    tex.sprint(tex.ctxcatcodes, string.format(
        "\\doPDFannotation{%ssp}{%ssp}{/Subtype /Movie /Border [0 0 0] /T (movie %s) /Movie << /F (%s) /Aspect [%s %s] %s>> %s}",
        width, height, dr.label, du.foundname, factor * width, factor * height, options, actions
    ))
    return data
end

--~ if node then do
--~     local n = node.new(0,0)
--~     local m = getmetatable(n)
--~     m.__concat = function(a,b)
--~         local t = node.slide(a)
--~         t.next, b.prev = b, t
--~         return a
--~     end
--~     node.free(n)
--~ end end

--- some extra img functions ---

function img.totable(i)
    local t = { }
    for _, v in ipairs(img.keys()) do
        t[v] = i[v]
    end
    return t
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

figures               = figures          or { }
figures.loaded        = figures.loaded   or { }
figures.used          = figures.used     or { }
figures.found         = figures.found    or { }
figures.suffixes      = figures.suffixes or { }
figures.patterns      = figures.patterns or { }
figures.boxnumber     = figures.boxid    or 0
figures.trace         = false
figures.defaultsearch = true
figures.defaultwidth  = 0
figures.defaultheight = 0
figures.defaultdepth  = 0
figures.n             = 0

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
    "pdf", "mps", "jpg", "png", "jbig", "svg", "eps", "mov", "buffer", "tex"
}

figures.formats = {
    ["pdf"]    = { },
    ["mps"]    = { patterns = { "%d+" } },
    ["jpg"]    = { list = { "jpg", "jpeg" } },
    ["png"]    = { } ,
    ["jbig"]   = { list = { "jbig", "jbig2", "jb2" } },
    ["svg"]    = { list = { "svg", "svgz" } },
    ["eps"]    = { list = { "eps", "ai" } },
    ["mov"]    = { list = { "mov", "avi" } },
    ["buffer"] = { list = { "tmp", "buffer", "buf" } },
    ["tex"]    = { },
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
    local data = figures.formats[target]
    if data then
        local d = data[tag]
        if d and not table.contains(d,what) then
            d[#d+1] = what
        else
            data[tag] = { what }
        end
    else
        figures.formats[target] = { }
    end
    figures.setlookups()
end

function figures.registersuffix (suffix, target) register('list',   target,suffix ) end
function figures.registerpattern(pattern,target) register('pattern',target,pattern) end

local pathhash = { }

function figures.setpaths(locationset,pathlist)
    local ph, iv, t = pathhash[locationset], interfaces.variables, nil
    if ph then
        ph = ph[pathlist]
        if ph then
            figures.paths = ph
            return
        end
    end
    if not ph then
        ph = { }
        pathhash[locationset] = ph
    end
    local h = locationset:tohash()
    t = (h[iv["local"]] and figures.localpaths) or { }
    if h[iv["global"]] then
        for s in pathlist:gmatch("([^, ]+)") do
            t[#t+1] = s
        end
    end
    figures.defaultsearch = h[iv["default"]]
    ph[pathlist] = t
    figures.paths = t
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
    return data.status.fullname .. "+".. (data.request.page or 1) -- img is still not perfect
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
        input.starttiming(figures)
        local figuredata = figures.new()
        if request then
            local iv = interfaces.variables
            local w, h = tonumber(request.width), tonumber(request.height)
            request.page      = math.max(tonumber(request.page) or 1,1)
            request.size      = img.check_size(request.size)
            request.object    = iv[request.object] == "yes"
            request["repeat"] = iv[request["repeat"]] == "yes"
            request.preview   = iv[request.preview] == "yes"
            request.cache     = request.cache  ~= "" and request.cache
            request.prefix    = request.prefix ~= "" and request.prefix
            request.format    = request.format ~= "" and request.format
            request.width     = (w and w > 0) or false
            request.height    = (h and h > 0) or false
            table.merge(figuredata.request,request)
        end
        callstack[#callstack+1] = figuredata
        return figuredata
    end
    function figures.pop()
        figuredata = callstack[#callstack]
        callstack[#callstack] = nil
        input.stoptiming(figures)
    end
    -- maybe move tex.sprint to tex
    function figures.get(category,tag,default)
        local value = figuredata[category][tag]
        if not value or value == "" or value == true then
            return default or ""
        else
            return value
        end
    end
    function figures.tprint(category,tag,default)
        tex.sprint(tex.ctxcatcodes,figures.get(category,tag,default))
    end
    function figures.current()
        return callstack[#callstack]
    end

end

do

    local function register(askedname,specification)
        if specification then
            local format = specification.format
            if format then
                local converter = figures.converters[format]
                if converter then
                    local oldname = specification.fullname
                    local newpath = file.dirname(oldname)
                    local newbase = file.replacesuffix(file.basename(oldname),"pdf") -- todo
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
                    elseif exists(oldname) then
                        specification.fullname  = newname
                        specification.converted = false
                    end
                end
            end
            specification.found = true -- ?
        else
            specification = { }
        end
        specification.foundname = specification.foundname or specification.fullname
        figures.found[askedname] = specification
        return specification
    end

    local function locate(request) -- name, format, cache
        local askedname = input.clean_path(request.name)
        if figures.found[askedname] then
            return figures.found[askedname]
        end
        local askedpath= file.dirname(askedname)
        local askedbase = file.basename(askedname)
        local askedformat = (request.format ~= "" and request.format ~= "unknown" and request.format) or file.extname(askedname)
        local askedcache = request.cache
        if askedformat ~= "" then
            askedformat = askedformat:lower()
            local format = figures.suffixes[askedformat]
            if not format then
                for _, pattern in ipairs(figures.patterns) do
                    if askedformat:find(pattern[1]) then
                        format = pattern[2]
                        break
                    end
                end
            end
            if format then
                local foundname = figures.exists(askedname,askedformat)
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
            if askedpath ~= "" then
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
                    if figures.exists(askedname,askedformat) then
                        return register(check, {
                            askedname = askedname,
                            fullname = check,
                            format = askedformat,
                            cache = askedcache,
                        })
                    end
                end
                if figures.defaultsearch then
                    local check = input.find_file(texmf.instance,askedname)
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
        elseif askedpath ~= "" then
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
            for _, format in ipairs(figures.order) do
                local list = figures.formats[format].list or { format }
                for _, suffix in ipairs(list) do
                    local name = file.replacesuffix(askedbase,suffix)
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
                    if figures.defaultsearch then
                        local check = input.find_file(texmf.instance,file.replacesuffix(askedname,suffix))
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
        tex.sprint(tex.ctxcatcodes,"\\doscalefigure")
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

    function figures.dummy(data) -- fails
--~         data = data or figures.current()
--~         local dr, du, ds = data.request, data.used, data.status
--~         local r = node.new("rule")
--~         r.width  = du.width  or figures.defaultwidth
--~         r.height = du.height or figures.defaultheight
--~         r.depth  = du.depth  or figures.defaultdepth
--~         tex.box[figures.boxnumber] = node.write(r)
        tex.sprint(tex.ctxcatcodes,"\\emptyfoundexternalfigure")
    end

end

-- -- -- generic -- -- --

function figures.existers.generic(askedname)
--~     local result = io.exists(askedname)
--~     result = (result==true and askedname) or result
--~     local result = input.find_file(texmf.instance,askedname) or ""
    local result = input.findbinfile(texmf.instance,askedname) or ""
    if result == "" then result = false end
    if figures.trace then
        if result then
            logs.report("figures", "found:" .. askedname .. " ->" .. result)
        else
            logs.report("figures", "not found:" .. askedname)
        end
    end
    return result
end
function figures.checkers.generic(data)
    local dr, du, ds = data.request, data.used, data.status
    local name, page, size = du.fullname or "unknown generic", dr.page, dr.size or "crop"
    local hash = name .. "->" .. page .. "->" .. size
    local figure = figures.loaded[hash]
    if figure == nil then
        figure = img.new { filename = name, page = page, pagebox = dr.size }
        figure = (figure and img.scan(figure)) or false
        figures.loaded[hash] = figure
    end
    if figure then
        du.width = figure.width
        du.height = figure.height
        du.pages = figure.pages
        ds.private = figure
    end
    return data
end
function figures.includers.generic(data)
    local dr, du, ds = data.request, data.used, data.status
    dr.width = dr.width or du.width
    dr.height = dr.height or du.height
    local hash = figures.hash(data)
    local figure = figures.used[hash]
    if figure == nil then
        figure = ds.private
        if figure then
--~ figure.page = dr.page or '1'
            figure = img.copy(figure)
            figure = (figure and img.clone(figure,data.request)) or false
        end
        figures.used[hash] = figure
    end
    if figure then
        local n = figures.boxnumber
        tex.box[n] = img.node(figure) -- img.write(figure)
        tex.wd[n], tex.ht[n], tex.dp[n] = figure.width, figure.height, 0 -- new, hm, tricky, we need to do that in tex (yet)
        ds.objectnumber = figure.objnum
        tex.sprint(tex.ctxcatcodes,"\\relocateexternalfigure")
    end
    return data
end

-- -- -- nongeneric -- -- --

function figures.checkers.nongeneric(data,command)
    local dr, du, ds = data.request, data.used, data.status
    local name = du.fullname or "unknown nongeneric"
    local hash = name
    if dr.object then
        if not job.objects["FIG::"..hash] then
            tex.sprint(tex.ctxcatcodes,command)
            tex.sprint(tex.ctxcatcodes,string.format("\\setobject{FIG}{%s}\\vbox{\\box\\foundexternalfigure}",hash))
        end
        tex.sprint(tex.ctxcatcodes,string.format("\\global\\setbox\\foundexternalfigure\\vbox{\\getobject{FIG}{%s}}",hash))
    else
        tex.sprint(tex.ctxcatcodes,command)
    end
    return data
end
function figures.includers.nongeneric(data)
    return data
end

-- -- -- mov -- -- --

function figures.checkers.mov(data)
    local dr, du, ds = data.request, data.used, data.status
    du.width = dr.width or figures.defaultwidth
    du.height = dr.height or figures.defaultheight
    du.foundname = du.fullname
    tex.sprint(tex.ctxcatcodes,string.format("\\startfoundexternalfigure{%ssp}{%ssp}",du.width,du.height))
    data = backends.pdf.insertmovie(data)
    tex.sprint(tex.ctxcatcodes,"\\stopfoundexternalfigure")
    return data
end
figures.includers.mov = figures.includers.nongeneric

-- -- -- mps -- -- --

function figures.checkers.mps(data)
    return figures.checkers.nongeneric(data,string.format("\\docheckfiguremps{%s}",data.used.fullname))
end
figures.includers.mps = figures.includers.nongeneric

-- -- -- buffer -- -- --

function figures.existers.buffer(askedname)
    askedname = file.nameonly(askedname)
    return buffers.exists(askedname) and askedname
end
function figures.checkers.buffer(data)
    return figures.checkers.nongeneric(data,string.format("\\docheckfigurebuffer{%s}", file.nameonly(data.used.fullname)))
end
figures.includers.buffers = figures.includers.nongeneric

-- -- -- tex -- -- --

function figures.existers.tex(askedname)
    askedname = input.find_file(texmf.instance,askedname)
    return (askedname ~= "" and askedname) or false
end
function figures.checkers.tex(data)
    return figures.checkers.nongeneric(data,string.format("\\docheckfiguretex{%s}", data.used.fullname))
end
figures.includers.tex = figures.includers.nongeneric

-- -- -- eps -- -- --

function figures.converters.eps(oldname,newname)
    -- hack, we need a lua based converter script, or better, we should use
    -- rlx as alternative
    local outputpath = file.dirname(newname)
    local outputbase = file.basename(newname)
    local command = string.format("mtxrun bin:pstopdf --outputpath=%s %s",outputpath,oldname)
    os.spawn(command)
end

figures.converters.svg = figures.converters.eps

-- -- -- lowres -- -- --

--~ function figures.converters.pdf(oldname,newname)
--~     local outputpath = file.dirname(newname)
--~     local outputbase = file.basename(newname)
--~     local command = string.format("mtxrun bin:pstopdf --method=4 --outputpath=%s %s",outputpath,oldname)
--~     os.spawn(command)
--~ end


figures.bases         = { }
figures.bases.list    = { } -- index      => { basename, fullname, xmlroot }
figures.bases.used    = { } -- [basename] => { basename, fullname, xmlroot } -- pointer to list
figures.bases.found   = { }
figures.bases.enabled = false

function figures.bases.use(basename)
    if basename == "reset" then
        figures.bases.list = { }
        figures.bases.used = { }
        figures.bases.found = { }
        figures.bases.enabled = false
    else
        basename = file.addsuffix(basename,"xml")
        if not figures.bases.used[basename] then
            local t = { basename, nil, nil }
            figures.bases.used[basename] = t
            figures.bases.list[#figures.bases.list+1] = t
            if not figures.bases.enabled then
                figures.bases.enabled = true
                xml.registerns("rlx","http://www.pragma-ade.com/schemas/rlx") -- we should be able to do this per xml file
            end
        end
    end
end

function figures.bases.find(basename,askedlabel)
    basename = file.addsuffix(basename,"xml")
    local t = figures.bases.found[askedlabel]
    if t == nil then
        local base = figures.bases.used[basename]
        local page = 0
        if base[2] == nil then
            -- no yet located
            for _, path in ipairs(figures.paths) do
                local xmlfile = path .. "/" .. basename
                if io.exists(xmlfile) then
                    base[2] = xmlfile
                    base[3] = xml.load(xmlfile)
                    break
                end
            end
        end
        t = false
        if base[2] and base[3] then
            for e, d, k in xml.elements(base[3],"/(*:library|figurelibrary)/*:figure/*:label") do
                page = page + 1
                if xml.content(d[k]) == askedlabel then
                    t = {
                        base = file.replacesuffix(base[2],"pdf"),
                        format = "pdf",
                        name = xml.filters.text(e,"*:file"),
                        page = page,
                    }
                    figures.bases.found[askedlabel] = t
                    break
                end
            end
        end
        figures.bases.found[askedlabel] = t
    end
    return t
end

-- we can access sequential or by name

function figures.bases.locate(askedlabel)
    for _, entry in ipairs(figures.bases.list) do
        local t = figures.bases.find(entry[1],askedlabel)
        if t then
            return t
        end
    end
    return false
end

function figures.identifiers.base(data)
    if figures.bases.enabled then
        local dr, du, ds = data.request, data.used, data.status
        local fbl = figures.bases.locate(dr.name or dr.label)
        if fbl then
            du.page = fbl.page
            du.format = fbl.format
            du.fullname = fbl.base
            ds.fullname = fbl.name
            ds.format = fbl.format
            ds.status = 10
        end
    end
    return data
end

figures.identifiers.list = {
    figures.identifiers.base,
    figures.identifiers.default
}

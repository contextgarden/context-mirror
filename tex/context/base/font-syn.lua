if not modules then modules = { } end modules ['font-syn'] = {
    version   = 1.001,
    comment   = "companion to font-ini.tex",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

--[[ldx--
<p>This module implements a name to filename resolver. Names are resolved
using a table that has keys filtered from the font related files.</p>
--ldx]]--

fonts = fonts or { }
input = input or { }
texmf = texmf or { }

fonts.names            = { }
fonts.names.filters    = { }
fonts.names.data       = { }
fonts.names.version    = 1.04
fonts.names.saved      = false
fonts.names.loaded     = false
fonts.names.be_clever  = true
fonts.names.enabled    = true
fonts.names.cache      = containers.define("fonts","data",fonts.names.version,true)

--[[ldx--
<p>It would make sense to implement the filters in the related modules,
but to keep the overview, we define them here.</p>
--ldx]]--

fonts.names.filters.otf = fontforge.info
fonts.names.filters.ttf = fontforge.info
fonts.names.filters.ttc = fontforge.info

function fonts.names.filters.afm(name)
    local f = io.open(name)
    if f then
        local hash = { }
        for line in f:lines() do
            local key, value = line:match("^(.+)%s+(.+)%s*$")
            if key and #key > 0 then
                hash[key:lower()] = value
            end
            if line:find("StartCharMetrics") then
                break
            end
        end
        f:close()
        return hash
    else
        return nil
    end
end

function fonts.names.filters.pfb(name)
    return fontforge.info(name)
end

--[[ldx--
<p>The scanner loops over the filters using the information stored in
the file databases. Watch how we check not only for the names, but also
for combination with the weight of a font.</p>
--ldx]]--

fonts.names.filters.list = {
    "otf", "ttf", "ttc", "afm" -- pfb is quite messy, too many messages, maybe broken
}

fonts.names.filters.fixes = {
    { "reg$", "regular", },
    { "ita$", "italic", },
    { "ital$", "italic", },
    { "cond$", "condensed", },
}

--~ todo
--~
--~ function getosfontdirs()
--~     local hash, result = { }, { }
--~     local function collect(t)
--~         for _, v in ipairs(t) do
--~             v = input.clean_path(v)
--~             v = v:gsub("/+$","")
--~             local key = v:lower()
--~             if not hash[key] then
--~                 hash[key], result[#result+1] = true, v
--~             end
--~         end
--~     end
--~     collect(input.expanded_path_list(instance,"osfontdir"))
--~     local name = input.find_file(instance,"fonts.conf","other")
--~     if name ~= "" then
--~         local root = xml.load(name)
--~         collect(xml.all_texts(root,"dir",true))
--~     end
--~     return result
--~ end


function fonts.names.identify()
    fonts.names.data = {
        mapping = { },
        version = fonts.names.version
    }
    local done, mapping, nofread, nofok = { }, fonts.names.data.mapping, 0, 0
    local function add(n,fontname,filename,suffix, sub)
        n = n:lower()
        if not mapping[n] then mapping[n], nofok = { suffix, fontname, filename, sub }, nofok + 1 end
        n = n:gsub("[^%a%d]","")
        if not mapping[n] then mapping[n], nofok = { suffix, fontname, filename, sub }, nofok + 1 end
    end
    local function check(result, filename, suffix, is_sub)
        local fontname = result.fullname
        if fontname then
            add(result.fullname, fontname, filename, suffix, is_sub)
        end
        if result.fontname then
            fontname = fontname or result.fontname
            add(result.fontname, fontname, filename, suffix, is_sub)
        end
        if result.familyname and result.weight then
            local madename = result.familyname .. " " .. result.weight
            fontname = fontname or madename
            add(madename, fontname, filename, suffix, is_sub)
        end
    end
    local function identify(completename,name,suffix)
        if not done[name] then
            nofread = nofread + 1
            logs.info("fontnames", "identifying " .. suffix .. " font " .. completename)
            logs.push()
            local result = fonts.names.filters[suffix](completename)
            logs.pop()
            if result then
                if not result[1] then
                    check(result,name,suffix,false)
                else for _, r in ipairs(result) do
                    check(r,name,suffix,true)
                end end
            end
            done[name] = true
        end
    end
    local function traverse(what, method)
        for n, suffix in pairs(fonts.names.filters.list) do
            nofread, nofok  = 0, 0
            local t = os.clock() -- use elapser
            logs.report("fontnames", string.format("identifying %s font files with suffix %s",what,suffix))
            method(suffix)
            logs.report("fontnames", string.format("%s %s files identified, %s hash entries added, runtime %s seconds", nofread, what,nofok, os.clock()-t))
        end
    end
    traverse("tree", function(suffix)
        input.with_files(texmf.instance,".*%." .. suffix .. "$", function(method,root,path,name)
            if method == "file" then
                identify(root .."/" .. path .. "/" .. name,name,suffix)
            end
        end)
    end)
    traverse("system", function(suffix)
        local pathlist = input.expanded_path_list(texmf.instance,"osfontdir")
        if pathlist then
            for _, path in ipairs(pathlist) do
                -- not that much needed
                path = input.clean_path(path .. "/")
                path = path:gsub("/+","/")
                local pattern = path .. "*." .. suffix
                logs.info("fontnames", "globbing path " .. pattern)
                local t = dir.glob(pattern)
                for _, name in pairs(t) do -- ipairs
                    local mode = lfs.attributes(name,'mode')
                    if mode == "file" then
                        identify(name,file.basename(name),suffix)
                    end
                end
            end
        end
    end)
    local t = { }
    for _, f in ipairs(fonts.names.filters.fixes) do
        local expression, replacement = f[1], f[2]
        for k,v in pairs(mapping) do
            local fix, pos = k:gsub(expression,replacement)
            if pos > 0 and not mapping[fix] then
                t[fix] = v
            end
        end
    end
    for k,v in pairs(t) do
        mapping[k] = v
    end
end

function fonts.names.load(reload)
    if not fonts.names.loaded then
        if reload then
            if containers.is_usable(fonts.names.cache, "names") then
                fonts.names.identify()
                containers.write(fonts.names.cache, "names", fonts.names.data)
            end
            fonts.names.saved = true
        else
            fonts.names.data = containers.read(fonts.names.cache, "names")
            if not fonts.names.saved then
                if table.is_empty(fonts.names.data) or table.is_empty(fonts.names.data.mapping) then
                    fonts.names.load(true)
                end
                fonts.names.saved = true
            end
        end
        fonts.names.loaded = true
    end
end

function fonts.names.list(pattern,reload)
    fonts.names.load(reload)
    if fonts.names.loaded then
        local t = { }
        for k,v in pairs(fonts.names.data.mapping) do
            if k:find(pattern) then
                t[k] = v
            end
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

do

    local function found(name)
        if fonts.names.data then
            local result, mapping = nil, fonts.names.data.mapping
            local mn = mapping[name]
            if mn then
                return mn[2], mn[3], mn[4]
            end
            if fonts.names.be_clever then -- this will become obsolete
                local encoding, tag = name:match("^(.-)[%-%:](.+)$")
                local mt = mapping[tag]
                if tag and fonts.enc.is_known(encoding) and mt then
                    return mt[1], encoding .. "-" .. mt[3], mt[4]
                end
            end
            -- name, type, file
            for k,v in pairs(mapping) do
                if k:find(name) then
                    return v[2], v[3], v[4]
                end
            end
            local condensed = name:gsub("[^%a%d]","")
            local mc = mapping[condensed]
            if mc then
                return mc[2], mc[3], mc[4]
            end
            for k,v in pairs(mapping) do
                if k:find(condensed) then
                    return v[2], v[3], v[4]
                end
            end
        end
        return nil, nil, nil
    end

    function fonts.names.resolve(name, sub)
        if not name then
            return nil, nil
        elseif fonts.names.enabled then
            fonts.names.load()
            local name, filename, is_sub = found(name:lower())
            if is_sub then
                return filename, name
            else
                return filename, sub
            end
        else
            return filename, sub
        end
    end

end

--[[ldx--
<p>A handy helper.</p>
--ldx]]--

function fonts.names.table(pattern,reload,all)
    local t = fonts.names.list(pattern,reload)
    if t then
        tex.sprint(tex.ctxcatcodes,"\\start\\nonknuthmode\\starttabulate[|T|T|T|T|T|]")
        tex.sprint(tex.ctxcatcodes,"\\NC hashname\\NC type\\NC fontname\\NC filename\\NC\\NR\\HL")
        for k,v in pairs(table.sortedkeys(t)) do
            if all or v == t[v][2]:lower() then
                local type, name, file = unpack(t[v])
                if type and name and file then
                    tex.sprint(tex.ctxcatcodes,string.format("\\NC %s\\NC %s\\NC %s\\NC %s\\NC\\NR",v,type, name, file))
                else
                    logs.report("font table", "skipping ".. v)
                end
            end
        end
        tex.sprint(tex.ctxcatcodes,"\\stoptabulate\\stop")
    end
end

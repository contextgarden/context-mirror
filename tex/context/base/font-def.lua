if not modules then modules = { } end modules ['font-def'] = {
    version   = 1.001,
    comment   = "companion to font-ini.tex",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- check reuse of lmroman1o-regular vs lmr10

local texsprint, count, dimen, format, concat = tex.sprint, tex.count, tex.dimen, string.format, table.concat

--[[ldx--
<p>Here we deal with defining fonts. We do so by intercepting the
default loader that only handles <l n='tfm'/>.</p>
--ldx]]--

fonts        = fonts        or { }
fonts.define = fonts.define or { }
fonts.tfm    = fonts.tfm    or { }
fonts.vf     = fonts.vf     or { }
fonts.used   = fonts.used   or { }

local tfm = fonts.tfm
local vf  = fonts.vf

tfm.version = 1.01
tfm.cache   = containers.define("fonts", "tfm", tfm.version, false) -- better in font-tfm

--[[ldx--
<p>Choosing a font by name and specififying its size is only part of the
game. In order to prevent complex commands, <l n='xetex'/> introduced
a method to pass feature information as part of the font name. At the
risk of introducing nasty parsing and compatinility problems, this
syntax was expanded over time.</p>

<p>For the sake of users who have defined fonts using that syntax, we
will support it, but we will provide additional methods as well.
Normally users will not use this direct way, but use a more abstract
interface.</p>
 --ldx]]--

--~ name, kind, features = fonts.features.split_xetex("blabla / B : + lnum ; foo = bar ; - whatever ; whow ; + hans ; test = yes")

fonts.define.method        = 3 -- 1: tfm  2: tfm and if not then afm  3: afm and if not then tfm
fonts.define.auto_afm      = true
fonts.define.auto_otf      = true
fonts.define.specify       = fonts.define.specify or { }
fonts.define.methods       = fonts.define.methods or { }

tfm.fonts            = tfm.fonts        or { }
tfm.readers          = tfm.readers      or { }
tfm.internalized     = tfm.internalized or { } -- internal tex numbers
tfm.id               = tfm.id           or { } -- font data, maybe use just fonts.ids (faster lookup)

tfm.readers.sequence = { 'otf', 'ttf', 'afm', 'tfm' }

--[[ldx--
<p>We hardly gain anything when we cache the final (pre scaled)
<l n='tfm'/> table. But it can be handy for debugging.</p>
--ldx]]--

fonts.version = 1.05
fonts.cache   = containers.define("fonts", "def", fonts.version, false)

--[[ldx--
<p>We can prefix a font specification by <type>name:</type> or
<type>file:</type>. The first case will result in a lookup in the
synonym table.</p>

<typing>
[ name: | file: ] identifier [ separator [ specification ] ]
</typing>

<p>The following function split the font specification into components
and prepares a table that will move along as we proceed.</p>
--ldx]]--

-- beware, we discard additional specs
--
-- method:name method:name(sub) method:name(sub)*spec method:name*spec
-- name name(sub) name(sub)*spec name*spec
-- name@spec*oeps

local splitter, specifiers = nil, ""

function fonts.define.add_specifier(symbol)
    specifiers = specifiers .. symbol
    local left          = lpeg.P("(")
    local right         = lpeg.P(")")
    local colon         = lpeg.P(":")
    local method        = lpeg.S(specifiers)
    local lookup        = lpeg.C(lpeg.P("file")+lpeg.P("name")) * colon -- hard test, else problems with : method
    local sub           = left * lpeg.C(lpeg.P(1-left-right-method)^1) * right
    local specification = lpeg.C(method) * lpeg.C(lpeg.P(1-method)^1)
    local name          = lpeg.C((1-sub-specification)^1)
    splitter = lpeg.P((lookup + lpeg.Cc("")) * name * (sub + lpeg.Cc("")) * (specification + lpeg.Cc("")))
end

function fonts.define.get_specification(str)
    return splitter:match(str)
end

function fonts.define.register_split(symbol,action)
    fonts.define.add_specifier(symbol)
    fonts.define.specify[symbol] = action
end

function fonts.define.makespecification(specification, lookup, name, sub, method, detail, size)
    size = size or 655360
    if fonts.trace then
        logs.report("define font","%s -> lookup: %s, name: %s, sub: %s, method: %s, detail: %s",
            specification, (lookup ~= "" and lookup) or "[file]", (name ~= "" and name) or "-",
            (sub ~= "" and sub) or "-", (method ~= "" and method) or "-", (detail ~= "" and detail) or "-")
    end
    if lookup ~= 'name' then -- for the moment only two lookups, maybe some day also system:
        lookup = 'file'
    end
    local t = {
        lookup        = lookup,        -- forced type
        specification = specification, -- full specification
        size          = size,          -- size in scaled points or -1000*n
        name          = name,          -- font or filename
        sub           = sub,           -- subfont (eg in ttc)
        method        = method,        -- specification method
        detail        = detail,        -- specification
        resolved      = "",            -- resolved font name
        forced        = "",            -- forced loader
        features      = { },           -- preprocessed features
    }
    return t
end

function fonts.define.analyze(specification, size)
    local lookup, name, sub, method, detail = fonts.define.get_specification(specification or "")
    return fonts.define.makespecification(specification,lookup, name, sub, method, detail, size)
end

--[[ldx--
<p>A unique hash value is generated by:</p>
--ldx]]--

function tfm.hash_features(specification)
    local features = specification.features
    if features then
        local t = { }
        local normal = features.normal
        if normal and next(normal) then
            local f = table.sortedhashkeys(normal)
            for i=1,#f do
                local v = f[i]
                if v ~= "number" then
                    t[#t+1] = v .. '=' .. tostring(normal[v])
                end
            end
        end
        local vtf = features.vtf
        if vtf and next(vtf) then
            local f = table.sortedhashkeys(vtf)
            for i=1,#f do
                local v = f[i]
                t[#t+1] = v .. '=' .. tostring(vtf[v])
            end
        end
        if #t > 0 then
            return concat(t,"+")
        end
    end
    return "unknown"
end

fonts.designsizes = { }

--[[ldx--
<p>In principle we can share tfm tables when we are in node for a font, but then
we need to define a font switch as an id/attr switch which is no fun, so in that
case users can best use dynamic features ... so, we will not use that speedup. Okay,
when we get rid of base mode we can optimize even further by sharing, but then we
loose our testcases for <l n='luatex'/>.</p>
--ldx]]--

function tfm.hash_instance(specification,force)
    local hash, size, fallbacks = specification.hash, specification.size, specification.fallbacks
    if force or not hash then
        hash = tfm.hash_features(specification)
        specification.hash = hash
    end
    if size < 1000 and fonts.designsizes[hash] then
        size = math.round(tfm.scaled(size, fonts.designsizes[hash]))
        specification.size = size
    end
    if fallbacks then
        return hash .. ' @ ' .. tostring(size) .. ' @ ' .. fallbacks
    else
        return hash .. ' @ ' .. tostring(size)
    end
end

--[[ldx--
<p>We can resolve the filename using the next function:</p>
--ldx]]--

function fonts.define.resolve(specification)
    if not specification.resolved or specification.resolved == "" then -- resolved itself not per se in mapping hash
        if specification.lookup == 'name' then
            specification.resolved, specification.sub = fonts.names.resolve(specification.name,specification.sub)
            if specification.resolved then
                specification.forced = file.extname(specification.resolved)
                specification.name = file.removesuffix(specification.resolved)
            end
        elseif specification.lookup == 'file' then
            specification.forced = file.extname(specification.name)
            specification.name = file.removesuffix(specification.name)
        end
    end
    if specification.forced == "" then
        specification.forced = nil
    else
        specification.forced = specification.forced
    end
    specification.hash = specification.name .. ' @ ' .. tfm.hash_features(specification)
    if specification.sub and specification.sub ~= "" then
        specification.hash = specification.sub .. ' @ ' .. specification.hash
    end
    return specification
end

--[[ldx--
<p>The main read function either uses a forced reader (as determined by
a lookup) or tries to resolve the name using the list of readers.</p>

<p>We need to cache when possible. We do cache raw tfm data (from <l
n='tfm'/>, <l n='afm'/> or <l n='otf'/>). After that we can cache based
on specificstion (name) and size, that is, <l n='tex'/> only needs a number
for an already loaded fonts. However, it may make sense to cache fonts
before they're scaled as well (store <l n='tfm'/>'s with applied methods
and features). However, there may be a relation between the size and
features (esp in virtual fonts) so let's not do that now.</p>

<p>Watch out, here we do load a font, but we don't prepare the
specification yet.</p>
--ldx]]--

function tfm.read(specification)
--~     input.starttiming(fonts)
    local hash = tfm.hash_instance(specification)
    local tfmtable = tfm.fonts[hash] -- hashes by size !
    if not tfmtable then
        if specification.forced and specification.forced ~= "" then
            tfmtable = tfm.readers[specification.forced:lower()](specification)
            if not tfmtable then
                logs.report("define font","forced type %s of %s not found",specification.forced,specification.name)
            end
        else
            for _, reader in ipairs(tfm.readers.sequence) do
                if tfm.readers[reader] then -- not really needed
                    if fonts.trace then
                        logs.report("define font","trying type %s for %s with file %s",reader,specification.name,specification.filename or "unknown")
                    end
                    tfmtable = tfm.readers[reader](specification)
                    if tfmtable then break end
                end
            end
        end
        if tfmtable then
            if tfmtable.filename and fonts.dontembed[tfmtable.filename] then
                tfmtable.embedding = "no"
            else
                tfmtable.embedding = "subset"
            end
            tfm.fonts[hash] = tfmtable
            fonts.designsizes[specification.hash] = tfmtable.designsize -- we only know this for sure after loading once
        --~ tfmtable.mode = specification.features.normal.mode or "base"
        end
    end
--~     input.stoptiming(fonts)
    if not tfmtable then
        logs.report("define font","font with name %s is not found",specification.name)
    end
    return tfmtable
end

--[[ldx--
<p>For virtual fonts we need a slightly different approach:</p>
--ldx]]--

function tfm.read_and_define(name,size) -- no id
    local specification = fonts.define.analyze(name,size)
    local method = specification.method
    if method and fonts.define.specify[method] then
        specification = fonts.define.specify[method](specification)
    end
    specification = fonts.define.resolve(specification)
    local hash = tfm.hash_instance(specification)
    local id = fonts.define.registered(hash)
    if not id then
        local fontdata = tfm.read(specification)
        if fontdata then
            fontdata.hash = hash
            id = font.define(fontdata)
            fonts.define.register(fontdata,id)
tfm.cleanup_table(fontdata)
        else
            id = 0  -- signal
        end
    end
    return tfm.id[id], id
end

--[[ldx--
<p>Next follow the readers. This code was written while <l n='luatex'/>
evolved. Each one has its own way of dealing with its format.</p>
--ldx]]--

function tfm.readers.opentype(specification,suffix,what)
    if fonts.define.auto_otf then
        local fullname, tfmtable = nil, nil
        fullname = input.findbinfile(specification.name,suffix) or ""
        if fullname == "" then
            local fb = fonts.names.old_to_new[specification.name]
            if fb then
                fullname = input.findbinfile(fb,suffix) or ""
            end
        end
        if fullname == "" then
            local fb = fonts.names.new_to_old[specification.name]
            if fb then
                fullname = input.findbinfile(fb,suffix) or ""
            end
        end
        if fullname ~= "" then
            specification.filename, specification.format = fullname, what -- hm, so we do set the filename, then
            tfmtable = tfm.read_from_open_type(specification)       -- we need to do it for all matches / todo
        end
        return tfmtable
    else
        return nil
    end
end

function tfm.readers.otf(specification) return tfm.readers.opentype(specification,"otf","opentype") end
function tfm.readers.ttf(specification) return tfm.readers.opentype(specification,"ttf","truetype") end
function tfm.readers.ttc(specification) return tfm.readers.opentype(specification,"ttf","truetype") end -- !!

function tfm.readers.afm(specification,method)
    local fullname, tfmtable = nil, nil
    method = method or fonts.define.method
    if method == 2 then
        fullname = input.findbinfile(specification.name,"ofm") or ""
        if fullname == "" then
            tfmtable = tfm.read_from_afm(specification)
        else -- redundant
            specification.filename = fullname
            tfmtable = tfm.read_from_tfm(specification)
        end
    elseif method == 3 then -- maybe also findbinfile here
        if fonts.define.auto_afm then
            tfmtable = tfm.read_from_afm(specification)
        end
    elseif method == 4 then -- maybe also findbinfile here
        tfmtable = tfm.read_from_afm(specification)
    end
    return tfmtable
end

function tfm.readers.tfm(specification)
    local fullname, tfmtable = nil, nil
    tfmtable = tfm.read_from_tfm(specification)
    return tfmtable
end

--[[ldx--
<p>So far we haven't really dealt with features (or whatever we want
to pass along with the font definition. We distinguish the following
situations:</p>
situations:</p>

<code>
name:xetex like specs
name@virtual font spec
name*context specification
</code>

<p>Of course one can always define more.</p>
--ldx]]--

function fonts.define.specify.predefined(specification)
    local detail = specification.detail
    if detail ~= "" then
    --  detail = detail:gsub("["..fonts.define.splitsymbols.."].*$","") -- get rid of *whatever specs and such
        if fonts.define.methods[detail] then                            -- since these may be appended at the
            specification.features.vtf = { preset = detail }            -- tex end by default
        end
    end
    return specification
end

fonts.define.register_split("@", fonts.define.specify.predefined)

function fonts.define.specify.colonized(specification) -- xetex mode
    local list = { }
    if specification.detail and specification.detail ~= "" then
        local expanded_features = { }
        local function expand(features)
            for _,v in pairs(features:split(";")) do --just gmatch
                expanded_features[#expanded_features+1] = v
            end
        end
        expand(specification.detail)
        for _,v in pairs(expanded_features) do
            local a, b = v:match("^%s*(%S+)%s*=%s*(%S+)%s*$")
            if a and b then
                list[a] = b:is_boolean()
                if type(list[a]) == "nil" then
                    list[a] = b
                end
            else
                local a, b = v:match("^%s*([%+%-]?)%s*(%S+)%s*$")
                if a and b then
                    list[b] = a ~= "-"
                end
            end
        end
    end
    specification.features.normal = list
    return specification
end

function tfm.make(specification)
    -- currently fonts are scaled while constructing the font, so we
    -- have to do scaling of commands in the vf at that point using
    -- e.g. "local scale = g.factor or 1" after all, we need to work
    -- with copies anyway and scaling needs to be done at some point;
    -- however, when virtual tricks are used as feature (makes more
    -- sense) we scale the commands in fonts.tfm.scale (and set the
    -- factor there)
    local fvm = fonts.define.methods[specification.features.vtf.preset]
    if fvm then
        return fvm(specification)
    else
        return nil
    end
end

fonts.define.register_split(":", fonts.define.specify.colonized)

fonts.define.specify.context_setups  = fonts.define.specify.context_setups  or { }
fonts.define.specify.context_numbers = fonts.define.specify.context_numbers or { }
fonts.define.specify.synonyms        = fonts.define.specify.synonyms        or { }

input.storage.register(false,"fonts/setups" , fonts.define.specify.context_setups , "fonts.define.specify.context_setups" )
input.storage.register(false,"fonts/numbers", fonts.define.specify.context_numbers, "fonts.define.specify.context_numbers")

fonts.triggers = fonts.triggers or { }

function fonts.define.specify.preset_context(name,parent,features)
    if features == "" then
        if parent:find("=") then
            features = parent
            parent = ""
        end
    end
    local fds = fonts.define.specify
    local setups, numbers, synonyms = fds.context_setups, fds.context_numbers, fds.synonyms
    local number = (setups[name] and setups[name].number) or 0
    local t = (features == "" and { }) or fonts.otf.meanings.normalize(aux.settings_to_hash(features))
    -- todo: synonyms, and not otf bound
    if parent ~= "" then
        for p in parent:gmatch("[^, ]+") do
            local s = setups[p]
            if s then
                for k,v in pairs(s) do
                    if t[k] == nil then
                        t[k] = v
                    end
                end
            end
        end
    end
    -- these are auto set so in order to prevent redundant definitions
    -- we need to preset them (we hash the features and adding a default
    -- setting during initialization may result in a different hash)
    local default = fonts.otf.features.default
    for k,v in pairs(fonts.triggers) do
        if type(t[v]) == "nil" then
            local vv = default[v]
            if vv then t[v] = vv end
        end
    end
    -- sparse 'm so that we get a better hash and less test (experimental
    -- optimization)
    local tt = { }
    for k,v in pairs(t) do
        if v then tt[k] = v end
    end
    -- needed for dynamic features
    if number == 0 then
        numbers[#numbers+1] = name
        tt.number = #numbers
    else
        tt.number = number
    end
    setups[name] = tt
end

do

    -- here we clone features according to languages

    local default = 0
    local setups  = fonts.define.specify.context_setups
    local numbers = fonts.define.specify.context_numbers

    function fonts.define.specify.context_number(name)
        local t = setups[name]
        if not t then
            return default
        elseif t.auto then
            local lng = tonumber(tex.language)
            local tag = name .. ":" .. lng
            local s = setups[tag]
            if s then
                return s.number or default
            else
                local script, language = languages.association(lng)
                if t.script ~= script or t.language ~= language then
                    local s = table.fastcopy(t)
                    local n = #numbers + 1
                    setups[tag] = s
                    numbers[n] = tag
                    s.number = n
                    s.script = script
                    s.language = language
                    return n
                else
                    setups[tag] = t
                    return t.number or default
                end
            end
        else
            return t.number or default
        end
    end

end

function fonts.define.specify.context_tostring(name,kind,separator,yes,no,strict,omit) -- not used
    return aux.hash_to_string(table.merged(fonts[kind].features.default or {},fonts.define.specify.context_setups[name] or {}),separator,yes,no,strict,omit)
end

function fonts.define.specify.split_context(features)
    if fonts.define.specify.context_setups[features] then
        return fonts.define.specify.context_setups[features]
    else -- ? ? ?
        return fonts.define.specify.preset_context("***",features)
    end
end

local splitter = lpeg.splitat(",")

function fonts.define.specify.starred(features) -- no longer fallbacks here
    local detail = features.detail
    if detail and detail ~= "" then
        features.features.normal = fonts.define.specify.split_context(detail)
    else
        features.features.normal = { }
    end
    return features
end

fonts.define.register_split('*',fonts.define.specify.starred)

--[[ldx--
<p>We need to check for default features. For this we provide
a helper function.</p>
--ldx]]--

function fonts.define.check(features,defaults) -- nb adapts features !
    local done = false
    if table.is_empty(features) then
        features, done = table.fastcopy(defaults), true
    else
        for k,v in pairs(defaults) do
            if features[k] == nil then
                features[k], done = v, true
            end
        end
    end
    return features, done -- done signals a change
end

--[[ldx--
<p>So far the specifyers. Now comes the real definer. Here we cache
based on id's. Here we also intercept the virtual font handler. Since
it evolved stepwise I may rewrite this bit (combine code).</p>

In the previously defined reader (the one resulting in a <l n='tfm'/>
table) we cached the (scaled) instances. Here we cache them again, but
this time based on id. We could combine this in one cache but this does
not gain much. By the way, passing id's back to in the callback was
introduced later in the development.</p>
--ldx]]--

fonts.define.last = nil

function fonts.define.register(fontdata,id)
    if fontdata and id then
        local hash = fontdata.hash
        if not tfm.internalized[hash] then
            if fonts.trace then
                logs.report("define font","loading at 2 id %s, hash: %s",id or "?",hash or "?")
            end
            tfm.id[id] = fontdata
            tfm.internalized[hash] = id
        end
    end
end

function fonts.define.registered(hash)
    local id = tfm.internalized[hash]
    return id, id and tfm.id[id]
end

local cache_them = false

function fonts.define.read(specification,size,id) -- id can be optional, name can already be table
    input.starttiming(fonts)
    if type(specification) == "string" then
        specification = fonts.define.analyze(specification,size)
    end
    local method = specification.method
    if method and fonts.define.specify[method] then
        specification = fonts.define.specify[method](specification)
    end
    specification = fonts.define.resolve(specification)
    local hash = tfm.hash_instance(specification)
    if cache_them then
        local fontdata = containers.read(fonts.cache(),hash) -- for tracing purposes
    end
    local fontdata = fonts.define.registered(hash) -- id
    if not fontdata then
        if specification.features.vtf and specification.features.vtf.preset then
            fontdata = tfm.make(specification)
        else
            fontdata = tfm.read(specification)
            if fontdata then
                tfm.check_virtual_id(fontdata)
            end
        end
        if cache_them then
            fontdata = containers.write(fonts.cache(),hash,fontdata) -- for tracing purposes
        end
        if fontdata then
            fontdata.hash = hash
            if id then
                fonts.define.register(fontdata,id)
            end
        end
    end
    fonts.define.last = fontdata or id -- todo ! ! ! ! !
    if not fontdata then
        logs.report("define font", "unknown font %s, loading aborted",specification.name)
    elseif fonts.trace and type(fontdata) == "table" then
        logs.report("define font","using %s font with id %s, n:%s s:%s b:%s e:%s p:%s f:%s",
            fontdata.type          or "unknown",
            id                     or "?",
            fontdata.name          or "?",
            fontdata.size          or "default",
            fontdata.encodingbytes or "?",
            fontdata.encodingname  or "unicode",
            fontdata.fullname      or "?",
            file.basename(fontdata.filename or "?"))
    end
    input.stoptiming(fonts)
    return fontdata
end

-- define (two steps)

local P, C, Cc = lpeg.P, lpeg.C, lpeg.Cc

local space        = P(" ")
local spaces       = space^0
local value        = C((1-space)^1)
local rest         = C(P(1)^0)
local scale_none   =               Cc(0)
local scale_at     = P("at")     * Cc(1) * spaces * value
local scale_sa     = P("sa")     * Cc(2) * spaces * value
local scale_mo     = P("mo")     * Cc(3) * spaces * value
local scale_scaled = P("scaled") * Cc(4) * spaces * value

local sizepattern  = spaces * (scale_at + scale_sa + scale_mo + scale_scaled + scale_none)
local splitpattern = spaces * value * spaces * rest

local specification --

function fonts.define.command_1(str)
    input.starttiming(fonts)
    local fullname, size = splitpattern:match(str)
    local lookup, name, sub, method, detail = fonts.define.get_specification(fullname)
    if not name then
        logs.report("define font","strange definition '%s'",str)
        texsprint(tex.ctxcatcodes,"\\glet\\somefontname\\defaultfontfile")
    elseif name == "unknown" then
        texsprint(tex.ctxcatcodes,"\\glet\\somefontname\\defaultfontfile")
    else
        texsprint(tex.ctxcatcodes,format("\\xdef\\somefontname{%s}",name))
    end
    -- we can also use a count for the size
    if size and size ~= "" then
        local mode, size = sizepattern:match(size)
        if size and mode then
            count.scaledfontmode = mode
            texsprint(tex.ctxcatcodes,format("\\def\\somefontsize{%s}",size))
        else
            count.scaledfontmode = 0
            texsprint(tex.ctxcatcodes,format("\\let\\somefontsize\\empty",size))
        end
    else
        count.scaledfontmode = 0
        texsprint(tex.ctxcatcodes,format("\\let\\somefontsize\\empty",size))
    end
    specification = fonts.define.makespecification(str,lookup,name,sub,method,detail,size)
end

function fonts.define.command_2(global,cs,name,size,classfeatures,fontfeatures,classfallbacks,fontfallbacks)
    local trace = fonts.trace
    -- name is now resolved and size is scaled cf sa/mo
    local lookup, name, sub, method, detail = fonts.define.get_specification(name or "")
    -- asome settings can be overloaded
    if lookup and lookup ~= "" then specification.lookup = lookup end
    specification.name = name
    specification.size = size
    specification.sub = sub
    if detail and detail ~= "" then
        specification.method, specification.detail = method or "*", detail
    elseif specification.detail and specification.detail ~= "" then
        -- already set
    elseif fontfeatures and fontfeatures ~= "" then
        specification.method, specification.detail = "*", fontfeatures
    elseif classfeatures and classfeatures ~= "" then
        specification.method, specification.detail = "*", classfeatures
    end
    if trace then
        logs.report("define font","memory usage before: %s",ctx.memused())
    end
if fontfallbacks and fontfallbacks ~= "" then
    specification.fallbacks = fontfallbacks
elseif classfallbacks and classfallbacks ~= "" then
    specification.fallbacks = classfallbacks
end
    local tfmdata = fonts.define.read(specification,size) -- id not yet known
    if not tfmdata then
        logs.report("define font","unable to define %s as \\%s",name,cs)
    elseif type(tfmdata) == "number" then
        if trace then
            logs.report("define font","reusing %s with id %s as \\%s (features: %s/%s, fallbacks: %s/%s)",name,tfmdata,cs,classfeatures,fontfeatures,classfallbacks,fontfallbacks)
        end
        tex.definefont(global,cs,tfmdata)
        -- resolved (when designsize is used):
        texsprint(tex.ctxcatcodes,format("\\def\\somefontsize{%isp}",tfm.id[tfmdata].size))
    else
    --  local t = os.clock(t)
        local id = font.define(tfmdata)
    --  print(name,os.clock()-t)
        tfmdata.id = id
        fonts.define.register(tfmdata,id)
        tex.definefont(global,cs,id)
        tfm.cleanup_table(tfmdata)
        if fonts.trace then
            logs.report("define font","defining %s with id %s as \\%s (features: %s/%s, fallbacks: %s/%s)",name,id,cs,classfeatures,fontfeatures,classfallbacks,fontfallbacks)
        end
        -- resolved (when designsize is used):
        texsprint(tex.ctxcatcodes,format("\\def\\somefontsize{%isp}",tfmdata.size))
    --~ if specification.fallbacks then
    --~     fonts.collections.prepare(specification.fallbacks)
    --~ end
    end
    if trace then
        logs.report("define font","memory usage after: %s",ctx.memused())
    end
    input.stoptiming(fonts)
end


--~ table.insert(tfm.readers.sequence,1,'vtf')

--~ function tfm.readers.vtf(specification)
--~     if specification.features.vtf and specification.features.vtf.preset then
--~         return tfm.make(specification)
--~     else
--~         return nil
--~     end
--~ end

function fonts.vf.find(name)
    name = file.removesuffix(file.basename(name))
    if tfm.resolve_vf then
        local format = fonts.logger.format(name)
        if format == 'tfm' or format == 'ofm' then
            if fonts.trace then
                logs.report("define font","locating vf for %s",name)
            end
            return input.findbinfile(name,"ovf")
        else
            if fonts.trace then
                logs.report("define font","vf for %s is already taken care of",name)
            end
            return nil -- ""
        end
    else
        if fonts.trace then
            logs.report("define font","locating vf for %s",name)
        end
        return input.findbinfile(name,"ovf")
    end
end

--[[ldx--
<p>We overload both the <l n='tfm'/> and <l n='vf'/> readers.</p>
--ldx]]--

callback.register('define_font' , fonts.define.read)
callback.register('find_vf_file', fonts.vf.find    ) -- not that relevant any more

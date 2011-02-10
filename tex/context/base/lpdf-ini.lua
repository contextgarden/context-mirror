if not modules then modules = { } end modules ['lpdf-ini'] = {
    version   = 1.001,
    comment   = "companion to lpdf-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local setmetatable, getmetatable, type, next, tostring, tonumber, rawset = setmetatable, getmetatable, type, next, tostring, tonumber, rawset
local char, byte, format, gsub, concat, match, sub, gmatch = string.char, string.byte, string.format, string.gsub, table.concat, string.match, string.sub, string.gmatch
local utfvalues = string.utfvalues
local texset = tex.set
local sind, cosd = math.sind, math.cosd
local lpegmatch = lpeg.match

--~ local pdfreserveobject   = pdf and pdf.reserveobj   or function() return 1 end -- for testing
--~ local pdfimmediateobject = pdf and pdf.immediateobj or function() return 2 end -- for testing

local pdfreserveobject   = pdf.reserveobj
local pdfimmediateobject = pdf.immediateobj
local pdfdeferredobject  = pdf.obj
local pdfreferenceobject = pdf.refobj

local trace_finalizers = false  trackers.register("backend.finalizers", function(v) trace_finalizers = v end)
local trace_resources  = false  trackers.register("backend.resources",  function(v) trace_resources  = v end)
local trace_objects    = false  trackers.register("backend.objects",    function(v) trace_objects    = v end)
local trace_detail     = false  trackers.register("backend.detail",     function(v) trace_detail     = v end)

local report_objects    = logs.reporter("backend","objects")
local report_finalizing = logs.reporter("backend","finalizing")

local backends, context = backends, context

backends.pdf = backends.pdf or {
    comment        = "backend for directly generating pdf output",
    nodeinjections = { },
    codeinjections = { },
    registrations  = { },
    tables         = { },
}

lpdf       = lpdf or { }
local lpdf = lpdf

local function tosixteen(str)
    if not str or str == "" then
        return "<feff>" -- not () as we want an indication that it's unicode
    else
        local r, n = { "<feff" }, 1
        for b in utfvalues(str) do
            n = n + 1
            if b < 0x10000 then
                r[n] = format("%04x",b)
            else
                r[n] = format("%04x%04x",b/1024+0xD800,b%1024+0xDC00)
            end
        end
        n = n + 1
        r[n] = ">"
        return concat(r)
    end
end

lpdf.tosixteen = tosixteen

-- lpeg is some 5 times faster than gsub (in test) on escaping

-- local escapes = {
--     ["\\"] = "\\\\",
--     ["/"] = "\\/", ["#"] = "\\#",
--     ["<"] = "\\<", [">"] = "\\>",
--     ["["] = "\\[", ["]"] = "\\]",
--     ["("] = "\\(", [")"] = "\\)",
-- }
--
-- local escaped = lpeg.Cs(lpeg.Cc("(") * (lpeg.S("\\/#<>[]()")/escapes + lpeg.P(1))^0 * lpeg.Cc(")"))
--
-- local function toeight(str)
--     if not str or str == "" then
--         return "()"
--     else
--         return lpegmatch(escaped,str)
--     end
-- end
--
-- -- no need for escaping .. just use unicode instead

-- \0 \t \n \r \f <space> ( ) [ ] { } / %

local function toeight(str)
    return "(" .. str .. ")"
end

lpdf.toeight = toeight

--~ local escaped = lpeg.Cs((lpeg.S("\0\t\n\r\f ()[]{}/%")/"#" + lpeg.P(1))^0)
--~
--~ local function cleaned(str)
--~     return (str and str ~= "" and lpegmatch(escaped,str)) or ""
--~ end
--~
--~ lpdf.cleaned = cleaned -- not public yet

local function merge_t(a,b)
    local t = { }
    for k,v in next, a do t[k] = v end
    for k,v in next, b do t[k] = v end
    return setmetatable(t,getmetatable(a))
end

local tostring_a, tostring_d

tostring_d = function(t,contentonly,key)
    if not next(t) then
        if contentonly then
            return ""
        else
            return "<< >>"
        end
    else
        local r, rn = { }, 0
        for k, v in next, t do
            rn = rn + 1
            local tv = type(v)
            if tv == "string" then
                r[rn] = format("/%s %s",k,toeight(v))
            elseif tv == "unicode" then
                r[rn] = format("/%s %s",k,tosixteen(v))
            elseif tv == "table" then
                local mv = getmetatable(v)
                if mv and mv.__lpdftype then
                    r[rn] = format("/%s %s",k,tostring(v))
                elseif v[1] then
                    r[rn] = format("/%s %s",k,tostring_a(v))
                else
                    r[rn] = format("/%s %s",k,tostring_d(v))
                end
            else
                r[rn] = format("/%s %s",k,tostring(v))
            end
        end
        if contentonly then
            return concat(r, " ")
        elseif key then
            return format("/%s << %s >>", key, concat(r, " "))
        else
            return format("<< %s >>", concat(r, " "))
        end
    end
end

tostring_a = function(t,contentonly,key)
    local tn = #t
    if tn == 0 then
        if contentonly then
            return ""
        else
            return "[ ]"
        end
    else
        local r = { }
        for k=1,tn do
            local v = t[k]
            local tv = type(v)
            if tv == "string" then
                r[k] = toeight(v)
            elseif tv == "unicode" then
                r[k] = tosixteen(v)
            elseif tv == "table" then
                local mv = getmetatable(v)
                local mt = mv and mv.__lpdftype
                if mt then
                    r[k] = tostring(v)
                elseif v[1] then
                    r[k] = tostring_a(v)
                else
                    r[k] = tostring_d(v)
                end
            else
                r[k] = tostring(v)
            end
        end
        if contentonly then
            return concat(r, " ")
        elseif key then
            return format("/%s [ %s ]", key, concat(r, " "))
        else
            return format("[ %s ]", concat(r, " "))
        end
    end
end

local tostring_x = function(t) return concat(t, " ")  end
local tostring_s = function(t) return toeight(t[1])   end
local tostring_u = function(t) return tosixteen(t[1]) end
local tostring_n = function(t) return tostring(t[1])  end -- tostring not needed
local tostring_c = function(t) return t[1]            end -- already prefixed (hashed)
local tostring_z = function()  return "null"          end
local tostring_t = function()  return "true"          end
local tostring_f = function()  return "false"         end
local tostring_r = function(t) local n = t[1] return n and n > 0 and (n .. " 0 R") or "NULL" end

local tostring_v = function(t)
    local s = t[1]
    if type(s) == "table" then
        return concat(s,"")
    else
        return s
    end
end

local function value_x(t)     return t                  end -- the call is experimental
local function value_s(t,key) return t[1]               end -- the call is experimental
local function value_u(t,key) return t[1]               end -- the call is experimental
local function value_n(t,key) return t[1]               end -- the call is experimental
local function value_c(t)     return sub(t[1],2)        end -- the call is experimental
local function value_d(t)     return tostring_d(t,true) end -- the call is experimental
local function value_a(t)     return tostring_a(t,true) end -- the call is experimental
local function value_z()      return nil                end -- the call is experimental
local function value_t(t)     return t.value or true    end -- the call is experimental
local function value_f(t)     return t.value or false   end -- the call is experimental
local function value_r()      return t[1] or 0          end -- the call is experimental -- NULL
local function value_v()      return t[1]               end -- the call is experimental

local function add_x(t,k,v) rawset(t,k,tostring(v)) end

local mt_x = { __lpdftype = "stream",     __tostring = tostring_x, __call = value_x, __newindex = add_x }
local mt_d = { __lpdftype = "dictionary", __tostring = tostring_d, __call = value_d }
local mt_a = { __lpdftype = "array",      __tostring = tostring_a, __call = value_a }
local mt_u = { __lpdftype = "unicode",    __tostring = tostring_u, __call = value_u }
local mt_s = { __lpdftype = "string",     __tostring = tostring_s, __call = value_s }
local mt_n = { __lpdftype = "number",     __tostring = tostring_n, __call = value_n }
local mt_c = { __lpdftype = "constant",   __tostring = tostring_c, __call = value_c }
local mt_z = { __lpdftype = "null",       __tostring = tostring_z, __call = value_z }
local mt_t = { __lpdftype = "true",       __tostring = tostring_t, __call = value_t }
local mt_f = { __lpdftype = "false",      __tostring = tostring_f, __call = value_f }
local mt_r = { __lpdftype = "reference",  __tostring = tostring_r, __call = value_r }
local mt_v = { __lpdftype = "verbose",    __tostring = tostring_v, __call = value_v }

local function pdfstream(t) -- we need to add attrbutes
    if t then
        for i=1,#t do
            t[i] = tostring(t[i])
        end
    end
    return setmetatable(t or { },mt_x)
end

local function pdfdictionary(t)
    return setmetatable(t or { },mt_d)
end

local function pdfarray(t)
    if type(t) == "string" then
        return setmetatable({ t },mt_a)
    else
        return setmetatable(t or { },mt_a)
    end
end

local function pdfstring(str,default)
    return setmetatable({ str or default or "" },mt_s)
end

local function pdfunicode(str,default)
    return setmetatable({ str or default or "" },mt_u)
end

local cache = { } -- can be weak

local function pdfnumber(n,default) -- 0-10
    n = n or default
    local c = cache[n]
    if not c then
        c = setmetatable({ n },mt_n)
    --  cache[n] = c -- too many numbers
    end
    return c
end

for i=-1,9 do cache[i] = pdfnumber(i) end

local cache = { } -- can be weak

local forbidden, replacements = "\0\t\n\r\f ()[]{}/%%#\\", { } -- table faster than function

for s in gmatch(forbidden,".") do
    replacements[s] = format("#%02x",byte(s))
end

local escaped = lpeg.Cs(lpeg.Cc("/") * (lpeg.S(forbidden)/replacements + lpeg.P(1))^0)

local function pdfconstant(str,default)
    str = str or default or ""
    local c = cache[str]
    if not c then
     -- c = setmetatable({ "/" .. str },mt_c)
        c = setmetatable({ lpegmatch(escaped,str) },mt_c)
        cache[str] = c
    end
    return c
end

local p_null  = { } setmetatable(p_null, mt_z)
local p_true  = { } setmetatable(p_true, mt_t)
local p_false = { } setmetatable(p_false,mt_f)

local function pdfnull()
    return p_null
end

--~ print(pdfboolean(false),pdfboolean(false,false),pdfboolean(false,true))
--~ print(pdfboolean(true),pdfboolean(true,false),pdfboolean(true,true))
--~ print(pdfboolean(nil,true),pdfboolean(nil,false))

local function pdfboolean(b,default)
    if type(b) == "boolean" then
        return b and p_true or p_false
    else
        return default and p_true or p_false
    end
end

local function pdfreference(r)
    return setmetatable({ r or 0 },mt_r)
end

local function pdfverbose(t) -- maybe check for type
    return setmetatable({ t or "" },mt_v)
end

lpdf.stream      = pdfstream -- THIS WILL PROBABLY CHANGE
lpdf.dictionary  = pdfdictionary
lpdf.array       = pdfarray
lpdf.string      = pdfstring
lpdf.unicode     = pdfunicode
lpdf.number      = pdfnumber
lpdf.constant    = pdfconstant
lpdf.null        = pdfnull
lpdf.boolean     = pdfboolean
lpdf.reference   = pdfreference
lpdf.verbose     = pdfverbose

-- n = pdf.obj(n, str)
-- n = pdf.obj(n, "file", filename)
-- n = pdf.obj(n, "stream", streamtext, attrtext)
-- n = pdf.obj(n, "streamfile", filename, attrtext)

-- we only use immediate objects

-- todo: tracing

local names, cache = { }, { }

function lpdf.reserveobject(name)
    if name == "annot" then
        -- catch misuse
        return pdfreserveobject("annot")
    else
        local r = pdfreserveobject()
        if name then
            names[name] = r
            if trace_objects then
                report_objects("reserving number %s under name '%s'",r,name)
            end
        elseif trace_objects then
            report_objects("reserving number %s",r)
        end
        return r
    end
end

function lpdf.reserveannotation()
    return pdfreserveobject("annot")
end

lpdf.immediateobject    = pdfimmediateobject
lpdf.object             = pdfdeferredobject          -- the table interface, todo: auto attr() and so
lpdf.deferredobject     = pdfdeferredobject
lpdf.referenceobject    = pdfreferenceobject
lpdf.pagereference      = pdf.pageref or tex.pdfpageref
lpdf.registerannotation = pdf.registerannot

function lpdf.delayedobject(data)
    local n = pdfdeferredobject(data)
    pdfreferenceobject(n)
    return n
end

function lpdf.flushobject(name,data)
    if data then
        name = names[name] or name
        if name then
            if trace_objects then
                if trace_detail then
                    report_objects("flushing data to reserved object with name '%s' -> %s",name,tostring(data))
                else
                    report_objects("flushing data to reserved object with name '%s'",name)
                end
            end
            return pdfimmediateobject(name,tostring(data))
        else
            if trace_objects then
                if trace_detail then
                    report_objects("flushing data to reserved object with number %s -> %s",name,tostring(data))
                else
                    report_objects("flushing data to reserved object with number %s",name)
                end
            end
            return pdfimmediateobject(tostring(data))
        end
    else
        if trace_objects and trace_detail then
            report_objects("flushing data -> %s",tostring(name))
        end
        return pdfimmediateobject(tostring(name))
    end
end

local shareobjectcache, shareobjectreferencecache = { }, { }

function lpdf.shareobject(content)
    content = tostring(content)
    local o = shareobjectcache[content]
    if not o then
        o = pdfimmediateobject(content)
        shareobjectcache[content] = o
    end
    return o
end

function lpdf.shareobjectreference(content)
    content = tostring(content)
    local r = shareobjectreferencecache[content]
    if not r then
        local o = shareobjectcache[content]
        if not o then
            o = pdfimmediateobject(content)
            shareobjectcache[content] = o
        end
        r = pdfreference(o)
        shareobjectreferencecache[content] = r
    end
    return r
end

--~ local d = lpdf.dictionary()
--~ local e = lpdf.dictionary { ["e"] = "abc", x = lpdf.dictionary { ["f"] = "ABC" }  }
--~ local f = lpdf.dictionary { ["f"] = "ABC" }
--~ local a = lpdf.array { lpdf.array { lpdf.string("xxx") } }

--~ print(a)
--~ os.exit()

--~ d["test"] = lpdf.string ("test")
--~ d["more"] = "more"
--~ d["bool"] = true
--~ d["numb"] = 1234
--~ d["oeps"] = lpdf.dictionary { ["hans"] = "ton" }
--~ d["whow"] = lpdf.array { lpdf.string("ton") }

--~ a[#a+1] = lpdf.string("xxx")
--~ a[#a+1] = lpdf.string("yyy")

--~ d.what = a

--~ print(e)

--~ local d = lpdf.dictionary()
--~ d["abcd"] = { 1, 2, 3, "test" }
--~ print(d)
--~ print(d())

--~ local d = lpdf.array()
--~ d[#d+1] = 1
--~ d[#d+1] = 2
--~ d[#d+1] = 3
--~ d[#d+1] = "test"
--~ print(d)

--~ local d = lpdf.array()
--~ d[#d+1] = { 1, 2, 3, "test" }
--~ print(d)

--~ local d = lpdf.array()
--~ d[#d+1] = { a=1, b=2, c=3, d="test" }
--~ print(d)

--~ local s = lpdf.constant("xx")
--~ print(s) -- fails somehow
--~ print(s()) -- fails somehow

--~ local s = lpdf.boolean(false)
--~ s.value = true
--~ print(s)
--~ print(s())

-- three priority levels, default=2

local pagefinalizers, documentfinalizers = { { }, { }, { } }, { { }, { }, { } }

local pageresources, pageattributes, pagesattributes

local function resetpageproperties()
    pageresources   = pdfdictionary()
    pageattributes  = pdfdictionary()
    pagesattributes = pdfdictionary()
end

resetpageproperties()

local function setpageproperties()
    pdf.pageresources   = pageresources  ()
    pdf.pageattributes  = pageattributes ()
    pdf.pagesattributes = pagesattributes()
end

local function addtopageresources  (k,v) pageresources  [k] = v end
local function addtopageattributes (k,v) pageattributes [k] = v end
local function addtopagesattributes(k,v) pagesattributes[k] = v end

lpdf.addtopageresources   = addtopageresources
lpdf.addtopageattributes  = addtopageattributes
lpdf.addtopagesattributes = addtopagesattributes

local function set(where,what,f,when,comment)
    if type(when) == "string" then
        when, comment = 2, when
    elseif not when then
        when = 2
    end
    local w = where[when]
    w[#w+1] = { f, comment }
    if trace_finalizers then
        report_finalizing("%s set: [%s,%s]",what,when,#w)
    end
end

local function run(where,what)
    if trace_finalizers then
        report_finalizing("start backend: category=%s, n=%s",what,#where)
    end
    for i=1,#where do
        local w = where[i]
        for j=1,#w do
            local wj = w[j]
            if trace_finalizers then
                report_finalizing("%s finalizer: [%s,%s] %s",what,i,j,wj[2] or "")
            end
            wj[1]()
        end
    end
    if trace_finalizers then
        report_finalizing("stop finalizing")
    end
end

local function registerpagefinalizer(f,when,comment)
    set(pagefinalizers,"page",f,when,comment)
end

local function registerdocumentfinalizer(f,when,comment)
    set(documentfinalizers,"document",f,when,comment)
end

lpdf.registerpagefinalizer     = registerpagefinalizer
lpdf.registerdocumentfinalizer = registerdocumentfinalizer

function lpdf.finalizepage()
    if not environment.initex then
     -- resetpageproperties() -- maybe better before
        run(pagefinalizers,"page")
        setpageproperties()
        resetpageproperties() -- maybe better before
    end
end

function lpdf.finalizedocument()
    if not environment.initex then
        run(documentfinalizers,"document")
        function lpdf.finalizedocument()
            report_finalizing("serious error: the document is finalized multiple times")
            function lpdf.finalizedocument() end
        end
    end
end

backends.pdf.codeinjections.finalizepage = lpdf.finalizepage      -- will go when we have hook

--~ callbacks.register("finish_pdfpage", lpdf.finalizepage)
callbacks.register("finish_pdffile", lpdf.finalizedocument)

-- some minimal tracing, handy for checking the order

local function trace_set(what,key)
    if trace_resources then
        report_finalizing("setting key '%s' in '%s'",key,what)
    end
end
local function trace_flush(what)
    if trace_resources then
        report_finalizing("flushing '%s'",what)
    end
end

lpdf.protectresources = true

local catalog = pdfdictionary { Type = pdfconstant("Catalog") } -- nicer, but when we assign we nil the Type
local info    = pdfdictionary { Type = pdfconstant("Info")    } -- nicer, but when we assign we nil the Type
local names   = pdfdictionary { Type = pdfconstant("Names")   } -- nicer, but when we assign we nil the Type

local function flushcatalog() if not environment.initex then trace_flush("catalog") catalog.Type = nil pdf.catalog = catalog() end end
local function flushinfo   () if not environment.initex then trace_flush("info")    info   .Type = nil pdf.info    = info   () end end
local function flushnames  () if not environment.initex then trace_flush("names")   names  .Type = nil pdf.names   = names  () end end

function lpdf.addtocatalog(k,v) if not (lpdf.protectresources and catalog[k]) then trace_set("catalog",k) catalog[k] = v end end
function lpdf.addtoinfo   (k,v) if not (lpdf.protectresources and info   [k]) then trace_set("info",   k) info   [k] = v end end
function lpdf.addtonames  (k,v) if not (lpdf.protectresources and names  [k]) then trace_set("names",  k) names  [k] = v end end

local dummy = pdfreserveobject() -- else bug in hvmd due so some internal luatex conflict

local r_extgstates,  d_extgstates  = pdfreserveobject(), pdfdictionary()  local p_extgstates  = pdfreference(r_extgstates)
local r_colorspaces, d_colorspaces = pdfreserveobject(), pdfdictionary()  local p_colorspaces = pdfreference(r_colorspaces)
local r_patterns,    d_patterns    = pdfreserveobject(), pdfdictionary()  local p_patterns    = pdfreference(r_patterns)
local r_shades,      d_shades      = pdfreserveobject(), pdfdictionary()  local p_shades      = pdfreference(r_shades)

local function checkextgstates () if next(d_extgstates ) then addtopageresources("ExtGState", p_extgstates ) end end
local function checkcolorspaces() if next(d_colorspaces) then addtopageresources("ColorSpace",p_colorspaces) end end
local function checkpatterns   () if next(d_patterns   ) then addtopageresources("Pattern",   p_patterns   ) end end
local function checkshades     () if next(d_shades     ) then addtopageresources("Shading",   p_shades     ) end end

local function flushextgstates () if next(d_extgstates ) then trace_flush("extgstates")  pdfimmediateobject(r_extgstates, tostring(d_extgstates )) end end
local function flushcolorspaces() if next(d_colorspaces) then trace_flush("colorspaces") pdfimmediateobject(r_colorspaces,tostring(d_colorspaces)) end end
local function flushpatterns   () if next(d_patterns   ) then trace_flush("patterns")    pdfimmediateobject(r_patterns,   tostring(d_patterns   )) end end
local function flushshades     () if next(d_shades     ) then trace_flush("shades")      pdfimmediateobject(r_shades,     tostring(d_shades     )) end end

local collected = pdfdictionary {
    ExtGState  = p_extgstates,
    ColorSpace = p_colorspaces,
    Pattern    = p_patterns,
    Shading    = p_shades,
} ; collected = collected()

function lpdf.collectedresources()
    context(collected)
end

function lpdf.adddocumentextgstate (k,v) d_extgstates [k] = v end
function lpdf.adddocumentcolorspace(k,v) d_colorspaces[k] = v end
function lpdf.adddocumentpattern   (k,v) d_patterns   [k] = v end
function lpdf.adddocumentshade     (k,v) d_shades     [k] = v end

registerdocumentfinalizer(flushextgstates,3,"extended graphic states")
registerdocumentfinalizer(flushcolorspaces,3,"color spaces")
registerdocumentfinalizer(flushpatterns,3,"patterns")
registerdocumentfinalizer(flushshades,3,"shades")

registerdocumentfinalizer(flushcatalog,3,"catalog")
registerdocumentfinalizer(flushinfo,3,"info")
registerdocumentfinalizer(flushnames,3,"names") -- before catalog

registerpagefinalizer(checkextgstates,3,"extended graphic states")
registerpagefinalizer(checkcolorspaces,3,"color spaces")
registerpagefinalizer(checkpatterns,3,"patterns")
registerpagefinalizer(checkshades,3,"shades")

-- in strc-bkm: lpdf.registerdocumentfinalizer(function() structures.bookmarks.place() end,1)

function lpdf.rotationcm(a)
    local s, c = sind(a), cosd(a)
    context("%s %s %s %s 0 0 cm",c,s,-s,c)
end

-- ! -> universaltime

local timestamp = os.date("%Y-%m-%dT%X") .. os.timezone(true)

function lpdf.timestamp()
    return timestamp
end

function lpdf.pdftimestamp(str)
    local Y, M, D, h, m, s, Zs, Zh, Zm = match(str,"^(%d%d%d%d)%-(%d%d)%-(%d%d)T(%d%d):(%d%d):(%d%d)([%+%-])(%d%d):(%d%d)$")
    return Y and format("D:%s%s%s%s%s%s%s%s'%s'",Y,M,D,h,m,s,Zs,Zh,Zm)
end

function lpdf.id()
    return format("%s.%s",tex.jobname,timestamp)
end

function lpdf.checkedkey(t,key,kind)
    local pn = t[key]
    if pn then
        local tn = type(pn)
        if tn == kind then
            if kind == "string" then
                return pn ~= "" and pn
            elseif kind == "table" then
                return next(pn) and pn
            else
                return pn
            end
        elseif tn == "string" and kind == "number" then
            return tonumber(pn)
        end
    end
end

function lpdf.checkedvalue(value,kind) -- code not shared
    if value then
        local tv = type(value)
        if tv == kind then
            if kind == "string" then
                return value ~= "" and value
            elseif kind == "table" then
                return next(value) and value
            else
                return value
            end
        elseif tv == "string" and kind == "number" then
            return tonumber(value)
        end
    end
end

function lpdf.limited(n,min,max,default)
    if not n then
        return default
    else
        n = tonumber(n)
        if not n then
            return default
        elseif n > max then
            return max
        elseif n < min then
            return min
        else
            return n
        end
    end
end

-- lpdf.addtoinfo("ConTeXt.Version", tex.contextversiontoks)
-- lpdf.addtoinfo("ConTeXt.Time",    os.date("%Y.%m.%d %H:%M")) -- :%S
-- lpdf.addtoinfo("ConTeXt.Jobname", tex.jobname)
-- lpdf.addtoinfo("ConTeXt.Url",     "www.pragma-ade.com")

if not pdfreferenceobject then

    local delayed = { }

    local function flush()
        local n = 0
        for k,v in next, delayed do
            pdfimmediateobject(k,v)
            n = n + 1
        end
        if trace_objects then
            report_objects("%s objects flushed",n)
        end
        delayed = { }
    end

    lpdf.registerdocumentfinalizer(flush,3,"objects") -- so we need a final flush too
    lpdf.registerpagefinalizer    (flush,3,"objects") -- somehow this lags behind .. I need to look into that some day

    function lpdf.delayedobject(data)
        local n = pdfreserveobject()
        delayed[n] = data
        return n
    end

end

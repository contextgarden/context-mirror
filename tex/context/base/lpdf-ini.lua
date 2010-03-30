if not modules then modules = { } end modules ['lpdf-ini'] = {
    version   = 1.001,
    comment   = "companion to lpdf-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- This code is very experimental !

local setmetatable, getmetatable, type, next, tostring, tonumber, rawset = setmetatable, getmetatable, type, next, tostring, tonumber, rawset
local char, byte, format, gsub, concat, match, sub = string.char, string.byte, string.format, string.gsub, table.concat, string.match, string.sub
local utfvalues = string.utfvalues
local texwrite, texset, texsprint, ctxcatcodes = tex.write, tex.set, tex.sprint, tex.ctxcatcodes
local sind, cosd = math.sind, math.cosd
local lpegmatch = lpeg.match

local pdfreserveobj   = pdf and pdf.reserveobj   or function() return 1 end -- for testing
local pdfimmediateobj = pdf and pdf.immediateobj or function() return 2 end -- for testing

local trace_finalizers = false  trackers.register("backend.finalizers", function(v) trace_finalizers = v end)
local trace_resources  = false  trackers.register("backend.resources",  function(v) trace_resources  = v end)
local trace_objects    = false  trackers.register("backend.objects",    function(v) trace_objects    = v end)
local trace_detail     = false  trackers.register("backend.detail",     function(v) trace_detail     = v end)

lpdf = lpdf or { }

local function tosixteen(str)
    if not str or str == "" then
        return "()"
    else
        local r = { "<feff" }
        for b in utfvalues(str) do
            if b < 0x10000 then
                r[#r+1] = format("%04x",b)
            else
                r[#r+1] = format("%04x%04x",b/1024+0xD800,b%1024+0xDC00)
            end
        end
        r[#r+1] = ">"
        return concat(r)
    end
end

lpdf.tosixteen = tosixteen

-- lpeg is some 5 times faster than gsub (in test) on escaping

local escapes = {
    ["\\"] = "\\\\",
    ["/"] = "\\/", ["#"] = "\\#",
    ["<"] = "\\<", [">"] = "\\>",
    ["["] = "\\[", ["]"] = "\\]",
    ["("] = "\\(", [")"] = "\\)",
}

local escaped = lpeg.Cs(lpeg.Cc("(") * (lpeg.S("\\/#<>[]()")/escapes + lpeg.P(1))^0 * lpeg.Cc(")"))

local function toeight(str)
 -- if not str or str == "" then
 --     return "()"
 -- else
 --     return lpegmatch(escaped,str)
 -- end
 --
 -- no need for escaping .. just use unicode instead
    return "(" .. str .. ")"
end

lpdf.toeight = toeight

local escapes = "-"

local escaped = lpeg.Cs(lpeg.Cc("(") * (lpeg.S("\\/#<>[]()")/escapes + lpeg.P(1))^0 * lpeg.Cc(")"))

local function cleaned(str)
    if not str or str == "" then
        return "()"
    else
        return lpegmatch(escaped,str)
    end
end

lpdf.cleaned = cleaned

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
        local r = { }
        for k, v in next, t do
            local tv = type(v)
            if tv == "string" then
                r[#r+1] = format("/%s %s",k,toeight(v))
            elseif tv == "unicode" then
                r[#r+1] = format("/%s %s",k,tosixteen(v))
            elseif tv == "table" then
                local mv = getmetatable(v)
                if mv and mv.__lpdftype then
                    r[#r+1] = format("/%s %s",k,tostring(v))
                elseif v[1] then
                    r[#r+1] = format("/%s %s",k,tostring_a(v))
                else
                    r[#r+1] = format("/%s %s",k,tostring_d(v))
                end
            else
                r[#r+1] = format("/%s %s",k,tostring(v))
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
    if #t == 0 then
        if contentonly then
            return ""
        else
            return "[ ]"
        end
    else
        local r = { }
        for k, v in next, t do
            local tv = type(v)
            if tv == "string" then
                r[#r+1] = toeight(v)
            elseif tv == "unicode" then
                r[#r+1] = tosixteen(v)
            elseif tv == "table" then
                local mv = getmetatable(v)
                local mt = mv and mv.__lpdftype
                if mt then
                    r[#r+1] = tostring(v)
                elseif v[1] then
                    r[#r+1] = tostring_a(v)
                else
                    r[#r+1] = tostring_d(v)
                end
            else
                r[#r+1] = tostring(v)
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
local tostring_r = function(t) return t[1] .. " 0 R"  end

local tostring_v = function(t)
    local s = t[1]
    if type(s) == "table" then
        return concat(s,"")
    else
        return s
    end
end

local function value_x(t)     return t                      end -- the call is experimental
local function value_s(t,key) return t[1]                   end -- the call is experimental
local function value_u(t,key) return t[1]                   end -- the call is experimental
local function value_n(t,key) return t[1]                   end -- the call is experimental
local function value_c(t)     return sub(t[1],2)            end -- the call is experimental
local function value_d(t)     return tostring_d(t,true,key) end -- the call is experimental
local function value_a(t)     return tostring_a(t,true,key) end -- the call is experimental
local function value_z()      return nil                    end -- the call is experimental
local function value_t(t)     return t.value or true        end -- the call is experimental
local function value_f(t)     return t.value or false       end -- the call is experimental
local function value_r()      return t[1]                   end -- the call is experimental
local function value_v()      return t[1]                   end -- the call is experimental

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

local function pdfconstant(str,default)
    str = str or default or ""
    local c = cache[str]
    if not c then
        c = setmetatable({ "/" .. str },mt_c)
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

local function pdfboolean(b,default)
    if ((type(b) == "boolean") and b) or default then
        return p_true
    else
        return p_false
    end
end

local function pdfreference(r)
    return setmetatable({ r or 0 },mt_r)
end

local function pdfverbose(t) -- maybe check for type
    return setmetatable({ t or "" },mt_v)
end

lpdf.stream      = pdfstream
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
    local r = pdfreserveobj()
    if name then
        names[name] = r
        if trace_objects then
            logs.report("backends", "reserving object number %s under name '%s'",r,name)
        end
    elseif trace_objects then
        logs.report("backends", "reserving object number %s",r)
    end
    return r
end

--~ local pdfreserveobject = lpdf.reserveobject

function lpdf.flushobject(name,data)
    if data then
        name = names[name] or name
        if name then
            if trace_objects then
                if trace_detail then
                    logs.report("backends", "flushing object data to reserved object with name '%s' -> %s",name,tostring(data))
                else
                    logs.report("backends", "flushing object data to reserved object with name '%s'",name)
                end
            end
            return pdfimmediateobj(name,tostring(data))
        else
            if trace_objects then
                if trace_detail then
                    logs.report("backends", "flushing object data to reserved object with number %s -> %s",name,tostring(data))
                else
                    logs.report("backends", "flushing object data to reserved object with number %s",name)
                end
            end
            return pdfimmediateobj(tostring(data))
        end
    else
        if trace_objects and trace_detail then
            logs.report("backends", "flushing object data -> %s",tostring(name))
        end
        return pdfimmediateobj(tostring(name))
    end
end

function lpdf.sharedobj(content)
    local r = cache[content]
    if not r then
        r = pdfreference(pdfimmediateobj(content))
        cache[content] = r
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

local function setpageproperties()
    texset("global", "pdfpageresources", pageresources  ())
    texset("global", "pdfpageattr",      pageattributes ())
    texset("global", "pdfpagesattr",     pagesattributes())
end

function lpdf.addtopageresources  (k,v) pageresources  [k] = v end
function lpdf.addtopageattributes (k,v) pageattributes [k] = v end
function lpdf.addtopagesattributes(k,v) pagesattributes[k] = v end

local function set(where,f,when,what)
    when = when or 2
    local w = where[when]
    w[#w+1] = f
    if trace_finalizers then
        logs.report("backend","%s set: [%s,%s]",what,when,#w)
    end
end

local function run(where,what)
    for i=1,#where do
        local w = where[i]
        for j=1,#w do
            if trace_finalizers then
                logs.report("backend","%s finalizer: [%s,%s]",what,i,j)
            end
            w[j]()
        end
    end
end

function lpdf.registerpagefinalizer(f,when)
    set(pagefinalizers,f,when,"page")
end

function lpdf.registerdocumentfinalizer(f,when)
    set(documentfinalizers,f,when,"document")
end

function lpdf.finalizepage()
    if not environment.initex then
        resetpageproperties()
        run(pagefinalizers,"page")
        setpageproperties()
    end
end

function lpdf.finalizedocument()
    if not environment.initex then
        run(documentfinalizers,"document")
        function lpdf.finalizedocument()
            logs.report("backend","serious error: the document is finalized multiple times")
            function lpdf.finalizedocument() end
        end
    end
end

-- some minimal tracing, handy for checking the order

local function trace_set(what,key)
    if trace_resources then
        logs.report("backend", "setting key '%s' in '%s'",key,what)
    end
end
local function trace_flush(what)
    if trace_resources then
        logs.report("backend", "flushing '%s'",what)
    end
end

local catalog, info, names = pdfdictionary(), pdfdictionary(), pdfdictionary()

local function flushcatalog() if not environment.initex then trace_flush("catalog") pdf.pdfcatalog = catalog() end end
local function flushinfo   () if not environment.initex then trace_flush("info")    pdf.pdfinfo    = info   () end end
local function flushnames  () if not environment.initex then trace_flush("names")   pdf.pdfnames   = names  () end end

if pdf and not pdf.pdfcatalog then

    local c_template, i_template, n_template = "\\normalpdfcatalog{%s}", "\\normalpdfinfo{%s}", "\\normalpdfnames{%s}"

    flushcatalog = function() if not environment.initex then texsprint(ctxcatcodes,format(c_template,catalog())) end end
    flushinfo    = function() if not environment.initex then texsprint(ctxcatcodes,format(i_template,info   ())) end end
    flushnames   = function() if not environment.initex then texsprint(ctxcatcodes,format(n_template,names  ())) end end

end

lpdf.protectresources = true

function lpdf.addtocatalog(k,v) if not (lpdf.protectresources and catalog[k]) then trace_set("catalog",k) catalog[k] = v end end
function lpdf.addtoinfo   (k,v) if not (lpdf.protectresources and info   [k]) then trace_set("info",   k) info   [k] = v end end
function lpdf.addtonames  (k,v) if not (lpdf.protectresources and names  [k]) then trace_set("names",  k) names  [k] = v end end

local dummy = pdfreserveobj() -- else bug in hvmd due so some internal luatex conflict

local r_extgstates,  d_extgstates  = pdfreserveobj(), pdfdictionary()  local p_extgstates  = pdfreference(r_extgstates)
local r_colorspaces, d_colorspaces = pdfreserveobj(), pdfdictionary()  local p_colorspaces = pdfreference(r_colorspaces)
local r_patterns,    d_patterns    = pdfreserveobj(), pdfdictionary()  local p_patterns    = pdfreference(r_patterns)
local r_shades,      d_shades      = pdfreserveobj(), pdfdictionary()  local p_shades      = pdfreference(r_shades)

local function checkextgstates () if next(d_extgstates ) then lpdf.addtopageresources("ExtGState", p_extgstates ) end end
local function checkcolorspaces() if next(d_colorspaces) then lpdf.addtopageresources("ColorSpace",p_colorspaces) end end
local function checkpatterns   () if next(d_patterns   ) then lpdf.addtopageresources("Pattern",   p_patterns   ) end end
local function checkshades     () if next(d_shades     ) then lpdf.addtopageresources("Shading",   p_shades     ) end end

local function flushextgstates () if next(d_extgstates ) then trace_flush("extgstates")  pdfimmediateobj(r_extgstates, tostring(d_extgstates )) end end
local function flushcolorspaces() if next(d_colorspaces) then trace_flush("colorspaces") pdfimmediateobj(r_colorspaces,tostring(d_colorspaces)) end end
local function flushpatterns   () if next(d_patterns   ) then trace_flush("patterns")    pdfimmediateobj(r_patterns,   tostring(d_patterns   )) end end
local function flushshades     () if next(d_shades     ) then trace_flush("shades")      pdfimmediateobj(r_shades,     tostring(d_shades     )) end end

local collected = pdfdictionary {
    ExtGState  = p_extgstates,
    ColorSpace = p_colorspaces,
    Pattern    = p_patterns,
    Shading    = p_shades,
} ; collected = collected()

function lpdf.collectedresources()
    tex.sprint(tex.ctxcatcodes,collected)
end

function lpdf.adddocumentextgstate (k,v) d_extgstates [k] = v end
function lpdf.adddocumentcolorspace(k,v) d_colorspaces[k] = v end
function lpdf.adddocumentpattern   (k,v) d_patterns   [k] = v end
function lpdf.adddocumentshade     (k,v) d_shades     [k] = v end

lpdf.registerdocumentfinalizer(flushextgstates,3)
lpdf.registerdocumentfinalizer(flushcolorspaces,3)
lpdf.registerdocumentfinalizer(flushpatterns,3)
lpdf.registerdocumentfinalizer(flushshades,3)

lpdf.registerdocumentfinalizer(flushcatalog,3)
lpdf.registerdocumentfinalizer(flushinfo,3)
lpdf.registerdocumentfinalizer(flushnames,3)

lpdf.registerpagefinalizer(checkextgstates,3)
lpdf.registerpagefinalizer(checkcolorspaces,3)
lpdf.registerpagefinalizer(checkpatterns,3)
lpdf.registerpagefinalizer(checkshades,3)

-- in strc-bkm: lpdf.registerdocumentfinalizer(function() structure.bookmarks.place() end,1)

function lpdf.rotationcm(a)
    local s, c = sind(a), cosd(a)
    texwrite(format("%s %s %s %s 0 0 cm",c,s,-s,c))
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

-- saves definitions later on

backends     = backends or { }
backends.pdf = backends.pdf or {
    comment        = "backend for directly generating pdf output",
    nodeinjections = { },
    codeinjections = { },
    registrations  = { },
    helpers        = { },
}

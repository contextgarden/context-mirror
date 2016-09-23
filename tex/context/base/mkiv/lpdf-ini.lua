if not modules then modules = { } end modules ['lpdf-ini'] = {
    version   = 1.001,
    comment   = "companion to lpdf-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- beware of "too many locals" here

local setmetatable, getmetatable, type, next, tostring, tonumber, rawset = setmetatable, getmetatable, type, next, tostring, tonumber, rawset
local char, byte, format, gsub, concat, match, sub, gmatch = string.char, string.byte, string.format, string.gsub, table.concat, string.match, string.sub, string.gmatch
local utfchar, utfbyte, utfvalues = utf.char, utf.byte, utf.values
local sind, cosd, floor, max, min = math.sind, math.cosd, math.floor, math.max, math.min
local sort = table.sort
local lpegmatch, P, C, R, S, Cc, Cs = lpeg.match, lpeg.P, lpeg.C, lpeg.R, lpeg.S, lpeg.Cc, lpeg.Cs
local formatters = string.formatters
local isboolean = string.is_boolean

local report_objects    = logs.reporter("backend","objects")
local report_finalizing = logs.reporter("backend","finalizing")
local report_blocked    = logs.reporter("backend","blocked")

local implement         = interfaces.implement
local two_strings       = interfaces.strings[2]

-- In ConTeXt MkIV we use utf8 exclusively so all strings get mapped onto a hex
-- encoded utf16 string type between <>. We could probably save some bytes by using
-- strings between () but then we end up with escaped ()\ too.

-- gethpos              : used
-- getpos               : used
-- getvpos              : used
--
-- getmatrix            : used
-- hasmatrix            : used
--
-- mapfile              : used in font-ctx.lua
-- mapline              : used in font-ctx.lua
--
-- maxobjnum            : not used
-- obj                  : used
-- immediateobj         : used
-- objtype              : not used
-- pageref              : used
-- print                : can be used
-- refobj               : used
-- registerannot        : not to be used
-- reserveobj           : used

-- pdf.catalog          : used
-- pdf.info             : used
-- pdf.trailer          : used
-- pdf.names            : not to be used

-- pdf.setinfo          : used
-- pdf.setcatalog       : used
-- pdf.setnames         : not to be used
-- pdf.settrailer       : used

-- pdf.getinfo          : used
-- pdf.getcatalog       : used
-- pdf.getnames         : not to be used
-- pdf.gettrailer       : used

local pdf    = pdf
local factor = number.dimenfactors.bp

do

    local texget = tex.get
    local texset = tex.set

    function pdf.setmajorversion (n) texset("global","pdfmajorversion", n) end
    function pdf.getmajorversion ( ) return texget("pdfmajorversion") end

end

local pdfsetinfo            = pdf.setinfo
local pdfsetcatalog         = pdf.setcatalog
----- pdfsetnames           = pdf.setnames
----- pdfsettrailer         = pdf.settrailer

local pdfsetpageresources   = pdf.setpageresources
local pdfsetpageattributes  = pdf.setpageattributes
local pdfsetpagesattributes = pdf.setpagesattributes

local pdfgetpos             = pdf.getpos
local pdfgethpos            = pdf.gethpos
local pdfgetvpos            = pdf.getvpos
local pdfgetmatrix          = pdf.getmatrix
local pdfhasmatrix          = pdf.hasmatrix

local pdfreserveobject      = pdf.reserveobj
local pdfimmediateobject    = pdf.immediateobj
local pdfdeferredobject     = pdf.obj
local pdfreferenceobject    = pdf.refobj

local function pdfdisablecommand(command)
    pdf[command] = function() report_blocked("'pdf.%s' is not supported",command) end
end

pdfdisablecommand("setinfo")
pdfdisablecommand("setcatalog")
pdfdisablecommand("setnames")
pdfdisablecommand("settrailer")
pdfdisablecommand("setpageresources")
pdfdisablecommand("setpageattributes")
pdfdisablecommand("setpagesattributes")
pdfdisablecommand("registerannot")

local trace_finalizers = false  trackers.register("backend.finalizers", function(v) trace_finalizers = v end)
local trace_resources  = false  trackers.register("backend.resources",  function(v) trace_resources  = v end)
local trace_objects    = false  trackers.register("backend.objects",    function(v) trace_objects    = v end)
local trace_detail     = false  trackers.register("backend.detail",     function(v) trace_detail     = v end)

local backends   = backends
local pdfbackend = {
    comment        = "backend for directly generating pdf output",
    nodeinjections = { },
    codeinjections = { },
    registrations  = { },
    tables         = { },
}
backends.pdf     = pdfbackend
lpdf             = lpdf or { }
local lpdf       = lpdf

local codeinjections = pdfbackend.codeinjections
local nodeinjections = pdfbackend.nodeinjections

codeinjections.getpos    = pdfgetpos     lpdf.getpos    = pdfgetpos
codeinjections.gethpos   = pdfgethpos    lpdf.gethpos   = pdfgethpos
codeinjections.getvpos   = pdfgetvpos    lpdf.getvpos   = pdfgetvpos
codeinjections.hasmatrix = pdfhasmatrix  lpdf.hasmatrix = pdfhasmatrix
codeinjections.getmatrix = pdfgetmatrix  lpdf.getmatrix = pdfgetmatrix

-- local function transform(llx,lly,urx,ury,rx,sx,sy,ry)
--     local x1 = llx * rx + lly * sy
--     local y1 = llx * sx + lly * ry
--     local x2 = llx * rx + ury * sy
--     local y2 = llx * sx + ury * ry
--     local x3 = urx * rx + lly * sy
--     local y3 = urx * sx + lly * ry
--     local x4 = urx * rx + ury * sy
--     local y4 = urx * sx + ury * ry
--     llx = min(x1,x2,x3,x4);
--     lly = min(y1,y2,y3,y4);
--     urx = max(x1,x2,x3,x4);
--     ury = max(y1,y2,y3,y4);
--     return llx, lly, urx, ury
-- end

function lpdf.transform(llx,lly,urx,ury) -- not yet used so unchecked
    if pdfhasmatrix() then
        local sx, rx, ry, sy = pdfgetmatrix()
        local w, h = urx - llx, ury - lly
        return llx, lly, llx + sy*w - ry*h, lly + sx*h - rx*w
     -- return transform(llx,lly,urx,ury,sx,rx,ry,sy)
    else
        return llx, lly, urx, ury
    end
end

-- funny values for tx and ty

function lpdf.rectangle(width,height,depth,offset)
    local tx, ty = pdfgetpos()
    if offset then
        tx     = tx     -   offset
        ty     = ty     +   offset
        width  = width  + 2*offset
        height = height +   offset
        depth  = depth  +   offset
    end
    if pdfhasmatrix() then
        local rx, sx, sy, ry = pdfgetmatrix()
        return
            factor *  tx,
            factor * (ty - ry*depth  + sx*width),
            factor * (tx + rx*width  - sy*height),
            factor * (ty + ry*height - sx*width)
    else
        return
            factor *  tx,
            factor * (ty - depth),
            factor * (tx + width),
            factor * (ty + height)
    end
end

-- we could use a hash of predefined unicodes

-- local function tosixteen(str) -- an lpeg might be faster (no table)
--     if not str or str == "" then
--         return "<feff>" -- not () as we want an indication that it's unicode
--     else
--         local r, n = { "<feff" }, 1
--         for b in utfvalues(str) do
--             n = n + 1
--             if b < 0x10000 then
--                 r[n] = format("%04x",b)
--             else
--              -- r[n] = format("%04x%04x",b/1024+0xD800,b%1024+0xDC00)
--                 r[n] = format("%04x%04x",floor(b/1024),b%1024+0xDC00) --bit32.rshift(b,10)
--             end
--         end
--         n = n + 1
--         r[n] = ">"
--         return concat(r)
--     end
-- end

local cache = table.setmetatableindex(function(t,k) -- can be made weak
    local v = utfbyte(k)
    if v < 0x10000 then
        v = format("%04x",v)
    else
     -- v = format("%04x%04x",v/1024+0xD800,v%1024+0xDC00)
        v = format("%04x%04x",floor(v/1024),v%1024+0xDC00)
    end
    t[k] = v
    return v
end)

local escaped = Cs(Cc("(") * (S("\\()")/"\\%0" + P(1))^0 * Cc(")"))
local unified = Cs(Cc("<feff") * (lpeg.patterns.utf8character/cache)^1 * Cc(">"))

local function tosixteen(str) -- an lpeg might be faster (no table)
    if not str or str == "" then
        return "<feff>" -- not () as we want an indication that it's unicode
    else
        return lpegmatch(unified,str)
    end
end

local more = 0

local pattern = C(4) / function(s) -- needs checking !
    local now = tonumber(s,16)
    if more > 0 then
        now = (more-0xD800)*0x400 + (now-0xDC00) + 0x10000 -- the 0x10000 smells wrong
        more = 0
        return utfchar(now)
    elseif now >= 0xD800 and now <= 0xDBFF then
        more = now
        return "" -- else the c's end up in the stream
    else
        return utfchar(now)
    end
end

local pattern = P(true) / function() more = 0 end * Cs(pattern^0)

local function fromsixteen(str)
    if not str or str == "" then
        return ""
    else
        return lpegmatch(pattern,str)
    end
end

local toregime   = regimes.toregime
local fromregime = regimes.fromregime

local function topdfdoc(str,default)
    if not str or str == "" then
        return ""
    else
        return lpegmatch(escaped,toregime("pdfdoc",str,default)) -- could be combined if needed
    end
end

local function frompdfdoc(str)
    if not str or str == "" then
        return ""
    else
        return fromregime("pdfdoc",str)
    end
end

if not toregime   then topdfdoc   = function(s) return s end end
if not fromregime then frompdfdoc = function(s) return s end end

local function toeight(str)
    if not str or str == "" then
        return "()"
    else
        return lpegmatch(escaped,str)
    end
end

lpdf.tosixteen   = tosixteen
lpdf.toeight     = toeight
lpdf.topdfdoc    = topdfdoc
lpdf.fromsixteen = fromsixteen
lpdf.frompdfdoc  = frompdfdoc

local function merge_t(a,b)
    local t = { }
    for k,v in next, a do t[k] = v end
    for k,v in next, b do t[k] = v end
    return setmetatable(t,getmetatable(a))
end

local f_key_null       = formatters["/%s null"]
local f_key_value      = formatters["/%s %s"]
local f_key_dictionary = formatters["/%s << % t >>"]
local f_dictionary     = formatters["<< % t >>"]
local f_key_array      = formatters["/%s [ % t ]"]
local f_array          = formatters["[ % t ]"]
local f_key_number     = formatters["/%s %F"]
local f_tonumber       = formatters["%F"]

local tostring_a, tostring_d

tostring_d = function(t,contentonly,key)
    if next(t) then
        local r, n = { }, 0
        for k in next, t do
            n = n + 1
            r[n] = k
        end
        sort(r)
        for i=1,n do
            local k  = r[i]
            local v  = t[k]
            local tv = type(v)
            if tv == "string" then
                r[i] = f_key_value(k,toeight(v))
            elseif tv == "number" then
                r[i] = f_key_number(k,v)
         -- elseif tv == "unicode" then -- can't happen
         --     r[i] = f_key_value(k,tosixteen(v))
            elseif tv == "table" then
                local mv = getmetatable(v)
                if mv and mv.__lpdftype then
                 -- if v == t then
                 --     report_objects("ignoring circular reference in dirctionary")
                 --     r[i] = f_key_null(k)
                 -- else
                        r[i] = f_key_value(k,tostring(v))
                 -- end
                elseif v[1] then
                    r[i] = f_key_value(k,tostring_a(v))
                else
                    r[i] = f_key_value(k,tostring_d(v))
                end
            else
                r[i] = f_key_value(k,tostring(v))
            end
        end
        if contentonly then
            return concat(r," ")
        elseif key then
            return f_key_dictionary(key,r)
        else
            return f_dictionary(r)
        end
    elseif contentonly then
        return ""
    else
        return "<< >>"
    end
end

tostring_a = function(t,contentonly,key)
    local tn = #t
    if tn ~= 0 then
        local r = { }
        for k=1,tn do
            local v = t[k]
            local tv = type(v)
            if tv == "string" then
                r[k] = toeight(v)
            elseif tv == "number" then
                r[k] = f_tonumber(v)
         -- elseif tv == "unicode" then
         --     r[k] = tosixteen(v)
            elseif tv == "table" then
                local mv = getmetatable(v)
                local mt = mv and mv.__lpdftype
                if mt then
                 -- if v == t then
                 --     report_objects("ignoring circular reference in array")
                 --     r[k] = "null"
                 -- else
                        r[k] = tostring(v)
                 -- end
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
            return f_key_array(key,r)
        else
            return f_array(r)
        end
    elseif contentonly then
        return ""
    else
        return "[ ]"
    end
end

local tostring_x = function(t) return concat(t," ")       end
local tostring_s = function(t) return toeight(t[1])       end
local tostring_p = function(t) return topdfdoc(t[1],t[2]) end
local tostring_u = function(t) return tosixteen(t[1])     end
----- tostring_n = function(t) return tostring(t[1])      end -- tostring not needed
local tostring_n = function(t) return f_tonumber(t[1])    end -- tostring not needed
local tostring_c = function(t) return t[1]                end -- already prefixed (hashed)
local tostring_z = function()  return "null"              end
local tostring_t = function()  return "true"              end
local tostring_f = function()  return "false"             end
local tostring_r = function(t) local n = t[1] return n and n > 0 and (n .. " 0 R") or "null" end

local tostring_v = function(t)
    local s = t[1]
    if type(s) == "table" then
        return concat(s)
    else
        return s
    end
end

local function value_x(t) return t                  end
local function value_s(t) return t[1]               end
local function value_p(t) return t[1]               end
local function value_u(t) return t[1]               end
local function value_n(t) return t[1]               end
local function value_c(t) return sub(t[1],2)        end
local function value_d(t) return tostring_d(t,true) end
local function value_a(t) return tostring_a(t,true) end
local function value_z()  return nil                end
local function value_t(t) return t.value or true    end
local function value_f(t) return t.value or false   end
local function value_r()  return t[1] or 0          end -- null
local function value_v()  return t[1]               end

local function add_x(t,k,v) rawset(t,k,tostring(v)) end

local mt_x = { __lpdftype = "stream",     __tostring = tostring_x, __call = value_x, __newindex = add_x }
local mt_d = { __lpdftype = "dictionary", __tostring = tostring_d, __call = value_d }
local mt_a = { __lpdftype = "array",      __tostring = tostring_a, __call = value_a }
local mt_u = { __lpdftype = "unicode",    __tostring = tostring_u, __call = value_u }
local mt_s = { __lpdftype = "string",     __tostring = tostring_s, __call = value_s }
local mt_p = { __lpdftype = "docstring",  __tostring = tostring_p, __call = value_p }
local mt_n = { __lpdftype = "number",     __tostring = tostring_n, __call = value_n }
local mt_c = { __lpdftype = "constant",   __tostring = tostring_c, __call = value_c }
local mt_z = { __lpdftype = "null",       __tostring = tostring_z, __call = value_z }
local mt_t = { __lpdftype = "true",       __tostring = tostring_t, __call = value_t }
local mt_f = { __lpdftype = "false",      __tostring = tostring_f, __call = value_f }
local mt_r = { __lpdftype = "reference",  __tostring = tostring_r, __call = value_r }
local mt_v = { __lpdftype = "verbose",    __tostring = tostring_v, __call = value_v }

local function pdfstream(t) -- we need to add attributes
    if t then
        local tt = type(t)
        if tt == "table" then
            for i=1,#t do
                t[i] = tostring(t[i])
            end
        elseif tt == "string" then
            t= { t }
        else
            t= { tostring(t) }
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

local function pdfdocstring(str,default,defaultchar)
    return setmetatable({ str or default or "", defaultchar or " " },mt_p)
end

local function pdfunicode(str,default)
    return setmetatable({ str or default or "" },mt_u) -- could be a string
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

local escaped = Cs(Cc("/") * (S(forbidden)/replacements + P(1))^0)

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

local escaped = Cs((S(forbidden)/replacements + P(1))^0)
----- escaped = Cs((1-forbidden)^0 * S(forbidden)/replacements * ((S(forbidden)/replacements + P(1))^0)

function lpdf.escaped(str)
    return lpegmatch(escaped,str) or str
end

do

    local p_null  = { } setmetatable(p_null, mt_z)
    local p_true  = { } setmetatable(p_true, mt_t)
    local p_false = { } setmetatable(p_false,mt_f)

    pdfnull = function()
        return p_null
    end

    pdfboolean = function(b,default)
        if type(b) == "boolean" then
            return b and p_true or p_false
        else
            return default and p_true or p_false
        end
    end

    -- print(pdfboolean(false),pdfboolean(false,false),pdfboolean(false,true))
    -- print(pdfboolean(true),pdfboolean(true,false),pdfboolean(true,true))
    -- print(pdfboolean(nil,true),pdfboolean(nil,false))

    local r_zero = setmetatable({ 0 },mt_r)

    pdfreference = function(r)  -- maybe make a weak table
        if r and r ~= 0 then
            return setmetatable({ r },mt_r)
        else
            return r_zero
        end
    end

    local v_zero  = setmetatable({ 0  },mt_v)
    local v_empty = setmetatable({ "" },mt_v)

    pdfverbose = function(t) -- maybe check for type
        if t == 0 then
            return v_zero
        elseif t == "" then
            return v_empty
        else
            return setmetatable({ t },mt_v)
        end
    end

end

lpdf.stream      = pdfstream -- THIS WILL PROBABLY CHANGE
lpdf.dictionary  = pdfdictionary
lpdf.array       = pdfarray
lpdf.docstring   = pdfdocstring
lpdf.string      = pdfstring
lpdf.unicode     = pdfunicode
lpdf.number      = pdfnumber
lpdf.constant    = pdfconstant
lpdf.null        = pdfnull
lpdf.boolean     = pdfboolean
lpdf.reference   = pdfreference
lpdf.verbose     = pdfverbose

local names, cache = { }, { }

function lpdf.reserveobject(name)
    local r = pdfreserveobject() -- we don't support "annot"
    if name then
        names[name] = r
        if trace_objects then
            report_objects("reserving number %a under name %a",r,name)
        end
    elseif trace_objects then
        report_objects("reserving number %a",r)
    end
    return r
end

-- lpdf.immediateobject = pdfimmediateobject
-- lpdf.deferredobject  = pdfdeferredobject
-- lpdf.object          = pdfdeferredobject
-- lpdf.referenceobject = pdfreferenceobject

local pagereference = pdf.pageref -- tex.pdfpageref is obsolete
local nofpages      = 0

function lpdf.pagereference(n)
    if nofpages == 0 then
        nofpages = structures.pages.nofpages
        if nofpages == 0 then
            nofpages = 1
        end
    end
    if n > nofpages then
        return pagereference(nofpages) -- or 1, could be configureable
    else
        return pagereference(n)
    end
end

function lpdf.delayedobject(data,n)
    if n then
        pdfdeferredobject(n,data)
    else
        n = pdfdeferredobject(data)
    end
    pdfreferenceobject(n)
    return n
end

function lpdf.flushobject(name,data)
    if data then
        local named = names[name]
        if named then
            if not trace_objects then
            elseif trace_detail then
                report_objects("flushing data to reserved object with name %a, data: %S",name,data)
            else
                report_objects("flushing data to reserved object with name %a",name)
            end
            return pdfimmediateobject(named,tostring(data))
        else
            if not trace_objects then
            elseif trace_detail then
                report_objects("flushing data to reserved object with number %s, data: %S",name,data)
            else
                report_objects("flushing data to reserved object with number %s",name)
            end
            return pdfimmediateobject(name,tostring(data))
        end
    else
        if trace_objects and trace_detail then
            report_objects("flushing data: %S",name)
        end
        return pdfimmediateobject(tostring(name))
    end
end


function lpdf.flushstreamobject(data,dict,compressed) -- default compressed
    if trace_objects then
        report_objects("flushing stream object of %s bytes",#data)
    end
    local dtype = type(dict)
    return pdfdeferredobject {
        immediate     = true,
        compresslevel = compressed == false and 0 or nil,
        type          = "stream",
        string        = data,
        attr          = (dtype == "string" and dict) or (dtype == "table" and dict()) or nil,
    }
end

function lpdf.flushstreamfileobject(filename,dict,compressed) -- default compressed
    if trace_objects then
        report_objects("flushing stream file object %a",filename)
    end
    local dtype = type(dict)
    return pdfdeferredobject {
        immediate     = true,
        compresslevel = compressed == false and 0 or nil,
        type          = "stream",
        file          = filename,
        attr          = (dtype == "string" and dict) or (dtype == "table" and dict()) or nil,
    }
end

local shareobjectcache, shareobjectreferencecache = { }, { }

function lpdf.shareobject(content)
    if content == nil then
        -- invalid object not created
    else
        content = tostring(content)
        local o = shareobjectcache[content]
        if not o then
            o = pdfimmediateobject(content)
            shareobjectcache[content] = o
        end
        return o
    end
end

function lpdf.shareobjectreference(content)
    if content == nil then
        -- invalid object not created
    else
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
end

-- three priority levels, default=2

local pagefinalizers     = { { }, { }, { } }
local documentfinalizers = { { }, { }, { } }

local pageresources, pageattributes, pagesattributes

local function resetpageproperties()
    pageresources   = pdfdictionary()
    pageattributes  = pdfdictionary()
    pagesattributes = pdfdictionary()
end

resetpageproperties()

local function setpageproperties()
    pdfsetpageresources  (pageresources  ())
    pdfsetpageattributes (pageattributes ())
    pdfsetpagesattributes(pagesattributes())
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
        report_finalizing("start backend, category %a, n %a",what,#where)
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

function lpdf.finalizepage(shipout)
    if shipout and not environment.initex then
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

-- codeinjections.finalizepage = lpdf.finalizepage -- no longer triggered at the tex end

if not callbacks.register("finish_pdfpage", lpdf.finalizepage) then

    local find_tail    = nodes.tail
    local latelua_node = nodes.pool.latelua

    function nodeinjections.finalizepage(head)
        local t = find_tail(head.list)
        if t then
            local n = latelua_node("lpdf.finalizepage(true)") -- last in the shipout
            t.next = n
            n.prev = t
        end
        return head, true
    end

    nodes.tasks.appendaction("shipouts","normalizers","backends.pdf.nodeinjections.finalizepage")

end

callbacks.register("finish_pdffile", lpdf.finalizedocument)


do

    -- some minimal tracing, handy for checking the order

    local function trace_set(what,key)
        if trace_resources then
            report_finalizing("setting key %a in %a",key,what)
        end
    end

    local function trace_flush(what)
        if trace_resources then
            report_finalizing("flushing %a",what)
        end
    end

    lpdf.protectresources = true

    local catalog = pdfdictionary { Type = pdfconstant("Catalog") } -- nicer, but when we assign we nil the Type
    local info    = pdfdictionary { Type = pdfconstant("Info")    } -- nicer, but when we assign we nil the Type
    ----- names   = pdfdictionary { Type = pdfconstant("Names")   } -- nicer, but when we assign we nil the Type

    local function flushcatalog()
        if not environment.initex then
            trace_flush("catalog")
            catalog.Type = nil
            pdfsetcatalog(catalog())
        end
    end

    local function flushinfo()
        if not environment.initex then
            trace_flush("info")
            info.Type = nil
            pdfsetinfo(info())
        end
    end

    -- local function flushnames()
    --     if not environment.initex then
    --         trace_flush("names")
    --         names.Type = nil
    --         pdfsetnames(names())
    --     end
    -- end

    function lpdf.addtocatalog(k,v)
        if not (lpdf.protectresources and catalog[k]) then
            trace_set("catalog",k)
            catalog[k] = v
        end
    end

    function lpdf.addtoinfo(k,v)
        if not (lpdf.protectresources and info[k]) then
            trace_set("info",k)
            info[k] = v
        end
    end

    -- local function lpdf.addtonames(k,v)
    --     if not (lpdf.protectresources and names[k]) then
    --         trace_set("names",k)
    --         names[k] = v
    --     end
    -- end

    local names = pdfdictionary {
     -- Type = pdfconstant("Names")
    }

    local function flushnames()
        if next(names) and not environment.initex then
            names.Type = pdfconstant("Names")
            trace_flush("names")
            lpdf.addtocatalog("Names",pdfreference(pdfimmediateobject(tostring(names))))
        end
    end

    function lpdf.addtonames(k,v)
        if not (lpdf.protectresources and names[k]) then
            trace_set("names",  k)
            names  [k] = v
        end
    end

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

    -- patterns are special as they need resources to so we can get recursive references and in that case
    -- acrobat doesn't show anything (other viewers handle it well)
    --
    -- todo: share them
    -- todo: force when not yet set

    function lpdf.collectedresources(options)
        local ExtGState  = next(d_extgstates ) and p_extgstates
        local ColorSpace = next(d_colorspaces) and p_colorspaces
        local Pattern    = next(d_patterns   ) and p_patterns
        local Shading    = next(d_shades     ) and p_shades
        if options and options.patterns == false then
            Pattern = nil
        end
        if ExtGState or ColorSpace or Pattern or Shading then
            local collected = pdfdictionary {
                ExtGState  = ExtGState,
                ColorSpace = ColorSpace,
                Pattern    = Pattern,
                Shading    = Shading,
             -- ProcSet    = pdfarray { pdfconstant("PDF") },
            }
            return collected()
        else
            return ""
        end
    end

    function lpdf.adddocumentextgstate (k,v) d_extgstates [k] = v end
    function lpdf.adddocumentcolorspace(k,v) d_colorspaces[k] = v end
    function lpdf.adddocumentpattern   (k,v) d_patterns   [k] = v end
    function lpdf.adddocumentshade     (k,v) d_shades     [k] = v end

    registerdocumentfinalizer(flushextgstates,3,"extended graphic states")
    registerdocumentfinalizer(flushcolorspaces,3,"color spaces")
    registerdocumentfinalizer(flushpatterns,3,"patterns")
    registerdocumentfinalizer(flushshades,3,"shades")

    registerdocumentfinalizer(flushnames,3,"names") -- before catalog
    registerdocumentfinalizer(flushcatalog,3,"catalog")
    registerdocumentfinalizer(flushinfo,3,"info")

    registerpagefinalizer(checkextgstates,3,"extended graphic states")
    registerpagefinalizer(checkcolorspaces,3,"color spaces")
    registerpagefinalizer(checkpatterns,3,"patterns")
    registerpagefinalizer(checkshades,3,"shades")

end

-- in strc-bkm: lpdf.registerdocumentfinalizer(function() structures.bookmarks.place() end,1)

function lpdf.rotationcm(a)
    local s, c = sind(a), cosd(a)
    return format("%0.6F %0.6F %0.6F %0.6F 0 0 cm",c,s,-s,c)
end

-- ! -> universaltime

do

    local timestamp = backends.timestamp()

    function lpdf.timestamp()
        return timestamp
    end

    function lpdf.settime(n)
        if n then
            n = converters.totime(n)
            if n then
                converters.settime(n)
                timestamp = backends.timestamp()
            end
        end
        return timestamp
    end

    lpdf.settime(tonumber(resolvers.variable("start_time")) or tonumber(resolvers.variable("SOURCE_DATE_EPOCH"))) -- bah

    function lpdf.pdftimestamp(str)
        local Y, M, D, h, m, s, Zs, Zh, Zm = match(str,"^(%d%d%d%d)%-(%d%d)%-(%d%d)T(%d%d):(%d%d):(%d%d)([%+%-])(%d%d):(%d%d)$")
        return Y and format("D:%s%s%s%s%s%s%s%s'%s'",Y,M,D,h,m,s,Zs,Zh,Zm)
    end

    function lpdf.id(nodate)
        if nodate then
            return tex.jobname
        else
            return format("%s.%s",tex.jobname,timestamp)
        end
    end

end

-- return nil is nicer in test prints

function lpdf.checkedkey(t,key,variant)
    local pn = t and t[key]
    if pn ~= nil then
        local tn = type(pn)
        if tn == variant then
            if variant == "string" then
                if pn ~= "" then
                    return pn
                end
            elseif variant == "table" then
                if next(pn) then
                    return pn
                end
            else
                return pn
            end
        elseif tn == "string" then
            if variant == "number" then
                return tonumber(pn)
            elseif variant == "boolean" then
                return isboolean(pn,nil,true)
            end
        end
    end
 -- return nil
end

function lpdf.checkedvalue(value,variant) -- code not shared
    if value ~= nil then
        local tv = type(value)
        if tv == variant then
            if variant == "string" then
                if value ~= "" then
                    return value
                end
            elseif variant == "table" then
                if next(value) then
                    return value
                end
            else
                return value
            end
        elseif tv == "string" then
            if variant == "number" then
                return tonumber(value)
            elseif variant == "boolean" then
                return isboolean(value,nil,true)
            end
        end
    end
 -- return nil
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

-- if not pdfreferenceobject then
--
--     local delayed = { }
--
--     local function flush()
--         local n = 0
--         for k,v in next, delayed do
--             pdfimmediateobject(k,v)
--             n = n + 1
--         end
--         if trace_objects then
--             report_objects("%s objects flushed",n)
--         end
--         delayed = { }
--     end
--
--     lpdf.registerdocumentfinalizer(flush,3,"objects") -- so we need a final flush too
--     lpdf.registerpagefinalizer    (flush,3,"objects") -- somehow this lags behind .. I need to look into that some day
--
--     function lpdf.delayedobject(data)
--         local n = pdfreserveobject()
--         delayed[n] = data
--         return n
--     end
--
-- end

-- setmetatable(pdf, {
--     __index = function(t,k)
--         if     k == "info"           then return pdf.getinfo()
--         elseif k == "catalog"        then return pdf.getcatalog()
--         elseif k == "names"          then return pdf.getnames()
--         elseif k == "trailer"        then return pdf.gettrailer()
--         elseif k == "pageattribute"  then return pdf.getpageattribute()
--         elseif k == "pageattributes" then return pdf.getpageattributes()
--         elseif k == "pageresources"  then return pdf.getpageresources()
--         elseif
--             return nil
--         end
--     end,
--     __newindex = function(t,k,v)
--         if     k == "info"           then return pdf.setinfo(v)
--         elseif k == "catalog"        then return pdf.setcatalog(v)
--         elseif k == "names"          then return pdf.setnames(v)
--         elseif k == "trailer"        then return pdf.settrailer(v)
--         elseif k == "pageattribute"  then return pdf.setpageattribute(v)
--         elseif k == "pageattributes" then return pdf.setpageattributes(v)
--         elseif k == "pageresources"  then return pdf.setpageresources(v)
--         else
--             rawset(t,k,v)
--         end
--     end,
-- })


-- The next variant of ActualText is what Taco and I could come up with
-- eventually. As of September 2013 Acrobat copies okay, Sumatra copies a
-- question mark, pdftotext injects an extra space and Okular adds a
-- newline plus space.

-- return formatters["BT /Span << /ActualText (CONTEXT) >> BDC [<feff>] TJ % t EMC ET"](code)

do

    local f_actual_text_one   = formatters["BT /Span << /ActualText <feff%04x> >> BDC [<feff>] TJ %s EMC ET"]
    local f_actual_text_two   = formatters["BT /Span << /ActualText <feff%04x%04x> >> BDC [<feff>] TJ %s EMC ET"]
    local f_actual_text_one_b = formatters["BT /Span << /ActualText <feff%04x> >> BDC [<feff>] TJ "]
    local f_actual_text_two_b = formatters["BT /Span << /ActualText <feff%04x%04x> >> BDC [<feff>] TJ "]
    local f_actual_text_b     = formatters["BT /Span << /ActualText <feff%s> >> BDC [<feff>] TJ "]
    local s_actual_text_e     = "EMC ET"
    local f_actual_text_b_not = formatters["/Span << /ActualText <feff%s> >> BDC [<feff>] TJ "]
    local s_actual_text_e_not = "EMC"
    local f_actual_text       = formatters["/Span <</ActualText %s >> BDC"]

    local context   = context
    local pdfdirect = nodes.pool.pdfdirect

    -- todo: use tounicode from the font mapper

    function codeinjections.unicodetoactualtext(unicode,pdfcode)
        if unicode < 0x10000 then
            return f_actual_text_one(unicode,pdfcode)
        else
            return f_actual_text_two(unicode/1024+0xD800,unicode%1024+0xDC00,pdfcode)
        end
    end

    function codeinjections.startunicodetoactualtext(unicode)
        if type(unicode) == "string" then
            return f_actual_text_b(unicode)
        elseif unicode < 0x10000 then
            return f_actual_text_one_b(unicode)
        else
            return f_actual_text_two_b(unicode/1024+0xD800,unicode%1024+0xDC00)
        end
    end

    function codeinjections.stopunicodetoactualtext()
        return s_actual_text_e
    end

    function codeinjections.startunicodetoactualtextdirect(unicode)
        return f_actual_text_b_not(unicode)
    end

    function codeinjections.stopunicodetoactualtextdirect()
        return s_actual_text_e_not
    end

    implement {
        name      = "startactualtext",
        arguments = "string",
        actions   = function(str)
            context(pdfdirect(f_actual_text(tosixteen(str))))
        end
    }

    implement {
        name      = "stopactualtext",
        actions   = function()
            context(pdfdirect("EMC"))
        end
    }

end

-- interface

implement { name = "lpdf_collectedresources",                             actions = { lpdf.collectedresources, context } }
implement { name = "lpdf_addtocatalog",          arguments = two_strings, actions = lpdf.addtocatalog }
implement { name = "lpdf_addtoinfo",             arguments = two_strings, actions = function(a,b,c) lpdf.addtoinfo(a,b,c) end } -- gets adapted
implement { name = "lpdf_addtonames",            arguments = two_strings, actions = lpdf.addtonames }
implement { name = "lpdf_addtopageattributes",   arguments = two_strings, actions = lpdf.addtopageattributes }
implement { name = "lpdf_addtopagesattributes",  arguments = two_strings, actions = lpdf.addtopagesattributes }
implement { name = "lpdf_addtopageresources",    arguments = two_strings, actions = lpdf.addtopageresources }
implement { name = "lpdf_adddocumentextgstate",  arguments = two_strings, actions = function(a,b) lpdf.adddocumentextgstate (a,pdfverbose(b)) end }
implement { name = "lpdf_adddocumentcolorspace", arguments = two_strings, actions = function(a,b) lpdf.adddocumentcolorspace(a,pdfverbose(b)) end }
implement { name = "lpdf_adddocumentpattern",    arguments = two_strings, actions = function(a,b) lpdf.adddocumentpattern   (a,pdfverbose(b)) end }
implement { name = "lpdf_adddocumentshade",      arguments = two_strings, actions = function(a,b) lpdf.adddocumentshade     (a,pdfverbose(b)) end }


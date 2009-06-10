if not modules then modules = { } end modules ['lxml-tab'] = {
    version   = 1.001,
    comment   = "this module is the basis for the lxml-* ones",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

--[[ldx--
<p>The parser used here is inspired by the variant discussed in the lua book, but
handles comment and processing instructions, has a different structure, provides
parent access; a first version used different trickery but was less optimized to we
went this route. First we had a find based parser, now we have an <l n='lpeg'/> based one.
The find based parser can be found in l-xml-edu.lua along with other older code.</p>

<p>Expecially the lpath code is experimental, we will support some of xpath, but
only things that make sense for us; as compensation it is possible to hook in your
own functions. Apart from preprocessing content for <l n='context'/> we also need
this module for process management, like handling <l n='ctx'/> and <l n='rlx'/>
files.</p>

<typing>
a/b/c /*/c
a/b/c/first() a/b/c/last() a/b/c/index(n) a/b/c/index(-n)
a/b/c/text() a/b/c/text(1) a/b/c/text(-1) a/b/c/text(n)
</typing>

<p>Beware, the interface may change. For instance at, ns, tg, dt may get more
verbose names. Once the code is stable we will also remove some tracing and
optimize the code.</p>
--ldx]]--

xml = xml or { }

--~ local xml = xml

local concat, remove, insert = table.concat, table.remove, table.insert
local type, next, setmetatable = type, next, setmetatable
local format, lower, find = string.format, string.lower, string.find

--[[ldx--
<p>This module can be used stand alone but also inside <l n='mkiv'/> in
which case it hooks into the tracker code. Therefore we provide a few
functions that set the tracers.</p>
--ldx]]--

local trace_remap = false

if trackers then
    trackers.register("xml.remap", function(v) trace_remap = v end)
end

function xml.settrace(str,value)
    if str == "remap" then
        trace_remap = value or false
    end
end

--[[ldx--
<p>First a hack to enable namespace resolving. A namespace is characterized by
a <l n='url'/>. The following function associates a namespace prefix with a
pattern. We use <l n='lpeg'/>, which in this case is more than twice as fast as a
find based solution where we loop over an array of patterns. Less code and
much cleaner.</p>
--ldx]]--

xml.xmlns = xml.xmlns or { }

local check = lpeg.P(false)
local parse = check

--[[ldx--
<p>The next function associates a namespace prefix with an <l n='url'/>. This
normally happens independent of parsing.</p>

<typing>
xml.registerns("mml","mathml")
</typing>
--ldx]]--

function xml.registerns(namespace, pattern) -- pattern can be an lpeg
    check = check + lpeg.C(lpeg.P(lower(pattern))) / namespace
    parse = lpeg.P { lpeg.P(check) + 1 * lpeg.V(1) }
end

--[[ldx--
<p>The next function also registers a namespace, but this time we map a
given namespace prefix onto a registered one, using the given
<l n='url'/>. This used for attributes like <t>xmlns:m</t>.</p>

<typing>
xml.checkns("m","http://www.w3.org/mathml")
</typing>
--ldx]]--

function xml.checkns(namespace,url)
    local ns = parse:match(lower(url))
    if ns and namespace ~= ns then
        xml.xmlns[namespace] = ns
    end
end

--[[ldx--
<p>Next we provide a way to turn an <l n='url'/> into a registered
namespace. This used for the <t>xmlns</t> attribute.</p>

<typing>
resolvedns = xml.resolvens("http://www.w3.org/mathml")
</typing>

This returns <t>mml</t>.
--ldx]]--

function xml.resolvens(url)
     return parse:match(lower(url)) or ""
end

--[[ldx--
<p>A namespace in an element can be remapped onto the registered
one efficiently by using the <t>xml.xmlns</t> table.</p>
--ldx]]--

--[[ldx--
<p>This version uses <l n='lpeg'/>. We follow the same approach as before, stack and top and
such. This version is about twice as fast which is mostly due to the fact that
we don't have to prepare the stream for cdata, doctype etc etc. This variant is
is dedicated to Luigi Scarso, who challenged me with 40 megabyte <l n='xml'/> files that
took 12.5 seconds to load (1.5 for file io and the rest for tree building). With
the <l n='lpeg'/> implementation we got that down to less 7.3 seconds. Loading the 14
<l n='context'/> interface definition files (2.6 meg) went down from 1.05 seconds to 0.55.</p>

<p>Next comes the parser. The rather messy doctype definition comes in many
disguises so it is no surprice that later on have to dedicate quite some
<l n='lpeg'/> code to it.</p>

<typing>
<!DOCTYPE Something PUBLIC "... ..." "..." [ ... ] >
<!DOCTYPE Something PUBLIC "... ..." "..." >
<!DOCTYPE Something SYSTEM "... ..." [ ... ] >
<!DOCTYPE Something SYSTEM "... ..." >
<!DOCTYPE Something [ ... ] >
<!DOCTYPE Something >
</typing>

<p>The code may look a bit complex but this is mostly due to the fact that we
resolve namespaces and attach metatables. There is only one public function:</p>

<typing>
local x = xml.convert(somestring)
</typing>

<p>An optional second boolean argument tells this function not to create a root
element.</p>
--ldx]]--

xml.strip_cm_and_dt = false -- an extra global flag, in case we have many includes

-- not just one big nested table capture (lpeg overflow)

local nsremap, resolvens = xml.xmlns, xml.resolvens

local stack, top, dt, at, xmlns, errorstr, entities = {}, {}, {}, {}, {}, nil, {}

local mt = { __tostring = xml.text }

function xml.check_error(top,toclose)
    return ""
end

local strip   = false
local cleanup = false

function xml.set_text_cleanup(fnc)
    cleanup = fnc
end

local function add_attribute(namespace,tag,value)
    if cleanup and #value > 0 then
        value = cleanup(value) -- new
    end
    if tag == "xmlns" then
        xmlns[#xmlns+1] = resolvens(value)
        at[tag] = value
    elseif namespace == "xmlns" then
        xml.checkns(tag,value)
        at["xmlns:" .. tag] = value
    else
        at[tag] = value
    end
end

local function add_begin(spacing, namespace, tag)
    if #spacing > 0 then
        dt[#dt+1] = spacing
    end
    local resolved = (namespace == "" and xmlns[#xmlns]) or nsremap[namespace] or namespace
    top = { ns=namespace or "", rn=resolved, tg=tag, at=at, dt={}, __p__ = stack[#stack] }
    setmetatable(top, mt)
    dt = top.dt
    stack[#stack+1] = top
    at = { }
end

local function add_end(spacing, namespace, tag)
    if #spacing > 0 then
        dt[#dt+1] = spacing
    end
    local toclose = remove(stack)
    top = stack[#stack]
    if #stack < 1 then
        errorstr = format("nothing to close with %s %s", tag, xml.check_error(top,toclose) or "")
    elseif toclose.tg ~= tag then -- no namespace check
        errorstr = format("unable to close %s with %s %s", toclose.tg, tag, xml.check_error(top,toclose) or "")
    end
    dt = top.dt
    dt[#dt+1] = toclose
    dt[0] = top
    if toclose.at.xmlns then
        remove(xmlns)
    end
end

local function add_empty(spacing, namespace, tag)
    if #spacing > 0 then
        dt[#dt+1] = spacing
    end
    local resolved = (namespace == "" and xmlns[#xmlns]) or nsremap[namespace] or namespace
    top = stack[#stack]
    dt = top.dt
    local t = { ns=namespace or "", rn=resolved, tg=tag, at=at, dt={}, __p__ = top }
    dt[#dt+1] = t
    setmetatable(t, mt)
    if at.xmlns then
        remove(xmlns)
    end
    at = { }
end

local function add_text(text)
    if cleanup and #text > 0 then
        dt[#dt+1] = cleanup(text)
    else
        dt[#dt+1] = text
    end
end

local function add_special(what, spacing, text)
    if #spacing > 0 then
        dt[#dt+1] = spacing
    end
    if strip and (what == "@cm@" or what == "@dt@") then
        -- forget it
    else
        dt[#dt+1] = { special=true, ns="", tg=what, dt={text} }
    end
end

local function set_message(txt)
    errorstr = "garbage at the end of the file: " .. gsub(txt,"([ \n\r\t]*)","")
end

local P, S, R, C, V = lpeg.P, lpeg.S, lpeg.R, lpeg.C, lpeg.V

local space            = S(' \r\n\t')
local open             = P('<')
local close            = P('>')
local squote           = S("'")
local dquote           = S('"')
local equal            = P('=')
local slash            = P('/')
local colon            = P(':')
local valid            = R('az', 'AZ', '09') + S('_-.')
local name_yes         = C(valid^1) * colon * C(valid^1)
local name_nop         = C(P(true)) * C(valid^1)
local name             = name_yes + name_nop

local utfbom           = P('\000\000\254\255') + P('\255\254\000\000') +
                         P('\255\254') + P('\254\255') + P('\239\187\191') -- no capture

local spacing          = C(space^0)
local justtext         = C((1-open)^1)
local somespace        = space^1
local optionalspace    = space^0

local value            = (squote * C((1 - squote)^0) * squote) + (dquote * C((1 - dquote)^0) * dquote)
local attribute        = (somespace * name * optionalspace * equal * optionalspace * value) / add_attribute
local attributes       = attribute^0

local text             = justtext / add_text
local balanced         = P { "[" * ((1 - S"[]") + V(1))^0 * "]" } -- taken from lpeg manual, () example

local emptyelement     = (spacing * open         * name * attributes * optionalspace * slash * close) / add_empty
local beginelement     = (spacing * open         * name * attributes * optionalspace         * close) / add_begin
local endelement       = (spacing * open * slash * name              * optionalspace         * close) / add_end

local begincomment     = open * P("!--")
local endcomment       = P("--") * close
local begininstruction = open * P("?")
local endinstruction   = P("?") * close
local begincdata       = open * P("![CDATA[")
local endcdata         = P("]]") * close

local someinstruction  = C((1 - endinstruction)^0)
local somecomment      = C((1 - endcomment    )^0)
local somecdata        = C((1 - endcdata      )^0)

local function entity(k,v) entities[k] = v end

local begindoctype     = open * P("!DOCTYPE")
local enddoctype       = close
local beginset         = P("[")
local endset           = P("]")
local doctypename      = C((1-somespace)^0)
local elementdoctype   = optionalspace * P("<!ELEMENT") * (1-close)^0 * close
local entitydoctype    = optionalspace * P("<!ENTITY") * somespace * (doctypename * somespace * value)/entity * optionalspace * close
local publicdoctype    = doctypename * somespace * P("PUBLIC") * somespace * value * somespace * value * somespace
local systemdoctype    = doctypename * somespace * P("SYSTEM") * somespace * value * somespace
local definitiondoctype= doctypename * somespace * beginset * P(elementdoctype + entitydoctype)^0 * optionalspace * endset
local simpledoctype    = (1-close)^1                     -- * balanced^0
local somedoctype      = C((somespace * (publicdoctype + systemdoctype + definitiondoctype + simpledoctype) * optionalspace)^0)

local instruction      = (spacing * begininstruction * someinstruction * endinstruction) / function(...) add_special("@pi@",...) end
local comment          = (spacing * begincomment     * somecomment     * endcomment    ) / function(...) add_special("@cm@",...) end
local cdata            = (spacing * begincdata       * somecdata       * endcdata      ) / function(...) add_special("@cd@",...) end
local doctype          = (spacing * begindoctype     * somedoctype     * enddoctype    ) / function(...) add_special("@dt@",...) end

--  nicer but slower:
--
--  local instruction = (lpeg.Cc("@pi@") * spacing * begininstruction * someinstruction * endinstruction) / add_special
--  local comment     = (lpeg.Cc("@cm@") * spacing * begincomment     * somecomment     * endcomment    ) / add_special
--  local cdata       = (lpeg.Cc("@cd@") * spacing * begincdata       * somecdata       * endcdata      ) / add_special
--  local doctype     = (lpeg.Cc("@dt@") * spacing * begindoctype     * somedoctype     * enddoctype    ) / add_special

local trailer = space^0 * (justtext/set_message)^0

--  comment + emptyelement + text + cdata + instruction + V("parent"), -- 6.5 seconds on 40 MB database file
--  text + comment + emptyelement + cdata + instruction + V("parent"), -- 5.8
--  text + V("parent") + emptyelement + comment + cdata + instruction, -- 5.5

local grammar = P { "preamble",
    preamble = utfbom^0 * instruction^0 * (doctype + comment + instruction)^0 * V("parent") * trailer,
    parent   = beginelement * V("children")^0 * endelement,
    children = text + V("parent") + emptyelement + comment + cdata + instruction,
}

-- todo: xml.new + properties like entities and strip and such (store in root)

function xml.convert(data, no_root, strip_cm_and_dt, given_entities) -- maybe use table met k/v (given_entities may disapear)
    strip = strip_cm_and_dt or xml.strip_cm_and_dt
    stack, top, at, xmlns, errorstr, result, entities = {}, {}, {}, {}, nil, nil, given_entities or {}
    stack[#stack+1] = top
    top.dt = { }
    dt = top.dt
    if not data or data == "" then
        errorstr = "empty xml file"
    elseif not grammar:match(data) then
        errorstr = "invalid xml file"
    else
        errorstr = ""
    end
    if errorstr and errorstr ~= "" then
        result = { dt = { { ns = "", tg = "error", dt = { errorstr }, at={}, er = true } }, error = true }
        setmetatable(stack, mt)
        if xml.error_handler then xml.error_handler("load",errorstr) end
    else
        result = stack[1]
    end
    if not no_root then
        result = { special = true, ns = "", tg = '@rt@', dt = result.dt, at={}, entities = entities }
        setmetatable(result, mt)
        local rdt = result.dt
        for k=1,#rdt do
            local v = rdt[k]
            if type(v) == "table" and not v.special then -- always table -)
                result.ri = k -- rootindex
                break
            end
        end
    end
    return result
end

--[[ldx--
<p>Packaging data in an xml like table is done with the following
function. Maybe it will go away (when not used).</p>
--ldx]]--

function xml.is_valid(root)
    return root and root.dt and root.dt[1] and type(root.dt[1]) == "table" and not root.dt[1].er
end

function xml.package(tag,attributes,data)
    local ns, tg = tag:match("^(.-):?([^:]+)$")
    local t = { ns = ns, tg = tg, dt = data or "", at = attributes or {} }
    setmetatable(t, mt)
    return t
end

function xml.is_valid(root)
    return root and not root.error
end

xml.error_handler = (logs and logs.report) or (input and logs.report) or print

--[[ldx--
<p>We cannot load an <l n='lpeg'/> from a filehandle so we need to load
the whole file first. The function accepts a string representing
a filename or a file handle.</p>
--ldx]]--

function xml.load(filename)
    if type(filename) == "string" then
        local f = io.open(filename,'r')
        if f then
            local root = xml.convert(f:read("*all"))
            f:close()
            return root
        else
            return xml.convert("")
        end
    elseif filename then -- filehandle
        return xml.convert(filename:read("*all"))
    else
        return xml.convert("")
    end
end

--[[ldx--
<p>When we inject new elements, we need to convert strings to
valid trees, which is what the next function does.</p>
--ldx]]--

function xml.toxml(data)
    if type(data) == "string" then
        local root = { xml.convert(data,true) }
        return (#root > 1 and root) or root[1]
    else
        return data
    end
end

--[[ldx--
<p>For copying a tree we use a dedicated function instead of the
generic table copier. Since we know what we're dealing with we
can speed up things a bit. The second argument is not to be used!</p>
--ldx]]--

function copy(old,tables)
    if old then
        tables = tables or { }
        local new = { }
        if not tables[old] then
            tables[old] = new
        end
        for k,v in pairs(old) do
            new[k] = (type(v) == "table" and (tables[v] or copy(v, tables))) or v
        end
        local mt = getmetatable(old)
        if mt then
            setmetatable(new,mt)
        end
        return new
    else
        return { }
    end
end

xml.copy = copy

--[[ldx--
<p>In <l n='context'/> serializing the tree or parts of the tree is a major
actitivity which is why the following function is pretty optimized resulting
in a few more lines of code than needed. The variant that uses the formatting
function for all components is about 15% slower than the concatinating
alternative.</p>
--ldx]]--

-- todo: add <?xml version='1.0' standalone='yes'?> when not present

local fallbackhandle = (tex and tex.sprint) or io.write

local function serialize(e, handle, textconverter, attributeconverter, specialconverter, nocommands)
    if not e then
        return
    elseif not nocommands then
        local ec = e.command
        if ec ~= nil then -- we can have all kind of types
            if e.special then
                local etg, edt = e.tg, e.dt
                local spc = specialconverter and specialconverter[etg]
                if spc then
                    local result = spc(edt[1])
                    if result then
                        handle(result)
                        return
                    else
                        -- no need to handle any further
                    end
                end
            end
            local xc = xml.command
            if xc then
                xc(e,ec)
                return
            end
        end
    end
    handle = handle or fallbackhandle
    local etg = e.tg
    if etg then
        if e.special then
            local edt = e.dt
            local spc = specialconverter and specialconverter[etg]
            if spc then
                local result = spc(edt[1])
                if result then
                    handle(result)
                else
                    -- no need to handle any further
                end
            elseif etg == "@pi@" then
            --  handle(format("<?%s?>",edt[1]))
                handle("<?" .. edt[1] .. "?>")
            elseif etg == "@cm@" then
            --  handle(format("<!--%s-->",edt[1]))
                handle("<!--" .. edt[1] .. "-->")
            elseif etg == "@cd@" then
            --  handle(format("<![CDATA[%s]]>",edt[1]))
                handle("<![CDATA[" .. edt[1] .. "]]>")
            elseif etg == "@dt@" then
            --  handle(format("<!DOCTYPE %s>",edt[1]))
                handle("<!DOCTYPE " .. edt[1] .. ">")
            elseif etg == "@rt@" then
                serialize(edt,handle,textconverter,attributeconverter,specialconverter,nocommands)
            end
        else
            local ens, eat, edt, ern = e.ns, e.at, e.dt, e.rn
            local ats = eat and next(eat) and { } -- type test maybe faster
            if ats then
                if attributeconverter then
                    for k,v in next, eat do
                        ats[#ats+1] = format('%s=%q',k,attributeconverter(v))
                    end
                else
                    for k,v in next, eat do
                        ats[#ats+1] = format('%s=%q',k,v)
                    end
                end
            end
            if ern and trace_remap and ern ~= ens then
                ens = ern
            end
            if ens ~= "" then
                if edt and #edt > 0 then
                    if ats then
                    --  handle(format("<%s:%s %s>",ens,etg,concat(ats," ")))
                        handle("<" .. ens .. ":" .. etg .. " " .. concat(ats," ") .. ">")
                    else
                    --  handle(format("<%s:%s>",ens,etg))
                        handle("<" .. ens .. ":" .. etg .. ">")
                    end
                    for i=1,#edt do
                        local e = edt[i]
                        if type(e) == "string" then
                            if textconverter then
                                handle(textconverter(e))
                            else
                                handle(e)
                            end
                        else
                            serialize(e,handle,textconverter,attributeconverter,specialconverter,nocommands)
                        end
                    end
                --  handle(format("</%s:%s>",ens,etg))
                    handle("</" .. ens .. ":" .. etg .. ">")
                else
                    if ats then
                    --  handle(format("<%s:%s %s/>",ens,etg,concat(ats," ")))
                        handle("<" .. ens .. ":" .. etg .. " " .. concat(ats," ") .. "/>")
                    else
                    --  handle(format("<%s:%s/>",ens,etg))
                        handle("<" .. ens .. ":" .. etg .. "/>")
                    end
                end
            else
                if edt and #edt > 0 then
                    if ats then
                    --  handle(format("<%s %s>",etg,concat(ats," ")))
                        handle("<" .. etg .. " " .. concat(ats," ") .. ">")
                    else
                    --  handle(format("<%s>",etg))
                        handle("<" .. etg .. ">")
                    end
                    for i=1,#edt do
                        local ei = edt[i]
                        if type(ei) == "string" then
                            if textconverter then
                                handle(textconverter(ei))
                            else
                                handle(ei)
                            end
                        else
                            serialize(ei,handle,textconverter,attributeconverter,specialconverter,nocommands)
                        end
                    end
                --  handle(format("</%s>",etg))
                    handle("</" .. etg .. ">")
                else
                    if ats then
                    --  handle(format("<%s %s/>",etg,concat(ats," ")))
                        handle("<" .. etg .. " " .. concat(ats," ") .. "/>")
                    else
                    --  handle(format("<%s/>",etg))
                        handle("<" .. etg .. "/>")
                    end
                end
            end
        end
    elseif type(e) == "string" then
        if textconverter then
            handle(textconverter(e))
        else
            handle(e)
        end
    else
        for i=1,#e do
            local ei = e[i]
            if type(ei) == "string" then
                if textconverter then
                    handle(textconverter(ei))
                else
                    handle(ei)
                end
            else
                serialize(ei,handle,textconverter,attributeconverter,specialconverter,nocommands)
            end
        end
    end
end

xml.serialize = serialize

function xml.checkbom(root) -- can be made faster
    if root.ri then
        local dt, found = root.dt, false
        for k=1,#dt do
            local v = dt[k]
            if type(v) == "table" and v.special and v.tg == "@pi" and find(v.dt,"xml.*version=") then
                found = true
                break
            end
        end
        if not found then
            insert(dt, 1, { special=true, ns="", tg="@pi@", dt = { "xml version='1.0' standalone='yes'"} } )
            insert(dt, 2, "\n" )
        end
    end
end

--[[ldx--
<p>At the cost of some 25% runtime overhead you can first convert the tree to a string
and then handle the lot.</p>
--ldx]]--

function xml.tostring(root) -- 25% overhead due to collecting
    if root then
        if type(root) == 'string' then
            return root
        elseif next(root) then -- next is faster than type (and >0 test)
            local result = { }
            serialize(root,function(s) result[#result+1] = s end) -- brrr, slow (direct printing is faster)
            return concat(result,"")
        end
    end
    return ""
end

--[[ldx--
<p>The next function operated on the content only and needs a handle function
that accepts a string.</p>
--ldx]]--

function xml.string(e,handle)
    if not handle or (e.special and e.tg ~= "@rt@") then
        -- nothing
    elseif e.tg then
        local edt = e.dt
        if edt then
            for i=1,#edt do
                xml.string(edt[i],handle)
            end
        end
    else
        handle(e)
    end
end

--[[ldx--
<p>How you deal with saving data depends on your preferences. For a 40 MB database
file the timing on a 2.3 Core Duo are as follows (time in seconds):</p>

<lines>
1.3 : load data from file to string
6.1 : convert string into tree
5.3 : saving in file using xmlsave
6.8 : converting to string using xml.tostring
3.6 : saving converted string in file
</lines>

<p>The save function is given below.</p>
--ldx]]--

function xml.save(root,name)
    local f = io.open(name,"w")
    if f then
        xml.serialize(root,function(s) f:write(s) end)
        f:close()
    end
end

--[[ldx--
<p>A few helpers:</p>
--ldx]]--

function xml.body(root)
    return (root.ri and root.dt[root.ri]) or root
end

function xml.text(root)
    return (root and xml.tostring(root)) or ""
end

function xml.content(root) -- bugged
    return (root and root.dt and xml.tostring(root.dt)) or ""
end

function xml.isempty(root, pattern)
    if pattern == "" or pattern == "*" then
        pattern = nil
    end
    if pattern then
        -- todo
        return false
    else
        return not root or not root.dt or #root.dt == 0 or root.dt == ""
    end
end

--[[ldx--
<p>The next helper erases an element but keeps the table as it is,
and since empty strings are not serialized (effectively) it does
not harm. Copying the table would take more time. Usage:</p>

<typing>
dt[k] = xml.empty() or xml.empty(dt,k)
</typing>
--ldx]]--

function xml.empty(dt,k)
    if dt and k then
        dt[k] = ""
        return dt[k]
    else
        return ""
    end
end

--[[ldx--
<p>The next helper assigns a tree (or string). Usage:</p>

<typing>
dt[k] = xml.assign(root) or xml.assign(dt,k,root)
</typing>
--ldx]]--

function xml.assign(dt,k,root)
    if dt and k then
        dt[k] = (type(root) == "table" and xml.body(root)) or root
        return dt[k]
    else
        return xml.body(root)
    end
end

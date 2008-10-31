if not modules then modules = { } end modules ['l-xml'] = {
    version   = 1.001,
    comment   = "this module is the basis for the lxml-* ones",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- RJ: key=value ... lpeg.Ca(lpeg.Cc({}) * (pattern-producing-key-and-value / rawset)^0)

-- some code may move to l-xmlext
-- some day we will really compile the lpaths (just construct functions)

--[[ldx--
<p>The parser used here is inspired by the variant discussed in the lua book, but
handles comment and processing instructions, has a different structure, provides
parent access; a first version used different tricky but was less optimized to we
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
tex = tex or { }

xml.trace_lpath = false
xml.trace_print = false
xml.trace_remap = false

local format, concat, remove, insert, type, next = string.format, table.concat, table.remove, table.insert, type, next

--~ local pairs, next, type = pairs, next, type

-- todo: some things per xml file, like namespace remapping

--[[ldx--
<p>First a hack to enable namespace resolving. A namespace is characterized by
a <l n='url'/>. The following function associates a namespace prefix with a
pattern. We use <l n='lpeg'/>, which in this case is more than twice as fast as a
find based solution where we loop over an array of patterns. Less code and
much cleaner.</p>
--ldx]]--

xml.xmlns = xml.xmlns or { }

do

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
        check = check + lpeg.C(lpeg.P(pattern:lower())) / namespace
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
        local ns = parse:match(url:lower())
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
         return parse:match(url:lower()) or ""
    end

    --[[ldx--
    <p>A namespace in an element can be remapped onto the registered
    one efficiently by using the <t>xml.xmlns</t> table.</p>
    --ldx]]--

end

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

do

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
        errorstr = "garbage at the end of the file: " .. txt:gsub("([ \n\r\t]*)","")
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

    function entity(k,v) entities[k] = v end

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

    xml.error_handler = (logs and logs.report) or (input and input.report) or print

end

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

do

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

end

--[[ldx--
<p>In <l n='context'/> serializing the tree or parts of the tree is a major
actitivity which is why the following function is pretty optimized resulting
in a few more lines of code than needed. The variant that uses the formatting
function for all components is about 15% slower than the concatinating
alternative.</p>
--ldx]]--

do

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
                        for k,v in pairs(eat) do
                            ats[#ats+1] = format('%s=%q',k,attributeconverter(v))
                        end
                    else
                        for k,v in pairs(eat) do
                            ats[#ats+1] = format('%s=%q',k,v)
                        end
                    end
                end
                if ern and xml.trace_remap and ern ~= ens then
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
            for k,v in ipairs(dt) do
                if type(v) == "table" and v.special and v.tg == "@pi" and v.dt:find("xml.*version=") then
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
                serialize(root,function(s) result[#result+1] = s end)
                return concat(result,"")
            end
        end
        return ""
    end

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

--[[ldx--
<p>We've now arrived at an intersting part: accessing the tree using a subset
of <l n='xpath'/> and since we're not compatible we call it <l n='lpath'/>. We
will explain more about its usage in other documents.</p>
--ldx]]--

local lpathcalls  = 0 -- statisctics
local lpathcached = 0 -- statisctics

do

    xml.functions   = xml.functions   or { }
    xml.expressions = xml.expressions or { }

    local functions   = xml.functions
    local expressions = xml.expressions

    local actions = {
        [10] = "stay",
        [11] = "parent",
        [12] = "subtree root",
        [13] = "document root",
        [14] = "any",
        [15] = "many",
        [16] = "initial",
        [20] = "match",
        [21] = "match one of",
        [22] = "match and attribute eq",
        [23] = "match and attribute ne",
        [24] = "match one of and attribute eq",
        [25] = "match one of and attribute ne",
        [27] = "has attribute",
        [28] = "has value",
        [29] = "fast match",
        [30] = "select",
        [31] = "expression",
        [40] = "processing instruction",
    }

    -- a rather dumb lpeg

    local P, S, R, C, V, Cc = lpeg.P, lpeg.S, lpeg.R, lpeg.C, lpeg.V, lpeg.Cc

    -- instead of using functions we just parse a few names which saves a call
    -- later on

    local lp_position  = P("position()") / "ps"
    local lp_index     = P("index()")    / "id"
    local lp_text      = P("text()")     / "tx"
    local lp_name      = P("name()")     / "(ns~='' and ns..':'..tg)" -- "((rt.ns~='' and rt.ns..':'..rt.tg) or '')"
    local lp_tag       = P("tag()")      / "tg" -- (rt.tg or '')
    local lp_ns        = P("ns()")       / "ns" -- (rt.ns or '')
    local lp_noequal   = P("!=")         / "~=" + P("<=") + P(">=") + P("==")
    local lp_doequal   = P("=")          / "=="
    local lp_attribute = P("@")          / "" * Cc("(at['") * R("az","AZ","--","__")^1 * Cc("'] or '')")

    local lp_lua_function  = C(R("az","AZ","--","__")^1 * (P(".") * R("az","AZ","--","__")^1)^1) * P("(") / function(t) -- todo: better . handling
        return t .. "("
    end

    local lp_function  = C(R("az","AZ","--","__")^1) * P("(") / function(t) -- todo: better . handling
        if expressions[t] then
            return "expressions." .. t .. "("
        else
            return "expressions.error("
        end
    end

    local lparent  = lpeg.P("(")
    local rparent  = lpeg.P(")")
    local noparent = 1 - (lparent+rparent)
    local nested   = lpeg.P{lparent * (noparent + lpeg.V(1))^0 * rparent}
    local value    = lpeg.P(lparent * lpeg.C((noparent + nested)^0) * rparent) -- lpeg.P{"("*C(((1-S("()"))+V(1))^0)*")"}

    -- if we use a dedicated namespace then we don't need to pass rt and k

    local lp_special = (C(P("name")+P("text")+P("tag"))) * value / function(t,s)
        if expressions[t] then
            if s then
                return "expressions." .. t .. "(r,k," .. s ..")"
            else
                return "expressions." .. t .. "(r,k)"
            end
        else
            return "expressions.error(" .. t .. ")"
        end
    end

    local converter = lpeg.Cs ( (
        lp_position +
        lp_index +
        lp_text + lp_name + -- fast one
        lp_special +
        lp_noequal + lp_doequal +
        lp_attribute +
        lp_lua_function +
        lp_function +
    1 )^1 )

    -- expressions,root,rootdt,k,e,edt,ns,tg,idx,hsh[tg] or 1

    local template = [[
        return function(expressions,r,d,k,e,dt,ns,tg,id,ps)
            local at, tx = e.at or { }, dt[1] or ""
            return %s
        end
    ]]

    local function make_expression(str)
        str = converter:match(str)
        return str, loadstring(format(template,str))()
    end

    local map = { }

    local space             = S(' \r\n\t')
    local squote            = S("'")
    local dquote            = S('"')
    local lparent           = P('(')
    local rparent           = P(')')
    local atsign            = P('@')
    local lbracket          = P('[')
    local rbracket          = P(']')
    local exclam            = P('!')
    local period            = P('.')
    local eq                = P('==') + P('=')
    local ne                = P('<>') + P('!=')
    local star              = P('*')
    local slash             = P('/')
    local colon             = P(':')
    local bar               = P('|')
    local hat               = P('^')
    local valid             = R('az', 'AZ', '09') + S('_-')
--~     local name_yes          = C(valid^1 + star) * colon * C(valid^1 + star) -- permits ns:* *:tg *:*
--~     local name_nop          = C(P(true)) * C(valid^1)
    local name_yes          = C(valid^1 + star) * colon * C(valid^1 + star) -- permits ns:* *:tg *:*
    local name_nop          = Cc("*") * C(valid^1)
    local name              = name_yes + name_nop
    local number            = C((S('+-')^0 * R('09')^1)) / tonumber
    local names             = (bar^0 * name)^1
    local morenames         = name * (bar^0 * name)^1
    local instructiontag    = P('pi::')
    local spacing           = C(space^0)
    local somespace         = space^1
    local optionalspace     = space^0
    local text              = C(valid^0)
    local value             = (squote * C((1 - squote)^0) * squote) + (dquote * C((1 - dquote)^0) * dquote)
    local empty             = 1-slash

    local is_eq             = lbracket * atsign * name * eq * value * rbracket
    local is_ne             = lbracket * atsign * name * ne * value * rbracket
    local is_attribute      = lbracket * atsign * name              * rbracket
    local is_value          = lbracket *          value             * rbracket
    local is_number         = lbracket *          number            * rbracket

    local nobracket         = 1-(lbracket+rbracket)  -- must be improved
    local is_expression     = lbracket * C(((C(nobracket^1))/make_expression)) * rbracket

    local is_expression     = lbracket * (C(nobracket^1))/make_expression * rbracket

    local is_one            =          name
    local is_none           = exclam * name
    local is_one_of         =          ((lparent * names * rparent) + morenames)
    local is_none_of        = exclam * ((lparent * names * rparent) + morenames)

    local stay                     = (period                )
    local parent                   = (period * period       ) / function(   ) map[#map+1] = { 11             } end
    local subtreeroot              = (slash + hat           ) / function(   ) map[#map+1] = { 12             } end
    local documentroot             = (hat * hat             ) / function(   ) map[#map+1] = { 13             } end
    local any                      = (star                  ) / function(   ) map[#map+1] = { 14             } end
    local many                     = (star * star           ) / function(   ) map[#map+1] = { 15             } end
    local initial                  = (hat * hat * hat       ) / function(   ) map[#map+1] = { 16             } end

    local match                    = (is_one                ) / function(...) map[#map+1] = { 20, true , ... } end
    local match_one_of             = (is_one_of             ) / function(...) map[#map+1] = { 21, true , ... } end
    local dont_match               = (is_none               ) / function(...) map[#map+1] = { 20, false, ... } end
    local dont_match_one_of        = (is_none_of            ) / function(...) map[#map+1] = { 21, false, ... } end

    local match_and_eq             = (is_one     * is_eq    ) / function(...) map[#map+1] = { 22, true , ... } end
    local match_and_ne             = (is_one     * is_ne    ) / function(...) map[#map+1] = { 23, true , ... } end
    local dont_match_and_eq        = (is_none    * is_eq    ) / function(...) map[#map+1] = { 22, false, ... } end
    local dont_match_and_ne        = (is_none    * is_ne    ) / function(...) map[#map+1] = { 23, false, ... } end

    local match_one_of_and_eq      = (is_one_of  * is_eq    ) / function(...) map[#map+1] = { 24, true , ... } end
    local match_one_of_and_ne      = (is_one_of  * is_ne    ) / function(...) map[#map+1] = { 25, true , ... } end
    local dont_match_one_of_and_eq = (is_none_of * is_eq    ) / function(...) map[#map+1] = { 24, false, ... } end
    local dont_match_one_of_and_ne = (is_none_of * is_ne    ) / function(...) map[#map+1] = { 25, false, ... } end

    local has_attribute            = (is_one  * is_attribute) / function(...) map[#map+1] = { 27, true , ... } end
    local has_value                = (is_one  * is_value    ) / function(...) map[#map+1] = { 28, true , ... } end
    local dont_has_attribute       = (is_none * is_attribute) / function(...) map[#map+1] = { 27, false, ... } end
    local dont_has_value           = (is_none * is_value    ) / function(...) map[#map+1] = { 28, false, ... } end
    local position                 = (is_one  * is_number   ) / function(...) map[#map+1] = { 30, true,  ... } end
    local dont_position            = (is_none * is_number   ) / function(...) map[#map+1] = { 30, false, ... } end

    local expression               = (is_one  * is_expression)/ function(...) map[#map+1] = { 31, true,  ... } end
    local dont_expression          = (is_none * is_expression)/ function(...) map[#map+1] = { 31, false, ... } end

    local self_expression          = (         is_expression) / function(...) if #map == 0 then map[#map+1] = { 11 } end
                                                                              map[#map+1] = { 31, true,  "*", "*", ... } end
    local dont_self_expression     = (exclam * is_expression) / function(...) if #map == 0 then map[#map+1] = { 11 } end
                                                                              map[#map+1] = { 31, false, "*", "*", ... } end

    local instruction              = (instructiontag * text ) / function(...) map[#map+1] = { 40,        ... } end
    local nothing                  = (empty                 ) / function(   ) map[#map+1] = { 15             } end -- 15 ?
    local crap                     = (1-slash)^1

    -- a few ugly goodies:

    local docroottag               = P('^^')             / function(   ) map[#map+1] = { 12             } end
    local subroottag               = P('^')              / function(   ) map[#map+1] = { 13             } end
    local roottag                  = P('root::')         / function(   ) map[#map+1] = { 12             } end
    local parenttag                = P('parent::')       / function(   ) map[#map+1] = { 11             } end
    local childtag                 = P('child::')
    local selftag                  = P('self::')

    -- there will be more and order will be optimized

    local selector = (
        instruction +
--~         many + any + -- brrr, not here !
        parent + stay +
        dont_position + position +
        dont_match_one_of_and_eq + dont_match_one_of_and_ne +
        match_one_of_and_eq + match_one_of_and_ne +
        dont_match_and_eq + dont_match_and_ne +
        match_and_eq + match_and_ne +
        dont_expression + expression +
        dont_self_expression + self_expression +
        has_attribute + has_value +
        dont_match_one_of + match_one_of +
        dont_match + match +
        many + any +
        crap + empty
    )

    local grammar = P { "startup",
        startup  = (initial + documentroot + subtreeroot + roottag + docroottag + subroottag)^0 * V("followup"),
        followup = ((slash + parenttag + childtag + selftag)^0 * selector)^1,
    }

    local function compose(str)
        if not str or str == "" then
            -- wildcard
            return true
        elseif str == '/' then
            -- root
            return false
        else
            map = { }
            grammar:match(str)
            if #map == 0 then
                return true
            else
                local m = map[1][1]
                if #map == 1 then
                    if m == 14 or m == 15 then
                        -- wildcard
                        return true
                    elseif m == 12 then
                        -- root
                        return false
                    end
                elseif #map == 2 and m == 12 and map[2][1] == 20 then
                --  return { { 29, map[2][2], map[2][3], map[2][4], map[2][5] } }
                    map[2][1] = 29
                    return { map[2] }
                end
                if m ~= 11 and m ~= 12 and m ~= 13 and m ~= 14 and m ~= 15 and m ~= 16 then
                    insert(map, 1, { 16 })
                end
            --  print((table.serialize(map)):gsub("[ \n]+"," "))
                return map
            end
        end
    end

    local cache = { }

    function xml.lpath(pattern,trace)
        lpathcalls = lpathcalls + 1
        if type(pattern) == "string" then
            local result = cache[pattern]
            if result == nil then -- can be false which is valid -)
                result = compose(pattern)
                cache[pattern] = result
                lpathcached = lpathcached + 1
            end
            if trace or xml.trace_lpath then
                xml.lshow(result)
            end
            return result
        else
            return pattern
        end
    end

    function lpath_cached_patterns()
        return cache
    end

    local fallbackreport = (texio and texio.write) or io.write

    function xml.lshow(pattern,report)
        report = report or fallbackreport
        local lp = xml.lpath(pattern)
        if lp == false then
            report(" -: root\n")
        elseif lp == true then
            report(" -: wildcard\n")
        else
            if type(pattern) == "string" then
                report(format("pattern: %s\n",pattern))
            end
            for k=1,#lp do
                local v = lp[k]
                if #v > 1 then
                    local t = { }
                    for i=2,#v do
                        local vv = v[i]
                        if type(vv) == "string" then
                            t[#t+1] = (vv ~= "" and vv) or "#"
                        elseif type(vv) == "boolean" then
                            t[#t+1] = (vv and "==") or "<>"
                        end
                    end
                    report(format("%2i: %s %s -> %s\n", k,v[1],actions[v[1]],concat(t," ")))
                else
                    report(format("%2i: %s %s\n", k,v[1],actions[v[1]]))
                end
            end
        end
    end

    function xml.xshow(e,...) -- also handy when report is given, use () to isolate first e
        local t = { ... }
        local report = (type(t[#t]) == "function" and t[#t]) or fallbackreport
        if e == nil then
            report("<!-- no element -->\n")
        elseif type(e) ~= "table" then
            report(tostring(e))
        elseif e.tg then
            report(tostring(e) .. "\n")
        else
            for i=1,#e do
                report(tostring(e[i]) .. "\n")
            end
        end
    end

end

--[[ldx--
<p>An <l n='lpath'/> is converted to a table with instructions for traversing the
tree. Hoever, simple cases are signaled by booleans. Because we don't know in
advance what we want to do with the found element the handle gets three arguments:</p>

<lines>
<t>r</t> : the root element of the data table
<t>d</t> : the data table of the result
<t>t</t> : the index in the data table of the result
</lines>

<p> Access to the root and data table makes it possible to construct insert and delete
functions.</p>
--ldx]]--

do

    local functions   = xml.functions
    local expressions = xml.expressions

    expressions.contains = string.find
    expressions.find     = string.find
    expressions.upper    = string.upper
    expressions.lower    = string.lower
    expressions.number   = tonumber
    expressions.boolean  = toboolean

    expressions.oneof = function(s,...) -- slow
        local t = {...} for i=1,#t do if s == t[i] then return true end end return false
    end

    expressions.error = function(str)
        xml.error_handler("unknown function in lpath expression",str or "?")
        return false
    end

    functions.text = function(root,k,n) -- unchecked, maybe one deeper
        local t = type(t)
        if t == "string" then
            return t
        else -- todo n
            local rdt = root.dt
            return (rdt and rdt[k]) or root[k] or ""
        end
    end

    functions.name = function(d,k,n) -- ns + tg
        local found = false
        n = n or 0
        if not k then
            -- not found
        elseif n == 0 then
            local dk = d[k]
            found = dk and (type(dk) == "table") and dk
        elseif n < 0 then
            for i=k-1,1,-1 do
                local di = d[i]
                if type(di) == "table" then
                    if n == -1 then
                        found = di
                        break
                    else
                        n = n + 1
                    end
                end
            end
        else
            for i=k+1,#d,1 do
                local di = d[i]
                if type(di) == "table" then
                    if n == 1 then
                        found = di
                        break
                    else
                        n = n - 1
                    end
                end
            end
        end
        if found then
            local ns, tg = found.rn or found.ns or "", found.tg
            if ns ~= "" then
                return ns .. ":" .. tg
            else
                return tg
            end
        else
            return ""
        end
    end

    functions.tag = function(d,k,n) -- only tg
        local found = false
        n = n or 0
        if not k then
            -- not found
        elseif n == 0 then
            local dk = d[k]
            found = dk and (type(dk) == "table") and dk
        elseif n < 0 then
            for i=k-1,1,-1 do
                local di = d[i]
                if type(di) == "table" then
                    if n == -1 then
                        found = di
                        break
                    else
                        n = n + 1
                    end
                end
            end
        else
            for i=k+1,#d,1 do
                local di = d[i]
                if type(di) == "table" then
                    if n == 1 then
                        found = di
                        break
                    else
                        n = n - 1
                    end
                end
            end
        end
        return (found and found.tg) or ""
    end

    expressions.text = functions.text
    expressions.name = functions.name
    expressions.tag  = functions.tag

    local function traverse(root,pattern,handle,reverse,index,parent,wildcard) -- multiple only for tags, not for namespaces
        if not root then -- error
            return false
        elseif pattern == false then -- root
            handle(root,root.dt,root.ri)
            return false
        elseif pattern == true then -- wildcard
            local rootdt = root.dt
            if rootdt then
                local start, stop, step = 1, #rootdt, 1
                if reverse then
                    start, stop, step = stop, start, -1
                end
                for k=start,stop,step do
                    if handle(root,rootdt,root.ri or k)            then return false end
                    if not traverse(rootdt[k],true,handle,reverse) then return false end
                end
            end
            return false
        elseif root.dt then
            index = index or 1
            local action = pattern[index]
            local command = action[1]
            if command == 29 then -- fast case /oeps
                local rootdt = root.dt
                for k=1,#rootdt do
                    local e = rootdt[k]
                    local tg = e.tg
                    if e.tg then
                        local ns = e.rn or e.ns
                        local ns_a, tg_a = action[3], action[4]
                        local matched = (ns_a == "*" or ns == ns_a) and (tg_a == "*" or tg == tg_a)
                        if not action[2] then matched = not matched end
                        if matched then
                            if handle(root,rootdt,k) then return false end
                        end
                    end
                end
            elseif command == 11 then -- parent
                local ep = root.__p__ or parent
                if index < #pattern then
                    if not traverse(ep,pattern,handle,reverse,index+1,root) then return false end
                elseif handle(root,rootdt,k) then
                    return false
                end
            else
                if (command == 16 or command == 12) and index == 1 then -- initial
                --  wildcard = true
                    wildcard = command == 16 -- ok?
                    index = index + 1
                    action = pattern[index]
                    command = action and action[1] or 0 -- something is wrong
                end
                if command == 11 then -- parent
                    local ep = root.__p__ or parent
                    if index < #pattern then
                        if not traverse(ep,pattern,handle,reverse,index+1,root) then return false end
                    elseif handle(root,rootdt,k) then
                        return false
                    end
                else
                    local rootdt = root.dt
                    local start, stop, step, n, dn = 1, #rootdt, 1, 0, 1
                    if command == 30 then
                        if action[5] < 0 then
                            start, stop, step = stop, start, -1
                            dn = -1
                        end
                    elseif reverse and index == #pattern then
                        start, stop, step = stop, start, -1
                    end
                    local idx = 0
                    local hsh = { } -- this will slooow down the lot
                    for k=start,stop,step do -- we used to have functions for all but a case is faster
                        local e = rootdt[k]
                        local ns, tg = e.rn or e.ns, e.tg
                        if tg then
                         -- we can optimize this for simple searches, but it probably does not pay off
                            hsh[tg] = (hsh[tg] or 0) + 1
                            idx = idx + 1
                            if command == 30 then
                                local ns_a, tg_a = action[3], action[4]
                                if tg == tg_a then
                                    matched = ns_a == "*" or ns == ns_a
                                elseif tg_a == '*' then
                                    matched, multiple = ns_a == "*" or ns == ns_a, true
                                else
                                    matched = false
                                end
                                if not action[2] then matched = not matched end
                                if matched then
                                    n = n + dn
                                    if n == action[5] then
                                        if index == #pattern then
                                            if handle(root,rootdt,root.ri or k) then return false end
                                        else
                                            if not traverse(e,pattern,handle,reverse,index+1,root) then return false end
                                        end
                                        break
                                    end
                                elseif wildcard then
                                    if not traverse(e,pattern,handle,reverse,index,root,true) then return false end
                                end
                            else
                                local matched, multiple = false, false
                                if command == 20 then -- match
                                    local ns_a, tg_a = action[3], action[4]
                                    if tg == tg_a then
                                        matched = ns_a == "*" or ns == ns_a
                                    elseif tg_a == '*' then
                                        matched, multiple = ns_a == "*" or ns == ns_a, true
                                    else
                                        matched = false
                                    end
                                    if not action[2] then matched = not matched end
                                elseif command == 21 then -- match one of
                                    multiple = true
                                    for i=3,#action,2 do
                                        local ns_a, tg_a = action[i], action[i+1]
                                        if (ns_a == "*" or ns == ns_a) and (tg == "*" or tg == tg_a) then
                                            matched = true
                                            break
                                        end
                                    end
                                    if not action[2] then matched = not matched end
                                elseif command == 22 then -- eq
                                    local ns_a, tg_a = action[3], action[4]
                                    if tg == tg_a then
                                        matched = ns_a == "*" or ns == ns_a
                                    elseif tg_a == '*' then
                                        matched, multiple = ns_a == "*" or ns == ns_a, true
                                    else
                                        matched = false
                                    end
                                    matched = matched and e.at[action[6]] == action[7]
                                elseif command == 23 then -- ne
                                    local ns_a, tg_a = action[3], action[4]
                                    if tg == tg_a then
                                        matched = ns_a == "*" or ns == ns_a
                                    elseif tg_a == '*' then
                                        matched, multiple = ns_a == "*" or ns == ns_a, true
                                    else
                                        matched = false
                                    end
                                    if not action[2] then matched = not matched end
                                    matched = mached and e.at[action[6]] ~= action[7]
                                elseif command == 24 then -- one of eq
                                    multiple = true
                                    for i=3,#action-2,2 do
                                        local ns_a, tg_a = action[i], action[i+1]
                                        if (ns_a == "*" or ns == ns_a) and (tg == "*" or tg == tg_a) then
                                            matched = true
                                            break
                                        end
                                    end
                                    if not action[2] then matched = not matched end
                                    matched = matched and e.at[action[#action-1]] == action[#action]
                                elseif command == 25 then -- one of ne
                                    multiple = true
                                    for i=3,#action-2,2 do
                                        local ns_a, tg_a = action[i], action[i+1]
                                        if (ns_a == "*" or ns == ns_a) and (tg == "*" or tg == tg_a) then
                                            matched = true
                                            break
                                        end
                                    end
                                    if not action[2] then matched = not matched end
                                    matched = matched and e.at[action[#action-1]] ~= action[#action]
                                elseif command == 27 then -- has attribute
                                    local ns_a, tg_a = action[3], action[4]
                                    if tg == tg_a then
                                        matched = ns_a == "*" or ns == ns_a
                                    elseif tg_a == '*' then
                                        matched, multiple = ns_a == "*" or ns == ns_a, true
                                    else
                                        matched = false
                                    end
                                    if not action[2] then matched = not matched end
                                    matched = matched and e.at[action[5]]
                                elseif command == 28 then -- has value
                                    local edt, ns_a, tg_a = e.dt, action[3], action[4]
                                    if tg == tg_a then
                                        matched = ns_a == "*" or ns == ns_a
                                    elseif tg_a == '*' then
                                        matched, multiple = ns_a == "*" or ns == ns_a, true
                                    else
                                        matched = false
                                    end
                                    if not action[2] then matched = not matched end
                                    matched = matched and edt and edt[1] == action[5]
                                elseif command == 31 then
                                    local edt, ns_a, tg_a = e.dt, action[3], action[4]
                                    if tg == tg_a then
                                        matched = ns_a == "*" or ns == ns_a
                                    elseif tg_a == '*' then
                                        matched, multiple = ns_a == "*" or ns == ns_a, true
                                    else
                                        matched = false
                                    end
                                    if not action[2] then matched = not matched end
                                    if matched then
                                        matched = action[6](expressions,root,rootdt,k,e,edt,ns,tg,idx,hsh[tg] or 1)
                                    end
                                end
                                if matched then -- combine tg test and at test
                                    if index == #pattern then
                                        if handle(root,rootdt,root.ri or k) then return false end
                                        if wildcard then
                                            if multiple then
                                                if not traverse(e,pattern,handle,reverse,index,root,true) then return false end
                                            else
                                             -- maybe or multiple; anyhow, check on (section|title) vs just section and title in example in lxml
                                                if not traverse(e,pattern,handle,reverse,index,root) then return false end
                                            end
                                        end
                                    else
                                        if not traverse(e,pattern,handle,reverse,index+1,root) then return false end
                                    end
                                elseif command == 14 then -- any
                                    if index == #pattern then
                                        if handle(root,rootdt,root.ri or k) then return false end
                                    else
                                        if not traverse(e,pattern,handle,reverse,index+1,root) then return false end
                                    end
                                elseif command == 15 then -- many
                                    if index == #pattern then
                                        if handle(root,rootdt,root.ri or k) then return false end
                                    else
                                        if not traverse(e,pattern,handle,reverse,index+1,root,true) then return false end
                                    end
                                -- not here : 11
                                elseif command == 11 then -- parent
                                    local ep = e.__p__ or parent
                                    if index < #pattern then
                                        if not traverse(ep,pattern,handle,reverse,root,index+1) then return false end
                                    elseif handle(root,rootdt,k) then
                                        return false
                                    end
                                elseif command == 40 and e.special and tg == "@pi@" then -- pi
                                    local pi = action[2]
                                    if pi ~= "" then
                                        local pt = e.dt[1]
                                        if pt and pt:find(pi) then
                                            if handle(root,rootdt,k) then
                                                return false
                                            end
                                        end
                                    elseif handle(root,rootdt,k) then
                                        return false
                                    end
                                elseif wildcard then
                                    if not traverse(e,pattern,handle,reverse,index,root,true) then return false end
                                end
                            end
                        else
                            -- not here : 11
                            if command == 11 then -- parent
                                local ep = e.__p__ or parent
                                if index < #pattern then
                                    if not traverse(ep,pattern,handle,reverse,index+1,root) then return false end
                                elseif handle(root,rootdt,k) then
                                    return false
                                end
                                break -- else loop
                            end
                        end
                    end
                end
            end
        end
        return true
    end

    xml.traverse = traverse

end

--[[ldx--
<p>Next come all kind of locators and manipulators. The most generic function here
is <t>xml.filter(root,pattern)</t>. All registers functions in the filters namespace
can be path of a search path, as in:</p>

<typing>
local r, d, k = xml.filter(root,"/a/b/c/position(4)"
</typing>
--ldx]]--

do

    local traverse, lpath, convert = xml.traverse, xml.lpath, xml.convert

    xml.filters = { }

    function xml.filters.default(root,pattern)
        local rt, dt, dk
        traverse(root, lpath(pattern), function(r,d,k) rt,dt,dk = r,d,k return true end)
        return dt and dt[dk], rt, dt, dk
    end
    function xml.filters.attributes(root,pattern,arguments)
        local rt, dt, dk
        traverse(root, lpath(pattern), function(r,d,k) rt, dt, dk = r, d, k return true end)
        local ekat = (dt and dt[dk] and dt[dk].at) or (rt and rt.at)
        if ekat then
            if arguments then
                return ekat[arguments] or "", rt, dt, dk
            else
                return ekat, rt, dt, dk
            end
        else
            return { }, rt, dt, dk
        end
    end
    function xml.filters.reverse(root,pattern)
        local rt, dt, dk
        traverse(root, lpath(pattern), function(r,d,k) rt,dt,dk = r,d,k return true end, 'reverse')
        return dt and dt[dk], rt, dt, dk
    end
    function xml.filters.count(root,pattern,everything)
        local n = 0
        traverse(root, lpath(pattern), function(r,d,t)
            if everything or type(d[t]) == "table" then
                n = n + 1
            end
        end)
        return n
    end
    function xml.filters.elements(root, pattern) -- == all
        local t = { }
        traverse(root, lpath(pattern), function(r,d,k)
            local e = d[k]
            if e then
                t[#t+1] = e
            end
        end)
        return t
    end
    function xml.filters.texts(root, pattern)
        local t = { }
        traverse(root, lpath(pattern), function(r,d,k)
            local e = d[k]
            if e and e.dt then
                t[#t+1] = e.dt
            end
        end)
        return t
    end
    function xml.filters.first(root,pattern)
        local rt, dt, dk
        traverse(root, lpath(pattern), function(r,d,k) rt,dt,dk = r,d,k return true end)
        return dt and dt[dk], rt, dt, dk
    end
    function xml.filters.last(root,pattern)
        local rt, dt, dk
        traverse(root, lpath(pattern), function(r,d,k) rt,dt,dk = r,d,k return true end, 'reverse')
        return dt and dt[dk], rt, dt, dk
    end
    function xml.filters.index(root,pattern,arguments)
        local rt, dt, dk, reverse, i = nil, nil, nil, false, tonumber(arguments or '1') or 1
        if i and i ~= 0 then
            if i < 0 then
                reverse, i = true, -i
            end
            traverse(root, lpath(pattern), function(r,d,k) rt, dt, dk, i = r, d, k, i-1 return i == 0 end, reverse)
            if i == 0 then
                return dt and dt[dk], rt, dt, dk
            end
        end
        return nil, nil, nil, nil
    end
    function xml.filters.attribute(root,pattern,arguments)
        local rt, dt, dk
        traverse(root, lpath(pattern), function(r,d,k) rt, dt, dk = r, d, k return true end)
        local ekat = (dt and dt[dk] and dt[dk].at) or (rt and rt.at)
        return (ekat and (ekat[arguments] or ekat[arguments:gsub("^([\"\'])(.*)%1$","%2")])) or ""
    end
    function xml.filters.text(root,pattern,arguments) -- ?? why index, tostring slow
        local dtk, rt, dt, dk = xml.filters.index(root,pattern,arguments)
        if dtk then -- n
            local dtkdt = dtk.dt
            if not dtkdt then
                return "", rt, dt, dk
            elseif #dtkdt == 1 and type(dtkdt[1]) == "string" then
                return dtkdt[1], rt, dt, dk
            else
                return xml.tostring(dtkdt), rt, dt, dk
            end
        else
            return "", rt, dt, dk
        end
    end
    function xml.filters.tag(root,pattern,n)
        local tag = ""
        traverse(root, lpath(pattern), function(r,d,k)
            tag = xml.functions.tag(d,k,n and tonumber(n))
            return true
        end)
        return tag
    end
    function xml.filters.name(root,pattern,n)
        local tag = ""
        traverse(root, lpath(pattern), function(r,d,k)
            tag = xml.functions.name(d,k,n and tonumber(n))
            return true
        end)
        return tag
    end

    --[[ldx--
    <p>For splitting the filter function from the path specification, we can
    use string matching or lpeg matching. Here the difference in speed is
    neglectable but the lpeg variant is more robust.</p>
    --ldx]]--

    --  not faster but hipper ... although ... i can't get rid of the trailing / in the path

    local P, S, R, C, V, Cc = lpeg.P, lpeg.S, lpeg.R, lpeg.C, lpeg.V, lpeg.Cc

    local slash     = P('/')
    local name      = (R("az","AZ","--","__"))^1
    local path      = C(((1-slash)^0 * slash)^1)
    local argument  = P { "(" * C(((1 - S("()")) + V(1))^0) * ")" }
    local action    = Cc(1) * path * C(name) * argument
    local attribute = Cc(2) * path * P('@') * C(name)
    local direct    = Cc(3) * Cc("../*") * slash^0 * C(name) * argument

    local parser    = direct + action + attribute

    local filters          = xml.filters
    local attribute_filter = xml.filters.attributes
    local default_filter   = xml.filters.default

    -- todo: also hash, could be gc'd

    function xml.filter(root,pattern)
        local kind, a, b, c = parser:match(pattern)
--~ if xml.trace_lpath then
--~     print(pattern,kind,a,b,c)
--~ end
        if kind == 1 or kind == 3 then
            return (filters[b] or default_filter)(root,a,c)
        elseif kind == 2 then
            return attribute_filter(root,a,b)
        else
            return default_filter(root,pattern)
        end
    end

    --~     slightly faster, but first we need a proper test file
    --~
    --~     local hash = { }
    --~
    --~     function xml.filter(root,pattern)
    --~         local h = hash[pattern]
    --~         if not h then
    --~             local kind, a, b, c = parser:match(pattern)
    --~             if kind == 1 then
    --~                 h = { kind, filters[b] or default_filter, a, b, c }
    --~             elseif kind == 2 then
    --~                 h = { kind, attribute_filter, a, b, c }
    --~             else
    --~                 h = { kind, default_filter, a, b, c }
    --~             end
    --~             hash[pattern] = h
    --~         end
    --~         local kind = h[1]
    --~         if kind == 1 then
    --~             return h[2](root,h[2],h[4])
    --~         elseif kind == 2 then
    --~             return h[2](root,h[2],h[3])
    --~         else
    --~             return h[2](root,pattern)
    --~         end
    --~     end

    --[[ldx--
    <p>The following functions collect elements and texts.</p>
    --ldx]]--

    -- still somewhat bugged

    function xml.collect_elements(root, pattern, ignorespaces)
        local rr, dd = { }, { }
        traverse(root, lpath(pattern), function(r,d,k)
            local dk = d and d[k]
            if dk then
                if ignorespaces and type(dk) == "string" and dk:find("[^%S]") then
                    -- ignore
                else
                    local n = #rr+1
                    rr[n], dd[n] = r, dk
                end
            end
        end)
        return dd, rr
    end

    function xml.collect_texts(root, pattern, flatten)
        local t = { } -- no r collector
        traverse(root, lpath(pattern), function(r,d,k)
            if d then
                local ek = d[k]
                local tx = ek and ek.dt
                if flatten then
                    if tx then
                        t[#t+1] = xml.tostring(tx) or ""
                    else
                        t[#t+1] = ""
                    end
                else
                    t[#t+1] = tx or ""
                end
            else
                t[#t+1] = ""
            end
        end)
        return t
    end

    function xml.collect_tags(root, pattern, nonamespace)
        local t = { }
        xml.traverse(root, xml.lpath(pattern), function(r,d,k)
            local dk = d and d[k]
            if dk and type(dk) == "table" then
                local ns, tg = e.ns, e.tg
                if nonamespace then
                    t[#t+1] = tg -- if needed we can return an extra table
                elseif ns == "" then
                    t[#t+1] = tg
                else
                    t[#t+1] = ns .. ":" .. tg
                end
            end
        end)
        return #t > 0 and {}
    end

    --[[ldx--
    <p>Often using an iterators looks nicer in the code than passing handler
    functions. The <l n='lua'/> book describes how to use coroutines for that
    purpose (<url href='http://www.lua.org/pil/9.3.html'/>). This permits
    code like:</p>

    <typing>
    for r, d, k in xml.elements(xml.load('text.xml'),"title") do
        print(d[k])
    end
    </typing>

    <p>Which will print all the titles in the document. The iterator variant takes
    1.5 times the runtime of the function variant which is due to the overhead in
    creating the wrapper. So, instead of:</p>

    <typing>
    function xml.filters.first(root,pattern)
        for rt,dt,dk in xml.elements(root,pattern)
            return dt and dt[dk], rt, dt, dk
        end
        return nil, nil, nil, nil
    end
    </typing>

    <p>We use the function variants in the filters.</p>
    --ldx]]--

    local wrap, yield = coroutine.wrap, coroutine.yield

    function xml.elements(root,pattern,reverse)
        return wrap(function() traverse(root, lpath(pattern), yield, reverse) end)
    end

    function xml.elements_only(root,pattern,reverse)
        return wrap(function() traverse(root, lpath(pattern), function(r,d,k) yield(d[k]) end, reverse) end)
    end

    function xml.each_element(root, pattern, handle, reverse)
        local ok
        traverse(root, lpath(pattern), function(r,d,k) ok = true handle(r,d,k) end, reverse)
        return ok
    end

    function xml.process_elements(root, pattern, handle)
        traverse(root, lpath(pattern), function(r,d,k)
            local dkdt = d[k].dt
            if dkdt then
                for i=1,#dkdt do
                    local v = dkdt[i]
                    if v.tg then handle(v) end
                end
            end
        end)
    end

    function xml.process_attributes(root, pattern, handle)
        traverse(root, lpath(pattern), function(r,d,k)
            local ek = d[k]
            local a = ek.at or { }
            handle(a)
            if next(a) then -- next is faster than type (and >0 test)
                ek.at = a
            else
                ek.at = nil
            end
        end)
    end

    --[[ldx--
    <p>We've now arrives at the functions that manipulate the tree.</p>
    --ldx]]--

    function xml.inject_element(root, pattern, element, prepend)
        if root and element then
            local matches, collect = { }, nil
            if type(element) == "string" then
                element = convert(element,true)
            end
            if element then
                collect = function(r,d,k) matches[#matches+1] = { r, d, k, element } end
                traverse(root, lpath(pattern), collect)
                for i=1,#matches do
                    local m = matches[i]
                    local r, d, k, element, edt = m[1], m[2], m[3], m[4], nil
                    if element.ri then
                        element = element.dt[element.ri].dt
                    else
                        element = element.dt
                    end
                    if r.ri then
                        edt = r.dt[r.ri].dt
                    else
                        edt = d and d[k] and d[k].dt
                    end
                    if edt then
                        local be, af
                        if prepend then
                            be, af = xml.copy(element), edt
                        else
                            be, af = edt, xml.copy(element)
                        end
                        for i=1,#af do
                            be[#be+1] = af[i]
                        end
                        if r.ri then
                            r.dt[r.ri].dt = be
                        else
                            d[k].dt = be
                        end
                    else
                     -- r.dt = element.dt -- todo
                    end
                end
            end
        end
    end

    -- todo: copy !

    function xml.insert_element(root, pattern, element, before) -- todo: element als functie
        if root and element then
            if pattern == "/" then
                xml.inject_element(root, pattern, element, before)
            else
                local matches, collect = { }, nil
                if type(element) == "string" then
                    element = convert(element,true)
                end
                if element and element.ri then
                    element = element.dt[element.ri]
                end
                if element then
                    collect = function(r,d,k) matches[#matches+1] = { r, d, k, element } end
                    traverse(root, lpath(pattern), collect)
                    for i=#matches,1,-1 do
                        local m = matches[i]
                        local r, d, k, element = m[1], m[2], m[3], m[4]
                        if not before then k = k + 1 end
                        if element.tg then
                            insert(d,k,element) -- untested
--~                         elseif element.dt then
--~                             for _,v in ipairs(element.dt) do -- i added
--~                                 insert(d,k,v)
--~                                 k = k + 1
--~                             end
--~                         end
                        else
                            local edt = element.dt
                            if edt then
                                for i=1,#edt do
                                    insert(d,k,edt[i])
                                    k = k + 1
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    xml.insert_element_after  =                 xml.insert_element
    xml.insert_element_before = function(r,p,e) xml.insert_element(r,p,e,true) end
    xml.inject_element_after  =                 xml.inject_element
    xml.inject_element_before = function(r,p,e) xml.inject_element(r,p,e,true) end

    function xml.delete_element(root, pattern)
        local matches, deleted = { }, { }
        local collect = function(r,d,k) matches[#matches+1] = { r, d, k } end
        traverse(root, lpath(pattern), collect)
        for i=#matches,1,-1 do
            local m = matches[i]
            deleted[#deleted+1] = table.remove(m[2],m[3])
        end
        return deleted
    end

    function xml.replace_element(root, pattern, element)
        if type(element) == "string" then
            element = convert(element,true)
        end
        if element and element.ri then
            element = element.dt[element.ri]
        end
        if element then
            traverse(root, lpath(pattern), function(rm, d, k)
                d[k] = element.dt -- maybe not clever enough
            end)
        end
    end

    local function load_data(name) -- == io.loaddata
        local f, data = io.open(name), ""
        if f then
            data = f:read("*all",'b') -- 'b' ?
            f:close()
        end
        return data
    end

    function xml.include(xmldata,pattern,attribute,recursive,loaddata)
        -- parse="text" (default: xml), encoding="" (todo)
        -- attribute = attribute or 'href'
        pattern = pattern or 'include'
        loaddata = loaddata or load_data
        local function include(r,d,k)
            local ek, name = d[k], nil
            if not attribute or attribute == "" then
                local ekdt = ek.dt
                name = (type(ekdt) == "table" and ekdt[1]) or ekdt
            end
            if not name then
                if ek.at then
                    for a in (attribute or "href"):gmatch("([^|]+)") do
                        name = ek.at[a]
                        if name then break end
                    end
                end
            end
            local data = (name and name ~= "" and loaddata(name)) or ""
            if data == "" then
                xml.empty(d,k)
            elseif ek.at["parse"] == "text" then -- for the moment hard coded
                d[k] = xml.escaped(data)
            else
                local xi = xml.convert(data)
                if not xi then
                    xml.empty(d,k)
                else
                    if recursive then
                        xml.include(xi,pattern,attribute,recursive,loaddata)
                    end
                    xml.assign(d,k,xi)
                end
            end
        end
        xml.each_element(xmldata, pattern, include)
    end

    function xml.strip_whitespace(root, pattern, nolines) -- strips all leading and trailing space !
        traverse(root, lpath(pattern), function(r,d,k)
            local dkdt = d[k].dt
            if dkdt then -- can be optimized
                local t = { }
                for i=1,#dkdt do
                    local str = dkdt[i]
                    if type(str) == "string" then

                        if str == "" then
                            -- stripped
                        else
                            if nolines then
                                str = str:gsub("[ \n\r\t]+"," ")
                            end
                            if str == "" then
                                -- stripped
                            else
                                t[#t+1] = str
                            end
                        end
                    else
                        t[#t+1] = str
                    end
                end
                d[k].dt = t
            end
        end)
    end

    function xml.rename_space(root, oldspace, newspace) -- fast variant
        local ndt = #root.dt
        local rename = xml.rename_space
        for i=1,ndt or 0 do
            local e = root[i]
            if type(e) == "table" then
                if e.ns == oldspace then
                    e.ns = newspace
                    if e.rn then
                        e.rn = newspace
                    end
                end
                local edt = e.dt
                if edt then
                    rename(edt, oldspace, newspace)
                end
            end
        end
    end

    function xml.remap_tag(root, pattern, newtg)
        traverse(root, lpath(pattern), function(r,d,k)
            d[k].tg = newtg
        end)
    end
    function xml.remap_namespace(root, pattern, newns)
        traverse(root, lpath(pattern), function(r,d,k)
            d[k].ns = newns
        end)
    end
    function xml.check_namespace(root, pattern, newns)
        traverse(root, lpath(pattern), function(r,d,k)
            local dk = d[k]
            if (not dk.rn or dk.rn == "") and dk.ns == "" then
                dk.rn = newns
            end
        end)
    end
    function xml.remap_name(root, pattern, newtg, newns, newrn)
        traverse(root, lpath(pattern), function(r,d,k)
            local dk = d[k]
            dk.tg = newtg
            dk.ns = newns
            dk.rn = newrn
        end)
    end

    function xml.filters.found(root,pattern,check_content)
        local found = false
        traverse(root, lpath(pattern), function(r,d,k)
            if check_content then
                local dk = d and d[k]
                found = dk and dk.dt and next(dk.dt) and true
            else
                found = true
            end
            return true
        end)
        return found
    end

end

--[[ldx--
<p>Here are a few synonyms.</p>
--ldx]]--

xml.filters.position = xml.filters.index

xml.count    = xml.filters.count
xml.index    = xml.filters.index
xml.position = xml.filters.index
xml.first    = xml.filters.first
xml.last     = xml.filters.last
xml.found    = xml.filters.found

xml.each     = xml.each_element
xml.process  = xml.process_element
xml.strip    = xml.strip_whitespace
xml.collect  = xml.collect_elements
xml.all      = xml.collect_elements

xml.insert   = xml.insert_element_after
xml.inject   = xml.inject_element_after
xml.after    = xml.insert_element_after
xml.before   = xml.insert_element_before
xml.delete   = xml.delete_element
xml.replace  = xml.replace_element

--[[ldx--
<p>The following helper functions best belong to the <t>lmxl-ini</t>
module. Some are here because we need then in the <t>mk</t>
document and other manuals, others came up when playing with
this module. Since this module is also used in <l n='mtxrun'/> we've
put them here instead of loading mode modules there then needed.</p>
--ldx]]--

function xml.gsub(t,old,new)
    if t.dt then
        for k,v in ipairs(t.dt) do
            if type(v) == "string" then
                t.dt[k] = v:gsub(old,new)
            else
                xml.gsub(v,old,new)
            end
        end
    end
end

function xml.strip_leading_spaces(dk,d,k) -- cosmetic, for manual
    if d and k and d[k-1] and type(d[k-1]) == "string" then
        local s = d[k-1]:match("\n(%s+)")
        xml.gsub(dk,"\n"..string.rep(" ",#s),"\n")
    end
end

function xml.serialize_path(root,lpath,handle)
    local dk, r, d, k = xml.first(root,lpath)
    dk = xml.copy(dk)
    xml.strip_leading_spaces(dk,d,k)
    xml.serialize(dk,handle)
end

--~ xml.escapes   = { ['&'] = '&amp;', ['<'] = '&lt;', ['>'] = '&gt;', ['"'] = '&quot;' }
--~ xml.unescapes = { } for k,v in pairs(xml.escapes) do xml.unescapes[v] = k end

--~ function xml.escaped  (str) return str:gsub("(.)"   , xml.escapes  ) end
--~ function xml.unescaped(str) return str:gsub("(&.-;)", xml.unescapes) end
--~ function xml.cleansed (str) return str:gsub("<.->"  , ''           ) end -- "%b<>"

do

    local P, S, R, C, V, Cc, Cs = lpeg.P, lpeg.S, lpeg.R, lpeg.C, lpeg.V, lpeg.Cc, lpeg.Cs

    -- 100 * 2500 * "oeps< oeps> oeps&" : gsub:lpeg|lpeg|lpeg
    --
    -- 1021:0335:0287:0247

    -- 10 * 1000 * "oeps< oeps> oeps& asfjhalskfjh alskfjh alskfjh alskfjh ;al J;LSFDJ"
    --
    -- 1559:0257:0288:0190 (last one suggested by roberto)

    --    escaped = Cs((S("<&>") / xml.escapes + 1)^0)
    --    escaped = Cs((S("<")/"&lt;" + S(">")/"&gt;" + S("&")/"&amp;" + 1)^0)
    local normal  = (1 - S("<&>"))^0
    local special = P("<")/"&lt;" + P(">")/"&gt;" + P("&")/"&amp;"
    local escaped = Cs(normal * (special * normal)^0)

    -- 100 * 1000 * "oeps&lt; oeps&gt; oeps&amp;" : gsub:lpeg == 0153:0280:0151:0080 (last one by roberto)

    --    unescaped = Cs((S("&lt;")/"<" + S("&gt;")/">" + S("&amp;")/"&" + 1)^0)
    --    unescaped = Cs((((P("&")/"") * (P("lt")/"<" + P("gt")/">" + P("amp")/"&") * (P(";")/"")) + 1)^0)
    local normal    = (1 - S"&")^0
    local special   = P("&lt;")/"<" + P("&gt;")/">" + P("&amp;")/"&"
    local unescaped = Cs(normal * (special * normal)^0)

    -- 100 * 5000 * "oeps <oeps bla='oeps' foo='bar'> oeps </oeps> oeps " : gsub:lpeg == 623:501 msec (short tags, less difference)

    local cleansed = Cs(((P("<") * (1-P(">"))^0 * P(">"))/"" + 1)^0)

    function xml.escaped  (str) return escaped  :match(str) end
    function xml.unescaped(str) return unescaped:match(str) end
    function xml.cleansed (str) return cleansed :match(str) end

end

function xml.join(t,separator,lastseparator)
    if #t > 0 then
        local result = { }
        for k,v in pairs(t) do
            result[k] = xml.tostring(v)
        end
        if lastseparator then
            return concat(result,separator or "",1,#result-1) .. (lastseparator or "") .. result[#result]
        else
            return concat(result,separator)
        end
    else
        return ""
    end
end


--[[ldx--
<p>We provide (at least here) two entity handlers. The more extensive
resolver consults a hash first, tries to convert to <l n='utf'/> next,
and finaly calls a handler when defines. When this all fails, the
original entity is returned.</p>
--ldx]]--

do if unicode and unicode.utf8 then

    xml.entities = xml.entities or { } -- xml.entity_handler == function

    function xml.entity_handler(e)
        return format("[%s]",e)
    end

    local char = unicode.utf8.char

    local function toutf(s)
        return char(tonumber(s,16))
    end

    function utfize(root)
        local d = root.dt
        for k=1,#d do
            local dk = d[k]
            if type(dk) == "string" then
            --  test prevents copying if no match
                if dk:find("&#x.-;") then
                    d[k] = dk:gsub("&#x(.-);",toutf)
                end
            else
                utfize(dk)
            end
        end
    end

    xml.utfize = utfize

    local function resolve(e) -- hex encoded always first, just to avoid mkii fallbacks
        if e:find("#x") then
            return char(tonumber(e:sub(3),16))
        else
            local ee = xml.entities[e] -- we cannot shortcut this one (is reloaded)
            if ee then
                return ee
            else
                local h = xml.entity_handler
                return (h and h(e)) or "&" .. e .. ";"
            end
        end
    end

    local function resolve_entities(root)
        if not root.special or root.tg == "@rt@" then
            local d = root.dt
            for k=1,#d do
                local dk = d[k]
                if type(dk) == "string" then
                    if dk:find("&.-;") then
                        d[k] = dk:gsub("&(.-);",resolve)
                    end
                else
                    resolve_entities(dk)
                end
            end
        end
    end

    xml.resolve_entities = resolve_entities

    function xml.utfize_text(str)
        if str:find("&#") then
            return (str:gsub("&#x(.-);",toutf))
        else
            return str
        end
    end

    function xml.resolve_text_entities(str) -- maybe an lpeg. maybe resolve inline
        if str:find("&") then
            return (str:gsub("&(.-);",resolve))
        else
            return str
        end
    end

    function xml.show_text_entities(str)
        if str:find("&") then
            return (str:gsub("&(.-);","[%1]"))
        else
            return str
        end
    end

    -- experimental, this will be done differently

    function xml.merge_entities(root)
        local documententities = root.entities
        local allentities = xml.entities
        if documententities then
            for k, v in pairs(documententities) do
                allentities[k] = v
            end
        end
    end

end end

function xml.statistics()
    return {
        lpathcalls = lpathcalls,
        lpathcached = lpathcached,
    }
end

--  xml.set_text_cleanup(xml.show_text_entities)
--  xml.set_text_cleanup(xml.resolve_text_entities)

--~ xml.lshow("/../../../a/(b|c)[@d='e']/f")
--~ xml.lshow("/../../../a/!(b|c)[@d='e']/f")
--~ xml.lshow("/../../../a/!b[@d!='e']/f")

--~ x = xml.convert([[
--~     <a>
--~         <b n='01'>01</b>
--~         <b n='02'>02</b>
--~         <b n='03'>03</b>
--~         <b n='04'>OK</b>
--~         <b n='05'>05</b>
--~         <b n='06'>06</b>
--~         <b n='07'>ALSO OK</b>
--~     </a>
--~ ]])

--~ xml.trace_lpath = true

--~ xml.xshow(xml.first(x,"b[position() > 2 and position() < 5 and text() == 'ok']"))
--~ xml.xshow(xml.first(x,"b[position() > 2 and position() < 5 and text() == upper('ok')]"))
--~ xml.xshow(xml.first(x,"b[@n=='03' or @n=='08']"))
--~ xml.xshow(xml.all  (x,"b[number(@n)>2 and number(@n)<6]"))
--~ xml.xshow(xml.first(x,"b[find(text(),'ALSO')]"))

--~ str = [[
--~ <?xml version="1.0" encoding="utf-8"?>
--~ <story line='mojca'>
--~     <windows>my secret</mouse>
--~ </story>
--~ ]]

--~ x = xml.convert([[
--~     <a><b n='01'>01</b><b n='02'>02</b><x>xx</x><b n='03'>03</b><b n='04'>OK</b></a>
--~ ]])
--~ xml.xshow(xml.first(x,"b[tag(2) == 'x']"))
--~ xml.xshow(xml.first(x,"b[tag(1) == 'x']"))
--~ xml.xshow(xml.first(x,"b[tag(-1) == 'x']"))
--~ xml.xshow(xml.first(x,"b[tag(-2) == 'x']"))

--~ print(xml.filter(x,"b/tag(2)"))
--~ print(xml.filter(x,"b/tag(1)"))

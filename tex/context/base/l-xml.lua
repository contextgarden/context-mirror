if not modules then modules = { } end modules ['l-xml'] = {
    version   = 1.001,
    comment   = "this module is the basis for the lxml-* ones",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- RJ: key=value ... lpeg.Ca(lpeg.Cc({}) * (pattern-producing-key-and-value / rawset)^0)

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

--[[ldx--
<p>First a hack to enable namespace resolving. A namespace is characterized by
a <l n='url'/>. The following function associates a namespace prefix with a
pattern. We use <l n='lpeg'/>, which in this case is more than twice as fast as a
find based solution where we loop over an array of patterns. Less code and
much cleaner.</p>
--ldx]]--

xml.xmlns = { }

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

do

    local remove, nsremap = table.remove, xml.xmlns

    local stack, top, dt, at, xmlns, errorstr = {}, {}, {}, {}, {}, nil

    local mt = { __tostring = xml.text }

    function xml.check_error(top,toclose)
        return ""
    end

    local cleanup = false

    function xml.set_text_cleanup(fnc)
        cleanup = fnc
    end

    local function add_attribute(namespace,tag,value)
        if tag == "xmlns" then
            xmlns[#xmlns+1] = xml.resolvens(value)
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
            errorstr = string.format("nothing to close with %s %s", tag, xml.check_error(top,toclose) or "")
        elseif toclose.tg ~= tag then -- no namespace check
            errorstr = string.format("unable to close %s with %s %s", toclose.tg, tag, xml.check_error(top,toclose) or "")
        end
        dt = top.dt
        dt[#dt+1] = toclose
        if at.xmlns then
            remove(xmlns)
        end
    end
    local function add_empty(spacing, namespace, tag)
        if #spacing > 0 then
            dt[#dt+1] = spacing
        end
        local resolved = (namespace == "" and xmlns[#xmlns]) or nsremap[namespace] or namespace
        top = stack[#stack]
        setmetatable(top, mt)
        dt = top.dt
        dt[#dt+1] = { ns=namespace or "", rn=resolved, tg=tag, at=at, dt={}, __p__ = top }
        at = { }
        if at.xmlns then
            remove(xmlns)
        end
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
        top = stack[#stack]
        setmetatable(top, mt)
        dt[#dt+1] = { special=true, ns="", tg=what, dt={text} }
    end
    local function set_message(txt)
        errorstr = "garbage at the end of the file: " .. txt:gsub("([ \n\r\t]*)","")
    end

    local space            = lpeg.S(' \r\n\t')
    local open             = lpeg.P('<')
    local close            = lpeg.P('>')
    local squote           = lpeg.S("'")
    local dquote           = lpeg.S('"')
    local equal            = lpeg.P('=')
    local slash            = lpeg.P('/')
    local colon            = lpeg.P(':')
    local valid            = lpeg.R('az', 'AZ', '09') + lpeg.S('_-.')
    local name_yes         = lpeg.C(valid^1) * colon * lpeg.C(valid^1)
    local name_nop         = lpeg.C(lpeg.P(true)) * lpeg.C(valid^1)
    local name             = name_yes + name_nop

    local utfbom           = lpeg.P('\000\000\254\255') + lpeg.P('\255\254\000\000') +
                             lpeg.P('\255\254') + lpeg.P('\254\255') + lpeg.P('\239\187\191') -- no capture

    local spacing          = lpeg.C(space^0)
    local justtext         = lpeg.C((1-open)^1)
    local somespace        = space^1
    local optionalspace    = space^0

    local value            = (squote * lpeg.C((1 - squote)^0) * squote) + (dquote * lpeg.C((1 - dquote)^0) * dquote)
    local attribute        = (somespace * name * optionalspace * equal * optionalspace * value) / add_attribute
    local attributes       = attribute^0

    local text             = justtext / add_text
    local balanced         = lpeg.P { "[" * ((1 - lpeg.S"[]") + lpeg.V(1))^0 * "]" } -- taken from lpeg manual, () example

    local emptyelement     = (spacing * open         * name * attributes * optionalspace * slash * close) / add_empty
    local beginelement     = (spacing * open         * name * attributes * optionalspace         * close) / add_begin
    local endelement       = (spacing * open * slash * name              * optionalspace         * close) / add_end

    local begincomment     = open * lpeg.P("!--")
    local endcomment       = lpeg.P("--") * close
    local begininstruction = open * lpeg.P("?")
    local endinstruction   = lpeg.P("?") * close
    local begincdata       = open * lpeg.P("![CDATA[")
    local endcdata         = lpeg.P("]]") * close

    local someinstruction  = lpeg.C((1 - endinstruction)^0)
    local somecomment      = lpeg.C((1 - endcomment    )^0)
    local somecdata        = lpeg.C((1 - endcdata      )^0)

    local begindoctype     = open * lpeg.P("!DOCTYPE")
    local enddoctype       = close
    local publicdoctype    = lpeg.P("PUBLIC") * somespace * value * somespace * value * somespace * balanced^0
    local systemdoctype    = lpeg.P("SYSTEM") * somespace * value * somespace                     * balanced^0
    local simpledoctype    = (1-close)^1                                                          * balanced^0
    local somedoctype      = lpeg.C((somespace * lpeg.P(publicdoctype + systemdoctype + simpledoctype) * optionalspace)^0)

    local instruction      = (spacing * begininstruction * someinstruction * endinstruction) / function(...) add_special("@pi@",...) end
    local comment          = (spacing * begincomment     * somecomment     * endcomment    ) / function(...) add_special("@cm@",...) end
    local cdata            = (spacing * begincdata       * somecdata       * endcdata      ) / function(...) add_special("@cd@",...) end
    local doctype          = (spacing * begindoctype     * somedoctype     * enddoctype    ) / function(...) add_special("@dd@",...) end

    --  nicer but slower:
    --
    --  local instruction = (lpeg.Cc("@pi@") * spacing * begininstruction * someinstruction * endinstruction) / add_special
    --  local comment     = (lpeg.Cc("@cm@") * spacing * begincomment     * somecomment     * endcomment    ) / add_special
    --  local cdata       = (lpeg.Cc("@cd@") * spacing * begincdata       * somecdata       * endcdata      ) / add_special
    --  local doctype     = (lpeg.Cc("@dd@") * spacing * begindoctype     * somedoctype     * enddoctype    ) / add_special

    local trailer = space^0 * (justtext/set_message)^0

    --  comment + emptyelement + text + cdata + instruction + lpeg.V("parent"), -- 6.5 seconds on 40 MB database file
    --  text + comment + emptyelement + cdata + instruction + lpeg.V("parent"), -- 5.8
    --  text + lpeg.V("parent") + emptyelement + comment + cdata + instruction, -- 5.5

    local grammar = lpeg.P { "preamble",
        preamble = utfbom^0 * instruction^0 * (doctype + comment + instruction)^0 * lpeg.V("parent") * trailer,
        parent   = beginelement * lpeg.V("children")^0 * endelement,
        children = text + lpeg.V("parent") + emptyelement + comment + cdata + instruction,
    }

    function xml.convert(data, no_root)
        stack, top, at, xmlns, errorstr, result = {}, {}, {}, {}, nil, nil
        stack[#stack+1] = top
        top.dt = { }
        dt = top.dt
        if not data or data == "" then
            errorstr = "empty xml file"
        elseif not grammar:match(data) then
            errorstr = "invalid xml file"
        end
        if errorstr then
            result = { dt = { { ns = "", tg = "error", dt = { errorstr }, at={}, er = true } }, error = true }
            setmetatable(stack, mt)
            if xml.error_handler then xml.error_handler("load",errorstr) end
        else
            result = stack[1]
        end
        if not no_root then
            result = { special = true, ns = "", tg = '@rt@', dt = result.dt, at={} }
            setmetatable(result, mt)
            for k,v in ipairs(result.dt) do
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

    xml.error_handler = (logs and logs.report) or print

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

function xml.copy(old,tables)
    if old then
        tables = tables or { }
        local new = { }
        if not tables[old] then
            tables[old] = new
        end
        for k,v in pairs(old) do
            new[k] = (type(v) == "table" and (tables[v] or xml.copy(v, tables))) or v
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

    function xml.serialize(e, handle, textconverter, attributeconverter, specialconverter, nocommands)
        if not e then
            -- quit
        elseif not nocommands and e.command and xml.command then
            xml.command(e)
        else
            handle = handle or fallbackhandle
            local etg = e.tg
            if etg then
            --  local format = string.format
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
                        handle("<?" .. edt[1] .. "?>") -- maybe table.join(edt)
                    elseif etg == "@cm@" then
                    --  handle(format("<!--%s-->",edt[1]))
                        handle("<!--" .. edt[1] .. "-->")
                    elseif etg == "@cd@" then
                    --  handle(format("<![CDATA[%s]]>",edt[1]))
                        handle("<![CDATA[" .. edt[1] .. "]]>")
                    elseif etg == "@dd@" then
                    --  handle(format("<!DOCTYPE %s>",edt[1]))
                        handle("<!DOCTYPE " .. edt[1] .. ">")
                    elseif etg == "@rt@" then
                        xml.serialize(edt,handle,textconverter,attributeconverter,specialconverter,nocommands)
                    end
                else
                    local ens, eat, edt, ern = e.ns, e.at, e.dt, e.rn
                    local ats = eat and next(eat) and { }
                    if ats then
                        local format = string.format
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
                    if ern and xml.trace_remap then
                        if ats then
                            ats[#ats+1] = string.format("xmlns:remapped='%s'",ern)
                        else
                            ats = { string.format("xmlns:remapped='%s'",ern) }
                        end
                    end
                    if ens ~= "" then
                        if edt and #edt > 0 then
                            if ats then
                            --  handle(format("<%s:%s %s>",ens,etg,table.concat(ats," ")))
                                handle("<" .. ens .. ":" .. etg .. " " .. table.concat(ats," ") .. ">")
                            else
                            --  handle(format("<%s:%s>",ens,etg))
                                handle("<" .. ens .. ":" .. etg .. ">")
                            end
                            local serialize = xml.serialize
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
                            --  handle(format("<%s:%s %s/>",ens,etg,table.concat(ats," ")))
                                handle("<" .. ens .. ":" .. etg .. " " .. table.concat(ats," ") .. "/>")
                            else
                            --  handle(format("<%s:%s/>",ens,etg))
                                handle("<" .. ens .. ":" .. "/>")
                            end
                        end
                    else
                        if edt and #edt > 0 then
                            if ats then
                            --  handle(format("<%s %s>",etg,table.concat(ats," ")))
                                handle("<" .. etg .. " " .. table.concat(ats," ") .. ">")
                            else
                            --  handle(format("<%s>",etg))
                                handle("<" .. etg .. ">")
                            end
                            local serialize = xml.serialize
                            for i=1,#edt do
                                serialize(edt[i],handle,textconverter,attributeconverter,specialconverter,nocommands)
                            end
                        --  handle(format("</%s>",etg))
                            handle("</" .. etg .. ">")
                        else
                            if ats then
                            --  handle(format("<%s %s/>",etg,table.concat(ats," ")))
                                handle("<" .. etg .. " " .. table.concat(ats," ") .. "/>")
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
                local serialize = xml.serialize
                for i=1,#e do
                    serialize(e[i],handle,textconverter,attributeconverter,specialconverter,nocommands)
                end
            end
        end
    end

    function xml.checkbom(root)
        if root.ri then
            local dt, found = root.dt, false
            for k,v in ipairs(dt) do
                if type(v) == "table" and v.special and v.tg == "@pi" and v.dt:find("xml.*version=") then
                    found = true
                    break
                end
            end
            if not found then
                table.insert(dt, 1, { special=true, ns="", tg="@pi@", dt = { "xml version='1.0' standalone='yes'"} } )
                table.insert(dt, 2, "\n" )
            end
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
    elseif next(root) then
        local result = { }
        xml.serialize(root,function(s) result[#result+1] = s end)
        return table.concat(result,"")
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

function xml.content(root)
    return (root and root.dt and xml.tostring(root.dt)) or ""
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

do

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

    local function make_expression(str)
        str = str:gsub("@([a-zA-Z%-_]+)", "(a['%1'] or '')")
        str = str:gsub("position%(%)", "i")
        str = str:gsub("text%(%)", "t")
        str = str:gsub("!=", "~=")
        str = str:gsub("([^=!~<>])=([^=!~<>])", "%1==%2")
        str = str:gsub("([a-zA-Z%-_]+)%(", "functions.%1(")
        return str, loadstring(string.format("return function(functions,i,a,t) return %s end", str))()
    end

    local map = { }

    local space             = lpeg.S(' \r\n\t')
    local squote            = lpeg.S("'")
    local dquote            = lpeg.S('"')
    local lparent           = lpeg.P('(')
    local rparent           = lpeg.P(')')
    local atsign            = lpeg.P('@')
    local lbracket          = lpeg.P('[')
    local rbracket          = lpeg.P(']')
    local exclam            = lpeg.P('!')
    local period            = lpeg.P('.')
    local eq                = lpeg.P('==') + lpeg.P('=')
    local ne                = lpeg.P('<>') + lpeg.P('!=')
    local star              = lpeg.P('*')
    local slash             = lpeg.P('/')
    local colon             = lpeg.P(':')
    local bar               = lpeg.P('|')
    local hat               = lpeg.P('^')
    local valid             = lpeg.R('az', 'AZ', '09') + lpeg.S('_-')
    local name_yes          = lpeg.C(valid^1) * colon * lpeg.C(valid^1 + star) -- permits ns:*
    local name_nop          = lpeg.C(lpeg.P(true)) * lpeg.C(valid^1)
    local name              = name_yes + name_nop
    local number            = lpeg.C((lpeg.S('+-')^0 * lpeg.R('09')^1)) / tonumber
    local names             = (bar^0 * name)^1
    local morenames         = name * (bar^0 * name)^1
    local instructiontag    = lpeg.P('pi::')
    local spacing           = lpeg.C(space^0)
    local somespace         = space^1
    local optionalspace     = space^0
    local text              = lpeg.C(valid^0)
    local value             = (squote * lpeg.C((1 - squote)^0) * squote) + (dquote * lpeg.C((1 - dquote)^0) * dquote)
    local empty             = 1-slash

    local is_eq             = lbracket * atsign * name * eq * value * rbracket
    local is_ne             = lbracket * atsign * name * ne * value * rbracket
    local is_attribute      = lbracket * atsign * name              * rbracket
    local is_value          = lbracket *          value             * rbracket
    local is_number         = lbracket *          number            * rbracket

    local nobracket         = 1-(lbracket+rbracket)  -- must be improved
    local is_expression     = lbracket * lpeg.C(((lpeg.C(nobracket^1))/make_expression)) * rbracket

    local is_expression     = lbracket * (lpeg.C(nobracket^1))/make_expression * rbracket

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

    local instruction              = (instructiontag * text ) / function(...) map[#map+1] = { 40,        ... } end
    local nothing                  = (empty                 ) / function(   ) map[#map+1] = { 15             } end -- 15 ?
    local crap                     = (1-slash)^1

    -- a few ugly goodies:

    local docroottag               = lpeg.P('^^')             / function(   ) map[#map+1] = { 12             } end
    local subroottag               = lpeg.P('^')              / function(   ) map[#map+1] = { 13             } end
    local roottag                  = lpeg.P('root::')         / function(   ) map[#map+1] = { 12             } end
    local parenttag                = lpeg.P('parent::')       / function(   ) map[#map+1] = { 11             } end
    local childtag                 = lpeg.P('child::')
    local selftag                  = lpeg.P('self::')

    -- there will be more and order will be optimized

    local selector = (
        instruction +
        many + any +
        parent + stay +
        dont_position + position +
        dont_match_one_of_and_eq + dont_match_one_of_and_ne +
        match_one_of_and_eq + match_one_of_and_ne +
        dont_match_and_eq + dont_match_and_ne +
        match_and_eq + match_and_ne +
        dont_expression + expression +
        has_attribute + has_value +
        dont_match_one_of + match_one_of +
        dont_match + match +
        crap + empty
    )

    local grammar = lpeg.P { "startup",
        startup  = (initial + documentroot + subtreeroot + roottag + docroottag + subroottag)^0 * lpeg.V("followup"),
        followup = ((slash + parenttag + childtag + selftag)^0 * selector)^1,
    }

    function compose(str)
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
                elseif #map == 2  and m == 12 and map[2][1] == 20 then
                --  return { { 29, map[2][2], map[2][3], map[2][4], map[2][5] } }
                    map[2][1] = 29
                    return { map[2] }
                end
                if m ~= 11 and m ~= 12 and m ~= 13 and m ~= 14 and m ~= 15 and m ~= 16 then
                    table.insert(map, 1, { 16 })
                end
                return map
            end
        end
    end

    local cache = { }

    function xml.lpath(pattern,trace)
        if type(pattern) == "string" then
            local result = cache[pattern]
            if not result then
                result = compose(pattern)
                cache[pattern] = result
            end
            if trace or xml.trace_lpath then
                xml.lshow(result)
            end
            return result
        else
            return pattern
        end
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
                report(string.format("pattern: %s\n",pattern))
            end
            for k,v in ipairs(lp) do
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
                    report(string.format("%2i: %s %s -> %s\n", k,v[1],actions[v[1]],table.join(t," ")))
                else
                    report(string.format("%2i: %s %s\n", k,v[1],actions[v[1]]))
                end
            end
        end
    end

    function xml.xshow(e,...) -- also handy when report is given, use () to isolate first e
        local t = { ... }
        local report = (type(t[#t]) == "function" and t[#t]) or fallbackreport
        if not e then
            report("<!-- no element -->\n")
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

xml.functions = { }

do

    local functions = xml.functions

    functions.contains = string.find
    functions.find     = string.find
    functions.upper    = string.upper
    functions.lower    = string.lower
    functions.number   = tonumber
    functions.boolean  = toboolean
    functions.oneof    = function(s,...) -- slow
        local t = {...} for i=1,#t do if s == t[i] then return true end end return false
    end

    function xml.traverse(root,pattern,handle,reverse,index,parent,wildcard)
        if not root then -- error
            return false
        elseif pattern == false then -- root
            handle(root,root.dt,root.ri)
            return false
        elseif pattern == true then -- wildcard
            local traverse = xml.traverse
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
                    local ns, tg = (e.rn or e.ns), e.tg
                    local matched = ns == action[3] and tg == action[4]
                    if not action[2] then matched = not matched end
                    if matched then
                        if handle(root,rootdt,k) then return false end
                    end
                end
            elseif command == 11 then -- parent
                local ep = root.__p__ or parent
                if index < #pattern then
                    if not xml.traverse(ep,pattern,handle,reverse,index+1,root) then return false end
                elseif handle(root,rootdt,k) then
                    return false
                end
            else
                if (command == 16 or command == 12) and index == 1 then -- initial
--~                     wildcard = true
                    wildcard = command == 16 -- ok?
                    index = index + 1
                    action = pattern[index]
                    command = action and action[1] or 0 -- something is wrong
                end
                if command == 11 then -- parent
                    local ep = root.__p__ or parent
                    if index < #pattern then
                        if not xml.traverse(ep,pattern,handle,reverse,index+1,root) then return false end
                    elseif handle(root,rootdt,k) then
                        return false
                    end
                else
                    local traverse = xml.traverse
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
                    for k=start,stop,step do
                        local e = rootdt[k]
                        local ns, tg = e.rn or e.ns, e.tg
                        if tg then
                            idx = idx + 1
                            if command == 30 then
                                local tg_a = action[4]
                                if tg == tg_a then matched = ns == action[3] elseif tg_a == '*' then matched, multiple = ns == action[3], true else matched = false end
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
                                    local tg_a = action[4]
                                    if tg == tg_a then matched = ns == action[3] elseif tg_a == '*' then matched, multiple = ns == action[3], true else matched = false end
                                    if not action[2] then matched = not matched end
                                elseif command == 21 then -- match one of
                                    multiple = true
                                    for i=3,#action,2 do
                                        if ns == action[i] and tg == action[i+1] then matched = true break end
                                    end
                                    if not action[2] then matched = not matched end
                                elseif command == 22 then -- eq
                                    local tg_a = action[4]
                                    if tg == tg_a then matched = ns == action[3] elseif tg_a == '*' then matched, multiple = ns == action[3], true else matched = false end
                                    if not action[2] then matched = not matched end
                                    matched = matched and e.at[action[6]] == action[7]
                                elseif command == 23 then -- ne
                                    local tg_a = action[4]
                                    if tg == tg_a then matched = ns == action[3] elseif tg_a == '*' then matched, multiple = ns == action[3], true else matched = false end
                                    if not action[2] then matched = not matched end
                                    matched = mached and e.at[action[6]] ~= action[7]
                                elseif command == 24 then -- one of eq
                                    multiple = true
                                    for i=3,#action-2,2 do
                                        if ns == action[i] and tg == action[i+1] then matched = true break end
                                    end
                                    if not action[2] then matched = not matched end
                                    matched = matched and e.at[action[#action-1]] == action[#action]
                                elseif command == 25 then -- one of ne
                                    multiple = true
                                    for i=3,#action-2,2 do
                                        if ns == action[i] and tg == action[i+1] then matched = true break end
                                    end
                                    if not action[2] then matched = not matched end
                                    matched = matched and e.at[action[#action-1]] ~= action[#action]
                                elseif command == 27 then -- has attribute
                                    local tg_a = action[4]
                                    if tg == tg_a then matched = ns == action[3] elseif tg_a == '*' then matched, multiple = ns == action[3], true else matched = false end
                                    if not action[2] then matched = not matched end
                                    matched = matched and e.at[action[5]]
                                elseif command == 28 then -- has value
                                    local edt = e.dt
                                    local tg_a = action[4]
                                    if tg == tg_a then matched = ns == action[3] elseif tg_a == '*' then matched, multiple = ns == action[3], true else matched = false end
                                    if not action[2] then matched = not matched end
                                    matched = matched and edt and edt[1] == action[5]
                                elseif command == 31 then
                                    local edt = e.dt
                                    local tg_a = action[4]
                                    if tg == tg_a then matched = ns == action[3] elseif tg_a == '*' then matched, multiple = ns == action[3], true else matched = false end
                                    if not action[2] then matched = not matched end
                                    if matched then
                                        matched = action[6](functions,idx,e.at,edt[1])
                                    end
                                end
                                if matched then -- combine tg test and at test
                                    if index == #pattern then
                                        if handle(root,rootdt,root.ri or k) then return false end
                                        if wildcard and multiple then
                                            if not traverse(e,pattern,handle,reverse,index,root,true) then return false end
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

    --[[ldx--
    <p>For splitting the filter function from the path specification, we can
    use string matching or lpeg matching. Here the difference in speed is
    neglectable but the lpeg variant is more robust.</p>
    --ldx]]--

    --  function xml.filter(root,pattern)
    --      local pat, fun, arg = pattern:match("^(.+)/(.-)%((.*)%)$")
    --      if fun then
    --          return (xml.filters[fun] or xml.filters.default)(root,pat,arg)
    --      else
    --          pat, arg = pattern:match("^(.+)/@(.-)$")
    --          if arg then
    --              return xml.filters.attributes(root,pat,arg)
    --          else
    --              return xml.filters.default(root,pattern)
    --          end
    --      end
    --  end

    --  not faster but hipper ... although ... i can't get rid of the trailing / in the path

    local name      = (lpeg.R("az","AZ")+lpeg.R("_-"))^1
    local path      = lpeg.C(((1-lpeg.P('/'))^0 * lpeg.P('/'))^1)
    local argument  = lpeg.P { "(" * lpeg.C(((1 - lpeg.S("()")) + lpeg.V(1))^0) * ")" }
    local action    = lpeg.Cc(1) * path * lpeg.C(name) * argument
    local attribute = lpeg.Cc(2) * path * lpeg.P('@') * lpeg.C(name)

    local parser    = action + attribute

    function xml.filter(root,pattern)
        local kind, a, b, c = parser:match(pattern)
        if kind == 1 then
            return (xml.filters[b] or xml.filters.default)(root,a,c)
        elseif kind == 2 then
            return xml.filters.attributes(root,a,b)
        else
            return xml.filters.default(root,pattern)
        end
    end

    function xml.filters.default(root,pattern)
        local rt, dt, dk
        traverse(root, lpath(pattern), function(r,d,k) rt,dt,dk = r,d,k return true end)
        return dt and dt[dk], rt, dt, dk
    end

    function xml.filters.reverse(root,pattern)
        local rt, dt, dk
        traverse(root, lpath(pattern), function(r,d,k) rt,dt,dk = r,d,k return true end, 'reverse')
        return dt and dt[dk], rt, dt, dk
    end
    function xml.filters.count(root, pattern,everything)
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
    function xml.filters.attribute(root,pattern,arguments)
        local rt, dt, dk
        traverse(root, lpath(pattern), function(r,d,k) rt, dt, dk = r, d, k return true end)
        local ekat = (dt and dt[dk] and dt[dk].at) or (rt and rt.at)
        return (ekat and ekat[arguments]) or ""
    end
    function xml.filters.text(root,pattern,arguments)
        local dtk, rt, dt, dk = xml.filters.index(root,pattern,arguments)
        if dtk then
            local dtkdt = dtk.dt
            if #dtkdt == 1 and type(dtkdt[1]) == "string" then
                return dtkdt[1], rt, dt, dk
            else
                return xml.tostring(dtkdt), rt, dt, dk
            end
        else
            return "", rt, dt, dk
        end
    end

    --[[ldx--
    <p>The following functions collect elements and texts.</p>
    --ldx]]--

    function xml.collect_elements(root, pattern, ignorespaces)
        local rr, dd = { }, { }
        traverse(root, lpath(pattern), function(r,d,k)
            local dk = d and d[k]
            if dk then
                if ignorespaces and type(dk) == "string" and dk:find("^%s*$") then
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
    1.5 times the runtime of the function variant which si due to the overhead in
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

    function xml.elements(root,pattern,reverse)
        return coroutine.wrap(function() traverse(root, lpath(pattern), coroutine.yield, reverse) end)
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
            if next(a) then
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
                            table.insert(d,k,element) -- untested
                        elseif element.dt then
                            for _,v in ipairs(element.dt) do -- i added
                                table.insert(d,k,v)
                                k = k + 1
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

    function xml.include(xmldata,pattern,attribute,recursive,findfile)
        -- parse="text" (default: xml), encoding="" (todo)
        pattern = pattern or 'include'
        -- attribute = attribute or 'href'
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
            if name then
                name = (findfile and findfile(name)) or name
                if name ~= "" then
                    local f = io.open(name)
                    if f then
                        if ek.at["parse"] == "text" then -- for the moment hard coded
                            d[k] = xml.escaped(f:read("*all"))
                        else
                            local xi = xml.load(f)
                            if recursive then
                                xml.include(xi,pattern,attribute,recursive,findfile)
                            end
                            xml.assign(d,k,xi)
                        end
                        f:close()
                    else
                        xml.empty(d,k)
                    end
                else
                    xml.empty(d,k)
                end
            else
                xml.empty(d,k)
            end
        end
        xml.each_element(xmldata, pattern, include)
    end

    function xml.strip_whitespace(root, pattern)
        traverse(root, lpath(pattern), function(r,d,k)
            local dkdt = d[k].dt
            if dkdt then -- can be optimized
                local t = { }
                for i=1,#dkdt do
                    local str = dkdt[i]
                    if type(str) == "string" and str:find("^[ \n\r\t]*$") then
                        -- stripped
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

    -- 100 * 2500 * "oeps< oeps> oeps&" : gsub:lpeg|lpeg|lpeg
    --
    -- 1021:0335:0287:0247

    -- 10 * 1000 * "oeps< oeps> oeps& asfjhalskfjh alskfjh alskfjh alskfjh ;al J;LSFDJ"
    --
    -- 1559:0257:0288:0190 (last one suggested by roberto)

    --    escaped = lpeg.Cs((lpeg.S("<&>") / xml.escapes + 1)^0)
    --    escaped = lpeg.Cs((lpeg.S("<")/"&lt;" + lpeg.S(">")/"&gt;" + lpeg.S("&")/"&amp;" + 1)^0)
    local normal  = (1 - lpeg.S("<&>"))^0
    local special = lpeg.P("<")/"&lt;" + lpeg.P(">")/"&gt;" + lpeg.P("&")/"&amp;"
    local escaped = lpeg.Cs(normal * (special * normal)^0)

    -- 100 * 1000 * "oeps&lt; oeps&gt; oeps&amp;" : gsub:lpeg == 0153:0280:0151:0080 (last one by roberto)

    --    unescaped = lpeg.Cs((lpeg.S("&lt;")/"<" + lpeg.S("&gt;")/">" + lpeg.S("&amp;")/"&" + 1)^0)
    --    unescaped = lpeg.Cs((((lpeg.P("&")/"") * (lpeg.P("lt")/"<" + lpeg.P("gt")/">" + lpeg.P("amp")/"&") * (lpeg.P(";")/"")) + 1)^0)
    local normal    = (1 - lpeg.S"&")^0
    local special   = lpeg.P("&lt;")/"<" + lpeg.P("&gt;")/">" + lpeg.P("&amp;")/"&"
    local unescaped = lpeg.Cs(normal * (special * normal)^0)

    -- 100 * 5000 * "oeps <oeps bla='oeps' foo='bar'> oeps </oeps> oeps " : gsub:lpeg == 623:501 msec (short tags, less difference)

    local cleansed = lpeg.Cs(((lpeg.P("<") * (1-lpeg.P(">"))^0 * lpeg.P(">"))/"" + 1)^0)

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
            return table.join(result,separator or "",1,#result-1) .. (lastseparator or "") .. result[#result]
        else
            return table.join(result,separator)
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

    xml.entities = xml.entities or { } -- xml.entities.handler == function

    local char = unicode.utf8.char

    local function toutf(s)
        return char(tonumber(s,16))
    end

    function xml.utfize(root)
        local d = root.dt
        for k=1,#d do
            local dk = d[k]
            if type(dk) == "string" then
            --  test prevents copying if no match
                if dk:find("&#x.-;") then
                    d[k] = dk:gsub("&#x(.-);",toutf)
                end
            else
                xml.utfize(dk)
            end
        end
    end

    local entities = xml.entities

    local function resolve(e)
        local ee = entities[e]
        if ee then
            return ee
        elseif e:find("#x") then
            return char(tonumber(e:sub(3),16))
        else
            local h = entities.handler
            return (h and h(e)) or "&" .. e .. ";"
        end
    end

    function xml.resolve_entities(root)
        local d = root.dt
        for k=1,#d do
            local dk = d[k]
            if type(dk) == "string" then
                if dk:find("&.-;") then
                    d[k] = dk:gsub("&(.-);",resolve)
                end
            else
                xml.utfize(dk)
            end
        end
    end

    function xml.utfize_text(str)
        if str:find("&#") then
            return (str:gsub("&#x(.-);",toutf))
        else
            return str
        end
    end

    function xml.resolve_text_entities(str)
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

--  xml.set_text_cleanup(xml.show_text_entities)
--  xml.set_text_cleanup(xml.resolve_text_entities)

end end

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

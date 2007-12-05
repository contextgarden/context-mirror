if not modules then modules = { } end modules ['lxml-ini'] = {
    version   = 1.001,
    comment   = "companion to lxml-ini.tex",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

document     = document or { }
document.xml = document.xml or { }

lxml         = { }
lxml.loaded  = { }
lxml.self    = { }

do

    local crlf    = lpeg.P("\r\n")
    local cr      = lpeg.P("\r")
    local lf      = lpeg.P("\n")
    local space   = lpeg.S(" \t\f\v")
    local newline = crlf + cr + lf
    local spacing = space^0 * newline  * space^0
    local content = lpeg.C((1-spacing)^1)
    local verbose = lpeg.C((1-(space+newline))^1)

    local capture  = (
        newline^2  * lpeg.Cc("")  / tex.print +
        newline    * lpeg.Cc(" ") / tex.sprint +
        content                   / tex.sprint
    )^0

    xml.specialhandler = { }

    local function sprint(root)
        if not root then
            -- quit
        elseif type(root) == 'string' then
            lpeg.match(capture,root)
        elseif next(root) then
            xml.serialize(root,sprint,nil,nil,xml.specialhandler)
        end
    end

    xml.sprint = sprint

    function xml.tprint(root)
        if type(root) == "table" then
            for i=1,#root do
                sprint(root[i])
            end
        elseif type(root) == "string" then
            sprint(root)
        end
    end

    -- lines (untested)

    local buffer = { }

    local capture  = (
        newline^2 / function()  buffer[#buffer+1] = "" end +
        newline   / function()  buffer[#buffer] = buffer[#buffer] .. " " end +
        content   / function(s) buffer[#buffer] = buffer[#buffer] ..  s  end
    )^0

    function lines(root)
        if not root then
            -- quit
        elseif type(root) == 'string' then
            lpeg.match(capture,root)
        elseif next(root) then
            xml.serialize(root, lines)
        end
    end

    function xml.lines(root)
        buffer = { "" }
        lines(root)
        return result
    end

    -- cdata

    local linecommand   = "\\obeyedline"
    local spacecommand  = "\\obeyedspace" -- "\\strut\\obeyedspace"
    local beforecommand = ""
    local aftercommand  = ""

    local capture  = (
        newline / function( ) tex.sprint(tex.texcatcodes,linecommand  .. "{}") end +
        verbose / function(s) tex.sprint(tex.vrbcatcodes,s) end +
        space   / function( ) tex.sprint(tex.texcatcodes,spacecommand .. "{}") end
    )^0

    function toverbatim(str)
        if beforecommand then tex.sprint(tex.texcatcodes,beforecommand .. "{}") end
        lpeg.match(capture,str)
        if aftercommand  then tex.sprint(tex.texcatcodes,aftercommand  .. "{}")  end
    end

    function lxml.set_verbatim(before,after,obeyedline,obeyedspace)
        beforecommand, aftercommand, linecommand, spacecommand = before, after, obeyedline, obeyedspace
    end

    function lxml.set_cdata()
        xml.specialhandler['@cd@'] = toverbatim
    end

    function lxml.reset_cdata()
        xml.specialhandler['@cd@'] = nil
    end

    function lxml.verbatim(id,before,after)
        local root = lxml.id(id)
        if before then tex.sprint(tex.ctxcatcodes,string.format("%s[%s]",before,root.tg)) end
        xml.serialize(root.dt,toverbatim,nil,nil,nil,true)  -- was root
        if after  then tex.sprint(tex.ctxcatcodes,after) end
    end
    function lxml.inlineverbatim(id)
        lxml.verbatim(id,"\\startxmlinlineverbatim","\\stopxmlinlineverbatim")
    end
    function lxml.displayverbatim(id)
        lxml.verbatim(id,"\\startxmldisplayverbatim","\\stopxmldisplayverbatim")
    end

end

-- now comes the lxml one

function lxml.id(id)
    return (type(id) == "table" and id) or lxml.loaded[id] or lxml.self[tonumber(id)]
end

function lxml.root(id)
    return lxml.loaded[id]
end

-- redefine xml load

xml.originalload = xml.load

function xml.load(filename)
    input.starttiming(lxml)
    local x = xml.originalload(filename)
    input.stoptiming(lxml)
    return x
end

function lxml.filename(filename) -- some day we will do this in input, first figure out /
    return input.find_file(texmf.instance,url.filename(filename)) or ""
end

function lxml.load(id,filename)
    if texmf then
        local fullname = lxml.filename(filename)
        if fullname ~= "" then
            filename = fullname
        end
    end
    lxml.loaded[id] = xml.load(filename)
    return lxml.loaded[id], filename
end

function lxml.include(id,pattern,attribute,recurse)
    xml.include(lxml.id(id),pattern,attribute,recurse,lxml.filename)
end

function lxml.utfize(id)
    xml.utfize(lxml.id(id))
end

function lxml.filter(id,pattern)
    xml.sprint(xml.filter(lxml.id(id),pattern))
end

function lxml.first(id,pattern)
    xml.sprint(xml.first(lxml.id(id),pattern))
end

function lxml.last(id,pattern)
    xml.sprint(xml.last(lxml.id(id),pattern))
end

function lxml.all(id,pattern)
    xml.tprint(xml.collect(lxml.id(id),pattern))
end

function lxml.nonspace(id,pattern)
    xml.tprint(xml.collect(lxml.id(id),pattern,true))
end

function lxml.strip(id,pattern)
    xml.strip(lxml.id(id),pattern)
end

function lxml.text(id,pattern)
    xml.tprint(xml.collect_texts(lxml.id(id),pattern) or {})
end

function lxml.content(id,pattern)
    xml.sprint(xml.content(lxml.id(id),pattern) or "")
end

function lxml.stripped(id,pattern)
    local str = xml.content(lxml.id(id),pattern)  or ""
    xml.sprint((str:gsub("^%s*(.-)%s*$","%1")))
end

function lxml.flush(id)
    xml.sprint(lxml.id(id).dt)
end

function lxml.index(id,pattern,i)
    xml.sprint((xml.filters.index(lxml.id(id),pattern,i)))
end

function lxml.attribute(id,pattern,a,default) --todo: snelle xmlatt
    local str = xml.filters.attribute(lxml.id(id),pattern,a) or ""
    tex.sprint((str == "" and default) or str)
end

function lxml.count(id,pattern)
    tex.sprint(xml.count(lxml.id(id),pattern) or 0)
end
function lxml.name(id) -- or remapped name?
    local r = lxml.id(id)
    if r.ns then
        tex.sprint(r.ns .. ":" .. r.tg)
    else
        tex.sprint(r.tg)
    end
end
function lxml.tag(id)
    tex.sprint(lxml.id(id).tg or "")
end
function lxml.namespace(id) -- or remapped name?
    local root = lxml.id(id)
    tex.sprint(root.rn or root.ns or "")
end

--~ function lxml.concat(id,what,separator,lastseparator)
--~     tex.sprint(table.concat(xml.collect_texts(lxml.id(id),what,true),separator or ""))
--~ end

function lxml.concat(id,what,separator,lastseparator)
    local t = xml.collect_texts(lxml.id(id),what,true)
    local separator = separator or ""
    local lastseparator = lastseparator or separator or ""
    for i=1,#t do
        tex.sprint(t[i])
        if i == #t then
            -- nothing
        elseif i == #t-1 and lastseparator ~= "" then
            tex.sprint(tex.ctxcatcodes,lastseparator)
        elseif separator ~= "" then
            tex.sprint(tex.ctxcatcodes,separator)
        end
    end
end

function xml.command(root) -- todo: free self after usage, so maybe hash after all
    -- no longer needed: xml.sflush()
    if type(root.command) == "string" then
        local n = #lxml.self + 1
        lxml.self[n] = root
        if xml.trace_print then
            texio.write_nl(string.format("tex.sprint: (((%s:%s)))",n,root.command))
        end
        -- problems with empty elements
        tex.sprint(tex.ctxcatcodes,string.format("\\xmlsetup{%s}{%s}",n,root.command)) -- no sprint, else spaces go wrong
    else
        root.command(root)
    end
end

function lxml.setaction(id,pattern,action)
    for rt, dt, dk in xml.elements(lxml.id(id),pattern) do
        dt[dk].command = action
    end
end

lxml.trace_setups = false

function lxml.setsetup(id,pattern,setup)
    local trace = lxml.trace_setups
    if not setup or setup == "" or setup == "*" then
        for rt, dt, dk in xml.elements(lxml.id(id),pattern) do
            local dtdk = dt and dt[dk] or rt
            local ns, tg = dtdk.rn or dtdk.ns, dtdk.tg
            if ns == "" then
                dtdk.command = tg
            else
                dtdk.command = ns .. ":" .. tg
            end
            if trace then
                texio.write_nl(string.format("lpath matched -> %s -> %s", dtdk.command, dtdk.command))
            end
        end
    else
        if trace then
            texio.write_nl(string.format("lpath pattern -> %s -> %s", pattern, setup))
        end
        for rt, dt, dk in xml.elements(lxml.id(id),pattern) do
            local dtdk = (dt and dt[dk]) or rt
            dtdk.command = setup
            if trace then
                local ns, tg = dtdk.rn or dtdk.ns, dtdk.tg
                if ns == "" then
                    texio.write_nl(string.format("lpath matched -> %s -> %s", tg, setup))
                else
                    texio.write_nl(string.format("lpath matched -> %s:%s -> %s", ns, tg, setup))
                end
            end
        end
    end
end

function lxml.idx(id,pattern,i)
    local r = lxml.id(id)
    if r then
        local rp = r.patterns
        if not rp then
            rp = { }
            r.patterns = rp
        end
        if not rp[pattern] then
            rp[pattern] = xml.collect_elements(r,pattern) -- dd, rr
        end
        local rpi = rp[pattern] and rp[pattern][i]
        if rpi then
            xml.sprint(rpi)
        end
    end
end

do

    local traverse = xml.traverse
    local lpath    = xml.lpath

    function xml.filters.command(root,pattern,command) -- met zonder ''
        command = command:gsub("^([\'\"])(.-)%1$", "%2")
        traverse(root, lpath(pattern), function(r,d,k)
            -- this can become pretty large
            local n = #lxml.self + 1
            lxml.self[n] = (d and d[k]) or r
            tex.sprint(tex.ctxcatcodes,string.format("\\xmlsetup{%s}{%s}",n,command))
        end)
    end

    function lxml.command(id,pattern,command)
        xml.filters.command(lxml.id(id),pattern,command)
    end

end

do

    --~ <?xml version="1.0" standalone="yes"?>
    --~ <!-- demo.cdx -->
    --~ <directives>
    --~ <!--
    --~     <directive attribute='id' value="100" setup="cdx:100"/>
    --~     <directive attribute='id' value="101" setup="cdx:101"/>
    --~ -->
    --~ <!--
    --~     <directive attribute='cdx' value="colors"   element="cals:table" setup="cdx:cals:table:colors"/>
    --~     <directive attribute='cdx' value="vertical" element="cals:table" setup="cdx:cals:table:vertical"/>
    --~     <directive attribute='cdx' value="noframe"  element="cals:table" setup="cdx:cals:table:noframe"/>
    --~ -->
    --~ <directive attribute='cdx' value="*" element="cals:table" setup="cdx:cals:table:*"/>
    --~ </directives>

    lxml.directives = { }

    local data = {
        setup  = { },
        before = { },
        after  = { }
    }

    function lxml.directives.load(filename)
        if texmf then
            local fullname = input.find_file(texmf.instance,filename) or ""
            if fullname ~= "" then
                filename = fullname
            end
        end
        local root = xml.load(filename)
        local format = string.format
        for r, d, k in xml.elements(root,"directive") do
            local dk = d[k]
            local at = dk.at
            local attribute, value, element = at.attribute or "", at.value or "", at.element or '*'
            local setup, before, after = at.setup or "", at.before or "", at.after or ""
            if attribute ~= "" and value ~= "" then
                local key = format("%s::%s::%s",element,attribute,value)
                local t = data[key] or { }
                if setup  ~= "" then t.setup  = setup  end
                if before ~= "" then t.before = before end
                if after  ~= "" then t.after  = after  end
                data[key] = t
            end
        end
    end

    function lxml.directives.setup(root,attribute,element)
        lxml.directives.handle_setup('setup',root,attribute,element)
    end
    function lxml.directives.before(root,attribute,element)
        lxml.directives.handle_setup('before',root,attribute,element)
    end
    function lxml.directives.after(root,attribute,element)
        lxml.directives.handle_setup('after',root,attribute,element)
    end

    function lxml.directives.handle_setup(category,root,attribute,element)
        root = lxml.id(root)
        attribute = attribute
        if attribute then
            local value = root.at[attribute]
            if value then
                if not element then
                    local ns, tg = root.rn or root.ns, root.tg
                    if ns == "" then
                        element = tg
                    else
                        element = ns .. ':' .. tg
                    end
                end
                local format = string.format
                local setup = data[format("%s::%s::%s",element,attribute,value)]
                if setup then
                    setup = setup[category]
                end
                if setup then
                    tex.sprint(tex.ctxcatcodes,format("\\directsetup{%s}",setup))
                else
                    setup = data[format("%s::%s::*",element,attribute)]
                    if setup then
                        setup = setup[category]
                    end
                    if setup then
                        tex.sprint(tex.ctxcatcodes,format("\\directsetup{%s}",setup:gsub('%*',value)))
                    end
                end
            end
        end
    end

end

function xml.getbuffer(name) -- we need to make sure that commands are processed
    xml.tostring(xml.convert(table.join(buffers.data[name] or {},"")))
end

function lxml.loadbuffer(id,name)
    input.starttiming(lxml)
    lxml.loaded[id] = xml.convert(table.join(buffers.data[name or id] or {},""))
    input.stoptiming(lxml)
    return lxml.loaded[id], name or id
end

-- for the moment here:

lxml.set_verbatim("\\xmlcdatabefore", "\\xmlcdataafter", "\\xmlcdataobeyedline", "\\xmlcdataobeyedspace")
lxml.set_cdata()

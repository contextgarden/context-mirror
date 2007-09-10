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

function lxml.id(id)
    return (type(id) == "table" and id) or lxml.loaded[id] or lxml.self[tonumber(id)]
end

function lxml.root(id)
    return lxml.loaded[id]
end

function lxml.load(id,filename)
    input.start_timing(lxml)
    if texmf then
        local fullname = input.find_file(texmf.instance,filename) or ""
        if fullname ~= "" then
            filename = fullname
        end
    end
    lxml.loaded[id] = xml.load(filename)
    input.stop_timing(lxml)
    return lxml.loaded[id], filename
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
    xml.tprint(xml.all(lxml.id(id),pattern))
end

function lxml.nonspace(id,pattern)
    xml.tprint(xml.all(lxml.id(id),pattern,true))
end

function lxml.strip(id,pattern)
    xml.strip(lxml.id(id),pattern)
end

function lxml.text(id,pattern)
    xml.tprint(xml.all_texts(lxml.id(id),pattern) or {})
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
    tex.sprint((xml.filters.attribute(lxml.id(id),pattern,a)) or default or "")
end

function lxml.count(id,pattern)
    tex.sprint(xml.count(lxml.id(id),pattern) or 0)
end
function lxml.name(id)
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
function lxml.namespace(id)
    tex.sprint(lxml.id(id).ns or "")
end

function lxml.concat(id,what,separator)
    tex.sprint(table.concat(xml.all_texts(lxml.id(id),what,true),separator or ""))
end

function xml.command(root) -- todo: free self after usage, so maybe hash after all
    xml.sflush()
    if type(root.command) == "string" then
        local n = #lxml.self + 1
        lxml.self[n] = root
        if xml.trace_print then
            texio.write_nl(string.format("tex.sprint: (((%s:%s)))",n,root.command))
        end
        tex.sprint(tex.ctxcatcodes,string.format("\\xmlsetup{%s}{%s}",n,root.command))
    else
        root.command(root)
    end
end

function lxml.setaction(id,pattern,action)
    for rt, dt, dk in xml.elements(lxml.id(id),pattern) do
        dt[dk].command = action
    end
end

function lxml.setsetup(id,pattern,setup)
    if not setup or setup == "" or setup == "*" then
        for rt, dt, dk in xml.elements(lxml.id(id),pattern) do
            local dtdk = dt[dk]
            if dtdk.ns == "" then
                dtdk.command = dtdk.tg
            else
                dtdk.command = dtdk.ns .. ":" .. dtdk.tg
            end
        end
    else
        for rt, dt, dk in xml.elements(lxml.id(id),pattern) do
            dt[dk].command = setup
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
            rp[pattern] = xml.all_elements(r,pattern) -- dd, rr
        end
        local rpi = rp[pattern] and rp[pattern][i]
        if rpi then
            xml.sprint(rpi)
        end
    end
end

do

    local traverse = xml.traverse_tree
    local lpath    = xml.lpath

    function xml.filters.command(root,pattern,command) -- met zonder ''
        command = command:gsub("^([\'\"])(.-)%1$", "%2")
        traverse(root, lpath(pattern), function(r,d,k)
            -- this can become pretty large
            local n = #lxml.self + 1
            lxml.self[n] = d[k]
            tex.sprint(tex.ctxcatcodes,string.format("\\xmlsetup{%s}{%s}",n,command))
        end)
    end

    function lxml.command(id,pattern,command)
        xml.filters.command(lxml.id(id),pattern,command)
    end

end

do

    lxml.directives = { }

    local data = { }

    function lxml.directives.load(filename)
        if texmf then
            local fullname = input.find_file(texmf.instance,filename) or ""
            if fullname ~= "" then
                filename = fullname
            end
        end
        local root = xml.load(filename)
        for r, d, k in xml.elements(root,"directive") do
            local dk = d[k]
            local at = dk.at
            local id, setup = at.id, at.setup
            if id and setup then
                data[id] = setup
            end
        end
    end

    function lxml.directives.setups(root)
        root = lxml.id(root)
        local id = root.at.id
        if id then
            local setup = data[id]
            if setup then
                tex.sprint(tex.ctxcatcodes,string.format("\\directsetup{%s}",setup))
            end
        end
    end

end

function xml.getbuffer(name) -- we need to make sure that commands are processed
    xml.tostring(xml.convert(table.join(buffers.data[name] or {},"")))
end

function lxml.loadbuffer(id,name)
    input.start_timing(lxml)
    lxml.loaded[id] = xml.convert(table.join(buffers.data[name or id] or {},""))
    input.stop_timing(lxml)
    return lxml.loaded[id], name or id
end

if not modules then modules = { } end modules ['node-ser'] = {
    version   = 1.001,
    comment   = "companion to node-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- beware, some field names will change in a next releases
-- of luatex; this is pretty old code that needs an overhaul

local type, format, concat = type, string.format, table.concat

local ctxcatcodes = tex.ctxcatcodes

local hlist   = node.id('hlist')
local vlist   = node.id('vlist')

local traverse    = node.traverse
local node_fields = node.fields
local node_type   = node.type

local expand = table.tohash {
    "list",         -- list_ptr & ins_ptr & adjust_ptr
    "pre",          --
    "post",         --
    "spec",         -- glue_ptr
    "top_skip",     --
    "attr",         --
    "replace",      -- nobreak
    "components",   -- lig_ptr
    "box_left",     --
    "box_right",    --
    "glyph",        -- margin_char
    "leader",       -- leader_ptr
    "action",       -- action_ptr
    "value",        -- user_defined nodes with subtype 'a' en 'n'
}

-- page_insert: "height", "last_ins_ptr", "best_ins_ptr"
-- split_insert:  "height", "last_ins_ptr", "best_ins_ptr", "broken_ptr", "broken_ins"

local ignore = table.tohash {
    "page_insert",
    "split_insert",
    "ref_count",
}

local dimension = table.tohash {
    "width", "height", "depth", "shift",
    "stretch", "shrink",
    "xoffset", "yoffset",
    "surround",
    "kern",
    "box_left_width", "box_right_width"
}

-- flat: don't use next, but indexes
-- verbose: also add type
-- can be sped up

nodes.dimensionfields = dimension
nodes.listablefields  = expand
nodes.ignorablefields = ignore

-- not ok yet:

function nodes.astable(n,sparse) -- not yet ok
    local f, t = node_fields(n.id,n.subtype), { }
    for i=1,#f do
        local v = f[i]
        local d = n[v]
        if d then
            if ignore[v] or v == "id" then
                -- skip
            elseif expand[v] then -- or: type(n[v]) ~= "string" or type(n[v]) ~= "number" or type(n[v]) ~= "table"
                t[v] = "pointer to list"
            elseif sparse then
                if (type(d) == "number" and d ~= 0) or (type(d) == "string" and d ~= "") then
                    t[v] = d
                end
            else
                t[v] = d
            end
        end
    end
    t.type = node_type(n.id)
    return t
end

-- under construction:

local function totable(n,flat,verbose)
    -- todo: no local function
    local function to_table(n,flat,verbose)
        local f = node_fields(n.id,n.subtype)
        local tt = { }
        for k=1,#f do
            local v = f[k]
            local nv = n[v]
            if nv then
                if ignore[v] then
                    -- skip
                elseif expand[v] then
                    if type(nv) == "number" or type(nv) == "string" then
                        tt[v] = nv
                    else
                        tt[v] = totable(nv,flat,verbose)
                    end
                elseif type(nv) == "table" then
                    tt[v] = nv -- totable(nv,flat,verbose) -- data
                else
                    tt[v] = nv
                end
            end
        end
        if verbose then
            tt.type = node_type(tt.id)
        end
        return tt
    end
    if n then
        if flat then
            local t = { }
            while n do
                t[#t+1] = to_table(n,flat,verbise)
                n = n.next
            end
            return t
        else
            local t = to_table(n)
            if n.next then
                t.next = totable(n.next,flat,verbose)
            end
            return t
        end
    else
        return { }
    end
end

nodes.totable = totable

local function key(k)
    return ((type(k) == "number") and "["..k.."]") or k
end

-- not ok yet; this will become a module

local function serialize(root,name,handle,depth,m)
    handle = handle or print
    if depth then
        depth = depth .. " "
        handle(format("%s%s={",depth,key(name)))
    else
        depth = ""
        local tname = type(name)
        if tname == "string" then
            if name == "return" then
                handle("return {")
            else
                handle(name .. "={")
            end
        elseif tname == "number" then
            handle("[" .. name .. "]={")
        else
            handle("t={")
        end
    end
    if root then
        local fld
        if root.id then
            fld = node_fields(root.id,root.subtype) -- we can cache these (todo)
        else
            fld = table.sortedkeys(root)
        end
        if type(root) == 'table' and root['type'] then -- userdata or table
            handle(format("%s %s=%q,",depth,'type',root['type']))
        end
        for f=1,#fld do
            local k = fld[f]
            if k == "ref_count" then
                -- skip
            elseif k then
                local v = root[k]
                local t = type(v)
                if t == "number" then
                    if v == 0 then
                        -- skip
                    else
                        handle(format("%s %s=%s,",depth,key(k),v))
                    end
                elseif t == "string" then
                    if v == "" then
                        -- skip
                    else
                        handle(format("%s %s=%q,",depth,key(k),v))
                    end
                elseif t == "boolean" then
                    handle(format("%s %s=%q,",depth,key(k),tostring(v)))
                elseif v then -- userdata or table
                    serialize(v,k,handle,depth,m+1)
                end
            end
        end
        if root['next'] then -- userdata or table
            serialize(root['next'],'next',handle,depth,m+1)
        end
    end
    if m and m > 0 then
        handle(format("%s},",depth))
    else
        handle(format("%s}",depth))
    end
end

function nodes.serialize(root,name)
    local t = { }
    local function flush(s)
        t[#t+1] = s
    end
    serialize(root, name, flush, nil, 0)
    return concat(t,"\n")
end

function nodes.serializebox(n,flat,verbose,name)
    return nodes.serialize(nodes.totable(tex.box[n],flat,verbose),name)
end

function nodes.visualizebox(...)
    tex.print(ctxcatcodes,"\\starttyping")
    tex.print(nodes.serializebox(...))
    tex.print("\\stoptyping")
end

function nodes.list(head,n) -- name might change to nodes.type
    if not n then
        tex.print(ctxcatcodes,"\\starttyping")
    end
    while head do
        local id = head.id
        tex.print(string.rep(" ",n or 0) .. tostring(head) .. "\n")
        if id == hlist or id == vlist then
            nodes.list(head.list,(n or 0)+1)
        end
        head = head.next
    end
    if not n then
        tex.print("\\stoptyping")
    end
end

function nodes.print(head,n)
    while head do
        local id = head.id
        texio.write_nl(string.rep(" ",n or 0) .. tostring(head))
        if id == hlist or id == vlist then
            nodes.print(head.list,(n or 0)+1)
        end
        head = head.next
    end
end

function nodes.check_for_leaks(sparse)
    local l = { }
    local q = node.usedlist()
    for p in traverse(q) do
        local s = table.serialize(nodes.astable(p,sparse),node_type(p.id))
        l[s] = (l[s] or 0) + 1
    end
    node.flush_list(q)
    for k, v in next, l do
        texio.write_nl(format("%s * %s", v, k))
    end
end


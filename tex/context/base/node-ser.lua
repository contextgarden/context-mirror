if not modules then modules = { } end modules ['node-ser'] = {
    version   = 1.001,
    comment   = "companion to node-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- beware, some field names will change in a next releases
-- of luatex; this is pretty old code that needs an overhaul

local type, format, rep = type, string.format, string.rep
local concat, tohash, sortedkeys, printtable = table.concat, table.tohash, table.sortedkeys, table.print

local allocate = utilities.storage.allocate

local context     = context
local nodes       = nodes
local node        = node

local traverse    = node.traverse
local is_node     = node.is_node

local nodecodes   = nodes.nodecodes
local noadcodes   = nodes.noadcodes
local nodefields  = nodes.fields

local hlist_code  = nodecodes.hlist
local vlist_code  = nodecodes.vlist

local expand = allocate ( tohash {
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
    "head",
} )

-- page_insert: "height", "last_ins_ptr", "best_ins_ptr"
-- split_insert:  "height", "last_ins_ptr", "best_ins_ptr", "broken_ptr", "broken_ins"

local ignore = allocate ( tohash {
    "page_insert",
    "split_insert",
    "ref_count",
} )

local dimension = allocate ( tohash {
    "width", "height", "depth", "shift",
    "stretch", "shrink",
    "xoffset", "yoffset",
    "surround",
    "kern",
    "box_left_width", "box_right_width"
} )

-- flat: don't use next, but indexes
-- verbose: also add type
-- can be sped up

nodes.dimensionfields = dimension
nodes.listablefields  = expand
nodes.ignorablefields = ignore

-- not ok yet:

local function astable(n,sparse) -- not yet ok
    local f, t = nodefields(n), { }
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
    t.type = nodecodes[n.id]
    return t
end

nodes.astable = astable

setinspector(function(v) if is_node(v) then printtable(astable(v),tostring(v)) return true end end)

-- under construction:

local function totable(n,flat,verbose,noattributes)
    -- todo: no local function
    local function to_table(n,flat,verbose,noattributes) -- no need to pass
        local f = nodefields(n)
        local tt = { }
        for k=1,#f do
            local v = f[k]
            local nv = v and n[v]
            if nv then
                if ignore[v] then
                    -- skip
                elseif noattributes and v == "attr" then
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
            tt.type = nodecodes[tt.id]
        end
        return tt
    end
    if n then
        if flat then
            local t, tn = { }, 0
            while n do
                tn = tn + 1
                t[tn] = to_table(n,flat,verbose,noattributes)
                n = n.next
            end
            return t
        else
            local t = to_table(n)
            if n.next then
                t.next = totable(n.next,flat,verbose,noattributes)
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

-- todo: adapt to nodecodes etc

local function serialize(root,name,handle,depth,m,noattributes)
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
            fld = nodefields(root) -- we can cache these (todo)
        else
            fld = sortedkeys(root)
        end
        if type(root) == 'table' and root['type'] then -- userdata or table
            handle(format("%s %s=%q,",depth,'type',root['type']))
        end
        for f=1,#fld do
            local k = fld[f]
            if k == "ref_count" then
                -- skip
            elseif noattributes and k == "attr" then
                -- skip
            elseif k == "id" then
                local v = root[k]
                handle(format("%s id=%s,",depth,nodecodes[v] or noadcodes[v] or v))
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
                    serialize(v,k,handle,depth,m+1,noattributes)
                end
            end
        end
        if root['next'] then -- userdata or table
            serialize(root['next'],'next',handle,depth,m+1,noattributes)
        end
    end
    if m and m > 0 then
        handle(format("%s},",depth))
    else
        handle(format("%s}",depth))
    end
end

function nodes.serialize(root,name,noattributes)
    local t, n = { }, 0
    local function flush(s)
        n = n + 1
        t[n] = s
    end
    serialize(root,name,flush,nil,0,noattributes)
    return concat(t,"\n")
end

function nodes.serializebox(n,flat,verbose,name)
    return nodes.serialize(nodes.totable(tex.box[n],flat,verbose),name)
end

function nodes.visualizebox(...) -- to be checked .. will move to module anyway
    context.starttyping()
    context.pushcatcodes("verbatim")
    context(nodes.serializebox(...))
    context.stoptyping()
    context.popcatcodes()
end

function nodes.list(head,n) -- name might change to nodes.type -- to be checked .. will move to module anyway
    if not n then
        context.starttyping(true)
    end
    while head do
        local id = head.id
        context(rep(" ",n or 0) .. tostring(head) .. "\n")
        if id == hlist_code or id == vlist_code then
            nodes.list(head.list,(n or 0)+1)
        end
        head = head.next
    end
    if not n then
        context.stoptyping(true)
    end
end

function nodes.print(head,n)
    while head do
        local id = head.id
        logs.writer(string.formatters["%w%S"],n or 0,head)
        if id == hlist_code or id == vlist_code then
            nodes.print(head.list,(n or 0)+1)
        end
        head = head.next
    end
end

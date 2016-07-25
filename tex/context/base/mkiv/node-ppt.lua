if not modules then modules = { } end modules ['node-ppt'] = {
    version   = 1.001,
    comment   = "companion to node-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- This is all very exeperimental and likely to change.

local next, type, unpack, load = next, type, table.unpack, load

local serialize = table.serialize
local formatters = string.formatters

local report           = logs.reporter("properties")
local report_setting   = logs.reporter("properties","setting")
local trace_setting    = false trackers.register("properties.setting", function(v) trace_setting = v end)

-- report("using experimental properties")

local nuts             = nodes.nuts
local tonut            = nuts.tonut
local tonode           = nuts.tonode
local getid            = nuts.getid
local getnext          = nuts.getnext
local getprev          = nuts.getprev
local getsubtype       = nuts.getsubtype
local getfield         = nuts.getfield
local setfield         = nuts.setfield
local getlist          = nuts.getlist
local setlist          = nuts.setlist
local removenode       = nuts.remove
local traverse         = nuts.traverse
local traverse_id      = nuts.traverse_id

local nodecodes        = nodes.nodecodes
local whatsitcodes     = nodes.whatsitcodes

local whatsit_code     = nodecodes.whatsit
local hlist_code       = nodecodes.hlist
local vlist_code       = nodecodes.vlist
local userdefined_code = whatsitcodes.userdefined

local nodepool         = nodes.pool
local new_usernumber   = nodepool.usernumber

local variables        = interfaces.variables
local v_before         = variables.before
local v_after          = variables.after
local v_here           = variables.here

local cache            = { }
local nofslots         = 0
local property_id      = nodepool.userids["property"]

local properties       = nodes.properties
local propertydata     = properties.data

local starttiming      = statistics.starttiming
local stoptiming       = statistics.stoptiming

if not propertydata then
    return
end

-- management

local function register(where,data,...)
    if not data then
        data  = where
        where = v_after
    end
    if data then
        local data = { where, data, ... }
        nofslots = nofslots + 1
        if nofslots > 1 then
            cache[nofslots] = data
        else
         -- report("restarting attacher")
            cache = { data } -- also forces collection
        end
        return new_usernumber(property_id,nofslots)
    end
end

local writenode = node.write
local flushnode = context.nodes.flush

function commands.deferredproperty(...)
--  context(register(...))
    flushnode(register(...))
end

function commands.immediateproperty(...)
    writenode(register(...))
end

commands.attachproperty = commands.deferredproperty

local actions = { } properties.actions = actions

table.setmetatableindex(actions,function(t,k)
    report("unknown property action %a",k)
    local v = function() end
    return v
end)

local f_delayed   = formatters["return function(target,head,where,propdata,parent) %s end"]
local f_immediate = formatters["return function(target,head,where,propdata) %s end"]

local nofdelayed  = 0 -- better is to keep track of it per page ... we can have deleted nodes with properties

function actions.delayed(target,head,where,propdata,code,...) -- this one is used at the tex end
--    local kind = type(code)
--    if kind == "string" then
--        code, err = load(f_delayed(code))
--        if code then
--            code = code()
--        end
--    elseif kind ~= "function" then
--        code = nil
--    end
    if code then
        local delayed = propdata.delayed
        if delayed then
            delayed[#delayed+1] = { where, code, ... }
        else
            propdata.delayed = { { where, code, ... } }
            nofdelayed = nofdelayed + 1
        end
    end
end

function actions.fdelayed(target,head,where,propdata,code,...) -- this one is used at the tex end
--    local kind = type(code)
--    if kind == "string" then
--        code, err = load(f_delayed(code))
--        if code then
--            code = code()
--        end
--    elseif kind ~= "function" then
--        code = nil
--    end
    if code then
        local delayed = propdata.delayed
        if delayed then
            delayed[#delayed+1] = { false, code, ... }
        else
            propdata.delayed = { { false, code, ... } }
            nofdelayed = nofdelayed + 1
        end
    end
end

function actions.immediate(target,head,where,propdata,code,...) -- this one is used at the tex end
    local kind = type(code)
    if kind == "string" then
        local f = f_immediate(code)
        local okay, err = load(f)
        if okay then
            local h = okay()(target,head,where,propdata,...)
            if h and h ~= head then
                return h
            end
        end
    elseif kind == "function" then
        local h = code()(target,head,where,propdata,...)
        if h and h ~= head then
            return h
        end
    end
end

-- another experiment (a table or function closure are equally efficient); a function
-- is easier when we want to experiment with different (compatible) implementations

-- local nutpool          = nuts.pool
-- local nut_usernumber = nutpool.usernumber

-- function nodes.nuts.pool.deferredfunction(...)
--     nofdelayed = nofdelayed + 1
--     local n = nut_usernumber(property_id,0)
--     propertydata[n] = { deferred = { ... } }
--     return n
-- end

-- function nodes.nuts.pool.deferredfunction(f)
--     nofdelayed = nofdelayed + 1
--     local n = nut_usernumber(property_id,0)
--     propertydata[n] = { deferred = f }
--     return n
-- end

-- maybe actions will get parent too

local function delayed(head,parent) -- direct based
    for target in traverse(head) do
        local p = propertydata[target]
        if p then
         -- local deferred = p.deferred -- kind of late lua (but too soon as we have no access to pdf.h/v)
         -- if deferred then
         --  -- if #deferred > 0 then
         --  --     deferred[1](unpack(deferred,2))
         --  -- else
         --  --     deferred[1]()
         --  -- end
         --     deferred()
         --     p.deferred = false
         --     if nofdelayed == 1 then
         --         nofdelayed = 0
         --         return head
         --     else
         --         nofdelayed = nofdelayed - 1
         --     end
         -- else
                local delayed = p.delayed
                if delayed then
                    for i=1,#delayed do
                        local d = delayed[i]
                        local code  = d[2]
                        local kind = type(code)
                        if kind == "string" then
                            code, err = load(f_delayed(code))
                            if code then
                                code = code()
                            end
                        end
                        local where = d[1]
                        if where then
                            local h = code(target,where,head,p,parent,unpack(d,3)) -- target where propdata head parent
                            if h and h ~= head then
                                head = h
                            end
                        else
                            code(unpack(d,3))
                        end
                    end
                    p.delayed = nil
                    if nofdelayed == 1 then
                        nofdelayed = 0
                        return head
                    else
                        nofdelayed = nofdelayed - 1
                    end
                end
         -- end
        end
        local id = getid(target)
        if id == hlist_code or id == vlist_code then
            local list = getlist(target)
            if list then
                local done = delayed(list,parent)
                if done then
                    setlist(target,done)
                end
                if nofdelayed == 0 then
                    return head
                end
            end
        else
            -- maybe also some more lists? but we will only use this for some
            -- special cases .. who knows
        end
    end
    return head
end

function properties.delayed(head) --
    if nofdelayed > 0 then
     -- if next(propertydata) then
            starttiming(properties)
            head = delayed(tonut(head))
            stoptiming(properties)
            return tonode(head), true -- done in shipout anyway
     -- else
     --     delayed = 0
     --  end
    end
    return head, false
end

-- more explicit ones too

local anchored = {
    [v_before] = function(n)
        while n do
            n = getprev(n)
            if getid(n) == whatsit_code and getsubtype(n) == user_code and getfield(n,"user_id") == property_id then
                -- continue
            else
                return n
            end
        end
    end,
    [v_after] = function(n)
        while n do
            n = getnext(n)
            if getid(n) == whatsit_code then
                local subtype = getsubtype(n)
                if (subtype == userdefined_code and getfield(n,"user_id") == property_id) then
                    -- continue
                else
                    return n
                end
            else
                return n
            end
        end
    end,
    [v_here] = function(n)
        -- todo
    end,
}

table.setmetatableindex(anchored,function(t,k)
    v = anchored[v_after]
    t[k] = v
    return v
end)

function properties.attach(head)

    if nofslots <= 0 then
        return head, false
    end

    local done = false
    local last = nil
    local head = tonut(head)

    starttiming(properties)

    for source in traverse_id(whatsit_code,head) do
        if getsubtype(source) == userdefined_code then
            if last then
                removenode(head,last,true)
                last = nil
            end
            if getfield(source,"user_id") == property_id then
                local slot = getfield(source,"value")
                local data = cache[slot]
                if data then
                    cache[slot] = nil
                    local where  = data[1]
                    local target = anchored[where](source)
                    if target then
                        local first    = data[2]
                        local method   = type(first)
                        local p_target = propertydata[target]
                        local p_source = propertydata[source]
                        if p_target then
                            if p_source then
                                for k, v in next, p_source do
                                    p_target[k] = v
                                end
                            end
                            if method == "table" then
                                for k, v in next, first do
                                    p_target[k] = v
                                end
                            elseif method == "function" then
                                first(target,head,where,p_target,unpack(data,3))
                            elseif method == "string" then
                                actions[first](target,head,where,p_target,unpack(data,3))
                            end
                        elseif p_source then
                            if method == "table" then
                                propertydata[target] = p_source
                                for k, v in next, first do
                                    p_source[k] = v
                                end
                            elseif method == "function" then
                                propertydata[target] = p_source
                                first(target,head,where,p_source,unpack(data,3))
                            elseif method == "string" then
                                propertydata[target] = p_source
                                actions[first](target,head,where,p_source,unpack(data,3))
                            end
                        else
                            if method == "table" then
                                propertydata[target] = first
                            elseif method == "function" then
                                local t = { }
                                propertydata[target] = t
                                first(target,head,where,t,unpack(data,3))
                            elseif method == "string" then
                                local t = { }
                                propertydata[target] = t
                                actions[first](target,head,where,t,unpack(data,3))
                            end
                        end
                        if trace_setting then
                            report_setting("node %i, id %s, data %s",
                                target,nodecodes[getid(target)],serialize(propertydata[target],false))
                        end
                    end
                    if nofslots == 1  then
                        nofslots = 0
                        last = source
                        break
                    else
                        nofslots = nofslots - 1
                    end
                end
                last = source
            end
        end
    end

    if last then
        removenode(head,last,true)
    end

    stoptiming(properties)

    return head, done

end

local tasks = nodes.tasks

-- maybe better hard coded in-place

-- tasks.prependaction("processors","before","nodes.properties.attach")
-- tasks.appendaction("shipouts","normalizers","nodes.properties.delayed")

statistics.register("properties processing time", function()
    return statistics.elapsedseconds(properties)
end)

-- only for development

-- local function show(head,level,report)
--     for target in traverse(head) do
--         local p = propertydata[target]
--         if p then
--             report("level %i, node %i, id %s, data %s",
--                 level,target,nodecodes[getid(target)],serialize(propertydata[target],false))
--         end
--         local id = getid(target)
--         if id == hlist_code or id == vlist_code then
--             local list = getlist(target)
--             if list then
--                 show(list,level+1,report)
--             end
--         else
--             -- maybe more lists
--         end
--     end
--     return head, false
-- end
--
-- local report_shipout    = logs.reporter("properties","shipout")
-- local report_processors = logs.reporter("properties","processors")
--
-- function properties.showshipout   (head) return tonode(show(tonut(head),1,report_shipout   )), true end
-- function properties.showprocessors(head) return tonode(show(tonut(head),1,report_processors)), true end
--
-- tasks.prependaction("shipouts","before","nodes.properties.showshipout")
-- tasks.disableaction("shipouts","nodes.properties.showshipout")
--
-- trackers.register("properties.shipout",function(v)
--     tasks.setaction("shipouts","nodes.properties.showshipout",v)
-- end)
--
-- tasks.appendaction ("processors","after","nodes.properties.showprocessors")
-- tasks.disableaction("processors","nodes.properties.showprocessors")
--
-- trackers.register("properties.processors",function(v)
--     tasks.setaction("processors","nodes.properties.showprocessors",v)
-- end)

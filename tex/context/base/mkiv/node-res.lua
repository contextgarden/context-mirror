if not modules then modules = { } end modules ['node-res'] = {
    version   = 1.001,
    comment   = "companion to node-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local gmatch, format = string.gmatch, string.format
local tonumber, round = tonumber, math.round

--[[ldx--
<p>The next function is not that much needed but in <l n='context'/> we use
for debugging <l n='luatex'/> node management.</p>
--ldx]]--

local report_nodes = logs.reporter("nodes","housekeeping")

local nodes, node = nodes, node

nodes.pool          = nodes.pool or { }
local nodepool      = nodes.pool

local whatsitcodes  = nodes.whatsitcodes
local skipcodes     = nodes.skipcodes
local kerncodes     = nodes.kerncodes
local rulecodes     = nodes.rulecodes
local nodecodes     = nodes.nodecodes
local boundarycodes = nodes.boundarycodes
local usercodes     = nodes.usercodes

local glyph_code    = nodecodes.glyph

local allocate      = utilities.storage.allocate

local texgetcount   = tex.getcount

local reserved, nofreserved = { }, 0

-- user nodes

local userids = allocate()
local lastid  = 0

setmetatable(userids, {
    __index = function(t,k)
        if type(k) == "string" then
            lastid = lastid + 1
            rawset(userids,lastid,k)
            rawset(userids,k,lastid)
            return lastid
        else
            rawset(userids,k,k)
            return k
        end
    end,
    __call = function(t,k)
        return t[k]
    end
} )

-- nuts overload

local nuts       = nodes.nuts
local nutpool    = { }
nuts.pool        = nutpool

local tonut      = nuts.tonut
local tonode     = nuts.tonode

local getbox     = nuts.getbox
local getfield   = nuts.getfield
local getid      = nuts.getid
local getlist    = nuts.getlist

local setfield   = nuts.setfield
local setchar    = nuts.setchar
local setlist    = nuts.setlist

local copy_nut   = nuts.copy
local new_nut    = nuts.new
local flush_nut  = nuts.flush

local copy_node  = nodes.copy
local new_node   = nodes.new

-- at some point we could have a dual set (the overhead of tonut is not much larger than
-- metatable associations at the lua/c end esp if we also take assignments into account

-- table.setmetatableindex(nodepool,function(t,k,v)
--  -- report_nodes("defining nodepool[%s] instance",k)
--     local f = nutpool[k]
--     local v = function(...)
--         return tonode(f(...))
--     end
--     t[k] = v
--     return v
-- end)
--
-- -- we delay one step because that permits us a forward reference
-- -- e.g. in pdfsetmatrix

table.setmetatableindex(nodepool,function(t,k,v)
 -- report_nodes("defining nodepool[%s] instance",k)
    local v = function(...)
        local f = nutpool[k]
        local v = function(...)
            return tonode(f(...))
        end
        t[k] = v
        return v(...)
    end
    t[k] = v
    return v
end)

local function register_nut(n)
    nofreserved = nofreserved + 1
    reserved[nofreserved] = n
    return n
end

local function register_node(n)
    nofreserved = nofreserved + 1
    if type(n) == "number" then -- isnut(n)
        reserved[nofreserved] = n
    else
        reserved[nofreserved] = tonut(n)
    end
    return n
end

nodepool.userids  = userids
nodepool.register = register_node

nutpool.userids   = userids
nutpool.register  = register_node -- could be register_nut

-- so far

local disc              = register_nut(new_nut("disc"))
local kern              = register_nut(new_nut("kern",kerncodes.userkern))
local fontkern          = register_nut(new_nut("kern",kerncodes.fontkern))
local italickern        = register_nut(new_nut("kern",kerncodes.italiccorrection))
local penalty           = register_nut(new_nut("penalty"))
local glue              = register_nut(new_nut("glue")) -- glue.spec = nil
local glue_spec         = register_nut(new_nut("glue_spec"))
local glyph             = register_nut(new_nut("glyph",0))

local textdir           = register_nut(new_nut("dir"))

local latelua           = register_nut(new_nut("whatsit",whatsitcodes.latelua))
local special           = register_nut(new_nut("whatsit",whatsitcodes.special))

local user_node         = new_nut("whatsit",whatsitcodes.userdefined)

local user_number       = register_nut(copy_nut(user_node)) setfield(user_number,    "type",usercodes.number)
local user_nodes        = register_nut(copy_nut(user_node)) setfield(user_nodes,     "type",usercodes.nodes)
local user_string       = register_nut(copy_nut(user_node)) setfield(user_string,    "type",usercodes.string)
local user_tokens       = register_nut(copy_nut(user_node)) setfield(user_tokens,    "type",usercodes.tokens)
----- user_lua          = register_nut(copy_nut(user_node)) setfield(user_lua,       "type",usercodes.lua) -- in > 0.95
local user_attributes   = register_nut(copy_nut(user_node)) setfield(user_attributes,"type",usercodes.attributes)

local left_margin_kern  = register_nut(new_nut("margin_kern",0))
local right_margin_kern = register_nut(new_nut("margin_kern",1))

local lineskip          = register_nut(new_nut("glue",skipcodes.lineskip))
local baselineskip      = register_nut(new_nut("glue",skipcodes.baselineskip))
local leftskip          = register_nut(new_nut("glue",skipcodes.leftskip))
local rightskip         = register_nut(new_nut("glue",skipcodes.rightskip))

local temp              = register_nut(new_nut("temp",0))

local noad              = register_nut(new_nut("noad"))

local boundary          = register_nut(new_nut("boundary",boundarycodes.user))
local wordboundary      = register_nut(new_nut("boundary",boundarycodes.word))

-- the dir field needs to be set otherwise crash:

local rule              = register_nut(new_nut("rule"))                  setfield(rule, "dir","TLT")
local emptyrule         = register_nut(new_nut("rule",rulecodes.empty))  setfield(rule, "dir","TLT")
local userrule          = register_nut(new_nut("rule",rulecodes.user))   setfield(rule, "dir","TLT")
local hlist             = register_nut(new_nut("hlist"))                 setfield(hlist,"dir","TLT")
local vlist             = register_nut(new_nut("vlist"))                 setfield(vlist,"dir","TLT")

function nutpool.zeroglue(n)
    if n then
        return
            getfield(n,"width")         == 0 and
            getfield(n,"stretch")       == 0 and
            getfield(n,"shrink")        == 0 and
            getfield(n,"stretch_order") == 0 and
            getfield(n,"shrink_order")  == 0
    else
        return false
    end
end

function nutpool.glyph(fnt,chr)
    local n = copy_nut(glyph)
    if fnt then setfield(n,"font",fnt) end
    if chr then setchar(n,chr) end
    return n
end

function nutpool.penalty(p)
    local n = copy_nut(penalty)
    if p and p ~= 0 then
        setfield(n,"penalty",p)
    end
    return n
end

function nutpool.kern(k)
    local n = copy_nut(kern)
    if k and k ~= 0 then
        setfield(n,"kern",k)
    end
    return n
end

function nutpool.boundary(v)
    local n = copy_nut(boundary)
    if v and v ~= 0 then
        setfield(n,"value",v)
    end
    return n
end

function nutpool.wordboundary(v)
    local n = copy_nut(wordboundary)
    if v and v ~= 0 then
        setfield(n,"value",v)
    end
    return n
end

function nutpool.fontkern(k)
    local n = copy_nut(fontkern)
    setfield(n,"kern",k)
    return n
end

function nutpool.italickern(k)
    local n = copy_nut(italickern)
    if k and k ~= 0 then
        setfield(n,"kern",k)
    end
    return n
end

function nutpool.gluespec(width,stretch,shrink,stretch_order,shrink_order)
    -- maybe setglue
    local s = copy_nut(glue_spec)
    if width and width ~= 0 then
        setfield(s,"width",width)
    end
    if stretch and stretch ~= 0 then
        setfield(s,"stretch",stretch)
    end
    if shrink and shrink ~= 0 then
        setfield(s,"shrink",shrink)
    end
    if stretch_order and stretch_order ~= 0 then
        setfield(s,"stretch_order",stretch_order)
    end
    if shrink_order and shrink_order ~= 0 then
        setfield(s,"shrink_order",shrink_order)
    end
    return s
end

local function someskip(skip,width,stretch,shrink,stretch_order,shrink_order)
    -- maybe setglue
    local n = copy_nut(skip)
    if width and width ~= 0 then
        setfield(n,"width",width)
    end
    if stretch and stretch ~= 0 then
        setfield(n,"stretch",stretch)
    end
    if shrink and shrink ~= 0 then
        setfield(n,"shrink",shrink)
    end
    if stretch_order and stretch_order ~= 0 then
        setfield(n,"stretch_order",stretch_order)
    end
    if shrink_order and shrink_order ~= 0 then
        setfield(n,"shrink_order",shrink_order)
    end
    return n
end

function nutpool.stretch(a,b)
    local n = copy_nut(glue)
    if b then
        setfield(n,"stretch",a)
        setfield(n,"stretch_order",b)
    else
        setfield(n,"stretch",1)
        setfield(n,"stretch_order",a or 1)
    end
    return n
end

function nutpool.shrink(a,b)
    local n = copy_nut(glue)
    if b then
        setfield(n,"shrink",a)
        setfield(n,"shrink_order",b)
    else
        setfield(n,"shrink",1)
        setfield(n,"shrink_order",a or 1)
    end
    return n
end

function nutpool.glue(width,stretch,shrink,stretch_order,shrink_order)
    return someskip(glue,width,stretch,shrink,stretch_order,shrink_order)
end

function nutpool.negatedglue(glue)
    local n = copy_nut(glue)
    local width   = getfield(n,"width")
    local stretch = getfield(n,"stretch")
    local shrink  = getfield(n,"shrink")
    if width and width ~= 0 then
        setfield(n,"width",  -width)
    end
    if stretch and stretch ~= 0 then
        setfield(n,"stretch",-stretch)
    end
    if shrink and shrink ~= 0 then
        setfield(n,"shrink", -shrink)
    end
    return n
end

function nutpool.leftskip(width,stretch,shrink,stretch_order,shrink_order)
    return someskip(leftskip,width,stretch,shrink,stretch_order,shrink_order)
end

function nutpool.rightskip(width,stretch,shrink,stretch_order,shrink_order)
    return someskip(rightskip,width,stretch,shrink,stretch_order,shrink_order)
end

function nutpool.lineskip(width,stretch,shrink,stretch_order,shrink_order)
    return someskip(lineskip,width,stretch,shrink,stretch_order,shrink_order)
end

function nutpool.baselineskip(width,stretch,shrink)
    return someskip(baselineskip,width,stretch,shrink)
end

function nutpool.disc()
    return copy_nut(disc)
end

function nutpool.textdir(dir)
    local t = copy_nut(textdir)
    setfield(t,"dir",dir)
    return t
end

function nutpool.rule(width,height,depth,dir) -- w/h/d == nil will let them adapt
    local n = copy_nut(rule)
    if width then -- also 0 else adapt
        setfield(n,"width",width)
    end
    if height then -- also 0 else adapt
        setfield(n,"height",height)
    end
    if depth then -- also 0 else adapt
        setfield(n,"depth",depth)
    end
    if dir then
        setfield(n,"dir",dir)
    end
    return n
end

function nutpool.emptyrule(width,height,depth,dir) -- w/h/d == nil will let them adapt
    local n = copy_nut(emptyrule)
    if width then -- also 0 else adapt
        setfield(n,"width",width)
    end
    if height then -- also 0 else adapt
        setfield(n,"height",height)
    end
    if depth then -- also 0 else adapt
        setfield(n,"depth",depth)
    end
    if dir then
        setfield(n,"dir",dir)
    end
    return n
end

function nutpool.userrule(width,height,depth,dir) -- w/h/d == nil will let them adapt
    local n = copy_nut(userrule)
    if width then -- also 0 else adapt
        setfield(n,"width",width)
    end
    if height then -- also 0 else adapt
        setfield(n,"height",height)
    end
    if depth then -- also 0 else adapt
        setfield(n,"depth",depth)
    end
    if dir then
        setfield(n,"dir",dir)
    end
    return n
end

function nutpool.latelua(code)
    local n = copy_nut(latelua)
    setfield(n,"string",code)
    return n
end

----- latelua_node  = register_node(new_node("whatsit",whatsitcodes.latelua))
local latelua_nut   = register_nut (new_nut ("whatsit",whatsitcodes.latelua))

-- local setfield_node = nodes.setfield
-- local setfield_nut  = nuts .setfield

-- function nodepool.lateluafunction(f)
--     local n = copy_node(latelua_node)
--     setfield_node(n,"string",f)
--     return n
-- end

function nutpool.lateluafunction(f)
    local n = copy_nut(latelua_nut)
    setfield(n,"string",f)
    return n
end

function nutpool.leftmarginkern(glyph,width)
    local n = copy_nut(left_margin_kern)
    if not glyph then
        report_nodes("invalid pointer to left margin glyph node")
    elseif getid(glyph) ~= glyph_code then
        report_nodes("invalid node type %a for %s margin glyph node",nodecodes[glyph],"left")
    else
        setfield(n,"glyph",glyph)
    end
    if width and width ~= 0 then
        setfield(n,"width",width)
    end
    return n
end

function nutpool.rightmarginkern(glyph,width)
    local n = copy_nut(right_margin_kern)
    if not glyph then
        report_nodes("invalid pointer to right margin glyph node")
    elseif getid(glyph) ~= glyph_code then
        report_nodes("invalid node type %a for %s margin glyph node",nodecodes[p],"right")
    else
        setfield(n,"glyph",glyph)
    end
    if width and width ~= 0 then
        setfield(n,"width",width)
    end
    return n
end

function nutpool.temp()
    return copy_nut(temp)
end

function nutpool.noad()
    return copy_nut(noad)
end

local function new_hlist(list,width,height,depth,shift)
    local n = copy_nut(hlist)
    if list then
        setlist(n,list)
    end
    if width and width ~= 0 then
        setfield(n,"width",width)
    end
    if height and height ~= 0 then
        setfield(n,"height",height)
    end
    if depth and depth ~= 0 then
        setfield(n,"depth",depth)
    end
    if shift and shift ~= 0 then
        setfield(n,"shift",shift)
    end
    return n
end

local function new_vlist(list,width,height,depth,shift)
    local n = copy_nut(vlist)
    if list then
        setlist(n,list)
    end
    if width and width ~= 0 then
        setfield(n,"width",width)
    end
    if height and height ~= 0 then
        setfield(n,"height",height)
    end
    if depth and depth ~= 0 then
        setfield(n,"depth",depth)
    end
    if shift and shift ~= 0 then
        setfield(n,"shift",shift)
    end
    return n
end

nutpool.hlist = new_hlist
nutpool.vlist = new_vlist

function nodepool.hlist(list,width,height,depth,shift)
    return tonode(new_hlist(list and tonut(list),width,height,depth,shift))
end

function nodepool.vlist(list,width,height,depth,shift)
    return tonode(new_vlist(list and tonut(list),width,height,depth,shift))
end

-- local num = userids["my id"]
-- local str = userids[num]

function nutpool.usernumber(id,num)
    local n = copy_nut(user_number)
    if num then
        setfield(n,"user_id",id)
        setfield(n,"value",num)
    elseif id then
        setfield(n,"value",id)
    end
    return n
end

function nutpool.userlist(id,list)
    local n = copy_nut(user_nodes)
    if list then
        setfield(n,"user_id",id)
        setfield(n,"value",list)
    else
        setfield(n,"value",id)
    end
    return n
end

function nutpool.userstring(id,str)
    local n = copy_nut(user_string)
    if str then
        setfield(n,"user_id",id)
        setfield(n,"value",str)
    else
        setfield(n,"value",id)
    end
    return n
end

function nutpool.usertokens(id,tokens)
    local n = copy_nut(user_tokens)
    if tokens then
        setfield(n,"user_id",id)
        setfield(n,"value",tokens)
    else
        setfield(n,"value",id)
    end
    return n
end

function nutpool.userlua(id,code)
    local n = copy_nut(user_lua)
    if code then
        setfield(n,"user_id",id)
        setfield(n,"value",code)
    else
        setfield(n,"value",id)
    end
    return n
end

function nutpool.userattributes(id,attr)
    local n = copy_nut(user_attributes)
    if attr then
        setfield(n,"user_id",id)
        setfield(n,"value",attr)
    else
        setfield(n,"value",id)
    end
    return n
end

function nutpool.special(str)
    local n = copy_nut(special)
    setfield(n,"data",str)
    return n
end

-- housekeeping

local function cleanup(nofboxes) -- todo
    if nodes.tracers.steppers then -- to be resolved
        nodes.tracers.steppers.reset() -- todo: make a registration subsystem
    end
    local nl = 0
    local nr = nofreserved
    for i=1,nofreserved do
        local ri = reserved[i]
        flush_nut(reserved[i])
    end
    if nofboxes then
        for i=0,nofboxes do
            local l = getbox(i)
            if l then
                flush_nut(l) -- also list ?
                nl = nl + 1
            end
        end
    end
    reserved    = { }
    nofreserved = 0
    return nr, nl, nofboxes -- can be nil
end


local function usage()
    local t = { }
    for n, tag in gmatch(status.node_mem_usage,"(%d+) ([a-z_]+)") do
        t[tag] = n
    end
    return t
end

nutpool .cleanup = cleanup
nodepool.cleanup = cleanup

nutpool .usage   = usage
nodepool.usage   = usage

-- end

statistics.register("cleaned up reserved nodes", function()
    return format("%s nodes, %s lists of %s", cleanup(texgetcount("c_syst_last_allocated_box")))
end) -- \topofboxstack

statistics.register("node memory usage", function() -- comes after cleanup !
    local usage = status.node_mem_usage
    if usage ~= "" then
        return usage
    end
end)

lua.registerfinalizer(cleanup, "cleanup reserved nodes")

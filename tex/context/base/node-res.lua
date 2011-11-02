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

local copy_node    = node.copy
local free_node    = node.free
local free_list    = node.flush_list
local new_node     = node.new

nodes.pool         = nodes.pool or { }
local pool         = nodes.pool

local whatsitcodes = nodes.whatsitcodes
local skipcodes    = nodes.skipcodes
local kerncodes    = nodes.kerncodes
local nodecodes    = nodes.nodecodes

local glyph_code   = nodecodes.glyph

local reserved, nofreserved = { }, 0

local function register_node(n)
    nofreserved = nofreserved + 1
    reserved[nofreserved] = n
    return n
end

pool.register = register_node

function pool.cleanup(nofboxes) -- todo
    nodes.tracers.steppers.reset() -- todo: make a registration subsystem
    local nl, nr = 0, nofreserved
    for i=1,nofreserved do
        local ri = reserved[i]
    --  if not (ri.id == glue_spec and not ri.is_writable) then
            free_node(reserved[i])
    --  end
    end
    if nofboxes then
        local tb = tex.box
        for i=0,nofboxes do
            local l = tb[i]
            if l then
                free_node(tb[i])
                nl = nl + 1
            end
        end
    end
    reserved = { }
    nofreserved = 0
    return nr, nl, nofboxes -- can be nil
end

function pool.usage()
    local t = { }
    for n, tag in gmatch(status.node_mem_usage,"(%d+) ([a-z_]+)") do
        t[tag] = n
    end
    return t
end

local disc              = register_node(new_node("disc"))
local kern              = register_node(new_node("kern",kerncodes.userkern))
local fontkern          = register_node(new_node("kern",kerncodes.fontkern))
local penalty           = register_node(new_node("penalty"))
local glue              = register_node(new_node("glue")) -- glue.spec = nil
local glue_spec         = register_node(new_node("glue_spec"))
local glyph             = register_node(new_node("glyph",0))
local textdir           = register_node(new_node("whatsit",whatsitcodes.dir))
local rule              = register_node(new_node("rule"))
local latelua           = register_node(new_node("whatsit",whatsitcodes.latelua))
local special           = register_node(new_node("whatsit",whatsitcodes.special))
local user_n            = register_node(new_node("whatsit",whatsitcodes.userdefined)) user_n.type = 100 -- 44
local user_l            = register_node(new_node("whatsit",whatsitcodes.userdefined)) user_l.type = 110 -- 44
local user_s            = register_node(new_node("whatsit",whatsitcodes.userdefined)) user_s.type = 115 -- 44
local user_t            = register_node(new_node("whatsit",whatsitcodes.userdefined)) user_t.type = 116 -- 44
local left_margin_kern  = register_node(new_node("margin_kern",0))
local right_margin_kern = register_node(new_node("margin_kern",1))
local lineskip          = register_node(new_node("glue",skipcodes.lineskip))
local baselineskip      = register_node(new_node("glue",skipcodes.baselineskip))
local leftskip          = register_node(new_node("glue",skipcodes.leftskip))
local rightskip         = register_node(new_node("glue",skipcodes.rightskip))
local temp              = register_node(new_node("temp",0))
local noad              = register_node(new_node("noad"))

function pool.zeroglue(n)
    local s = n.spec
    return not writable or (
                     s.width == 0
         and       s.stretch == 0
         and        s.shrink == 0
         and s.stretch_order == 0
         and  s.shrink_order == 0
        )
end

function pool.glyph(fnt,chr)
    local n = copy_node(glyph)
    if fnt then n.font = fnt end
    if chr then n.char = chr end
    return n
end

function pool.penalty(p)
    local n = copy_node(penalty)
    n.penalty = p
    return n
end

function pool.kern(k)
    local n = copy_node(kern)
    n.kern = k
    return n
end

function pool.fontkern(k)
    local n = copy_node(fontkern)
    n.kern = k
    return n
end

function pool.gluespec(width,stretch,shrink,stretch_order,shrink_order)
    local s = copy_node(glue_spec)
    if width         then s.width         = width         end
    if stretch       then s.stretch       = stretch       end
    if shrink        then s.shrink        = shrink        end
    if stretch_order then s.stretch_order = stretch_order end
    if shrink_order  then s.shrink_order  = shrink_order  end
    return s
end

local function someskip(skip,width,stretch,shrink,stretch_order,shrink_order)
    local n = copy_node(skip)
    if not width then
        -- no spec
    elseif width == false or tonumber(width) then
        local s = copy_node(glue_spec)
        if width         then s.width         = width         end
        if stretch       then s.stretch       = stretch       end
        if shrink        then s.shrink        = shrink        end
        if stretch_order then s.stretch_order = stretch_order end
        if shrink_order  then s.shrink_order  = shrink_order  end
        n.spec = s
    else
        -- shared
        n.spec = copy_node(width)
    end
    return n
end

function pool.stretch(a,b)
    local n = copy_node(glue)
    local s = copy_node(glue_spec)
    if b then
        s.stretch       = a
        s.stretch_order = b
    else
        s.stretch       = 1
        s.stretch_order = a or 1
    end
    n.spec = s
    return n
end

function pool.shrink(a,b)
    local n = copy_node(glue)
    local s = copy_node(glue_spec)
    if b then
        s.shrink       = a
        s.shrink_order = b
    else
        s.shrink       = 1
        s.shrink_order = a or 1
    end
    n.spec = s
    return n
end


function pool.glue(width,stretch,shrink,stretch_order,shrink_order)
    return someskip(glue,width,stretch,shrink,stretch_order,shrink_order)
end

function pool.leftskip(width,stretch,shrink,stretch_order,shrink_order)
    return someskip(leftskip,width,stretch,shrink,stretch_order,shrink_order)
end

function pool.rightskip(width,stretch,shrink,stretch_order,shrink_order)
    return someskip(rightskip,width,stretch,shrink,stretch_order,shrink_order)
end

function pool.lineskip(width,stretch,shrink,stretch_order,shrink_order)
    return someskip(lineskip,width,stretch,shrink,stretch_order,shrink_order)
end

function pool.baselineskip(width,stretch,shrink)
    return someskip(baselineskip,width,stretch,shrink)
end

function pool.disc()
    return copy_node(disc)
end

function pool.textdir(dir)
    local t = copy_node(textdir)
    t.dir = dir
    return t
end

function pool.rule(width,height,depth,dir)
    local n = copy_node(rule)
    if width  then n.width  = width  end
    if height then n.height = height end
    if depth  then n.depth  = depth  end
    if dir    then n.dir    = dir    end
    return n
end

if node.has_field(latelua,'string') then
    function pool.latelua(code)
        local n = copy_node(latelua)
        n.string = code
        return n
    end
else
    function pool.latelua(code)
        local n = copy_node(latelua)
        n.data = code
        return n
    end
end

function pool.leftmarginkern(glyph,width)
    local n = copy_node(left_margin_kern)
    if not glyph then
        report_nodes("invalid pointer to left margin glyph node")
    elseif glyph.id ~= glyph_code then
        report_nodes("invalid node type %s for left margin glyph node",nodecodes[glyph])
    else
        n.glyph = glyph
    end
    if width then
        n.width = width
    end
    return n
end

function pool.rightmarginkern(glyph,width)
    local n = copy_node(right_margin_kern)
    if not glyph then
        report_nodes("invalid pointer to right margin glyph node")
    elseif glyph.id ~= glyph_code then
        report_nodes("invalid node type %s for right margin glyph node",nodecodes[p])
    else
        n.glyph = glyph
    end
    if width then
        n.width = width
    end
    return n
end

function pool.temp()
    return copy_node(temp)
end

function pool.noad()
    return copy_node(noad)
end

--[[
<p>At some point we ran into a problem that the glue specification
of the zeropoint dimension was overwritten when adapting a glue spec
node. This is a side effect of glue specs being shared. After a
couple of hours tracing and debugging Taco and I came to the
conclusion that it made no sense to complicate the spec allocator
and settled on a writable flag. This all is a side effect of the
fact that some glues use reserved memory slots (with the zeropoint
glue being a noticeable one). So, next we wrap this into a function
and hide it for the user. And yes, LuaTeX now gives a warning as
well.</p>
]]--

function nodes.writable_spec(n) -- not pool
    local spec = n.spec
    if not spec then
        spec = copy_node(glue_spec)
        n.spec = spec
    elseif not spec.writable then
        spec = copy_node(spec)
        n.spec = spec
    end
    return spec
end

-- local num = userids["my id"]
-- local str = userids[num]

local userids = utilities.storage.allocate()  pool.userids = userids
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

function pool.usernumber(id,num)
    local n = copy_node(user_n)
    if num then
        n.user_id, n.value = id, num
    elseif id then
        n.value = id
    end
    return n
end

function pool.userlist(id,list)
    local n = copy_node(user_l)
    if list then
        n.user_id, n.value =id, list
    else
        n.value = id
    end
    return n
end

function pool.userstring(id,str)
    local n = copy_node(user_s)
    if str then
        n.user_id, n.value =id, str
    else
        n.value = id
    end
    return n
end

function pool.usertokens(id,tokens)
    local n = copy_node(user_t)
    if tokens then
        n.user_id, n.value =id, tokens
    else
        n.value = id
    end
    return n
end

function pool.special(str)
    local n = copy_node(special)
    n.data = str
    return n
end

statistics.register("cleaned up reserved nodes", function()
    return format("%s nodes, %s lists of %s", pool.cleanup(tex.count["last_allocated_box"]))
end) -- \topofboxstack

statistics.register("node memory usage", function() -- comes after cleanup !
    return status.node_mem_usage
end)

lua.registerfinalizer(pool.cleanup, "cleanup reserved nodes")

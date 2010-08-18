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

local nodes, node = nodes, node

local copy_node    = node.copy
local free_node    = node.free
local free_list    = node.flush_list
local new_node     = node.new
local node_type    = node.type

nodes.pool         = nodes.pool or { }
local pool         = nodes.pool

local whatsitcodes = nodes.whatsitcodes
local skipcodes    = nodes.skipcodes
local nodecodes    = nodes.nodecodes

local glyph_code   = nodecodes.glyph

local reserved = { }

local function register_node(n)
    reserved[#reserved+1] = n
    return n
end

pool.register = register_node

function pool.cleanup(nofboxes) -- todo
    nodes.tracers.steppers.reset() -- todo: make a registration subsystem
    local nr, nl = #reserved, 0
    for i=1,nr do
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
local kern              = register_node(new_node("kern",1))
local penalty           = register_node(new_node("penalty"))
local glue              = register_node(new_node("glue")) -- glue.spec = nil
local glue_spec         = register_node(new_node("glue_spec"))
local glyph             = register_node(new_node("glyph",0))
local textdir           = register_node(new_node("whatsit",whatsitcodes.dir))
local rule              = register_node(new_node("rule"))
local latelua           = register_node(new_node("whatsit",whatsitcodes.latelua))
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

function pool.gluespec(width,stretch,shrink)
    local s = copy_node(glue_spec)
    s.width, s.stretch, s.shrink = width, stretch, shrink
    return s
end

local function someskip(skip,width,stretch,shrink)
    local n = copy_node(skip)
    if not width then
        -- no spec
    elseif tonumber(width) then
        local s = copy_node(glue_spec)
        s.width, s.stretch, s.shrink = width, stretch, shrink
        n.spec = s
    else
        -- shared
        n.spec = copy_node(width)
    end
    return n
end

function pool.glue(width,stretch,shrink)
    return someskip(glue,width,stretch,shrink)
end

function pool.leftskip(width,stretch,shrink)
    return someskip(leftskip,width,stretch,shrink)
end

function pool.rightskip(width,stretch,shrink)
    return someskip(rightskip,width,stretch,shrink)
end

function pool.lineskip(width,stretch,shrink)
    return someskip(lineskip,width,stretch,shrink)
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

function pool.latelua(code)
    local n = copy_node(latelua)
    n.data = code
    return n
end

function pool.leftmarginkern(glyph,width)
    local n = copy_node(left_margin_kern)
    if not glyph then
        logs.fatal("nodes","invalid pointer to left margin glyph node")
    elseif glyph.id ~= glyph_code then
        logs.fatal("nodes","invalid node type %s for left margin glyph node",node_type(glyph))
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
        logs.fatal("nodes","invalid pointer to right margin glyph node")
    elseif glyph.id ~= glyph_code then
        logs.fatal("nodes","invalid node type %s for right margin glyph node",node_type(p))
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

function pool.usernumber(id,num) -- if one argument then num
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

statistics.register("cleaned up reserved nodes", function()
    return format("%s nodes, %s lists of %s", pool.cleanup(tex.count["lastallocatedbox"]))
end) -- \topofboxstack

statistics.register("node memory usage", function() -- comes after cleanup !
    return status.node_mem_usage
end)

lua.registerfinalizer(pool.cleanup, "cleanup reserved nodes")

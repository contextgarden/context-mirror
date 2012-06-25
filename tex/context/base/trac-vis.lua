if not modules then modules = { } end modules ['trac-vis'] = {
    version   = 1.001,
    comment   = "companion to trac-vis.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local string, number, table = string, number, table
local node, nodes, attributes, fonts, tex = node, nodes, attributes, fonts, tex

local format = string.format

-- This module started out in the early days of mkiv and luatex with
-- visualizing kerns related to fonts. In the process of cleaning up the
-- visual debugger code it made sense to integrate some other code that
-- I had laying around and replace the old supp-vis debugging code. As
-- only a subset of the old visual debugger makes sense it has become a
-- different implementation. Soms of the m-visual functionality will also
-- be ported. The code is rather trivial. The caching is not really needed
-- but saves upto 50% of the time needed to add visualization. Of course
-- the overall runtime is larger because of color and layer processing in
-- the backend (can be times as much) so the runtime is somewhat larger
-- with full visualization enabled. In practice this will never happen
-- unless one is demoing.

-- todo: global switch (so no attributes)
-- todo: maybe also xoffset, yoffset of glyph
-- todo: inline concat (more efficient)

local nodecodes           = nodes.nodecodes
local disc_code           = nodecodes.disc
local kern_code           = nodecodes.kern
local glyph_code          = nodecodes.glyph
local hlist_code          = nodecodes.hlist
local vlist_code          = nodecodes.vlist
local glue_code           = nodecodes.glue
local penalty_code        = nodecodes.penalty

local kerncodes           = nodes.kerncodes
local font_kern_code      = kerncodes.fontkern
local user_kern_code      = kerncodes.userkern

local gluecodes           = nodes.gluecodes
local cleaders_code       = gluecodes.cleaders
local userskip_code       = gluecodes.userskip
local space_code          = gluecodes.space
local xspace_code         = gluecodes.xspace
local leftskip_code       = gluecodes.leftskip
local rightskip_code      = gluecodes.rightskip

local concat_nodes        = nodes.concat
local hpack_nodes         = node.hpack
local vpack_nodes         = node.vpack
local hpack_string        = typesetters.hpack
local fast_hpack_string   = typesetters.fast_hpack
local copy_node           = node.copy
local copy_list           = node.copy_list
local free_node           = node.free
local free_node_list      = node.flush_list
local has_attribute       = node.has_attribute
local set_attribute       = node.set_attribute
local insert_before       = node.insert_before
local fast_hpack          = nodes.fasthpack

local tex_attribute       = tex.attribute
local unsetvalue          = attributes.unsetvalue

local current_font        = font.current

local exheights           = fonts.hashes.exheights
local emwidths            = fonts.hashes.emwidths
local pt_factor           = number.dimenfactors.pt

local nodepool            = nodes.pool
local new_rule            = nodepool.rule
local new_kern            = nodepool.kern
local new_glue            = nodepool.glue
local new_penalty         = nodepool.penalty

local tracers             = nodes.tracers
local visualizers         = nodes.visualizers

local setcolor            = tracers.colors.set
local setlistcolor        = tracers.colors.setlist
local settransparency     = tracers.transparencies.set
local setlisttransparency = tracers.transparencies.setlist

local starttiming         = statistics.starttiming
local stoptiming          = statistics.stoptiming

-- local function setlistattribute(list,a,v)
--     while list do
--         set_attribute(list,a,v)
--         list = list.next
--     end
-- end

local a_visual            = attributes.private("visual")
local a_fontkern          = attributes.private("fontkern")
local a_layer             = attributes.private("viewerlayer")

local hasbit              = number.hasbit
local bit                 = number.bit
local setbit              = number.setbit
local clearbit            = number.clearbit

local trace_hbox     --  1
local trace_vbox     --  2
local trace_kern     --  4
local trace_glue     --  8
local trace_penalty  -- 16
local trace_fontkern -- 32

local report_visualize = logs.reporter("visualize")

local modes = {
    hbox     =  1,
    vbox     =  2,
    kern     =  4,
    glue     =  8,
    penalty  = 16,
    fontkern = 32,
}

local usedfont, exheight, emwidth
local l_penalty, l_glue, l_kern, l_fontkern, l_hbox, l_vbox

local enabled = false

function visualizers.setfont(id)
    usedfont = id or current_font()
    exheight = exheights[usedfont]
    emwidth = emwidths[usedfont]
end

local function setvisual(n,a,what) -- this will become more efficient when we have the bit lib linked in
    if not n or n == "reset" then
        return unsetvalue
    elseif n == "makeup" then
        a = setvisual("hbox",a)
        a = setvisual("vbox",a)
        a = setvisual("kern",a)
        a = setvisual("glue",a)
        a = setvisual("penalty",a)
    elseif n == "all" then
        if what == false then
            return unsetvalue
        else
            for k, v in next, modes do
                a = setvisual(k,a)
            end
        end
    else
        local m = modes[n]
        if m then
            if a == unsetvalue then
                if what == false then
                    return unsetvalue
                else
                    a = setbit(0,m)
                end
            elseif what == false then
                a = clearbit(a,m)
            else
                a = setbit(a,m)
            end
        elseif not a then
            return unsetvalue
        end
    end
    if a == unsetvalue or a == 0 then
        return unsetvalue
    elseif not enabled then -- must happen at runtime (as we don't store layers yet)
        if not usedfont then
            -- we use a narrow monospaced font
            visualizers.setfont(fonts.definers.define { name = "lmmonoltcond10regular", size = tex.sp("4pt") })
        end
        local layers = { }
        for mode, value in next, modes do
            local tag = format("v_%s",mode)
            attributes.viewerlayers.define {
                tag       = format(tag),
                title     = format("visualizer %s",mode),
                visible   = "start",
                editable  = "yes",
                printable = "yes"
            }
            layers[mode] = attributes.viewerlayers.register(tag,true)
        end
        l_penalty  = layers.penalty
        l_glue     = layers.glue
        l_kern     = layers.kern
        l_fontkern = layers.fontkern
        l_hbox     = layers.hbox
        l_vbox     = layers.vbox
        nodes.tasks.enableaction("shipouts","nodes.visualizers.handler")
        report_visualize("enabled")
        enabled = true
    end
    return a
end

function visualizers.setvisual(n)
    tex_attribute[a_visual] = setvisual(n,tex_attribute[a_visual])
end

commands.setvisual = visualizers.setvisual

function commands.visual(n)
    context(setvisual(n,0))
end

local function set(mode,v)
    tex_attribute[a_visual] = setvisual(mode,tex_attribute[a_visual],v)
end

for mode, value in next, modes do
    trackers.register(format("visualizers.%s",mode), function(v) set(mode,v) end)
end

trackers.register("visualizers.all",   function(v) set("all",   v) end)
trackers.register("visualizers.makeup",function(v) set("makeup",v) end)
trackers.register("visualizers.reset", function(v) set("reset", v) end)

local c_positive   = "trace:b"
local c_negative   = "trace:r"
local c_zero       = "trace:g"
local c_text       = "trace:s"
local c_space      = "trace:y"
local c_skip_a     = "trace:c"
local c_skip_b     = "trace:m"

local c_positive_d = "trace:db"
local c_negative_d = "trace:dr"
local c_zero_d     = "trace:dg"
local c_text_d     = "trace:ds"
local c_space_d    = "trace:dy"
local c_skip_a_d   = "trace:dc"
local c_skip_b_d   = "trace:dm"

local function sometext(str,layer,color)
    local text = fast_hpack_string(str,usedfont)
    local size = text.width
    local rule = new_rule(size,2*exheight,exheight/2)
    local kern = new_kern(-size)
    setcolor(rule,color)
    local info = concat_nodes {
        rule,
        kern,
        text,
    }
    setlisttransparency(info,c_zero)
    info = fast_hpack(info)
    set_attribute(info,a_layer,layer)
    info.width = 0
    info.height = 0
    info.depth = 0
    return info
end

local f_cache = { }

local function fontkern(head,current)
    local kern = current.kern
    local info = f_cache[kern]
    if info then
        -- print("hit fontkern")
    else
        local text = fast_hpack_string(format(" %0.3f",kern*pt_factor),usedfont)
        local rule = new_rule(emwidth/10,6*exheight,2*exheight)
        local list = text.list
        if kern > 0 then
            setlistcolor(list,c_positive_d)
        elseif kern < 0 then
            setlistcolor(list,c_negative_d)
        else
            setlistcolor(list,c_zero_d)
        end
        setlisttransparency(list,c_text_d)
        settransparency(rule,c_text_d)
        text.shift = -5 * exheight
        info = concat_nodes {
            rule,
            text,
        }
        info = fast_hpack(info)
        set_attribute(info,a_layer,l_fontkern)
        info.width = 0
        info.height = 0
        info.depth = 0
        f_cache[kern] = info
    end
    head, current = insert_before(head,current,copy_list(info))
    return head, current.next
end

-- cache baseline

local b_cache

local function ruledbox(head, current, vertical)
    local wd = current.width
    if wd ~= 0 then
        local ht, dp = current.height, current.depth
        local next, prev = current.next, current.prev
        current.next, current.prev = nil, nil
        local linewidth = .1 * emwidth
        local baseline
        if dp ~= 0 and ht ~= 0 then
            if not b_cache then
                -- due to an optimized leader color/transparency we need to se the glue node in order
                -- to trigger this mechanism
                b_cache = new_glue(0)
                local leader = concat_nodes {
                    new_glue(2.5*linewidth),
                    new_rule(5*linewidth,linewidth,0),
                    new_glue(2.5*linewidth),
                }
             -- setlisttransparency(leader,c_text)
                leader = fast_hpack(leader)
             -- setlisttransparency(leader,c_text)
                b_cache.leader = leader
                b_cache.subtype = cleaders_code
                b_cache.spec.stretch = 65536
                b_cache.spec.stretch_order = 2
                setlisttransparency(b_cache,c_text)
            end
            baseline = copy_list(b_cache)
            baseline = fast_hpack(baseline,wd-2*linewidth)
            -- or new hpack node, set head and also:
            -- baseline.width = wd
            -- baseline.glue_set = wd/65536
            -- baseline.glue_order = 2
            -- baseline.glue_sign = 1
        end
        local info = concat_nodes {
            new_rule(linewidth,ht,dp),
            new_rule(wd-2*linewidth,-dp+linewidth,dp),
            new_rule(linewidth,ht,dp),
            new_kern(-wd+linewidth),
            new_rule(wd-2*linewidth,ht,-ht+linewidth),
            new_kern(-wd+linewidth),
            baseline,
        }
        setlisttransparency(info,c_text)
        info = fast_hpack(info)
        info.width = 0
        info.height = 0
        info.depth = 0
        set_attribute(info,a_layer,vertical and l_vbox or l_hbox)
        local info = concat_nodes {
            info,
            current,
        }
        info = fast_hpack(info)
        if vertical then
            info = vpack_nodes(info)
        end
        if next then
            info.next = next
            next.prev = info
        end
        if prev then
            info.prev = prev
            prev.next = info
        end
        if head == current then
            return info, info
        else
            return head, info
        end
    else
        return head, current
    end
end

local g_cache = { }

local tags = {
 -- userskip              = "US",
    lineskip              = "LS",
    baselineskip          = "BS",
    parskip               = "PS",
    abovedisplayskip      = "DA",
    belowdisplayskip      = "DB",
    abovedisplayshortskip = "SA",
    belowdisplayshortskip = "SB",
    leftskip              = "LS",
    rightskip             = "RS",
    topskip               = "TS",
    splittopskip          = "ST",
    tabskip               = "AS",
    spaceskip             = "SS",
    xspaceskip            = "XS",
    parfillskip           = "PF",
    thinmuskip            = "MS",
    medmuskip             = "MM",
    thickmuskip           = "ML",
    leaders               = "NL",
    cleaders              = "CL",
    xleaders              = "XL",
    gleaders              = "GL",
 -- true                  = "VS",
 -- false                 = "HS",
}

local function ruledglue(head,current,vertical)
    local spec = current.spec
    local width = spec.width
    local subtype = current.subtype
    local amount = format("%s:%0.3f",tags[subtype] or (vertical and "VS") or "HS",width*pt_factor)
    local info = g_cache[amount]
    if info then
        -- print("glue hit")
    else
        if subtype == space_code or subtype == xspace_code then -- not yet all space
            info = sometext(amount,l_glue,c_space)
        elseif subtype == leftskip_code or subtype == rightskip_code then
            info = sometext(amount,l_glue,c_skip_a)
        elseif subtype == userskip_code then
            if width > 0 then
                info = sometext(amount,l_glue,c_positive)
            elseif width < 0 then
                info = sometext(amount,l_glue,c_negative)
            else
                info = sometext(amount,l_glue,c_zero)
            end
        else
            info = sometext(amount,l_glue,c_skip_b)
        end
        g_cache[amount] = info
    end
    info = copy_list(info)
    if vertical then
        info = vpack_nodes(info)
    end
    head, current = insert_before(head,current,info)
    return head, current.next
end

local k_cache = { }

local function ruledkern(head,current,vertical)
    local kern = current.kern
    local info = k_cache[kern]
    if info then
        -- print("kern hit")
    else
        local amount = format("%s:%0.3f",vertical and "VK" or "HK",kern*pt_factor)
        if kern > 0 then
            info = sometext(amount,l_kern,c_positive)
        elseif kern < 0 then
            info = sometext(amount,l_kern,c_negative)
        else
            info = sometext(amount,l_kern,c_zero)
        end
        k_cache[kern] = info
    end
    info = copy_list(info)
    if vertical then
        info = vpack_nodes(info)
    end
    head, current = insert_before(head,current,info)
    return head, current.next
end

local p_cache = { }

local function ruledpenalty(head,current,vertical)
    local penalty = current.penalty
    local info = p_cache[penalty]
    if info then
        -- print("penalty hit")
    else
        local amount = format("%s:%s",vertical and "VP" or "HP",penalty)
        if penalty > 0 then
            info = sometext(amount,l_penalty,c_positive)
        elseif penalty < 0 then
            info = sometext(amount,l_penalty,c_negative)
        else
            info = sometext(amount,l_penalty,c_zero)
        end
        p_cache[penalty] = info
    end
    info = copy_list(info)
    if vertical then
        info = vpack_nodes(info)
    end
    head, current = insert_before(head,current,info)
    return head, current.next
end

local function visualize(head,vertical)
    local trace_hbox     = false
    local trace_vbox     = false
    local trace_kern     = false
    local trace_glue     = false
    local trace_penalty  = false
    local trace_fontkern = false
    local current = head
    local prev_trace_fontkern = nil
    local attr = unsetvalue
    while current do
        local id = current.id
        local a = has_attribute(current,a_visual)
        if a ~= attr then
            prev_trace_fontkern = trace_fontkern
            if not a then
                trace_hbox     = false
                trace_vbox     = false
                trace_kern     = false
                trace_glue     = false
                trace_penalty  = false
                trace_fontkern = false
            else
                trace_hbox     = hasbit(a,1)
                trace_vbox     = hasbit(a,2)
                trace_kern     = hasbit(a,4)
                trace_glue     = hasbit(a,8)
                trace_penalty  = hasbit(a,16)
                trace_fontkern = hasbit(a,32)
            end
            attr = a
        end
        if id == kern_code then
            local subtype = current.subtype
            -- tricky ... we don't copy the trace attribute in node-inj (yet)
            if subtype == font_kern_code or has_attribute(current,a_fontkern) then
                if trace_fontkern or prev_trace_fontkern then
                    head, current = fontkern(head,current)
                end
            elseif subtype == user_kern_code then
                if trace_kern then
                    head, current = ruledkern(head,current,vertical)
                end
            end
        elseif id == glue_code then
            local content = current.leader
            if content then
                current.leaders = visualize(content,false)
            elseif trace_glue then
                head, current = ruledglue(head,current,vertical)
            end
        elseif id == penalty_code then
            if trace_penalty then
                head, current = ruledpenalty(head,current,vertical)
            end
        elseif id == disc_code then
            current.pre = visualize(current.pre)
            current.post = visualize(current.post)
            current.replace = visualize(current.replace)
        elseif id == hlist_code then
            local content = current.list
            if content then
                current.list = visualize(content,false)
            end
            if trace_hbox then
                head, current = ruledbox(head,current,false)
            end
        elseif id == vlist_code then
            local content = current.list
            if content then
                current.list = visualize(content,true)
            end
            if trace_vbox then
                head, current = ruledbox(head,current,true)
            end
        end
        current = current.next
    end
    return head
end

local function freed(cache)
    local n = 0
    for k, v in next, cache do
        free_node_list(v)
        n = n + 1
    end
    if n == 0 then
        return 0, cache
    else
        return n, { }
    end
end

local function cleanup()
    local hf, ng, np, nk
    nf, f_cache = freed(f_cache)
    ng, g_cache = freed(g_cache)
    np, p_cache = freed(p_cache)
    nk, k_cache = freed(k_cache)
    if b_cache then
        free_node_list(b_cache)
        b_cache = nil
    end
 -- report_visualize("cache: %s fontkerns, %s skips, %s penalties, %s kerns",nf,ng,np,nk)
end

function visualizers.handler(head)
    if usedfont then
        starttiming(visualizers)
        head = visualize(head)
--      cleanup()
        stoptiming(visualizers)
    end
    return head, false
end

function nodes.visualizers.box(n)
    tex.box[n].list = nodes.visualizers.handler(tex.box[n].list)
end

statistics.register("visualization time",function()
    if enabled then
        cleanup() -- in case we don't don't do it each time
        return format("%s seconds",statistics.elapsedtime(visualizers))
    end
end)

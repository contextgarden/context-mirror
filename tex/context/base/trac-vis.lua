if not modules then modules = { } end modules ['trac-vis'] = {
    version   = 1.001,
    comment   = "companion to trac-vis.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local string, number, table = string, number, table
local node, nodes, attributes, fonts, tex = node, nodes, attributes, fonts, tex
local type = type
local format = string.format
local formatters = string.formatters

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

-- We could use pdf literals and re stream codes but it's not worth the
-- trouble because we would end up in color etc mess. Maybe one day I'll
-- make a nodeinjection variant.

-- todo: global switch (so no attributes)
-- todo: maybe also xoffset, yoffset of glyph
-- todo: inline concat (more efficient)

local nodecodes           = nodes.nodecodes
local disc_code           = nodecodes.disc
local kern_code           = nodecodes.kern
local glyph_code          = nodecodes.glyph
local disc_code           = nodecodes.disc
local hlist_code          = nodecodes.hlist
local vlist_code          = nodecodes.vlist
local glue_code           = nodecodes.glue
local penalty_code        = nodecodes.penalty
local whatsit_code        = nodecodes.whatsit
local user_code           = nodecodes.user

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

local whatsitcodes        = nodes.whatsitcodes

local concat_nodes        = nodes.concat
local hpack_nodes         = node.hpack
local vpack_nodes         = node.vpack
local hpack_string        = typesetters.hpack
local fast_hpack_string   = typesetters.fast_hpack
local copy_node           = node.copy
local copy_list           = node.copy_list
local free_node           = node.free
local free_node_list      = node.flush_list
local insert_node_before  = node.insert_before
local insert_node_after   = node.insert_after
local fast_hpack          = nodes.fasthpack
local traverse_nodes      = node.traverse

local tex_attribute       = tex.attribute
local tex_box             = tex.box
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

local a_visual            = attributes.private("visual")
local a_fontkern          = attributes.private("fontkern")
local a_layer             = attributes.private("viewerlayer")

local hasbit              = number.hasbit
local bit                 = number.bit
local setbit              = number.setbit
local clearbit            = number.clearbit

local trace_hbox
local trace_vbox
local trace_vtop
local trace_kern
local trace_glue
local trace_penalty
local trace_fontkern
local trace_strut
local trace_whatsit
local trace_user

local report_visualize = logs.reporter("visualize")

local modes = {
    hbox       =    1,
    vbox       =    2,
    vtop       =    4,
    kern       =    8,
    glue       =   16,
    penalty    =   32,
    fontkern   =   64,
    strut      =  128,
    whatsit    =  256,
    glyph      =  512,
    simple     = 1024,
    simplehbox = 1024 + 1,
    simplevbox = 1024 + 2,
    simplevtop = 1024 + 4,
    user       = 2048,
}

local modes_makeup = { "hbox", "vbox", "kern", "glue", "penalty" }
local modes_boxes  = { "hbox", "vbox"  }
local modes_all    = { "hbox", "vbox", "kern", "glue", "penalty", "fontkern", "whatsit", "glyph", "user" }

local usedfont, exheight, emwidth
local l_penalty, l_glue, l_kern, l_fontkern, l_hbox, l_vbox, l_vtop, l_strut, l_whatsit, l_glyph, l_user

local enabled = false
local layers  = { }

local preset_boxes  = modes.hbox + modes.vbox
local preset_makeup = preset_boxes + modes.kern + modes.glue + modes.penalty
local preset_all    = preset_makeup + modes.fontkern + modes.whatsit + modes.glyph + modes.user

function visualizers.setfont(id)
    usedfont = id or current_font()
    exheight = exheights[usedfont]
    emwidth = emwidths[usedfont]
end

-- we can preset a bunch of bits

local function enable()
    if not usedfont then
        -- we use a narrow monospaced font
        visualizers.setfont(fonts.definers.define { name = "lmmonoltcond10regular", size = tex.sp("4pt") })
    end
    for mode, value in next, modes do
        local tag = formatters["v_%s"](mode)
        attributes.viewerlayers.define {
            tag       = tag,
            title     = formatters["visualizer %s"](mode),
            visible   = "start",
            editable  = "yes",
            printable = "yes"
        }
        layers[mode] = attributes.viewerlayers.register(tag,true)
    end
    l_hbox     = layers.hbox
    l_vbox     = layers.vbox
    l_vtop     = layers.vtop
    l_glue     = layers.glue
    l_kern     = layers.kern
    l_penalty  = layers.penalty
    l_fontkern = layers.fontkern
    l_strut    = layers.strut
    l_whatsit  = layers.whatsit
    l_glyph    = layers.glyph
    l_user     = layers.user
    nodes.tasks.enableaction("shipouts","nodes.visualizers.handler")
    report_visualize("enabled")
    enabled = true
    tex.setcount("global","c_syst_visualizers_state",1) -- so that we can optimize at the tex end
end

local function setvisual(n,a,what) -- this will become more efficient when we have the bit lib linked in
    if not n or n == "reset" then
        return unsetvalue
    elseif n == "makeup" then
        if not a or a == 0 or a == unsetvalue then
            a = preset_makeup
        else
            a = setbit(a,preset_makeup)
         -- for i=1,#modes_makeup do
         --     a = setvisual(modes_makeup[i],a)
         -- end
        end
    elseif n == "boxes" then
        if not a or a == 0 or a == unsetvalue then
            a = preset_boxes
        else
            a = setbit(a,preset_boxes)
         -- for i=1,#modes_boxes do
         --     a = setvisual(modes_boxes[i],a)
         -- end
        end
    elseif n == "all" then
        if what == false then
            return unsetvalue
        elseif not a or a == 0 or a == unsetvalue then
            a = preset_all
        else
            a = setbit(a,preset_all)
         -- for i=1,#modes_all do
         --     a = setvisual(modes_all[i],a)
         -- end
        end
    else
        local m = modes[n]
        if not m then
            -- go on
        elseif a == unsetvalue then
            if what == false then
                return unsetvalue
            else
             -- a = setbit(0,m)
                a = m
            end
        elseif what == false then
            a = clearbit(a,m)
        elseif not a or a == 0 then
            a = m
        else
            a = setbit(a,m)
        end
    end
    if not a or a == 0 or a == unsetvalue then
        return unsetvalue
    elseif not enabled then -- must happen at runtime (as we don't store layers yet)
        enable()
    end
    return a
end

function visualizers.setvisual(n)
    tex_attribute[a_visual] = setvisual(n,tex_attribute[a_visual])
end

function visualizers.setlayer(n)
    tex_attribute[a_layer] = layers[n] or unsetvalue
end

commands.setvisual = visualizers.setvisual
commands.setlayer  = visualizers.setlayer

function commands.visual(n)
    context(setvisual(n))
end

local function set(mode,v)
    tex_attribute[a_visual] = setvisual(mode,tex_attribute[a_visual],v)
end

for mode, value in next, modes do
    trackers.register(formatters["visualizers.%s"](mode), function(v) set(mode,v) end)
end

trackers.register("visualizers.reset", function(v) set("reset", v) end)
trackers.register("visualizers.all",   function(v) set("all",   v) end)
trackers.register("visualizers.makeup",function(v) set("makeup",v) end)
trackers.register("visualizers.boxes", function(v) set("boxes", v) end)

local c_positive   = "trace:b"
local c_negative   = "trace:r"
local c_zero       = "trace:g"
local c_text       = "trace:s"
local c_space      = "trace:y"
local c_skip_a     = "trace:c"
local c_skip_b     = "trace:m"
local c_glyph      = "trace:o"
local c_white      = "trace:w"

local c_positive_d = "trace:db"
local c_negative_d = "trace:dr"
local c_zero_d     = "trace:dg"
local c_text_d     = "trace:ds"
local c_space_d    = "trace:dy"
local c_skip_a_d   = "trace:dc"
local c_skip_b_d   = "trace:dm"
local c_glyph_d    = "trace:do"
local c_white_d    = "trace:dw"

local function sometext(str,layer,color,textcolor) -- we can just paste verbatim together .. no typesteting needed
    local text = fast_hpack_string(str,usedfont)
    local size = text.width
    local rule = new_rule(size,2*exheight,exheight/2)
    local kern = new_kern(-size)
    if color then
        setcolor(rule,color)
    end
    if textcolor then
        setlistcolor(text.list,textcolor)
    end
    local info = concat_nodes {
        rule,
        kern,
        text,
    }
    setlisttransparency(info,c_zero)
    info = fast_hpack(info)
    if layer then
        info[a_layer] = layer
    end
    local width = info.width
    info.width = 0
    info.height = 0
    info.depth = 0
    return info, width
end

local f_cache = { }

local function fontkern(head,current)
    local kern = current.kern
    local info = f_cache[kern]
    if info then
        -- print("hit fontkern")
    else
        local text = fast_hpack_string(formatters[" %0.3f"](kern*pt_factor),usedfont)
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
        info[a_layer] = l_fontkern
        info.width = 0
        info.height = 0
        info.depth = 0
        f_cache[kern] = info
    end
    head = insert_node_before(head,current,copy_list(info))
    return head, current
end

local w_cache = { }

local tags = {
    open           = "FIC",
    write          = "FIW",
    close          = "FIC",
    special        = "SPE",
    localpar       = "PAR",
    dir            = "DIR",
    pdfliteral     = "PDF",
    pdfrefobj      = "PDF",
    pdfrefxform    = "PDF",
    pdfrefximage   = "PDF",
    pdfannot       = "PDF",
    pdfstartlink   = "PDF",
    pdfendlink     = "PDF",
    pdfdest        = "PDF",
    pdfthread      = "PDF",
    pdfstartthread = "PDF",
    pdfendthread   = "PDF",
    pdfsavepos     = "PDF",
    pdfthreaddata  = "PDF",
    pdflinkdata    = "PDF",
    pdfcolorstack  = "PDF",
    pdfsetmatrix   = "PDF",
    pdfsave        = "PDF",
    pdfrestore     = "PDF",
    latelua        = "LUA",
    closelua       = "LUA",
    cancelboundary = "CBD",
    userdefined    = "USR",
}

local function whatsit(head,current)
    local what = current.subtype
    local info = w_cache[what]
    if info then
        -- print("hit whatsit")
    else
        local tag = whatsitcodes[what]
        -- maybe different text colors per tag
        info = sometext(formatters["W:%s"](tag and tags[tag] or what),usedfont,nil,c_white)
        info[a_layer] = l_whatsit
        w_cache[what] = info
    end
    head, current = insert_node_after(head,current,copy_list(info))
    return head, current
end

local function user(head,current)
    local what = current.subtype
    local info = w_cache[what]
    if info then
        -- print("hit user")
    else
        info = sometext(formatters["U:%s"](what),usedfont)
        info[a_layer] = l_user
        w_cache[what] = info
    end
    head, current = insert_node_after(head,current,copy_list(info))
    return head, current
end

local b_cache = { }

local function ruledbox(head,current,vertical,layer,what,simple)
    local wd = current.width
    if wd ~= 0 then
        local ht, dp = current.height, current.depth
        local next, prev = current.next, current.prev
        current.next, current.prev = nil, nil
        local linewidth = emwidth/10
        local baseline, baseskip
        if dp ~= 0 and ht ~= 0 then
            if wd > 20*linewidth then
                baseline = b_cache.baseline
                if not baseline then
                    -- due to an optimized leader color/transparency we need to set the glue node in order
                    -- to trigger this mechanism
                    local leader = concat_nodes {
                        new_glue(2*linewidth),              -- 2.5
                        new_rule(6*linewidth,linewidth,0),  -- 5.0
                        new_glue(2*linewidth),              -- 2.5
                    }
                 -- setlisttransparency(leader,c_text)
                    leader = fast_hpack(leader)
                 -- setlisttransparency(leader,c_text)
                    baseline = new_glue(0)
                    baseline.leader = leader
                    baseline.subtype = cleaders_code
                    baseline.spec.stretch = 65536
                    baseline.spec.stretch_order = 2
                    setlisttransparency(baseline,c_text)
                    b_cache.baseline = baseline
                end
                baseline = copy_list(baseline)
                baseline = fast_hpack(baseline,wd-2*linewidth)
                -- or new hpack node, set head and also:
                -- baseline.width = wd
                -- baseline.glue_set = wd/65536
                -- baseline.glue_order = 2
                -- baseline.glue_sign = 1
                baseskip = new_kern(-wd+linewidth)
            else
                baseline = new_rule(wd-2*linewidth,linewidth,0)
                baseskip = new_kern(-wd+2*linewidth)
            end
        end
        local this
        if not simple then
            this = b_cache[what]
            if not this then
                local text = fast_hpack_string(what,usedfont)
                this = concat_nodes {
                    new_kern(-text.width),
                    text,
                }
                setlisttransparency(this,c_text)
                this = fast_hpack(this)
                this.width = 0
                this.height = 0
                this.depth = 0
                b_cache[what] = this
            end
        end
        local info = concat_nodes {
            this and copy_list(this) or nil, -- this also triggers the right mode (else sometimes no whatits)
            new_rule(linewidth,ht,dp),
            new_rule(wd-2*linewidth,-dp+linewidth,dp),
            new_rule(linewidth,ht,dp),
            new_kern(-wd+linewidth),
            new_rule(wd-2*linewidth,ht,-ht+linewidth),
            baseskip,
            baseline,
        }
        setlisttransparency(info,c_text)
        info = fast_hpack(info)
        info.width = 0
        info.height = 0
        info.depth = 0
        info[a_layer] = layer
        local info = concat_nodes {
            current,
            new_kern(-wd),
            info,
        }
        info = fast_hpack(info,wd)
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

local function ruledglyph(head,current)
    local wd = current.width
    if wd ~= 0 then
        local ht, dp = current.height, current.depth
        local next, prev = current.next, current.prev
        current.next, current.prev = nil, nil
        local linewidth = emwidth/20
        local baseline
        if dp ~= 0 and ht ~= 0 then
            baseline = new_rule(wd-2*linewidth,linewidth,0)
        end
        local doublelinewidth = 2*linewidth
        local info = concat_nodes {
            new_rule(linewidth,ht,dp),
            new_rule(wd-doublelinewidth,-dp+linewidth,dp),
            new_rule(linewidth,ht,dp),
            new_kern(-wd+linewidth),
            new_rule(wd-doublelinewidth,ht,-ht+linewidth),
            new_kern(-wd+doublelinewidth),
            baseline,
        }
        setlistcolor(info,c_glyph)
        setlisttransparency(info,c_glyph_d)
        info = fast_hpack(info)
        info.width = 0
        info.height = 0
        info.depth = 0
        info[a_layer] = l_glyph
        local info = concat_nodes {
            current,
            new_kern(-wd),
            info,
        }
        info = fast_hpack(info)
        info.width = wd
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
    local amount = formatters["%s:%0.3f"](tags[subtype] or (vertical and "VS") or "HS",width*pt_factor)
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
    head, current = insert_node_before(head,current,info)
    return head, current.next
end

local k_cache = { }

local function ruledkern(head,current,vertical)
    local kern = current.kern
    local info = k_cache[kern]
    if info then
        -- print("kern hit")
    else
        local amount = formatters["%s:%0.3f"](vertical and "VK" or "HK",kern*pt_factor)
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
    head, current = insert_node_before(head,current,info)
    return head, current.next
end

local p_cache = { }

local function ruledpenalty(head,current,vertical)
    local penalty = current.penalty
    local info = p_cache[penalty]
    if info then
        -- print("penalty hit")
    else
        local amount = formatters["%s:%s"](vertical and "VP" or "HP",penalty)
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
    head, current = insert_node_before(head,current,info)
    return head, current.next
end

local function visualize(head,vertical)
    local trace_hbox     = false
    local trace_vbox     = false
    local trace_vtop     = false
    local trace_kern     = false
    local trace_glue     = false
    local trace_penalty  = false
    local trace_fontkern = false
    local trace_strut    = false
    local trace_whatsit  = false
    local trace_glyph    = false
    local trace_simple   = false
    local trace_user     = false
    local current = head
    local prev_trace_fontkern = nil
    local attr = unsetvalue
    while current do
        local id = current.id
        local a = current[a_visual] or unsetvalue
        if a ~= attr then
            prev_trace_fontkern = trace_fontkern
            if a == unsetvalue then
                trace_hbox     = false
                trace_vbox     = false
                trace_vtop     = false
                trace_kern     = false
                trace_glue     = false
                trace_penalty  = false
                trace_fontkern = false
                trace_strut    = false
                trace_whatsit  = false
                trace_glyph    = false
                trace_simple   = false
                trace_user     = false
            else -- dead slow:
                trace_hbox     = hasbit(a,   1)
                trace_vbox     = hasbit(a,   2)
                trace_vtop     = hasbit(a,   4)
                trace_kern     = hasbit(a,   8)
                trace_glue     = hasbit(a,  16)
                trace_penalty  = hasbit(a,  32)
                trace_fontkern = hasbit(a,  64)
                trace_strut    = hasbit(a, 128)
                trace_whatsit  = hasbit(a, 256)
                trace_glyph    = hasbit(a, 512)
                trace_simple   = hasbit(a,1024)
                trace_user     = hasbit(a,2048)
            end
            attr = a
        end
        if trace_strut then
            current[a_layer] = l_strut
        elseif id == glyph_code then
            if trace_glyph then
                head, current = ruledglyph(head,current)
            end
        elseif id == disc_code then
            if trace_glyph then
                local pre = current.pre
                if pre then
                    current.pre = ruledglyph(pre,pre)
                end
                local post = current.post
                if post then
                    current.post = ruledglyph(post,post)
                end
                local replace = current.replace
                if replace then
                    current.replace = ruledglyph(replace,replace)
                end
            end
        elseif id == kern_code then
            local subtype = current.subtype
            -- tricky ... we don't copy the trace attribute in node-inj (yet)
            if subtype == font_kern_code or current[a_fontkern] then
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
                current.leader = visualize(content,false)
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
                head, current = ruledbox(head,current,false,l_hbox,"H__",trace_simple)
            end
        elseif id == vlist_code then
            local content = current.list
            if content then
                current.list = visualize(content,true)
            end
            if trace_vtop then
                head, current = ruledbox(head,current,true,l_vtop,"_T_",trace_simple)
            elseif trace_vbox then
                head, current = ruledbox(head,current,true,l_vbox,"__V",trace_simple)
            end
        elseif id == whatsit_code then
            if trace_whatsit then
                head, current = whatsit(head,current)
            end
        elseif id == user_code then
            if trace_whatsit then
                head, current = user(head,current)
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
    local hf, ng, np, nk, nw
    nf, f_cache = freed(f_cache)
    ng, g_cache = freed(g_cache)
    np, p_cache = freed(p_cache)
    nk, k_cache = freed(k_cache)
    nw, w_cache = freed(w_cache)
    nb, b_cache = freed(b_cache)
 -- report_visualize("cache: %s fontkerns, %s skips, %s penalties, %s kerns, %s whatsits, %s boxes",nf,ng,np,nk,nw,nb)
end

function visualizers.handler(head)
    if usedfont then
        starttiming(visualizers)
     -- local l = tex_attribute[a_layer]
     -- local v = tex_attribute[a_visual]
     -- tex_attribute[a_layer] = unsetvalue
     -- tex_attribute[a_visual] = unsetvalue
        head = visualize(head)
     -- tex_attribute[a_layer] = l
     -- tex_attribute[a_visual] = v
     -- -- cleanup()
        stoptiming(visualizers)
    end
    return head, false
end

function visualizers.box(n)
    tex_box[n].list = visualizers.handler(tex_box[n].list)
end

local last = nil
local used = nil

local mark = {
    "trace:1", "trace:2", "trace:3",
    "trace:4", "trace:5", "trace:6",
    "trace:7",
}

local function markfonts(list)
    for n in traverse_nodes(list) do
        local id = n.id
        if id == glyph_code then
            local font = n.font
            local okay = used[font]
            if not okay then
                last = last + 1
                okay = mark[last]
                used[font] = okay
            end
            setcolor(n,okay)
        elseif id == hlist_code or id == vlist_code then
            markfonts(n.list)
        end
    end
end

function visualizers.markfonts(list)
    last, used = 0, { }
    markfonts(type(n) == "number" and tex_box[n].list or n)
end

function commands.markfonts(n)
    visualizers.markfonts(n)
end

statistics.register("visualization time",function()
    if enabled then
        cleanup() -- in case we don't don't do it each time
        return format("%s seconds",statistics.elapsedtime(visualizers))
    end
end)

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
local gmatch = string.gmatch
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
-- todo: tags can also be numbers (just add to hash)

-- todo: dir and localpar nodes

local nodecodes           = nodes.nodecodes
local disc_code           = nodecodes.disc
local kern_code           = nodecodes.kern
local glyph_code          = nodecodes.glyph
local hlist_code          = nodecodes.hlist
local vlist_code          = nodecodes.vlist
local glue_code           = nodecodes.glue
local penalty_code        = nodecodes.penalty
local whatsit_code        = nodecodes.whatsit
local user_code           = nodecodes.user
local math_code           = nodecodes.math
local gluespec_code       = nodecodes.gluespec

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
local mathcodes           = nodes.mathcodes

local nuts                = nodes.nuts
local tonut               = nuts.tonut
local tonode              = nuts.tonode

local setfield            = nuts.setfield
local setboth             = nuts.setboth
local setlink             = nuts.setlink
local setdisc             = nuts.setdisc
local setlist             = nuts.setlist
local setleader           = nuts.setleader
local setsubtype          = nuts.setsubtype
local setattr             = nuts.setattr

local getfield            = nuts.getfield
local getid               = nuts.getid
local getfont             = nuts.getfont
local getattr             = nuts.getattr
local getsubtype          = nuts.getsubtype
local getchar             = nuts.getchar
local getbox              = nuts.getbox
local getlist             = nuts.getlist
local getleader           = nuts.getleader
local getnext             = nuts.getnext
local getprev             = nuts.getprev
local getboth             = nuts.getboth
local getdisc             = nuts.getdisc

local hpack_nodes         = nuts.hpack
local vpack_nodes         = nuts.vpack
local copy_list           = nuts.copy_list
local flush_node_list     = nuts.flush_list
local insert_node_before  = nuts.insert_before
local insert_node_after   = nuts.insert_after
local traverse_nodes      = nuts.traverse
local linked_nodes        = nuts.linked
local apply_to_nodes      = nuts.apply

local effectiveglue       = nuts.effective_glue

local hpack_string        = nuts.typesetters.tohpack

local texgetattribute     = tex.getattribute
local texsetattribute     = tex.setattribute

local unsetvalue          = attributes.unsetvalue

local current_font        = font.current

local fonthashes          = fonts.hashes
local chardata            = fonthashes.characters
local exheights           = fonthashes.exheights
local emwidths            = fonthashes.emwidths
local pt_factor           = number.dimenfactors.pt

local nodepool            = nuts.pool
local new_rule            = nodepool.rule
local new_kern            = nodepool.kern
local new_glue            = nodepool.glue
local new_hlist           = nodepool.hlist
local new_vlist           = nodepool.vlist

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
local trace_math
local trace_italic

local report_visualize = logs.reporter("visualize")

local modes = {
    hbox       =     1,
    vbox       =     2,
    vtop       =     4,
    kern       =     8,
    glue       =    16,
 -- skip       =    16,
    penalty    =    32,
    fontkern   =    64,
    strut      =   128,
    whatsit    =   256,
    glyph      =   512,
    simple     =  1024,
    simplehbox =  1024 + 1,
    simplevbox =  1024 + 2,
    simplevtop =  1024 + 4,
    user       =  2048,
    math       =  4096,
    italic     =  8192,
    origin     = 16384,
}

local usedfont, exheight, emwidth
local l_penalty, l_glue, l_kern, l_fontkern, l_hbox, l_vbox, l_vtop, l_strut, l_whatsit, l_glyph, l_user, l_math, l_italic, l_origin

local enabled = false
local layers  = { }

local preset_boxes  = modes.hbox + modes.vbox + modes.origin
local preset_makeup = preset_boxes
                    + modes.kern + modes.glue + modes.penalty
local preset_all    = preset_makeup
                    + modes.fontkern + modes.whatsit + modes.glyph + modes.user + modes.math

function visualizers.setfont(id)
    usedfont = id or current_font()
    exheight = exheights[usedfont]
    emwidth  = emwidths[usedfont]
end

-- we can preset a bunch of bits

local function enable()
    if not usedfont then
        -- we use a narrow monospaced font -- infofont ?
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
    l_math     = layers.math
    l_italic   = layers.italic
    l_origin   = layers.origin
    nodes.tasks.enableaction("shipouts","nodes.visualizers.handler")
    report_visualize("enabled")
    enabled = true
    tex.setcount("global","c_syst_visualizers_state",1) -- so that we can optimize at the tex end
end

local function setvisual(n,a,what,list) -- this will become more efficient when we have the bit lib linked in
    if not n or n == "reset" then
        return unsetvalue
    elseif n == true or n == "makeup" then
        if not a or a == 0 or a == unsetvalue then
            a = preset_makeup
        else
            a = setbit(a,preset_makeup)
        end
    elseif n == "boxes" then
        if not a or a == 0 or a == unsetvalue then
            a = preset_boxes
        else
            a = setbit(a,preset_boxes)
        end
    elseif n == "all" then
        if what == false then
            return unsetvalue
        elseif not a or a == 0 or a == unsetvalue then
            a = preset_all
        else
            a = setbit(a,preset_all)
        end
    else
        for s in gmatch(n,"[a-z]+") do
            local m = modes[s]
            if not m then
                -- go on
            elseif not a or a == 0 or a == unsetvalue then
                a = m
            else
                a = setbit(a,m)
            end
        end
    end
    if not a or a == 0 or a == unsetvalue then
        return unsetvalue
    elseif not enabled then -- must happen at runtime (as we don't store layers yet)
        enable()
    end
    return a
end

function nuts.setvisual(n,mode)
    setattr(n,a_visual,setvisual(mode,getattr(n,a_visual),true))
end

function nuts.setvisuals(n,mode)
    setattr(n,a_visual,setvisual(mode,getattr(n,a_visual),true,true))
end

function nuts.applyvisuals(n,mode)
    local a = unsetvalue
    if mode == true then
        a = texgetattribute (a_visual)
    elseif mode then
        a = setvisual(mode)
    end
    apply_to_nodes(n,function(n) setattr(n,a_visual,a) end)
end

function nuts.copyvisual(n,m)
    setattr(n,a_visual,getattr(m,a_visual))
end

function visualizers.setvisual(n)
    texsetattribute(a_visual,setvisual(n,texgetattribute(a_visual)))
end

function visualizers.setlayer(n)
    texsetattribute(a_layer,layers[n] or unsetvalue)
end

local function set(mode,v)
    texsetattribute(a_visual,setvisual(mode,texgetattribute(a_visual),v))
end

for mode, value in next, modes do
    trackers.register(formatters["visualizers.%s"](mode), function(v) set(mode,v) end)
end

local raisepenalties = false

directives.register("visualizers.raisepenalties",function(v) raisepenalties = v end)

local fraction = 10

trackers  .register("visualizers.reset",    function(v) set("reset", v) end)
trackers  .register("visualizers.all",      function(v) set("all",   v) end)
trackers  .register("visualizers.makeup",   function(v) set("makeup",v) end)
trackers  .register("visualizers.boxes",    function(v) set("boxes", v) end)
directives.register("visualizers.fraction", function(v) fraction = (v and tonumber(v)) or (v == "more" and 5) or 10 end)

local c_positive   = "trace:b"
local c_negative   = "trace:r"
local c_zero       = "trace:g"
local c_text       = "trace:s"
local c_space      = "trace:y"
local c_skip_a     = "trace:c"
local c_skip_b     = "trace:m"
local c_glyph      = "trace:o"
local c_ligature   = "trace:s"
local c_white      = "trace:w"
local c_math       = "trace:r"
local c_origin     = "trace:o"

local c_positive_d = "trace:db"
local c_negative_d = "trace:dr"
local c_zero_d     = "trace:dg"
local c_text_d     = "trace:ds"
local c_space_d    = "trace:dy"
local c_skip_a_d   = "trace:dc"
local c_skip_b_d   = "trace:dm"
local c_glyph_d    = "trace:do"
local c_ligature_d = "trace:ds"
local c_white_d    = "trace:dw"
local c_math_d     = "trace:dr"
local c_origin_d   = "trace:do"

local function sometext(str,layer,color,textcolor,lap) -- we can just paste verbatim together .. no typesteting needed
    local text = hpack_string(str,usedfont)
    local size = getfield(text,"width")
    local rule = new_rule(size,2*exheight,exheight/2)
    local kern = new_kern(-size)
    if color then
        setcolor(rule,color)
    end
    if textcolor then
        setlistcolor(getlist(text),textcolor)
    end
    local info = linked_nodes(rule,kern,text)
    setlisttransparency(info,c_zero)
    info = new_hlist(info)
    local width = getfield(info,"width")
    if lap then
        info = new_hlist(linked_nodes(new_kern(-width),info))
    end
    if layer then
        setattr(info,a_layer,layer)
    end
    return info, width
end

local f_cache = { }

local function fontkern(head,current)
    local width = getfield(current,"kern")
    local extra = getfield(current,"expansion_factor")
    local kern  = width + extra
    local info  = f_cache[kern]
 -- report_visualize("fontkern: %p ex %p",width,extra)
    if info then
        -- print("hit fontkern")
    else
        local text = hpack_string(formatters[" %0.3f"](kern*pt_factor),usedfont)
        local rule = new_rule(emwidth/fraction,6*exheight,2*exheight)
        local list = getlist(text)
        if kern > 0 then
            setlistcolor(list,c_positive_d)
        elseif kern < 0 then
            setlistcolor(list,c_negative_d)
        else
            setlistcolor(list,c_zero_d)
        end
        setlisttransparency(list,c_text_d)
        settransparency(rule,c_text_d)
        setfield(text,"shift",-5 * exheight)
        info = new_hlist(linked_nodes(rule,text))
        setattr(info,a_layer,l_fontkern)
        f_cache[kern] = info
    end
    head = insert_node_before(head,current,copy_list(info))
    return head, current
end

local w_cache = { }
local tags    = {
    open             = "FIC",
    write            = "FIW",
    close            = "FIC",
    special          = "SPE",
    latelua          = "LUA",
    savepos          = "POS",
    userdefined      = "USR",
 -- backend stuff
    pdfliteral       = "PDF",
    pdfrefobj        = "PDF",
    pdfannot         = "PDF",
    pdfstartlink     = "PDF",
    pdfendlink       = "PDF",
    pdfdest          = "PDF",
    pdfthread        = "PDF",
    pdfstartthread   = "PDF",
    pdfendthread     = "PDF",
    pdfthreaddata    = "PDF",
    pdflinkdata      = "PDF",
    pdfcolorstack    = "PDF",
    pdfsetmatrix     = "PDF",
    pdfsave          = "PDF",
    pdfrestore       = "PDF",
}

local function whatsit(head,current)
    local what = getsubtype(current)
    local info = w_cache[what]
    if info then
        -- print("hit whatsit")
    else
        local tag = whatsitcodes[what]
        -- maybe different text colors per tag
        info = sometext(formatters["W:%s"](tag and tags[tag] or what),usedfont,nil,c_white)
        setattr(info,a_layer,l_whatsit)
        w_cache[what] = info
    end
    head, current = insert_node_after(head,current,copy_list(info))
    return head, current
end

local u_cache = { }

local function user(head,current)
    local what = getsubtype(current)
    local info = u_cache[what]
    if info then
        -- print("hit user")
    else
        info = sometext(formatters["U:%s"](what),usedfont)
        setattr(info,a_layer,l_user)
        u_cache[what] = info
    end
    head, current = insert_node_after(head,current,copy_list(info))
    return head, current
end

local m_cache = { }
local tags    = {
    beginmath = "B",
    endmath   = "E",
}

local function math(head,current)
    local what = getsubtype(current)
    local info = m_cache[what]
    if info then
        -- print("hit math")
    else
        local tag = mathcodes[what]
        info = sometext(formatters["M:%s"](tag and tags[tag] or what),usedfont,nil,c_math_d)
        setattr(info,a_layer,l_math)
        m_cache[what] = info
    end
    head, current = insert_node_after(head,current,copy_list(info))
    return head, current
end

local b_cache = { }

local o_cache = table.setmetatableindex(function(t,size)
    local rule = new_rule(2*size,size,size)
    origin = hpack_nodes(rule)
    setcolor(rule,c_origin_d)
    settransparency(rule,c_origin_d)
    setattr(rule,a_layer,l_origin)
    t[size] = origin
    return origin
end)

local function ruledbox(head,current,vertical,layer,what,simple,previous,trace_origin,parent)
    local wd = getfield(current,"width")
    if wd ~= 0 then
        local ht = getfield(current,"height")
        local dp = getfield(current,"depth")
        local shift = getfield(current,"shift")
        local next = getnext(current)
        local prev = previous
     -- local prev = getprev(current) -- prev can be wrong in math mode < 0.78.3
        setboth(current)
        local linewidth = emwidth/fraction
        local size      = 2*linewidth
        local baseline, baseskip
        if dp ~= 0 and ht ~= 0 then
            if wd > 20*linewidth then
                baseline = b_cache.baseline
                if not baseline then
                    -- due to an optimized leader color/transparency we need to set the glue node in order
                    -- to trigger this mechanism
                    local leader = linked_nodes(new_glue(size),new_rule(3*size,linewidth,0),new_glue(size))
                    leader = hpack_nodes(leader)
                    baseline = new_glue(0)
                    setleader(baseline,leader)
                    setsubtype(baseline,cleaders_code)
                    setfield(baseline,"stretch",65536)
                    setfield(baseline,"stretch_order",2)
                    setlisttransparency(baseline,c_text)
                    b_cache.baseline = baseline
                end
                baseline = copy_list(baseline)
                baseline = hpack_nodes(baseline,wd-size)
                -- or new_hlist, set head and also:
                -- baseline.width = wd
                -- baseline.glue_set = wd/65536
                -- baseline.glue_order = 2
                -- baseline.glue_sign = 1
                baseskip = new_kern(-wd+linewidth)
            else
                baseline = new_rule(wd-size,linewidth,0)
                baseskip = new_kern(-wd+size)
            end
        end
        local this
        if not simple then
            this = b_cache[what]
            if not this then
                local text = hpack_string(what,usedfont)
                this = linked_nodes(new_kern(-getfield(text,"width")),text)
                setlisttransparency(this,c_text)
                this = new_hlist(this)
                b_cache[what] = this
            end
        end
        -- we need to trigger the right mode (else sometimes no whatits)
        local info = linked_nodes(
            this and copy_list(this) or nil,
            new_rule(linewidth,ht,dp),
            new_rule(wd-size,-dp+linewidth,dp),
            new_rule(linewidth,ht,dp),
            new_kern(-wd+linewidth),
            new_rule(wd-size,ht,-ht+linewidth)
        )
        if baseskip then
            info = linked_nodes(info,baseskip,baseline) -- could be in previous linked
        end
        setlisttransparency(info,c_text)
        info = new_hlist(info)
        --
        setattr(info,a_layer,layer)
        if vertical then
            if shift == 0 then
                info = linked_nodes(current,dp ~= 0 and new_kern(-dp) or nil,info)
            elseif trace_origin then
                local size   = 2*size
                local origin = o_cache[size]
                origin = copy_list(origin)
                if getid(parent) == vlist_code then
                    setfield(origin,"shift",-shift)
                    info = linked_nodes(current,new_kern(-size),origin,new_kern(-size-dp),info)
                else
                    -- todo .. i need an example
                    info = linked_nodes(current,dp ~= 0 and new_kern(-dp) or nil,info)
                end
                setfield(current,"shift",0)
            else
                info = linked_nodes(current,new_dp ~= 0 and new_kern(-dp) or nil,info)
                setfield(current,"shift",0)
            end
            info = new_vlist(info,wd,ht,dp,shift)
        else
            if shift == 0 then
                info = linked_nodes(current,new_kern(-wd),info)
            elseif trace_origin then
                local size   = 2*size
                local origin = o_cache[size]
                origin = copy_list(origin)
                if getid(parent) == vlist_code then
                    info = linked_nodes(current,new_kern(-wd-size-shift),origin,new_kern(-size+shift),info)
                else
                    setfield(origin,"shift",-shift)
                    info = linked_nodes(current,new_kern(-wd-size),origin,new_kern(-size),info)
                end
                setfield(current,"shift",0)
            else
                info = linked_nodes(current,new_kern(-wd),info)
                setfield(current,"shift",0)
            end
            info = new_hlist(info,wd,ht,dp,shift)
        end
        if next then
            setlink(info,next)
        end
        if prev then
            if getid(prev) == gluespec_code then
                report_visualize("ignoring invalid prev")
                -- weird, how can this happen, an inline glue-spec, probably math
            else
                setlink(prev,info)
            end
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

local function ruledglyph(head,current,previous)
    local wd = getfield(current,"width")
 -- local wd = chardata[getfont(current)][getchar(current)].width
    if wd ~= 0 then
        local ht = getfield(current,"height")
        local dp = getfield(current,"depth")
        local next = getnext(current)
        local prev = previous
        setboth(current)
        local linewidth = emwidth/(2*fraction)
        local baseline
     -- if dp ~= 0 and ht ~= 0 then
        if (dp >= 0 and ht >= 0) or (dp <= 0 and ht <= 0) then
            baseline = new_rule(wd-2*linewidth,linewidth,0)
        end
        local doublelinewidth = 2*linewidth
        -- could be a pdf rule (or a user rule now)
        local info = linked_nodes(
            new_rule(linewidth,ht,dp),
            new_rule(wd-doublelinewidth,-dp+linewidth,dp),
            new_rule(linewidth,ht,dp),
            new_kern(-wd+linewidth),
            new_rule(wd-doublelinewidth,ht,-ht+linewidth),
            new_kern(-wd+doublelinewidth),
            baseline
        )
        local char = chardata[getfont(current)][getchar(current)]
        if char and type(char.unicode) == "table" then -- hackery test
            setlistcolor(info,c_ligature)
            setlisttransparency(info,c_ligature_d)
        else
            setlistcolor(info,c_glyph)
            setlisttransparency(info,c_glyph_d)
        end
        info = new_hlist(info)
        setattr(info,a_layer,l_glyph)
        local info = linked_nodes(current,new_kern(-wd),info)
        info = hpack_nodes(info)
        setfield(info,"width",wd)
        if next then
            setlink(info,next)
        end
        if prev then
            setlink(prev,info)
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

local g_cache_v = { }
local g_cache_h = { }

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

-- we sometimes pass previous as we can have issues in math (not watertight for all)

local function ruledglue(head,current,vertical,parent)
    local subtype = getsubtype(current)
    local width   = effectiveglue(current,parent)
    local amount  = formatters["%s:%0.3f"](tags[subtype] or (vertical and "VS") or "HS",width*pt_factor)
    local info    = (vertical and g_cache_v or g_cache_h)[amount]
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
        (vertical and g_cache_v or g_cache_h)[amount] = info
    end
    info = copy_list(info)
    if vertical then
        info = vpack_nodes(info)
    end
    head, current = insert_node_before(head,current,info)
    return head, getnext(current)
end

local k_cache_v = { }
local k_cache_h = { }

local function ruledkern(head,current,vertical)
    local kern = getfield(current,"kern")
    local info = (vertical and k_cache_v or k_cache_h)[kern]
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
        (vertical and k_cache_v or k_cache_h)[kern] = info
    end
    info = copy_list(info)
    if vertical then
        info = vpack_nodes(info)
    end
    head, current = insert_node_before(head,current,info)
    return head, getnext(current)
end

local i_cache = { }

local function ruleditalic(head,current)
    local kern = getfield(current,"kern")
    local info = i_cache[kern]
    if info then
        -- print("kern hit")
    else
        local amount = formatters["%s:%0.3f"]("IC",kern*pt_factor)
        if kern > 0 then
            info = sometext(amount,l_kern,c_positive)
        elseif kern < 0 then
            info = sometext(amount,l_kern,c_negative)
        else
            info = sometext(amount,l_kern,c_zero)
        end
        i_cache[kern] = info
    end
    info = copy_list(info)
    head, current = insert_node_before(head,current,info)
    return head, getnext(current)
end

local p_cache_v = { }
local p_cache_h = { }

local function ruledpenalty(head,current,vertical)
    local penalty = getfield(current,"penalty")
    local info = (vertical and p_cache_v or p_cache_h)[penalty]
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
        (vertical and p_cache_v or p_cache_h)[penalty] = info
    end
    info = copy_list(info)
    if vertical then
        info = vpack_nodes(info)
    elseif raisepenalties then
        setfield(info,"shift",-65536*4)
    end
    head, current = insert_node_before(head,current,info)
    return head, getnext(current)
end

local function visualize(head,vertical,forced,parent)
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
    local trace_math     = false
    local trace_italic   = false
    local trace_origin   = false
    local current        = head
    local previous       = nil
    local attr           = unsetvalue
    local prev_trace_fontkern = nil
    while current do
        local id = getid(current)
        local a = forced or getattr(current,a_visual) or unsetvalue
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
                trace_math     = false
                trace_italic   = false
                trace_origin   = false
            else -- dead slow:
                trace_hbox     = hasbit(a,    1)
                trace_vbox     = hasbit(a,    2)
                trace_vtop     = hasbit(a,    4)
                trace_kern     = hasbit(a,    8)
                trace_glue     = hasbit(a,   16)
                trace_penalty  = hasbit(a,   32)
                trace_fontkern = hasbit(a,   64)
                trace_strut    = hasbit(a,  128)
                trace_whatsit  = hasbit(a,  256)
                trace_glyph    = hasbit(a,  512)
                trace_simple   = hasbit(a, 1024)
                trace_user     = hasbit(a, 2048)
                trace_math     = hasbit(a, 4096)
                trace_italic   = hasbit(a, 8192)
                trace_origin   = hasbit(a,16384)
            end
            attr = a
        end
        if trace_strut then
            setattr(current,a_layer,l_strut)
        elseif id == glyph_code then
            if trace_glyph then
                head, current = ruledglyph(head,current,previous)
            end
        elseif id == disc_code then
            local pre, post, replace = getdisc(current)
            if pre then
                pre = visualize(pre,false,a,parent)
            end
            if post then
                post = visualize(post,false,a,parent)
            end
            if replace then
                replace = visualize(replace,false,a,parent)
            end
            setdisc(current,pre,post,replace)
        elseif id == kern_code then
            local subtype = getsubtype(current)
            -- tricky ... we don't copy the trace attribute in node-inj (yet)
            if subtype == font_kern_code or getattr(current,a_fontkern) then
                if trace_fontkern or prev_trace_fontkern then
                    head, current = fontkern(head,current)
                end
            else -- if subtype == user_kern_code then
                if trace_italic then
                    head, current = ruleditalic(head,current)
                elseif trace_kern then
                    head, current = ruledkern(head,current,vertical)
                end
            end
        elseif id == glue_code then
            local content = getleader(current)
            if content then
                setleader(current,visualize(content,false,nil,parent))
            elseif trace_glue then
                head, current = ruledglue(head,current,vertical,parent)
            end
        elseif id == penalty_code then
            if trace_penalty then
                head, current = ruledpenalty(head,current,vertical)
            end
        elseif id == hlist_code then
            local content = getlist(current)
            if content then
                setlist(current,visualize(content,false,nil,current))
            end
            if trace_hbox then
                head, current = ruledbox(head,current,false,l_hbox,"H__",trace_simple,previous,trace_origin,parent)
            end
        elseif id == vlist_code then
            local content = getlist(current)
            if content then
                setlist(current,visualize(content,true,nil,current))
            end
            if trace_vtop then
                head, current = ruledbox(head,current,true,l_vtop,"_T_",trace_simple,previous,trace_origin,parent)
            elseif trace_vbox then
                head, current = ruledbox(head,current,true,l_vbox,"__V",trace_simple,previous,trace_origin,parent)
            end
        elseif id == whatsit_code then
            if trace_whatsit then
                head, current = whatsit(head,current)
            end
        elseif id == user_code then
            if trace_user then
                head, current = user(head,current)
            end
        elseif id == math_code then
            if trace_math then
                head, current = math(head,current)
            end
        end
        previous = current
        current  = getnext(current)
    end
    return head
end

do

    local function freed(cache)
        local n = 0
        for k, v in next, cache do
            flush_node_list(v)
            n = n + 1
        end
        if n == 0 then
            return 0, cache
        else
            return n, { }
        end
    end

    local function cleanup()
        local hf, nw, nb, ng_v, ng_h, np_v, np_h, nk_v, nk_h
        nf,   f_cache   = freed(f_cache)
        nw,   w_cache   = freed(w_cache)
        nb,   b_cache   = freed(b_cache)
        no,   o_cache   = freed(o_cache)
        ng_v, g_cache_v = freed(g_cache_v)
        ng_h, g_cache_h = freed(g_cache_h)
        np_v, p_cache_v = freed(p_cache_v)
        np_h, p_cache_h = freed(p_cache_h)
        nk_v, k_cache_v = freed(k_cache_v)
        nk_h, k_cache_h = freed(k_cache_h)
     -- report_visualize("cache cleanup: %s fontkerns, %s skips, %s penalties, %s kerns, %s whatsits, %s boxes, %s origins",
     --     nf,ng_v+ng_h,np_v+np_h,nk_v+nk_h,nw,nb,no)
    end

    local function handler(head)
        if usedfont then
            starttiming(visualizers)
         -- local l = texgetattribute(a_layer)
         -- local v = texgetattribute(a_visual)
         -- texsetattribute(a_layer,unsetvalue)
         -- texsetattribute(a_visual,unsetvalue)
            head = visualize(tonut(head),true)
         -- texsetattribute(a_layer,l)
         -- texsetattribute(a_visual,v)
         -- -- cleanup()
            stoptiming(visualizers)
            return tonode(head), true
        else
            return head, false
        end
    end

    visualizers.handler = handler

    luatex.registerstopactions(cleanup)

end

function visualizers.box(n)
    if usedfont then
        starttiming(visualizers)
        local box = getbox(n)
        if box then
            setlist(box,visualize(getlist(box),getid(box) == vlist_code))
        end
        stoptiming(visualizers)
        return head, true
    else
        return head, false
    end
end

do

    local last = nil
    local used = nil

    local mark = {
        "trace:1", "trace:2", "trace:3",
        "trace:4", "trace:5", "trace:6",
        "trace:7",
    }

    local function markfonts(list)
        for n in traverse_nodes(list) do
            local id = getid(n)
            if id == glyph_code then
                local font = getfont(n)
                local okay = used[font]
                if not okay then
                    last = last + 1
                    okay = mark[last]
                    used[font] = okay
                end
                setcolor(n,okay)
            elseif id == hlist_code or id == vlist_code then
                markfonts(getlist(n))
            end
        end
    end

    function visualizers.markfonts(list)
        last, used = 0, { }
        markfonts(type(n) == "number" and getlist(getbox(n)) or n)
    end

end

statistics.register("visualization time",function()
    if enabled then
     -- cleanup() -- in case we don't don't do it each time
        return formatters["%s seconds"](statistics.elapsedtime(visualizers))
    end
end)

-- interface

local implement = interfaces.implement

implement {
    name      = "setvisual",
    arguments = "string",
    actions   = visualizers.setvisual
}

implement {
    name      = "setvisuals",
    arguments = "string",
    actions   = visualizers.setvisual
}

implement {
    name      = "getvisual",
    arguments = "string",
    actions   = { setvisual, context }
}

    implement {
    name      = "setvisuallayer",
    arguments = "string",
    actions   = visualizers.setlayer
}

implement {
    name      = "markvisualfonts",
    arguments = "integer",
    actions   = visualizers.markfonts
}

implement {
    name      = "setvisualfont",
    arguments = "integer",
    actions   = visualizers.setfont
}

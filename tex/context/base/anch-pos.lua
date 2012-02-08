if not modules then modules = { } end modules ['anch-pos'] = {
    version   = 1.001,
    comment   = "companion to anch-pos.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

--[[ldx--
<p>We save positional information in the main utility table. Not only
can we store much more information in <l n='lua'/> but it's also
more efficient.</p>
--ldx]]--

-- plus (extra) is obsolete but we will keep it for a while

-- maybe replace texsp by our own converter (stay at the lua end)
-- eventually mp will have large numbers so we can use sp there too

local tostring = tostring
local concat, format, gmatch, match = table.concat, string.format, string.gmatch, string.match
local rawget = rawget
local lpegmatch = lpeg.match
local insert, remove = table.insert, table.remove
local allocate, mark = utilities.storage.allocate, utilities.storage.mark
local texsp, texcount, texbox, texdimen, texsetcount = tex.sp, tex.count, tex.box, tex.dimen, tex.setcount
----- texsp = string.todimen -- because we cache this is much faster but no rounding

local setmetatableindex = table.setmetatableindex

local variables   = interfaces.variables

local v_text      = variables.text
local v_column    = variables.column

local new_latelua = nodes.pool.latelua
local find_tail   = node.slide

local pt  = number.dimenfactors.pt
local pts = number.pts

local collected = allocate()
local tobesaved = allocate()

local jobpositions = {
    collected = collected,
    tobesaved = tobesaved,
}

job.positions = jobpositions

_plib_ = jobpositions

local function initializer()
    tobesaved = jobpositions.tobesaved
    collected = jobpositions.collected
end

job.register('job.positions.collected', tobesaved, initializer)

local regions    = { }
local nofregions = 0
local region     = nil
local nofcolumns = 0
local column     = nil
local nofpages   = nil

-- beware ... we're not sparse here as lua will reserve slots for the nilled

local function setdim(name,w,h,d,extra) -- will be used when we move to sp allover
    local x = pdf.h
    local y = pdf.v
    if x == 0 then x = nil end
    if y == 0 then y = nil end
    if w == 0 then w = nil end
    if h == 0 then h = nil end
    if d == 0 then d = nil end
    if extra == "" then extra = nil end
    -- todo: sparse
    tobesaved[name] = {
        p = texcount.realpageno,
        x = x,
        y = y,
        w = w,
        h = h,
        d = d,
        e = extra,
        r = region,
        c = column,
    }
end

local function setall(name,p,x,y,w,h,d,extra)
    if x == 0 then x = nil end
    if y == 0 then y = nil end
    if w == 0 then w = nil end
    if h == 0 then h = nil end
    if d == 0 then d = nil end
    if extra == "" then extra = nil end
    -- todo: sparse
    tobesaved[name] = {
        p = p,
        x = x,
        y = y,
        w = w,
        h = h,
        d = d,
        e = extra,
        r = region,
        c = column,
    }
end

local function enhance(data)
    if not data then
        return nil
    end
    if data.r == true then -- or ""
        data.r = region
    end
    if data.x == true then
        data.x = pdf.h
    end
    if data.y == true then
        data.y = pdf.v
    end
    if data.p == true then -- or 0
        data.p = texcount.realpageno
    end
    if data.c == true then -- or 0
        data.c = column
    end
    if data.w == 0 then
        data.w = nil
    end
    if data.h == 0 then
        data.h = nil
    end
    if data.d == 0 then
        data.d = nil
    end
    return data
end

local function set(name,index,val)
    local data = enhance(val or index)
    if val then
        container = tobesaved[name]
        if not container then
            tobesaved[name] = {
                [index] = data
            }
        else
            container[index] = data
        end
    else
        tobesaved[name] = data
    end
end

local function get(id,index)
    if index then
        local container = collected[id]
        return container and container[index]
    else
        return collected[id]
    end
end

jobpositions.setdim = setdim
jobpositions.setall = setall
jobpositions.set    = set
jobpositions.get    = get

-- function jobpositions.pushregion(tag,w,h,d)
--     if w then
--         setdim(tag,w,h,d)
--     end
--     insert(regions,tag)
--     region = tag
-- end

-- function jobpositions.popregion()
--     remove(regions)
--     region = regions[#regions]
-- end

-- function jobpositions.markregionbox(n,tag)
--     if not tag or tag == "" then
--         nofregions = nofregions + 1
--         tag = nofregions
--     end
--     local box = texbox[n]
--     local push = new_latelua(format("_plib_.pushregion(%q,%s,%s,%s)",tag,box.width,box.height,box.depth))
--     local pop  = new_latelua("_plib_.popregion()")
--     local head = box.list
--     local tail = find_tail(head)
--     head.prev = push
--     push.next = head
--     pop .prev = tail
--     tail.next = pop
--     box.list = push
-- end

function jobpositions.b_region(tag)
    local last = tobesaved[tag]
    last.x = pdf.h
    last.p = texcount.realpageno
    insert(regions,tag)
    region = tag
end

function jobpositions.e_region()
    remove(regions)
    tobesaved[region].y = pdf.v
    region = regions[#regions]
end

function jobpositions.markregionbox(n,tag)
    if not tag or tag == "" then
        nofregions = nofregions + 1
        tag = format("region:%s",nofregions)
    end
    local box = texbox[n]
    tobesaved[tag] = {
        p = true,
        x = true,
        y = true,
        w = box.width,
        h = box.height,
        d = box.depth,
    }
    local push = new_latelua(format("_plib_.b_region(%q)",tag))
    local pop  = new_latelua("_plib_.e_region()")
    local head = box.list
    local tail = find_tail(head)
    head.prev = push
    push.next = head
    pop .prev = tail
    tail.next = pop
    box.list = push
end

-- here the page is part of the column so we can only save when we reassign
-- the table (column:* => column:*:*)

function jobpositions.b_column(w,h,d) -- there can be multiple column ranges per page
    local page = texcount.realpageno -- we could have a nice page synchronizer (saves calls)
    if page ~= nofpages then
        nofpages = page
        nofcolumns = 1
    else
        nofcolumns = nofcolumns + 1
    end
    column = nofcolumns
    if w then
        set(format("column:%s:%s",page,column), {
            x = true,
            y = true,
            w = w,
            h = h,
            d = d,
        })
    end
end

function jobpositions.e_column()
    column = nil
end

function jobpositions.markcolumnbox(n,column)
    local box = texbox[n]
    local push = new_latelua(format("_plib_.b_column(%s,%s,%s)",box.width,box.height,box.depth))
    local pop  = new_latelua("_plib_.e_column()")
    local head = box.list
    if head then
        local tail = find_tail(head)
        head.prev = push
        push.next = head
        pop .prev = tail
        tail.next = pop
    else -- we can have a simple push/pop
        push.next = pop
        pop.prev = push
    end
    box.list = push
end

function jobpositions.enhance(name)
    enhance(tobesaved[name])
end

function commands.pos(name,t)
    tobesaved[name] = t
    context(new_latelua(format("_plib_.enhance(%q)",name)))
end

local nofparagraphs = 0

function commands.parpos() -- todo: relate to localpar (so this is an intermediate variant)
    nofparagraphs = nofparagraphs + 1
    texsetcount("global","parposcounter",nofparagraphs)
    local strutbox = texbox.strutbox
    local t = {
        p  = true,
     -- c  = true,
        x  = true,
        y  = true,
        h  = strutbox.height,
        d  = strutbox.depth,
        hs = tex.hsize,
    }
    local leftskip   = tex.leftskip.width
    local rightskip  = tex.rightskip.width
    local hangindent = tex.hangindent
    local hangafter  = tex.hangafter
    local parindent  = tex.parindent
    if leftskip ~= 0 then
        t.ls = leftskip
    end
    if rightskip ~= 0 then
        t.rs = rightskip
    end
    if hangindent ~= 0 then
        t.hi = hangindent
    end
    if hangafter ~= 1 and hangafter ~= 0 then -- can not be zero .. so it needs to be 1 if zero
        t.ha = hangafter
    end
    if parindent ~= 0 then
        t.pi = parindent
    end
    local tag = format("p:%s",nofparagraphs)
    tobesaved[tag] = t
    context(new_latelua(format("_plib_.enhance(%q)",tag)))
end

function commands.posxy(name) -- can node.write be used here?
    tobesaved[name] = {
        p = true,
     -- c = true,
        r = true,
        x = true,
        y = true,
        n = nofparagraphs > 0 and nofparagraphs or nil,
    }
    context(new_latelua(format("_plib_.enhance(%q)",name)))
end

function commands.poswhd(name,w,h,d)
    tobesaved[name] = {
        p = true,
     -- c = true,
        r = true,
        x = true,
        y = true,
        w = w,
        h = h,
        d = d,
        n = nofparagraphs > 0 and nofparagraphs or nil,
    }
    context(new_latelua(format("_plib_.enhance(%q)",name)))
end

function commands.posplus(name,w,h,d,extra)
    tobesaved[name] = {
        p = true,
     -- c = true,
        r = true,
        x = true,
        y = true,
        w = w,
        h = h,
        d = d,
        n = nofparagraphs > 0 and nofparagraphs or nil,
        e = extra,
    }
    context(new_latelua(format("_plib_.enhance(%q)",name)))
end

function commands.posstrut(name,w,h,d)
    local strutbox = texbox.strutbox
    tobesaved[name] = {
        p = true,
     -- c = true,
        r = true,
        x = true,
        y = true,
        h = strutbox.height,
        d = strutbox.depth,
        n = nofparagraphs > 0 and nofparagraphs or nil,
    }
    context(new_latelua(format("_plib_.enhance(%q)",name)))
end

function jobpositions.getreserved(tag,n)
    if tag == v_column then
        local fulltag = format("%s:%s:%s",tag,texcount.realpageno,n or 1)
        local data = collected[fulltag]
        if data then
            return data, fulltag
        end
        tag = v_text
    end
    if tag == v_text then
        local fulltag = format("%s:%s",tag,texcount.realpageno)
        return collected[fulltag] or false, fulltag
    end
    return collected[tag] or false, tag
end

function jobpositions.copy(target,source)
    collected[target] = collected[source]
end

function jobpositions.replace(id,p,x,y,w,h,d)
--     local t = collected[id]
--     if t then
--         t.p = p or t.p
--         t.x = x or t.x
--         t.y = y or t.y
--         t.w = w or t.w
--         t.h = h or t.h
--         t.d = d or t.d
--     else
        collected[id] = { p = p, x = x, y = y, w = w, h = h, d = d }
--     end
end

function jobpositions.page(id)
    local jpi = collected[id]
    return jpi and jpi.p or 0
end

function jobpositions.region(id)
    local jpi = collected[id]
    return jpi and jpi.r or false
end

function jobpositions.column(id)
    local jpi = collected[id]
    return jpi and jpi.c or false
end

function jobpositions.paragraph(id)
    local jpi = collected[id]
    return jpi and jpi.n or 0
end

jobpositions.p = jobpositions.page
jobpositions.r = jobpositions.region
jobpositions.c = jobpositions.column
jobpositions.n = jobpositions.paragraph

function jobpositions.x(id)
    local jpi = collected[id]
    return jpi and jpi.x or 0
end

function jobpositions.y(id)
    local jpi = collected[id]
    return jpi and jpi.y or 0
end

function jobpositions.width(id)
    local jpi = collected[id]
    return jpi and jpi.w or 0
end

function jobpositions.height(id)
    local jpi = collected[id]
    return jpi and jpi.h or 0
end

function jobpositions.depth(id)
    local jpi = collected[id]
    return jpi and jpi.d or 0
end

function jobpositions.leftskip(id)
    local jpi = collected[id]
    return jpi and jpi.ls or 0
end

function jobpositions.rightskip(id)
    local jpi = collected[id]
    return jpi and jpi.rs or 0
end

function jobpositions.hsize(id)
    local jpi = collected[id]
    return jpi and jpi.hs or 0
end

function jobpositions.parindent(id)
    local jpi = collected[id]
    return jpi and jpi.pi or 0
end

function jobpositions.hangindent(id)
    local jpi = collected[id]
    return jpi and jpi.hi or 0
end

function jobpositions.hangafter(id)
    local jpi = collected[id]
    return jpi and jpi.ha or 1
end

function jobpositions.xy(id)
    local jpi = collected[id]
    if jpi then
        local x = jpi.x or 0
        local y = jpi.y or 0
        return x, y
    else
        return 0, 0
    end
end

function jobpositions.lowerleft(id)
    local jpi = collected[id]
    if jpi then
        local x = jpi.x or 0
        local y = jpi.y or 0
        local d = jpi.d or 0
        return x, y - d
    else
        return 0, 0
    end
end

function jobpositions.lowerright(id)
    local jpi = collected[id]
    if jpi then
        local x = jpi.x or 0
        local y = jpi.y or 0
        local w = jpi.w or 0
        local d = jpi.d or 0
        return x + w, y - d
    else
        return 0, 0
    end
end

function jobpositions.upperright(id)
    local jpi = collected[id]
    if jpi then
        local x = jpi.x or 0
        local y = jpi.y or 0
        local w = jpi.w or 0
        local h = jpi.h or 0
        return x + w, y + h
    else
        return 0, 0
    end
end

function jobpositions.upperleft(id)
    local jpi = collected[id]
    if jpi then
        local x = jpi.x or 0
        local y = jpi.y or 0
        local h = jpi.h or 0
        return x, y + h
    else
        return 0, 0
    end
end

function jobpositions.position(id)
    local jpi = collected[id]
    if jpi then
        return jpi.p or 0, jpi.x or 0, jpi.y or 0, jpi.w or 0, jpi.h or 0, jpi.d or 0
    else
        return 0, 0, 0, 0, 0, 0
    end
end

function jobpositions.extra(id,n,default) -- assume numbers
    local jpi = collected[id]
    if jpi then
        local e = jpi.e
        if e then
            local split = jpi.split
            if not split then
                split = lpegmatch(splitter,jpi.e)
                jpi.split = split
            end
            return texsp(split[n]) or default -- watch the texsp here
        end
    end
    return default
end

local function overlapping(one,two,overlappingmargin) -- hm, strings so this is wrong .. texsp
    one = collected[one]
    two = collected[two]
    if one and two and one.p == two.p then
        if not overlappingmargin then
            overlappingmargin = 2
        end
        local x_one = one.x or 0
        local x_two = two.x or 0
        local w_two = two.w or 0
        local llx_one = x_one         - overlappingmargin
        local urx_two = x_two + w_two + overlappingmargin
        if llx_one > urx_two then
            return false
        end
        local w_one = one.w or 0
        local urx_one = x_one + w_one + overlappingmargin
        local llx_two = x_two         - overlappingmargin
        if urx_one < llx_two then
            return false
        end
        local y_one = one.y or 0
        local y_two = two.y or 0
        local d_one = one.d or 0
        local h_two = two.h or 0
        local lly_one = y_one - d_one - overlappingmargin
        local ury_two = y_two + h_two + overlappingmargin
        if lly_one > ury_two then
            return false
        end
        local h_one = one.h or 0
        local d_two = two.d or 0
        local ury_one = y_one + h_one + overlappingmargin
        local lly_two = y_two - d_two - overlappingmargin
        if ury_one < lly_two then
            return false
        end
        return true
    end
end

local function onsamepage(list,page)
    for id in gmatch(list,"(, )") do
        local jpi = collected[id]
        if jpi then
            local p = jpi.p
            if not p then
                return false
            elseif not page then
                page = p
            elseif page ~= p then
                return false
            end
        end
    end
    return page
end

jobpositions.overlapping = overlapping
jobpositions.onsamepage  = onsamepage

-- interface

commands.replacepospxywhd = jobpositions.replace
commands.copyposition     = jobpositions.copy

function commands.MPp(id)
    local jpi = collected[id]
    if jpi then
        local p = jpi.p
        if p then
            context(p)
            return
        end
    end
    context('0')
end

function commands.MPx(id)
    local jpi = collected[id]
    if jpi then
        local x = jpi.x
        if x then
            context("%spt",x*pt)
            return
        end
    end
    context('0pt')
end

function commands.MPy(id)
    local jpi = collected[id]
    if jpi then
        local y = jpi.y
        if y then
            context("%spt",y*pt)
            return
        end
    end
    context('0pt')
end

function commands.MPw(id)
    local jpi = collected[id]
    if jpi then
        local w = jpi.w
        if w then
            context("%spt",w*pt)
            return
        end
    end
    context('0pt')
end

function commands.MPh(id)
    local jpi = collected[id]
    if jpi then
        local h = jpi.h
        if h then
            context("%spt",h*pt)
            return
        end
    end
    context('0pt')
end

function commands.MPd(id)
    if jpi then
        local d = jpi.d
        if d then
            context("%spt",d*pt)
            return
        end
    end
    context('0pt')
end

function commands.MPxy(id)
    local jpi = collected[id]
    if jpi then
        context('(%spt,%spt)',
            (jpi.x or 0)*pt,
            (jpi.y or 0)*pt
        )
    else
        context('(0,0)')
    end
end

function commands.MPll(id)
    local jpi = collected[id]
    if jpi then
        context('(%spt,%spt)',
             (jpi.x or 0)              *pt,
            ((jpi.y or 0)-(jpi.d or 0))*pt
        )
    else
        context('(0,0)')
    end
end

function commands.MPlr(id)
    local jpi = collected[id]
    if jpi then
        context('(%spt,%spt)',
            ((jpi.x or 0)+(jpi.w or 0))*pt,
            ((jpi.y or 0)-(jpi.d or 0))*pt
        )
    else
        context('(0,0)')
    end
end

function commands.MPur(id)
    local jpi = collected[id]
    if jpi then
        context('(%spt,%spt)',
            ((jpi.x or 0)+(jpi.w or 0))*pt,
            ((jpi.y or 0)+(jpi.h or 0))*pt
        )
    else
        context('(0,0)')
    end
end

function commands.MPul(id)
    local jpi = collected[id]
    if jpi then
        context('(%spt,%spt)',
             (jpi.x or 0)              *pt,
            ((jpi.y or 0)+(jpi.h or 0))*pt
        )
    else
        context('(0,0)')
    end
end

local function MPpos(id)
    local jpi = collected[id]
    if jpi then
        local p = jpi.p
        if p then
            context("%s,%spt,%spt,%spt,%spt,%spt",
                p,
                (jpi.x or 0)*pt,
                (jpi.y or 0)*pt,
                (jpi.w or 0)*pt,
                (jpi.h or 0)*pt,
                (jpi.d or 0)*pt
            )
            return
        end
    end
    context('0,0,0,0,0,0')
end

commands.MPpos = MPpos

function commands.MPn(id)
    local jpi = collected[id]
    if jpi then
        local n = jpi.n
        if n then
            context(n)
            return
        end
    end
    context(0)
end

function commands.MPc(id)
    local jpi = collected[id]
    if jpi then
        local c = jpi.c
        if c then
            context(c)
            return
        end
    end
    context(c) -- number
end

function commands.MPr(id)
    local jpi = collected[id]
    if jpi then
        local r = jpi.r
        if r then
            context(r)
            return
        end
    end
 -- context("") -- empty so that we can test
end

local function MPpardata(n)
    local t = collected[n]
    if not t then
        local tag = format("p:%s",n)
        t = collected[tag]
    end
    if t then
        context("%spt,%spt,%spt,%spt,%s,%spt", -- can be %.5f
            (t.hs or 0)*pt,
            (t.ls or 0)*pt,
            (t.rs or 0)*pt,
            (t.hi or 0)*pt,
            (t.ha or 1),
            (t.pi or 0)*pt
        )
    else
        context("0,0,0,0,0,0") -- meant for MP
    end
end

commands.MPpardata = MPpardata

-- function commands.MPposset(id) -- special helper, used in backgrounds
--     local b = format("b:%s",id)
--     local e = format("e:%s",id)
--     local w = format("w:%s",id)
--     local p = format("p:%s",jobpositions.n(b))
--     MPpos(b) context(",") MPpos(e) context(",") MPpos(w) context(",") MPpos(p) context(",") MPpardata(p)
-- end

function commands.MPls(id)
    local t = collected[id]
    if t then
        context((t.ls or 0)*pt)
    else
        context("0pt")
    end
end

function commands.MPrs(id)
    local t = collected[id]
    if t then
        context((t.rs or 0)*pt)
    else
        context("0pt")
    end
end

local splitter = lpeg.tsplitat(",")

function commands.MPplus(id,n,default)
    local jpi = collected[id]
    if jpi then
        local e = jpi.e
        if e then
            local split = jpi.split
            if not split then
                split = lpegmatch(splitter,jpi.e)
                jpi.split = split
            end
            context(split[n] or default)
            return
        end
    end
    context(default)
end

function commands.MPrest(id,default)
    local jpi = collected[id]
    context(jpi and jpi.e or default)
end

function commands.MPxywhd(id)
    local t = collected[id]
    if t then
        context("%spt,%spt,%spt,%spt,%spt", -- can be %.5f
            (t.x or 0)*pt,
            (t.y or 0)*pt,
            (t.w or 0)*pt,
            (t.h or 0)*pt,
            (t.d or 0)*pt
        )
    else
        context("0,0,0,0,0") -- meant for MP
    end
end

-- is testcase already defined? if so, then local

function commands.doifpositionelse(name)
    commands.testcase(collected[name])
end

function commands.doifoverlappingelse(one,two,overlappingmargin)
    commands.testcase(overlapping(one,two,overlappingmargin))
end

function commands.doifpositionsonsamepageelse(list,page)
    commands.testcase(onsamepage(list))
end

function commands.doifpositionsonthispageelse(list)
    commands.testcase(onsamepage(list,tostring(tex.count.realpageno)))
end

commands.markcolumnbox = jobpositions.markcolumnbox
commands.markregionbox = jobpositions.markregionbox

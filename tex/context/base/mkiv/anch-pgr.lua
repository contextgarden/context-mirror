if not modules then modules = { } end modules ['anch-pgr'] = {
    version   = 1.001,
    comment   = "companion to anch-pgr.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- This is a bit messy module but backgrounds are messy anyway. Especially when we want to
-- follow shapes. This is work in progress (and always will be).

local format = string.format
local abs = math.abs
local concat, sort, copy = table.concat, table.sort, table.copy
local splitter = lpeg.splitat(":")
local lpegmatch = lpeg.match

local jobpositions    = job.positions
local formatters      = string.formatters

local commands        = commands
local context         = context

local implement       = interfaces.implement

local report_graphics = logs.reporter("graphics")

local f_b_tag         = formatters["b:%s"]
local f_e_tag         = formatters["e:%s"]
local f_p_tag         = formatters["p:%s"]

local f_tag_two       = formatters["%s:%s"]

local f_point         = formatters["%p"]
local f_pair          = formatters["(%p,%p)"]
local f_path          = formatters["%--t--cycle"]

graphics              = graphics or { }
local backgrounds     = { }
graphics.backgrounds  = backgrounds

local function regionarea(r)
    local rx = r.x
    local ry = r.y
    local rw = rx + r.w
    local rh = ry + r.h
    local rd = ry - r.d
    return {
        f_pair(rx, rh - ry),
        f_pair(rw, rh - ry),
        f_pair(rw, rd - ry),
        f_pair(rx, rd - ry),
    }
end

-- we can use a 'local t, n' and reuse the table

local eps = 2

local function add(t,x,y,direction,last)
    local n = #t
    if n == 0 then
        t[n+1] = { x, y }
    else
        local tn = t[n]
        local lx = tn[1]
        local ly = tn[2]
        if x == lx and y == ly then
            -- quick skip
        elseif n == 1 then
            if abs(lx-x) > eps or abs(ly-y) > eps then
                t[n+1] = { x, y }
            end
        else
            local tm = t[n-1]
            local px = tm[1]
            local py = tm[2]
            if (direction == "down" and y > ly) or (direction == "up" and y < ly) then
                -- move back from too much hang
                tn[1] = x -- hm
            elseif abs(lx-px) <= eps and abs(lx-x) <= eps then
                if abs(ly-y) > eps then
                    tn[2] = y
                end
                t[n+1] = { x, y }
            elseif abs(ly-py) <= eps and abs(ly-y) <= eps then
                if abs(lx-x) > eps then
                    tn[1] = x
                end
                t[n+1] = { x, y }
            elseif not last then
                t[n+1] = { x, y }
            end
        end
    end
end

-- local function add(t,x,y,last)
--     t[#t+1] = { x, y }
-- end

local function finish(t) -- circulair list
    local n = #t
    if n > 1 then
        local first = t[1]
        local last  = t[n]
        if abs(first[1]-last[1]) <= eps and abs(first[2]-last[2]) <= eps then
            t[n] = nil
        end
    end
end

local function clip(t,ytop,ybot)
    local first = 1
    local last  = #t
    for i=first,last do
        local y = t[i][2]
        if ytop < y then
            first = i
        end
        if ybot > y then
            last = i
            break
        end
    end
    -- or just reuse t
    local lp = { { t[first][1], ytop } }
    local ln = 2
    for i=first+1,last-1 do
     -- lp[ln] = { t[i][1], t[i][2] }
        lp[ln] = t[i]
        ln = ln + 1
    end
    lp[ln] = { t[last][1], ybot }
    return lp
end

-- todo: mark regions and free paragraphs in collected

-- We assume that we only hang per page and not cross pages which makes sense as hanging
-- is only uses in special cases. We can remove data as soon as a page is done so we could
-- remember per page and discard areas after each shipout.

local function shapes(r,rx,ry,rw,rh,rd,lytop,lybot,rytop,rybot,obeyhang)
    local delta      = r2l and (rw - rx) or 0
    local xleft      = rx + delta
    local xright     = rw - delta
    local paragraphs = r.paragraphs
    local leftshape  = { { xleft,  rh } } -- spikes get removed so we can start at the edge
    local rightshape = { { xright, rh } } -- even if we hang next
    local extending  = false

    if obeyhang and paragraphs and #paragraphs > 0 then

        for i=1,#paragraphs do
            local p  = paragraphs[i]
            local ha = p.ha
            if ha and ha ~= 0 then
                local py = p.y
                local ph = p.h
                local pd = p.d
                local hi = p.hi
                local hang  = ha * (ph + pd)
                local py_ph = py + ph
                if ha < 0 then
                    if hi < 0 then
                        -- right top
                        add(rightshape,xright,     py_ph,       "down") -- "up"
                        add(rightshape,xright + hi,py_ph,       "down") -- "up"
                        add(rightshape,xright + hi,py_ph + hang,"down") -- "up"
                        add(rightshape,xright,     py_ph + hang,"down") -- "up"
                    else
                        -- left top
                        add(leftshape,xleft,     py_ph,       "down")
                        add(leftshape,xleft + hi,py_ph,       "down")
                        add(leftshape,xleft + hi,py_ph + hang,"down")
                        add(leftshape,xleft,     py_ph + hang,"down")
                    end
                else
                    -- maybe some day
                end
                extending = true -- false
            else -- we need to clip to the next par
                local ps = p.ps
                if ps then
                    local py = p.y
                    local ph = p.h
                    local pd = p.d
                    local step = ph + pd
                    local size = #ps * step
                    local py_ph = py + ph
                    add(leftshape, rx,py_ph,"up")
                    add(rightshape,rw,py_ph,"down")
                    for i=1,#ps do
                        local p = ps[i]
                        local l = p[1]
                        local w = p[2]
                        add(leftshape, xleft  + l,     py_ph,"up")
                        add(rightshape,xright + l + w, py_ph,"down")
                        py_ph = py_ph - step
                        add(leftshape, xleft  + l,     py_ph,"up")
                        add(rightshape,xright + l + w, py_ph,"down")
                    end
                    extending = true
                elseif extending then
                    local py = p.y
                    local ph = p.h
                    local pd = p.d
                    local py_ph = py + ph
                    local py_pd = py - pd
                    add(leftshape, leftshape [#leftshape ][1],py_ph,"up")
                    add(rightshape,rightshape[#rightshape][1],py_ph,"down")
                    add(leftshape, xleft ,py_ph,"up")  -- shouldn't this be py_pd
                    add(rightshape,xright,py_ph,"down") -- shouldn't this be py_pd
                    extending = false
                end
            end
        end
        -- we can have a simple variant when no paragraphs
        if extending then
            -- not ok
            leftshape [#leftshape] [2] = rd
            rightshape[#rightshape][2] = rd
        else
            add(leftshape, xleft ,rd,"up")
            add(rightshape,xright,rd,"down")
        end

    else
        leftshape [2] = { xleft,  rd }
        rightshape[2] = { xright, rd }
    end
    leftshape  = clip(leftshape,lytop,lybot)
    rightshape = clip(rightshape,rytop,rybot)
    return leftshape, rightshape
end

local function singlepart(b,e,r,left,right,obeyhang)
    local bx, by = b.x, b.y
    local ex, ey = e.x, e.y
    local rx, ry = r.x, r.y
    local rw = rx + r.w
    local rh = ry + r.h
    local rd = ry - r.d
    if left then
        rx = rx + left
        rw = rw - right
    end
    local bh = by + b.h
    local bd = by - b.d
    local eh = ey + e.h
    local ed = ey - e.d
    if ex == rx then
        -- We probably have a strut at the next line so we force a width
        -- although of course it is better to move up. But as we have whitespace
        -- (at least visually) injected then it's best to stress the issue.
        ex = rw
    end
    local area
    if by == ey then
        area = {
            f_pair(bx,bh-ry),
            f_pair(ex,eh-ry),
            f_pair(ex,ed-ry),
            f_pair(bx,bd-ry),
        }
    else
        area = { }
        local leftshapes, rightshapes = shapes(r,rx,ry,rw,rh,rd,bd,ed,bh,eh,obeyhang,b.r2l)

        -- needed for shapes

        bx = leftshapes[1][1]
        ex = rightshapes[#rightshapes][1]

        --

        add(area,bx,bh-ry)
        for i=1,#rightshapes do
            local ri = rightshapes[i]
            add(area,ri[1],ri[2]-ry)
        end
        add(area,ex,eh-ry)
        add(area,ex,ed-ry)
        for i=#leftshapes,1,-1 do
            local li = leftshapes[i]
            add(area,li[1],li[2]-ry)
        end
        add(area,bx,bd-ry)
        add(area,bx,bh-ry,nil,true) -- finish last straight line (but no add as we cycle)

        finish(area)

        for i=1,#area do
            local a = area[i]
            area[i] = f_pair(a[1],a[2])
        end
    end
    return {
        location = "single",
        region   = r,
        area     = area,
    }
end

local function firstpart(b,r,left,right,obeyhang)
    local bx, by = b.x, b.y
    local rx, ry = r.x, r.y
    local rw = rx + r.w
    local rh = ry + r.h
    local rd = ry - r.d
    if left then
        rx = rx + left
        rw = rw - right
    end
    local bh = by + b.h
    local bd = by - b.d
    local area = { }
    local leftshapes, rightshapes = shapes(r,rx,ry,rw,rh,rd,bd,rd,bh,rd,obeyhang,b.r2l)
    add(area,bx,bh-ry)
    for i=1,#rightshapes do
        local ri = rightshapes[i]
        add(area,ri[1],ri[2]-ry)
    end
    for i=#leftshapes,1,-1 do
        local li = leftshapes[i]
        add(area,li[1],li[2]-ry)
    end
    add(area,bx,bd-ry)
    add(area,bx,bh-ry,nil,true) -- finish last straight line (but no add as we cycle)
    finish(area)
    for i=1,#area do
        local a = area[i]
        area[i] = f_pair(a[1],a[2])
    end
    return {
        location = "first",
        region   = r,
        area     = area,
    }
end

local function middlepart(r,left,right,obeyhang)
    local rx = r.x
    local ry = r.y
    local rw = rx + r.w
    local rh = ry + r.h
    local rd = ry - r.d
    if left then
        rx = rx + left
        rw = rw - right
    end
    local area = { }
    local leftshapes, rightshapes = shapes(r,rx,ry,rw,rh,rd,rh,rd,rh,rd,obeyhang)
    for i=#leftshapes,1,-1 do
        local li = leftshapes[i]
        add(area,li[1],li[2]-ry)
    end
    for i=1,#rightshapes do
        local ri = rightshapes[i]
        add(area,ri[1],ri[2]-ry)
    end
    finish(area)
    for i=1,#area do
        local a = area[i]
        area[i] = f_pair(a[1],a[2])
    end
    return {
        location = "middle",
        region   = r,
        area     = area,
    }
end

local function lastpart(e,r,left,right,obeyhang)
    local ex, ey = e.x, e.y
    local rx, ry = r.x, r.y
    local rw = rx + r.w
    local rh = ry + r.h
    local rd = ry - r.d
    if left then
        rx = rx + left
        rw = rw - right
    end
    local eh = ey + e.h
    local ed = ey - e.d
    local area = { }
    -- two cases: till end and halfway e line
    local leftshapes, rightshapes = shapes(r,rx,ry,rw,rh,rd,rh,ed,rh,eh,obeyhang,e.r2l)
    for i=1,#rightshapes do
        local ri = rightshapes[i]
        add(area,ri[1],ri[2]-ry)
    end
    add(area,ex,eh-ry)
    add(area,ex,ed-ry)
    for i=#leftshapes,1,-1 do
        local li = leftshapes[i]
        add(area,li[1],li[2]-ry)
    end
    finish(area)
    for i=1,#area do
        local a = area[i]
        area[i] = f_pair(a[1],a[2])
    end
    return {
        location = "last",
        region   = r,
        area     = area,
    }
end

local function calculatemultipar(tag,obeyhang)
    local collected = jobpositions.collected
    local b = collected[f_b_tag(tag)]
    local e = collected[f_e_tag(tag)]
    if not b or not e then
        report_graphics("invalid tag %a",tag)
        return { }
    end
    local br = b.r
    local er = e.r
    if not br or not er then
        report_graphics("invalid region for %a",tag)
        return { }
    end
    local btag, bindex = lpegmatch(splitter,br)
    local etag, eindex = lpegmatch(splitter,er)
    if not bindex or not eindex or btag ~= etag then
        report_graphics("invalid indices for %a",tag)
        return { }
    end
    local bindex = tonumber(bindex)
    local eindex = tonumber(eindex)
    -- Here we compensate for columns (in tables): a table can have a set of column
    -- entries and these are shared. We compensate left/right based on the columns
    -- x and w but need to take the region into acount where the specification was
    -- flushed and not the begin pos's region, because otherwise we get the wrong
    -- compensation for assymetrical doublesided layouts.
    local left = 0
    local right = 0
    local rc = b.c
    if rc then
        rc = collected[rc]
        if rc then
            local tb = collected[rc.r]
            if tb then
                left = -(tb.x - rc.x)
                right = (tb.w - rc.w - left) -- tb.x - rc.x
            end
        end
    end
    -- Obeying intermediate changes of left/rightskip makes no sense as it will
    -- look bad, so we only look at the begin situation.
    local bn = b.n
    if bn then
        local bp = collected[f_p_tag(bn)]
        if bp then
            left  = left  + bp.ls
            right = right + bp.rs
        end
    end
    --
    local result
    if bindex == eindex then
        result = {
            list = { [b.p] = { singlepart(b,e,collected[br],left,right,obeyhang) } },
            bpos = b,
            epos = e,
        }
    else
        local list = {
            [b.p] = { firstpart(b,collected[br],left,right,obeyhang) },
        }
        for i=bindex+1,eindex-1 do
            br = f_tag_two(btag,i)
            local r = collected[br]
            if not r then
               report_graphics("invalid middle for %a",br)
            else
                local p  = r.p
                local pp = list[p]
                local mp = middlepart(r,left,right,obeyhang)
                if pp then
                    pp[#pp+1] = mp
                else
                    list[p] = { mp }
                end
            end
        end
        local p  = e.p
        local pp = list[p]
        local lp = lastpart(e,collected[er],left,right,obeyhang)
        if pp then
            pp[#pp+1] = lp
        else
            list[p] = { lp }
        end
        result = {
            list = list,
            bpos = b,
            epos = e,
        }
    end
    return result
end

-- local pending = { } -- needs gc
--
-- local function register(data,n,anchor)
--     local pa = pending[anchor]
--     if not pa then
--         pa = { }
--         pending[anchor] = pa
--     end
--     for page, pagedata in next, data do
--         local pap = pa[page]
--         if pap then
--             pap[#pap+1] = n
--         else
--             pa[page] = { n }
--         end
--     end
-- end
--
-- function backgrounds.registered(anchor,page)
--     local pa = pending[anchor]
--     if pa then
--         concat(pa,",")
--     else
--         return ""
--     end
-- end

local pbg = { } -- will move to pending

function backgrounds.calculatemultipar(n)
    if not pbg[n] then
        pbg[n] = calculatemultipar("pbg",n) or { }
    end
end

local multilocs = {
    single = 1, -- maybe 0
    first  = 1,
    middle = 2,
    last   = 3,
}

-- if unknown context_abck : input mp-abck.mpiv ; fi ;

local f_template_a = formatters[ [[
path multiregs[], multipars[], multibox ;
string multikind[] ;
numeric multilocs[], nofmultipars ;
nofmultipars := %s ;
multibox := unitsquare xyscaled (%p,%p) ;
numeric par_strut_height, par_strut_depth, par_line_height ;
par_strut_height := %p ;
par_strut_depth := %p ;
par_line_height := %p ;
]] ]

local f_template_b = formatters[ [[
multilocs[%s] := %s ;
multikind[%s] := "%s" ;
multipars[%s] := simplified(%--t--cycle) shifted - (%p,%p) ;
]] ]

local f_template_c = formatters[ [[
setbounds currentpicture to multibox ;
]] ]

local function fetchmultipar(n,anchor,page,obeyhang)
    local data = pbg[n]
    if not data then
        data = calculatemultipar(n,obeyhang)
        pbg[n] = data -- can be replaced by register
     -- register(data.list,n,anchor)
    end
    if data then
        local list = data.list
        if list then
            local pagedata = list[page]
            if pagedata then
                local nofmultipars = #pagedata
             -- report_graphics("fetching %a at page %s using anchor %a containing %s multipars",n,page,anchor,nofmultipars)
                local a = jobpositions.collected[anchor]
                if not a then
                    report_graphics("missing anchor %a",anchor)
                else
                    local x, y, w, h, d = a.x, a.y, a.w, a.h, a.d
                    local bpos = data.bpos
                    local bh, bd = bpos.h, bpos.d
                    local result = { f_template_a(nofmultipars,w,h+d,bh,bd,bh+bd) }
                    for i=1,nofmultipars do
                        local region = pagedata[i]
                        result[#result+1] = f_template_b(
                            i, multilocs[region.location],
                            i, region.location,
                            i, region.area, x, y-region.region.y)
                    end
                    data[page] = nil
                    result[#result+1] = f_template_c()
                    result = concat(result,"\n")
                    return result
                end
            end
        end
    end
    return f_template_a(0,"origin",0,0,0)
end

backgrounds.fetchmultipar = fetchmultipar

backgrounds.point = f_point
backgrounds.pair  = f_pair
backgrounds.path  = f_path

-- n anchor page

implement {
    name      = "fetchmultipar",
    actions   = { fetchmultipar, context },
    arguments = { "string", "string", "integer" }
}

implement {
    name      = "fetchmultishape",
    actions   = { fetchmultipar, context },
    arguments = { "string", "string", "integer", true }
}

local f_template_a = formatters[ [[
path posboxes[], posregions[] ;
numeric pospages[] ;
numeric nofposboxes ;
nofposboxes := %s ;
%t ;
]] ]

local f_template_b = formatters[ [[
pospages[%s] := %s ;
posboxes[%s] := (%p,%p)--(%p,%p)--(%p,%p)--(%p,%p)--cycle ;
posregions[%s] := (%p,%p)--(%p,%p)--(%p,%p)--(%p,%p)--cycle ;
]] ]

implement {
    name      = "fetchposboxes",
    arguments = { "string", "string", "integer" },
    actions   = function(tags,anchor,page)  -- no caching (yet) / todo: anchor, page
        local collected = jobpositions.collected
        if type(tags) == "string" then
            tags = utilities.parsers.settings_to_array(tags)
        end
        local list, nofboxes = { }, 0
        for i=1,#tags do
            local tag= tags[i]
            local c = collected[tag]
            if c then
                local r = c.r
                if r then
                    r = collected[r]
                    if r then
                        local rx, ry, rw, rh, rd = r.x, r.y, r.w, r.h, r.d
                        local cx = c.x - rx
                        local cy = c.y - ry
                        local cw = cx + c.w
                        local ch = cy + c.h
                        local cd = cy - c.d
                        nofboxes = nofboxes + 1
                        list[nofboxes] = f_template_b(
                            nofboxes,c.p,
                            nofboxes,cx,ch,cw,ch,cw,cd,cx,cd,
                            nofboxes,0,rh,rw,rh,rw,rd,0,rd
                        )
                    end
                end
            else
                print("\n missing",tag)
            end
        end
        context(f_template_a(nofboxes,list))
    end
}

local doifelse = commands.doifelse

implement {
    name      = "doifelserangeonpage",
    arguments = { "string", "string", "integer" },
    actions   = function(first,last,page)
        local collected = jobpositions.collected
        local f = collected[first]
        if not f or f.p == true then
            doifelse(false)
            return
        end
        local l = collected[last]
        if not l or l.p == true  then
            doifelse(false)
            return
        end
        doifelse(page >= f.p and page <= l.p)
    end
}

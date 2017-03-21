if not modules then modules = { } end modules ['font-ttf'] = {
    version   = 1.001,
    comment   = "companion to font-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- This version is different from previous in the sense that we no longer store
-- contours but keep points and contours (endpoints) separate for a while
-- because later on we need to apply deltas and that is easier on a list of
-- points.

-- The code is a bit messy. I looked at the ff code but it's messy too. It has
-- to do with the fact that we need to look at points on the curve and control
-- points in between. This also means that we start at point 2 and have to look
-- at point 1 when we're at the end. We still use a ps like storage with the
-- operator last in an entry. It's typical code that evolves stepwise till a
-- point of no comprehension.

-- For deltas we need a rather complex loop over points that can have holes and
-- be less than nofpoints and even can have duplicates and also the x and y value
-- lists can be shorter than etc. I need fonts in order to complete this simply
-- because I need to visualize in order to understand (what the standard tries
-- to explain).

-- 0 point then none applied
-- 1 points then applied to all
-- otherwise inferred deltas using nearest
--    if no lower point then use highest referenced point
--    if no higher point then use lowest referenced point
--    factor = (target-left)/(right-left)
--    delta  = (1-factor)*left + factor * right

local next, type, unpack = next, type, unpack
local bittest, band, rshift = bit32.btest, bit32.band, bit32.rshift
local sqrt, round = math.sqrt, math.round
local char = string.char
local concat = table.concat

local report        = logs.reporter("otf reader","ttf")

local readers       = fonts.handlers.otf.readers
local streamreader  = readers.streamreader

local setposition   = streamreader.setposition
local getposition   = streamreader.getposition
local skipbytes     = streamreader.skip
local readbyte      = streamreader.readcardinal1  --  8-bit unsigned integer
local readushort    = streamreader.readcardinal2  -- 16-bit unsigned integer
local readulong     = streamreader.readcardinal4  -- 24-bit unsigned integer
local readchar      = streamreader.readinteger1   --  8-bit   signed integer
local readshort     = streamreader.readinteger2   -- 16-bit   signed integer
local read2dot14    = streamreader.read2dot14     -- 16-bit signed fixed number with the low 14 bits of fraction (2.14) (F2DOT14)
local readinteger   = streamreader.readinteger1

local helpers       = readers.helpers
local gotodatatable = helpers.gotodatatable

local function mergecomposites(glyphs,shapes)

    -- todo : deltas

    local function merge(index,shape,components)
        local contours    = { }
        local points      = { }
        local nofcontours = 0
        local nofpoints   = 0
        local offset      = 0
        local deltas      = shape.deltas
        for i=1,#components do
            local component   = components[i]
            local subindex    = component.index
            local subshape    = shapes[subindex]
            local subcontours = subshape.contours
            local subpoints   = subshape.points
            if not subcontours then
                local subcomponents = subshape.components
                if subcomponents then
                    subcontours, subpoints = merge(subindex,subshape,subcomponents)
                end
            end
            if subpoints then
                local matrix  = component.matrix
                local xscale  = matrix[1]
                local xrotate = matrix[2]
                local yrotate = matrix[3]
                local yscale  = matrix[4]
                local xoffset = matrix[5]
                local yoffset = matrix[6]
                for i=1,#subpoints do
                    local p = subpoints[i]
                    local x = p[1]
                    local y = p[2]
                    nofpoints = nofpoints + 1
                    points[nofpoints] = {
                        xscale * x + xrotate * y + xoffset,
                        yscale * y + yrotate * x + yoffset,
                        p[3]
                    }
                end
                for i=1,#subcontours do
                    nofcontours = nofcontours + 1
                    contours[nofcontours] = offset + subcontours[i]
                end
                offset = offset + #subpoints
            else
                report("missing contours composite %s, component %s of %s, glyph %s",index,i,#components,subindex)
            end
        end
        shape.points     = points -- todo : phantom points
        shape.contours   = contours
        shape.components = nil
        return contours, points
    end

    for index=1,#glyphs do
        local shape = shapes[index]
        if shape then
            local components = shape.components
            if components then
                merge(index,shape,components)
            end
        end
    end

end

local function readnothing(f,nofcontours)
    return {
        type = "nothing",
    }
end

-- begin of converter

local function curveto(m_x,m_y,l_x,l_y,r_x,r_y) -- todo: inline this
    return
        l_x + 2/3 *(m_x-l_x), l_y + 2/3 *(m_y-l_y),
        r_x + 2/3 *(m_x-r_x), r_y + 2/3 *(m_y-r_y),
        r_x, r_y, "c"
end

-- We could omit the operator which saves some 10%:
--
--   #2=lineto  #4=quadratic  #6=cubic #3=moveto (with "m")
--
-- This is tricky ... something to do with phantom points .. however, the hvar
-- and vvar tables should take care of the width .. the test font doesn't have
-- those so here we go then (we need a flag for hvar).
--
--    h-advance left-side-bearing v-advance top-side-bearing
--
-- We had two loops (going backward) but can do it in one loop .. but maybe we
-- should only accept fonts with proper hvar tables.

local function applyaxis(glyph,shape,points,deltas)
    if points then
        local nofpoints = #points
-- local h = nofpoints + 2 -- weird, the example font seems to have left first
-- ----- l = nofpoints + 2
-- ----- v = nofpoints + 3
-- ----- t = nofpoints + 4
-- local width = glyph.width
        for i=1,#deltas do
            local deltaset = deltas[i]
            local xvalues  = deltaset.xvalues
            local yvalues  = deltaset.yvalues
            local dpoints  = deltaset.points
            local factor   = deltaset.factor
            if dpoints then
                -- todo: interpolate
                local nofdpoints = #dpoints
                for i=1,nofdpoints do
                    local d = dpoints[i]
                    local p = points[d]
                    if p then
                        if xvalues then
                            local x = xvalues[d]
                            if x and x ~= 0 then
                                p[1] = p[1] + factor * x
                            end
                        end
                        if yvalues then
                            local y = yvalues[d]
                            if y and y ~= 0 then
                                p[2] = p[2] + factor * y
                            end
                        end
                    elseif width then
-- weird one-off and bad values
--
-- if d == h then
-- print("index",d)
-- inspect(dpoints)
-- inspect(xvalues)
--     local x = xvalues[i]
--     if x then
-- print("phantom h advance",width,factor*x)
--         width = width + factor * x
--     end
-- end
                    end
                end
            else
                for i=1,nofpoints do
                    local p = points[i]
                    if xvalues then
                        local x = xvalues[i]
                        if x and x ~= 0 then
                            p[1] = p[1] + factor * x
                        end
                    end
                    if yvalues then
                        local y = yvalues[i]
                        if y and y ~= 0 then
                            p[2] = p[2] + factor * y
                        end
                    end
                end
-- todo : phantom point hadvance
            end
        end
-- glyph.width = width
    end
end

-- round or not ?

-- local quadratic = true -- both methods work, todo: install a directive
local quadratic = false

local function contours2outlines_normal(glyphs,shapes) -- maybe accept the bbox overhead
    for index=1,#glyphs do
        local shape = shapes[index]
        if shape then
            local glyph    = glyphs[index]
            local contours = shape.contours
            local points   = shape.points
            if contours then
                local nofcontours = #contours
                local segments    = { }
                local nofsegments = 0
                glyph.segments    = segments
                if nofcontours > 0 then
                    local px, py = 0, 0 -- we could use these in calculations which saves a copy
                    local first = 1
                    for i=1,nofcontours do
                        local last = contours[i]
                        if last >= first then
                            local first_pt = points[first]
                            local first_on = first_pt[3]
                            -- todo no new tables but reuse lineto and quadratic
                            if first == last then
                                first_pt[3] = "m" -- "moveto"
                                nofsegments = nofsegments + 1
                                segments[nofsegments] = first_pt
                            else -- maybe also treat n == 2 special
                                local first_on   = first_pt[3]
                                local last_pt    = points[last]
                                local last_on    = last_pt[3]
                                local start      = 1
                                local control_pt = false
                                if first_on then
                                    start = 2
                                else
                                    if last_on then
                                        first_pt = last_pt
                                    else
                                        first_pt = { (first_pt[1]+last_pt[1])/2, (first_pt[2]+last_pt[2])/2, false }
                                    end
                                    control_pt = first_pt
                                end
                                local x, y = first_pt[1], first_pt[2]
                                if not done then
                                    xmin, ymin, xmax, ymax = x, y, x, y
                                    done = true
                                end
                                nofsegments = nofsegments + 1
                                segments[nofsegments] = { x, y, "m" } -- "moveto"
                                if not quadratic then
                                    px, py = x, y
                                end
                                local previous_pt = first_pt
                                for i=first,last do
                                    local current_pt  = points[i]
                                    local current_on  = current_pt[3]
                                    local previous_on = previous_pt[3]
                                    if previous_on then
                                        if current_on then
                                            -- both normal points
                                            local x, y = current_pt[1], current_pt[2]
                                            nofsegments = nofsegments + 1
                                            segments[nofsegments] = { x, y, "l" } -- "lineto"
                                            if not quadratic then
                                                px, py = x, y
                                            end
                                        else
                                            control_pt = current_pt
                                        end
                                    elseif current_on then
                                        local x1, y1 = control_pt[1], control_pt[2]
                                        local x2, y2 = current_pt[1], current_pt[2]
                                        nofsegments = nofsegments + 1
                                        if quadratic then
                                            segments[nofsegments] = { x1, y1, x2, y2, "q" } -- "quadraticto"
                                        else
                                            x1, y1, x2, y2, px, py = curveto(x1, y1, px, py, x2, y2)
                                            segments[nofsegments] = { x1, y1, x2, y2, px, py, "c" } -- "curveto"
                                        end
                                        control_pt = false
                                    else
                                        local x2, y2 = (previous_pt[1]+current_pt[1])/2, (previous_pt[2]+current_pt[2])/2
                                        local x1, y1 = control_pt[1], control_pt[2]
                                        nofsegments = nofsegments + 1
                                        if quadratic then
                                            segments[nofsegments] = { x1, y1, x2, y2, "q" } -- "quadraticto"
                                        else
                                            x1, y1, x2, y2, px, py = curveto(x1, y1, px, py, x2, y2)
                                            segments[nofsegments] = { x1, y1, x2, y2, px, py, "c" } -- "curveto"
                                        end
                                        control_pt = current_pt
                                    end
                                    previous_pt = current_pt
                                end
                                if first_pt == last_pt then
                                    -- we're already done, probably a simple curve
                                else
                                    nofsegments = nofsegments + 1
                                    local x2, y2 = first_pt[1], first_pt[2]
                                    if not control_pt then
                                        segments[nofsegments] = { x2, y2, "l" } -- "lineto"
                                    elseif quadratic then
                                        local x1, y1 = control_pt[1], control_pt[2]
                                        segments[nofsegments] = { x1, y1, x2, y2, "q" } -- "quadraticto"
                                    else
                                        local x1, y1 = control_pt[1], control_pt[2]
                                        x1, y1, x2, y2, px, py = curveto(x1, y1, px, py, x2, y2)
                                        segments[nofsegments] = { x1, y1, x2, y2, px, py, "c" } -- "curveto"
                                     -- px, py = x2, y2
                                    end
                                end
                            end
                        end
                        first = last + 1
                    end
                end
            end
        end
    end
end

local function contours2outlines_shaped(glyphs,shapes,keepcurve)
    for index=1,#glyphs do
        local shape = shapes[index]
        if shape then
            local glyph    = glyphs[index]
            local contours = shape.contours
            local points   = shape.points
            if contours then
                local nofcontours = #contours
                local segments    = keepcurve and { } or nil
                local nofsegments = 0
                if keepcurve then
                    glyph.segments = segments
                end
                if nofcontours > 0 then
                    local xmin, ymin, xmax, ymax, done = 0, 0, 0, 0, false
                    local px, py = 0, 0 -- we could use these in calculations which saves a copy
                    local first = 1
                    for i=1,nofcontours do
                        local last = contours[i]
                        if last >= first then
                            local first_pt = points[first]
                            local first_on = first_pt[3]
                            -- todo no new tables but reuse lineto and quadratic
                            if first == last then
                                -- this can influence the boundingbox
                                if keepcurve then
                                    first_pt[3] = "m" -- "moveto"
                                    nofsegments = nofsegments + 1
                                    segments[nofsegments] = first_pt
                                end
                            else -- maybe also treat n == 2 special
                                local first_on   = first_pt[3]
                                local last_pt    = points[last]
                                local last_on    = last_pt[3]
                                local start      = 1
                                local control_pt = false
                                if first_on then
                                    start = 2
                                else
                                    if last_on then
                                        first_pt = last_pt
                                    else
                                        first_pt = { (first_pt[1]+last_pt[1])/2, (first_pt[2]+last_pt[2])/2, false }
                                    end
                                    control_pt = first_pt
                                end
                                local x, y = first_pt[1], first_pt[2]
                                if not done then
                                    xmin, ymin, xmax, ymax = x, y, x, y
                                    done = true
                                else
                                    if x < xmin then xmin = x elseif x > xmax then xmax = x end
                                    if y < ymin then ymin = y elseif y > ymax then ymax = y end
                                end
                                if keepcurve then
                                    nofsegments = nofsegments + 1
                                    segments[nofsegments] = { x, y, "m" } -- "moveto"
                                end
                                if not quadratic then
                                    px, py = x, y
                                end
                                local previous_pt = first_pt
                                for i=first,last do
                                    local current_pt  = points[i]
                                    local current_on  = current_pt[3]
                                    local previous_on = previous_pt[3]
                                    if previous_on then
                                        if current_on then
                                            -- both normal points
                                            local x, y = current_pt[1], current_pt[2]
                                            if x < xmin then xmin = x elseif x > xmax then xmax = x end
                                            if y < ymin then ymin = y elseif y > ymax then ymax = y end
                                            if keepcurve then
                                                nofsegments = nofsegments + 1
                                                segments[nofsegments] = { x, y, "l" } -- "lineto"
                                            end
                                            if not quadratic then
                                                px, py = x, y
                                            end
                                        else
                                            control_pt = current_pt
                                        end
                                    elseif current_on then
                                        local x1, y1 = control_pt[1], control_pt[2]
                                        local x2, y2 = current_pt[1], current_pt[2]
                                        if quadratic then
                                            if x1 < xmin then xmin = x1 elseif x1 > xmax then xmax = x1 end
                                            if y1 < ymin then ymin = y1 elseif y1 > ymax then ymax = y1 end
                                            if keepcurve then
                                                nofsegments = nofsegments + 1
                                                segments[nofsegments] = { x1, y1, x2, y2, "q" } -- "quadraticto"
                                            end
                                        else
                                            x1, y1, x2, y2, px, py = curveto(x1, y1, px, py, x2, y2)
                                            if x1 < xmin then xmin = x1 elseif x1 > xmax then xmax = x1 end
                                            if y1 < ymin then ymin = y1 elseif y1 > ymax then ymax = y1 end
                                            if x2 < xmin then xmin = x2 elseif x2 > xmax then xmax = x2 end
                                            if y2 < ymin then ymin = y2 elseif y2 > ymax then ymax = y2 end
                                            if px < xmin then xmin = px elseif px > xmax then xmax = px end
                                            if py < ymin then ymin = py elseif py > ymax then ymax = py end
                                            if keepcurve then
                                                nofsegments = nofsegments + 1
                                                segments[nofsegments] = { x1, y1, x2, y2, px, py, "c" } -- "curveto"
                                            end
                                        end
                                        control_pt = false
                                    else
                                        local x2, y2 = (previous_pt[1]+current_pt[1])/2, (previous_pt[2]+current_pt[2])/2
                                        local x1, y1 = control_pt[1], control_pt[2]
                                        if quadratic then
                                            if x1 < xmin then xmin = x1 elseif x1 > xmax then xmax = x1 end
                                            if y1 < ymin then ymin = y1 elseif y1 > ymax then ymax = y1 end
                                            if keepcurve then
                                                nofsegments = nofsegments + 1
                                                segments[nofsegments] = { x1, y1, x2, y2, "q" } -- "quadraticto"
                                            end
                                        else
                                            x1, y1, x2, y2, px, py = curveto(x1, y1, px, py, x2, y2)
                                            if x1 < xmin then xmin = x1 elseif x1 > xmax then xmax = x1 end
                                            if y1 < ymin then ymin = y1 elseif y1 > ymax then ymax = y1 end
                                            if x2 < xmin then xmin = x2 elseif x2 > xmax then xmax = x2 end
                                            if y2 < ymin then ymin = y2 elseif y2 > ymax then ymax = y2 end
                                            if px < xmin then xmin = px elseif px > xmax then xmax = px end
                                            if py < ymin then ymin = py elseif py > ymax then ymax = py end
                                            if keepcurve then
                                                nofsegments = nofsegments + 1
                                                segments[nofsegments] = { x1, y1, x2, y2, px, py, "c" } -- "curveto"
                                            end
                                        end
                                        control_pt = current_pt
                                    end
                                    previous_pt = current_pt
                                end
                                if first_pt == last_pt then
                                    -- we're already done, probably a simple curve
                                elseif not control_pt then
                                    if keepcurve then
                                        nofsegments = nofsegments + 1
                                        segments[nofsegments] = { first_pt[1], first_pt[2], "l" } -- "lineto"
                                    end
                                else
                                    local x1, y1 = control_pt[1], control_pt[2]
                                    local x2, y2 = first_pt[1], first_pt[2]
                                    if x1 < xmin then xmin = x1 elseif x1 > xmax then xmax = x1 end
                                    if y1 < ymin then ymin = y1 elseif y1 > ymax then ymax = y1 end
                                    if quadratic then
                                        if keepcurve then
                                            nofsegments = nofsegments + 1
                                            segments[nofsegments] = { x1, y1, x2, y2, "q" } -- "quadraticto"
                                        end
                                    else
                                        x1, y1, x2, y2, px, py = curveto(x1, y1, px, py, x2, y2)
                                        if x2 < xmin then xmin = x2 elseif x2 > xmax then xmax = x2 end
                                        if y2 < ymin then ymin = y2 elseif y2 > ymax then ymax = y2 end
                                        if px < xmin then xmin = px elseif px > xmax then xmax = px end
                                        if py < ymin then ymin = py elseif py > ymax then ymax = py end
                                        if keepcurve then
                                            nofsegments = nofsegments + 1
                                            segments[nofsegments] = { x1, y1, x2, y2, px, py, "c" } -- "curveto"
                                        end
                                     -- px, py = x2, y2
                                    end
                                end
                            end
                        end
                        first = last + 1
                    end
                    glyph.boundingbox = { round(xmin), round(ymin), round(xmax), round(ymax) }
                end
            end
        end
    end
end

-- optimize for zero

local c_zero = char(0)
local s_zero = char(0,0)

local function toushort(n)
    return char(band(rshift(n,8),0xFF),band(n,0xFF))
end

local function toshort(n)
    if n < 0 then
        n = n + 0x10000
    end
    return char(band(rshift(n,8),0xFF),band(n,0xFF))
end

-- todo: we can reuse result, xpoints and ypoints

local function repackpoints(glyphs,shapes)
    local noboundingbox = { 0, 0, 0, 0 }
    local result        = { } -- reused
    for index=1,#glyphs do
        local shape = shapes[index]
        if shape then
            local r     = 0
            local glyph = glyphs[index]
            if false then -- shape.type == "composite"
                -- we merged them
            else
                local contours    = shape.contours
                local nofcontours = #contours
                local boundingbox = glyph.boundingbox or noboundingbox
                r = r + 1 result[r] = toshort(nofcontours)
                r = r + 1 result[r] = toshort(boundingbox[1]) -- xmin
                r = r + 1 result[r] = toshort(boundingbox[2]) -- ymin
                r = r + 1 result[r] = toshort(boundingbox[3]) -- xmax
                r = r + 1 result[r] = toshort(boundingbox[4]) -- ymax
                if nofcontours > 0 then
                    for i=1,nofcontours do
                        r = r + 1 result[r] = toshort(contours[i]-1)
                    end
                    r = r + 1 result[r] = s_zero -- no instructions
                    local points   = shape.points
                    local currentx = 0
                    local currenty = 0
                    local xpoints  = { }
                    local ypoints  = { }
                    local x        = 0
                    local y        = 0
                    local lastflag = nil
                    local nofflags = 0
                    for i=1,#points do
                        local pt = points[i]
                        local px = pt[1]
                        local py = pt[2]
                        local fl = pt[3] and 0x01 or 0x00
                        if px == currentx then
                            fl = fl + 0x10
                        else
                            local dx = round(px - currentx)
                            if dx < -255 or dx > 255 then
                                x = x + 1 xpoints[x] = toshort(dx)
                            elseif dx < 0 then
                                fl = fl + 0x02
                                x = x + 1 xpoints[x] = char(-dx)
                            elseif dx > 0 then
                                fl = fl + 0x12
                                x = x + 1 xpoints[x] = char(dx)
                            else
                                fl = fl + 0x02
                                x = x + 1 xpoints[x] = c_zero
                            end
                        end
                        if py == currenty then
                            fl = fl + 0x20
                        else
                            local dy = round(py - currenty)
                            if dy < -255 or dy > 255 then
                                y = y + 1 ypoints[y] = toshort(dy)
                            elseif dy < 0 then
                                fl = fl + 0x04
                                y = y + 1 ypoints[y] = char(-dy)
                            elseif dy > 0 then
                                fl = fl + 0x24
                                y = y + 1 ypoints[y] = char(dy)
                            else
                                fl = fl + 0x04
                                y = y + 1 ypoints[y] = c_zero
                            end
                        end
                        currentx = px
                        currenty = py
                        if lastflag == fl then
                            nofflags = nofflags + 1
                        else -- if > 255
                            if nofflags == 1 then
                                r = r + 1 result[r] = char(lastflag)
                            elseif nofflags == 2 then
                                r = r + 1 result[r] = char(lastflag,lastflag)
                            elseif nofflags > 2 then
                                lastflag = lastflag + 0x08
                                r = r + 1 result[r] = char(lastflag,nofflags-1)
                            end
                            nofflags = 1
                            lastflag = fl
                        end
                    end
                    if nofflags == 1 then
                        r = r + 1 result[r] = char(lastflag)
                    elseif nofflags == 2 then
                        r = r + 1 result[r] = char(lastflag,lastflag)
                    elseif nofflags > 2 then
                        lastflag = lastflag + 0x08
                        r = r + 1 result[r] = char(lastflag,nofflags-1)
                    end
                    r = r + 1 result[r] = concat(xpoints)
                    r = r + 1 result[r] = concat(ypoints)
                end
            end
            glyph.stream = concat(result,"",1,r)
        else
            -- fatal
        end
    end
end

-- end of converter

local function readglyph(f,nofcontours) -- read deltas here, saves space
    local points       = { }
    local contours     = { }
    local instructions = { }
    local flags        = { }
    for i=1,nofcontours do
        contours[i] = readshort(f) + 1
    end
    local nofpoints       = contours[nofcontours]
    local nofinstructions = readushort(f)
    skipbytes(f,nofinstructions)
    -- because flags can repeat we don't know the amount ... in fact this is
    -- not that efficient (small files but more mem)
    local i = 1
    while i <= nofpoints do
        local flag = readbyte(f)
        flags[i] = flag
        if bittest(flag,0x08) then
            for j=1,readbyte(f) do
                i = i + 1
                flags[i] = flag
            end
        end
        i = i + 1
    end
    -- first come the x coordinates, and next the y coordinates and they
    -- can be repeated
    local x = 0
    for i=1,nofpoints do
        local flag  = flags[i]
        local short = bittest(flag,0x02)
        local same  = bittest(flag,0x10)
        if short then
            if same then
                x = x + readbyte(f)
            else
                x = x - readbyte(f)
            end
        elseif same then
            -- copy
        else
            x = x + readshort(f)
        end
        points[i] = { x, y, bittest(flag,0x01) }
    end
    local y = 0
    for i=1,nofpoints do
        local flag  = flags[i]
        local short = bittest(flag,0x04)
        local same  = bittest(flag,0x20)
        if short then
            if same then
                y = y + readbyte(f)
            else
                y = y - readbyte(f)
            end
        elseif same then
         -- copy
        else
            y = y + readshort(f)
        end
        points[i][2] = y
    end
    return {
        type      = "glyph",
        points    = points,
        contours  = contours,
        nofpoints = nofpoints,
    }
end

local function readcomposite(f)
    local components    = { }
    local nofcomponents = 0
    local instructions  = false
    while true do
        local flags      = readushort(f)
        local index      = readushort(f)
        ----- f_words    = bittest(flags,0x0001)
        local f_xyarg    = bittest(flags,0x0002)
        ----- f_round    = bittest(flags,0x0004+0x0002)
        ----- f_scale    = bittest(flags,0x0008)
        ----- f_reserved = bittest(flags,0x0010)
        ----- f_more     = bittest(flags,0x0020)
        ----- f_xyscale  = bittest(flags,0x0040)
        ----- f_matrix   = bittest(flags,0x0080)
        ----- f_instruct = bittest(flags,0x0100)
        ----- f_usemine  = bittest(flags,0x0200)
        ----- f_overlap  = bittest(flags,0x0400)
        local f_offset   = bittest(flags,0x0800)
        ----- f_uoffset  = bittest(flags,0x1000)
        local xscale     = 1
        local xrotate    = 0
        local yrotate    = 0
        local yscale     = 1
        local xoffset    = 0
        local yoffset    = 0
        local base       = false
        local reference  = false
        if f_xyarg then
            if bittest(flags,0x0001) then -- f_words
                xoffset = readshort(f)
                yoffset = readshort(f)
            else
                xoffset = readchar(f) -- signed byte, stupid name
                yoffset = readchar(f) -- signed byte, stupid name
            end
        else
            if bittest(flags,0x0001) then -- f_words
                base      = readshort(f)
                reference = readshort(f)
            else
                base      = readchar(f) -- signed byte, stupid name
                reference = readchar(f) -- signed byte, stupid name
            end
        end
        if bittest(flags,0x0008) then -- f_scale
            xscale = read2dot14(f)
            yscale = xscale
            if f_xyarg and f_offset then
                xoffset = xoffset * xscale
                yoffset = yoffset * yscale
            end
        elseif bittest(flags,0x0040) then -- f_xyscale
            xscale = read2dot14(f)
            yscale = read2dot14(f)
            if f_xyarg and f_offset then
                xoffset = xoffset * xscale
                yoffset = yoffset * yscale
            end
        elseif bittest(flags,0x0080) then -- f_matrix
            xscale  = read2dot14(f)
            xrotate = read2dot14(f)
            yrotate = read2dot14(f)
            yscale  = read2dot14(f)
            if f_xyarg and f_offset then
                xoffset = xoffset * sqrt(xscale ^2 + xrotate^2)
                yoffset = yoffset * sqrt(yrotate^2 + yscale ^2)
            end
        end
        nofcomponents = nofcomponents + 1
        components[nofcomponents] = {
            index      = index,
            usemine    = bittest(flags,0x0200), -- f_usemine
            round      = bittest(flags,0x0006), -- f_round,
            base       = base,
            reference  = reference,
            matrix     = { xscale, xrotate, yrotate, yscale, xoffset, yoffset },
        }
        if bittest(flags,0x0100) then
            instructions = true
        end
        if not bittest(flags,0x0020) then -- f_more
            break
        end
    end
    return {
        type       = "composite",
        components = components,
    }
end

-- function readers.cff(f,offset,glyphs,doshapes) -- false == no shapes (nil or true otherwise)

-- The glyf table depends on the loca table. We have one entry to much
-- in the locations table (the last one is a dummy) because we need to
-- calculate the size of a glyph blob from the delta, although we not
-- need it in our usage (yet). We can remove the locations table when
-- we're done (todo: cleanup finalizer).

function readers.loca(f,fontdata,specification)
    if specification.glyphs then
        local datatable = fontdata.tables.loca
        if datatable then
            -- locations are relative to the glypdata table (glyf)
            local offset    = fontdata.tables.glyf.offset
            local format    = fontdata.fontheader.indextolocformat
            local locations = { }
            setposition(f,datatable.offset)
            if format == 1 then
                local nofglyphs = datatable.length/4 - 2
                for i=0,nofglyphs do
                    locations[i] = offset + readulong(f)
                end
                fontdata.nofglyphs = nofglyphs
            else
                local nofglyphs = datatable.length/2 - 2
                for i=0,nofglyphs do
                    locations[i] = offset + readushort(f) * 2
                end
                fontdata.nofglyphs = nofglyphs
            end
            fontdata.locations = locations
        end
    end
end

function readers.glyf(f,fontdata,specification) -- part goes to cff module
    local tableoffset = gotodatatable(f,fontdata,"glyf",specification.glyphs)
    if tableoffset then
        local locations = fontdata.locations
        if locations then
            local glyphs     = fontdata.glyphs
            local nofglyphs  = fontdata.nofglyphs
            local filesize   = fontdata.filesize
            local nothing    = { 0, 0, 0, 0 }
            local shapes     = { }
            local loadshapes = specification.shapes or specification.instance
            for index=0,nofglyphs do
                local location = locations[index]
                if location >= filesize then
                    report("discarding %s glyphs due to glyph location bug",nofglyphs-index+1)
                    fontdata.nofglyphs = index - 1
                    fontdata.badfont   = true
                    break
                elseif location > 0 then
                    setposition(f,location)
                    local nofcontours = readshort(f)
                    glyphs[index].boundingbox = {
                        readshort(f), -- xmin
                        readshort(f), -- ymin
                        readshort(f), -- xmax
                        readshort(f), -- ymax
                    }
                    if not loadshapes then
                        -- save space
                    elseif nofcontours == 0 then
                        shapes[index] = readnothing(f,nofcontours)
                    elseif nofcontours > 0 then
                        shapes[index] = readglyph(f,nofcontours)
                    else
                        shapes[index] = readcomposite(f,nofcontours)
                    end
                else
                    if loadshapes then
                        shapes[index] = { }
                    end
                    glyphs[index].boundingbox = nothing
                end
            end
            if loadshapes then
                if readers.gvar then
                    readers.gvar(f,fontdata,specification,glyphs,shapes)
                end
                mergecomposites(glyphs,shapes)
                if specification.instance then
                    if specification.streams then
                        repackpoints(glyphs,shapes)
                    else
                        contours2outlines_shaped(glyphs,shapes,specification.shapes)
                    end
                elseif specification.loadshapes then
                    contours2outlines_normal(glyphs,shapes)
                end
            end
        end
    end
end

-- gvar is a bit crazy format and one can really wonder if the bit-jugling obscurity
-- is still needed in these days .. cff is much nicer with these blends while the ttf
-- coding variant looks quite horrible

local function readtuplerecord(f,nofaxis)
    local record = { }
    for i=1,nofaxis do
        record[i] = read2dot14(f)
    end
    return record
end

local function readpoints(f)
    local count = readbyte(f)
    if count == 0 then
        -- second byte not used, deltas for all point numbers
        return nil, 0 -- todo
    else
        if count < 128 then
            -- no second byte, use count
        else
            count = band(count,0x80) * 256 + readbyte(f)
        end
        local points = { }
        local p = 0
        local n = 1
        while p < count do
            local control   = readbyte(f)
            local runreader = bittest(control,0x80) and readushort or readbyte
            local runlength = band(control,0x7F)
            for i=1,runlength+1 do
                n = n + runreader(f)
                p = p + 1
                points[p] = n
            end
        end
        return points, p
    end
end

local function readdeltas(f,nofpoints)
    local deltas = { }
    local p = 0
    local n = 0
    local z = false
    while nofpoints > 0 do
        local control   = readbyte(f)
        local allzero   = bittest(control,0x80)
        local runreader = bittest(control,0x40) and readshort or readinteger
        local runlength = band(control,0x3F) + 1
        if allzero then
            z = runlength
        else
            if z then
                for i=1,z do
                    p = p + 1
                    deltas[p] = 0
                end
                z = false
            end
            for i=1,runlength do
                p = p + 1
                deltas[p] = runreader(f)
            end
        end
        nofpoints = nofpoints - runlength
    end
    -- saves space
 -- if z then
 --     for i=1,z do
 --         p = p + 1
 --         deltas[p] = 0
 --     end
 -- end
    if p > 0 then
        -- forget about trailing zeros
        return deltas
    else
        -- forget about all zeros
    end
end

function readers.gvar(f,fontdata,specification,glyphdata,shapedata)
    local instance = specification.instance
    if not instance then
        return
    end
    local factors = specification.factors
    if not factors then
        return
    end
    local tableoffset = gotodatatable(f,fontdata,"gvar",specification.variable or specification.shapes)
    if tableoffset then
        local version     = readulong(f) -- 1.0
        local nofaxis     = readushort(f)
        local noftuples   = readushort(f)
        local tupleoffset = readulong(f)  -- shared
        local nofglyphs   = readushort(f)
        local flags       = readushort(f)
        local dataoffset  = tableoffset + readulong(f)
        local data        = { }
        local tuples      = { }
        local glyphdata   = fontdata.glyphs
        -- there is one more offset (so that one can calculate the size i suppose)
        -- so we could test for overflows but we simply assume sane font files
        if bittest(flags,0x0001) then
            for i=1,nofglyphs do
                data[i] = readulong(f)
            end
        else
            for i=1,nofglyphs do
                data[i] = 2*readushort(f)
            end
        end
        --
        setposition(f,tableoffset+tupleoffset)
        for i=1,noftuples do
            tuples[i] = readtuplerecord(f,nofaxis) -- used ?
        end
        local lastoffset = false
        for i=1,nofglyphs do -- hm one more cf spec
            local shape = shapedata[i-1] -- todo 0
            if shape then
                local startoffset = dataoffset + data[i]
                if startoffset == lastoffset then
                    -- in the font that i used for testing there were the same offsets so
                    -- we can assume that this indicates a zero entry
                else
                    -- todo: args_are_xy_values mess .. i have to be really bored
                    -- and motivated to deal with it

                    lastoffset = startoffset
                    setposition(f,startoffset)
                    local flags     = readushort(f)
                    local count     = band(flags,0x0FFF)
                    local points    = bittest(flags,0x8000)
                    local offset    = startoffset + readushort(f) -- to serialized
                    local deltas    = { }
                    local nofpoints = 0
                    local allpoints = (shape.nofpoints or 0) + 1
                    if points then
                        -- go to the packed stream (get them once)
                        local current = getposition(f)
                        setposition(f,offset)
                        points, nofpoints = readpoints(f)
                        offset = getposition(f)
                        setposition(f,current)
                        -- and back to the table
                    else
                        points, nofpoints = nil, 0
                    end
                    for i=1,count do
                        local currentstart = getposition(f)
                        local size         = readushort(f) -- check
                        local flags        = readushort(f)
                        local index        = band(flags,0x0FFF)
                        local haspeak      = bittest(flags,0x8000)
                        local intermediate = bittest(flags,0x4000)
                        local private      = bittest(flags,0x1000)
                        local peak         = nil
                        local start        = nil
                        local stop         = nil
                        local xvalues      = nil
                        local yvalues      = nil
                        local points       = points    -- we default to shared
                        local nofpoints    = nofpoints -- we default to shared
                        local advance      = 4
                        if peak then
                            peak    = readtuplerecord(f,nofaxis)
                            advance = advance + 2*nofaxis
                        else
                            if index+1 > #tuples then
                                print("error, bad index",index)
                            end
                            peak = tuples[index+1] -- hm, needs checking, only peak?
                        end
-- what start otherwise ?
                        if intermediate then
                            start   = readtuplerecord(f,nofaxis)
                            stop    = readtuplerecord(f,nofaxis)
                            advance = advance + 4*nofaxis
                        end
                        -- get the deltas
                        if size > 0 then
                            -- goto the packed stream
                            setposition(f,offset)
                            if private then
                                points, nofpoints = readpoints(f)
                            elseif nofpoints == 0 then
                                nofpoints = allpoints
                            end
                            if nofpoints > 0 then
                                xvalues = readdeltas(f,nofpoints)
                                yvalues = readdeltas(f,nofpoints)
                            end
                            offset = getposition(f)
                            -- back to the table
                            setposition(f,currentstart+advance)
                        end
                        if not xvalues and not yvalues then
                            points = nil
                        end
                        local s = 1
                        for i=1,nofaxis do
                            local f = factors[i]
                            local start = start and start[i] or 0
                            local peak  = peak  and peak [i] or 0
                            local stop  = stop  and stop [i] or 0
                            -- do we really need these tests ... can't we assume sane values
                            if start > peak or peak > stop then
                                -- * 1
                            elseif start < 0 and stop > 0 and peak ~= 0 then
                                -- * 1
                            elseif peak == 0 then
                                -- * 1
                            elseif f < start or f > stop then
                                -- * 0
                                s = 0
                                break
                            elseif f < peak then
--                                 s = - s * (f - start) / (peak - start)
                                s = s * (f - start) / (peak - start)
                            elseif f > peak then
                                s = s * (stop - f) / (stop - peak)
                            else
                                -- * 1
                            end
                        end
                        if s ~= 0 then
                            deltas[#deltas+1] = {
                                factor  = s,
                                points  = points,
                                xvalues = xvalues,
                                yvalues = yvalues,
                            }
                        end
                    end
                    if shape.type == "glyph" then
                        applyaxis(glyphdata[i],shape,shape.points,deltas)
                    else
                        shape.deltas = deltas
                    end
                end
            end
        end
    end
end

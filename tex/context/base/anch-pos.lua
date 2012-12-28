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

local commands, context = commands, context

local tostring, next, rawget, setmetatable = tostring, next, rawget, setmetatable
local sort = table.sort
local format, gmatch, match = string.format, string.gmatch, string.match
local rawget = rawget
local lpegmatch = lpeg.match
local insert, remove = table.insert, table.remove
local allocate, mark = utilities.storage.allocate, utilities.storage.mark
local texsp, texcount, texbox, texdimen, texsetcount = tex.sp, tex.count, tex.box, tex.dimen, tex.setcount
----- texsp = string.todimen -- because we cache this is much faster but no rounding

local pdf               = pdf -- h and v are variables

local setmetatableindex = table.setmetatableindex
local new_latelua       = nodes.pool.latelua
local find_tail         = node.slide

local variables         = interfaces.variables
local v_text            = variables.text
local v_column          = variables.column

local pt                = number.dimenfactors.pt
local pts               = number.pts
local formatters        = string.formatters

local collected         = allocate()
local tobesaved         = allocate()

local jobpositions = {
    collected = collected,
    tobesaved = tobesaved,
}

job.positions = jobpositions

_plib_ = jobpositions -- might go

local default = { -- not r and paragraphs etc
    __index = {
        x  = 0,     -- x position baseline
        y  = 0,     -- y position baseline
        w  = 0,     -- width
        h  = 0,     -- height
        d  = 0,     -- depth
        p  = 0,     -- page
        n  = 0,     -- paragraph
        ls = 0,     -- leftskip
        rs = 0,     -- rightskip
        hi = 0,     -- hangindent
        ha = 0,     -- hangafter
        hs = 0,     -- hsize
        pi = 0,     -- parindent
        ps = false, -- parshape
    }
}

local f_b_tag     = formatters["b:%s"]
local f_e_tag     = formatters["e:%s"]
local f_p_tag     = formatters["p:%s"]
local f_w_tag     = formatters["w:%s"]

local f_b_column  = formatters["_plib_.b_col(%q)"]
local f_e_column  = formatters["_plib_.e_col()"]

local f_enhance   = formatters["_plib_.enhance(%q)"]
local f_region    = formatters["region:%s"]

local f_b_region  = formatters["_plib_.b_region(%q)"]
local f_e_region  = formatters["_plib_.e_region(%s)"]

local f_tag_three = formatters["%s:%s:%s"]
local f_tag_two   = formatters["%s:%s"]

local function sorter(a,b)
    return a.y > b.y
end

local nofusedregions    = 0
local nofmissingregions = 0
local nofregular        = 0

-- todo: register subsets and count them indepently

local function initializer()
    tobesaved = jobpositions.tobesaved
    collected = jobpositions.collected
    -- enhance regions with paragraphs
    for tag, data in next, collected do
        local region = data.r
        if region then
            local r = collected[region]
            if r then
                local paragraphs = r.paragraphs
                if not paragraphs then
                    r.paragraphs = { data }
                else
                    paragraphs[#paragraphs+1] = data
                end
                nofusedregions = nofusedregions + 1
            else
                nofmissingregions = nofmissingregions + 1
            end
        else
            nofregular = nofregular + 1
        end
        setmetatable(data,default)
    end
    -- add metatable
 -- for tag, data in next, collected do
 --     setmetatable(data,default)
 -- end
    -- sort this data
    for tag, data in next, collected do
        local region = data.r
        if region then
            local r = collected[region]
            if r then
                local paragraphs = r.paragraphs
                if paragraphs and #paragraphs > 1 then
                    sort(paragraphs,sorter)
                end
            end
        end
        -- so, we can be sparse and don't need 'or 0' code
    end
end

job.register('job.positions.collected', tobesaved, initializer)

local regions    = { }
local nofregions = 0
local region     = nil

local columns    = { }
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
    if data.p == true then
        data.p = texcount.realpageno
    end
    if data.c == true then
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

commands.setpos     = setall

-- will become private table (could also become attribute driven but too nasty
-- as attributes can bleed e.g. in margin stuff)

function jobpositions.b_col(tag)
    tobesaved[tag] = {
        r = true,
        x = pdf.h,
        w = 0,
    }
    insert(columns,tag)
    column = tag
end

function jobpositions.e_col(tag)
    local t = tobesaved[column]
    if not t then
        -- something's wrong
    else
        t.w = pdf.h - t.x
        t.r = region
    end
    remove(columns)
    column = columns[#columns]
end

function commands.bcolumn(tag,register)
    insert(columns,tag)
    column = tag
    if register then
        context(new_latelua(f_b_column(tag)))
    end
end

function commands.ecolumn(register)
    if register then
        context(new_latelua(f_e_column()))
    end
    remove(columns)
    column = columns[#columns]
end

-- regions

function jobpositions.b_region(tag)
    local last = tobesaved[tag]
    last.x = pdf.h
last.y = pdf.v
    last.p = texcount.realpageno
    insert(regions,tag)
    region = tag
end

function jobpositions.e_region(correct)
    local last = tobesaved[region]
if correct then
    last.h = last.y - pdf.v
end
    last.y = pdf.v
    remove(regions)
    region = regions[#regions]
end

function jobpositions.markregionbox(n,tag,correct)
    if not tag or tag == "" then
        nofregions = nofregions + 1
        tag = f_region(nofregions)
    end
    local box = texbox[n]
    local w = box.width
    local h = box.height
    local d = box.depth
    tobesaved[tag] = {
        p = true,
        x = true,
        y = pdf.v, -- true,
        w = w ~= 0 and w or nil,
        h = h ~= 0 and h or nil,
        d = d ~= 0 and d or nil,
    }
    local push = new_latelua(f_b_region(tag))
    local pop  = new_latelua(f_e_region(tostring(correct))) -- todo: check if tostring is needed with formatter
    -- maybe we should construct a hbox first (needs experimenting) so that we can avoid some at the tex end
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
    context(new_latelua(f_enhance(name)))
end

local nofparagraphs = 0

function commands.parpos() -- todo: relate to localpar (so this is an intermediate variant)
    nofparagraphs = nofparagraphs + 1
    texsetcount("global","c_anch_positions_paragraph",nofparagraphs)
    local strutbox = texbox.strutbox
    local t = {
        p  = true,
        c  = true,
        r  = true,
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
    local parshape   = tex.parshape
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
    if parshape and #parshape > 0 then
        t.ps = parshape
    end
    local tag = f_p_tag(nofparagraphs)
    tobesaved[tag] = t
    context(new_latelua(f_enhance(tag)))
end

function commands.posxy(name) -- can node.write be used here?
    tobesaved[name] = {
        p = true,
        c = column,
        r = true,
        x = true,
        y = true,
        n = nofparagraphs > 0 and nofparagraphs or nil,
    }
    context(new_latelua(f_enhance(name)))
end

function commands.poswhd(name,w,h,d)
    tobesaved[name] = {
        p = true,
        c = column,
        r = true,
        x = true,
        y = true,
        w = w,
        h = h,
        d = d,
        n = nofparagraphs > 0 and nofparagraphs or nil,
    }
    context(new_latelua(f_enhance(name)))
end

function commands.posplus(name,w,h,d,extra)
    tobesaved[name] = {
        p = true,
        c = column,
        r = true,
        x = true,
        y = true,
        w = w,
        h = h,
        d = d,
        n = nofparagraphs > 0 and nofparagraphs or nil,
        e = extra,
    }
    context(new_latelua(f_enhance(name)))
end

function commands.posstrut(name,w,h,d)
    local strutbox = texbox.strutbox
    tobesaved[name] = {
        p = true,
        c = column,
        r = true,
        x = true,
        y = true,
        h = strutbox.height,
        d = strutbox.depth,
        n = nofparagraphs > 0 and nofparagraphs or nil,
    }
    context(new_latelua(f_enhance(name)))
end

function jobpositions.getreserved(tag,n)
    if tag == v_column then
        local fulltag = f_tag_three(tag,texcount.realpageno,n or 1)
        local data = collected[fulltag]
        if data then
            return data, fulltag
        end
        tag = v_text
    end
    if tag == v_text then
        local fulltag = f_tag_two(tag,texcount.realpageno)
        return collected[fulltag] or false, fulltag
    end
    return collected[tag] or false, tag
end

function jobpositions.copy(target,source)
    collected[target] = collected[source]
end

function jobpositions.replace(id,p,x,y,w,h,d)
    collected[id] = { p = p, x = x, y = y, w = w, h = h, d = d } -- c g
end

function jobpositions.page(id)
    local jpi = collected[id]
    return jpi and jpi.p
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
    return jpi and jpi.n
end

jobpositions.p = jobpositions.page
jobpositions.r = jobpositions.region
jobpositions.c = jobpositions.column
jobpositions.n = jobpositions.paragraph

function jobpositions.x(id)
    local jpi = collected[id]
    return jpi and jpi.x
end

function jobpositions.y(id)
    local jpi = collected[id]
    return jpi and jpi.y
end

function jobpositions.width(id)
    local jpi = collected[id]
    return jpi and jpi.w
end

function jobpositions.height(id)
    local jpi = collected[id]
    return jpi and jpi.h
end

function jobpositions.depth(id)
    local jpi = collected[id]
    return jpi and jpi.d
end

function jobpositions.leftskip(id)
    local jpi = collected[id]
    return jpi and jpi.ls
end

function jobpositions.rightskip(id)
    local jpi = collected[id]
    return jpi and jpi.rs
end

function jobpositions.hsize(id)
    local jpi = collected[id]
    return jpi and jpi.hs
end

function jobpositions.parindent(id)
    local jpi = collected[id]
    return jpi and jpi.pi
end

function jobpositions.hangindent(id)
    local jpi = collected[id]
    return jpi and jpi.hi
end

function jobpositions.hangafter(id)
    local jpi = collected[id]
    return jpi and jpi.ha or 1
end

function jobpositions.xy(id)
    local jpi = collected[id]
    if jpi then
        return jpi.x, jpi.y
    else
        return 0, 0
    end
end

function jobpositions.lowerleft(id)
    local jpi = collected[id]
    if jpi then
        return jpi.x, jpi.y - jpi.d
    else
        return 0, 0
    end
end

function jobpositions.lowerright(id)
    local jpi = collected[id]
    if jpi then
        return jpi.x + jpi.w, jpi.y - jpi.d
    else
        return 0, 0
    end
end

function jobpositions.upperright(id)
    local jpi = collected[id]
    if jpi then
        return jpi.x + jpi.w, jpi.y + jpi.h
    else
        return 0, 0
    end
end

function jobpositions.upperleft(id)
    local jpi = collected[id]
    if jpi then
        return jpi.x, jpi.y + jpi.h
    else
        return 0, 0
    end
end

function jobpositions.position(id)
    local jpi = collected[id]
    if jpi then
        return jpi.p, jpi.x, jpi.y, jpi.w, jpi.h, jpi.d
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
        local x_one = one.x
        local x_two = two.x
        local w_two = two.w
        local llx_one = x_one         - overlappingmargin
        local urx_two = x_two + w_two + overlappingmargin
        if llx_one > urx_two then
            return false
        end
        local w_one = one.w
        local urx_one = x_one + w_one + overlappingmargin
        local llx_two = x_two         - overlappingmargin
        if urx_one < llx_two then
            return false
        end
        local y_one = one.y
        local y_two = two.y
        local d_one = one.d
        local h_two = two.h
        local lly_one = y_one - d_one - overlappingmargin
        local ury_two = y_two + h_two + overlappingmargin
        if lly_one > ury_two then
            return false
        end
        local h_one = one.h
        local d_two = two.d
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
        if p and p ~= true then
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
        if x and x ~= true and x ~= 0 then
            context("%.5fpt",x*pt)
            return
        end
    end
    context('0pt')
end

function commands.MPy(id)
    local jpi = collected[id]
    if jpi then
        local y = jpi.y
        if y and y ~= true and y ~= 0 then
            context("%.5fpt",y*pt)
            return
        end
    end
    context('0pt')
end

function commands.MPw(id)
    local jpi = collected[id]
    if jpi then
        local w = jpi.w
        if w and w ~= 0 then
            context("%.5fpt",w*pt)
            return
        end
    end
    context('0pt')
end

function commands.MPh(id)
    local jpi = collected[id]
    if jpi then
        local h = jpi.h
        if h and h ~= 0 then
            context("%.5fpt",h*pt)
            return
        end
    end
    context('0pt')
end

function commands.MPd(id)
    local jpi = collected[id]
    if jpi then
        local d = jpi.d
        if d and d ~= 0 then
            context("%.5fpt",d*pt)
            return
        end
    end
    context('0pt')
end

function commands.MPxy(id)
    local jpi = collected[id]
    if jpi then
        context('(%.5fpt,%.5fpt)',
            jpi.x*pt,
            jpi.y*pt
        )
    else
        context('(0,0)')
    end
end

function commands.MPll(id)
    local jpi = collected[id]
    if jpi then
        context('(%.5fpt,%.5fpt)',
             jpi.x       *pt,
            (jpi.y-jpi.d)*pt
        )
    else
        context('(0,0)') -- for mp only
    end
end

function commands.MPlr(id)
    local jpi = collected[id]
    if jpi then
        context('(%.5fpt,%.5fpt)',
            (jpi.x + jpi.w)*pt,
            (jpi.y - jpi.d)*pt
        )
    else
        context('(0,0)') -- for mp only
    end
end

function commands.MPur(id)
    local jpi = collected[id]
    if jpi then
        context('(%.5fpt,%.5fpt)',
            (jpi.x + jpi.w)*pt,
            (jpi.y + jpi.h)*pt
        )
    else
        context('(0,0)') -- for mp only
    end
end

function commands.MPul(id)
    local jpi = collected[id]
    if jpi then
        context('(%.5fpt,%.5fpt)',
             jpi.x         *pt,
            (jpi.y + jpi.h)*pt
        )
    else
        context('(0,0)') -- for mp only
    end
end

local function MPpos(id)
    local jpi = collected[id]
    if jpi then
        local p = jpi.p
        if p then
            context("%s,%.5fpt,%.5fpt,%.5fpt,%.5fpt,%.5fpt",
                p,
                jpi.x*pt,
                jpi.y*pt,
                jpi.w*pt,
                jpi.h*pt,
                jpi.d*pt
            )
            return
        end
    end
    context('0,0,0,0,0,0') -- for mp only
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
        if c and p ~= true  then
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
        if r and p ~= true  then
            context(r)
            return
        end
    end
end

local function MPpardata(n)
    local t = collected[n]
    if not t then
        local tag = f_p_tag(n)
        t = collected[tag]
    end
    if t then
        context("%.5fpt,%.5fpt,%.5fpt,%.5fpt,%s,%.5fpt",
            t.hs*pt,
            t.ls*pt,
            t.rs*pt,
            t.hi*pt,
            t.ha,
            t.pi*pt
        )
    else
        context("0,0,0,0,0,0") -- for mp only
    end
end

commands.MPpardata = MPpardata

function commands.MPposset(id) -- special helper, used in backgrounds
    local b = f_b_tag(id)
    local e = f_e_tag(id)
    local w = f_w_tag(id)
    local p = f_p_tag(jobpositions.n(b))
    MPpos(b) context(",") MPpos(e) context(",") MPpos(w) context(",") MPpos(p) context(",") MPpardata(p)
end

function commands.MPls(id)
    local t = collected[id]
    if t then
        context("%.5fpt",t.ls*pt)
    else
        context("0pt")
    end
end

function commands.MPrs(id)
    local t = collected[id]
    if t then
        context("%.5fpt",t.rs*pt)
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
        context("%.5fpt,%.5fpt,%.5fpt,%.5fpt,%.5fpt",
            t.x*pt,
            t.y*pt,
            t.w*pt,
            t.h*pt,
            t.d*pt
        )
    else
        context("0,0,0,0,0") -- for mp only
    end
end

local doif, doifelse = commands.doif, commands.doifelse

function commands.doifpositionelse(name)
    doifelse(collected[name])
end

function commands.doifposition(name)
    doif(collected[name])
end

function commands.doifpositiononpage(name,page) -- probably always realpageno
    local c = collected[name]
    doifelse(c and c.p == page)
end

function commands.doifoverlappingelse(one,two,overlappingmargin)
    doifelse(overlapping(one,two,overlappingmargin))
end

function commands.doifpositionsonsamepageelse(list,page)
    doifelse(onsamepage(list))
end

function commands.doifpositionsonthispageelse(list)
    doifelse(onsamepage(list,tostring(tex.count.realpageno)))
end

function commands.doifelsepositionsused()
    doifelse(next(collected))
end

commands.markcolumnbox = jobpositions.markcolumnbox
commands.markregionbox = jobpositions.markregionbox

-- statistics (at least for the moment, when testing)

statistics.register("positions", function()
    local total = nofregular + nofusedregions + nofmissingregions
    if total > 0 then
        return format("%s collected, %s regulars, %s regions, %s unresolved regions",
            total, nofregular, nofusedregions, nofmissingregions)
    else
        return nil
    end
end)

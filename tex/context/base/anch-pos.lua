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

-- context(new_latelua_node(f_enhance(tag)))
--     =>
-- context.lateluafunction(function() f_enhance(tag) end)

-- maybe replace texsp by our own converter (stay at the lua end)
-- eventually mp will have large numbers so we can use sp there too

local tostring, next, rawget, setmetatable = tostring, next, rawget, setmetatable
local sort = table.sort
local format, gmatch, match = string.format, string.gmatch, string.match
local rawget = rawget
local lpegmatch = lpeg.match
local insert, remove = table.insert, table.remove
local allocate, mark = utilities.storage.allocate, utilities.storage.mark

local scanners          = tokens.scanners
local scanstring        = scanners.string
local scaninteger       = scanners.integer
local scandimen         = scanners.dimen

local compilescanner    = tokens.compile
local scanners          = interfaces.scanners

local commands          = commands
local context           = context

local tex               = tex
local texgetcount       = tex.getcount
local texsetcount       = tex.setcount
local texget            = tex.get
local texsp             = tex.sp
----- texsp             = string.todimen -- because we cache this is much faster but no rounding

local pdf               = pdf -- h and v are variables

local setmetatableindex = table.setmetatableindex

local nuts              = nodes.nuts

local getfield          = nuts.getfield
local setfield          = nuts.setfield
local getlist           = nuts.getlist
local getbox            = nuts.getbox
local getskip           = nuts.getskip

local find_tail         = nuts.tail

local new_latelua       = nuts.pool.latelua
local new_latelua_node  = nodes.pool.latelua

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

jobpositions.used       = false

-- todo: register subsets and count them indepently

local function initializer()
    tobesaved = jobpositions.tobesaved
    collected = jobpositions.collected
    -- add sparse regions
    local pages = structures.pages.collected
    if pages  then
        local last = nil
        for p=1,#pages do
            local region = "page:" .. p
            local data   = collected[region]
            if data then
                last   = data
                last.p = nil -- no need for a page
            elseif last then
                collected[region] = last
            end
        end
    end
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
    jobpositions.used = next(collected)
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

local getpos  = function() getpos  = backends.codeinjections.getpos  return getpos () end
local gethpos = function() gethpos = backends.codeinjections.gethpos return gethpos() end
local getvpos = function() getvpos = backends.codeinjections.getvpos return getvpos() end

local function setdim(name,w,h,d,extra) -- will be used when we move to sp allover
    local x, y = getpos()
    if x == 0 then x = nil end
    if y == 0 then y = nil end
    if w == 0 then w = nil end
    if h == 0 then h = nil end
    if d == 0 then d = nil end
    if extra == "" then extra = nil end
    -- todo: sparse
    tobesaved[name] = {
        p = texgetcount("realpageno"),
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
        if data.y == true then
            data.x, data.y = getpos()
        else
            data.x = gethpos()
        end
    elseif data.y == true then
        data.y = getvpos()
    end
    if data.p == true then
        data.p = texgetcount("realpageno")
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

-- analyze some files (with lots if margindata) and then when one key optionally
-- use that one instead of a table (so, a 3rd / 4th argument: key, e.g. "x")

local function set(name,index,val) -- ,key
    local data = enhance(val or index)
    if val then
-- if data[key] and not next(next(data)) then
--     data = data[key]
-- end
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

-- scanners.setpos     = setall

-- trackers.enable("tokens.compi*")

-- something weird: the compiler fails us here

scanners.dosaveposition = compilescanner {
    actions   = setall, -- name p x y
    arguments = { "string", "integer", "dimen", "dimen" }
}

scanners.dosavepositionwhd = compilescanner { -- somehow fails
    actions   = setall, -- name p x y w h d
    arguments = { "string", "integer", "dimen", "dimen", "dimen", "dimen", "dimen" }
}

scanners.dosavepositionplus = compilescanner {
    actions   = setall,  -- name p x y w h d extra
    arguments = { "string", "integer", "dimen", "dimen", "dimen", "dimen", "dimen", "string" }
}

-- will become private table (could also become attribute driven but too nasty
-- as attributes can bleed e.g. in margin stuff)

-- not much gain in keeping stack (inc/dec instead of insert/remove)

function jobpositions.b_col(tag)
    tobesaved[tag] = {
        r = true,
        x = gethpos(),
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
        t.w = gethpos() - t.x
        t.r = region
    end
    remove(columns)
    column = columns[#columns]
end

scanners.bposcolumn = function() -- tag
    local tag = scanstring()
    insert(columns,tag)
    column = tag
end

scanners.bposcolumnregistered = function() -- tag
    local tag = scanstring()
    insert(columns,tag)
    column = tag
    context(new_latelua_node(f_b_column(tag)))
end

scanners.eposcolumn = function()
    remove(columns)
    column = columns[#columns]
end

scanners.eposcolumnregistered = function()
    context(new_latelua_node(f_e_column()))
    remove(columns)
    column = columns[#columns]
end

-- regions

function jobpositions.b_region(tag)
    local last = tobesaved[tag]
    last.x, last.y = getpos()
    last.p = texgetcount("realpageno")
    insert(regions,tag)
    region = tag
end

function jobpositions.e_region(correct)
    local last = tobesaved[region]
    local v = getvpos()
    if correct then
        last.h = last.y - v
    end
    last.y = v
    remove(regions)
    region = regions[#regions]
end

local function setregionbox(n,tag)
    if not tag or tag == "" then
        nofregions = nofregions + 1
        tag = f_region(nofregions)
    end
    local box = getbox(n)
    local w = getfield(box,"width")
    local h = getfield(box,"height")
    local d = getfield(box,"depth")
    tobesaved[tag] = {
        p = true,
        x = true,
        y = getvpos(), -- true,
        w = w ~= 0 and w or nil,
        h = h ~= 0 and h or nil,
        d = d ~= 0 and d or nil,
    }
    return tag, box
end

local function markregionbox(n,tag,correct)
    local tag, box = setregionbox(n,tag)
    local push = new_latelua(f_b_region(tag))
    local pop  = new_latelua(f_e_region(tostring(correct))) -- todo: check if tostring is needed with formatter
    -- maybe we should construct a hbox first (needs experimenting) so that we can avoid some at the tex end
    local head = getlist(box)
    if head then
        local tail = find_tail(head)
        setfield(head,"prev",push)
        setfield(push,"next",head)
        setfield(pop,"prev",tail)
        setfield(tail,"next",pop)
    else -- we can have a simple push/pop
        setfield(push,"next",pop)
        setfield(pop,"prev",push)
    end
    setfield(box,"list",push)
end

jobpositions.markregionbox = markregionbox
jobpositions.setregionbox  = setregionbox

function jobpositions.enhance(name)
    enhance(tobesaved[name])
end

-- scanners.pos = function(name,t) -- name t
--     local name = scanstring()
--     tobesaved[name] = scanstring()
--     context(new_latelua_node(f_enhance(name)))
-- end

local nofparagraphs = 0

scanners.parpos = function() -- todo: relate to localpar (so this is an intermediate variant)
    nofparagraphs = nofparagraphs + 1
    texsetcount("global","c_anch_positions_paragraph",nofparagraphs)
    local strutbox = getbox("strutbox")
    local t = {
        p  = true,
        c  = true,
        r  = true,
        x  = true,
        y  = true,
        h  = getfield(strutbox,"height"),
        d  = getfield(strutbox,"depth"),
        hs = texget("hsize"),
    }
    local leftskip   = getfield(getskip("leftskip"),"width")
    local rightskip  = getfield(getskip("rightskip"),"width")
    local hangindent = texget("hangindent")
    local hangafter  = texget("hangafter")
    local parindent  = texget("parindent")
    local parshape   = texget("parshape")
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
    context(new_latelua_node(f_enhance(tag)))
end

scanners.dosetposition = function() -- name
    local name = scanstring()
    tobesaved[name] = {
        p = true,
        c = column,
        r = true,
        x = true,
        y = true,
        n = nofparagraphs > 0 and nofparagraphs or nil,
    }
    context(new_latelua_node(f_enhance(name)))
end

scanners.dosetpositionwhd = function() -- name w h d extra
    local name = scanstring()
    tobesaved[name] = {
        p = true,
        c = column,
        r = true,
        x = true,
        y = true,
        w = scandimen(),
        h = scandimen(),
        d = scandimen(),
        n = nofparagraphs > 0 and nofparagraphs or nil,
    }
    context(new_latelua_node(f_enhance(name)))
end

scanners.dosetpositionbox = function() -- name box
    local name = scanstring()
    local box  = getbox(scaninteger())
    tobesaved[name] = {
        p = true,
        c = column,
        r = true,
        x = true,
        y = true,
        w = getfield(box,"width"),
        h = getfield(box,"height"),
        d = getfield(box,"depth"),
        n = nofparagraphs > 0 and nofparagraphs or nil,
    }
    context(new_latelua_node(f_enhance(name)))
end

scanners.dosetpositionplus = function() -- name w h d extra
    local name = scanstring()
    tobesaved[name] = {
        p = true,
        c = column,
        r = true,
        x = true,
        y = true,
        w = scandimen(),
        h = scandimen(),
        d = scandimen(),
        n = nofparagraphs > 0 and nofparagraphs or nil,
        e = scanstring(),
    }
    context(new_latelua_node(f_enhance(name)))
end

scanners.dosetpositionstrut = function() -- name
    local name = scanstring()
    local strutbox = getbox("strutbox")
    tobesaved[name] = {
        p = true,
        c = column,
        r = true,
        x = true,
        y = true,
        h = getfield(strutbox,"height"),
        d = getfield(strutbox,"depth"),
        n = nofparagraphs > 0 and nofparagraphs or nil,
    }
    context(new_latelua_node(f_enhance(name)))
end

function jobpositions.getreserved(tag,n)
    if tag == v_column then
        local fulltag = f_tag_three(tag,texgetcount("realpageno"),n or 1)
        local data = collected[fulltag]
        if data then
            return data, fulltag
        end
        tag = v_text
    end
    if tag == v_text then
        local fulltag = f_tag_two(tag,texgetcount("realpageno"))
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
    if jpi then
        local r = jpi.r
        if r then
            return r
        end
        local p = jpi.p
        if p then
            return "page:" .. p
        end
    end
    return false
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

scanners.replacepospxywhd = function() -- name page x y w h d
    collected[scanstring()] = {
        p = scaninteger(),
        x = scandimen(),
        y = scandimen(),
        w = scandimen(),
        h = scandimen(),
        d = scandimen(),
    }
end

scanners.copyposition = function() -- target source
    collected[scanstring()] = collected[scanstring()]
end

scanners.MPp = function() -- name
    local jpi = collected[scanstring()]
    if jpi then
        local p = jpi.p
        if p and p ~= true then
            context(p)
            return
        end
    end
    context('0')
end

scanners.MPx = function() -- name
    local jpi = collected[scanstring()]
    if jpi then
        local x = jpi.x
        if x and x ~= true and x ~= 0 then
            context("%.5Fpt",x*pt)
            return
        end
    end
    context('0pt')
end

scanners.MPy = function() -- name
    local jpi = collected[scanstring()]
    if jpi then
        local y = jpi.y
        if y and y ~= true and y ~= 0 then
            context("%.5Fpt",y*pt)
            return
        end
    end
    context('0pt')
end

scanners.MPw = function() -- name
    local jpi = collected[scanstring()]
    if jpi then
        local w = jpi.w
        if w and w ~= 0 then
            context("%.5Fpt",w*pt)
            return
        end
    end
    context('0pt')
end

scanners.MPh = function() -- name
    local jpi = collected[scanstring()]
    if jpi then
        local h = jpi.h
        if h and h ~= 0 then
            context("%.5Fpt",h*pt)
            return
        end
    end
    context('0pt')
end

scanners.MPd = function() -- name
    local jpi = collected[scanstring()]
    if jpi then
        local d = jpi.d
        if d and d ~= 0 then
            context("%.5Fpt",d*pt)
            return
        end
    end
    context('0pt')
end

scanners.MPxy = function() -- name
    local jpi = collected[scanstring()]
    if jpi then
        context('(%.5Fpt,%.5Fpt)',
            jpi.x*pt,
            jpi.y*pt
        )
    else
        context('(0,0)')
    end
end

scanners.MPll = function() -- name
    local jpi = collected[scanstring()]
    if jpi then
        context('(%.5Fpt,%.5Fpt)',
             jpi.x       *pt,
            (jpi.y-jpi.d)*pt
        )
    else
        context('(0,0)') -- for mp only
    end
end

scanners.MPlr = function() -- name
    local jpi = collected[scanstring()]
    if jpi then
        context('(%.5Fpt,%.5Fpt)',
            (jpi.x + jpi.w)*pt,
            (jpi.y - jpi.d)*pt
        )
    else
        context('(0,0)') -- for mp only
    end
end

scanners.MPur = function() -- name
    local jpi = collected[scanstring()]
    if jpi then
        context('(%.5Fpt,%.5Fpt)',
            (jpi.x + jpi.w)*pt,
            (jpi.y + jpi.h)*pt
        )
    else
        context('(0,0)') -- for mp only
    end
end

scanners.MPul = function() -- name
    local jpi = collected[scanstring()]
    if jpi then
        context('(%.5Fpt,%.5Fpt)',
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
            context("%s,%.5Fpt,%.5Fpt,%.5Fpt,%.5Fpt,%.5Fpt",
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

scanners.MPpos = function() -- name
    MPpos(scanstring())
end

scanners.MPn = function() -- name
    local jpi = collected[scanstring()]
    if jpi then
        local n = jpi.n
        if n then
            context(n)
            return
        end
    end
    context(0)
end

scanners.MPc = function() -- name
    local jpi = collected[scanstring()]
    if jpi then
        local c = jpi.c
        if c and c ~= true  then
            context(c)
            return
        end
    end
    context('0') -- okay ?
end

scanners.MPr = function() -- name
    local jpi = collected[scanstring()]
    if jpi then
        local r = jpi.r
        if r and r ~= true  then
            context(r)
        end
        local p = jpi.p
        if p then
            context("page:" .. p)
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
        context("%.5Fpt,%.5Fpt,%.5Fpt,%.5Fpt,%s,%.5Fpt",
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

scanners.MPpardata = function() -- name
    MPpardata(scanstring())
end

scanners.MPposset = function() -- name (special helper, used in backgrounds)
    local name = scanstring()
    local b = f_b_tag(name)
    local e = f_e_tag(name)
    local w = f_w_tag(name)
    local p = f_p_tag(jobpositions.n(b))
    MPpos(b) context(",") MPpos(e) context(",") MPpos(w) context(",") MPpos(p) context(",") MPpardata(p)
end

scanners.MPls = function() -- name
    local jpi = collected[scanstring()]
    if jpi then
        context("%.5Fpt",jpi.ls*pt)
    else
        context("0pt")
    end
end

scanners.MPrs = function() -- name
    local jpi = collected[scanstring()]
    if jpi then
        context("%.5Fpt",jpi.rs*pt)
    else
        context("0pt")
    end
end

local splitter = lpeg.tsplitat(",")

scanners.MPplus = function() -- name n default
    local jpi     = collected[scanstring()]
    local n       = scaninteger()
    local default = scanstring()
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

scanners.MPrest = function() -- name default
    local jpi     = collected[scanstring()]
    local default = scanstring()
    context(jpi and jpi.e or default)
end

scanners.MPxywhd = function() -- name
    local jpi = collected[scanstring()]
    if jpi then
        context("%.5Fpt,%.5Fpt,%.5Fpt,%.5Fpt,%.5Fpt",
            jpi.x*pt,
            jpi.y*pt,
            jpi.w*pt,
            jpi.h*pt,
            jpi.d*pt
        )
    else
        context("0,0,0,0,0") -- for mp only
    end
end

local doif     = commands.doif
local doifelse = commands.doifelse

scanners.doifelseposition = function() -- name
    doifelse(collected[scanstring()])
end

scanners.doifposition = function() -- name
    doif(collected[scanstring()])
end

scanners.doifelsepositiononpage = function() -- name page -- probably always realpageno
    local c = collected[scanstring()]
    local p = scaninteger()
    doifelse(c and c.p == p)
end

scanners.doifelseoverlapping = function() -- one two
    doifelse(overlapping(scanstring(),scanstring()))
end

scanners.doifelsepositionsonsamepage = function() -- list
    doifelse(onsamepage(scanstring()))
end

scanners.doifelsepositionsonthispage = function() -- list
    doifelse(onsamepage(scanstring(),tostring(texgetcount("realpageno"))))
end

scanners.doifelsepositionsused = function()
    doifelse(next(collected))
end

scanners.markregionbox = function() -- box
    markregionbox(scaninteger())
end

scanners.setregionbox = function() -- box
    setregionbox(scaninteger())
end

scanners.markregionboxtagged = function() -- box tag
    markregionbox(scaninteger(),scanstring())
end

scanners.setregionboxtagged = function() -- box tag
    setregionbox(scaninteger(),scanstring())
end

scanners.markregionboxcorrected = function() -- box tag
    markregionbox(scaninteger(),scanstring(),true)
end

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

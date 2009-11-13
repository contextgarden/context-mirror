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

local concat, format = table.concat, string.format
local texprint, ctxcatcodes = tex.print, tex.ctxcatcodes

jobpositions           = jobpositions or { }
jobpositions.collected = jobpositions.collected or { }
jobpositions.tobesaved = jobpositions.tobesaved or { }

-- these are global since they are used often at the tex end

-- \the\dimexpr #2\ifnum\positionanchormode=\plusone-\MPx\pageanchor\fi\relax
-- \the\dimexpr #3\ifnum\positionanchormode=\plusone-\MPy\pageanchor\fi\relax

ptbs, pcol = jobpositions.tobesaved, jobpositions.collected -- global

local dx, dy = "0pt", "0pt"

local function initializer()
    ptbs, pcol = jobpositions.tobesaved, jobpositions.collected
    local p = pcol["page:0"] -- page:1
    if p then
-- to be checked !
--~ dx, dy = p[2] or "0pt", p[3] or "0pt"
    end
end

job.register('jobpositions.collected', jobpositions.tobesaved, initializer)

function jobpositions.copy(target,source)
    jobpositions.collected[target] = jobpositions.collected[source] or ptbs[source]
end

function jobpositions.replace(name,...)
    jobpositions.collected[name] = {...}
end

function jobpositions.doifelse(name)
    commands.testcase(jobpositions.collected[name] or ptbs[name])
end

function jobpositions.MPp(id) local jpi = pcol[id] or ptbs[id] texprint(ctxcatcodes,(jpi and jpi[1]) or '0'  ) end
function jobpositions.MPx(id) local jpi = pcol[id] or ptbs[id] texprint(ctxcatcodes,(jpi and jpi[2]) or '0pt') end
function jobpositions.MPy(id) local jpi = pcol[id] or ptbs[id] texprint(ctxcatcodes,(jpi and jpi[3]) or '0pt') end
function jobpositions.MPw(id) local jpi = pcol[id] or ptbs[id] texprint(ctxcatcodes,(jpi and jpi[4]) or '0pt') end
function jobpositions.MPh(id) local jpi = pcol[id] or ptbs[id] texprint(ctxcatcodes,(jpi and jpi[5]) or '0pt') end
function jobpositions.MPd(id) local jpi = pcol[id] or ptbs[id] texprint(ctxcatcodes,(jpi and jpi[6]) or '0pt') end


    function jobpositions.MPx(id)
        local jpi = pcol[id] or ptbs[id]
        local x = jpi and jpi[2]
        if x then
            texprint(ctxcatcodes,format('\\the\\dimexpr %s-%s\\relax',x,dx))
        else
            texprint(ctxcatcodes,'0pt')
        end
    end
    function jobpositions.MPy(id)
        local jpi = pcol[id] or ptbs[id]
        local y = jpi and jpi[3]
        if y then
            texprint(ctxcatcodes,format('\\the\\dimexpr %s-%s\\relax',y,dy))
        else
            texprint(ctxcatcodes,'0pt')
        end
    end

-- the following are only for MP so there we can leave out the pt

-- can be writes and no format needed any more

function jobpositions.MPxy(id)
    local jpi = pcol[id] or ptbs[id]
    if jpi then
        texprint(ctxcatcodes,format('(%s-%s,%s-%s)',jpi[2],dx,jpi[3],dy))
--~         texprint(ctxcatcodes,'(',jpi[2],'-',dx,',',jpi[3],'-',dy,')')
    else
        texprint(ctxcatcodes,'(0,0)')
    end
end

function jobpositions.MPll(id)
    local jpi = pcol[id] or ptbs[id]
    if jpi then
        texprint(ctxcatcodes,format('(%s-%s,%s-%s-%s)',jpi[2],dx,jpi[3],jpi[6],dy))
--~         texprint(ctxcatcodes,'(',jpi[2],'-',dx,',',jpi[3],'-',jpi[6],'-',dy,')')
    else
        texprint(ctxcatcodes,'(0,0)')
    end
end

function jobpositions.MPlr(id)
    local jpi = pcol[id] or ptbs[id]
    if jpi then
        texprint(ctxcatcodes,format('(%s+%s-%s,%s-%s-%s)',jpi[2],jpi[4],dx,jpi[3],jpi[6],dy))
--~         texprint(ctxcatcodes,'(',jpi[2],'+',jpi[4],'-',dx,',',jpi[3],'-',jpi[6],'-',dy,')')
    else
        texprint(ctxcatcodes,'(0,0)')
    end
end

function jobpositions.MPur(id)
    local jpi = pcol[id] or ptbs[id]
    if jpi then
        texprint(ctxcatcodes,format('(%s+%s-%s,%s+%s-%s)',jpi[2],jpi[4],dx,jpi[3],jpi[5],dy))
--~         texprint(ctxcatcodes,'(',jpi[2],'+',jpi[4],'-',dx,',',jpi[3],'+',jpi[5],'-',dy,')')
    else
        texprint(ctxcatcodes,'(0,0)')
    end
end

function jobpositions.MPul(id)
    local jpi = pcol[id] or ptbs[id]
    if jpi then
        texprint(ctxcatcodes,format('(%s-%s,%s+%s-%s)',jpi[2],dx,jpi[3],jpi[5],dy))
--~         texprint(ctxcatcodes,'(',jpi[2],'-',dx,',',jpi[3],'+',jpi[5],'-',dy,')')
    else
        texprint(ctxcatcodes,'(0,0)')
    end
end

function jobpositions.MPpos(id)
    local jpi = pcol[id] or ptbs[id]
    if jpi then
        texprint(ctxcatcodes,concat(jpi,',',1,6))
    else
        texprint(ctxcatcodes,'0,0,0,0,0,0')
    end
end

local splitter = lpeg.splitat(",")

function jobpositions.MPplus(id,n,default)
    local jpi = pcol[id] or ptbs[id]
    if not jpi then
        texprint(ctxcatcodes,default)
    else
        local split = jpi[0]
        if not split then
            split = splitter:match(jpi[7])
            jpi[0] = split
        end
        texprint(ctxcatcodes,split[n] or default)
    end
end

function jobpositions.MPrest(id,default)
    local jpi = pcol[id] or ptbs[id]
 -- texprint(ctxcatcodes,(jpi and jpi[7] and concat(jpi,",",7,#jpi)) or default)
    texprint(ctxcatcodes,(jpi and jpi[7]) or default)
end

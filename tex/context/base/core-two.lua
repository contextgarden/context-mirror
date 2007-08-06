if not modules then modules = { } end modules ['core-two'] = {
    version   = 1.001,
    comment   = "companion to core-two.tex",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

--[[ldx--
<p>We save multi-pass information in the main utility table.</p>
--ldx]]--

if not jobs        then jobs         = { } end
if not job         then jobs['main'] = { } end job = jobs['main']
if not job.twopass then job.twopass  = { } end

function job.definetwopassdata(id)
    job.twopass[id] = job.twopass[id] or { }
end

function job.gettwopassdata(id)
    local jti = job.twopass[id]
    if jti and #jti > 0 then
        tex.print(jti[1])
        table.remove(jti,1)
    end
end

function job.checktwopassdata(id)
    local jti = job.twopass[id]
    if jti and #jti > 0 then
        tex.print(jti[1])
    end
end

function job.getfromtwopassdata(id,n)
    local jti = job.twopass[id]
    if jti and jti[n] then
        tex.print(jti[n])
    end
end

job.findtwopassdata  = job.getfromtwopassdata
job.getfirstpassdata = job.checktwopassdata

function job.getlasttwopassdata(id)
    local jti = job.twopass[id]
    if jti and #jti > 0 then
        tex.print(jti[#jti])
    end
end

function job.noftwopassitems(id)
    local jti = job.twopass[id]
    if jti then
        tex.print(#jti)
    else
        tex.print('0')
    end
end

function job.twopassdatalist(id)
    local jti = job.twopass[id]
    if jti then
        tex.print(table.concat(jti,','))
    end
end

function job.doifelseintwopassdata(id,str)
    local jti = job.twopass[id]
    if jti then
        local found = false
        for _, v in pairs(jti) do
            if v == str then
                found = true
                break
            end
        end
        cs.testcase(found)
    else
        cs.testcase(false)
    end
end

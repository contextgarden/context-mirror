if not modules then modules = { } end modules ['core-two'] = {
    version   = 1.001,
    comment   = "companion to core-two.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local remove, concat = table.remove, table.concat
local allocate = utilities.storage.allocate

--[[ldx--
<p>We save multi-pass information in the main utility table. This is a
bit of a mess because we support old and new methods.</p>
--ldx]]--

local collected = allocate()
local tobesaved = allocate()

local jobpasses = {
    collected = collected,
    tobesaved = tobesaved,
}

job.passes = jobpasses

local function initializer()
    collected = jobpasses.collected
    tobesaved = jobpasses.tobesaved
end

job.register('job.passes.collected', tobesaved, initializer, nil)

local function allocate(id)
    local p = tobesaved[id]
    if not p then
        p = { }
        tobesaved[id] = p
    end
    return p
end

jobpasses.define = allocate

function jobpasses.save(id,str)
    local jti = allocate(id)
    jti[#jti+1] = str
end

function jobpasses.savetagged(id,tag,str)
    local jti = allocate(id)
    jti[tag] = str
end

function jobpasses.getcollected(id)
    return collected[id] or { }
end

function jobpasses.gettobesaved(id)
    return allocate(id)
end

function jobpasses.get(id)
    local jti = collected[id]
    if jti and #jti > 0 then
        context(remove(jti,1))
    end
end

function jobpasses.first(id)
    local jti = collected[id]
    if jti and #jti > 0 then
        context(jti[1])
    end
end

function jobpasses.last(id)
    local jti = collected[id]
    if jti and #jti > 0 then
        context(jti[#jti])
    end
end

jobpasses.check = jobpasses.first

function jobpasses.find(id,n)
    local jti = collected[id]
    if jti and jti[n] then
        context(jti[n])
    end
end

function jobpasses.count(id)
    local jti = collected[id]
    context((jti and #jti) or 0)
end

function jobpasses.list(id)
    local jti = collected[id]
    if jti then
        context(concat(jti,','))
    end
end

function jobpasses.doifinlistelse(id,str)
    local jti = collected[id]
    if jti then
        local found = false
        for _, v in next, jti do
            if v == str then
                found = true
                break
            end
        end
        commands.testcase(found)
    else
        commands.testcase(false)
    end
end

--

function jobpasses.savedata(id,data)
    local jti = allocate(id)
    jti[#jti+1] = data
    return #jti
end

function jobpasses.getdata(id,index,default)
    local jti = collected[id]
    local value = jit and jti[index]
    context((value ~= "" and value) or default or "")
end

function jobpasses.getfield(id,index,tag,default)
    local jti = collected[id]
    jti = jti and jti[index]
    local value = jti and jti[tag]
    context((value ~= "" and value) or default or "")
end


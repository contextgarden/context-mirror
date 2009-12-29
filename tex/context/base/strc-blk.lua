if not modules then modules = { } end modules ['strc--blk'] = {
    version   = 1.001,
    comment   = "companion to strc-blk.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- this one runs on top of buffers and structure

local texprint, format, gmatch, find = tex.print, string.format, string.gmatch, string.find
local lpegmatch = lpeg.match

local ctxcatcodes = tex.ctxcatcodes

structure        = structure or { }
structure.blocks = structure.blocks or { }

local blocks = structure.blocks

blocks.collected = blocks.collected or { }
blocks.tobesaved = blocks.tobesaved or { }
blocks.states    = blocks.states    or { }

local tobesaved, collected, states = blocks.tobesaved, blocks.collected, blocks.states

local function initializer()
    collected, tobesaved = blocks.collected, blocks.tobesaved
end

job.register('structure.blocks.collected', structure.blocks.tobesaved, initializer)

local printer = (lpeg.linebyline/texprint)^0

function blocks.print(name,data,hide)
    if hide then
        texprint(ctxcatcodes,format("\\dostarthiddenblock{%s}",name))
    else
        texprint(ctxcatcodes,format("\\dostartnormalblock{%s}",name))
    end
    if type(data) == "table" then
        for i=1,#data do
            texprint(data[i])
        end
    else
        lpegmatch(printer,data)
    end
    if hide then
        texprint(ctxcatcodes,"\\dostophiddenblock")
    else
        texprint(ctxcatcodes,"\\dostopnormalblock")
    end
end

function blocks.define(name)
    states[name] = { all = "hide" }
end

function blocks.setstate(state,name,tag)
    local all = tag == ""
    local tags = not all and aux.settings_to_array(tag)
    for n in gmatch(name,"%s*([^,]+)") do
        local sn = states[n]
        if not sn then
            -- error
        elseif all then
            sn.all = state
        else
            for _, tag in pairs(tags) do
                sn[tag] = state
            end
        end
    end
end

--~ filter_collected(names, criterium, number, collected)

function blocks.select(state,name,tag,criterium)
    criterium = criterium or "text"
    if find(tag,"=") then tag = "" end
    local names = aux.settings_to_set(name)
    local all = tag == ""
    local tags = not all and aux.settings_to_set(tag)
    local hide = state == "process"
    local n = structure.sections.number_at_depth(criterium)
    local result = structure.lists.filter_collected("all", criterium, n, collected)
    for i=1,#result do
        local ri = result[i]
        local metadata = ri.metadata
        if names[metadata.name] then
            if all then
                blocks.print(name,ri.data,hide)
            else
                local mtags = metadata.tags
                for tag, sta in pairs(tags) do
                    if mtags[tag] then
                        blocks.print(name,ri.data,hide)
                        break
                    end
                end
            end
        end
    end
end

function blocks.save(name,tag,buffer) -- wrong, not yet adapted
    local data = buffers.data[buffer]
    local tags = aux.settings_to_set(tag)
    local plus, minus = false, false
    if tags['+'] then plus  = true tags['+'] = nil end
    if tags['-'] then minus = true tags['-'] = nil end
    tobesaved[#tobesaved+1] = {
        metadata = {
            name = name,
            tags = tags,
            plus = plus,
            minus = minus,
        },
        references = {
            section  = structure.sections.currentid(),
        },
        data = data or "error",
    }
    local allstate = states[name].all
    if not next(tags) then
        if allstate ~= "hide" then
            blocks.print(name,data)
        elseif plus then
            blocks.print(name,data,true)
        end
    else
        local sn = states[name]
        for tag, _ in pairs(tags) do
            if sn[tag] == nil then
                if allstate ~= "hide" then
                    blocks.print(name,data)
                    break
                end
            elseif sn[tag] ~= "hide" then
                blocks.print(name,data)
                break
            end
        end
    end
    buffers.data[buffer] = nil
end

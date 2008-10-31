if not modules then modules = { } end modules ['core-blk'] = {
    version   = 1.001,
    comment   = "companion to core-blk.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- this one runs on top of buffers and structure

local texprint, format = tex.print, string.format

structure        = structure or { }
structure.blocks = structure.blocks or { }

local blocks = structure.blocks

blocks.collected = blocks.collected or { }
blocks.tobesaved = blocks.tobesaved or { }
blocks.states    = blocks.states    or { }

local tobesaved, collected, states = blocks.tobesaved, blocks.collected, blocks.states

local function initializer()
    tobesaved, collected, states = blocks.tobesaved, blocks.collected, blocks.states
end

-- not used, todo: option to do single or double pass

-- job.register('structure.blocks.collected', structure.blocks.tobesaved, initializer, nil)

local printer = (lpeg.linebyline/texprint)^0

function blocks.print(name,data,hide)
    if hide then
        texprint(tex.ctxcatcodes,format("\\dostarthiddenblock{%s}",name))
    else
        texprint(tex.ctxcatcodes,format("\\dostartnormalblock{%s}",name))
    end
    if type(data) == "table" then
        for i=1,#data do
            texprint(data[i])
        end
    else
        printer:match(data)
    end
    if hide then
        texprint(tex.ctxcatcodes,"\\dostophiddenblock")
    else
        texprint(tex.ctxcatcodes,"\\dostopnormalblock")
    end
end

function blocks.define(name)
    states[name] = { all = "hide" }
end

function blocks.setstate(state,name,tag)
    local all = tag == ""
    local tags = not all and aux.settings_to_array(tag)
    for n in name:gmatch("%s*([^,]+)") do
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

function blocks.select(state,name,tag,criterium)
    criterium = criterium or "text"
    if tag:find("=") then tag = "" end
    local names = aux.settings_to_set(name)
    local all = tag == ""
    local tags = not all and aux.settings_to_set(tag)
    local hide = state == "process"
    local n = structure.sections.number_at_depth(criterium)
    local result = structure.lists.filter_collected("all", criterium, n, tobesaved)
    for i=1,#result do
        local b = result[i].entry
        if names[b.name] then
            local btags = b.tags
            if all then
                blocks.print(name,b.data,hide)
            else
                for tag, sta in pairs(tags) do
                    if btags[tag] then
                        blocks.print(name,b.data,hide)
                        break
                    end
                end
            end
        end
    end
end

function blocks.save(name,tag,buffer)
    local data = buffers.data[buffer]
    local tags = aux.settings_to_set(tag)
    local plus, minus = false, false
    if tags['+'] then plus  = true tags['+'] = nil end
    if tags['-'] then minus = true tags['-'] = nil end
    local slt = structure.lists.tobesaved
    tobesaved[#tobesaved+1] = {
        entry = {
            name = name,
            tags = tags,
            data = data or "error",
            plus = plus,
            minus = minus,
        },
        sectionnumber = slt[#slt] and slt[#slt].sectionnumber
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

-- function sections.getnumber()
--     structure.sections.number(entry, { }, "sectionnumber", "sectionnumber")
-- end

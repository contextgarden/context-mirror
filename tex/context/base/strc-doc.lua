if not modules then modules = { } end modules ['strc-doc'] = {
    version   = 1.001,
    comment   = "companion to strc-doc.tex",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local next, type = next, type
local format, gsub, find, concat = string.format, string.gsub, string.find, table.concat
local texsprint, texwrite = tex.sprint, tex.write

local ctxcatcodes = tex.ctxcatcodes

if not trackers then trackers = { register = function() end } end

local trace_sectioning = false  trackers.register("structure.sectioning", function(v) trace_sectioning = v end)

local function report(...)
--~ print(...)
    logs.report("sectioning:",...)
end

structure            = structure            or { }
structure.helpers    = structure.helpers    or { }
structure.documents  = structure.documents  or { }
structure.sections   = structure.sections   or { }
structure.sets       = structure.sets       or { }
structure.processors = structure.processors or { }

local helpers    = structure.helpers
local documents  = structure.documents
local sections   = structure.sections
local sets       = structure.sets
local processors = structure.processors

-- -- -- document -- -- --

local data

function documents.initialize()
    data = {
        numbers = { },
        ownnumbers = { },
        status = { },
        checkers = { },
        depth = 0,
        blocks = { },
        block = "",
    }
    documents.data = data
end

function documents.reset()
    data.numbers = { }
    data.ownnumbers = { }
    data.status = { }
    data.checkers = { }
    data.depth = 0
end

documents.initialize()

-- -- -- sections -- -- --

jobsections           = jobsections or { }
jobsections.collected = jobsections.collected or { }
jobsections.tobesaved = jobsections.tobesaved or { }

local collected, tobesaved = jobsections.collected, jobsections.tobesaved

--~ local function initializer()
--~     collected, tobesaved = jobsections.collected, jobsections.tobesaved
--~ end

--~ job.register('jobsections.collected', jobsections.tobesaved, initializer)

function sections.currentid()
    return #tobesaved
end

function sections.save(sectiondata)
--  local sectionnumber = helpers.simplify(section.sectiondata) -- maybe done earlier
    local numberdata = sectiondata.numberdata
    if not numberdata or sectiondata.metadata.nolist then
        return #tobesaved
    else
        local n = #tobesaved + 1
        tobesaved[n] = numberdata
        if not collected[n] then
            collected[n] = numberdata
        end
        return n
    end
end

function sections.load()
    setmetatable(collected,nil)
    local l = structure.lists.collected
    for i=1,#l do
        local li = l[i]
        local lm = li.metadata
        if lm and lm.kind == "section" and not lm.nolist then
            local ln = li.numberdata
            if ln then
                collected[#collected+1] = ln
            end
        end
    end
    sections.load = nil
end

setmetatable(collected, {
    __index = function(t,i)
        sections.load()
        return t[i] or { }
    end
})

--

structure.sections.levelmap = structure.sections.levelmap or { }

local levelmap = structure.sections.levelmap

storage.register("structure/sections/levelmap", structure.sections.levelmap, "structure.sections.levelmap")

sections.verbose = true

function sections.setlevel(name,level) -- level can be number or parent (=string)
    local l = tonumber(level)
    if not l then
        l = levelmap[level]
    end
    if l and l > 0 then
        levelmap[name] = l
    else
        -- error
    end
end

function sections.getlevel(name)
    return levelmap[name] or 0
end

function sections.way(way,by)
    texsprint(ctxcatcodes,(gsub(way,"^"..by,"")))
end

function sections.setblock(name)
    local block = name or data.block or "unknown" -- can be used to set the default
    data.block = block
    texwrite(block)
end

function sections.pushblock(name)
    local block = name or data.block
    data.blocks[#data.blocks+1] = block
    data.block = block
    documents.reset()
    texwrite(block)
end

function sections.popblock()
    data.blocks[#data.blocks] = nil
    local block = data.blocks[#data.blocks] or data.block
    data.block = block
    documents.reset()
    texwrite(block)
end

function sections.currentblock()
    return data.block or data.blocks[#data.blocks] or "unknown"
end

function sections.currentlevel()
    return data.depth
end

function sections.getcurrentlevel()
    texwrite(data.depth)
end

function sections.nextlevel()
    local depth = data.depth + 1
    data.depth = depth
    return depth
end

function sections.prevlevel()
    local numbers, ownnumbers, status, depth = data.numbers, data.ownnumbers, data.status, data.depth
    local resetter = sets.getall("structure:resets",data.block,status[depth].resets or "")
    local rd = resetter and resetter[depth]
    numbers[depth] = (rd and rd > 0 and rd < depth and numbers[depth]) or 0
    status[depth] = nil
    depth = depth - 1
    data.depth = depth
    return depth
end

function sections.somelevel(t)
    local numbers, ownnumbers, status, depth = data.numbers, data.ownnumbers, data.status, data.depth
    local d = tonumber(levelmap[t.metadata.name] or (depth > 0 and depth) or 1)
    local resetter = sets.getall("structure:resets",data.block,(t and t.resets) or "")
    local previous = { }
    if d > depth then
        local rd = resetter and resetter[i]
        for i=depth+1,d do
            numbers[i] = (rd and rd[i] and rd[i] > 0 and rd[i] < i and numbers[i]) or 0
            status[i] = { }
        end
    elseif d < depth then
        local rd = resetter and resetter[i]
        for i=depth,d+1,-1 do
            numbers[i] = (rd and rd[i] and rd[i] > 0 and rd[i] < i and numbers[i]) or 0
            status[i] = nil
        end
    end
    for i=1,d do
     -- selective resetter
        if numbers[i] == 0 then
            ownnumbers[i] = ""
        end
    end
    -- a trick to permits userdata to overload title, ownnumber and reference
    -- normally these are passed as argument but nowadays we provide several
    -- interfaces (we need this because we want to be compatible)
    local u = t.userdata
    if u then
        if u.reference and u.reference ~= "" then t.metadata.reference   = u.reference ; u.reference = nil end
        if u.ownnumber and u.ownnumber ~= "" then t.numberdata.ownnumber = u.ownnumber ; u.ownnumber = nil end
        if u.title     and u.title     ~= "" then t.titledata.title      = u.title     ; u.title     = nil end
        if u.bookmark  and u.bookmark  ~= "" then t.titledata.bookmark   = u.bookmark  ; u.bookmark  = nil end
        if u.label     and u.label     ~= "" then t.titledata.label      = u.label     ; u.label     = nil end
    end
    -- so far for the trick
    ownnumbers[d] = t.numberdata.ownnumber or ""
    t.numberdata.ownnumber = nil
--  t.numberdata = helpers.simplify(t.numberdata)
    data.depth = d
    sections.pluslevel(t)
end

function sections.writestatus()
    if sections.verbose then
        local numbers, ownnumbers, status, depth = data.numbers, data.ownnumbers, data.status, data.depth
        local d = status[depth]
        local o = concat(ownnumbers,".",1,depth)
        local n = (numbers and concat(numbers,".",1,depth)) or 0
        local l = d.titledata.title or ""
        local t = (l ~= "" and l) or d.titledata.title or "[no title]"
        local m = d.metadata.name
        if o and not find(o,"^%.*$") then
            commands.writestatus("structure","%s @ level %i : (%s) %s -> %s",m,depth,n,o,t)
        elseif d.directives and d.directives.hidenumber then
            commands.writestatus("structure","%s @ level %i : (%s) -> %s",m,depth,n,t)
        else
            commands.writestatus("structure","%s @ level %i : %s -> %s",m,depth,n,t)
        end
    end
end

function sections.pluslevel(t)
    -- data has saved level data
    local numbers, ownnumbers, status, depth = data.numbers, data.ownnumbers, data.status, data.depth
    local directives = t.directives
    local resetter = sets.getall("structure:resets",data.block, (directives and directives.resetset) or "")
    if not (directives and directives.hidenumber) then
        if numbers[depth] then
            numbers[depth] = numbers[depth] + 1
        else
            numbers[depth] = 1
        end
    end
    for k, v in pairs(resetter) do -- sparse
        if v > 0 and depth == v then
            numbers[k] = 0
        end
    end
    status[depth] = t or { }
    for k, v in pairs(data.checkers) do
        if v[1] == depth and v[2] then
            v[2](k)
        end
    end
    local numberdata= t.numberdata
    if not numberdata then
        -- probably simplified to nothing
        numberdata = { }
        t.numberdata = numberdata
    end
    numberdata.numbers = table.fastcopy(numbers)
    if #ownnumbers > 0 then
        numberdata.ownnumbers = table.fastcopy(ownnumbers)
    end
    t.references.section = sections.save(t)
--~     t.numberdata = nil
end

function sections.setnumber(depth,n)
    local numbers, depth = data.numbers, data.depth
    local d = numbers[depth]
    if type(n) == "string" then
        if n:find("^[%+%-]") then
            d = d + tonumber(n)
        else
            d = tonumber(n)
        end
    else
        d = n
    end
    numbers[depth] = d
    -- todo reset
end

function sections.number_at_depth(depth)
    return data.numbers[tonumber(depth) or sections.getlevel(depth) or 0] or 0
end

function sections.getnumber(depth)
    return texwrite(data.numbers[depth] or 0)
end

function sections.set(key,value)
    data.status[data.depth][key] = value -- may be nil for a reset
end

function sections.cct()
    local metadata = data.status[data.depth].metadata
    texsprint((metadata and metadata.catcodes) or ctxcatcodes)
end

function sections.get(key,default,honorcatcodetable)
    local data = data.status[data.depth]
    local d = data
    for k in key:gmatch("([^.]+)") do
        if type(d) == "table" then
            d = d[k]
            if not d then
                -- unknown key
                break
            end
        end
        if type(d) == "string" then
            if honorcatcodetable then
                local metadata = data.metadata
                texsprint((metadata and metadata.catcodes) or ctxcatcodes,d)
            else
                texsprint(ctxcatcodes,d)
            end
            return
        end
    end
    if default then
        texsprint(ctxcatcodes,default)
    end
end

function sections.getuser(key,default)
    local userdata = data.status[data.depth].userdata
    local str = (userdata and userdata[key]) or default
    if str then
        texsprint(ctxcatcodes,str)
    end
end

function sections.setchecker(name,level,command)
    data.checkers[name] = (name and command and level > 0 and { level, command }) or nil
end

function sections.current()
    return data.status[data.depth]
end

function sections.depthnumber(n)
    local depth = data.depth
    if not n or n == 0 then
        n = depth
    elseif n < 0 then
        n = depth + n
    end
    return texwrite(data.numbers[n] or 0)
end

function sections.autodepth(numbers)
    for i=#numbers,1,-1 do
        if numbers[i] ~= 0 then
            return i
        end
    end
    return 0
end

--

function structure.currentsectionnumber() -- brr, namespace wrong
    local sc = sections.current()
    return sc and sc.numberdata
end

-- \dorecurse{3} {
--     \chapter{Blabla}                 \subsection{bla 1 1} \subsection{bla 1 2}
--                      \section{bla 2} \subsection{bla 2 1} \subsection{bla 2 2}
-- }

function sections.typesetnumber(entry,kind,...) -- kind='section','number','prefix'
    if entry then
        local separatorset  = ""
        local conversionset = ""
        local conversion    = ""
        local stopper       = ""
        local connector     = ""
        local set           = ""
        local segments      = ""
        for _, data in ipairs { ... } do
            if data then
                if separatorset  == "" then separatorset  = data.separatorset  or "" end
                if conversionset == "" then conversionset = data.conversionset or "" end
                if conversion    == "" then conversion    = data.conversion    or "" end
                if stopper       == "" then stopper       = data.stopper       or "" end
                if connector     == "" then connector     = data.connector     or "" end
                if set           == "" then set           = data.set           or "" end
                if segments      == "" then segments      = data.segments      or "" end
            end
        end
        if separatorset  == "" then separatorset  = "default" end
        if conversionset == "" then conversionset = "default" end
        if conversion    == "" then conversion    = nil       end
        if stopper       == "" then stopper       = nil       end
        if connector     == "" then connector     = nil       end
        if set           == "" then set           = "default" end
        if segments      == "" then segments      = nil       end
        --
        local firstprefix, lastprefix = 0, 100
        if segments then
            local f, l = (tostring(segments)):match("^(.-):(.+)$")
            if f and l then
                -- 0:100, chapter:subsubsection
                firstprefix = tonumber(f) or sections.getlevel(f) or 0
                lastprefix = tonumber(l) or sections.getlevel(l) or 100
            else
                -- 3, section
                local fl = tonumber(segments) or sections.getlevel(segments) -- generalize
                if fl then
                    firstprefix, lastprefix = fl, fl
                end
            end
        end
        --
        local numbers, ownnumbers = entry.numbers, entry.ownnumbers
        if numbers then
            local done, preceding = false, false
            local function process(index) -- move to outer
                local number = numbers and (numbers[index] or 0)
                local ownnumber = ownnumbers and ownnumbers[index] or ""
                if number > 0 or (ownnumber ~= "") then
                    local block = entry.block
                    if preceding then
                        local separator = sets.get("structure:separators",b,s,preceding,".")
                        if separator then
                            processors.sprint(ctxcatcodes,separator)
                        end
                        preceding = false
                    end
                    if ownnumber ~= "" then
                        processors.sprint(ctxcatcodes,ownnumber)
                 -- elseif conversion and conversion ~= "" then
                 --    texsprint(ctxcatcodes,format("\\convertnumber{%s}{%s}",conversion,number))
                    elseif conversion and conversion ~= "" then
                     -- traditional (e.g. used in itemgroups)
                        texsprint(ctxcatcodes,format("\\convertnumber{%s}{%s}",conversion,number))
                    else
                        local theconversion = sets.get("structure:conversions",block,conversion,index,"numbers")
                        processors.sprint(ctxcatcodes,theconversion,function(str)
                            return format("\\convertnumber{%s}{%s}",str or "numbers",number)
                        end)
                    end
                    preceding, done = index, true
                else
                    preceding = preceding or false
                end
            end
            --
            local prefixlist = set and sets.getall("structure:prefixes","",set) -- "" == block
            --
            if prefixlist and (kind == 'section' or kind == 'prefix') then
                -- find valid set (problem: for sectionnumber we should pass the level)
            --  if kind == "section" then
                    -- no holes
                    local b, e, bb, ee = 1, #prefixlist, 0, 0
                    -- find last valid number
                    for k=e,b,-1 do
                        local prefix = prefixlist[k]
                        local index = sections.getlevel(prefix) or k
                        if index >= firstprefix and index <= lastprefix then
                            local number = numbers and numbers[index]
                            if number then
                                local ownnumber = ownnumbers and ownnumbers[index] or ""
                                if number > 0 or (ownnumber ~= "") then
                                    break
                                else
                                    e = k -1
                                end
                            end
                        end
                    end
                    -- find valid range
                    for k=b,e do
                        local prefix = prefixlist[k]
                        local index = sections.getlevel(prefix) or k
                        if index >= firstprefix and index <= lastprefix then
                            local number = numbers and numbers[index]
                            if number then
                                local ownnumber = ownnumbers and ownnumbers[index] or ""
                                if number > 0 or (ownnumber ~= "") then
                                    if bb == 0 then bb = k end
                                    ee = k
                                else
                                    bb, ee = 0, 0
                                end
                            else
                                break
                            end
                        end
                    end
                    -- print valid range
                    for k=bb,ee do
                        local prefix = prefixlist[k]
                        local index = sections.getlevel(prefix) or k
                        if index >= firstprefix and index <= lastprefix then
                            process(index)
                        end
                    end
            --  else
            --      for k=1,#prefixlist do
            --          local prefix = prefixlist[k]
            --          local index = sections.getlevel(prefix) or k
            --          if index >= firstprefix and index <= lastprefix then
            --              process(index)
            --          end
            --      end
            --  end
            else
                -- also holes check
                for prefix=firstprefix,lastprefix do
                    process(prefix)
                end
            end
            --
            if done and connector and kind == 'prefix' then
                processors.sprint(ctxcatcodes,connector)
            elseif done and stopper then
                processors.sprint(ctxcatcodes,stopper)
            end
        else
            report("error: no numbers")
        end
    end
end

function sections.fullnumber(depth)
    local data = data.status[depth or data.depth]
    if data then
        local sectiondata = jobsections.collected[data.references.section]
        if sectiondata then
            sections.typesetnumber(sectiondata,'section',sectiondata)
        end
    end
end

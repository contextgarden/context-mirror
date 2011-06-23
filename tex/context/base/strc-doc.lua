if not modules then modules = { } end modules ['strc-doc'] = {
    version   = 1.001,
    comment   = "companion to strc-doc.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- todo: associate counter with head

-- we need to freeze and document this module

local next, type = next, type
local format, gsub, find, concat, gmatch, match = string.format, string.gsub, string.find, table.concat, string.gmatch, string.match
local texsprint, texwrite = tex.sprint, tex.write
local concat = table.concat
local max, min = math.max, math.min
local allocate, mark = utilities.storage.allocate, utilities.storage.mark

local ctxcatcodes = tex.ctxcatcodes
local variables   = interfaces.variables

--~ if not trackers then trackers = { register = function() end } end

local trace_sectioning = false  trackers.register("structures.sectioning", function(v) trace_sectioning = v end)
local trace_detail     = false  trackers.register("structures.detail",     function(v) trace_detail     = v end)

local report_structure = logs.reporter("structure","sectioning")

local structures, context = structures, context

local helpers    = structures.helpers
local documents  = structures.documents
local sections   = structures.sections
local lists      = structures.lists
local counters   = structures.counters
local sets       = structures.sets
local tags       = structures.tags
local processors = structures.processors

local sprintprocessor = processors.sprint
local ignoreprocessor = processors.ignore

local a_internal      = attributes.private('internal')

-- -- -- document -- -- --

local data

function documents.initialize()
    data = {
        numbers    = { },
        forced     = { },
        ownnumbers = { },
        status     = { },
        checkers   = { },
        depth      = 0,
        blocks     = { },
        block      = "",
    }
    documents.data = data
end

function documents.reset()
    data.numbers    = { }
    data.forced     = { }
    data.ownnumbers = { }
    data.status     = { }
 -- data.checkers   = { }
    data.depth      = 0
end

documents.initialize()

-- -- -- sections -- -- --

local collected  = allocate()
local tobesaved  = allocate()

sections.collected  = collected
sections.tobesaved  = tobesaved

--~ local function initializer()
--~     collected = sections.collected
--~     tobesaved = sections.tobesaved
--~ end

--~ job.register('structures.sections.collected', tobesaved, initializer)

sections.registered = sections.registered or allocate()
local registered    = sections.registered

storage.register("structures/sections/registered", registered, "structures.sections.registered")

function sections.register(name,specification)
    registered[name] = specification
end

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
    local l = lists.collected
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

sections.levelmap = sections.levelmap or { }

local levelmap = sections.levelmap

storage.register("structures/sections/levelmap", sections.levelmap, "structures.sections.levelmap")

sections.verbose = true

levelmap.block = -1

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
    context((gsub(way,"^"..by,"")))
end

function sections.setblock(name)
    local block = name or data.block or "unknown" -- can be used to set the default
    data.block = block
    texwrite(block)
end

function sections.pushblock(name)
    counters.check(0) -- we assume sane usage of \page between blocks
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

function sections.somelevel(given)
    -- old number
    local numbers, ownnumbers, forced, status, olddepth = data.numbers, data.ownnumbers, data.forced, data.status, data.depth
    local givenname = given.metadata.name
    local mappedlevel = levelmap[givenname]
    local newdepth = tonumber(mappedlevel or (olddepth > 0 and olddepth) or 1) -- hm, levelmap only works for section-*
    local directives = given.directives
    local resetset = (directives and directives.resetset) or ""
 -- local resetter = sets.getall("structure:resets",data.block,resetset)
    -- a trick to permits userdata to overload title, ownnumber and reference
    -- normally these are passed as argument but nowadays we provide several
    -- interfaces (we need this because we want to be compatible)
    if trace_detail then
        report_structure("name '%s', mapped level '%s', old depth '%s', new depth '%s', reset set '%s'",givenname,mappedlevel,olddepth,newdepth,resetset)
    end
    local u = given.userdata
    if u then
        -- kind of obsolete as we can pass them directly anyway
        if u.reference and u.reference ~= "" then given.metadata.reference   = u.reference ; u.reference = nil end
        if u.ownnumber and u.ownnumber ~= "" then given.numberdata.ownnumber = u.ownnumber ; u.ownnumber = nil end
        if u.title     and u.title     ~= "" then given.titledata.title      = u.title     ; u.title     = nil end
        if u.bookmark  and u.bookmark  ~= "" then given.titledata.bookmark   = u.bookmark  ; u.bookmark  = nil end
        if u.label     and u.label     ~= "" then given.titledata.label      = u.label     ; u.label     = nil end
    end
    -- so far for the trick
    if newdepth > olddepth then
        for i=olddepth+1,newdepth do
            local s = tonumber(sets.get("structure:resets",data.block,resetset,i))
            if trace_detail then
                report_structure("new>old (%s>%s), reset set '%s', reset value '%s', current '%s'",olddepth,newdepth,resetset,s or "?",numbers[i] or "?")
            end
            if not s or s == 0 then
                numbers[i] = numbers[i] or 0
                ownnumbers[i] = ownnumbers[i] or ""
            else
                numbers[i] = s - 1
                ownnumbers[i] = ""
            end
            status[i] = { }
        end
    elseif newdepth < olddepth then
        for i=olddepth,newdepth+1,-1 do
            local s = tonumber(sets.get("structure:resets",data.block,resetset,i))
            if trace_detail then
                report_structure("new<old (%s<%s), reset set '%s', reset value '%s', current '%s'",olddepth,newdepth,resetset,s or "?",numbers[i] or "?")
            end
            if not s or s == 0 then
                numbers[i] = numbers[i] or 0
                ownnumbers[i] = ownnumbers[i] or ""
            else
                numbers[i] = s - 1
                ownnumbers[i] = ""
            end
            status[i] = nil
        end
    end
    counters.check(newdepth)
    ownnumbers[newdepth] = given.numberdata.ownnumber or ""
    given.numberdata.ownnumber = nil
    data.depth = newdepth
    -- new number
    olddepth = newdepth
    if given.metadata.increment then
        local oldn, newn = numbers[newdepth] or 0, 0
        local fd = forced[newdepth]
        if fd then
            if fd[1] == "add" then
                newn = oldn + fd[2] + 1
            else
                newn = fd[2] + 1
            end
            if newn < 0 then
                newn = 1 -- maybe zero is nicer
            end
            forced[newdepth] = nil
            if trace_detail then
                report_structure("old depth '%s', new depth '%s, old n '%s', new n '%s', forced '%s'",olddepth,newdepth,oldn,newn,concat(fd,""))
            end
        elseif newn then
            newn = oldn + 1
            if trace_detail then
                report_structure("old depth '%s', new depth '%s, old n '%s', new n '%s', increment",olddepth,newdepth,oldn,newn)
            end
        else
            local s = tonumber(sets.get("structure:resets",data.block,resetset,newdepth))
            if not s then
                newn = oldn or 0
            elseif s == 0 then
                newn = oldn or 0
            else
                newn = s - 1
            end
            if trace_detail then
                report_structure("old depth '%s', new depth '%s, old n '%s', new n '%s', reset",olddepth,newdepth,oldn,newn)
            end
        end
        numbers[newdepth] = newn
    end
    status[newdepth] = given or { }
    for k, v in next, data.checkers do
        if v[1] == newdepth and v[2] then
            v[2](k)
        end
    end
    local numberdata= given.numberdata
    if not numberdata then
        -- probably simplified to nothing
        numberdata = { }
        given.numberdata = numberdata
    end
    local n = { }
    for i=1,newdepth do
        n[i] = numbers[i]
    end
    numberdata.numbers = n
    if #ownnumbers > 0 then
        numberdata.ownnumbers = table.fastcopy(ownnumbers)
    end
    if trace_detail then
        report_structure("name '%s', numbers '%s', own numbers '%s'",givenname,concat(numberdata.numbers, " "),concat(numberdata.ownnumbers, " "))
    end

    local metadata   = given.metadata
    local references = given.references

    references.tag = references.tag or tags.getid(metadata.kind,metadata.name)

    references.section = sections.save(given)
 -- given.numberdata = nil
end

function sections.reportstructure()
    if sections.verbose then
        local numbers, ownnumbers, status, depth = data.numbers, data.ownnumbers, data.status, data.depth
        local d = status[depth]
        local o = concat(ownnumbers,".",1,depth)
        local n = (numbers and concat(numbers,".",1,min(depth,#numbers))) or 0
        local l = d.titledata.title or ""
        local t = (l ~= "" and l) or d.titledata.title or "[no title]"
        local m = d.metadata.name
        if o and not find(o,"^%.*$") then
            report_structure("%s @ level %i : (%s) %s -> %s",m,depth,n,o,t)
        elseif d.directives and d.directives.hidenumber then
            report_structure("%s @ level %i : (%s) -> %s",m,depth,n,t)
        else
            report_structure("%s @ level %i : %s -> %s",m,depth,n,t)
        end
    end
end

function sections.setnumber(depth,n)
    local forced, depth, new = data.forced, depth or data.depth, tonumber(n)
    if type(n) == "string" then
        if find(n,"^[%+%-]") then
            forced[depth] = { "add", new }
        else
            forced[depth] = { "set", new }
        end
    else
        forced[depth] = { "set", new }
    end
end

function sections.numberatdepth(depth)
    return data.numbers[tonumber(depth) or sections.getlevel(depth) or 0] or 0
end

function sections.numbers()
    return data.numbers
end

function sections.matchingtilldepth(depth,numbers,parentnumbers)
    local dn = parentnumbers or data.numbers
    local ok = false
    for i=1,depth do
        if dn[i] == numbers[i] then
            ok = true
        else
            return false
        end
    end
    return ok
end

function sections.getnumber(depth) -- redefined later ...
    texwrite(data.numbers[depth] or 0)
end

function sections.set(key,value)
    data.status[data.depth][key] = value -- may be nil for a reset
end

function sections.cct()
    local metadata = data.status[data.depth].metadata
    context(metadata and metadata.catcodes or ctxcatcodes)
end

function sections.structuredata(depth,key,default,honorcatcodetable) -- todo: spec table and then also depth
    if not depth or depth == 0 then depth = data.depth end
    local data = data.status[depth]
    local d = data
    for k in gmatch(key,"([^.]+)") do
        if type(d) == "table" then
            d = d[k]
            if not d then
                -- unknown key
                break
            end
        end
        if type(d) == "string" then
            if honorcatcodetable == true or honorcatcodetable == variables.auto then
                local metadata = data.metadata
                texsprint((metadata and metadata.catcodes) or ctxcatcodes,d)
            elseif not honorcatcodetable then
                context(d)
            elseif type(honorcatcodetable) == "number" then
                texsprint(honorcatcodetable,d)
            elseif type(honorcatcodetable) == "string" and honorcatcodetable ~= "" then
                honorcatcodetable = tex[honorcatcodetable] or ctxcatcodes-- we should move ctxcatcodes to another table, ctx or so
                texsprint(honorcatcodetable,d)
            else
                context(d)
            end
            return
        end
    end
    if default then
        context(default)
    end
end

function sections.userdata(depth,key,default)
    if not depth or depth == 0 then depth = data.depth end
    if depth > 0 then
        local userdata = data.status[depth]
        userdata = userdata and userdata.userdata
        userdata = (userdata and userdata[key]) or default
        if userdata then
            context(userdata)
        end
    end
end

function sections.setchecker(name,level,command) -- hm, checkers are not saved
    data.checkers[name] = (name and command and level >= 0 and { level, command }) or nil
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

function structures.currentsectionnumber() -- brr, namespace wrong
    local sc = sections.current()
    return sc and sc.numberdata
end

-- \dorecurse{3} {
--     \chapter{Blabla}                 \subsection{bla 1 1} \subsection{bla 1 2}
--                      \section{bla 2} \subsection{bla 2 1} \subsection{bla 2 2}
-- }

-- sign=all      => also zero and negative
-- sign=positive => also zero
-- sign=hang     => llap sign

--~ todo: test this
--~

local function process(index,numbers,ownnumbers,criterium,separatorset,conversion,conversionset,index,entry,result,preceding,done)
    -- todo: too much (100 steps)
    local number = numbers and (numbers[index] or 0)
    local ownnumber = ownnumbers and ownnumbers[index] or ""
    if number > criterium or (ownnumber ~= "") then
        local block = (entry.block ~= "" and entry.block) or sections.currentblock() -- added
        if preceding then
            local separator = sets.get("structure:separators",block,separatorset,preceding,".")
            if separator then
                if result then
                    result[#result+1] = ignoreprocessor(separator)
                else
                    sprintprocessor(ctxcatcodes,separator)
                end
            end
            preceding = false
        end
        if result then
            if ownnumber ~= "" then
                result[#result+1] = ownnumber
            elseif conversion and conversion ~= "" then -- traditional (e.g. used in itemgroups) .. inherited!
                result[#result+1] = converters.convert(conversion,number)
            else
                local theconversion = sets.get("structure:conversions",block,conversionset,index,"numbers")
                result[#result+1] = converters.convert(theconversion,number)
            end
        else
            if ownnumber ~= "" then
                sprintprocessor(ctxcatcodes,ownnumber)
            elseif conversion and conversion ~= "" then -- traditional (e.g. used in itemgroups)
                context.convertnumber(conversion,number)
            else
                local theconversion = sets.get("structure:conversions",block,conversionset,index,"numbers")
                sprintprocessor(ctxcatcodes,theconversion,function(str)
                    return format("\\convertnumber{%s}{%s}",str or "numbers",number)
                end)
            end
        end
        return index, true
    else
        return preceding or false, done
    end
end

function sections.typesetnumber(entry,kind,...) -- kind='section','number','prefix'
    if entry and entry.hidenumber ~= true then -- can be nil
        local separatorset  = ""
        local conversionset = ""
        local conversion    = ""
        local stopper       = ""
        local starter       = ""
        local connector     = ""
        local set           = ""
        local segments      = ""
        local criterium     = ""
        local dataset = { ... }
        for d=1,#dataset do
            local data = dataset[d] -- can be multiple parametersets
            if data then
                if separatorset  == "" then separatorset  = data.separatorset  or "" end
                if conversionset == "" then conversionset = data.conversionset or "" end
                if conversion    == "" then conversion    = data.conversion    or "" end
                if stopper       == "" then stopper       = data.stopper       or "" end
                if starter       == "" then starter       = data.starter       or "" end
                if connector     == "" then connector     = data.connector     or "" end
                if set           == "" then set           = data.set           or "" end
                if segments      == "" then segments      = data.segments      or "" end
                if criterium     == "" then criterium     = data.criterium     or "" end
            end
        end
        if separatorset  == "" then separatorset  = "default"  end
        if conversionset == "" then conversionset = "default"  end -- not used
        if conversion    == "" then conversion    = nil        end
        if stopper       == "" then stopper       = nil        end
        if starter       == "" then starter       = nil        end
        if connector     == "" then connector     = nil        end
        if set           == "" then set           = "default"  end
        if segments      == "" then segments      = nil        end
        --
        if criterium == variables.strict then
            criterium = 0
        elseif criterium == variables.positive then
            criterium = -1
        elseif criterium == variables.all then
            criterium = -1000000
        else
            criterium = 0
        end
        --
        local firstprefix, lastprefix = 0, 16
        if segments then
            local f, l = match(tostring(segments),"^(.-):(.+)$")
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
            --
            local result = kind == "direct" and { }
            if result then
                connector = false
            end
            --
            local prefixlist = set and sets.getall("structure:prefixes","",set) -- "" == block
            if starter then
                if result then
                    result[#result+1] = ignoreprocessor(starter)
                else
                    sprintprocessor(ctxcatcodes,starter)
                end
            end
            if prefixlist and (kind == 'section' or kind == 'prefix' or kind == 'direct') then
                -- find valid set (problem: for sectionnumber we should pass the level)
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
                     -- process(index,result)
                        preceding, done = process(index,numbers,ownnumbers,criterium,separatorset,conversion,conversionset,index,entry,result,preceding,done)
                    end
                end
            else
                -- also holes check
                for index=firstprefix,lastprefix do
                 -- process(index,result)
                    preceding, done = process(index,numbers,ownnumbers,criterium,separatorset,conversion,conversionset,index,entry,result,preceding,done)
                end
            end
            --
            if done and connector and kind == 'prefix' then
                if result then
                    -- can't happen as we're in 'direct'
                else
                    sprintprocessor(ctxcatcodes,connector)
                end
            elseif done and stopper then
                if result then
                    result[#result+1] = ignoreprocessor(stopper)
                else
                    sprintprocessor(ctxcatcodes,stopper)
                end
            end
            return result -- a table !
        else
        --  report_structure("error: no numbers")
        end
    end
end

function sections.title()
    local sc = sections.current()
    if sc then
        helpers.title(sc.titledata.title,sc.metadata)
    end
end

function sections.findnumber(depth,what) -- needs checking (looks wrong and slow too)
    local data = data.status[depth or data.depth]
    if data then
        local index = data.references.section
        local collected = sections.collected
        local sectiondata = collected[index]
        if sectiondata and sectiondata.hidenumber ~= true then -- can be nil
            local quit = what == variables.previous or what == variables.next
            if what == variables.first or what == variables.previous then
                for i=index,1,-1 do
                    local s = collected[i]
                    local n = s.numbers
                    if #n == depth and n[depth] and n[depth] ~= 0 then
                        sectiondata = s
                        if quit then
                            break
                        end
                    elseif #n < depth then
                        break
                    end
                end
            elseif what == variables.last or what == variables.next then
                for i=index,#collected do
                    local s = collected[i]
                    local n = s.numbers
                    if #n == depth and n[depth] and n[depth] ~= 0 then
                        sectiondata = s
                        if quit then
                            break
                        end
                    elseif #n < depth then
                        break
                    end
                end
            end
            return sectiondata
        end
    end
end

function sections.finddata(depth,what)
    local data = data.status[depth or data.depth]
    if data then
        -- if sectiondata and sectiondata.hidenumber ~= true then -- can be nil
        local index = data.references.listindex
        if index then
            local collected = structures.lists.collected
            local quit = what == variables.previous or what == variables.next
            if what == variables.first or what == variables.previous then
                for i=index-1,1,-1 do
                    local s = collected[i]
                    if not s then
                        break
                    elseif s.metadata.kind == "section" then -- maybe check on name
                        local n = s.numberdata.numbers
                        if #n == depth and n[depth] and n[depth] ~= 0 then
                            data = s
                            if quit then
                                break
                            end
                        elseif #n < depth then
                            break
                        end
                    end
                end
            elseif what == variables.last or what == variables.next then
                for i=index+1,#collected do
                    local s = collected[i]
                    if not s then
                        break
                    elseif s.metadata.kind == "section" then -- maybe check on name
                        local n = s.numberdata.numbers
                        if #n == depth and n[depth] and n[depth] ~= 0 then
                            data = s
                            if quit then
                                break
                            end
                        elseif #n < depth then
                            break
                        end
                    end
                end
            end
        end
        return data
    end
end

function sections.internalreference(sectionname,what) -- to be used in pagebuilder (no marks used)
    local r = type(sectionname) == "number" and sectionname or registered[sectionname]
    if r then
        local data = sections.finddata(r.level,what)
        return data and data.references and data.references.internal
    end
end

function sections.fullnumber(depth,what)
    local sectiondata = sections.findnumber(depth,what)
    if sectiondata then
        sections.typesetnumber(sectiondata,'section',sectiondata)
    end
end

function sections.getnumber(depth,what) -- redefined here
    local sectiondata = sections.findnumber(depth,what)
    texwrite((sectiondata and sectiondata.numbers[depth]) or 0)
end

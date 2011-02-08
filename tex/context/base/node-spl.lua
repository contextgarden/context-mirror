if not modules then modules = { } end modules ['node-spl'] = {
    version   = 1.001,
    comment   = "companion to node-spl.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- This module is dedicated to the oriental tex project and for
-- the moment is too experimental to be publicly supported.
--
-- We could cache solutions: say that we store the featureset and
-- all 'words' -> replacement ... so we create a large solution
-- database (per font)
--
-- This module can be optimized by using a dedicated dynamics handler
-- but I'll only do that when the rest of the code is stable.
--
-- Todo: bind setups to paragraph.

local gmatch, concat, format, remove = string.gmatch, table.concat, string.format, table.remove
local next, tostring, tonumber = next, tostring, tonumber
local utfchar = utf.char
local random = math.random
local variables = interfaces.variables
local settings_to_array, settings_to_hash = utilities.parsers.settings_to_array, utilities.parsers.settings_to_hash
local fcs = fonts.colors.set

local trace_split    = false  trackers.register("builders.paragraphs.solutions.splitters.splitter",  function(v) trace_split    = v end)
local trace_optimize = false  trackers.register("builders.paragraphs.solutions.splitters.optimizer", function(v) trace_optimize = v end)
local trace_colors   = false  trackers.register("builders.paragraphs.solutions.splitters.colors",    function(v) trace_colors   = v end)
local trace_goodies  = false  trackers.register("fonts.goodies",                                     function(v) trace_goodies  = v end)

local report_solutions  = logs.reporter("fonts","solutions")
local report_splitters  = logs.reporter("nodes","splitters")
local report_optimizers = logs.reporter("nodes","optimizers")

local nodes, node = nodes, node

local find_node_tail     = node.tail or node.slide
local free_node          = node.free
local free_nodelist      = node.flush_list
local has_attribute      = node.has_attribute
local set_attribute      = node.set_attribute
local new_node           = node.new
local copy_node          = node.copy
local copy_nodelist      = node.copy_list
local traverse_nodes     = node.traverse
local traverse_ids       = node.traverse_id
local protect_glyphs     = nodes.handlers.protectglyphs or node.protect_glyphs
local hpack_nodes        = node.hpack
local insert_node_before = node.insert_before
local insert_node_after  = node.insert_after
local repack_hlist       = nodes.repack_hlist

local nodecodes          = nodes.nodecodes
local whatsitcodes       = nodes.whatsitcodes

local glyph_code         = nodecodes.glyph
local disc_code          = nodecodes.disc
local hlist_code         = nodecodes.hlist
local whatsit_code       = nodecodes.whatsit

local localpar_code      = whatsitcodes.localpar
local dir_code           = whatsitcodes.dir
local userdefined_code   = whatsitcodes.userdefined

local nodepool           = nodes.pool
local tasks              = nodes.tasks

local new_textdir        = nodepool.textdir
local new_usernumber     = nodepool.usernumber

local starttiming        = statistics.starttiming
local stoptiming         = statistics.stoptiming
local process_characters = nodes.handlers.characters
local inject_kerns       = nodes.injections.handler
local fontdata           = fonts.identifiers

local parbuilders               = builders.paragraphs
parbuilders.solutions           = parbuilders.solutions           or { }
parbuilders.solutions.splitters = parbuilders.solutions.splitters or { }

local splitters = parbuilders.solutions.splitters

local preroll    = true
local variant    = "normal"
local split      = attributes.private('splitter')
local cache      = { }
local solutions  = { } -- attribute sets
local variants   = { }
local max_less   = 0
local max_more   = 0
local criterium  = 0
local randomseed = nil
local optimize   = nil -- set later

function splitters.setup(setups)
    local method = settings_to_hash(setups.method or "")
    if method[variables.preroll] then
        preroll = true
    else
        preroll = false
    end
    for k, v in next, method do
        if variants[k] then
            optimize = variants[k]
        end
    end
    randomseed = tonumber(setups.randomseed)
    criterium = tonumber(setups.criterium) or criterium
end

local contextsetups = fonts.definers.specifiers.contextsetups

local function convert(featuresets,name,set,what)
    local list, numbers, nofnumbers = set[what], { }, 0
    if list then
        for i=1,#list do
            local feature = list[i]
            local fs = featuresets[feature]
            local fn = fs and fs.number
            if not fn then
                -- fall back on global features
                fs = contextsetups[feature]
                fn = fs and fs.number
            end
            if fn then
                nofnumbers = nofnumbers + 1
                numbers[nofnumbers] = fn
                if trace_goodies or trace_optimize then
                    report_solutions("solution %s of '%s' uses feature '%s' with number %s",i,name,feature,fn)
                end
            else
                report_solutions("solution %s has an invalid feature reference '%s'",i,name,tostring(feature))
            end
        end
        return nofnumbers > 0 and numbers
    end
end

local function initialize(goodies)
    local solutions = goodies.solutions
    if solutions then
        local featuresets = goodies.featuresets
        local goodiesname = goodies.name
        if trace_goodies or trace_optimize then
            report_solutions("checking solutions in '%s'",goodiesname)
        end
        for name, set in next, solutions do
            set.less = convert(featuresets,name,set,"less")
            set.more = convert(featuresets,name,set,"more")
        end
    end
end

fonts.goodies.register("solutions",initialize)

function splitters.define(name,parameters)
    local settings = settings_to_hash(parameters) -- todo: interfacing
    local goodies, solution, less, more = settings.goodies, settings.solution, settings.less, settings.more
    local less_set, more_set
    local l = less and settings_to_array(less)
    local m = more and settings_to_array(more)
    if goodies then
        goodies = fonts.goodies.get(goodies) -- also in tfmdata
        if goodies then
            local featuresets = goodies.featuresets
            local solution = solution and goodies.solutions[solution]
            if l and #l > 0 then
                less_set = convert(featuresets,name,settings,"less") -- take from settings
            else
                less_set = solution and solution.less -- take from goodies
            end
            if m and #m > 0 then
                more_set = convert(featuresets,name,settings,"more") -- take from settings
            else
                more_set = solution and solution.more -- take from goodies
            end
        end
    else
        if l then
            local n = #less_set
            for i=1,#l do
                local ss = contextsetups[l[i]]
                if ss then
                    n = n + 1
                    less_set[n] = ss.number
                end
            end
        end
        if m then
            local n = #more_set
            for i=1,#m do
                local ss = contextsetups[m[i]]
                if ss then
                    n = n + 1
                    more_set[n] = ss.number
                end
            end
        end
    end
    if trace_optimize then
        report_solutions("defining solutions '%s', less: '%s', more: '%s'",name,concat(less_set or {}," "),concat(more_set or {}," "))
    end
    local nofsolutions = #solutions + 1
    solutions[nofsolutions] = {
        solution  = solution,
        less      = less_set or { },
        more      = more_set or { },
        settings  = settings, -- for tracing
    }
    tex.write(nofsolutions)
end

local nofwords, noftries, nofadapted, nofkept, nofparagraphs = 0, 0, 0, 0, 0

function splitters.split(head)
    -- quite fast
    local current, done, rlmode, start, stop, attribute = head, false, false, nil, nil, 0
    cache, max_less, max_more = { }, 0, 0
    local function flush() -- we can move this
        local font = start.font
        local last = stop.next
        local list = last and copy_nodelist(start,last) or copy_nodelist(start)
        local n = #cache + 1
        local user_one = new_usernumber(1,n)
        local user_two = new_usernumber(2,n)
        head, start = insert_node_before(head,start,user_one)
        insert_node_after(head,stop,user_two)
        if rlmode == "TRT" or rlmode == "+TRT" then
            local dirnode = new_textdir("+TRT")
            list.prev = dirnode
            dirnode.next = list
            list = dirnode
        end
        local c = {
            original  = list,
            attribute = attribute,
            direction = rlmode,
            font      = font
        }
        if trace_split then
            report_splitters("cached %4i: font: %s, attribute: %s, word: %s, direction: %s", n,
                font, attribute, nodes.listtoutf(list,true), rlmode)
        end
        cache[n] = c
        local solution = solutions[attribute]
        local l, m = #solution.less, #solution.more
        if l > max_less then max_less = l end
        if m > max_more then max_more = m end
        start, stop, done = nil, nil, true
    end
    while current do
        local id = current.id
        if id == glyph_code and current.subtype < 256 then
            local a = has_attribute(current,split)
            if not a then
                start, stop = nil, nil
            elseif not start then
                start, stop, attribute = current, current, a
            elseif a ~= attribute then
                start, stop = nil, nil
            else
                stop = current
            end
            current = current.next
        elseif id == disc_code then
            start, stop, current = nil, nil, current.next
        elseif id == whatsit_code then
            if start then
                flush()
            end
            local subtype = current.subtype
            if subtype == dir_code or subtype == localpar_code then
                rlmode = current.dir
            end
            current = current.next
        else
            if start then
                flush()
            end
            current = current.next
        end
    end
    if start then
        flush()
    end
    nofparagraphs = nofparagraphs + 1
    nofwords = nofwords + #cache
    return head, done
end

local function collect_words(list)
    local words, w, word = { }, 0, nil
    for current in traverse_ids(whatsit_code,list) do
        if current.subtype == userdefined_code then
            local user_id = current.user_id
            if user_id == 1 then
                word = { current.value, current, current }
                w = w + 1
                words[w] = word
            elseif user_id == 2 then
                word[3] = current
            end
        end
    end
    return words -- check for empty (elsewhere)
end

-- we could avoid a hpack but hpack is not that slow

local function doit(word,list,best,width,badness,line,set,listdir)
    local changed = 0
    local n = word[1]
    local found = cache[n]
    if found then
        local original, attribute, direction = found.original, found.attribute, found.direction
        local solution = solutions[attribute]
        local features = solution and solution[set]
        if features then
            local featurenumber = features[best] -- not ok probably
            if featurenumber then
                noftries = noftries + 1
                local first = copy_nodelist(original)
                if not trace_colors then
                    for n in traverse_nodes(first) do -- maybe fast force so no attr needed
                        set_attribute(n,0,featurenumber) -- this forces dynamics
                    end
                elseif set == "less" then
                    for n in traverse_nodes(first) do
                        fcs(n,"font:isol")
                        set_attribute(n,0,featurenumber)
                    end
                else
                    for n in traverse_nodes(first) do
                        fcs(n,"font:medi")
                        set_attribute(n,0,featurenumber)
                    end
                end
                local font = found.font
                local dynamics = found.dynamics
                local shared = fontdata[font].shared
                if not dynamics then -- we cache this
                    dynamics = shared.dynamics
                    found.dynamics = dynamics
                end
                local processors = found[featurenumber]
                if not processors then -- we cache this too
                    processors = shared.setdynamics(font,dynamics,featurenumber)
                    found[featurenumber] = processors
                end
                for i=1,#processors do -- often more than 1
                    first = processors[i](first,font,featurenumber) -- we can make a special one that already passes the dynamics
                end
                first = inject_kerns(first)
                local h = word[2].next -- head of current word
                local t = word[3].prev -- tail of current word
                if first.id == whatsit_code then
                    local temp = first
                    first = first.next
                    free_node(temp)
                end
                local last = find_node_tail(first)
                -- replace [u]h->t by [u]first->last
                local next, prev = t.next, h.prev
                prev.next, first.prev = first, prev
                if next then
                    last.next, next.prev = next, last
                end
                -- check new pack
                local temp, b = repack_hlist(list,width,'exactly',listdir)
                if b > badness then
                    if trace_optimize then
                        report_optimizers("line %s, badness before: %s, after: %s, criterium: %s -> quit",line,badness,b,criterium)
                    end
                    -- remove last insert
                    prev.next, h.prev = h, prev
                    if next then
                        t.next, next.prev = next, t
                    else
                        t.next = nil
                    end
                    last.next = nil
                    free_nodelist(first)
                else
                    if trace_optimize then
                        report_optimizers("line %s, badness before: %s, after: %s, criterium: %s -> continue",line,badness,b,criterium)
                    end
                    -- free old h->t
                    t.next = nil
                    free_nodelist(h)
                    changed, badness = changed + 1, b
                end
                if b <= criterium then
                    return true, changed
                end
            end
        end
    end
    return false, changed
end

-- We repeat some code but adding yet another layer of indirectness is not
-- making things better.

variants[variables.normal] = function(words,list,best,width,badness,line,set,listdir)
    local changed = 0
    for i=1,#words do
        local done, c = doit(words[i],list,best,width,badness,line,set,listdir)
        changed = changed + c
        if done then
            break
        end
    end
    if changed > 0 then
        nofadapted = nofadapted + 1
        -- todo: get rid of pack when ok because we already have packed and we only need the last b
        local list, b = repack_hlist(list,width,'exactly',listdir)
        return list, true, changed, b -- badness
    else
        nofkept = nofkept + 1
        return list, false, 0, badness
    end
end

variants[variables.reverse] = function(words,list,best,width,badness,line,set,listdir)
    local changed = 0
    for i=#words,1,-1 do
        local done, c = doit(words[i],list,best,width,badness,line,set,listdir)
        changed = changed + c
        if done then
            break
        end
    end
    if changed > 0 then
        nofadapted = nofadapted + 1
        -- todo: get rid of pack when ok because we already have packed and we only need the last b
        local list, b = repack_hlist(list,width,'exactly',listdir)
        return list, true, changed, b -- badness
    else
        nofkept = nofkept + 1
        return list, false, 0, badness
    end
end

variants[variables.random] = function(words,list,best,width,badness,line,set,listdir)
    local changed = 0
    while #words > 0 do
        local done, c = doit(remove(words,random(1,#words)),list,best,width,badness,line,set,listdir)
        changed = changed + c
        if done then
            break
        end
    end
    if changed > 0 then
        nofadapted = nofadapted + 1
        -- todo: get rid of pack when ok because we already have packed and we only need the last b
        local list, b = repack_hlist(list,width,'exactly',listdir)
        return list, true, changed, b -- badness
    else
        nofkept = nofkept + 1
        return list, false, 0, badness
    end
end

optimize = variants.normal -- the default

local function show_quality(current,what,line)
    local set    = current.glue_set
    local sign   = current.glue_sign
    local order  = current.glue_order
    local amount = set * ((sign == 2 and -1) or 1)
    report_optimizers("line %s, %s, amount %s, set %s, sign %s (%s), order %s",line,what,amount,set,sign,how,order)
end

function splitters.optimize(head)
    local nc = #cache
    if nc > 0 then
        starttiming(splitters)
        local listdir = nil -- todo ! ! !
        if randomseed then
            math.setrandomseedi(randomseed)
            randomseed = nil
        end
        local line = 0
        local tex_hbadness, tex_hfuzz = tex.hbadness, tex.hfuzz
        tex.hbadness, tex.hfuzz = 10000, number.maxdimen
        if trace_optimize then
            report_optimizers("preroll: %s, variant: %s, preroll criterium: %s, cache size: %s",
                tostring(preroll),variant,criterium,nc)
        end
        for current in traverse_ids(hlist_code,head) do
         -- report_splitters("before: [%s] => %s",current.dir,nodes.tosequence(current.list,nil))
            line = line + 1
            local sign, dir, list, width = current.glue_sign, current.dir, current.list, current.width
            local temp, badness = repack_hlist(list,width,'exactly',dir) -- it would be nice if the badness was stored in the node
            if badness > 0 then
                if sign == 0 then
                    if trace_optimize then
                        report_optimizers("line %s, badness %s, okay",line,badness)
                    end
                else
                    local set, max
                    if sign == 1 then
                        if trace_optimize then
                            report_optimizers("line %s, badness %s, underfull, trying more",line,badness)
                        end
                        set, max = "more", max_more
                    else
                        if trace_optimize then
                            report_optimizers("line %s, badness %s, overfull, trying less",line,badness)
                        end
                        set, max = "less", max_less
                    end
                    -- we can keep the best variants
                    local lastbest, lastbadness = nil, badness
                    if preroll then
                        local bb, base
                        for i=1,max do
                            if base then
                                free_nodelist(base)
                            end
                            base = copy_nodelist(list)
                            local words = collect_words(base) -- beware: words is adapted
                            for j=i,max do
                                local temp, done, changes, b = optimize(words,base,j,width,badness,line,set,dir)
                                base = temp
                                if trace_optimize then
                                    report_optimizers("line %s, alternative: %s.%s, changes: %s, badness %s",line,i,j,changes,b)
                                end
                                bb = b
                                if b <= criterium then
                                    break
                                end
                             -- if done then
                             --     break
                             -- end
                            end
                            if bb and bb > criterium then -- needs checking
                                if not lastbest then
                                    lastbest, lastbadness = i, bb
                                elseif bb > lastbadness then
                                    lastbest, lastbadness = i, bb
                                end
                            else
                                break
                            end
                        end
                        free_nodelist(base)
                    end
                    local words = collect_words(list)
                    for best=lastbest or 1,max do
                        local temp, done, changes, b = optimize(words,list,best,width,badness,line,set,dir)
                        current.list = temp
                        if trace_optimize then
                            report_optimizers("line %s, alternative: %s, changes: %s, badness %s",line,best,changes,b)
                        end
                        if done then
                            if b <= criterium then -- was == 0
                                protect_glyphs(list)
                                break
                            end
                        end
                    end
                end
            else
                if trace_optimize then
                    report_optimizers("line %s, not bad enough",line)
                end
            end
            -- we pack inside the outer hpack and that way keep the original wd/ht/dp as bonus
            current.list = hpack_nodes(current.list,width,'exactly',listdir)
         -- report_splitters("after: [%s] => %s",temp.dir,nodes.tosequence(temp.list,nil))
        end
        for i=1,nc do
            local ci = cache[i]
            free_nodelist(ci.original)
        end
        cache = { }
        tex.hbadness, tex.hfuzz = tex_hbadness, tex_hfuzz
        stoptiming(splitters)
    end
end

statistics.register("optimizer statistics", function()
    if nofwords > 0 then
        local elapsed = statistics.elapsedtime(splitters)
        local average = noftries/elapsed
        return format("%s words identified in %s paragraphs, %s words retried, %s lines tried, %0.3f seconds used, %s adapted, %0.1f lines per second",
            nofwords,nofparagraphs,noftries,nofadapted+nofkept,elapsed,nofadapted,average)
    end
end)

function splitters.enable()
    tasks.enableaction("processors", "builders.paragraphs.solutions.splitters.split")
    tasks.enableaction("finalizers", "builders.paragraphs.solutions.splitters.optimize")
end

function splitters.disable()
    tasks.disableaction("processors", "builders.paragraphs.solutions.splitters.split")
    tasks.disableaction("finalizers", "builders.paragraphs.solutions.splitters.optimize")
end

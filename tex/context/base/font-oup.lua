if not modules then modules = { } end modules ['font-oup'] = {
    version   = 1.001,
    comment   = "companion to font-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local next, type = next, type
local P, R, S = lpeg.P, lpeg.R, lpeg.S
local lpegmatch = lpeg.match
local insert, remove, copy = table.insert, table.remove, table.copy

local formatters        = string.formatters
local sortedkeys        = table.sortedkeys
local sortedhash        = table.sortedhash
local tohash            = table.tohash

local report            = logs.reporter("otf reader")

local trace_markwidth   = false  trackers.register("otf.markwidth",function(v) trace_markwidth = v end)

local readers           = fonts.handlers.otf.readers
local privateoffset     = fonts.constructors and fonts.constructors.privateoffset or 0xF0000 -- 0x10FFFF

local f_private         = formatters["P%05X"]
local f_unicode         = formatters["U%05X"]
local f_index           = formatters["I%05X"]
local f_character       = formatters["%C"]

local doduplicates      = true -- can become an option (pseudo feature)

local function replaced(list,index,replacement)
    if type(list) == "number" then
        return replacement
    elseif type(replacement) == "table" then
        local t = { }
        local n = index-1
        for i=1,n do
            t[i] = list[i]
        end
        for i=1,#replacement do
            n = n + 1
            t[n] = replacement[i]
        end
        for i=index+1,#list do
            n = n + 1
            t[n] = list[i]
        end
    else
        list[index] = replacement
        return list
    end
end

local function unifyresources(fontdata,indices)
    local descriptions = fontdata.descriptions
    local resources    = fontdata.resources
    if not descriptions or not resources then
        return
    end
    --
    local variants = fontdata.resources.variants
    if variants then
        for selector, unicodes in next, variants do
            for unicode, index in next, unicodes do
                unicodes[unicode] = indices[index]
            end
        end
    end
    --
    local function remark(marks)
        if marks then
            local newmarks = { }
            for k, v in next, marks do
                local u = indices[k]
                if u then
                    newmarks[u] = v
                else
                    report("discarding mark %i",k)
                end
            end
            return newmarks
        end
    end
    --
    local marks = resources.marks
    if marks then
        resources.marks  = remark(marks)
    end
    --
    local markclasses = resources.markclasses
    if markclasses then
        for class, marks in next, markclasses do
            markclasses[class] = remark(marks)
        end
    end
    --
    local marksets = resources.marksets
    if marksets then
        for class, marks in next, marksets do
            marksets[class] = remark(marks)
        end
    end
    --
    local done = { } -- we need to deal with shared !
    --
    local duplicates = doduplicates and resources.duplicates
    if duplicates and not next(duplicates) then
        duplicates = false
    end
    --
    local function recover(cover) -- can be packed
        for i=1,#cover do
            local c = cover[i]
            if not done[c] then
                local t = { }
                for k, v in next, c do
                    t[indices[k]] = v
                end
                cover[i] = t
                done[c]  = d
            end
        end
    end
    --
    local function recursed(c) -- ligs are not packed
        local t = { }
        for g, d in next, c do
            if type(d) == "table" then
                t[indices[g]] = recursed(d)
            else
                t[g] = indices[d] -- ligature
            end
        end
        return t
    end
    --
    -- the duplicates need checking (probably only in cjk fonts): currently we only check
    -- gsub_single, gsub_alternate and gsub_multiple
    --
    local function unifythem(sequences)
        if not sequences then
            return
        end
        for i=1,#sequences do
            local sequence  = sequences[i]
            local kind      = sequence.type
            local steps     = sequence.steps
            local features  = sequence.features
            if steps then
                for i=1,#steps do
                    local step = steps[i]
                    if kind == "gsub_single" then
                        local c = step.coverage
                        if c then
                            local t1 = done[c]
                            if not t1 then
                                t1 = { }
                                if duplicates then
                                    for g1, d1 in next, c do
                                        local ug1 = indices[g1]
                                        local ud1 = indices[d1]
                                        t1[ug1] = ud1
                                        --
                                        local dg1 = duplicates[ug1]
                                        if dg1 then
                                            for u in next, dg1 do
                                                t1[u] = ud1
                                            end
                                        end
                                    end
                                else
                                    for g1, d1 in next, c do
                                        t1[indices[g1]] = indices[d1]
                                    end
                                end
                                done[c] = t1
                            end
                            step.coverage = t1
                        end
                    elseif kind == "gpos_pair" then
                        local c = step.coverage
                        if c then
                            local t1 = done[c]
                            if not t1 then
                                t1 = { }
                                for g1, d1 in next, c do
                                    local t2 = done[d1]
                                    if not t2 then
                                        t2 = { }
                                        for g2, d2 in next, d1 do
                                            t2[indices[g2]] = d2
                                        end
                                        done[d1] = t2
                                    end
                                    t1[indices[g1]] = t2
                                end
                                done[c] = t1
                            end
                            step.coverage = t1
                        end
                    elseif kind == "gsub_ligature" then
                        local c = step.coverage
                        if c then
                            step.coverage = recursed(c)
                        end
                    elseif kind == "gsub_alternate" or kind == "gsub_multiple" then
                        local c = step.coverage
                        if c then
                            local t1 = done[c]
                            if not t1 then
                                t1 = { }
                                if duplicates then
                                    for g1, d1 in next, c do
                                        for i=1,#d1 do
                                            d1[i] = indices[d1[i]]
                                        end
                                        local ug1 = indices[g1]
                                        t1[ug1] = d1
                                        --
                                        local dg1 = duplicates[ug1]
                                        if dg1 then
                                            for u in next, dg1 do
                                                t1[u] = copy(d1)
                                            end
                                        end
                                    end
                                else
                                    for g1, d1 in next, c do
                                        for i=1,#d1 do
                                            d1[i] = indices[d1[i]]
                                        end
                                        t1[indices[g1]] = d1
                                    end
                                end
                                done[c] = t1
                            end
                            step.coverage = t1
                        end
                    elseif kind == "gpos_mark2base" or kind == "gpos_mark2mark" or kind == "gpos_mark2ligature" then
                        local c = step.coverage
                        if c then
                            local t1 = done[c]
                            if not t1 then
                                t1 = { }
                                for g1, d1 in next, c do
                                    t1[indices[g1]] = d1
                                end
                                done[c] = t1
                            end
                            step.coverage = t1
                        end
                        local c = step.baseclasses
                        if c then
                            local t1 = done[c]
                            if not t1 then
                                for g1, d1 in next, c do
                                    local t2 = done[d1]
                                    if not t2 then
                                        t2 = { }
                                        for g2, d2 in next, d1 do
                                            t2[indices[g2]] = d2
                                        end
                                        done[d1] = t2
                                    end
                                    c[g1] = t2
                                end
                                done[c] = c
                            end
                        end
                    elseif kind == "gpos_single" or kind == "gpos_cursive" then
                        local c = step.coverage
                        if c then
                            local t1 = done[c]
                            if not t1 then
                                t1 = { }
                                for g1, d1 in next, c do
                                    t1[indices[g1]] = d1
                                end
                                done[c] = t1
                            end
                            step.coverage = t1
                        end
                    end
                    --
                    local rules = step.rules
                    if rules then
                        for i=1,#rules do
                            local rule = rules[i]
                            --
                            local before   = rule.before   if before  then recover(before)  end
                            local after    = rule.after    if after   then recover(after)   end
                            local current  = rule.current  if current then recover(current) end
                            --
                            local replacements = rule.replacements
                            if replacements then
                                if not done[replacements] then
                                    local r = { }
                                    for k, v in next, replacements do
                                        r[indices[k]] = indices[v]
                                    end
                                    rule.replacements = r
                                    done[replacements] = r
                                end
                            end
                        end
                    end
                end
            end
       end
    end
    --
    unifythem(resources.sequences)
    unifythem(resources.sublookups)
end

local function copyduplicates(fontdata)
    if doduplicates then
        local descriptions = fontdata.descriptions
        local resources    = fontdata.resources
        local duplicates   = resources.duplicates
        if duplicates then
            for u, d in next, duplicates do
                local du = descriptions[u]
                if du then
                    local t  = { f_character(u) }
                    for u in next, d do
                        descriptions[u] = copy(du)
                        t[#t+1] = f_character(u)
                    end
                    report("duplicates: % t",t)
                else
                    -- what a mess
                end
            end
        end
    end
end

local ignore = { -- should we fix them?
    ["notdef"]            = true,
    [".notdef"]           = true,
    ["null"]              = true,
    [".null"]             = true,
    ["nonmarkingreturn"]  = true,
}


local function checklookups(fontdata,missing,nofmissing)
    local descriptions = fontdata.descriptions
    local resources    = fontdata.resources
    if missing and nofmissing and nofmissing <= 0 then
        return
    end
    --
    local singles    = { }
    local alternates = { }
    local ligatures  = { }

    if not missing then
        missing    = { }
        nofmissing = 0
        for u, d in next, descriptions do
            if not d.unicode then
                nofmissing = nofmissing + 1
                missing[u] = true
            end
        end
    end

    local function collectthem(sequences)
        if not sequences then
            return
        end
        for i=1,#sequences do
            local sequence = sequences[i]
            local kind     = sequence.type
            local steps    = sequence.steps
            if steps then
                for i=1,#steps do
                    local step = steps[i]
                    if kind == "gsub_single" then
                        local c = step.coverage
                        if c then
                            singles[#singles+1] = c
                        end
                    elseif kind == "gsub_alternate" then
                        local c = step.coverage
                        if c then
                            alternates[#alternates+1] = c
                        end
                    elseif kind == "gsub_ligature" then
                        local c = step.coverage
                        if c then
                            ligatures[#ligatures+1] = c
                        end
                    end
                end
            end
        end
    end

    collectthem(resources.sequences)
    collectthem(resources.sublookups)

    local loops = 0
    while true do
        loops = loops + 1
        local old = nofmissing
        for i=1,#singles do
            local c = singles[i]
            for g1, g2 in next, c do
                if missing[g1] then
                    local u2 = descriptions[g2].unicode
                    if u2 then
                        missing[g1] = false
                        descriptions[g1].unicode = u2
                        nofmissing = nofmissing - 1
                    end
                end
                if missing[g2] then
                    local u1 = descriptions[g1].unicode
                    if u1 then
                        missing[g2] = false
                        descriptions[g2].unicode = u1
                        nofmissing = nofmissing - 1
                    end
                end
            end
        end
        for i=1,#alternates do
            local c = alternates[i]
            -- maybe first a g1 loop and then a g2
            for g1, d1 in next, c do
                if missing[g1] then
                    for i=1,#d1 do
                        local g2 = d1[i]
                        local u2 = descriptions[g2].unicode
                        if u2 then
                            missing[g1] = false
                            descriptions[g1].unicode = u2
                            nofmissing = nofmissing - 1
                        end
                    end
                end
                if not missing[g1] then
                    for i=1,#d1 do
                        local g2 = d1[i]
                        if missing[g2] then
                            local u1 = descriptions[g1].unicode
                            if u1 then
                                missing[g2] = false
                                descriptions[g2].unicode = u1
                                nofmissing = nofmissing - 1
                            end
                        end
                    end
                end
            end
        end
        if nofmissing <= 0 then
            report("all done in %s loops",loops)
            return
        elseif old == nofmissing then
            break
        end
    end

    local t, n -- no need to insert/remove and allocate many times

    local function recursed(c)
        for g, d in next, c do
            if g ~= "ligature" then
                local u = descriptions[g].unicode
                if u then
                    n = n + 1
                    t[n] = u
                    recursed(d)
                    n = n - 1
                end
            elseif missing[d] then
                local l = { }
                local m = 0
                for i=1,n do
                    local u = t[i]
                    if type(u) == "table" then
                        for i=1,#u do
                            m = m + 1
                            l[m] = u[i]
                        end
                    else
                        m = m + 1
                        l[m] = u
                    end
                end
                missing[d] = false
                descriptions[d].unicode = l
                nofmissing = nofmissing - 1
            end
        end
    end

    if nofmissing > 0 then
        t = { }
        n = 0
        local loops = 0
        while true do
            loops = loops + 1
            local old = nofmissing
            for i=1,#ligatures do
                recursed(ligatures[i])
            end
            if nofmissing <= 0 then
                report("all done in %s loops",loops)
                return
            elseif old == nofmissing then
                break
            end
        end
        t = nil
        n = 0
    end

    if nofmissing > 0 then
        local done = { }
        for i, r in next, missing do
            if r then
                local name = descriptions[i].name or f_index(i)
                if not ignore[name] then
                    done[#done+1] = name
                end
            end
        end
        if #done > 0 then
            table.sort(done)
            report("not unicoded: % t",done)
        end
    end
end

local function unifymissing(fontdata)
    if not fonts.mappings then
        require("font-map")
        require("font-agl")
    end
    local unicodes     = { }
    local private      = fontdata.private
    local resources    = fontdata.resources
    resources.unicodes = unicodes
    for unicode, d in next, fontdata.descriptions do
        if unicode < privateoffset then
            local name = d.name
            if name then
                unicodes[name] = unicode
            end
        end
    end
    fonts.mappings.addtounicode(fontdata,fontdata.filename,checklookups)
    resources.unicodes = nil
end

local function unifyglyphs(fontdata,usenames)
    local private      = fontdata.private or privateoffset
    local glyphs       = fontdata.glyphs
    local indices      = { }
    local descriptions = { }
    local names        = usenames and { }
    local resources    = fontdata.resources
    local zero         = glyphs[0]
    local zerocode     = zero.unicode
    if not zerocode then
        zerocode       = private
        zero.unicode   = zerocode
        private        = private + 1
    end
    descriptions[zerocode] = zero
    if names then
        local name  = glyphs[0].name or f_private(zerocode)
        indices[0]  = name
        names[name] = zerocode
    else
        indices[0] = zerocode
    end
    --
    for index=1,#glyphs do
        local glyph   = glyphs[index]
        local unicode = glyph.unicode -- this is the primary one
        if not unicode then
         -- report("assigning private unicode %U to glyph indexed %05X (%s)",private,index,"unset")
            unicode = private
            -- glyph.unicode  = -1
            if names then
                local name     = glyph.name or f_private(unicode)
                indices[index] = name
                names[name]    = unicode
            else
                indices[index] = unicode
            end
            private = private + 1
        elseif descriptions[unicode] then
            -- real weird
report("assigning private unicode %U to glyph indexed %05X (%C)",private,index,unicode)
            unicode = private
            -- glyph.unicode  = -1
            if names then
                local name     = glyph.name or f_private(unicode)
                indices[index] = name
                names[name]    = unicode
            else
                indices[index] = unicode
            end
            private = private + 1
        else
            if names then
                local name     = glyph.name or f_unicode(unicode)
                indices[index] = name
                names[name]    = unicode
            else
                indices[index] = unicode
            end
        end
        descriptions[unicode] = glyph
    end
    --
    for index=1,#glyphs do
        local math  = glyphs[index].math
        if math then
            local list = math.vparts
            if list then
                for i=1,#list do local l = list[i] l.glyph = indices[l.glyph] end
            end
            local list = math.hparts
            if list then
                for i=1,#list do local l = list[i] l.glyph = indices[l.glyph] end
            end
            local list = math.vvariants
            if list then
             -- for i=1,#list do local l = list[i] l.glyph = indices[l.glyph] end
                for i=1,#list do list[i] = indices[list[i]] end
            end
            local list = math.hvariants
            if list then
             -- for i=1,#list do local l = list[i] l.glyph = indices[l.glyph] end
                for i=1,#list do list[i] = indices[list[i]] end
            end
        end
    end
    --
    fontdata.private      = private
    fontdata.glyphs       = nil
    fontdata.names        = names
    fontdata.descriptions = descriptions
    fontdata.hashmethod   = hashmethod
    --
    return indices, names
end

local p_bogusname = (
    (P("uni") + P("UNI") + P("Uni") + P("U") + P("u")) * S("Xx")^0 * R("09","AF")^1
  + (P("identity") + P("Identity") + P("IDENTITY")) * R("09","AF")^1
  + (P("index") + P("Index") + P("INDEX")) * R("09")^1
) * P(-1)

local function stripredundant(fontdata)
    local descriptions = fontdata.descriptions
    if descriptions then
        local n = 0
        local c = 0
        for unicode, d in next, descriptions do
            local name = d.name
            if name and lpegmatch(p_bogusname,name) then
                d.name = nil
                n = n + 1
            end
            if d.class == "base" then
                d.class = nil
                c = c + 1
            end
        end
        if n > 0 then
            report("%s bogus names removed (verbose unicode)",n)
        end
        if c > 0 then
            report("%s base class tags removed (default is base)",c)
        end
    end
end

function readers.rehash(fontdata,hashmethod) -- TODO: combine loops in one
    if not (fontdata and fontdata.glyphs) then
        return
    end
    if hashmethod == "indices" then
        fontdata.hashmethod = "indices"
    elseif hashmethod == "names" then
        fontdata.hashmethod = "names"
        local indices = unifyglyphs(fontdata,true)
        unifyresources(fontdata,indices)
        copyduplicates(fontdata)
        unifymissing(fontdata)
     -- stripredundant(fontdata)
    else
        fontdata.hashmethod = "unicode"
        local indices = unifyglyphs(fontdata)
        unifyresources(fontdata,indices)
        copyduplicates(fontdata)
        unifymissing(fontdata)
        stripredundant(fontdata)
    end
end

function readers.checkhash(fontdata)
    local hashmethod = fontdata.hashmethod
    if hashmethod == "unicodes" then
        fontdata.names = nil -- just to be sure
    elseif hashmethod == "names" and fontdata.names then
        unifyresources(fontdata,fontdata.names)
        copyduplicates(fontdata)
        fontdata.hashmethod = "unicode"
        fontdata.names = nil -- no need for it
    else
        readers.rehash(fontdata,"unicode")
    end
end

function readers.addunicodetable(fontdata)
    local resources = fontdata.resources
    local unicodes  = resources.unicodes
    if not unicodes then
        local descriptions = fontdata.descriptions
        if descriptions then
            unicodes = { }
            resources.unicodes = unicodes
            for u, d in next, descriptions do
                local n = d.name
                if n then
                    unicodes[n] = u
                end
            end
        end
    end
end

-- for the moment here:

local concat, sort = table.concat, table.sort
local next, type, tostring = next, type, tostring

local criterium     = 1
local threshold     = 0

local trace_packing = false  trackers.register("otf.packing", function(v) trace_packing = v end)
local trace_loading = false  trackers.register("otf.loading", function(v) trace_loading = v end)

local report_otf    = logs.reporter("fonts","otf loading")

local function tabstr_normal(t)
    local s = { }
    local n = 0
    for k, v in next, t do
        n = n + 1
        if type(v) == "table" then
            s[n] = k .. ">" .. tabstr_normal(v)
        elseif v == true then
            s[n] = k .. "+" -- "=true"
        elseif v then
            s[n] = k .. "=" .. v
        else
            s[n] = k .. "-" -- "=false"
        end
    end
    if n == 0 then
        return ""
    elseif n == 1 then
        return s[1]
    else
        sort(s) -- costly but needed (occasional wrong hit otherwise)
        return concat(s,",")
    end
end

local function tabstr_flat(t)
    local s = { }
    local n = 0
    for k, v in next, t do
        n = n + 1
        s[n] = k .. "=" .. v
    end
    if n == 0 then
        return ""
    elseif n == 1 then
        return s[1]
    else
        sort(s) -- costly but needed (occasional wrong hit otherwise)
        return concat(s,",")
    end
end

local function tabstr_mixed(t) -- indexed
    local s = { }
    local n = #t
    if n == 0 then
        return ""
    elseif n == 1 then
        local k = t[1]
        if k == true then
            return "++" -- we need to distinguish from "true"
        elseif k == false then
            return "--" -- we need to distinguish from "false"
        else
            return tostring(k) -- number or string
        end
    else
        for i=1,n do
            local k = t[i]
            if k == true then
                s[i] = "++" -- we need to distinguish from "true"
            elseif k == false then
                s[i] = "--" -- we need to distinguish from "false"
            else
                s[i] = k -- number or string
            end
        end
        return concat(s,",")
    end
end

local function tabstr_boolean(t)
    local s = { }
    local n = 0
    for k, v in next, t do
        n = n + 1
        if v then
            s[n] = k .. "+"
        else
            s[n] = k .. "-"
        end
    end
    if n == 0 then
        return ""
    elseif n == 1 then
        return s[1]
    else
        sort(s) -- costly but needed (occasional wrong hit otherwise)
        return concat(s,",")
    end
end

-- beware: we cannot unpack and repack the same table because then sharing
-- interferes (we could catch this if needed) .. so for now: save, reload
-- and repack in such cases (never needed anyway) .. a tricky aspect is that
-- we then need to sort more thanks to random hashing

function readers.pack(data)

    if data then

        local h, t, c = { }, { }, { }
        local hh, tt, cc = { }, { }, { }
        local nt, ntt = 0, 0

        local function pack_normal(v)
            local tag = tabstr_normal(v)
            local ht = h[tag]
            if ht then
                c[ht] = c[ht] + 1
                return ht
            else
                nt = nt + 1
                t[nt] = v
                h[tag] = nt
                c[nt] = 1
                return nt
            end
        end

        local function pack_flat(v)
            local tag = tabstr_flat(v)
            local ht = h[tag]
            if ht then
                c[ht] = c[ht] + 1
                return ht
            else
                nt = nt + 1
                t[nt] = v
                h[tag] = nt
                c[nt] = 1
                return nt
            end
        end

        local function pack_boolean(v)
            local tag = tabstr_boolean(v)
            local ht = h[tag]
            if ht then
                c[ht] = c[ht] + 1
                return ht
            else
                nt = nt + 1
                t[nt] = v
                h[tag] = nt
                c[nt] = 1
                return nt
            end
        end

        local function pack_indexed(v)
            local tag = concat(v," ")
            local ht = h[tag]
            if ht then
                c[ht] = c[ht] + 1
                return ht
            else
                nt = nt + 1
                t[nt] = v
                h[tag] = nt
                c[nt] = 1
                return nt
            end
        end

        local function pack_mixed(v)
            local tag = tabstr_mixed(v)
            local ht = h[tag]
            if ht then
                c[ht] = c[ht] + 1
                return ht
            else
                nt = nt + 1
                t[nt] = v
                h[tag] = nt
                c[nt] = 1
                return nt
            end
        end

        local function pack_final(v)
            -- v == number
            if c[v] <= criterium then
                return t[v]
            else
                -- compact hash
                local hv = hh[v]
                if hv then
                    return hv
                else
                    ntt = ntt + 1
                    tt[ntt] = t[v]
                    hh[v] = ntt
                    cc[ntt] = c[v]
                    return ntt
                end
            end
        end

        local function success(stage,pass)
            if nt == 0 then
                if trace_loading or trace_packing then
                    report_otf("pack quality: nothing to pack")
                end
                return false
            elseif nt >= threshold then
                local one, two, rest = 0, 0, 0
                if pass == 1 then
                    for k,v in next, c do
                        if v == 1 then
                            one = one + 1
                        elseif v == 2 then
                            two = two + 1
                        else
                            rest = rest + 1
                        end
                    end
                else
                    for k,v in next, cc do
                        if v > 20 then
                            rest = rest + 1
                        elseif v > 10 then
                            two = two + 1
                        else
                            one = one + 1
                        end
                    end
                    data.tables = tt
                end
                if trace_loading or trace_packing then
                    report_otf("pack quality: stage %s, pass %s, %s packed, 1-10:%s, 11-20:%s, rest:%s (criterium: %s)",
                        stage, pass, one+two+rest, one, two, rest, criterium)
                end
                return true
            else
                if trace_loading or trace_packing then
                    report_otf("pack quality: stage %s, pass %s, %s packed, aborting pack (threshold: %s)",
                        stage, pass, nt, threshold)
                end
                return false
            end
        end

        local function packers(pass)
            if pass == 1 then
                return pack_normal, pack_indexed, pack_flat, pack_boolean, pack_mixed
            else
                return pack_final, pack_final, pack_final, pack_final, pack_final
            end
        end

        local resources  = data.resources
        local sequences  = resources.sequences
        local sublookups = resources.sublookups
        local features   = resources.features

        local chardata     = characters and characters.data
        local descriptions = data.descriptions or data.glyphs

        if not descriptions then
            return
        end

        --

        for pass=1,2 do

            if trace_packing then
                report_otf("start packing: stage 1, pass %s",pass)
            end

            local pack_normal, pack_indexed, pack_flat, pack_boolean, pack_mixed = packers(pass)

            for unicode, description in next, descriptions do
                local boundingbox = description.boundingbox
                if boundingbox then
                    description.boundingbox = pack_indexed(boundingbox)
                end
                local math = description.math
                if math then
                    local kerns = math.kerns
                    if kerns then
                        for tag, kern in next, kerns do
                            kerns[tag] = pack_normal(kern)
                        end
                    end
                end
            end

            local function packthem(sequences)
                for i=1,#sequences do
                    local sequence = sequences[i]
                    local kind     = sequence.type
                    local steps    = sequence.steps
                    local order    = sequence.order
                    local features = sequence.features
                    local flags    = sequence.flags
                    if steps then
                        for i=1,#steps do
                            local step = steps[i]
                            if kind == "gpos_pair" then
                                local c = step.coverage
                                if c then
                                    if step.format == "kern" then
                                        for g1, d1 in next, c do
                                            c[g1] = pack_normal(d1)
                                        end
                                    else
                                        for g1, d1 in next, c do
                                            for g2, d2 in next, d1 do
                                                local f = d2[1] if f then d2[1] = pack_indexed(f) end
                                                local s = d2[2] if s then d2[2] = pack_indexed(s) end
                                            end
                                        end
                                    end
                                end
                            elseif kind == "gpos_single" then
                                local c = step.coverage
                                if c then
                                    if step.format == "kern" then
                                        step.coverage = pack_normal(c)
                                    else
                                        for g1, d1 in next, c do
                                            c[g1] = pack_indexed(d1)
                                        end
                                    end
                                end
                            elseif kind == "gpos_cursive" then
                                local c = step.coverage
                                if c then
                                    for g1, d1 in next, c do
                                        local f = d1[2] if f then d1[2] = pack_indexed(f) end
                                        local s = d1[3] if s then d1[3] = pack_indexed(s) end
                                    end
                                end
                            elseif kind == "gpos_mark2base" or kind == "gpos_mark2mark" then
                                local c = step.baseclasses
                                if c then
                                    for g1, d1 in next, c do
                                        for g2, d2 in next, d1 do
                                            d1[g2] = pack_indexed(d2)
                                        end
                                    end
                                end
                                local c = step.coverage
                                if c then
                                    for g1, d1 in next, c do
                                        d1[2] = pack_indexed(d1[2])
                                    end
                                end
                            elseif kind == "gpos_mark2ligature" then
                                local c = step.baseclasses
                                if c then
                                    for g1, d1 in next, c do
                                        for g2, d2 in next, d1 do
                                            for g3, d3 in next, d2 do
                                                d2[g3] = pack_indexed(d3)
                                            end
                                        end
                                    end
                                end
                                local c = step.coverage
                                if c then
                                    for g1, d1 in next, c do
                                        d1[2] = pack_indexed(d1[2])
                                    end
                                end
                            end
                            -- if ... chain ...
                            local rules = step.rules
                            if rules then
                                for i=1,#rules do
                                    local rule = rules[i]
                                    local r = rule.before       if r then for i=1,#r do r[i] = pack_boolean(r[i]) end end
                                    local r = rule.after        if r then for i=1,#r do r[i] = pack_boolean(r[i]) end end
                                    local r = rule.current      if r then for i=1,#r do r[i] = pack_boolean(r[i]) end end
                                    local r = rule.replacements if r then rule.replacements  = pack_flat   (r)    end -- can have holes
                                end
                            end
                        end
                    end
                    if order then
                        sequence.order = pack_indexed(order)
                    end
                    if features then
                        for script, feature in next, features do
                            features[script] = pack_normal(feature)
                        end
                    end
                    if flags then
                        sequence.flags = pack_normal(flags)
                    end
               end
            end

            if sequences then
                packthem(sequences)
            end

            if sublookups then
                packthem(sublookups)
            end

            if features then
                for k, list in next, features do
                    for feature, spec in next, list do
                        list[feature] = pack_normal(spec)
                    end
                end
            end

            if not success(1,pass) then
                return
            end

        end

        if nt > 0 then

            for pass=1,2 do

                if trace_packing then
                    report_otf("start packing: stage 2, pass %s",pass)
                end

                local pack_normal, pack_indexed, pack_flat, pack_boolean, pack_mixed = packers(pass)

                for unicode, description in next, descriptions do
                    local math = description.math
                    if math then
                        local kerns = math.kerns
                        if kerns then
                            math.kerns = pack_normal(kerns)
                        end
                    end
                end

                local function packthem(sequences)
                    for i=1,#sequences do
                        local sequence = sequences[i]
                        local kind     = sequence.type
                        local steps    = sequence.steps
                        local features = sequence.features
                        if steps then
                            for i=1,#steps do
                                local step = steps[i]
                                if kind == "gpos_pair" then
                                    local c = step.coverage
                                    if c then
                                        if step.format == "kern" then
                                            -- todo !
                                        else
                                            for g1, d1 in next, c do
                                                for g2, d2 in next, d1 do
                                                    d1[g2] = pack_normal(d2)
                                                end
                                            end
                                        end
                                    end
--                                 elseif kind == "gpos_mark2base" or kind == "gpos_mark2mark" or kind == "gpos_mark2ligature" then
-- local c = step.baseclasses
-- for k, v in next, c do
--     c[k] = pack_normal(v)
-- end
                                end
                                local rules = step.rules
                                if rules then
                                    for i=1,#rules do
                                        local rule = rules[i]
                                        local r = rule.before  if r then rule.before  = pack_normal(r) end
                                        local r = rule.after   if r then rule.after   = pack_normal(r) end
                                        local r = rule.current if r then rule.current = pack_normal(r) end
                                    end
                                end
                            end
                        end
                        if features then
                            sequence.features = pack_normal(features)
                        end
                   end
                end
                if sequences then
                    packthem(sequences)
                end
                if sublookups then
                    packthem(sublookups)
                end
                -- features
                if not success(2,pass) then
                 -- return
                end
            end

            for pass=1,2 do
                if trace_packing then
                    report_otf("start packing: stage 3, pass %s",pass)
                end

                local pack_normal, pack_indexed, pack_flat, pack_boolean, pack_mixed = packers(pass)

                local function packthem(sequences)
                    for i=1,#sequences do
                        local sequence = sequences[i]
                        local kind     = sequence.type
                        local steps    = sequence.steps
                        local features = sequence.features
                        if steps then
                            for i=1,#steps do
                                local step = steps[i]
                                if kind == "gpos_pair" then
                                    local c = step.coverage
                                    if c then
                                        if step.format == "kern" then
                                            -- todo !
                                        else
                                            for g1, d1 in next, c do
                                                c[g1] = pack_normal(d1)
                                            end
                                        end
                                    end
                                end
                            end
                        end
                   end
                end

                if sequences then
                    packthem(sequences)
                end
                if sublookups then
                    packthem(sublookups)
                end

            end

        end

    end
end

local unpacked_mt = {
    __index =
        function(t,k)
            t[k] = false
            return k -- next time true
        end
}

function readers.unpack(data)

    if data then
        local tables = data.tables
        if tables then
            local resources    = data.resources
            local descriptions = data.descriptions or data.glyphs
            local sequences    = resources.sequences
            local sublookups   = resources.sublookups
            local features     = resources.features
            local unpacked     = { }
            setmetatable(unpacked,unpacked_mt)
            for unicode, description in next, descriptions do
                local tv = tables[description.boundingbox]
                if tv then
                    description.boundingbox = tv
                end
                local math = description.math
                if math then
                    local kerns = math.kerns
                    if kerns then
                        local tm = tables[kerns]
                        if tm then
                            math.kerns = tm
                            kerns = unpacked[tm]
                        end
                        if kerns then
                            for k, kern in next, kerns do
                                local tv = tables[kern]
                                if tv then
                                    kerns[k] = tv
                                end
                            end
                        end
                    end
                end
            end

            local function unpackthem(sequences)
                for i=1,#sequences do
                    local sequence  = sequences[i]
                    local kind      = sequence.type
                    local steps     = sequence.steps
                    local order     = sequence.order
                    local features  = sequence.features
                    local flags     = sequence.flags
                    local markclass = sequence.markclass
                    if steps then
                        for i=1,#steps do
                            local step = steps[i]
                            if kind == "gpos_pair" then
                                local c = step.coverage
                                if c then
                                    if step.format == "kern" then
                                        for g1, d1 in next, c do
                                            local tv = tables[d1]
                                            if tv then
                                                c[g1] = tv
                                            end
                                        end
                                    else
                                        for g1, d1 in next, c do
                                            local tv = tables[d1]
                                            if tv then
                                                c[g1] = tv
                                                d1 = tv
                                            end
                                            for g2, d2 in next, d1 do
                                                local tv = tables[d2]
                                                if tv then
                                                    d1[g2] = tv
                                                    d2 = tv
                                                end
                                                local f = tables[d2[1]] if f then d2[1] = f end
                                                local s = tables[d2[2]] if s then d2[2] = s end
                                            end
                                        end
                                    end
                                end
                            elseif kind == "gpos_single" then
                                local c = step.coverage
                                if c then
                                    if step.format == "kern" then
                                        local tv = tables[c]
                                        if tv then
                                            step.coverage = tv
                                        end
                                    else
                                        for g1, d1 in next, c do
                                            local tv = tables[d1]
                                            if tv then
                                                c[g1] = tv
                                            end
                                        end
                                    end
                                end
                            elseif kind == "gpos_cursive" then
                                local c = step.coverage
                                if c then
                                    for g1, d1 in next, c do
                                        local f = tables[d1[2]] if f then d1[2] = f end
                                        local s = tables[d1[3]] if s then d1[3] = s end
                                    end
                                end
                            elseif kind == "gpos_mark2base" or kind == "gpos_mark2mark" then
                                local c = step.baseclasses
                                if c then
-- for k, v in next, c do
--     local tv = tables[v]
--     if tv then
--         c[k] = tv
--     end
-- end
                                    for g1, d1 in next, c do
                                        for g2, d2 in next, d1 do
                                            local tv = tables[d2]
                                            if tv then
                                                d1[g2] = tv
                                            end
                                        end
                                    end
                                end
                                local c = step.coverage
                                if c then
                                    for g1, d1 in next, c do
                                        local tv = tables[d1[2]]
                                        if tv then
                                            d1[2] = tv
                                        end
                                    end
                                end
                            elseif kind == "gpos_mark2ligature" then
                                local c = step.baseclasses
                                if c then
-- for k, v in next, c do
--     local tv = tables[v]
--     if tv then
--         c[k] = tv
--     end
-- end
                                    for g1, d1 in next, c do
                                        for g2, d2 in next, d1 do
                                            for g3, d3 in next, d2 do
                                                local tv = tables[d2[g3]]
                                                if tv then
                                                    d2[g3] = tv
                                                end
                                            end
                                        end
                                    end
                                end
                                local c = step.coverage
                                if c then
                                    for g1, d1 in next, c do
                                        local tv = tables[d1[2]]
                                        if tv then
                                            d1[2] = tv
                                        end
                                    end
                                end
                            end
                            local rules = step.rules
                            if rules then
                                for i=1,#rules do
                                    local rule = rules[i]
                                    local before = rule.before
                                    if before then
                                        local tv = tables[before]
                                        if tv then
                                            rule.before = tv
                                            before = tv
                                        end
                                        for i=1,#before do
                                            local tv = tables[before[i]]
                                            if tv then
                                                before[i] = tv
                                            end
                                        end
                                    end
                                    local after = rule.after
                                    if after then
                                        local tv = tables[after]
                                        if tv then
                                            rule.after = tv
                                            after = tv
                                        end
                                        for i=1,#after do
                                            local tv = tables[after[i]]
                                            if tv then
                                                after[i] = tv
                                            end
                                        end
                                    end
                                    local current = rule.current
                                    if current then
                                        local tv = tables[current]
                                        if tv then
                                            rule.current = tv
                                            current = tv
                                        end
                                        for i=1,#current do
                                            local tv = tables[current[i]]
                                            if tv then
                                                current[i] = tv
                                            end
                                        end
                                    end
                                    local replacements = rule.replacements
                                    if replacements then
                                        local tv = tables[replace]
                                        if tv then
                                            rule.replacements = tv
                                        end
                                    end
                                end
                            end
                        end
                    end
                    if features then
                        local tv = tables[features]
                        if tv then
                            sequence.features = tv
                            features = tv
                        end
                        for script, feature in next, features do
                            local tv = tables[feature]
                            if tv then
                                features[script] = tv
                            end
                        end
                    end
                    if order then
                        local tv = tables[order]
                        if tv then
                            sequence.order = tv
                        end
                    end
                    if flags then
                        local tv = tables[flags]
                        if tv then
                            sequence.flags = tv
                        end
                    end
               end
            end

            if sequences then
                unpackthem(sequences)
            end

            if sublookups then
                unpackthem(sublookups)
            end

            if features then
                for k, list in next, features do
                    for feature, spec in next, list do
                        local tv = tables[spec]
                        if tv then
                            list[feature] = tv
                        end
                    end
                end
            end

            data.tables = nil
        end
    end
end

local mt = {
    __index = function(t,k) -- maybe set it
        if k == "height" then
            local ht = t.boundingbox[4]
            return ht < 0 and 0 or ht
        elseif k == "depth" then
            local dp = -t.boundingbox[2]
            return dp < 0 and 0 or dp
        elseif k == "width" then
            return 0
        elseif k == "name" then -- or maybe uni*
            return forcenotdef and ".notdef"
        end
    end
}

local function sameformat(sequence,steps,first,nofsteps,kind)
    return true
end

local function mergesteps_1(lookup,strict)
    local steps    = lookup.steps
    local nofsteps = lookup.nofsteps
    local first    = steps[1]
    if strict then
        local f = first.format
        for i=2,nofsteps do
            if steps[i].format ~= f then
                report("not merging %a steps of %a lookup %a, different formats",nofsteps,lookup.type,lookup.name)
                return 0
            end
        end
    end
    report("merging %a steps of %a lookup %a",nofsteps,lookup.type,lookup.name)
    local target = first.coverage
    for i=2,nofsteps do
        for k, v in next, steps[i].coverage do
            if not target[k] then
                target[k] = v
            end
        end
    end
    lookup.nofsteps = 1
    lookup.merged   = true
    lookup.steps    = { first }
    return nofsteps - 1
end


local function mergesteps_2(lookup,strict) -- pairs
    local steps    = lookup.steps
    local nofsteps = lookup.nofsteps
    local first    = steps[1]
    if strict then
        local f = first.format
        for i=2,nofsteps do
            if steps[i].format ~= f then
                report("not merging %a steps of %a lookup %a, different formats",nofsteps,lookup.type,lookup.name)
                return 0
            end
        end
    end
    report("merging %a steps of %a lookup %a",nofsteps,lookup.type,lookup.name)
    local target = first.coverage
    for i=2,nofsteps do
        for k, v in next, steps[i].coverage do
            local tk = target[k]
            if tk then
                for k, v in next, v do
                    if not tk[k] then
                        tk[k] = v
                    end
                end
            else
                target[k] = v
            end
        end
    end
    lookup.nofsteps = 1
    lookup.steps = { first }
    return nofsteps - 1
end


local function mergesteps_3(lookup,strict) -- marks
    local steps    = lookup.steps
    local nofsteps = lookup.nofsteps
    local first    = steps[1]
    report("merging %a steps of %a lookup %a",nofsteps,lookup.type,lookup.name)
    local baseclasses = { }
    local coverage    = { }
    local used        = { }
    for i=1,nofsteps do
        local offset = i*10
        local step   = steps[i]
        for k, v in sortedhash(step.baseclasses) do
            baseclasses[offset+k] = v
        end
        for k, v in next, step.coverage do
            local tk = coverage[k]
            if tk then
                for k, v in next, v do
                    if not tk[k] then
                        tk[k] = v
                        local c = offset + v[1]
                        v[1] = c
                        if not used[c] then
                            used[c] = true
                        end
                    end
                end
            else
                coverage[k] = v
                local c = offset + v[1]
                v[1] = c
                if not used[c] then
                    used[c] = true
                end
            end
        end
    end
    for k, v in next, baseclasses do
        if not used[k] then
            baseclasses[k] = nil
            report("discarding not used baseclass %i",k)
        end
    end
    first.baseclasses = baseclasses
    first.coverage    = coverage
    lookup.nofsteps   = 1
    lookup.steps      = { first }
    return nofsteps - 1
end

local function nested(old,new)
    for k, v in next, old do
        if k == "ligature" then
            if not new.ligature then
                new.ligature = v
            end
        else
            local n = new[k]
            if n then
                nested(v,n)
            else
                new[k] = v
            end
        end
    end
end

local function mergesteps_4(lookup) -- ligatures
    local steps    = lookup.steps
    local nofsteps = lookup.nofsteps
    local first    = steps[1]
    report("merging %a steps of %a lookup %a",nofsteps,lookup.type,lookup.name)
    local target = first.coverage
    for i=2,nofsteps do
        for k, v in next, steps[i].coverage do
            local tk = target[k]
            if tk then
                nested(v,tk)
            else
                target[k] = v
            end
        end
    end
    lookup.nofsteps = 1
    lookup.steps = { first }
    return nofsteps - 1
end

local function checkkerns(lookup)
    local steps    = lookup.steps
    local nofsteps = lookup.nofsteps
    for i=1,nofsteps do
        local step = steps[i]
        if step.format == "pair" then
            local coverage = step.coverage
            local kerns    = true
            for g1, d1 in next, coverage do
                if d1[1] ~= 0 or d1[2] ~= 0 or d1[4] ~= 0 then
                    kerns = false
                    break
                end
            end
            if kerns then
                report("turning pairs of step %a of %a lookup %a into kerns",i,lookup.type,lookup.name)
                for g1, d1 in next, coverage do
                    coverage[g1] = d1[3]
                end
                step.format = "kern"
            end
        end
    end
end

local function checkpairs(lookup)
    local steps    = lookup.steps
    local nofsteps = lookup.nofsteps
    local kerned   = 0
    for i=1,nofsteps do
        local step = steps[i]
        if step.format == "pair" then
            local coverage = step.coverage
            local kerns    = true
            for g1, d1 in next, coverage do
                for g2, d2 in next, d1 do
                    if d2[2] then
                        kerns = false
                        break
                    else
                        local v = d2[1]
                        if v[1] ~= 0 or v[2] ~= 0 or v[4] ~= 0 then
                            kerns = false
                            break
                        end
                    end
                end
            end
            if kerns then
                report("turning pairs of step %a of %a lookup %a into kerns",i,lookup.type,lookup.name)
                for g1, d1 in next, coverage do
                    for g2, d2 in next, d1 do
                        d1[g2] = d2[1][3]
                    end
                end
                step.format = "kern"
                kerned = kerned + 1
            end
        end
    end
    return kerned
end

function readers.compact(data)
    if not data or data.compacted then
        return
    else
        data.compacted = true
    end
    local resources = data.resources
    local merged    = 0
    local kerned    = 0
    local allsteps  = 0
    local function compact(what)
        local lookups = resources[what]
        if lookups then
            for i=1,#lookups do
                local lookup   = lookups[i]
                local nofsteps = lookup.nofsteps
                allsteps = allsteps + nofsteps
                if nofsteps > 1 then
                    local kind = lookup.type
                    if kind == "gsub_single" or kind == "gsub_alternate" or kind == "gsub_multiple" then
                        merged = merged + mergesteps_1(lookup)
                    elseif kind == "gsub_ligature" then
                        merged = merged + mergesteps_4(lookup)
                    elseif kind == "gpos_single" then
                        merged = merged + mergesteps_1(lookup,true)
                        checkkerns(lookup)
                    elseif kind == "gpos_pair" then
                        merged = merged + mergesteps_2(lookup,true)
                        kerned = kerned + checkpairs(lookup)
                    elseif kind == "gpos_cursive" then
                        merged = merged + mergesteps_2(lookup)
                    elseif kind == "gpos_mark2mark" or kind == "gpos_mark2base" or kind == "gpos_mark2ligature" then
                        merged = merged + mergesteps_3(lookup)
                    end
                end
            end
        else
            report("no lookups in %a",what)
        end
    end
    compact("sequences")
    compact("sublookups")
    if merged > 0 then
        report("%i steps of %i removed due to merging",merged,allsteps)
    end
    if kerned > 0 then
        report("%i steps of %i steps turned from pairs into kerns",kerned,allsteps)
    end
end

function readers.expand(data)
    if not data or data.expanded then
        return
    else
        data.expanded = true
    end
    local resources    = data.resources
    local sublookups   = resources.sublookups
    local sequences    = resources.sequences -- were one level up
    local markclasses  = resources.markclasses
    local descriptions = data.descriptions
    if descriptions then
        local defaultwidth  = resources.defaultwidth  or 0
        local defaultheight = resources.defaultheight or 0
        local defaultdepth  = resources.defaultdepth  or 0
        local basename      = trace_markwidth and file.basename(resources.filename)
        for u, d in next, descriptions do
            local bb = d.boundingbox
            local wd = d.width
            if not wd then
                -- or bb?
                d.width = defaultwidth
            elseif trace_markwidth and wd ~= 0 and d.class == "mark" then
                report("mark %a with width %b found in %a",d.name or "<noname>",wd,basename)
            end
            if bb then
                local ht =  bb[4]
                local dp = -bb[2]
                if ht == 0 or ht < 0 then
                    -- not set
                else
                    d.height = ht
                end
                if dp == 0 or dp < 0 then
                    -- not set
                else
                    d.depth  = dp
                end
            end
        end
    end
    local function expandlookups(sequences)
        if sequences then
            -- we also need to do sublookups
            for i=1,#sequences do
                local sequence = sequences[i]
                local steps    = sequence.steps
                if steps then
                    local kind = sequence.type
                    local markclass = sequence.markclass
                    if markclass then
                        if not markclasses then
                            report_warning("missing markclasses")
                            sequence.markclass = false
                        else
                            sequence.markclass = markclasses[markclass]
                        end
                    end
                    for i=1,sequence.nofsteps do
                        local step = steps[i]
                        local baseclasses = step.baseclasses
                        if baseclasses then
                            local coverage = step.coverage
                            for k, v in next, coverage do
                                v[1] = baseclasses[v[1]] -- slot 1 is a placeholder
                            end
                        elseif kind == "gpos_cursive" then
                            local coverage = step.coverage
                            for k, v in next, coverage do
                                v[1] = coverage -- slot 1 is a placeholder
                            end
                        end
                        local rules = step.rules
                        if rules then
                            local rulehash   = { }
                            local rulesize   = 0
                            local coverage   = { }
                            local lookuptype = sequence.type
                            step.coverage    = coverage -- combined hits
                            for nofrules=1,#rules do
                                local rule         = rules[nofrules]
                                local current      = rule.current
                                local before       = rule.before
                                local after        = rule.after
                                local replacements = rule.replacements or false
                                local sequence     = { }
                                local nofsequences = 0
                                if before then
                                    for n=1,#before do
                                        nofsequences = nofsequences + 1
                                        sequence[nofsequences] = before[n]
                                    end
                                end
                                local start = nofsequences + 1
                                for n=1,#current do
                                    nofsequences = nofsequences + 1
                                    sequence[nofsequences] = current[n]
                                end
                                local stop = nofsequences
                                if after then
                                    for n=1,#after do
                                        nofsequences = nofsequences + 1
                                        sequence[nofsequences] = after[n]
                                    end
                                end
                                local lookups = rule.lookups or false
                                local subtype = nil
                                if lookups then
                                    for k, v in next, lookups do
                                        local lookup = sublookups[v]
                                        if lookup then
                                            lookups[k] = lookup
                                            if not subtype then
                                                subtype = lookup.type
                                            end
                                        else
                                            -- already expanded
                                        end
                                    end
                                end
                                if sequence[1] then -- we merge coverage into one
                                    rulesize = rulesize + 1
                                    rulehash[rulesize] = {
                                        nofrules,     -- 1
                                        lookuptype,   -- 2
                                        sequence,     -- 3
                                        start,        -- 4
                                        stop,         -- 5
                                        lookups,      -- 6 (6/7 also signal of what to do)
                                        replacements, -- 7
                                        subtype,      -- 8
                                    }
                                    for unic in next, sequence[start] do
                                        local cu = coverage[unic]
                                        if not cu then
                                            coverage[unic] = rulehash -- can now be done cleaner i think
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    expandlookups(sequences)
    expandlookups(sublookups)
end

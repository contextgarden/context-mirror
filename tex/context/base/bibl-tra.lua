if not modules then modules = { } end modules ['bibl-bib'] = {
    version   = 1.001,
    comment   = "this module is the basis for the lxml-* ones",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

bibtex       = bibtex       or { }
bibtex.hacks = bibtex.hacks or { }

local match, gmatch, format, concat, sort = string.match, string.gmatch, string.format, table.concat, table.sort
local texsprint, ctxcatcodes = tex.sprint, tex.ctxcatcodes
local variables, constants = interfaces.variables, interfaces.constants

local trace_bibtex = false  trackers.register("publications.bibtex", function(v) trace_bibtex = v end)

local hacks = bibtex.hacks

local list, done, alldone, used, registered, ordered  = { }, { }, { }, { }, { }, { }
local mode = 0

local template = string.striplong([[
  \citation{*}
  \bibstyle{cont-%s}
  \bibdata{%s}
]])

function hacks.process(settings)
    local style = settings.style or ""
    local database = settings.database or ""
    local jobname = tex.jobname
    if database ~= "" then
        interfaces.showmessage("publications",3)
        io.savedata(file.addsuffix(jobname,"aux"),format(template,style,database))
        if trace_bibtex then
            logs.report("publications","processing bibtex file '%s'",jobname)
        end
        os.execute(format("bibtex %s",jobname))
        -- purge 'm
    end
end

function hacks.register(str)
    if trace_bibtex then
        logs.report("publications","registering bibtex entry '%s'",str)
    end
    registered[#registered+1] = str
    ordered[str] = #registered
end

function hacks.reset(m)
    mode, list, done = m, { }, { }
end

function hacks.add(str,listindex)
    if not str or mode == 0 then
        -- skip
    elseif mode == 1 then
        -- all locals but no duplicates
        local sc = structure.sections.currentid()
        if done[str] ~= sc then
            done[str], alldone[str] = sc, true
            list[#list+1] = { str, listindex }
        end
    elseif mode == 2 then
        -- all locals but no preceding
        local sc = structure.sections.currentid()
        if not alldone[str] and done[str] ~= sc then
            done[str], alldone[str] = sc, true
            list[#list+1] = { str, listindex }
        end
    end
end

local function compare(a,b)
    return ordered[a[1]] < ordered[b[1]]
end

local function compare(a,b)
    local aa, bb = a[1], b[1]
    if aa and bb then
        return ordered[aa] < ordered[bb]
    else
        return true
    end
end

function hacks.flush(sortvariant)
    if sortvariant == "" or sortvariant == variables.cite or sortvariant == "default" then
        -- order is cite order i.e. same as list
    else
        sort(list,compare)
    end
    for i=1,#list do
        texsprint(ctxcatcodes,format("\\doprocessbibtexentry{%s}",list[i][1]))
    end
end

function hacks.registerplaced(str)
    used[str] = true
end

function hacks.doifalreadyplaced(str)
    commands.testcase(used[str])
end

-- we ask for <n>:tag but when we can't find it we go back
-- to look for previous definitions, and when not found again
-- we look forward

local function compare(a,b)
    return a[3] < b[3]
end

function hacks.resolve(prefix,block,reference) -- maybe already feed it split
    local subset = jobreferences.collected[prefix or ""] or jobreferences.collected[""]
    if subset then
        local result, done = { }, { }
        block = tonumber(block)
        for rest in gmatch(reference,"([^,]+)") do
            local blk, tag, found = block, nil, nil
            if block then
                tag = blk .. ":" .. rest
                found = subset[tag]
                if not found then
                    for i=block-1,1,-1 do
                        tag = i .. ":" .. rest
                        found = subset[tag]
                        if found then
                            blk = i
                            break
                        end
                    end
                end
            end
            if not found then
                blk = "*"
                tag = blk .. ":" .. rest
                found = subset[tag]
            end
            if found then
                local current = found.entries and found.entries.text
                if current and not done[current] then
                    result[#result+1] = { blk, rest, current }
                    done[current] = true
                end
            end
        end
        -- todo: ranges so the interface will change
        sort(result,compare)
        local first, last, firsti, lasti, firstr, lastr
        local collected = { }
        for i=1,#result do
            local r = result[i]
            local current = r[3]
            if not first then
                first, last, firsti, lasti, firstr, lastr = current, current, i, i, r, r
            elseif current == last + 1 then
                last, lasti, lastr = current, i, r
            else
                if last > first + 1 then
                    collected[#collected+1] = { firstr[1], firstr[2], lastr[1], lastr[2] }
                else
                    collected[#collected+1] = { firstr[1], firstr[2] }
                    if last > first then
                        collected[#collected+1] = { lastr[1], lastr[2] }
                    end
                end
                first, last, firsti, lasti, firstr, lastr = current, current, i, i, r, r
            end
        end
        if first then
            if last > first + 1 then
                collected[#collected+1] = { firstr[1], firstr[2], lastr[1], lastr[2] }
            else
                collected[#collected+1] = { firstr[1], firstr[2] }
                if last > first then
                    collected[#collected+1] = { lastr[1], lastr[2] }
                end
            end
        end
        for i=1,#collected do
            local c = collected[i]
            if c[3] then
                texsprint(ctxcatcodes,format("\\dowithbibtexnumrefrange{%s}{%s}{%s}{%s}{%s}{%s}{%s}",#collected,i,prefix,c[1],c[2],c[3],c[4]))
            else
                texsprint(ctxcatcodes,format("\\dowithbibtexnumref{%s}{%s}{%s}{%s}{%s}",#collected,i,prefix,c[1],c[2]))
            end
        end
    end
end

-- we've decided that external references make no sense
--
-- local function compare(a,b)
--     return a[3] < b[3]
-- end
--
-- local function resolve(subset,block,rest)
--     local blk, tag, found = block, nil, nil
--     if rest then
--         if block then
--             tag = blk .. ":" .. rest
--             found = subset[tag]
--             if not found then
--                 for i=block-1,1,-1 do
--                     tag = i .. ":" .. rest
--                     found = subset[tag]
--                     if found then
--                         blk = i
--                         break
--                     end
--                 end
--             end
--         end
--         if not found then
--             blk = "*"
--             tag = blk .. ":" .. rest
--             found = subset[tag]
--         end
--     end
--     return blk, rest, found
-- end

-- local function set_error(results,...)
--     local re = results[false]
--     if not re then re = { } results[false] = re end
--     re[#re+1] = { format(...) }
-- end
--
-- local function resolve_outer(results,outer,inner)
--     if inner then
--         if outer then
--             local re = results[outer]
--             if not re then re = { } results[outer] = re end
--             -- todo: external refs
--             re[#re+1] = { format("%s: %s",outer,inner) }
--         else
--             set_error(results,"no outer for inner: %s",inner)
--         end
--     else
--         set_error(results,"no inner for outer: %s",outer)
--     end
-- end
--
-- function hacks.resolve(prefix,block,reference) -- maybe already feed it split
--     local set, bug = jobreferences.identify(prefix,reference)
--     local subset = jobreferences.collected[prefix or ""] or jobreferences.collected[""]
--     if subset then
--         local jobname = tex.jobname
--         local results, done = { [jobname] = { } }, { }
--         local rj = results[jobname]
--         block = tonumber(block)
--         for i=1,#set do
--             local s = set[i]
--             local inner, outer, special = s.inner, s.outer, s.special
--             if special == "file" then
--                 resolve_outer(results,outer,s.operation)
--             elseif outer then
--                 resolve_outer(results,outer,inner)
--             elseif inner then
--                 local blk, inner, found = resolve(subset,block,inner)
--                 local current = found and found.entries and found.entries.text
--                 if current and not done[current] then
--                     rj[#rj+1] = { blk, inner, current }
--                     done[current] = true
--                 end
--             end
--         end
--         for where, result in next, results do
--             if where then -- else errors
--                 sort(result,compare)
--             end
--         end
--         local first, last, firsti, lasti, firstr, lastr
--         local function finish(cw)
--             if first then
--                 if last > first + 1 then
--                     cw[#cw+1] = { firstr[1], firstr[2], lastr[1], lastr[2] }
--                 else
--                     cw[#cw+1] = { firstr[1], firstr[2] }
--                     if last > first then
--                         cw[#cw+1] = { lastr[1], lastr[2] }
--                     end
--                 end
--             end
--         end
--         local collections = { }
--         for where, result in next, results do
--             if where == jobname then
--                 local cw = { }
--                 for i=1,#result do
--                     local r = result[i]
--                     local current = r[3]
--                     if not first then
--                         first, last, firsti, lasti, firstr, lastr = current, current, i, i, r, r
--                     elseif current == last + 1 then
--                         last, lasti, lastr = current, i, r
--                     else
--                         finish(cw)
--                         first, last, firsti, lasti, firstr, lastr = current, current, i, i, r, r
--                     end
--                 end
--                 finish(cw)
--                 if next(cw) then collections[where] = cw end
--             elseif where == false then
--                 collections[where] = result -- temp hack
--             else
--                 collections[where] = result -- temp hack
--             end
--         end
--         for where, collection in next, collections do
--             local n = #collection
--             for i=1,n do
--                 local c = collection[i]
--                 if where == jobname then
--                     -- internals
--                     if c[4] then
--                         texsprint(ctxcatcodes,format("\\dowithbibtexnumrefrange{%s}{%s}{%s}{%s}{%s}{%s}{%s}",n,i,prefix,c[1],c[2],c[3],c[4]))
--                     else
--                         texsprint(ctxcatcodes,format("\\dowithbibtexnumref{%s}{%s}{%s}{%s}{%s}",n,i,prefix,c[1],c[2]))
--                     end
--                 elseif where == false then
--                     -- errors
--                     texsprint(ctxcatcodes,c[1])
--                 else
--                     -- externals
--                     texsprint(ctxcatcodes,c[1])
--                 end
--             end
--         end
--     end
-- end

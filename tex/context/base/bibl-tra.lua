if not modules then modules = { } end modules ['bibl-bib'] = {
    version   = 1.001,
    comment   = "this module is the basis for the lxml-* ones",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

bibtex       = bibtex or { }
local bibtex = bibtex

bibtex.hacks = bibtex.hacks or { }
local hacks  = bibtex.hacks

local match, gmatch, format, concat, sort = string.match, string.gmatch, string.format, table.concat, table.sort
local variables, constants = interfaces.variables, interfaces.constants

local trace_bibtex = false  trackers.register("publications.bibtex", function(v) trace_bibtex = v end)

local report_tex = logs.reporter("publications","tex")

local context, structures = context, structures

local references = structures.references
local sections   = structures.sections

local list, done, alldone, used, registered, ordered  = { }, { }, { }, { }, { }, { }
local mode = 0

local template = utilities.strings.striplong([[
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
            report_tex("processing bibtex file '%s'",jobname)
        end
        os.execute(format("bibtex %s",jobname))
        -- purge 'm
    end
end

function hacks.register(str)
    if trace_bibtex then
        report_tex("registering bibtex entry '%s'",str)
    end
    registered[#registered+1] = str
    ordered[str] = #registered
end

function hacks.nofregistered()
    return #registered
end

function hacks.reset(m)
    mode, list, done = m, { }, { }
end

function hacks.add(str,listindex)
    if not str or mode == 0 then
        -- skip
    elseif mode == 1 then
        -- all locals but no duplicates
        local sc = sections.currentid()
        if done[str] ~= sc then
            done[str], alldone[str] = sc, true
            list[#list+1] = { str, listindex }
        end
    elseif mode == 2 then
        -- all locals but no preceding
        local sc = sections.currentid()
        if not alldone[str] and done[str] ~= sc then
            done[str], alldone[str] = sc, true
            list[#list+1] = { str, listindex }
        end
    end
end

local function compare(a,b) -- quite some checking for non-nil
    local aa, bb = a and a[1], b and b[1]
    if aa and bb then
        local oa, ob = ordered[aa], ordered[bb]
        return oa and ob and oa < ob
    end
    return false
end

function hacks.flush(sortvariant)
    if sortvariant == "" or sortvariant == variables.cite or sortvariant == "default" then
        -- order is cite order i.e. same as list
    else
        sort(list,compare)
    end
    for i=1,#list do
        context.doprocessbibtexentry(list[i][1])
    end
end

function hacks.filterall()
    for i=1,#registered do
        list[i] = { registered[i], i }
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
    local aa, bb = a and a[3], b and b[3]
    return aa and bb and aa < bb
end

function hacks.resolve(prefix,block,reference) -- maybe already feed it split
    local subset = references.collected[prefix or ""] or references.collected[""]
    if subset then
        local result, nofresult, done = { }, 0, { }
        block = tonumber(block)
        for rest in gmatch(reference,"[^, ]+") do
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
                local current = tonumber(found.entries and found.entries.text) -- tonumber needed
                if current and not done[current] then
                    nofresult = nofresult + 1
                    result[nofresult] = { blk, rest, current }
                    done[current] = true
                end
            end
        end
        -- todo: ranges so the interface will change
        sort(result,compare)
        local first, last, firsti, lasti, firstr, lastr
        local collected, nofcollected = { }, 0
        for i=1,nofresult do
            local r = result[i]
            local current = r[3]
            if not first then
                first, last, firsti, lasti, firstr, lastr = current, current, i, i, r, r
            elseif current == last + 1 then
                last, lasti, lastr = current, i, r
            else
                if last > first + 1 then
                    nofcollected = nofcollected + 1
                    collected[nofcollected] = { firstr[1], firstr[2], lastr[1], lastr[2] }
                else
                    nofcollected = nofcollected + 1
                    collected[nofcollected] = { firstr[1], firstr[2] }
                    if last > first then
                        nofcollected = nofcollected + 1
                        collected[nofcollected] = { lastr[1], lastr[2] }
                    end
                end
                first, last, firsti, lasti, firstr, lastr = current, current, i, i, r, r
            end
        end
        if first and last then
            if last > first + 1 then
                nofcollected = nofcollected + 1
                collected[nofcollected] = { firstr[1], firstr[2], lastr[1], lastr[2] }
            else
                nofcollected = nofcollected + 1
                collected[nofcollected] = { firstr[1], firstr[2] }
                if last > first then
                    nofcollected = nofcollected + 1
                    collected[nofcollected] = { lastr[1], lastr[2] }
                end
            end
        end
        if nofcollected > 0 then
            for i=1,nofcollected do
                local c = collected[i]
                if c[3] then
                    context.dowithbibtexnumrefrange(#collected,i,prefix,c[1],c[2],c[3],c[4])
                else
                    context.dowithbibtexnumref(#collected,i,prefix,c[1],c[2])
                end
            end
        else
            context.nobibtexnumref("error 1")
        end
    else
        context.nobibtexnumref("error 2")
    end
end

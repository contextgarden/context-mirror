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
        context.doprocessbibtexentry(list[i][1])
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
        for rest in gmatch(reference,"([^,%s]+)") do
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
        if #collected > 0 then
            for i=1,#collected do
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

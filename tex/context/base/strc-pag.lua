if not modules then modules = { } end modules ['strc-pag'] = {
    version   = 1.001,
    comment   = "companion to strc-pag.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local texcount, format = tex.count, string.format

local ctxcatcodes = tex.ctxcatcodes
local texsprint, texwrite = tex.sprint, tex.write

local trace_pages = false  trackers.register("structure.pages", function(v) trace_pages = v end)

structure.pages  = structure.pages      or { }

local helpers    = structure.helpers    or { }
local sections   = structure.sections   or { }
local pages      = structure.pages      or { }
local processors = structure.processors or { }
local sets       = structure.sets       or { }

local variables  = interfaces.variables

-- storage

jobpages           = jobpages or { }
jobpages.collected = jobpages.collected or { }
jobpages.tobesaved = jobpages.tobesaved or { }

local collected, tobesaved = jobpages.collected, jobpages.tobesaved

local function initializer()
    collected, tobesaved = jobpages.collected, jobpages.tobesaved
end

job.register('jobpages.collected', jobpages.tobesaved, initializer)

local specification = { } -- to be checked

function pages.save(prefixdata,numberdata)
    local realpage, userpage = texcount.realpageno, texcount.userpageno
    if realpage > 0 then
        if trace_pages then
            logs.report("pages","saving page %s.%s",realpage,userpage)
        end
        local data = {
            number = userpage,
            block = sections.currentblock(),
            prefixdata = prefixdata and helpers.simplify(prefixdata),
            numberdata = numberdata and helpers.simplify(numberdata),
        }
        tobesaved[realpage] = data
        if not collected[realpage] then
            collected[realpage] = data
        end
    elseif trace_pages then
        logs.report("pages","not saving page %s.%s",realpage,userpage)
    end
end

function structure.counters.specials.userpage()
    local r = texcount.realpageno
    if r > 0 then
        local t = tobesaved[r]
        if t then
            t.number = texcount.userpageno
            if trace_pages then
                logs.report("pages","forcing pagenumber of realpage %s to %s",r,t.number)
            end
        end
    end
end

--~ function pages.pagenumber(localspec)
--~     local deltaspec
--~     if localspec then
--~         for k,v in next, localspec do
--~             if v ~= "" and v ~= specification[k] then
--~                 if not deltaspec then deltaspec = { } end
--~                 deltaspec[k] = v
--~             end
--~         end
--~     end
--~     if deltaspec then
--~         return { realpage = texcount.realpageno, specification = deltaspec }
--~     else
--~         return { realpage = texcount.realpageno }
--~     end
--~ end

local function convertnumber(str,n)
    return format("\\convertnumber{%s}{%s}",str or "numbers",n)
end

function pages.number(realdata,pagespec)
    local userpage, block = realdata.number, realdata.block or "" -- sections.currentblock()
    local numberspec = realdata.numberdata
    local conversionset = (pagespec and pagespec.conversionset ~= "" and pagespec.conversionset) or (numberspec and numberspec.conversionset ~= "" and numberspec.conversionset) or ""
    local conversion    = (pagespec and pagespec.conversion    ~= "" and pagespec.conversion   ) or (numberspec and numberspec.conversion    ~= "" and numberspec.conversion   ) or ""
    local stopper       = (pagespec and pagespec.stopper       ~= "" and pagespec.stopper      ) or (numberspec and numberspec.stopper       ~= "" and numberspec.stopper      ) or ""
    if conversion ~= "" then
        texsprint(ctxcatcodes,format("\\convertnumber{%s}{%s}",conversion,userpage))
    else
        if conversionset == "" then conversionset = "default" end
        local theconversion = sets.get("structure:conversions",block,conversionset,index,"numbers")
        processors.sprint(ctxcatcodes,theconversion,convertnumber,userpage)
    end
    if stopper ~= "" then
        processors.sprint(ctxcatcodes,stopper)
    end
end

-- (pagespec.prefix == yes|unset) and (pages.prefix == yes) => prefix

function pages.analyse(entry,pagespecification)
    -- safeguard
    if not entry then
        return false, false, "no entry"
    end
    local references = entry.references
    if not references then
        return false, false, "no references"
    end
    local realpage = references.realpage
    if not realpage then
        return false, false, "no realpage"
    end
    local pagedata = collected[realpage]
    if not pagedata then
        return false, false, "no pagedata"
    end
    local section = references.section
    if not section then
        return pagedata, false, "no section"
    end
    local no = variables.no
    -- local preferences
    if pagespecification and pagespecification.prefix == no then
        return pagedata, false, "current spec blocks prefix"
    end
    -- stored preferences
--~     if entry.prefix == no then
--~         return pagedata, false, "entry blocks prefix"
--~     end
    -- stored page state
    pagespecification = pagedata.prefixdata
    if pagespecification and pagespecification.prefix == no then
        return pagedata, false, "pagedata blocks prefix"
    end
    -- final verdict
    return pagedata, jobsections.collected[references.section], "okay"
end

function helpers.page(data,pagespec)
    if data then
        local pagedata = pages.analyse(data,pagespec)
        if pagedata then
            pages.number(pagedata,pagespec)
        end
    end
end

function helpers.prefixpage(data,prefixspec,pagespec)
    if data then
        local pagedata, prefixdata, e = pages.analyse(data,pagespec)
        if pagedata then
            if prefixdata then
                sections.typesetnumber(prefixdata,"prefix",prefixspec or false,prefixdata or false,pagedata.prefixdata or false)
            end
            pages.number(pagedata,pagespec)
        end
    end
end

function helpers.prefixlastpage(data,prefixspec,pagespec)
    if data then
        local r = data.references
        local ls, lr = r.section, r.realpage
        r.section, r.realpage = r.lastsection or r.section, r.lastrealpage or r.realpage
        helpers.prefixpage(data,prefixspec,pagespec)
        r.section, r.realpage = ls, lr
    end
end

--

function helpers.analyse(entry,specification)
    -- safeguard
    if not entry then
        return false, false, "no entry"
    end
    local yes, no = variables.yes, variables.no
    -- section data
    local references = entry.references
    if not references then
        return entry, false, "no references"
    end
    local section = references.section
    if not section then
        return entry, false, "no section"
    end
    sectiondata = jobsections.collected[references.section]
    if not sectiondata then
        return entry, false, "no section data"
    end
    -- local preferences
    if specification and specification.prefix == no then
        return entry, false, "current spec blocks prefix"
    end
    -- stored preferences (not used)
    local prefixdata = entry.prefixdata
    if prefixdata and prefixdata.prefix == no then
        return entry, false, "entry blocks prefix"
    end
    -- final verdict
    return entry, sectiondata, "okay"
end

function helpers.prefix(data,prefixspec)
    if data then
        local _, prefixdata, status = helpers.analyse(data,prefixspec)
        if prefixdata then
            sections.typesetnumber(prefixdata,"prefix",prefixspec or false,data.prefixdata or false,prefixdata or false)
        end
    end
end

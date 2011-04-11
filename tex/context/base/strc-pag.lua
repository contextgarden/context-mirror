if not modules then modules = { } end modules ['strc-pag'] = {
    version   = 1.001,
    comment   = "companion to strc-pag.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local texcount, format = tex.count, string.format

local ctxcatcodes = tex.ctxcatcodes
local allocate, mark = utilities.storage.allocate, utilities.storage.mark

local trace_pages = false  trackers.register("structures.pages", function(v) trace_pages = v end)

local report_pages = logs.reporter("structure","pages")

local structures  = structures

local helpers     = structures.helpers
local sections    = structures.sections
local pages       = structures.pages
local processors  = structures.processors
local sets        = structures.sets
local counters    = structures.counters

local counterdata = counters.data

local variables   = interfaces.variables
local context     = context

-- storage

local collected, tobesaved = allocate(), allocate()

pages.collected = collected
pages.tobesaved = tobesaved

local function initializer()
    collected = pages.collected
    tobesaved = pages.tobesaved
end

job.register('structures.pages.collected', tobesaved, initializer)

local specification = { } -- to be checked

function pages.save(prefixdata,numberdata)
    local realpage, userpage = texcount.realpageno, texcount.userpageno
    if realpage > 0 then
        if trace_pages then
            report_pages("saving page %s.%s",realpage,userpage)
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
        report_pages("not saving page %s.%s",realpage,userpage)
    end
end

function counters.specials.userpage()
    local r = texcount.realpageno
    if r > 0 then
        local t = tobesaved[r]
        if t then
            t.number = texcount.userpageno
            if trace_pages then
                report_pages("forcing pagenumber of realpage %s to %s",r,t.number)
            end
        end
    end
end

local function convertnumber(str,n)
    return format("\\convertnumber{%s}{%s}",str or "numbers",n)
end

function pages.number(realdata,pagespec)
    local userpage, block = realdata.number, realdata.block or "" -- sections.currentblock()
    local numberspec = realdata.numberdata
    local conversionset = (pagespec and pagespec.conversionset ~= "" and pagespec.conversionset) or (numberspec and numberspec.conversionset ~= "" and numberspec.conversionset) or ""
    local conversion    = (pagespec and pagespec.conversion    ~= "" and pagespec.conversion   ) or (numberspec and numberspec.conversion    ~= "" and numberspec.conversion   ) or ""
    local starter       = (pagespec and pagespec.starter       ~= "" and pagespec.starter      ) or (numberspec and numberspec.starter       ~= "" and numberspec.starter      ) or ""
    local stopper       = (pagespec and pagespec.stopper       ~= "" and pagespec.stopper      ) or (numberspec and numberspec.stopper       ~= "" and numberspec.stopper      ) or ""
    if starter ~= "" then
        processors.sprint(ctxcatcodes,starter)
    end
    if conversion ~= "" then
        context.convertnumber(conversion,userpage)
    else
        if conversionset == "" then conversionset = "default" end
        local theconversion = sets.get("structure:conversions",block,conversionset,1,"numbers") -- to be checked: 1
        processors.sprint(ctxcatcodes,theconversion,convertnumber,userpage)
    end
    if stopper ~= "" then
        processors.sprint(ctxcatcodes,stopper)
    end
end

-- (pagespec.prefix == yes|unset) and (pages.prefix == yes) => prefix

function pages.analyze(entry,pagespecification)
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
    return pagedata, sections.collected[references.section], "okay"
end

function helpers.page(data,pagespec)
    if data then
        local pagedata = pages.analyze(data,pagespec)
        if pagedata then
            pages.number(pagedata,pagespec)
        end
    end
end

function helpers.prefixpage(data,prefixspec,pagespec)
    if data then
        local pagedata, prefixdata, e = pages.analyze(data,pagespec)
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

function helpers.analyze(entry,specification)
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
    local sectiondata = sections.collected[references.section]
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
        local _, prefixdata, status = helpers.analyze(data,prefixspec)
        if prefixdata then
            sections.typesetnumber(prefixdata,"prefix",prefixspec or false,data.prefixdata or false,prefixdata or false)
        end
    end
end

function pages.is_odd(n)
    n = n or texcount.realpageno
    if texcount.pagenoshift % 2 == 0 then
        return n % 2 == 0
    else
        return n % 2 ~= 0
    end
end

-- move to strc-pag.lua

function counters.analyze(name,counterspecification)
    local cd = counterdata[name]
    -- safeguard
    if not cd then
        return false, false, "no counter data"
    end
    -- section data
    local sectiondata = sections.current()
    if not sectiondata then
        return cd, false, "not in section"
    end
    local references = sectiondata.references
    if not references then
        return cd, false, "no references"
    end
    local section = references.section
    if not section then
        return cd, false, "no section"
    end
    sectiondata = sections.collected[references.section]
    if not sectiondata then
        return cd, false, "no section data"
    end
    -- local preferences
    local no = variables.no
    if counterspecification and counterspecification.prefix == no then
        return cd, false, "current spec blocks prefix"
    end
    -- stored preferences (not used)
    if cd.prefix == no then
        return cd, false, "entry blocks prefix"
    end
    -- sectioning
    -- if sectiondata.prefix == no then
    --     return false, false, "sectiondata blocks prefix"
    -- end
    -- final verdict
    return cd, sectiondata, "okay"
end

function counters.prefixedconverted(name,prefixspec,numberspec)
    local cd, prefixdata, result = counters.analyze(name,prefixspec)
    if cd then
        if prefixdata then
            sections.typesetnumber(prefixdata,"prefix",prefixspec or false,cd or false)
        end
        counters.converted(name,numberspec)
    end
end

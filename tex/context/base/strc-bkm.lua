if not modules then modules = { } end modules ['strc-bkm'] = {
    version   = 0.200,
    comment   = "companion to strc-bkm.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- Future version will support adding arbitrary bookmarks with
-- associated complex actions (rather trivial to implement).

-- this should become proper separated backend code

-- we should hook the placement into everystoptext ... needs checking

local format, concat, gsub = string.format, table.concat, string.gsub
local texsprint, utfvalues = tex.sprint, string.utfvalues
local ctxcatcodes = tex.ctxcatcodes
local settings_to_hash = utilities.parsers.settings_to_hash

local codeinjections = backends.codeinjections

local trace_bookmarks = false  trackers.register("references.bookmarks", function(v) trace_bookmarks = v end)

local report_bookmarks = logs.new("bookmarks")

local structures     = structures

structures.bookmarks = structures.bookmarks or { }

local bookmarks      = structures.bookmarks
local sections       = structures.sections
local lists          = structures.lists

local levelmap       = sections.levelmap
local variables      = interfaces.variables

bookmarks.method = "internal" -- or "page"

local names, opened, forced, numbered = { }, { }, { }, { }

function bookmarks.register(settings)
    local force = settings.force == variables.yes
    local number = settings.number == variables.yes
    local allopen = settings.opened == variables.all
    for k, v in next, settings_to_hash(settings.names or "") do
        names[k] = true
        if force then
            forced[k] = true
            if allopen then
                opened[k] = true
            end
        end
        if number then
            numbered[k] = true
        end
    end
    if not allopen then
        for k, v in next, settings_to_hash(settings.opened or "") do
            opened[k] = true
        end
    end
end

function bookmarks.overload(name,text)
    local l, ls = lists.tobesaved, nil
    if #l == 0 then
        -- no entries
    elseif name == "" then
        ls = l[#l]
    else
        for i=#l,0,-1 do
            local li = l[i]
            local metadata = li.metadata
            if metadata and not metadata.nolist and metadata.name == name then
                ls = li
                break
            end
        end
    end
    if ls then
        ls.titledata.bookmark = text
    end
end

local function stripped(str) -- kind of generic
    str = gsub(str,"\\([A-Z]+)","%1")            -- \LOGO
    str = gsub(str,"\\ "," ")                    -- \
    str = gsub(str,"\\([A-Za-z]+) *{(.-)}","%1") -- \bla{...}
    str = gsub(str," +"," ")                     -- spaces
    return str
end

-- todo: collect specs and collect later i.e. multiple places

local numberspec = { }

function bookmarks.setup(spec)
 -- table.merge(numberspec,spec)
    for k, v in next, spec do
        numberspec[k] = v
    end
end

function bookmarks.place()
    if next(names) then
        local list = lists.filtercollected(names,"all",nil,lists.collected,forced)
        if #list > 0 then
            local levels, lastlevel = { }, 1
            for i=1,#list do
                local li = list[i]
                local metadata = li.metadata
                local name = metadata.name
                if not metadata.nolist or forced[name] then -- and levelmap[name] then
                    local titledata = li.titledata
                    if titledata then
                        local structural = levelmap[name]
                        lastlevel = structural or lastlevel
                        local title = titledata.bookmark
                        if not title or title == "" then
                            -- We could typeset the title and then convert it.
                            if not structural then
                                -- placeholder, todo: bookmarklabel
                                title = name .. ": " .. (titledata.title or "?")
                            else
                                title = titledata.title or "?"
                            end
                        end
                        if numbered[name] then
                            local sectiondata = sections.collected[li.references.section]
                            local numberdata = li.numberdata
                            if sectiondata and numberdata and not numberdata.hidenumber then
                                -- we could typeset the number and convert it
                                title = concat(sections.typesetnumber(sectiondata,"direct",numberspec,sectiondata)) .. " " .. title
                            end
                        end
                        levels[#levels+1] = {
                            lastlevel,
                            stripped(title), -- can be replaced by converter
                            li.references, -- has internal and realpage
                            allopen or opened[name]
                        }
                    end
                end
            end
--~ print(table.serialize(levels))
            bookmarks.finalize(levels)
        end
        function bookmarks.place() end -- prevent second run
    end
end

function bookmarks.flatten(levels)
    -- This function promotes leading structurelements with a higher level
    -- to the next lower level. Such situations are the result of lack of
    -- structure: a subject preceding a chapter in a sectionblock. So, the
    -- following code runs over section blocks as well. (bookmarks-007.tex)
    local noflevels = #levels
    if noflevels > 1 then
        local skip, start, one = false, 1, levels[1]
        local first, block = one[1], one[3].block
        for i=2,noflevels do
            local li = levels[i]
            local new, newblock = li[1], li[3].block
            if newblock ~= block then
                first, block, start, skip = new, newblock, i, false
            elseif skip then
                -- go on
            elseif new > first then
                skip = true
            elseif new < first then
                for j=start,i-1 do
                    local lj = levels[j]
                    local old = lj[1]
                    lj[1] = new
                    if trace_bookmarks then
                        report_bookmarks("promoting entry %s from level %s to %s: %s",j,old,new,lj[2])
                    end
                end
                skip = true
            end
        end
    end
end

function bookmarks.finalize(levels)
    -- This function can be overloaded by an optional converter
    -- that uses nodes.toutf on a typeset stream. This is something
    -- that we will support when the main loop has become a coroutine.
    codeinjections.addbookmarks(levels,bookmarks.method)
end

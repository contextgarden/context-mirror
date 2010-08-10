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

local format, concat, gsub = string.format, table.concat, string.gsub
local texsprint, utfvalues = tex.sprint, string.utfvalues

local ctxcatcodes = tex.ctxcatcodes

local lists     = structure.lists
local levelmap  = structure.sections.levelmap
local variables = interfaces.variables

structure.bookmarks = structure.bookmarks or { }

local bookmarks = structure.bookmarks

bookmarks.method = "internal" -- or "page"

local names, opened, forced, numbered = { }, { }, { }, { }

function bookmarks.register(settings)
    local force = settings.force == variables.yes
    local number = settings.number == variables.yes
    local allopen = settings.opened == variables.all
    for k, v in next, aux.settings_to_hash(settings.names or "") do
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
        for k, v in next, aux.settings_to_hash(settings.opened or "") do
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

function structure.bookmarks.setup(spec)
 -- table.merge(numberspec,spec)
    for k, v in next, spec do
        numberspec[k] = v
    end
end

function bookmarks.place()
    if next(names) then
        local list = lists.filter_collected(names,"all",nil,lists.collected,forced)
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
                            local sectiondata = jobsections.collected[li.references.section]
                            local numberdata = li.numberdata
                            if sectiondata and numberdata and not numberdata.hidenumber then
                                -- we could typeset the number and convert it
                                title = concat(structure.sections.typesetnumber(sectiondata,"direct",numberspec,sectiondata)) .. " " .. title
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
            bookmarks.finalize(levels)
        end
        function bookmarks.place() end -- prevent second run
    end
end

function bookmarks.finalize(levels)
    -- This function can be overloaded by an optional converter
    -- that uses nodes.toutf on a typeset stream. This is something
    -- that we will support when the main loop has become a coroutine.
    backends.codeinjections.addbookmarks(levels,bookmarks.method)
end

lpdf.registerdocumentfinalizer(function() structure.bookmarks.place() end,1,"bookmarks")

if not modules then modules = { } end modules ['strc-bkm'] = {
    version   = 0.200,
    comment   = "companion to strc-bkm.tex",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- Future version will support adding arbitrary bookmarks with
-- associated complex actions (rather trivial to implement).

local format, concat, gsub = string.format, table.concat, string.gsub
local texsprint, utfvalues = tex.sprint, string.utfvalues

local ctxcatcodes = tex.ctxcatcodes

local lists    = structure.lists
local levelmap = structure.sections.levelmap

structure.bookmarks = structure.bookmarks or { }

local bookmarks = structure.bookmarks

bookmarks.method = "internal" -- or "page"

local names, opened = "", ""

function bookmarks.register(n,o)
    if names  == "" then names  = n else names  = names  .. "," .. n end
    if opened == "" then opened = o else opened = opened .. "," .. o end
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

function bookmarks.place()
    if names ~= "" then
        local list = lists.filter(names,"all",nil,lists.collected)
        if #list > 0 then
            local opened, levels = aux.settings_to_set(opened), { }
            for i=1,#list do
                local li = list[i]
                local metadata = li.metadata
                local name = metadata.name
                if not metadata.nolist and levelmap[name] then
                    local titledata = li.titledata
                    if titledata then
                        levels[#levels+1] = {
                            levelmap[name],
                            stripped(titledata.bookmark or titledata.title or "?"),
                            li.references, -- has internal and realpage
                            allopen or opened[name]
                        }
                    end
                end
            end
            backends.codeinjections.addbookmarks(levels,bookmarks.method)
        end
        function bookmarks.place() end -- prevent second run
    end
end

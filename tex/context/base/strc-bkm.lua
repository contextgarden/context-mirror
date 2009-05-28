if not modules then modules = { } end modules ['strc-bkm'] = {
    version   = 0.200,
    comment   = "companion to strc-bkm.tex",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- todo: move some code to backend

local format, concat, gsub = string.format, table.concat, string.gsub
local texsprint, utfvalues = tex.sprint, string.utfvalues

local ctxcatcodes = tex.ctxcatcodes

local lists = structure.lists

-- todo: backend code

local function pdfhexified(str)
    local t = { }
    t[#t+1] = "feff"
    for b in utfvalues(str) do
		if b < 0x10000 then
            t[#t+1] = format("%04x",b)
        else
            t[#t+1] = format("%04x%04x",b/1024+0xD800,b%1024+0xDC00)
        end
    end
    return concat(t)
end

-- todo: lpeg cleaner

local function pdfbookmark(level,n,text,page,open)
    text = gsub(text,"\\([A-Z]+)","%1")            -- \LOGO
    text = gsub(text,"\\ "," ")                    -- \
    text = gsub(text,"\\([A-Za-z]+) *{(.-)}","%1") -- \bla{...}
    text = gsub(text," +"," ")                     -- spaces
    text = pdfhexified(text) -- somehow must happen here
    texsprint(ctxcatcodes,format("\\doinsertbookmark{%s}{%s}{%s}{%s}{%s}",level,n,text,page,open))
end

-- end of todo

local levelmap = structure.sections.levelmap

structure.bookmarks = structure.bookmarks or { }

local bookmarks = structure.bookmarks

local function nofchildren(list,current,currentlevel)
    local i = current + 1
    local li = list[i]
    if li then
        local nextlevel = levelmap[li.metadata.name]
        if nextlevel and nextlevel > currentlevel then
            local n = 1
            i = i + 1
            li = list[i]
            while li do
                local somelevel = levelmap[li.metadata.name]
                if somelevel then
                    if somelevel == nextlevel then
                        n = n + 1
                    elseif somelevel < nextlevel then
                        break
                    end
                end
                i = i + 1
                li = list[i]
            end
            return n
        end
    end
    return 0
end

local names, opened = "", ""

function bookmarks.register(n,o)
    if names  == "" then names  = n else names  = names  .. "," .. n end
    if opened == "" then opened = o else opened = opened .. "," .. o end
end

function bookmarks.place()
    if name ~= "" then
        local list = lists.filter(names,"all",nil,lists.collected)
        if #list > 0 then
            local allopen = (opened == interfaces.variables.all) and 1
            opened = aux.settings_to_set(opened)
            for i=1,#list do
                local li = list[i]
                local metadata = li.metadata
                if not metadata.nolist and levelmap[metadata.name] then
                    local name, titledata = metadata.name, li.titledata
                    if titledata then
                        local level = levelmap[name]
                        local children = nofchildren(list,i,level)
                        local title = titledata.bookmark or titledata.title or "?"
                        local realpage = li.references and li.references.realpage
                        if realpage then
                            local open = allopen or (opened[name] and 1)
                            pdfbookmark(level,children,title,realpage,allopen or open or 0)
                        end
                    end
                end
            end
            bookmarks.place = function() end
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

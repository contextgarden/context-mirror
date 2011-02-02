if not modules then modules = { } end modules ['l-pdfview'] = {
    version   = 1.001,
    comment   = "companion to mtx-context.lua",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local format, concat = string.format, table.concat

pdfview = pdfview or { }

local opencalls = {
    ['default'] = "pdfopen --ax --file", -- "pdfopen --back --file"
    ['xpdf']    = "xpdfopen",
}

local closecalls= {
    ['default'] = "pdfclose --ax --file",
    ['xpdf']    = nil,
}

local allcalls = {
    ['default'] = "pdfclose --ax --all",
    ['xpdf']    = nil,
}

if os.type == "windows" then
 -- opencalls['okular'] = 'start "test" "c:/program files/kde/bin/okular.exe" --unique' -- todo: get focus
    opencalls['okular'] = 'start "test" "c:/data/system/kde/bin/okular.exe" --unique' -- todo: get focus
else
    opencalls['okular'] = 'okular --unique'
end

pdfview.method = "default"

directives.register("pdfview.method", function(v)
    pdfview.method = (opencalls[v] and v) or 'default'
end)

function pdfview.setmethod(method)
    if method and opencalls[method] then
        pdfview.method = method
    end
end

function pdfview.methods()
    return concat(table.sortedkeys(opencalls), " ")
end

function pdfview.status()
    return format("pdfview methods: %s, current method: %s (directives_pdfview_method)",pdfview.methods(),tostring(pdfview.method))
end

local openedfiles = { }

local function fullname(name)
    return file.addsuffix(name,"pdf")
end

function pdfview.open(...)
    local opencall = opencalls[pdfview.method]
    if opencall then
        local t = { ... }
        for i=1,#t do
            local name = fullname(t[i])
            if io.exists(name) then
                os.execute(format('%s "%s" 2>&1', opencall, name))
                openedfiles[name] = true
            end
        end
    end
end

function pdfview.close(...)
    local closecall = closecalls[pdfview.method]
    if closecall then
        local t = { ... }
        for i=1,#t do
            local name = fullname(t[i])
            if openedfiles[name] then
                os.execute(format('%s "%s" 2>&1', closecall, name))
                openedfiles[name] = nil
            else
                pdfview.closeall()
                break
            end
        end
    end
end

function pdfview.closeall()
    local allcall = allcalls[pdfview.method]
    if allcall then
        os.execute(format('%s 2>&1', allcall))
    end
    openedfiles = { }
end

--~ pdfview.open("t:/document/show-exa.pdf")
--~ os.sleep(3)
--~ pdfview.close("t:/document/show-exa.pdf")

return pdfview

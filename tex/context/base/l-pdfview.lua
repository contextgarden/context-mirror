if not modules then modules = { } end modules ['l-pdfview'] = {
    version   = 1.001,
    comment   = "companion to mtx-context.lua",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local format, getenv = string.format, os.getenv

pdfview = pdfview or { }

local opencalls = {
    ['default'] = "pdfopen --file", -- "pdfopen --back --file"
    ['okular']  = 'start "test" "c:/program files/kde/bin/okular.exe" --unique', -- todo: get focus
    ['xpdf']    = "xpdfopen",
}

local closecalls= {
    ['default'] = "pdfclose --file",
    ['okular']  = nil,
    ['xpdf']    = nil,
}

local allcalls = {
    ['default'] = "pdfclose --all",
    ['okular']  = nil,
    ['xpdf']    = nil,
}

pdfview.METHOD = "MTX_PDFVIEW_METHOD"
pdfview.method = getenv(pdfview.METHOD) or 'default'
pdfview.method = (opencalls[pdfview.method] and pdfview.method) or 'default'

function pdfview.methods()
    return table.concat(table.sortedkeys(opencalls), " ")
end

function pdfview.status()
    return format("pdfview methods: %s, current method: %s, MTX_PDFVIEW_METHOD=%s",pdfview.methods(),pdfview.method,getenv(pdfview.METHOD) or "<unset>")
end

local openedfiles = { }

local function fullname(name)
    return file.addsuffix(name,"pdf")
end

function pdfview.open(...)
    local opencall = opencalls[pdfview.method]
    if opencall then
        for _, name in ipairs({...}) do
            name = fullname(name)
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
        for _, name in ipairs({...}) do
            name = fullname(name)
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

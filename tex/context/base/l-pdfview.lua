if not modules then modules = { } end modules ['l-pdfview'] = {
    version   = 1.001,
    comment   = "companion to mtx-context.lua",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- Todo: figure out pdfopen/pdfclose on linux. Calling e.g. okular directly
-- doesn't work in linux when issued from scite as it blocks the editor (no
-- & possible or so). Unfortunately pdfopen keeps changing with not keeping
-- downward compatibility (command line arguments and so).

-- no 2>&1 any more, needs checking on windows

local format, concat = string.format, table.concat

pdfview = pdfview or { }

local opencalls, closecalls, allcalls, runner

if os.type == "windows" then

    opencalls = {
        ['default'] = "pdfopen --ax --file", -- --back --file --ax
        ['acrobat'] = "pdfopen --ax --file", -- --back --file --ax
        ['okular']  = 'start "test" "c:/data/system/kde/bin/okular.exe" --unique' -- todo!
    }
    closecalls= {
        ['default'] = "pdfclose --ax --file", -- --ax
        ['acrobat'] = "pdfclose --ax --file", -- --ax
        ['okular']  = false,
    }
    allcalls = {
        ['default'] = "pdfclose --ax --all", -- --ax
        ['acrobat'] = "pdfclose --ax --all", -- --ax
        ['okular']  = false,
    }

    pdfview.method = "acrobat"

    runner = function(...)
--         os.spawn(...)
        os.execute(...)
    end

else

    opencalls = {
        ['default'] = "pdfopen", -- we could pass the default here
        ['okular']  = 'okular --unique'
    }
    closecalls= {
        ['default'] = "pdfclose --file",
        ['okular']  = false,
    }
    allcalls = {
        ['default'] = "pdfclose --all",
        ['okular']  = false,
    }

    pdfview.method = "okular"

    runner = function(...)
        os.spawn(...)
    end

end

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
                runner(format('%s "%s"', opencall, name))
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
                runner(format('%s "%s"', closecall, name))
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
        runner(format('%s', allcall))
    end
    openedfiles = { }
end

--~ pdfview.open("t:/document/show-exa.pdf")
--~ os.sleep(3)
--~ pdfview.close("t:/document/show-exa.pdf")

return pdfview

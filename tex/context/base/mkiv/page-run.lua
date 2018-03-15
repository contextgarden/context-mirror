if not modules then modules = { } end modules ['page-run'] = {
    version   = 1.001,
    comment   = "companion to page-run.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local format, concat = string.format, table.concat
local todimen = number.todimen
local texdimen = tex.dimen

local function asdimen(name,unit)
    return todimen(texdimen[name],unit,"%0.4f") -- 4 is more than enough, even 3 would be okay
end

local function checkedoptions(options)
    if type(options) == "table" then
        return options
    elseif not options or options == "" then
        options = "pt,cm"
    end
    options = utilities.parsers.settings_to_hash(options)
    local n = 4
    for k, v in table.sortedhash(options) do
        local m = tonumber(k)
        if m then
            n = m
        end
    end
    options.n = n
    return options
end

function commands.showlayoutvariables(options)

    options = checkedoptions(options)

    local dimensions = { "pt", "bp", "cm", "mm", "dd", "cc", "pc", "nd", "nc", "sp", "in" }

    local n = 0
    for i=1,#dimensions do
        if options[dimensions[i]] then
            n = n + 1
        end
    end

    if n == 0 then
        options.pt = true
        n = 1
    end

    local function showdimension(name)
        context.NC()
        context.tex(interfaces.interfacedcommand(name))
        context.NC()
        for i=1,#dimensions do
            local d = dimensions[i]
            if options[d] then
                context("%s%s",asdimen(name,d),d)
                context.NC()
            end
        end
        context.NR()
    end

    local function showmacro(name)
        context.NC()
        context.tex(interfaces.interfacedcommand(name))
        context.NC()
        context.getvalue(name)
        context.NC()
        context.NR()
    end

    local function reportdimension(name)
        local result = { }
        for i=1,#dimensions do
            local d = dimensions[i]
            if options[d] then
                result[#result+1] = format("%12s%s",asdimen(name,d),d)
            end
        end
        commands.writestatus("layout",format("%-24s %s",interfaces.interfacedcommand(name),concat(result," ")))
    end

    if tex.count.textlevel == 0 then

        -- especially for Luigi:

        reportdimension("paperheight")
        reportdimension("paperwidth")
        reportdimension("printpaperheight")
        reportdimension("printpaperwidth")
        reportdimension("topspace")
        reportdimension("backspace")
        reportdimension("makeupheight")
        reportdimension("makeupwidth")
        reportdimension("topheight")
        reportdimension("topdistance")
        reportdimension("headerheight")
        reportdimension("headerdistance")
        reportdimension("textheight")
        reportdimension("footerdistance")
        reportdimension("footerheight")
        reportdimension("bottomdistance")
        reportdimension("bottomheight")
        reportdimension("leftedgewidth")
        reportdimension("leftedgedistance")
        reportdimension("leftmarginwidth")
        reportdimension("leftmargindistance")
        reportdimension("textwidth")
        reportdimension("rightmargindistance")
        reportdimension("rightmarginwidth")
        reportdimension("rightedgedistance")
        reportdimension("rightedgewidth")
        reportdimension("bodyfontsize")
        reportdimension("lineheight")

    else

        context.starttabulate { "|l|" .. string.rep("Tr|",n) }

            showdimension("paperheight")
            showdimension("paperwidth")
            showdimension("printpaperheight")
            showdimension("printpaperwidth")
            showdimension("topspace")
            showdimension("backspace")
            showdimension("makeupheight")
            showdimension("makeupwidth")
            showdimension("topheight")
            showdimension("topdistance")
            showdimension("headerheight")
            showdimension("headerdistance")
            showdimension("textheight")
            showdimension("footerdistance")
            showdimension("footerheight")
            showdimension("bottomdistance")
            showdimension("bottomheight")
            showdimension("leftedgewidth")
            showdimension("leftedgedistance")
            showdimension("leftmarginwidth")
            showdimension("leftmargindistance")
            showdimension("textwidth")
            showdimension("rightmargindistance")
            showdimension("rightmarginwidth")
            showdimension("rightedgedistance")
            showdimension("rightedgewidth")
            context.NR()
            showdimension("bodyfontsize")
            showdimension("lineheight")
            context.NR()
            showmacro("strutheightfactor")
            showmacro("strutdepthfactor")
            showmacro("topskipfactor")
            showmacro("maxdepthfactor")

        context.stoptabulate()

    end

end

function commands.showlayout(options)

    options = checkedoptions(options)

    if tex.count.textlevel == 0 then

        commands.showlayoutvariables(options)

    else

        context.page()
        context.bgroup()
        context.showframe()
        context.setuplayout { marking = interfaces.variables.on }
        for i=1,(options.n or 4) do
            commands.showlayoutvariables(options)
            context.page()
        end
        context.egroup()

    end

end


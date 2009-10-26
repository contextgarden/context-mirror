if not modules then modules = { } end modules ['x-ct'] = {
    version   = 1.001,
    comment   = "companion to x-ct.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local xmlsprint, xmlfilter, xmlcollected = xml.sprint, xml.filter, xml.collected
local texsprint, ctxcatcodes  = tex.sprint, tex.ctxcatcodes
local format, concat, rep = string.format, table.concat, string.rep

lxml.context = { }

local halignments = {
    left       = 'l',
    flushleft  = 'l',
    right      = 'r',
    flushright = 'r',
    center     = 'c',
    middle     = 'c',
    centre     = 'c',
    justify    = '',
}

local function roottemplate(root)
    local rt = root.at.template
    if rt then
        if not rt:find("|") then
            rt = rt:gsub(",","|")
        end
        if not rt:find("^|") then rt = "|" .. rt end
        if not rt:find("|$") then rt = rt .. "|" end
    end
    return rt
end

local function specifiedtemplate(root,templatespec)
    local template = { }
    for e in xmlcollected(root,templatespec) do
        local at = e.at
        local tm = halignments[at.align] or ""
        if toboolean(at.paragraph) then
            tm = tm .. "p"
        end
        template[#template+1] = tm
    end
    if #template > 0 then
        return "|" .. concat(template,"|") .. "|"
    else
        return nil
    end
end

local function autotemplate(root,rowspec,cellspec)
    local max = 0
    for e in xmlcollected(root,rowspec) do
        local n = xml.count(e,cellspec)
        if n > max then max = n end
    end
    if max == 2 then
        return "|l|p|"
    elseif max > 0 then
        return "|" .. rep("p|",max)
    else
        return nil
    end
end

local defaulttemplate = "|l|p|"

function lxml.context.tabulate(root,namespace)
    if not root then
        return
    else
        root = lxml.id(root)
    end

    local prefix = (namespace or "context") .. ":"

    local templatespec = "/" .. prefix .. "template" .. "/" .. prefix .. "column"
    local bodyrowspec  = "/" .. prefix .. "body" .. "/" .. prefix .. "row"
    local cellspec     = "/" .. prefix .. "cell"

    local template =
        roottemplate      (root) or
        specifiedtemplate (root,templatespec) or
        autotemplate      (root,bodyrowspec,cellspec) or
        defaulttemplate

    -- todo: head and foot

--~     lxml.directives.before(root,'cdx')
--~     texsprint(ctxcatcodes, "\\bgroup")
--~     lxml.directives.setup(root,'cdx')
--~     texsprint(ctxcatcodes, format("\\starttabulate[%s]",template))
--~     for e in xmlcollected(root,bodyrowspec) do
--~         texsprint(ctxcatcodes, "\\NC ")
--~         for e in xmlcollected(e,cellspec) do
--~             texsprint(xml.content(e)) -- use some xmlprint
--~             texsprint(ctxcatcodes, "\\NC")
--~         end
--~         texsprint(ctxcatcodes, "\\NR")
--~     end
--~     texsprint(ctxcatcodes, "\\stoptabulate")
--~     texsprint(ctxcatcodes, "\\egroup")
--~     lxml.directives.after(root,'cdx')

    local NC, NR = context.NC, context.NR

    lxml.directives.before(root,'cdx')
    context.bgroup()
    lxml.directives.setup(root,'cdx')
    context.starttabulate { template }
    for e in xmlcollected(root,bodyrowspec) do
        NC()
        for e in xmlcollected(e,cellspec) do
            texsprint(xml.content(e)) -- test: xmlcprint(e)
            NC()
        end
        NR()
    end
    context.stoptabulate()
    context.egroup()
    lxml.directives.after(root,'cdx')

end

function lxml.context.combination(root,namespace)

    if not root then
        return
    else
        root = lxml.id(root)
    end

    local prefix = (namespace or "context") .. ":"

    local pairspec    = "/" .. prefix .. "pair"
    local contentspec = "/" .. prefix .. "content" .. "/text()"
    local captionspec = "/" .. prefix .. "caption" .. "/text()"

    local nx, ny = root.at.nx, root.at.ny

    if not (nx or ny) then
        nx = xml.count(root,pairspec) or 2
    end
    local template = format("%s*%s", nx or 1, ny or 1)

    -- todo: alignments

--~     lxml.directives.before(root,'cdx')
--~     texsprint(ctxcatcodes, "\\bgroup")
--~     lxml.directives.setup(root,'cdx')
--~     texsprint(ctxcatcodes, "\\startcombination[",template,"]")
--~     for e in xmlcollected(root,pairspec) do
--~         texsprint(ctxcatcodes,"{")
--~         xmlfilter(e,contentspec)
--~         texsprint(ctxcatcodes,"}{")
--~         xmlfilter(e,captionspec)
--~         texsprint(ctxcatcodes,"}")
--~     end
--~     texsprint(ctxcatcodes, "\\stopcombination")
--~     texsprint(ctxcatcodes, "\\egroup")
--~     lxml.directives.after(root,'cdx')

    lxml.directives.before(root,'cdx')
    context.bgroup()
    lxml.directives.setup(root,'cdx')
    context.startcombination { template }
    for e in xmlcollected(root,pairspec) do
        texsprint(ctxcatcodes,"{")
        xmlfilter(e,contentspec)
        texsprint(ctxcatcodes,"}{")
        xmlfilter(e,captionspec)
        texsprint(ctxcatcodes,"}")
    end
    context.stopcombination()
    context.egroup()
    lxml.directives.after(root,'cdx')

end

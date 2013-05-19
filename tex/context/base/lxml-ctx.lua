if not modules then modules = { } end modules ['lxml-ctx'] = {
    version   = 1.001,
    comment   = "companion to lxml-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- is this still used?

local format, find = string.format, string.find

local xml = xml

xml.ctx           = { }
xml.ctx.enhancers = { }

-- hashen

function xml.ctx.enhancers.compound(root,lpath,before,tokens,after) -- todo lpeg
    local before  = before or "[%a%d][%a%d][%a%d]"
    local tokens  = tokens or "[%/%-]"
    local after   = after  or "[%a%d][%a%d][%a%d]"
    local pattern = "(" .. before .. ")(" .. tokens .. ")(" .. after .. ")"
    local action  = function(a,b,c)
        return a .. "<compound token=" .. format("%q",b) .. "/>" .. c -- formatters["%s<compound token=%q/>%s"](a,b,c)
    end
    xml.enhance(root,lpath,pattern,action) -- still present?
end

local loaded = { }

local nodesettostring = xml.nodesettostring

-- maybe use detokenize instead of \type

function xml.ctx.tshow(specification)
    local pattern = specification.pattern
    local xmlroot = specification.xmlroot
    local attribute = specification.attribute
    if context then
        local xmlpattern = pattern
        if not find(xmlpattern,"^[%a]+://") then
            xmlpattern = "xml://" .. pattern
        end
        local parsed = xml.lpath(xmlpattern)
        local titlecommand = specification.title or "type"
        if parsed.state then
            context[titlecommand]("pattern: " .. pattern .. " (".. parsed.state .. ")")
        else
            context[titlecommand]("pattern: " .. pattern)
        end
        context.starttabulate({ "|Tr|Tl|Tp|" } )
        if specification.warning then
            local comment = parsed.comment
            if comment then
                for k=1,#comment do
                    context.NC()
                    context("!")
                    context.NC()
                    context.rlap(comment[k])
                    context.NR()
                end
                context.TB()
            end
        end
        for p=1,#parsed do
            local pp = parsed[p]
            local kind = pp.kind
            context.NC()
            context(p)
            context.NC()
            context(kind)
            context.NC()
            if kind == "axis" then
                context(pp.axis)
            elseif kind == "nodes" then
                context(nodesettostring(pp.nodes,pp.nodetest))
            elseif kind == "expression" then
--~ context("%s => %s",pp.expression,pp.converted)
                context(pp.expression)
            elseif kind == "finalizer" then
                context("%s(%s)",pp.name,pp.arguments)
            elseif kind == "error" and pp.error then
                context(pp.error)
            end
            context.NC()
            context.NR()
        end
        context.stoptabulate()
        if xmlroot and xmlroot ~= "" then
            if not loaded[xmlroot] then
                loaded[xmlroot] = xml.convert(buffers.getcontent(xmlroot))
            end
            local collected = xml.filter(loaded[xmlroot],xmlpattern)
            if collected then
                local tc = type(collected)
                if not tc then
                    -- skip
                else
                    context.blank()
                    context.type("result : ")
                    if tc == "string" then
                        context.type(collected)
                    elseif tc == "table" then
                        if collected.tg then
                            collected  = { collected }
                        end
                        for c=1,#collected do
                            local cc = collected[c]
                            if attribute and attribute ~= "" then
                                local ccat = cc.at
                                local a = ccat and ccat[attribute]
                                if a and a ~= "" then
                                    context.type(a)
                                    context.type(">")
                                end
                            end
                            local ccns = cc.ns
                            if ccns == "" then
                                context.type(cc.tg)
                            else
                                context.type(ccns .. ":" .. cc.tg)
                            end
                            context.space()
                        end
                    else
                        context.type(tostring(tc))
                    end
                    context.blank()
                end
            end
        end
    end
end

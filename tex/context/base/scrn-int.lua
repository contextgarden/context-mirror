if not modules then modules = { } end modules ['scrn-int'] = {
    version   = 1.001,
    comment   = "companion to scrn-int.tex",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local format = string.format
local texsprint, texcount, ctxcatcodes = tex.sprint, tex.count, tex.ctxcatcodes

interactions = interactions or { }

local attachments = { }

function interactions.registerattachment(specification)
    if specification.label then
        specification.filename = specification.filename or specification.label
        specification.newname = specification.newname or specification.filename
        specification.title = specification.title or specification.filename
        specification.newname = file.addsuffix(specification.newname,file.extname(specification.filename))
        attachments[specification.label] = specification
        return specification
    end
end

function interactions.attachment(label)
    local at = attachments[label]
    if not at then
        interfaces.showmessage("interactions",6,label)
        return interactions.registerattachment { label = label }
    else
        return at
    end
end

function interactions.attachmentvar(label,key)
    local at = attachments[label]
    texsprint(ctxcatcodes,at and at[key] or "")
end

local soundclips = { }

function interactions.registersoundclip(specification)
    if specification.label then
        specification.filename = specification.filename or specification.label
        soundclips[specification.label] = specification
        return specification
    end
end

function interactions.soundclip(label)
    local sc = soundclips[label]
    if not sc then
        -- todo: message
        return interactions.registersoundclip { label = label }
    else
        return sc
    end
end

local renderings = { }

function interactions.registerrendering(specification)
    if specification.label then
        renderings[specification.label] = specification
        return specification
    end
end

function interactions.rendering(label)
    local rn = renderings[label]
    if not rn then
        -- todo: message
        return interactions.registerrendering { label = label }
    else
        return rn
    end
end

function interactions.renderingvar(label,key)
    local rn = renderings[label]
    texsprint(ctxcatcodes,rn and rn[key] or "")
end

-- linked lists

function interactions.definelinkedlist(name)
    -- no need
end

function interactions.addlinktolist(name)
    local tobesaved   = jobpasses.gettobesaved(name)
    local collected   = jobpasses.getcollected(name) or { }
    local currentlink = #tobesaved + 1
    local noflinks    = #collected
    tobesaved[currentlink] = 0
    local f = collected[1] or 0
    local l = collected[noflinks] or 0
    local p = collected[currentlink-1] or f
    local n = collected[currentlink+1] or l
    texsprint(ctxcatcodes,format("\\setlinkproperties{%s}{%s}{%s}{%s}{%s}{%s}",currentlink,noflinks,f,p,n,l))
end

function interactions.enhancelinkoflist(name,n)
    local ll = jobpasses.gettobesaved(name)
    if ll then
        ll[n] = texcount.realpageno
    end
end


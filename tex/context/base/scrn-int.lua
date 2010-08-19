if not modules then modules = { } end modules ['scrn-int'] = {
    version   = 1.001,
    comment   = "companion to scrn-int.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local format = string.format
local texsprint, texcount, ctxcatcodes = tex.sprint, tex.count, tex.ctxcatcodes

interactions       = interactions or { }
local interactions = interactions

interactions.attachments = interactions.attachments or { }
interactions.soundclips  = interactions.soundclips  or { }
interactions.renderings  = interactions.renderings  or { }
interactions.linkedlists = interactions.linkedlists or { }

local attachments = interactions.attachments
local soundclips  = interactions.soundclips
local renderings  = interactions.renderings
local linkedlists = interactions.linkedlists

local jobpasses   = job.passes

function attachments.register(specification)
    if specification.label then
        specification.filename = specification.filename or specification.label
        specification.newname = specification.newname or specification.filename
        specification.title = specification.title or specification.filename
        specification.newname = file.addsuffix(specification.newname,file.extname(specification.filename))
        attachments[specification.label] = specification
        return specification
    end
end

function attachments.attachment(label)
    local at = attachments[label]
    if not at then
        interfaces.showmessage("interactions",6,label)
        return attachments.register { label = label }
    else
        return at
    end
end

function attachments.var(label,key)
    local at = attachments[label]
    texsprint(ctxcatcodes,at and at[key] or "")
end

function soundclips.register(specification)
    if specification.label then
        specification.filename = specification.filename or specification.label
        soundclips[specification.label] = specification
        return specification
    end
end

function soundclips.soundclip(label)
    local sc = soundclips[label]
    if not sc then
        -- todo: message
        return soundclips.register { label = label }
    else
        return sc
    end
end

function renderings.register(specification)
    if specification.label then
        renderings[specification.label] = specification
        return specification
    end
end

function renderings.rendering(label)
    local rn = renderings[label]
    if not rn then
        -- todo: message
        return renderings.register { label = label }
    else
        return rn
    end
end

function renderings.var(label,key)
    local rn = renderings[label]
    texsprint(ctxcatcodes,rn and rn[key] or "")
end

-- linked lists

function linkedlists.define(name)
    -- no need
end

function linkedlists.add(name)
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

function linkedlists.enhance(name,n)
    local ll = jobpasses.gettobesaved(name)
    if ll then
        ll[n] = texcount.realpageno
    end
end

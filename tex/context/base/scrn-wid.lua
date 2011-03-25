if not modules then modules = { } end modules ['scrn-wid'] = {
    version   = 1.001,
    comment   = "companion to scrn-wid.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

interactions             = interactions or { }
local interactions       = interactions

local attachments        = { }
local comments           = { }
local soundclips         = { }
local renderings         = { }
local linkedlists        = { }

interactions.attachments = attachments
interactions.soundclips  = soundclips
interactions.renderings  = renderings
interactions.linkedlists = linkedlists

local jobpasses          = job.passes

local codeinjections     = backends.codeinjections
local nodeinjections     = backends.nodeinjections

local variables          = interfaces.variables
local v_auto             = variables.auto

-- Symbols

function commands.presetsymbollist(list)
    codeinjections.presetsymbollist(list)
end

-- Attachments
--
-- registered : unique id
-- tag        : used at the tex end
-- file       : name that the file has on the filesystem
-- name       : name that the file will get in the output
-- title      : up to the backend
-- subtitle   : up to the backend
-- author     : up to the backend
-- method     : up to the backend (hidden == no rendering)

local nofautoattachments, lastregistered = 0, nil

local function checkregistered(specification)
    local registered = specification.registered
    if not registered or registered == "" or registered == v_auto then
        nofautoattachments = nofautoattachments + 1
        lastregistered = "attachment-" .. nofautoattachments
        specification.registered = lastregistered
        return lastregistered
    else
        return registered
    end
end

local function checkbuffer(specification)
    local buffer = specification.buffer
    if buffer ~= "" then
        specification.data = buffers.getcontent(buffer) or "<no data>"
    end
end

function attachments.register(specification)
    checkregistered(specification)
    checkbuffer(specification)
    attachments[lastregistered] = specification
    return specification
end

function attachments.insert(specification)
    local registered = checkregistered(specification)
    local r = attachments[registered]
    if r then
        for k, v in next, r do
            local s = specification[k]
            if s == "" then
                specification[k] = v
            end
        end
    end
    checkbuffer(specification)
    return nodeinjections.attachfile(specification)
end

commands.registerattachment = attachments.register

function commands.insertattachment(specification)
    tex.box["scrn_attachment_box_link"] = attachments.insert(specification)
end

-- Comment

function comments.insert(specification)
    local buffer = specification.buffer
    if buffer ~= "" then
        specification.data = buffers.getcontent(buffer) or ""
    end
    return nodeinjections.comment(specification)
end

function commands.insertcomment(specification)
    tex.box["scrn_comment_box_link"] = comments.insert(specification)
end

-- Soundclips

function soundclips.register(specification)
    local tag = specification.tag
    if tag and tag ~= "" then
        local filename = specification.file
        if not filename or filename == "" then
            filename = tag
            specification.file = filename
        end
        soundclips[tag] = specification
        return specification
    end
end

function soundclips.insert(tag)
    local sc = soundclips[tag]
    if not sc then
        -- todo: message
        return soundclips.register { tag = tag }
    else
        return sc
    end
end

commands.registersoundclip = soundclips.register
commands.insertsoundclip   = soundclips.insert

-- Renderings

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
    context(rn and rn[key] or "")
end

-- Rendering:

function commands.insertrenderingwindow(specification)
    codeinjections.insertrenderingwindow(specification)
end

-- Linkedlists (only a context interface)

function commands.definelinkedlist(tag)
    -- no need
end

function commands.enhancelinkedlist(tag,n)
    local ll = jobpasses.gettobesaved(tag)
    if ll then
        ll[n] = texcount.realpageno
    end
end

function commands.addlinklistelement(tag)
    local tobesaved   = jobpasses.gettobesaved(tag)
    local collected   = jobpasses.getcollected(tag) or { }
    local currentlink = #tobesaved + 1
    local noflinks    = #collected
    tobesaved[currentlink] = 0
    local f = collected[1] or 0
    local l = collected[noflinks] or 0
    local p = collected[currentlink-1] or f
    local n = collected[currentlink+1] or l
    context.setlinkedlistproperties(currentlink,noflinks,f,p,n,l)
 -- context.ctxlatelua(function() commands.enhancelinkedlist(tag,currentlink) end)
end

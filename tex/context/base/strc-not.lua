if not modules then modules = { } end modules ['strc-not'] = {
    version   = 1.001,
    comment   = "companion to strc-not.tex",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local format = string.format
local next = next
local texsprint, texwrite = tex.sprint, tex.write

local ctxcatcodes = tex.ctxcatcodes

structure              = structure          or { }
structure.helpers      = structure.helpers  or { }
structure.lists        = structure.lists    or { }
structure.sections     = structure.sections or { }
structure.counters     = structure.counters or { }
structure.notes        = structure.notes    or { }

structure.notes.states    = structure.notes.states    or { }
structure.lists.enhancers = structure.lists.enhancers or { }

storage.register("structure/notes/states", structure.notes.states, "structure.notes.states")

local helpers  = structure.helpers
local lists    = structure.lists
local sections = structure.sections
local counters = structure.counters
local notes    = structure.notes

local notestates = structure.notes.states
local notedata   = { }

-- state: store, insert, postpone

function notes.store(tag,n)
    local nd = notedata[tag]
    if not nd then
        nd = { }
        notedata[tag] = nd
    end
    nd[#nd+1] = n
    local state = notestates[tag]
    if state.kind ~= "insert" then
--~         state.start = #nd
        state.start = state.start or #nd
    end
    tex.write(#nd)
end

function notes.get(tag,n)
    local nd = notedata[tag]
    if nd then
        nd = nd[n or #notedata]
        if nd then
            return structure.lists.collected[nd]
        end
    end
end

function notes.define(tag,kind,number)
    local state = notes.setstate(tag,kind)
    state.number = number
end

function notes.save(tag,newkind)
    local state = notestates[tag]
    if state and not state.saved then
        state.saved = notedata[tag]
        state.savedkind = state.kind
        state.kind = newkind or state.kind
        notedata[tag] = { }
    end
end

function notes.restore(tag)
    local state = notestates[tag]
    if state and state.saved then
        state.saved = nil
        state.kind = state.savedkind
        notedata[tag] = state.saved
    end
end

function notes.setstate(tag,newkind)
    local state = notestates[tag]
    if not state then
        state = {
            kind = newkind
        }
        notestates[tag] = state
    elseif newkind == "insert" then
        if not state.start then
            state.kind = newkind
        end
    else
        state.kind = newkind
    end
    return state
end

function notes.getstate(tag)
    local state = notestates[tag]
    texsprint(ctxcatcodes,(state and state.kind ) or "unknown")
end

function notes.doifcontent(tag)
    local ok = notestates[tag]
    if ok then
        if ok.kind == "insert" then
            ok = tex.box[ok.number]
            if ok then
                ok = tbs.list
                ok = lst and lst.next
            end
        else
            ok = ok.start
        end
    end
    commands.doif(ok)
end

local function internal(tag,n)
    local nd = notes.get(tag,n)
    if nd then
        local r = nd.references
        if r then
            local i = r.internal
            return i and lists.internals[i]
        end
    end
    return nil
end

local function ordered(kind,name,n)
    local o = lists.ordered[kind]
    o = o and o[name]
    return o and o[n]
end

function notes.checkpagechange(tag) -- called before increment !
    local nd = notedata[tag] -- can be unset at first entry
    if nd then
        local current = ordered("note",tag,#nd)
        local nextone = ordered("note",tag,#nd+1)
        if nextone then
            -- we can use data from the previous pass
            if nextone.pagenumber.number > current.pagenumber.number then
                counters.reset(tag)
            end
        elseif current then
            -- we need to locate the next one, best guess
            if tex.count[0] > current.pagenumber.number then
                counters.reset(tag)
            end
        end
    end
end

function notes.deltapage(tag,n)
    -- 0:unknown 1:textbefore, 2:textafter, 3:samepage
    local what = 0
    local li = internal(tag,n)
    if li then
        local metadata, pagenumber = li.metadata, li.pagenumber
        if metadata and pagenumber then
            local symbolpage = metadata.symbolpage or 0
            local notepage = pagenumber.number or 0
            if notepage > 0 and symbolpage > 0 then
                if notepage < symbolpage then
                    what = 1
                elseif notepage > symbolpage then
                    what = 2
                else
                    what = 3
                end
            end
        else
            -- might be a note that is not flushed due to to deep
            -- nesting in a vbox
            what = 3
        end
    end
    tex.write(what)
end

function notes.postpone()
    for tag, state in next, notestates do
        if state.kind ~= "store" then
            notes.setstate(tag,"postpone")
        end
    end
end

function notes.setsymbolpage(tag,n)
    local nd = notes.get(tag,n)
    if nd then
        nd.metadata.symbolpage = tex.count[0] -- realpage
    end
end

function notes.getsymbolpage(tag,n)
    local nd = notes.get(tag,n)
    nd = nd and nd.metadata.symbolpage
    texwrite(nd or 0)
end

function notes.getnumberpage(tag,n)
    local li = internal(tag,n)
    li = li and li.pagenumber
    li = li and li.numbers
    li = li and li[1]
    texwrite(li or 0)
end

function notes.flush(tag,whatkind) -- store and postpone
    local nd = notedata[tag]
    if nd then
        local state = notestates[tag]
        local ns = state and state.start -- first index
        if ns then
            local kind = state.kind
            if kind == whatkind then
                if kind == "postpone" then
                    for i=ns,#nd do
                        texsprint(ctxcatcodes,format("\\handlenoteinsert{%s}{%s}",tag,i))
                    end
                    state.start = nil
                    state.kind = "insert"
                elseif kind == "store" then
                    for i=ns,#nd do
                        texsprint(ctxcatcodes,format("\\handlenoteitself{%s}{%s}",tag,i))
                    end
                    state.start = nil
                end
            end
        end
    end
end

function notes.title(tag,n)
    structure.lists.savedtitle(tag,notedata[tag][n])
end

function notes.number(tag,n,spec)
    structure.lists.savedprefixednumber(tag,notedata[tag][n])
end

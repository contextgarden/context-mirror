if not modules then modules = { } end modules ['strc-not'] = {
    version   = 1.001,
    comment   = "companion to strc-not.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local format = string.format
local next = next
local texcount = tex.count

local trace_notes = false  trackers.register("structures.notes", function(v) trace_notes = v end)

local report_notes = logs.new("structure","notes")

local structures = structures
local helpers    = structures.helpers
local lists      = structures.lists
local sections   = structures.sections
local counters   = structures.counters
local notes      = structures.notes
local references = structures.references

notes.states     = notes.states or { }
lists.enhancers  = lists.enhancers or { }

storage.register("structures/notes/states", notes.states, "structures.notes.states")

local notestates = notes.states
local notedata   = { }

local variables  = interfaces.variables
local context    = context

-- state: store, insert, postpone

function notes.store(tag,n)
    local nd = notedata[tag]
    if not nd then
        nd = { }
        notedata[tag] = nd
    end
    local nnd = #nd + 1
    nd[nnd] = n
    local state = notestates[tag]
    if state.kind ~= "insert" then
        if trace_notes then
            report_notes("storing %s with state %s as %s",tag,state.kind,nnd)
        end
        state.start = state.start or nnd
    end
    context(#nd)
end

local function get(tag,n)
    local nd = notedata[tag]
    if nd then
        n = n or #nd
        nd = nd[n]
        if nd then
            if trace_notes then
                report_notes("getting note %s of '%s'",n,tag)
            end
            -- is this right?
            local newdata = lists.collected[nd]
            return newdata
        end
    end
end

local function getn(tag)
    local nd = notedata[tag]
    return (nd and #nd) or 0
end

notes.get = get
notes.getn = getn

-- we could make a special enhancer

function notes.listindex(tag,n)
    local ndt = notedata[tag]
    return ndt and ndt[n]
end

function notes.define(tag,kind,number)
    local state = notes.setstate(tag,kind)
    state.number = number
end

function notes.save(tag,newkind)
    local state = notestates[tag]
    if state and not state.saved then
        if trace_notes then
            report_notes("saving state of '%s': %s -> %s",tag,state.kind,newkind or state.kind)
        end
        state.saveddata = notedata[tag]
        state.savedkind = state.kind
        state.kind = newkind or state.kind
        state.saved = true
        notedata[tag] = { }
    end
end

function notes.restore(tag,forcedstate)
    local state = notestates[tag]
    if state and state.saved then
        if trace_notes then
            report_notes("restoring state of '%s': %s -> %s",tag,state.kind,state.savedkind)
        end
        notedata[tag] = state.saveddata
        state.kind = forcedstate or state.savedkind
        state.saveddata = nil
        state.saved = false
    end
end

function notes.setstate(tag,newkind)
    local state = notestates[tag]
    if trace_notes then
        report_notes("setting state of '%s' from %s to %s",tag,(state and state.kind) or "unset",newkind)
    end
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
    --  state.start can already be set and will be set when an entry is added or flushed
    return state
end

function notes.getstate(tag)
    local state = notestates[tag]
    context(state and state.kind or "unknown")
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
    local nd = get(tag,n)
    if nd then
        local r = nd.references
        if r then
            local i = r.internal
--~             return i and lists.internals[i]
            return i and references.internals[i] -- dependency on references
        end
    end
    return nil
end

local function ordered(kind,name,n)
    local o = lists.ordered[kind]
    o = o and o[name]
    return o and o[n]
end

notes.internal = internal
notes.ordered  = ordered

function notes.doifonsamepageasprevious(tag)
    local same = false
    local n = getn(tag,n)
    local current, previous = get(tag,n), get(tag,n-1)
    if current and previous then
        local cr, pr = current.references, previous.references
        same = cr and pr and cr.realpage == pr.realpage
    end
    commands.doifelse(same)
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
            if texcount.realpageno > current.pagenumber.number then
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
            local symbolpage = references.symbolpage or 0
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
    context(what)
end

function notes.postpone()
    if trace_notes then
        report_notes("postponing all insert notes")
    end
    for tag, state in next, notestates do
        if state.kind ~= "store" then
            notes.setstate(tag,"postpone")
        end
    end
end

function notes.setsymbolpage(tag,n,l)
    local l = l or notes.listindex(tag,n)
    if l then
        local p = texcount.realpageno
        if trace_notes then
            report_notes("note %s of '%s' with list index %s gets page %s",n,tag,l,p)
        end
        lists.cached[l].references.symbolpage = p
    else
        report_notes("internal error: note %s of '%s' is not initialized",n,tag)
    end
end

function notes.getsymbolpage(tag,n)
    local nd = get(tag,n)
    local p = nd and nd.references.symbolpage or 0
    if trace_notes then
        report_notes("page number of note symbol %s of '%s' is %s",n,tag,p)
    end
    context(p)
end

function notes.getnumberpage(tag,n)
    local li = internal(tag,n)
    li = li and li.references
    li = li and li.realpage or 0
    if trace_notes then
        report_notes("page number of note number %s of '%s' is %s",n,tag,li)
    end
    context(li)
end

function notes.flush(tag,whatkind,how) -- store and postpone
    local state = notestates[tag]
    local kind = state.kind
    if kind == whatkind then
        local nd = notedata[tag]
        local ns = state.start -- first index
        if kind == "postpone" then
            if nd and ns then
                if trace_notes then
                    report_notes("flushing state %s of %s from %s to %s",whatkind,tag,ns,#nd)
                end
                for i=ns,#nd do
                    context.handlenoteinsert(tag,i)
                end
            end
            state.start = nil
            state.kind = "insert"
        elseif kind == "store" then
            if nd and ns then
                if trace_notes then
                    report_notes("flushing state %s of %s from %s to %s",whatkind,tag,ns,#nd)
                end
                -- todo: as registers: start, stop, inbetween
                for i=ns,#nd do
                    -- tricky : trialtypesetting
                    if how == variables.page then
                        local rp = get(tag,i)
                        rp = rp and rp.references
                        rp = rp and rp.symbolpage or 0
                        if rp > texcount.realpageno then
                            state.start = i
                            return
                        end
                    end
                    if i > ns then
                        context.betweennoteitself(tag)
                    end
                    context.handlenoteitself(tag,i)
                end
            end
            state.start = nil
        elseif kind == "reset" then
            if nd and ns then
                if trace_notes then
                    report_notes("flushing state %s of %s from %s to %s",whatkind,tag,ns,#nd)
                end
            end
            state.start = nil
        elseif trace_notes then
            report_notes("not flushing state %s of %s",whatkind,tag)
        end
    elseif trace_notes then
        report_notes("not flushing state %s of %s",whatkind,tag)
    end
end

function notes.flushpostponed()
    if trace_notes then
        report_notes("flushing all postponed notes")
    end
    for tag, _ in next, notestates do
        notes.flush(tag,"postpone")
    end
end

function notes.resetpostponed()
    if trace_notes then
        report_notes("resetting all postponed notes")
    end
    for tag, state in next, notestates do
        if state.kind == "postpone" then
            state.start = nil
            state.kind = "insert"
        end
    end
end

function notes.title(tag,n)
    lists.savedtitle(tag,notedata[tag][n])
end

function notes.number(tag,n,spec)
    lists.savedprefixednumber(tag,notedata[tag][n])
end

function notes.internalid(tag,n)
    local nd = get(tag,n)
    if nd then
        local r = nd.references
        return r.internal
    end
end

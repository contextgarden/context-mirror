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

local trace_notes      = false  trackers.register("structures.notes",            function(v) trace_notes      = v end)
local trace_references = false  trackers.register("structures.notes.references", function(v) trace_references = v end)

local report_notes     = logs.reporter("structure","notes")

local structures       = structures
local helpers          = structures.helpers
local lists            = structures.lists
local sections         = structures.sections
local counters         = structures.counters
local notes            = structures.notes
local references       = structures.references
local counterspecials  = counters.specials

notes.states           = notes.states or { }
lists.enhancers        = lists.enhancers or { }

storage.register("structures/notes/states", notes.states, "structures.notes.states")

local notestates = notes.states
local notedata   = { }

local variables  = interfaces.variables
local context    = context
local commands   = commands

-- state: store, insert, postpone

local function store(tag,n)
    -- somewhat weird but this is a cheap hook spot
    if not counterspecials[tag] then
        counterspecials[tag] = function(tag)
            context.doresetlinenotecompression(tag) -- maybe flag that controls it
        end
    end
    --
    local nd = notedata[tag]
    if not nd then
        nd = { }
        notedata[tag] = nd
    end
    local nnd = #nd + 1
    nd[nnd] = n
    local state = notestates[tag]
    if not state then
        report_notes("unknown state for %a",tag)
    elseif state.kind ~= "insert" then
        if trace_notes then
            report_notes("storing %a with state %a as %a",tag,state.kind,nnd)
        end
        state.start = state.start or nnd
    end
    return #nd
end

notes.store = store

function commands.storenote(tag,n)
    context(store(tag,n))
end

local function get(tag,n) -- tricky ... only works when defined
    local nd = notedata[tag]
    if nd then
        n = n or #nd
        nd = nd[n]
        if nd then
            if trace_notes then
                report_notes("getting note %a of %a with listindex %a",n,tag,nd)
            end
            -- is this right?
--             local newdata = lists.collected[nd]
            local newdata = lists.cached[nd]
--             local newdata = lists.tobesaved[nd]
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

local function listindex(tag,n)
    local ndt = notedata[tag]
    return ndt and ndt[n]
end

notes.listindex = listindex

function commands.notelistindex(tag,n)
    context(listindex(tag,n))
end

local function setstate(tag,newkind)
    local state = notestates[tag]
    if trace_notes then
        report_notes("setting state of %a from %s to %s",tag,(state and state.kind) or "unset",newkind)
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
-- if newkind == "postpone" and state.kind == "store" then
-- else
        state.kind = newkind
-- end
    end
    --  state.start can already be set and will be set when an entry is added or flushed
    return state
end

local function getstate(tag)
    local state = notestates[tag]
    return state and state.kind or "unknown"
end

notes.setstate        = setstate
notes.getstate        = getstate

commands.setnotestate = setstate

function commands.getnotestate(tag)
    context(getstate(tag))
end

function notes.define(tag,kind,number)
    local state = setstate(tag,kind)
    state.number = number
end

commands.definenote = notes.define

function notes.save(tag,newkind)
    local state = notestates[tag]
    if state and not state.saved then
        if trace_notes then
            report_notes("saving state of %a, old: %a, new %a",tag,state.kind,newkind or state.kind)
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
            report_notes("restoring state of %a, old: %a, new: %a",tag,state.kind,state.savedkind)
        end
        notedata[tag] = state.saveddata
        state.kind = forcedstate or state.savedkind
        state.saveddata = nil
        state.saved = false
    end
end

commands.savenote    = notes.save
commands.restorenote = notes.restore

local function hascontent(tag)
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
    return ok and true or false
end

notes.hascontent = hascontent

function commands.doifnotecontent(tag)
    commands.doif(hascontent(tag))
end

local function internal(tag,n)
    local nd = get(tag,n)
    if nd then
        local r = nd.references
        if r then
            local i = r.internal
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

local function onsamepageasprevious(tag)
    local same = false
    local n = getn(tag,n)
    local current, previous = get(tag,n), get(tag,n-1)
    if current and previous then
        local cr, pr = current.references, previous.references
        same = cr and pr and cr.realpage == pr.realpage
    end
    return same and true or false
end

notes.doifonsamepageasprevious = onsamepageasprevious

function commands.doifnoteonsamepageasprevious(tag)
    commands.doifelse(onsamepageasprevious(tag))
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

function notes.postpone()
    if trace_notes then
        report_notes("postponing all insert notes")
    end
    for tag, state in next, notestates do
        if state.kind ~= "store" then
            setstate(tag,"postpone")
        end
    end
end

commands.postponenotes = notes.postpone

function notes.setsymbolpage(tag,n,l)
    local l = l or listindex(tag,n)
    if l then
        local p = texcount.realpageno
        if trace_notes or trace_references then
            report_notes("note %a of %a with list index %a gets symbol page %a",n,tag,l,p)
        end
        local entry = lists.cached[l]
        if entry then
            entry.references.symbolpage = p
        else
            report_notes("internal error: note %a of %a is not flushed",n,tag)
        end
    else
        report_notes("internal error: note %a of %a is not initialized",n,tag)
    end
end

commands.setnotesymbolpage = notes.setsymbolpage

local function getsymbolpage(tag,n)
    local li = internal(tag,n)
    li = li and li.references
    li = li and (li.symbolpage or li.realpage) or 0
    if trace_notes or trace_references then
        report_notes("page number of note symbol %a of %a is %a",n,tag,li)
    end
    return li
end

local function getnumberpage(tag,n)
    local li = internal(tag,n)
    li = li and li.references
    li = li and li.realpage or 0
    if trace_notes or trace_references then
        report_notes("page number of note number %s of %a is %a",n,tag,li)
    end
    return li
end

local function getdeltapage(tag,n)
    -- 0:unknown 1:textbefore, 2:textafter, 3:samepage
    local what = 0
 -- references.internals[lists.tobesaved[nd].internal]
    local li = internal(tag,n)
    if li then
        local references = li.references
        if references then
            local symbolpage = references.symbolpage or 0
            local notepage   = references.realpage   or 0
            if trace_references then
                report_notes("note number %a of %a points from page %a to page %a",n,tag,symbolpage,notepage)
            end
            if notepage < symbolpage then
                what = 3 -- after
            elseif notepage > symbolpage then
                what = 2 -- before
            elseif notepage > 0 then
                what = 1 -- same
            end
        else
            -- might be a note that is not flushed due to to deep
            -- nesting in a vbox
        end
    end
    return what
end

notes.getsymbolpage = getsymbolpage
notes.getnumberpage = getnumberpage
notes.getdeltapage  = getdeltapage

function commands.notesymbolpage(tag,n) context(getsymbolpage(tag,n)) end
function commands.notenumberpage(tag,n) context(getnumberpage(tag,n)) end
function commands.notedeltapage (tag,n) context(getdeltapage (tag,n)) end

function commands.flushnotes(tag,whatkind,how) -- store and postpone
    local state = notestates[tag]
    local kind = state.kind
    if kind == whatkind then
        local nd = notedata[tag]
        local ns = state.start -- first index
        if kind == "postpone" then
            if nd and ns then
                if trace_notes then
                    report_notes("flushing state %a of %a from %a to %a",whatkind,tag,ns,#nd)
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
                    report_notes("flushing state %a of %a from %a to %a",whatkind,tag,ns,#nd)
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
                    report_notes("flushing state %a of %a from %a to %a",whatkind,tag,ns,#nd)
                end
            end
            state.start = nil
        elseif trace_notes then
            report_notes("not flushing state %a of %a",whatkind,tag)
        end
    elseif trace_notes then
        report_notes("not flushing state %a of %a",whatkind,tag)
    end
end

function commands.flushpostponednotes()
    if trace_notes then
        report_notes("flushing all postponed notes")
    end
    for tag, _ in next, notestates do
        commands.flushnotes(tag,"postpone")
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

function commands.notetitle(tag,n)
    command.savedlisttitle(tag,notedata[tag][n])
end

function commands.noteprefixednumber(tag,n,spec)
    commands.savedlistprefixednumber(tag,notedata[tag][n])
end

function notes.internalid(tag,n)
    local nd = get(tag,n)
    if nd then
        local r = nd.references
        return r.internal
    end
end

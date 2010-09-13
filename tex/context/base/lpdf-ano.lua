if not modules then modules = { } end modules ['lpdf-ano'] = {
    version   = 1.001,
    comment   = "companion to lpdf-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local next, tostring = next, tostring
local rep, format = string.rep, string.format
local texcount = tex.count

local backends, lpdf = backends, lpdf

local trace_references   = false  trackers.register("references.references",   function(v) trace_references   = v end)
local trace_destinations = false  trackers.register("references.destinations", function(v) trace_destinations = v end)
local trace_bookmarks    = false  trackers.register("references.bookmarks",    function(v) trace_bookmarks    = v end)

local report_references   = logs.new("references")
local report_destinations = logs.new("destinations")
local report_bookmarks    = logs.new("bookmarks")

local variables = interfaces.variables
local constants = interfaces.constants

local settings_to_array = utilities.parsers.settings_to_array

local nodeinjections      = backends.pdf.nodeinjections
local codeinjections      = backends.pdf.codeinjections
local registrations       = backends.pdf.registrations

local javascriptcode      = interactions.javascripts.code

local references          = structures.references
local bookmarks           = structures.bookmarks
local references          = structures.references

local runners             = references.runners
local specials            = references.specials
local handlers            = references.handlers
local executers           = references.executers

local nodepool            = nodes.pool

local pdfannotation_node  = nodepool.pdfannotation
local pdfdestination_node = nodepool.pdfdestination
local latelua_node        = nodepool.latelua

local pdfdictionary           = lpdf.dictionary
local pdfarray                = lpdf.array
local pdfreference            = lpdf.reference
local pdfunicode              = lpdf.unicode
local pdfconstant             = lpdf.constant
local pdfflushobject          = lpdf.flushobject
local pdfshareobjectreference = lpdf.shareobjectreference
local pdfimmediateobject      = lpdf.immediateobject
local pdfreserveobject        = lpdf.reserveobject
local pdfpagereference        = lpdf.pagereference
local pdfdelayedobject        = lpdf.delayedobject
local pdfregisterannotation   = lpdf.registerannotation

local pdf_annot      = pdfconstant("Annot")
local pdf_uri        = pdfconstant("URI")
local pdf_gotor      = pdfconstant("GoToR")
local pdf_goto       = pdfconstant("GoTo")
local pdf_launch     = pdfconstant("Launch")
local pdf_javascript = pdfconstant("JavaScript")
local pdf_link       = pdfconstant("Link")
local pdf_n          = pdfconstant("N")
local pdf_t          = pdfconstant("T")
local pdf_fit        = pdfconstant("Fit")
local pdf_named      = pdfconstant("Named")

local pdf_border     = pdfarray { 0, 0, 0 }

local getinnermethod = references.getinnermethod

local cache = { }

local function pagedestination(n) -- only cache fit
    if n > 0 then
        local pd = cache[n]
        if not pd then
            local a = pdfarray {
                pdfreference(pdfpagereference(n)),
                pdf_fit,
            }
            pd = pdfshareobjectreference(a)
            cache[n] = pd
        end
        return pd
    end
end

lpdf.pagedestination = pagedestination

local defaultdestination = pdfarray { 0, pdf_fit }

local function link(url,filename,destination,page,actions)
    if filename and filename ~= "" then
        if file.basename(filename) == tex.jobname then
            return false
        else
            filename = file.addsuffix(filename,"pdf")
        end
    end
    if url and url ~= "" then
        if filename and filename ~= "" then
            if destination and destination ~= "" then
                url = file.join(url,filename).."#"..destination
            else
                url = file.join(url,filename)
            end
        end
        return pdfdictionary {
            S = pdf_uri,
            URI = url,
        }
    elseif filename and filename ~= "" then
        -- no page ?
        if destination == "" then
            destination = nil
        end
        if not destination and page then
            destination = pdfarray { page - 1, pdf_fit }
        end
        return pdfdictionary {
            S = pdf_gotor, -- can also be pdf_launch
            F = filename,
            D = destination or defaultdestination, -- D is mandate
            NewWindow = (actions.newwindow and true) or nil,
        }
    elseif destination and destination ~= "" then
        local realpage, p = texcount.realpageno, tonumber(page)
        if not p then
            -- sorry
        elseif p > realpage then
            texcount.referencepagestate = 3
        elseif p < realpage then
            texcount.referencepagestate = 2
        else
            texcount.referencepagestate = 1
        end
        return pdfdictionary { -- can be cached
            S = pdf_goto,
            D = destination,
        }
    elseif page and page ~= "" then
        local realpage, p = texcount.realpageno, tonumber(page)
        if p then
            if p > realpage then
                texcount.referencepagestate = 3
            elseif p < realpage then
                texcount.referencepagestate = 2
            else
                texcount.referencepagestate = 1
            end
            if p > 0 then
                --~ return gotopagedestination(p)
                --~ return pdfdictionary { -- can be cached
                --~     S = pdf_goto,
                --~     D = pagedestination(p),
                --~ }
                return pdfdictionary { -- can be cached
                    S = pdf_goto,
                    D = pdfarray {
                        pdfreference(pdfpagereference(p)),
                        pdf_fit,
                    }
                }
            end
        else
            commands.writestatus("references","invalid page reference: %s",page or "?")
        end
    end
    return false
end

lpdf.link = link

function lpdf.launch(program,parameters)
    if program and program ~= "" then
        local d = pdfdictionary {
            S = pdf_launch,
            F = program,
            D = ".",
        }
        if parameters and parameters ~= "" then
            d.P = parameters
        end
        return d
    end
end

function lpdf.javascript(name,arguments)
    local script = javascriptcode(name,arguments) -- make into object (hash)
    if script then
        return pdfdictionary {
            S  = pdf_javascript,
            JS = script,
        }
    end
end

local function pdfaction(actions)
    local nofactions = #actions
    texcount.referencepagestate = 0 -- goodie, as we do all in the backend, we need to set it here too
    if nofactions > 0 then
        local a = actions[1]
        local action = runners[a.kind]
        if action then
            action = action(a,actions)
        end
        if action then
            local first = action
            for i=2,nofactions do
                local a = actions[i]
                local what = runners[a.kind]
                if what then
                    what = what(a,actions)
                end
                if what then
                    action.next = what
                    action = what
                else
                    -- error
                    return nil
                end
            end
            return first
        end
    end
end

lpdf.action = pdfaction

function codeinjections.prerollreference(actions) -- share can become option
    local main = actions and pdfaction(actions)
    if main then
         main = pdfdictionary {
            Subtype = pdf_link,
            Border  = pdf_border,
            H       = (not actions.highlight and pdf_n) or nil,
            A       = pdfshareobjectreference(main),
            F       = 4, -- print (mandate in pdf/a)
        }
        return main("A")
    end
end

local function use_normal_annotations()

    local function reference(width,height,depth,prerolled) -- keep this one
        if prerolled then
            if trace_references then
                report_references("w=%s, h=%s, d=%s, a=%s",width,height,depth,prerolled)
            end
            return pdfannotation_node(width,height,depth,prerolled)
        end
    end

    local function finishreference()
    end

    return reference, finishreference

end

-- evenrually we can do this for special refs only

local hashed, nofunique, nofused = { }, 0, 0

local function use_shared_annotations()

    local factor = number.dimenfactors.bp

    local function finishreference(width,height,depth,prerolled) -- %0.2f looks okay enough (no scaling anyway)
        local h, v = pdf.h, pdf.v
        local llx, lly = h*factor, (v - depth)*factor
        local urx, ury = (h + width)*factor, (v + height)*factor
        local annot = format("<< /Type /Annot %s /Rect [%0.2f %0.2f %0.2f %0.2f] >>",prerolled,llx,lly,urx,ury)
        local n = hashed[annot]
        if not n then
            n = pdfdelayedobject(annot)
            hashed[annot] = n
            nofunique = nofunique + 1
        end
        nofused = nofused + 1
        pdfregisterannotation(n)
    end

    _bpnf_ = finishreference

    local function reference(width,height,depth,prerolled)
        if prerolled then
            if trace_references then
                report_references("w=%s, h=%s, d=%s, a=%s",width,height,depth,prerolled)
            end
            local luacode = format("_bpnf_(%s,%s,%s,'%s')",width,height,depth,prerolled)
            return latelua_node(luacode)
        end
    end

    statistics.register("pdf annotations", function()
        if nofused > 0 then
         -- table.print(hashed,"hashed_annotations")
            return string.format("%s embedded, %s unique",nofused,nofunique)
        else
            return nil
        end
    end)


    return reference, finishreference

end

local lln = latelua_node()  if node.has_field(lln,'string') then

    directives.register("refences.sharelinks", function(v)
        if v then
            backends.nodeinjections.reference, backends.codeinjections.finishreference = use_shared_annotations()
        else
            backends.nodeinjections.reference, backends.codeinjections.finishreference = use_normal_annotations()
        end
    end)

    nodeinjections.reference, codeinjections.finishreference = use_shared_annotations()

else

    nodeinjections.reference, codeinjections.finishreference = use_normal_annotations()

end  node.free(lln)

-- -- -- --
-- -- -- --



function nodeinjections.destination(width,height,depth,name,view)
    if trace_destinations then
        report_destinations("w=%s, h=%s, d=%s, n=%s, v=%s",width,height,depth,name,view or "no view")
    end
    return pdfdestination_node(width,height,depth,name,view)
end

-- runners and specials

runners["inner"] = function(var,actions)
    if getinnermethod() == "names" then
        local vir = var.i.references
        local internal = vir and vir.internal
        if internal then
            var.inner = "aut:"..internal
        end
    else
        var.inner = nil
    end
    return link(nil,nil,var.inner,var.r,actions)
end

runners["inner with arguments"] = function(var,actions)
    report_references("todo: inner with arguments")
    return false
end

runners["outer"] = function(var,actions)
    local file, url = references.checkedfileorurl(var.outer,var.outer)
    return link(url,file,var.arguments,nil,actions)
end

runners["outer with inner"] = function(var,actions)
    local file = references.checkedfile(var.f)
    return link(nil,file,var.inner,var.r,actions)
end

runners["special outer with operation"] = function(var,actions)
    local handler = specials[var.special]
    return handler and handler(var,actions)
end

runners["special outer"] = function(var,actions)
    report_references("todo: special outer")
    return false
end

runners["special"] = function(var,actions)
    local handler = specials[var.special]
    return handler and handler(var,actions)
end

runners["outer with inner with arguments"] = function(var,actions)
    report_references("todo: outer with inner with arguments")
    return false
end

runners["outer with special and operation and arguments"] = function(var,actions)
    report_references("todo: outer with special and operation and arguments")
    return false
end

runners["outer with special"] = function(var,actions)
    report_references("todo: outer with special")
    return false
end

runners["outer with special and operation"] = function(var,actions)
    report_references("todo: outer with special and operation")
    return false
end

runners["special operation"]                = runners["special"]
runners["special operation with arguments"] = runners["special"]

function specials.internal(var,actions) -- better resolve in strc-ref
    local i = tonumber(var.operation)
    local v = references.internals[i]
    if not v then
        -- error
    elseif getinnermethod() == "names" then
        -- named
        return link(nil,nil,"aut:"..i,v.references.realpage,actions)
    else
        -- page
        return link(nil,nil,nil,v.references.realpage,actions)
    end
end

specials.i = specials.internal

function specials.page(var,actions) -- better resolve in strc-ref
    local file = var.f
    if file then
        file = references.checkedfile(file)
        return link(nil,file,nil,var.operation,actions)
    else
        local p = references.pages[var.operation]
        if type(p) == "function" then
            p = p()
        end
        return link(nil,nil,nil,p or var.operation,actions)
    end
end

-- todo, do this in references namespace ordered instead (this is an experiment)

local splitter = lpeg.splitat(":")

function specials.order(var,actions) -- references.specials !
    local operation = var.operation
    if operation then
        local kind, name, n = lpegmatch(splitter,operation)
        local order = lists.ordered[kind]
        order = order and order[name]
        local v = order[tonumber(n)]
        local r = v and v.references.realpage
        if r then
            var.operation = r -- brrr, but test anyway
            return specials.page(var,actions)
        end
    end
end

function specials.url(var,actions)
    local url = references.checkedurl(var.operation)
    return link(url,nil,var.arguments,nil,actions)
end

function specials.file(var,actions)
    local file = references.checkedfile(var.operation)
    return link(nil,file,var.arguments,nil,actions)
end

function specials.fileorurl(var,actions)
    local file, url = references.checkedfileorurl(var.operation,var.operation)
    return link(url,file,var.arguments,nil,actions)
end

function specials.program(var,content)
    local program = references.checkedprogram(var.operation)
    return lpdf.launch(program,var.arguments)
end

function specials.javascript(var)
    return lpdf.javascript(var.operation,var.arguments)
end

specials.JS = specials.javascript

executers.importform  = pdfdictionary { S = pdf_named, N = pdfconstant("AcroForm:ImportFDF") }
executers.exportform  = pdfdictionary { S = pdf_named, N = pdfconstant("AcroForm:ExportFDF") }
executers.first       = pdfdictionary { S = pdf_named, N = pdfconstant("FirstPage") }
executers.previous    = pdfdictionary { S = pdf_named, N = pdfconstant("PrevPage") }
executers.next        = pdfdictionary { S = pdf_named, N = pdfconstant("NextPage") }
executers.last        = pdfdictionary { S = pdf_named, N = pdfconstant("LastPage") }
executers.backward    = pdfdictionary { S = pdf_named, N = pdfconstant("GoBack") }
executers.forward     = pdfdictionary { S = pdf_named, N = pdfconstant("GoForward") }
executers.print       = pdfdictionary { S = pdf_named, N = pdfconstant("Print") }
executers.exit        = pdfdictionary { S = pdf_named, N = pdfconstant("Quit") }
executers.close       = pdfdictionary { S = pdf_named, N = pdfconstant("Close") }
executers.save        = pdfdictionary { S = pdf_named, N = pdfconstant("Save") }
executers.savenamed   = pdfdictionary { S = pdf_named, N = pdfconstant("SaveAs") }
executers.opennamed   = pdfdictionary { S = pdf_named, N = pdfconstant("Open") }
executers.help        = pdfdictionary { S = pdf_named, N = pdfconstant("HelpUserGuide") }
executers.toggle      = pdfdictionary { S = pdf_named, N = pdfconstant("FullScreen") }
executers.search      = pdfdictionary { S = pdf_named, N = pdfconstant("Find") }
executers.searchagain = pdfdictionary { S = pdf_named, N = pdfconstant("FindAgain") }
executers.gotopage    = pdfdictionary { S = pdf_named, N = pdfconstant("GoToPage") }
executers.query       = pdfdictionary { S = pdf_named, N = pdfconstant("AcroSrch:Query") }
executers.queryagain  = pdfdictionary { S = pdf_named, N = pdfconstant("AcroSrch:NextHit") }
executers.fitwidth    = pdfdictionary { S = pdf_named, N = pdfconstant("FitWidth") }
executers.fitheight   = pdfdictionary { S = pdf_named, N = pdfconstant("FitHeight") }

local function fieldset(arguments)
    -- [\dogetfieldset{#1}]
    return nil
end

function executers.resetform(arguments)
    arguments = (type(arguments) == "table" and arguments) or settings_to_array(arguments)
    return pdfdictionary {
        S     = pdfconstant("ResetForm"),
        Field = fieldset(arguments[1])
    }
end

local formmethod = "post" -- "get" "post"
local formformat = "xml"  -- "xml" "html" "fdf"

-- bit 3 = html bit 6 = xml bit 4 = get

local flags = {
    get = {
        html = 12, fdf = 8, xml = 40,
    },
    post = {
        html = 4, fdf = 0, xml = 32,
    }
}

function executers.submitform(arguments)
    arguments = (type(arguments) == "table" and arguments) or settings_to_array(arguments)
    local flag = flags[formmethod] or flags.post
    flag = (flag and (flag[formformat] or flag.xml)) or 32 -- default: post, xml
    return pdfdictionary {
        S     = pdfconstant("ResetForm"),
        F     = fieldset(arguments[1]),
        Field = fieldset(arguments[2]),
        Flags = flag,
    -- \PDFsubmitfiller
    }
end

function executers.hide(arguments)
    return pdfdictionary {
        S = pdfconstant("Hide"),
        H = true,
        T = arguments,
    }
end

function executers.show(arguments)
    return pdfdictionary {
        S = pdfconstant("Hide"),
        H = false,
        T = arguments,
    }
end

local pdf_movie  = pdfconstant("Movie")
local pdf_start  = pdfconstant("Start")
local pdf_stop   = pdfconstant("Stop")
local pdf_resume = pdfconstant("Resume")
local pdf_pause  = pdfconstant("Pause")

local function movie_or_sound(operation,arguments)
    arguments = (type(arguments) == "table" and arguments) or settings_to_array(arguments)
    return pdfdictionary {
        S         = pdf_movie,
        T         = format("movie %s",arguments[1] or "noname"),
        Operation = operation,
    }
end

function executers.startmovie (arguments) return movie_or_sound(pdf_start ,arguments) end
function executers.stopmovie  (arguments) return movie_or_sound(pdf_stop  ,arguments) end
function executers.resumemovie(arguments) return movie_or_sound(pdf_resume,arguments) end
function executers.pausemovie (arguments) return movie_or_sound(pdf_pause ,arguments) end

function executers.startsound (arguments) return movie_or_sound(pdf_start ,arguments) end
function executers.stopsound  (arguments) return movie_or_sound(pdf_stop  ,arguments) end
function executers.resumesound(arguments) return movie_or_sound(pdf_resume,arguments) end
function executers.pausesound (arguments) return movie_or_sound(pdf_pause ,arguments) end

function specials.action(var)
    local operation = var.operation
    if var.operation and operation ~= "" then
        local e = executers[operation]
        if type(e) == "table" then
            return e
        elseif type(e) == "function" then
            return e(var.arguments)
        end
    end
end

--~ entry.A = pdfdictionary {
--~     S = pdfconstant("GoTo"),
--~     D = ....
--~ }

local function build(levels,start,parent,method)
    local startlevel = levels[start][1]
    local i, n = start, 0
    local child, entry, m, prev, first, last, f, l
    while i and i <= #levels do
        local li = levels[i]
        local level, title, reference, open = li[1], li[2], li[3], li[4]
        if level < startlevel then
            pdfflushobject(child,entry)
            return i, n, first, last
        elseif level == startlevel then
            if trace_bookmarks then
                report_bookmarks("%3i %s%s %s",reference.realpage,rep("  ",level-1),(open and "+") or "-",title)
            end
            local prev = child
            child = pdfreserveobject()
            if entry then
                entry.Next = child and pdfreference(child)
                pdfflushobject(prev,entry)
            end
            entry = pdfdictionary {
                Title  = pdfunicode(title),
                Parent = parent,
                Prev   = prev and pdfreference(prev),
            }
            if method == "internal" then
                entry.Dest = "aut:" .. reference.internal
            else -- if method == "page" then
                entry.Dest = pagedestination(reference.realpage)
            end
            if not first then first, last = child, child end
            prev = child
            last = prev
            n = n + 1
            i = i + 1
        elseif i < #levels and level > startlevel then
            i, m, f, l = build(levels,i,pdfreference(child),method)
            entry.Count = (open and m) or -m
            if m > 0 then
                entry.First, entry.Last = pdfreference(f), pdfreference(l)
            end
        else
            -- missing intermediate level but ok
            i, m, f, l = build(levels,i,pdfreference(child),method)
            entry.Count = (open and m) or -m
            if m > 0 then
                entry.First, entry.Last = pdfreference(f), pdfreference(l)
            end
            pdfflushobject(child,entry)
            return i, n, first, last
        end
    end
    pdfflushobject(child,entry)
    return nil, n, first, last
end

function codeinjections.addbookmarks(levels,method)
    if #levels > 0 then
        structures.bookmarks.flatten(levels) -- dirty trick for lack of structure
        local parent = pdfreserveobject()
        local _, m, first, last = build(levels,1,pdfreference(parent),method or "internal")
        local dict = pdfdictionary {
            Type  = pdfconstant("Outlines"),
            First = pdfreference(first),
            Last  = pdfreference(last),
            Count = m,
        }
        pdfflushobject(parent,dict)
        lpdf.addtocatalog("Outlines",lpdf.reference(parent))
    end
end

-- this could also be hooked into the frontend finalizer

lpdf.registerdocumentfinalizer(function() bookmarks.place() end,1,"bookmarks")

if not modules then modules = { } end modules ['lpdf-ano'] = {
    version   = 1.001,
    comment   = "companion to lpdf-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local tostring, format, rep = tostring, string.rep, string.format
local texcount = tex.count

local trace_references   = false  trackers.register("references.references",   function(v) trace_references   = v end)
local trace_destinations = false  trackers.register("references.destinations", function(v) trace_destinations = v end)
local trace_bookmarks    = false  trackers.register("references.bookmarks",    function(v) trace_bookmarks    = v end)

local variables = interfaces.variables
local constants = interfaces.constants

local nodeinjections = backends.pdf.nodeinjections
local codeinjections = backends.pdf.codeinjections
local registrations  = backends.pdf.registrations

jobreferences           = jobreferences           or { }
jobreferences.runners   = jobreferences.runners   or { }
jobreferences.specials  = jobreferences.specials  or { }
jobreferences.handlers  = jobreferences.handlers  or { }
jobreferences.executers = jobreferences.executers or { }

local runners   = jobreferences.runners
local specials  = jobreferences.specials
local handlers  = jobreferences.handlers
local executers = jobreferences.executers

local pdfdictionary = lpdf.dictionary
local pdfarray      = lpdf.array
local pdfreference  = lpdf.reference
local pdfunicode    = lpdf.unicode
local pdfconstant   = lpdf.constant

local pdfreserveobj   = pdf.reserveobj
local pdfimmediateobj = pdf.immediateobj
local pdfpageref      = tex.pdfpageref

local pdfannot  = nodes.pdfannot
local pdfdest   = nodes.pdfdest

local pdf_uri        = pdfconstant("URI")
local pdf_gotor      = pdfconstant("GoToR")
local pdf_goto       = pdfconstant("GoTo")
local pdf_launch     = pdfconstant("Launch")
local pdf_javascript = pdfconstant("JavaScript")
local pdf_link       = pdfconstant("Link")
local pdf_n          = pdfconstant("N")
local pdf_t          = pdfconstant("T")
local pdf_border     = pdfarray { 0, 0, 0 }

local cache = { }

local function pagedest(n)
    local pd = cache[n]
    if not pd then
        local a = pdfarray {
            pdfreference(pdfpageref(n)),
            pdfconstant("Fit")
        }
        pd = pdfreference(pdfimmediateobj(tostring(a)))
        cache[n] = pd
    end
    return pd
end

lpdf.pagedest = pagedest

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
        return pdfdictionary {
            S = pdf_gotor,
            F = filename,
            D = destination and destination ~= "" and destination,
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
        return pdfdictionary {
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
            return pdfdictionary {
                S = pdf_goto,
                D = pagedest(p),
            }
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
    local script = javascripts.code(name,arguments) -- make into object (hash)
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

lpdf.pdfaction = pdfaction

function codeinjections.prerollreference(actions)
    local main = actions and pdfaction(actions)
    if main then
         main = pdfdictionary {
            Subtype = pdf_link,
            Border  = pdf_border,
            H       = (not actions.highlight and pdf_n) or nil,
            A       = main,
        --  does not work at all in spite of specification
        --  OC      = (actions.layer and lpdf.layerreferences[actions.layer]) or nil,
        --  OC      = backends.pdf.layerreference(actions.layer),
        }
        return main("A") -- todo: cache this, maybe weak
    end
end

-- local cache = { } -- no real gain in thsi
--
-- function codeinjections.prerollreference(actions)
--     local main = actions and pdfaction(actions)
--     if main then
--          main = pdfdictionary {
--             Subtype = pdf_link,
--             Border  = pdf_border,
--             H       = (not actions.highlight and pdf_n) or nil,
--             A       = main,
--         }
--         local cm = cache[main]
--         if not cm then
--             cm = "/A ".. tostring(pdfreference(pdfimmediateobj(tostring(main))))
--             cache[main] = cm
--         end
--         return cm
--     end
-- end

function nodeinjections.reference(width,height,depth,prerolled)
    if prerolled then
        if swapdir then
            width = - width
        end
        if trace_references then
            logs.report("references","w=%s, h=%s, d=%s, a=%s",width,height,depth,prerolled)
        end
        return pdfannot(width,height,depth,prerolled)
    end
end

function nodeinjections.destination(width,height,depth,name,view)
    if swapdir then
        width = - width
    end
    if trace_destinations then
        logs.report("destinations","w=%s, h=%s, d=%s, n=%s, v=%s",width,height,depth,name,view or "no view")
    end
    return pdfdest(width,height,depth,name,view)
end

-- runners and specials

local method = "internal"

runners["inner"] = function(var,actions)
    if method == "internal" then
        local vir = var.i.references
        local internal = vir and vir.internal
        if internal then
            var.inner = "aut:"..internal
        end
    end
    return link(nil,nil,var.inner,var.r,actions)
end

runners["inner with arguments"] = function(var,actions)
    logs.report("references","todo: inner with arguments")
    return false
end

runners["outer"] = function(var,actions)
    return link(nil,var.f,nil,nil,actions) -- var.o ?
end

runners["outer with inner"] = function(var,actions)
    -- todo: resolve url/file name
    return link(nil,var.f,var.inner,var.r,actions)
end

runners["special outer with operation"] = function(var,actions)
    local handler = specials[var.special]
    return handler and handler(var,actions)
end

runners["special outer"] = function(var,actions)
    logs.report("references","todo: special outer")
    return false
end

runners["special"] = function(var,actions)
    local handler = specials[var.special]
    return handler and handler(var,actions)
end

runners["outer with inner with arguments"] = function(var,actions)
    logs.report("references","todo: outer with inner with arguments")
    return false
end

runners["outer with special and operation and arguments"] = function(var,actions)
    logs.report("references","todo: outer with special and operation and arguments")
    return false
end

runners["outer with special"] = function(var,actions)
    logs.report("references","todo: outer with special")
    return false
end

runners["outer with special and operation"] = function(var,actions)
    logs.report("references","todo: outer with special and operation")
    return false
end

runners["special operation"]                = runners["special"]
runners["special operation with arguments"] = runners["special"]

function specials.internal(var,actions) -- better resolve in strc-ref
    local i = tonumber(var.operation)
    local v = jobreferences.internals[i]
    if not v then
        -- error
    elseif method == "internal" then
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
        local f = jobreferences.files.data[file]
        if f then
            file = f[1] or file
        end
        return link(nil,file,nil,p or var.operation,actions)
    else
        local p = jobreferences.pages[var.operation]
        if type(p) == "function" then
            p = p()
        end
        return link(nil,nil,nil,p or var.operation,actions)
    end
end

function specials.url(var,actions) -- better resolve in strc-ref
    local url = var.operation
    if url then
        local u = jobreferences.urls.data[url]
        if u then
            local u, f = u[1], u[2]
            if f and f ~= "" then
                url = u .. "/" .. f
            else
                url = u
            end
        end
    end
    return link(url,nil,var.arguments,nil,actions)
end

function specials.file(var,actions) -- better resolve in strc-ref
    local file = var.operation
    if file then
        local f = jobreferences.files.data[file]
        if f then
            file = f[1] or file
        end
    end
    return link(nil,file,var.arguments,nil,actions)
end

function specials.fileorurl(var,actions) -- better resolve in strc-ref
    local whatever, url, file = var.operation, nil, nil
    if whatever then
        local w = jobreferences.files.data[whatever]
        if w then
            file = w[1]
        else
            w = jobreferences.urls.data[whatever]
            if w then
                local u, f = w[1], w[2]
                if f and f ~= "" then
                    url = u .. "/" .. f
                else
                    url = u
                end
            end
        end
    end
    return link(url,file,var.arguments,nil,actions)
end

function specials.program(var,content) -- better resolve in strc-ref
    local program = var.operation
    if program then
        local p = jobreferences.programs[program]
        if p then
            program = p[1]
        end
    end
    return lpdf.launch(program,var.arguments)
end

function specials.javascript(var)
    return lpdf.javascript(var.operation,var.arguments)
end

specials.JS = specials.javascript

local pdf_named = pdfconstant("Named")

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
    arguments = (type(arguments) == "table" and arguments) or aux.settings_to_array(arguments)
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
    arguments = (type(arguments) == "table" and arguments) or aux.settings_to_array(arguments)
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
    arguments = (type(arguments) == "table" and arguments) or aux.settings_to_array(arguments)
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
-- to be tested: i can be nil
    while i and i <= #levels do
        local li = levels[i]
        local level, title, reference, open = li[1], li[2], li[3], li[4]
        if level == startlevel then
            if trace_bookmarks then
                logs.report("bookmark","%3i %s%s %s",realpage,rep("  ",level-1),(open and "+") or "-",title)
            end
            local prev = child
            child = pdfreserveobj()
            if entry then
                entry.Next = child and pdfreference(child)
                pdfimmediateobj(prev,tostring(entry))
            end
            entry = pdfdictionary {
                Title  = pdfunicode(title),
                Parent = parent,
                Prev   = prev and pdfreference(prev),
            }
            if method == "internal" then
                entry.Dest = "aut:" .. reference.internal
            else -- if method == "page" then
                entry.Dest = pagedest(reference.realpage)
            end
            if not first then first, last = child, child end
            prev = child
            last = prev
            n = n + 1
            i = i + 1
        elseif level < startlevel then
            pdfimmediateobj(child,tostring(entry))
            return i, n, first, last
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
            pdfimmediateobj(child,tostring(entry))
            return i, n, first, last
        end
    end
    pdfimmediateobj(child,tostring(entry))
    return nil, n, first, last
end

function codeinjections.addbookmarks(levels,method)
    local parent = pdfreserveobj()
    local _, m, first, last = build(levels,1,pdfreference(parent),method or "internal")
    local dict = pdfdictionary {
        Type  = pdfconstant("Outlines"),
        First = pdfreference(first),
        Last  = pdfreference(last),
        Count = m,
    }
    pdfimmediateobj(parent,tostring(dict))
    lpdf.addtocatalog("Outlines",lpdf.reference(parent))
end

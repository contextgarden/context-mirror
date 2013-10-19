if not modules then modules = { } end modules ['mlib-pps'] = {
    version   = 1.001,
    comment   = "companion to mlib-ctx.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files",
}

-- todo: make a hashed textext variant where we only process the text once (normally
-- we cannot assume that no macros are involved which influence a next textext

local format, gmatch, match, split = string.format, string.gmatch, string.match, string.split
local tonumber, type = tonumber, type
local round = math.round
local insert, concat = table.insert, table.concat
local Cs, Cf, C, Cg, Ct, P, S, V, Carg = lpeg.Cs, lpeg.Cf, lpeg.C, lpeg.Cg, lpeg.Ct, lpeg.P, lpeg.S, lpeg.V, lpeg.Carg
local lpegmatch = lpeg.match
local formatters = string.formatters

local mplib, metapost, lpdf, context = mplib, metapost, lpdf, context

local texbox               = tex.box
local copy_list            = node.copy_list
local free_list            = node.flush_list
local setmetatableindex    = table.setmetatableindex
local sortedhash           = table.sortedhash

local starttiming          = statistics.starttiming
local stoptiming           = statistics.stoptiming

local trace_runs           = false  trackers.register("metapost.runs",     function(v) trace_runs     = v end)
local trace_textexts       = false  trackers.register("metapost.textexts", function(v) trace_textexts = v end)
local trace_scripts        = false  trackers.register("metapost.scripts",  function(v) trace_scripts  = v end)

local report_metapost      = logs.reporter("metapost")
local report_textexts      = logs.reporter("metapost","textexts")
local report_scripts       = logs.reporter("metapost","scripts")

local colors               = attributes.colors

local rgbtocmyk            = colors.rgbtocmyk  or function() return 0,0,0,1 end
local cmyktorgb            = colors.cmyktorgb  or function() return 0,0,0   end
local rgbtogray            = colors.rgbtogray  or function() return 0       end
local cmyktogray           = colors.cmyktogray or function() return 0       end

metapost.makempy           = metapost.makempy or { nofconverted = 0 }
local makempy              = metapost.makempy

local nooutercolor         = "0 g 0 G"
local nooutertransparency  = "/Tr0 gs" -- only when set
local outercolormode       = 0
local outercolor           = nooutercolor
local outertransparency    = nooutertransparency
local innercolor           = nooutercolor
local innertransparency    = nooutertransparency

local pdfcolor             = lpdf.color
local pdftransparency      = lpdf.transparency
local registercolor        = colors.register
local registerspotcolor    = colors.registerspotcolor

local transparencies       = attributes.transparencies
local registertransparency = transparencies.register

function metapost.setoutercolor(mode,colormodel,colorattribute,transparencyattribute)
    -- has always to be called before conversion
    -- todo: transparency (not in the mood now)
    outercolormode = mode
    if mode == 1 or mode == 3 then
        -- inherit from outer (registered color)
        outercolor        = pdfcolor(colormodel,colorattribute)    or nooutercolor
        outertransparency = pdftransparency(transparencyattribute) or nooutertransparency
    elseif mode == 2 then
        -- stand alone (see m-punk.tex)
        outercolor        = ""
        outertransparency = ""
    else -- 0
        outercolor        = nooutercolor
        outertransparency = nooutertransparency
    end
    innercolor        = outercolor
    innertransparency = outertransparency -- not yet used
end

local f_gray  = formatters["%.3f g %.3f G"]
local f_rgb   = formatters["%.3f %.3f %.3f rg %.3f %.3f %.3f RG"]
local f_cmyk  = formatters["%.3f %.3f %.3f %.3f k %.3f %.3f %.3f %.3f K"]
local f_cm    = formatters["q %f %f %f %f %f %f cm"]
local f_shade = formatters["MpSh%s"]

local function checked_color_pair(color,...)
    if not color then
        return innercolor, outercolor
    end
    if outercolormode == 3 then
        innercolor = color(...)
        return innercolor, innercolor
    else
        return color(...), outercolor
    end
end

function metapost.colorinitializer()
    innercolor = outercolor
    innertransparency = outertransparency
    return outercolor, outertransparency
end

--~

local specificationsplitter = lpeg.tsplitat(" ")
local colorsplitter         = lpeg.tsplitter(":",tonumber) -- no need for :
local domainsplitter        = lpeg.tsplitter(" ",tonumber)
local centersplitter        = domainsplitter
local coordinatesplitter    = domainsplitter

-- thanks to taco's reading of the postscript manual:
--
-- x' = sx * x + ry * y + tx
-- y' = rx * x + sy * y + ty

local nofshades = 0 -- todo: hash resources, start at 1000 in order not to clash with older

local function normalize(ca,cb)
    if #cb == 1 then
        if #ca == 4 then
            cb[1], cb[2], cb[3], cb[4] = 0, 0, 0, 1-cb[1]
        else
            cb[1], cb[2], cb[3] = cb[1], cb[1], cb[1]
        end
    elseif #cb == 3 then
        if #ca == 4 then
            cb[1], cb[2], cb[3], cb[4] = rgbtocmyk(cb[1],cb[2],cb[3])
        else
            cb[1], cb[2], cb[3] = cmyktorgb(cb[1],cb[2],cb[3],cb[4])
        end
    end
end

-- todo: check for the same colorspace (actually a backend issue), now we can
-- have several similar resources
--
-- normalize(ca,cb) fails for spotcolors

local function spotcolorconverter(parent, n, d, p)
    registerspotcolor(parent)
    return pdfcolor(colors.model,registercolor(nil,'spot',parent,n,d,p)), outercolor
end

local commasplitter = lpeg.tsplitat(",")

local function checkandconvertspot(n_a,f_a,c_a,v_a,n_b,f_b,c_b,v_b)
    -- must be the same but we don't check
    local name = f_shade(nofshades)
    local ca = lpegmatch(commasplitter,v_a)
    local cb = lpegmatch(commasplitter,v_b)
    if #ca == 0 or #cb == 0 then
        return { 0 }, { 1 }, "DeviceGray", name
    else
        for i=1,#ca do ca[i] = tonumber(ca[i]) or 0 end
        for i=1,#cb do cb[i] = tonumber(cb[i]) or 1 end
    --~ spotcolorconverter(n_a,f_a,c_a,v_a) -- not really needed
        return ca, cb, n_a or n_b, name
    end
end

local function checkandconvert(ca,cb)
    local name = f_shade(nofshades)
    if not ca or not cb or type(ca) == "string" then
        return { 0 }, { 1 }, "DeviceGray", name
    else
        if #ca > #cb then
            normalize(ca,cb)
        elseif #ca < #cb then
            normalize(cb,ca)
        end
        local model = colors.model
        if model == "all" then
            model= (#ca == 4 and "cmyk") or (#ca == 3 and "rgb") or "gray"
        end
        if model == "rgb" then
            if #ca == 4 then
                ca = { cmyktorgb(ca[1],ca[2],ca[3],ca[4]) }
                cb = { cmyktorgb(cb[1],cb[2],cb[3],cb[4]) }
            elseif #ca == 1 then
                local a, b = 1-ca[1], 1-cb[1]
                ca = { a, a, a }
                cb = { b, b, b }
            end
            return ca, cb, "DeviceRGB", name
        elseif model == "cmyk" then
            if #ca == 3 then
                ca = { rgbtocmyk(ca[1],ca[2],ca[3]) }
                cb = { rgbtocmyk(cb[1],cb[2],cb[3]) }
            elseif #ca == 1 then
                ca = { 0, 0, 0, ca[1] }
                cb = { 0, 0, 0, ca[1] }
            end
            return ca, cb, "DeviceCMYK", name
        else
            if #ca == 4 then
                ca = { cmyktogray(ca[1],ca[2],ca[3],ca[4]) }
                cb = { cmyktogray(cb[1],cb[2],cb[3],cb[4]) }
            elseif #ca == 3 then
                ca = { rgbtogray(ca[1],ca[2],ca[3]) }
                cb = { rgbtogray(cb[1],cb[2],cb[3]) }
            end
            -- backend specific (will be renamed)
            return ca, cb, "DeviceGray", name
        end
    end
end

local current_format, current_graphic, current_initializations

metapost.multipass = false

local textexts   = { } -- all boxes, optionally with a different color
local texslots   = { } -- references to textexts in order or usage
local texorder   = { } -- references to textexts by mp index
local textrial   = 0
local texfinal   = 0
local scratchbox = 0

local function freeboxes()
    for n, box in next, textexts do
        local tn = textexts[n]
        if tn then
            free_list(tn)
          -- texbox[scratchbox] = tn
          -- texbox[scratchbox] = nil -- this frees too
            if trace_textexts then
                report_textexts("freeing box %s",n)
            end
        end
    end
    textexts = { }
    texslots = { }
    texorder = { }
    textrial = 0
    texfinal = 0
end

metapost.resettextexts = freeboxes

function metapost.settext(box,slot)
    textexts[slot] = copy_list(texbox[box])
    texbox[box] = nil
    -- this will become
    -- textexts[slot] = texbox[box]
    -- unsetbox(box)
end

function metapost.gettext(box,slot)
    texbox[box] = copy_list(textexts[slot])
    if trace_textexts then
        report_textexts("putting text %s in box %s",slot,box)
    end
 -- textexts[slot] = nil -- no, pictures can be placed several times
end

-- rather generic pdf, so use this elsewhere too it no longer pays
-- off to distinguish between outline and fill (we now have both
-- too, e.g. in arrows)

metapost.reducetogray = true

local models = { }

function models.all(cr)
    local n = #cr
    if n == 0 then
        return checked_color_pair()
    elseif metapost.reducetogray then
        if n == 1 then
            local s = cr[1]
            return checked_color_pair(f_gray,s,s)
        elseif n == 3 then
            local r, g, b = cr[1], cr[2], cr[3]
            if r == g and g == b then
                return checked_color_pair(f_gray,r,r)
            else
                return checked_color_pair(f_rgb,r,g,b,r,g,b)
            end
        else
            local c, m, y, k = cr[1], cr[2], cr[3], cr[4]
            if c == m and m == y and y == 0 then
                k = 1 - k
                return checked_color_pair(f_gray,k,k)
            else
                return checked_color_pair(f_cmyk,c,m,y,k,c,m,y,k)
            end
        end
    elseif n == 1 then
        local s = cr[1]
        return checked_color_pair(f_gray,s,s)
    elseif n == 3 then
        local r, g, b = cr[1], cr[2], cr[3]
        return checked_color_pair(f_rgb,r,g,b,r,g,b)
    else
        local c, m, y, k = cr[1], cr[2], cr[3], cr[4]
        return checked_color_pair(f_cmyk,c,m,y,k,c,m,y,k)
    end
end

function models.rgb(cr)
    local n = #cr
    if n == 0 then
        return checked_color_pair()
    elseif metapost.reducetogray then
        if n == 1 then
            local s = cr[1]
            checked_color_pair(f_gray,s,s)
        elseif n == 3 then
            local r, g, b = cr[1], cr[2], cr[3]
            if r == g and g == b then
                return checked_color_pair(f_gray,r,r)
            else
                return checked_color_pair(f_rgb,r,g,b,r,g,b)
            end
        else
            local c, m, y, k = cr[1], cr[2], cr[3], cr[4]
            if c == m and m == y and y == 0 then
                k = 1 - k
                return checked_color_pair(f_gray,k,k)
            else
                local r, g, b = cmyktorgb(c,m,y,k)
                return checked_color_pair(f_rgb,r,g,b,r,g,b)
            end
        end
    elseif n == 1 then
        local s = cr[1]
        return checked_color_pair(f_gray,s,s)
    else
        local r, g, b
        if n == 3 then
            r, g, b = cmyktorgb(cr[1],cr[2],cr[3],cr[4])
        else
            r, g, b = cr[1], cr[2], cr[3]
        end
        return checked_color_pair(f_rgb,r,g,b,r,g,b)
    end
end

function models.cmyk(cr)
    local n = #cr
    if n == 0 then
        return checked_color_pair()
    elseif metapost.reducetogray then
        if n == 1 then
            local s = cr[1]
            return checked_color_pair(f_gray,s,s)
        elseif n == 3 then
            local r, g, b = cr[1], cr[2], cr[3]
            if r == g and g == b then
                return checked_color_pair(f_gray,r,r)
            else
                local c, m, y, k = rgbtocmyk(r,g,b)
                return checked_color_pair(f_cmyk,c,m,y,k,c,m,y,k)
            end
        else
            local c, m, y, k = cr[1], cr[2], cr[3], cr[4]
            if c == m and m == y and y == 0 then
                k = k - 1
                return checked_color_pair(f_gray,k,k)
            else
                return checked_color_pair(f_cmyk,c,m,y,k,c,m,y,k)
            end
        end
    elseif n == 1 then
        local s = cr[1]
        return checked_color_pair(f_gray,s,s)
    else
        local c, m, y, k
        if n == 3 then
            c, m, y, k = rgbtocmyk(cr[1],cr[2],cr[3])
        else
            c, m, y, k = cr[1], cr[2], cr[3], cr[4]
        end
        return checked_color_pair(f_cmyk,c,m,y,k,c,m,y,k)
    end
end

function models.gray(cr)
    local n, s = #cr, 0
    if n == 0 then
        return checked_color_pair()
    elseif n == 4 then
        s = cmyktogray(cr[1],cr[2],cr[3],cr[4])
    elseif n == 3 then
        s = rgbtogray(cr[1],cr[2],cr[3])
    else
        s = cr[1]
    end
    return checked_color_pair(f_gray,s,s)
end

setmetatableindex(models, function(t,k)
    local v = models.gray
    t[k] = v
    return v
end)

local function colorconverter(cs)
    return models[colors.model](cs)
end

local btex      = P("btex")
local etex      = P(" etex")
local vtex      = P("verbatimtex")
local ttex      = P("textext")
local gtex      = P("graphictext")
local multipass = P("forcemultipass")
local spacing   = S(" \n\r\t\v")^0
local dquote    = P('"')

local found, forced = false, false

local function convert(str)
    found = true
    return "rawtextext(\"" .. str .. "\")" -- centered
end
local function ditto(str)
    return "\" & ditto & \""
end
local function register()
    found = true
end
local function force()
    forced = true
end

local texmess = (dquote/ditto + (1 - etex))^0

local function ignore(s)
    report_metapost("ignoring verbatim tex: %s",s)
    return ""
end

-- local parser = P {
--     [1] = Cs((V(2)/register + V(4)/ignore + V(3)/convert + V(5)/force + 1)^0),
--     [2] = ttex + gtex,
--     [3] = btex * spacing * Cs(texmess) * etex,
--     [4] = vtex * spacing * Cs(texmess) * etex,
--     [5] = multipass, -- experimental, only for testing
-- }

-- currently a a one-liner produces less code

-- textext.*(".*") can have "'s but tricky parsing as we can have concatenated strings
-- so this is something for a boring plain or train trip and we might assume proper mp
-- input anyway

local parser = Cs((
    (ttex + gtex)/register
  + (btex * spacing * Cs(texmess) * etex)/convert
  + (vtex * spacing * Cs(texmess) * etex)/ignore
  + 1
)^0)

local function checktexts(str)
    found, forced = false, false
    return lpegmatch(parser,str), found, forced
end

metapost.checktexts = checktexts

local factor = 65536*(7227/7200)

function metapost.edefsxsy(wd,ht,dp) -- helper for figure
    local hd = ht + dp
    context.setvalue("sx",wd ~= 0 and factor/wd or 0)
    context.setvalue("sy",hd ~= 0 and factor/hd or 0)
end

local function sxsy(wd,ht,dp) -- helper for text
    local hd = ht + dp
    return (wd ~= 0 and factor/wd) or 0, (hd ~= 0 and factor/hd) or 0
end

local no_first_run = "mfun_first_run := false ;"
local do_first_run = "mfun_first_run := true ;"
local no_trial_run = "mfun_trial_run := false ;"
local do_trial_run = "mfun_trial_run := true ;"
local do_begin_fig = "; beginfig(1) ; "
local do_end_fig   = "; endfig ;"
local do_safeguard = ";"

local f_text_data  = formatters["mfun_tt_w[%i] := %f ; mfun_tt_h[%i] := %f ; mfun_tt_d[%i] := %f ;"]

function metapost.textextsdata()
    local t, nt, n = { }, 0, 0
    for n=1,#texorder do
        local box = textexts[texorder[n]]
        if box then
            local wd, ht, dp = box.width/factor, box.height/factor, box.depth/factor
            if trace_textexts then
                report_textexts("passed data item %s: (%p,%p,%p)",n,wd,ht,dp)
            end
            nt = nt + 1
            t[nt] = f_text_data(n,wd,n,ht,n,dp)
        else
            break
        end
    end
--     inspect(t)
    return t
end

metapost.intermediate         = metapost.intermediate         or {}
metapost.intermediate.actions = metapost.intermediate.actions or {}
metapost.intermediate.needed  = false

metapost.method = 1 -- 1:dumb 2:clever

-- maybe we can latelua the texts some day

local nofruns = 0 -- askedfig: "all", "first", number

local function checkaskedfig(askedfig) -- return askedfig, wrappit
    if not askedfig then
        return "direct", true
    elseif askedfig == "all" then
        return "all", false
    elseif askedfig == "direct" then
        return "all", true
    else
        askedfig = tonumber(askedfig)
        if askedfig then
            return askedfig, false
        else
            return "direct", true
        end
    end
end

function metapost.graphic_base_pass(specification)
    local mpx = specification.mpx -- mandate
    local data = specification.data or ""
    local definitions = specification.definitions or ""
--  local extensions = metapost.getextensions(specification.instance,specification.useextensions)
    local extensions = specification.extensions or ""
    local inclusions = specification.inclusions or ""
    local initializations = specification.initializations or ""
    local askedfig = specification.figure -- no default else no wrapper
    --
    nofruns = nofruns + 1
    local askedfig, wrappit = checkaskedfig(askedfig)
    local done_1, done_2, done_3, forced_1, forced_2, forced_3
    data, done_1, forced_1 = checktexts(data)
    -- we had preamble = extensions + inclusions
    if extensions == "" then
        extensions, done_2, forced_2 = "", false, false
    else
        extensions, done_2, forced_2 = checktexts(extensions)
    end
    if inclusions == "" then
        inclusions, done_3, forced_3 = "", false, false
    else
        inclusions, done_3, forced_3 = checktexts(inclusions)
    end
    metapost.intermediate.needed  = false
    metapost.multipass = false -- no needed here
    current_format = mpx
    current_graphic = data
    current_initializations = initializations
    local method = metapost.method
    if trace_runs then
        if method == 1 then
            report_metapost("forcing two runs due to library configuration")
        elseif method ~= 2 then
            report_metapost("ignoring run due to library configuration")
        elseif not (done_1 or done_2 or done_3) then
            report_metapost("forcing one run only due to analysis")
        elseif done_1 then
            report_metapost("forcing at max two runs due to main code")
        elseif done_2 then
            report_metapost("forcing at max two runs due to extensions")
        else
            report_metapost("forcing at max two runs due to inclusions")
        end
    end
    if method == 1 or (method == 2 and (done_1 or done_2 or done_3)) then
        if trace_runs then
            report_metapost("first run of job %s, asked figure %a",nofruns,askedfig)
        end
     -- first true means: trialrun, second true means: avoid extra run if no multipass
        local flushed = metapost.process(mpx, {
            definitions,
            extensions,
            inclusions,
            wrappit and do_begin_fig or "",
            do_first_run,
            do_trial_run,
            current_initializations,
            do_safeguard,
            current_graphic,
            wrappit and do_end_fig or "",
        }, true, nil, not (forced_1 or forced_2 or forced_3), false, askedfig)
        if metapost.intermediate.needed then
            for _, action in next, metapost.intermediate.actions do
                action()
            end
        end
        if not flushed or not metapost.optimize then
            -- tricky, we can only ask once for objects and therefore
            -- we really need a second run when not optimized
            context.MPLIBextrapass(askedfig)
        end
    else
        if trace_runs then
            report_metapost("running job %s, asked figure %a",nofruns,askedfig)
        end
        metapost.process(mpx, {
            preamble,
            wrappit and do_begin_fig or "",
            do_first_run,
            no_trial_run,
            current_initializations,
            do_safeguard,
            current_graphic,
            wrappit and do_end_fig or "",
        }, false, nil, false, false, askedfig)
    end
end

function metapost.graphic_extra_pass(askedfig)
    if trace_runs then
        report_metapost("second run of job %s, asked figure %a",nofruns,askedfig)
    end
    local askedfig, wrappit = checkaskedfig(askedfig)
    metapost.process(current_format, {
        wrappit and do_begin_fig or "",
        no_trial_run,
        concat(metapost.textextsdata()," ;\n"),
        current_initializations,
        do_safeguard,
        current_graphic,
        wrappit and do_end_fig or "",
    }, false, nil, false, true, askedfig)
    context.MPLIBresettexts() -- must happen afterwards
end

local start    = [[\starttext]]
local preamble = [[\long\def\MPLIBgraphictext#1{\startTEXpage[scale=10000]#1\stopTEXpage}]]
local stop     = [[\stoptext]]

function makempy.processgraphics(graphics)
    if #graphics > 0 then
        makempy.nofconverted = makempy.nofconverted + 1
        starttiming(makempy)
        local mpofile = tex.jobname .. "-mpgraph"
        local mpyfile = file.replacesuffix(mpofile,"mpy")
        local pdffile = file.replacesuffix(mpofile,"pdf")
        local texfile = file.replacesuffix(mpofile,"tex")
        io.savedata(texfile, { start, preamble, metapost.tex.get(), concat(graphics,"\n"), stop }, "\n")
        local command = format("context --once %s %s", (tex.interactionmode == 0 and "--batchmode") or "", texfile)
        os.execute(command)
        if io.exists(pdffile) then
            command = format("pstoedit -ssp -dt -f mpost %s %s", pdffile, mpyfile)
            os.execute(command)
            local result, r = { }, 0
            if io.exists(mpyfile) then
                local data = io.loaddata(mpyfile)
                for figure in gmatch(data,"beginfig(.-)endfig") do
                    r = r + 1
                    result[r] = formatters["begingraphictextfig%sendgraphictextfig ;\n"](figure)
                end
                io.savedata(mpyfile,concat(result,""))
            end
        end
        stoptiming(makempy)
    end
end

-- -- the new plugin handler -- --

local sequencers   = utilities.sequencers
local appendgroup  = sequencers.appendgroup
local appendaction = sequencers.appendaction

local resetter     = nil
local analyzer     = nil
local processor    = nil

local resetteractions     = sequencers.new { arguments = "t" }
local analyzeractions     = sequencers.new { arguments = "object,prescript" }
local processoractions    = sequencers.new { arguments = "object,prescript,before,after" }

appendgroup(resetteractions,    "system")
appendgroup(analyzeractions,    "system")
appendgroup(processoractions,   "system")

-- later entries come first

--~ local scriptsplitter = Cf(Ct("") * (
--~     Cg(C((1-S("= "))^1) * S("= ")^1 * C((1-S("\n\r"))^0) * S("\n\r")^0)
--~ )^0, rawset)

local scriptsplitter = Ct ( Ct (
    C((1-S("= "))^1) * S("= ")^1 * C((1-S("\n\r"))^0) * S("\n\r")^0
)^0 )

local function splitprescript(script)
    local hash = lpegmatch(scriptsplitter,script)
    for i=#hash,1,-1 do
        local h = hash[i]
        hash[h[1]] = h[2]
    end
    if trace_scripts then
        report_scripts(table.serialize(hash,"prescript"))
    end
    return hash
end

-- -- not used:
--
-- local function splitpostscript(script)
--     local hash = lpegmatch(scriptsplitter,script)
--     for i=1,#hash do
--         local h = hash[i]
--         hash[h[1]] = h[2]
--     end
--     if trace_scripts then
--         report_scripts(table.serialize(hash,"postscript"))
--     end
--     return hash
-- end

function metapost.pluginactions(what,t,flushfigure) -- before/after object, depending on what
    for i=1,#what do
        local wi = what[i]
        if type(wi) == "function" then
            -- assume injection
            flushfigure(t) -- to be checked: too many 0 g 0 G
            t = { }
            wi()
        else
            t[#t+1] = wi
        end
    end
    return t
end

function metapost.resetplugins(t) -- intialize plugins, before figure
    -- plugins can have been added
    resetter     = resetteractions    .runner
    analyzer     = analyzeractions    .runner
    processor    = processoractions   .runner
    -- let's apply one runner
    resetter(t)
end

function metapost.analyzeplugins(object) -- each object (first pass)
    local prescript = object.prescript   -- specifications
    if prescript and #prescript > 0 then
        return analyzer(object,splitprescript(prescript))
    end
end

function metapost.processplugins(object) -- each object (second pass)
    local prescript = object.prescript   -- specifications
    if prescript and #prescript > 0 then
        local before = { }
        local after = { }
        processor(object,splitprescript(prescript),before,after)
        return #before > 0 and before, #after > 0 and after
    else
        local c = object.color
        if c and #c > 0 then
            local b, a = colorconverter(c)
            return { b }, { a }
        end
    end
end

-- helpers

local basepoints = number.dimenfactors["bp"]

local function cm(object)
    local op = object.path
    if op then
        local first, second, fourth = op[1], op[2], op[4]
        local tx, ty = first.x_coord      , first.y_coord
        local sx, sy = second.x_coord - tx, fourth.y_coord - ty
        local rx, ry = second.y_coord - ty, fourth.x_coord - tx
        if sx == 0 then sx = 0.00001 end
        if sy == 0 then sy = 0.00001 end
        return sx, rx, ry, sy, tx, ty
    else
        return 1, 0, 0, 1, 0, 0 -- weird case
    end
end

-- color

local function cl_reset(t)
    t[#t+1] = metapost.colorinitializer() -- only color
end

local tx_hash = { }
local tx_last = 0

local function tx_reset()
    tx_hash = { }
    tx_last = 0
end

local fmt = formatters["%s %s %s % t"]

local function tx_analyze(object,prescript) -- todo: hash content and reuse them
    local tx_stage = prescript.tx_stage
    if tx_stage == "trial" then
        textrial = textrial + 1
        local tx_number = tonumber(prescript.tx_number)
        local s = object.postscript or ""
        local c = object.color -- only simple ones, no transparency
        local a = prescript.tr_alternative
        local t = prescript.tr_transparency
        local h = fmt(tx_number,a or "?",t or "?",c)
        local n = tx_hash[h] -- todo: hashed variant with s (nicer for similar labels)
        if not n then
            tx_last = tx_last + 1
            if not c then
                -- no color
            elseif #c == 1 then
                if a and t then
                    s = formatters["\\directcolored[s=%f,a=%f,t=%f]%s"](c[1],a,t,s)
                else
                    s = formatters["\\directcolored[s=%f]%s"](c[1],s)
                end
            elseif #c == 3 then
                if a and t then
                    s = formatters["\\directcolored[r=%f,g=%f,b=%f,a=%f,t=%f]%s"](c[1],c[2],c[3],a,t,s)
                else
                    s = formatters["\\directcolored[r=%f,g=%f,b=%f]%s"](c[1],c[2],c[3],s)
                end
            elseif #c == 4 then
                if a and t then
                    s = formatters["\\directcolored[c=%f,m=%f,y=%f,k=%f,a=%f,t=%f]%s"](c[1],c[2],c[3],c[4],a,t,s)
                else
                    s = formatters["\\directcolored[c=%f,m=%f,y=%f,k=%f]%s"](c[1],c[2],c[3],c[4],s)
                end
            end
            context.MPLIBsettext(tx_last,s)
            metapost.multipass = true
            tx_hash[h] = tx_last
            texslots[textrial] = tx_last
            texorder[tx_number] = tx_last
            if trace_textexts then
                report_textexts("stage %a, usage %a, number %a, new %a, hash %a",tx_stage,textrial,tx_number,tx_last,h)
            end
        else
            texslots[textrial] = n
            if trace_textexts then
                report_textexts("stage %a, usage %a, number %a, new %a, hash %a",tx_stage,textrial,tx_number,n,h)
            end
        end
    elseif tx_stage == "extra" then
        textrial = textrial + 1
        local tx_number = tonumber(prescript.tx_number)
        if not texorder[tx_number] then
            local s = object.postscript or ""
            tx_last = tx_last + 1
            context.MPLIBsettext(tx_last,s)
            metapost.multipass = true
            texslots[textrial] = tx_last
            texorder[tx_number] = tx_last
            if trace_textexts then
                report_textexts("stage %a, usage %a, number %a, extra %a",tx_stage,textrial,tx_number,tx_last)
            end
        end
    end
end

local function tx_process(object,prescript,before,after)
    local tx_number = prescript.tx_number
    if tx_number then
        tx_number = tonumber(tx_number)
        local tx_stage = prescript.tx_stage
        if tx_stage == "final" then
            texfinal = texfinal + 1
            local n = texslots[texfinal]
            if trace_textexts then
                report_textexts("stage %a, usage %a, number %a, use %a",tx_stage,texfinal,tx_number,n)
            end
            local sx, rx, ry, sy, tx, ty = cm(object) -- needs to be frozen outside the function
            local box = textexts[n]
            if box then
                before[#before+1] = function()
                 -- flush always happens, we can have a special flush function injected before
                    context.MPLIBgettextscaledcm(n,
                        format("%f",sx), -- bah ... %s no longer checks
                        format("%f",rx), -- bah ... %s no longer checks
                        format("%f",ry), -- bah ... %s no longer checks
                        format("%f",sy), -- bah ... %s no longer checks
                        format("%f",tx), -- bah ... %s no longer checks
                        format("%f",ty), -- bah ... %s no longer checks
                        sxsy(box.width,box.height,box.depth))
                end
            else
                before[#before+1] = function()
                    report_textexts("unknown %s",tx_number)
                end
            end
            if not trace_textexts then
                object.path = false -- else: keep it
            end
            object.color = false
            object.grouped = true
        end
    end
end

-- graphics

local graphics = { }

function metapost.intermediate.actions.makempy()
    if #graphics > 0 then
        makempy.processgraphics(graphics)
        graphics = { } -- ?
    end
end

local function gt_analyze(object,prescript)
    local gt_stage = prescript.gt_stage
    if gt_stage == "trial" then
        graphics[#graphics+1] = formatters["\\MPLIBgraphictext{%s}"](object.postscript or "")
        metapost.intermediate.needed = true
        metapost.multipass = true
    end
end

-- local function gt_process(object,prescript,before,after)
--     local gt_stage = prescript.gt_stage
--     if gt_stage == "final" then
--     end
-- end

-- shades

local function sh_process(object,prescript,before,after)
    local sh_type = prescript.sh_type
    if sh_type then
        nofshades = nofshades + 1
        local domain  = lpegmatch(domainsplitter,prescript.sh_domain)
        local centera = lpegmatch(centersplitter,prescript.sh_center_a)
        local centerb = lpegmatch(centersplitter,prescript.sh_center_b)
        --
        local sh_color_a = prescript.sh_color_a or "1"
        local sh_color_b = prescript.sh_color_b or "1"
        local ca, cb, colorspace, name, separation
        if prescript.sh_color == "into" and prescript.sp_name then
            -- some spotcolor
            local value_a, components_a, fractions_a, name_a
            local value_b, components_b, fractions_b, name_b
            for i=1,#prescript do
                -- { "sh_color_a", "1" },
                -- { "sh_color", "into" },
                -- { "sh_radius_b", "0" },
                -- { "sh_radius_a", "141.73225" },
                -- { "sh_center_b", "425.19676 141.73225" },
                -- { "sh_center_a", "425.19676 0" },
                -- { "sh_factor", "1" },
                local tag = prescript[i][1]
                if not name_a and tag == "sh_color_a" then
                    value_a      = prescript[i-5][2]
                    components_a = prescript[i-4][2]
                    fractions_a  = prescript[i-3][2]
                    name_a       = prescript[i-2][2]
                elseif not name_b and tag == "sh_color_b" then
                    value_b      = prescript[i-5][2]
                    components_b = prescript[i-4][2]
                    fractions_b  = prescript[i-3][2]
                    name_b       = prescript[i-2][2]
                end
                if name_a and name_b then
                    break
                end
            end
            ca, cb, separation, name = checkandconvertspot(
                name_a,fractions_a,components_a,value_a,
                name_b,fractions_b,components_b,value_b
            )
        else
            local colora = lpegmatch(colorsplitter,sh_color_a)
            local colorb = lpegmatch(colorsplitter,sh_color_b)
            ca, cb, colorspace, name = checkandconvert(colora,colorb)
        end
        if not ca or not cb then
            ca, cb, colorspace, name = checkandconvert()
        end
        if sh_type == "linear" then
            local coordinates = { centera[1], centera[2], centerb[1], centerb[2] }
            lpdf.linearshade(name,domain,ca,cb,1,colorspace,coordinates,separation) -- backend specific (will be renamed)
        elseif sh_type == "circular" then
            local radiusa = tonumber(prescript.sh_radius_a)
            local radiusb = tonumber(prescript.sh_radius_b)
            local coordinates = { centera[1], centera[2], radiusa, centerb[1], centerb[2], radiusb }
            lpdf.circularshade(name,domain,ca,cb,1,colorspace,coordinates,separation) -- backend specific (will be renamed)
        else
            -- fatal error
        end
        before[#before+1], after[#after+1] = "q /Pattern cs", formatters["W n /%s sh Q"](name)
        -- false, not nil, else mt triggered
        object.colored = false -- hm, not object.color ?
        object.type = false
        object.grouped = true
    end
end

-- bitmaps

local function bm_process(object,prescript,before,after)
    local bm_xresolution = prescript.bm_xresolution
    if bm_xresolution then
        before[#before+1] = f_cm(cm(object))
        before[#before+1] = function()
            figures.bitmapimage {
                xresolution = tonumber(bm_xresolution),
                yresolution = tonumber(prescript.bm_yresolution),
                width       = 1/basepoints,
                height      = 1/basepoints,
                data        = object.postscript
            }
        end
        before[#before+1] = "Q"
        object.path = false
        object.color = false
        object.grouped = true
    end
end

-- positions

local function ps_process(object,prescript,before,after)
    local ps_label = prescript.ps_label
    if ps_label then
        local op = object.path
        local first, third  = op[1], op[3]
        local x, y = first.x_coord, first.y_coord
        local w, h = third.x_coord - x, third.y_coord - y
        x = x - metapost.llx
        y = metapost.ury - y
        before[#before+1] = function()
            context.MPLIBpositionwhd(ps_label,x,y,w,h)
        end
        object.path = false
    end
end

-- figures

local function fg_process(object,prescript,before,after)
    local fg_name = prescript.fg_name
    if fg_name then
        before[#before+1] = f_cm(cm(object)) -- beware: does not use the cm stack
        before[#before+1] = function()
            context.MPLIBfigure(fg_name,prescript.fg_mask or "")
        end
        before[#before+1] = "Q"
        object.path = false
        object.grouped = true
    end
end

-- color and transparency

local value = Cs ( (
    (Carg(1) * C((1-P(","))^1)) / function(a,b) return format("%0.3f",a * tonumber(b)) end
  + P(","))^1
)

-- should be codeinjections

local t_list = attributes.list[attributes.private('transparency')]
local c_list = attributes.list[attributes.private('color')]

local function tr_process(object,prescript,before,after)
    -- before can be shortcut to t
    local tr_alternative = prescript.tr_alternative
    if tr_alternative then
        tr_alternative = tonumber(tr_alternative)
        local tr_transparency = tonumber(prescript.tr_transparency)
        before[#before+1] = formatters["/Tr%s gs"](registertransparency(nil,tr_alternative,tr_transparency,true))
        after[#after+1] = "/Tr0 gs" -- outertransparency
    end
    local cs = object.color
    if cs and #cs > 0 then
        local c_b, c_a
        local sp_type = prescript.sp_type
        if not sp_type then
            c_b, c_a = colorconverter(cs)
        elseif sp_type == "spot" or sp_type == "multitone" then
            local sp_name       = prescript.sp_name       or "black"
            local sp_fractions  = prescript.sp_fractions  or 1
            local sp_components = prescript.sp_components or ""
            local sp_value      = prescript.sp_value      or "1"
            local cf = cs[1]
            if cf ~= 1 then
                -- beware, we do scale the spotcolors but not the alternative representation
                sp_value = lpegmatch(value,sp_value,1,cf) or sp_value
            end
            c_b, c_a = spotcolorconverter(sp_name,sp_fractions,sp_components,sp_value)
        elseif sp_type == "named" then
            -- we might move this to another namespace .. also, named can be a spotcolor
            -- so we need to check for that too ... also we need to resolve indirect
            -- colors so we might need the second pass for this (draw dots with \MPcolor)
            local sp_name = prescript.sp_name or "black"
            if not tr_alternative then
                -- todo: sp_name is not yet registered at this time
                local t = t_list[sp_name] -- string or attribute
                local v = t and attributes.transparencies.value(t)
                if v then
                    before[#before+1] = formatters["/Tr%s gs"](registertransparency(nil,v[1],v[2],true))
                    after[#after+1] = "/Tr0 gs" -- outertransparency
                end
            end
            local c = c_list[sp_name] -- string or attribute
            local v = c and attributes.colors.value(c)
            if v then
                -- all=1 gray=2 rgb=3 cmyk=4
                local colorspace = v[1]
                local f = cs[1]
                if colorspace == 2 then
                    local s = f*v[2]
                    c_b, c_a = checked_color_pair(f_gray,s,s)
                elseif colorspace == 3 then
                    local r, g, b = f*v[3], f*v[4], f*v[5]
                    c_b, c_a = checked_color_pair(f_rgb,r,g,b,r,g,b)
                elseif colorspace == 4 or colorspace == 1 then
                    local c, m, y, k = f*v[6], f*v[7], f*v[8], f*v[9]
                    c_b, c_a = checked_color_pair(f_cmyk,c,m,y,k,c,m,y,k)
                else
                    local s = f*v[2]
                    c_b, c_a = checked_color_pair(f_gray,s,s)
                end
            end
            --
        end
        if c_a and c_b then
            before[#before+1] = c_b
            after[#after+1] = c_a
        end
    end
end

-- layers (nasty: we need to keep the 'grouping' right

local function la_process(object,prescript,before,after)
    local la_name = prescript.la_name
    if la_name then
        before[#before+1] = backends.codeinjections.startlayer(la_name)
        insert(after,1,backends.codeinjections.stoplayer())
    end
end

-- groups

local types = {
    isolated
}

local function gr_process(object,prescript,before,after)
    local gr_state = prescript.gr_state
    if gr_state then
        if gr_state == "start" then
            local gr_type = utilities.parsers.settings_to_hash(prescript.gr_type)
            before[#before+1] = function()
                context.MPLIBstartgroup(
                    gr_type.isolated and 1 or 0,
                    gr_type.knockout and 1 or 0,
                    prescript.gr_llx,
                    prescript.gr_lly,
                    prescript.gr_urx,
                    prescript.gr_ury
                )
            end
        elseif gr_state == "stop" then
            after[#after+1] = function()
                context.MPLIBstopgroup()
            end
        end
        object.path = false
        object.color = false
        object.grouped = true
    end
end

-- definitions

appendaction(resetteractions, "system",cl_reset)
appendaction(resetteractions, "system",tx_reset)

appendaction(processoractions,"system",gr_process)

appendaction(analyzeractions, "system",tx_analyze)
appendaction(analyzeractions, "system",gt_analyze)

appendaction(processoractions,"system",sh_process)
--          (processoractions,"system",gt_process)
appendaction(processoractions,"system",bm_process)
appendaction(processoractions,"system",tx_process)
appendaction(processoractions,"system",ps_process)
appendaction(processoractions,"system",fg_process)
appendaction(processoractions,"system",tr_process) -- last, as color can be reset

appendaction(processoractions,"system",la_process)

-- we're nice and set them already

resetter  = resetteractions .runner
analyzer  = analyzeractions .runner
processor = processoractions.runner

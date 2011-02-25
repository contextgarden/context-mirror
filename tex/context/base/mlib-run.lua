if not modules then modules = { } end modules ['mlib-run'] = {
    version   = 1.001,
    comment   = "companion to mlib-ctx.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files",
}

--~ cmyk       -> done, native
--~ spot       -> done, but needs reworking (simpler)
--~ multitone  ->
--~ shade      -> partly done, todo: cm
--~ figure     -> done
--~ hyperlink  -> low priority, easy

-- new * run
-- or
-- new * execute^1 * finish

-- a*[b,c] == b + a * (c-b)

--[[ldx--
<p>The directional helpers and pen analysis are more or less translated from the
<l n='c'/> code. It really helps that Taco know that source so well. Taco and I spent
quite some time on speeding up the <l n='lua'/> and <l n='c'/> code. There is not
much to gain, especially if one keeps in mind that when integrated in <l n='tex'/>
only a part of the time is spent in <l n='metapost'/>. Of course an integrated
approach is way faster than an external <l n='metapost'/> and processing time
nears zero.</p>
--ldx]]--

local trace_graphics = false  trackers.register("metapost.graphics", function(v) trace_graphics = v end)

local report_metapost = logs.reporter("metapost")

local texerrormessage = logs.texerrormessage

local format, gsub, match, find = string.format, string.gsub, string.match, string.find

local starttiming, stoptiming = statistics.starttiming, statistics.stoptiming

local mplib = mplib

metapost       = metapost or { }
local metapost = metapost

metapost.showlog      = false
metapost.lastlog      = ""
metapost.texerrors    = false
metapost.exectime     = metapost.exectime or { } -- hack

local mplibone = tonumber(mplib.version()) <= 1.50

directives.register("mplib.texerrors", function(v) metapost.texerrors = v end)

function metapost.resetlastlog()
    metapost.lastlog = ""
end

local function finder(name, mode, ftype) -- we can use the finder to intercept btex/etex
    if mode == "w" then
        return name
    elseif file.is_qualified_path(name) then
        return name
    else
        return resolvers.findfile(name,ftype)
    end
end

local function finder(name, mode, ftype) -- we use the finder to intercept btex/etex
    if mode ~= "w" then
        name = file.is_qualified_path(name) and name or resolvers.findfile(name,ftype)
        if not (find(name,"/metapost/context/base/") or find(name,"/metapost/context/") or find(name,"/metapost/base/")) then
            local data, found, forced = metapost.checktexts(io.loaddata(name) or "")
            if found then
                local temp = luatex.registertempfile(name,true)
                io.savedata(temp,data)
                name = temp
            end
        end
    end
    return name
end

-- -- --

metapost.finder = finder

function metapost.reporterror(result)
    if not result then
        report_metapost("error: no result object returned")
    elseif result.status > 0 then
        local t, e, l = result.term, result.error, result.log
        if t and t ~= "" then
            (metapost.texerrors and texerrormessage or report_metapost)("terminal: %s",t)
        end
        if e then
            (metapost.texerrors and texerrormessage or report_metapost)("error: %s",(e=="" and "?") or e)
        end
        if not t and not e and l then
            metapost.lastlog = metapost.lastlog .. "\n" .. l
            report_metapost("log: %s",l)
        else
            report_metapost("error: unknown, no error, terminal or log messages")
        end
    else
        return false
    end
    return true
end

if mplibone then

    local preamble = [[
        boolean mplib ; mplib := true ;
        string mp_parent_version ; mp_parent_version := "%s" ;
        input %s ; dump ;
    ]]

    metapost.parameters = {
        hash_size = 100000,
        main_memory = 4000000,
        max_in_open = 50,
        param_size = 100000,
    }

    function metapost.make(name, target, version)
        starttiming(mplib)
        target = file.replacesuffix(target or name, "mem") -- redundant
        local mpx = mplib.new ( table.merged (
            metapost.parameters,
            {
                ini_version = true,
                find_file = finder,
                job_name = file.removesuffix(target),
            }
        ) )
        if mpx then
            starttiming(metapost.exectime)
            local result = mpx:execute(format(preamble,version or "unknown",name))
            stoptiming(metapost.exectime)
            mpx:finish()
        end
        stoptiming(mplib)
    end

    function metapost.load(name)
        starttiming(mplib)
        local mpx = mplib.new ( table.merged (
            metapost.parameters,
            {
                ini_version = false,
                mem_name = file.replacesuffix(name,"mem"),
                find_file = finder,
             -- job_name = "mplib",
            }
        ) )
        local result
        if not mpx then
            result = { status = 99, error = "out of memory"}
        end
        stoptiming(mplib)
        return mpx, result
    end

    function metapost.checkformat(mpsinput)
        local mpsversion = environment.version or "unset version"
        local mpsinput   = file.addsuffix(mpsinput or "metafun", "mp")
        local mpsformat  = file.removesuffix(file.basename(texconfig.formatname or (tex and tex.formatname) or mpsinput))
        local mpsbase    = file.removesuffix(file.basename(mpsinput))
        if mpsbase ~= mpsformat then
            mpsformat = mpsformat .. "-" .. mpsbase
        end
        mpsformat = file.addsuffix(mpsformat, "mem")
        local mpsformatfullname = caches.getfirstreadablefile(mpsformat,"formats") or ""
        if mpsformatfullname ~= "" then
            report_metapost("loading '%s' from '%s'", mpsinput, mpsformatfullname)
            local mpx, result = metapost.load(mpsformatfullname)
            if mpx then
                local result = mpx:execute("show mp_parent_version ;")
                if not result.log then
                    metapost.reporterror(result)
                else
                    local version = match(result.log,">> *(.-)[\n\r]") or "unknown"
                    version = gsub(version,"[\'\"]","")
                    if version ~= mpsversion then
                        report_metapost("version mismatch: %s <> %s", version or "unknown", mpsversion)
                    else
                        return mpx
                    end
                end
            else
                report_metapost("error in loading '%s' from '%s'", mpsinput, mpsformatfullname)
                metapost.reporterror(result)
            end
        end
        local mpsformatfullname = caches.setfirstwritablefile(mpsformat,"formats")
        report_metapost("making '%s' into '%s'", mpsinput, mpsformatfullname)
        metapost.make(mpsinput,mpsformatfullname,mpsversion) -- somehow return ... fails here
        if lfs.isfile(mpsformatfullname) then
            report_metapost("loading '%s' from '%s'", mpsinput, mpsformatfullname)
            return metapost.load(mpsformatfullname)
        else
            report_metapost("problems with '%s' from '%s'", mpsinput, mpsformatfullname)
        end
    end

else

    local preamble = [[
        boolean mplib ; mplib := true ;
        let dump = endinput ;
        input %s ;
    ]]

    function metapost.load(name)
        starttiming(mplib)
        local mpx = mplib.new {
            ini_version = true,
            find_file = finder,
        }
        local result
        if not mpx then
            result = { status = 99, error = "out of memory"}
        else
            result = mpx:execute(format(preamble, file.replacesuffix(name,"mp")))
        end
        stoptiming(mplib)
        metapost.reporterror(result)
        return mpx, result
    end

    function metapost.checkformat(mpsinput)
        local mpsversion = environment.version or "unset version"
        local mpsinput   = file.addsuffix(mpsinput or "metafun", "mp")
        report_metapost("loading '%s' (experimental metapost version two)",mpsinput)
        local mpx, result = metapost.load(mpsinput)
        if mpx then
            return mpx
        else
            report_metapost("error in loading '%s'",mpsinput)
            metapost.reporterror(result)
        end
    end

end

function metapost.unload(mpx)
    starttiming(mplib)
    if mpx then
        mpx:finish()
    end
    stoptiming(mplib)
end

local mpxformats = { }

function metapost.format(instance,name)
    name = name or instance
    local mpx = mpxformats[instance]
    if not mpx then
        report_metapost("initializing instance '%s' using format '%s'",instance,name)
        mpx = metapost.checkformat(name)
        mpxformats[instance] = mpx
    end
    return mpx
end

function metapost.reset(mpx)
    if not mpx then
        -- nothing
    elseif type(mpx) == "string" then
        if mpxformats[mpx] then
            mpxformats[mpx]:finish()
            mpxformats[mpx] = nil
        end
    else
        for name, instance in next, mpxformats do
            if instance == mpx then
                mpx:finish()
                mpxformats[name] = nil
                break
            end
        end
    end
end

local mp_inp, mp_log, mp_tag = { }, { }, 0

function metapost.process(mpx, data, trialrun, flusher, multipass, isextrapass, askedfig)
    local converted, result = false, {}
    if type(mpx) == "string" then
        mpx = metapost.format(mpx) -- goody
    end
    if mpx and data then
        starttiming(metapost)
        if trace_graphics then
            if not mp_inp[mpx] then
                mp_tag = mp_tag + 1
                mp_inp[mpx] = io.open(format("%s-mplib-run-%03i.mp", tex.jobname,mp_tag),"w")
                mp_log[mpx] = io.open(format("%s-mplib-run-%03i.log",tex.jobname,mp_tag),"w")
            end
            local banner = format("%% begin graphic: n=%s, trialrun=%s, multipass=%s, isextrapass=%s\n\n", metapost.n, tostring(trialrun), tostring(multipass), tostring(isextrapass))
            mp_inp[mpx]:write(banner)
            mp_log[mpx]:write(banner)
        end
        if type(data) == "table" then
            for i=1,#data do
                local d = data[i]
                if d then
                    if trace_graphics then
                        mp_inp[mpx]:write(d)
                    end
                    starttiming(metapost.exectime)
                    result = mpx:execute(d)
                    stoptiming(metapost.exectime)
                    if trace_graphics and result then
                        local str = result.log or result.error
                        if str and str ~= "" then
                            mp_log[mpx]:write(str)
                        end
                    end
                    if not metapost.reporterror(result) then
                        if metapost.showlog then
                            local str = (result.term ~= "" and result.term) or "no terminal output"
                            if not string.is_empty(str) then
                                metapost.lastlog = metapost.lastlog .. "\n" .. str
                                report_metapost("log: %s",str)
                            end
                        end
                        if result.fig then
                            converted = metapost.convert(result, trialrun, flusher, multipass, askedfig)
                        end
                    end
                else
                    report_metapost("error: invalid graphic component %s",i)
                end
            end
       else
            if trace_graphics then
                mp_inp:write(data)
            end
            starttiming(metapost.exectime)
            result = mpx[mpx]:execute(data)
            stoptiming(metapost.exectime)
            if trace_graphics and result then
                local str = result.log or result.error
                if str and str ~= "" then
                    mp_log[mpx]:write(str)
                end
            end
            -- todo: error message
            if not result then
                report_metapost("error: no result object returned")
            elseif result.status > 0 then
                report_metapost("error: %s",(result.term or "no-term") .. "\n" .. (result.error or "no-error"))
            else
                if metapost.showlog then
                    metapost.lastlog = metapost.lastlog .. "\n" .. result.term
                    report_metapost("info: %s",result.term or "no-term")
                end
                if result.fig then
                    converted = metapost.convert(result, trialrun, flusher, multipass, askedfig)
                end
            end
        end
        if trace_graphics then
            local banner = "\n% end graphic\n\n"
            mp_inp[mpx]:write(banner)
            mp_log[mpx]:write(banner)
        end
        stoptiming(metapost)
    end
    return converted, result
end

function metapost.convert()
    report_metapost('warning: no converter set')
end

-- handy

function metapost.directrun(formatname,filename,outputformat,astable,mpdata)
    local fullname = file.addsuffix(filename,"mp")
    local data = mpdata or io.loaddata(fullname)
    if outputformat ~= "svg" then
        outputformat = "mps"
    end
    if not data then
        report_metapost("unknown file '%s'",filename or "?")
    else
        local mpx = metapost.checkformat(formatname)
        if not mpx then
            report_metapost("unknown format '%s'",formatname or "?")
        else
            report_metapost("processing '%s'",(mpdata and (filename or "data")) or fullname)
            local result = mpx:execute(data)
            if not result then
                report_metapost("error: no result object returned")
            elseif result.status > 0 then
                report_metapost("error: %s",(result.term or "no-term") .. "\n" .. (result.error or "no-error"))
            else
                if metapost.showlog then
                    metapost.lastlog = metapost.lastlog .. "\n" .. result.term
                    report_metapost("info: %s",result.term or "no-term")
                end
                local figures = result.fig
                if figures then
                    local sorted = table.sortedkeys(figures)
                    if astable then
                        local result = { }
                        report_metapost("storing %s figures in table",#sorted)
                        for k=1,#sorted do
                            local v = sorted[k]
                            if outputformat == "mps" then
                                result[v] = figures[v]:postscript()
                            else
                                result[v] = figures[v]:svg() -- (3) for prologues
                            end
                        end
                        return result
                    else
                        local basename = file.removesuffix(file.basename(filename))
                        for k=1,#sorted do
                            local v = sorted[k]
                            local output
                            if outputformat == "mps" then
                                output = figures[v]:postscript()
                            else
                                output = figures[v]:svg() -- (3) for prologues
                            end
                            local outname = format("%s-%s.%s",basename,v,outputformat)
                            report_metapost("saving %s bytes in '%s'",#output,outname)
                            io.savedata(outname,output)
                        end
                        return #sorted
                    end
                end
            end
        end
    end
end

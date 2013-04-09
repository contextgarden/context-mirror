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

local type, tostring, tonumber = type, tostring, tonumber
local format, gsub, match, find = string.format, string.gsub, string.match, string.find
local concat = table.concat
local emptystring = string.is_empty
local lpegmatch, P = lpeg.match, lpeg.P

local trace_graphics   = false  trackers.register("metapost.graphics",   function(v) trace_graphics   = v end)
local trace_tracingall = false  trackers.register("metapost.tracingall", function(v) trace_tracingall = v end)

local report_metapost = logs.reporter("metapost")
local texerrormessage = logs.texerrormessage

local starttiming     = statistics.starttiming
local stoptiming      = statistics.stoptiming

local mplib           = mplib
metapost              = metapost or { }
local metapost        = metapost

local mplibone        = tonumber(mplib.version()) <= 1.50

metapost.showlog      = false
metapost.lastlog      = ""
metapost.collapse     = true -- currently mplib cannot deal with begingroup/endgroup mismatch in stepwise processing
metapost.texerrors    = false
metapost.exectime     = metapost.exectime or { } -- hack

-- metapost.collapse  = false

directives.register("mplib.texerrors",  function(v) metapost.texerrors = v end)
trackers.register  ("metapost.showlog", function(v) metapost.showlog   = v end)

function metapost.resetlastlog()
    metapost.lastlog = ""
end

----- mpbasepath = lpeg.instringchecker(lpeg.append { "/metapost/context/", "/metapost/base/" })
local mpbasepath = lpeg.instringchecker(P("/metapost/") * (P("context") + P("base")) * P("/"))

-- local function i_finder(askedname,mode,ftype) -- fake message for mpost.map and metafun.mpvi
--     local foundname = file.is_qualified_path(askedname) and askedname or resolvers.findfile(askedname,ftype)
--     if not mpbasepath(foundname) then
--         -- we could use the via file but we don't have a complete io interface yet
--         local data, found, forced = metapost.checktexts(io.loaddata(foundname) or "")
--         if found then
--             local tempname = luatex.registertempfile(foundname,true)
--             io.savedata(tempname,data)
--             foundname = tempname
--         end
--     end
--     return foundname
-- end

-- mplib has no real io interface so we have a different mechanism than
-- tex (as soon as we have more control, we will use the normal code)

local finders = { }
mplib.finders   = finders

-- for some reason mp sometimes calls this function twice which is inefficient
-- but we cannot catch this

local function preprocessed(name)
    if not mpbasepath(name) then
        -- we could use the via file but we don't have a complete io interface yet
        local data, found, forced = metapost.checktexts(io.loaddata(name) or "")
        if found then
            local temp = luatex.registertempfile(name,true)
            io.savedata(temp,data)
            return temp
        end
    end
    return name
end

mplib.preprocessed = preprocessed -- helper

finders.file = function(specification,name,mode,ftype)
    return preprocessed(resolvers.findfile(name,ftype))
end

local function i_finder(name,mode,ftype) -- fake message for mpost.map and metafun.mpvi
    local specification = url.hashed(name)
    local finder = finders[specification.scheme] or finders.file
    return finder(specification,name,mode,ftype)
end

local function o_finder(name, mode, ftype)
    return name
end

local function finder(name, mode, ftype)
    if mode == "w" then
        return o_finder(name, mode, ftype)
    else
        return i_finder(name, mode, ftype)
    end
end

local i_limited = false
local o_limited = false

directives.register("system.inputmode", function(v)
    if not i_limited then
        local i_limiter = io.i_limiter(v)
        if i_limiter then
            i_finder = i_limiter.protect(i_finder)
            i_limited = true
        end
    end
end)

directives.register("system.outputmode", function(v)
    if not o_limited then
        local o_limiter = io.o_limiter(v)
        if o_limiter then
            o_finder = o_limiter.protect(o_finder)
            o_limited = true
        end
    end
end)

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
        if e == "" or e == "no-error" then
            e = nil
        end
        if e then
            (metapost.texerrors and texerrormessage or report_metapost)("error: %s",e)
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

    report_metapost("fatal error: mplib is too old")

    os.exit()

 -- local preamble = [[
 --     boolean mplib ; mplib := true ;
 --     string mp_parent_version ; mp_parent_version := "%s" ;
 --     input "%s" ; dump ;
 -- ]]
 --
 -- metapost.parameters = {
 --     hash_size = 100000,
 --     main_memory = 4000000,
 --     max_in_open = 50,
 --     param_size = 100000,
 -- }
 --
 -- function metapost.make(name, target, version)
 --     starttiming(mplib)
 --     target = file.replacesuffix(target or name, "mem") -- redundant
 --     local mpx = mplib.new ( table.merged (
 --         metapost.parameters,
 --         {
 --             ini_version = true,
 --             find_file = finder,
 --             job_name = file.removesuffix(target),
 --         }
 --     ) )
 --     if mpx then
 --         starttiming(metapost.exectime)
 --         local result = mpx:execute(format(preamble,version or "unknown",name))
 --         stoptiming(metapost.exectime)
 --         mpx:finish()
 --     end
 --     stoptiming(mplib)
 -- end
 --
 -- function metapost.load(name)
 --     starttiming(mplib)
 --     local mpx = mplib.new ( table.merged (
 --         metapost.parameters,
 --         {
 --             ini_version = false,
 --             mem_name = file.replacesuffix(name,"mem"),
 --             find_file = finder,
 --          -- job_name = "mplib",
 --         }
 --     ) )
 --     local result
 --     if not mpx then
 --         result = { status = 99, error = "out of memory"}
 --     end
 --     stoptiming(mplib)
 --     return mpx, result
 -- end
 --
 -- function metapost.checkformat(mpsinput)
 --     local mpsversion = environment.version or "unset version"
 --     local mpsinput   = file.addsuffix(mpsinput or "metafun", "mp")
 --     local mpsformat  = file.removesuffix(file.basename(texconfig.formatname or (tex and tex.formatname) or mpsinput))
 --     local mpsbase    = file.removesuffix(file.basename(mpsinput))
 --     if mpsbase ~= mpsformat then
 --         mpsformat = mpsformat .. "-" .. mpsbase
 --     end
 --     mpsformat = file.addsuffix(mpsformat, "mem")
 --     local mpsformatfullname = caches.getfirstreadablefile(mpsformat,"formats","metapost") or ""
 --     if mpsformatfullname ~= "" then
 --         report_metapost("loading %a from %a", mpsinput, mpsformatfullname)
 --         local mpx, result = metapost.load(mpsformatfullname)
 --         if mpx then
 --             local result = mpx:execute("show mp_parent_version ;")
 --             if not result.log then
 --                 metapost.reporterror(result)
 --             else
 --                 local version = match(result.log,">> *(.-)[\n\r]") or "unknown"
 --                 version = gsub(version,"[\'\"]","")
 --                 if version ~= mpsversion then
 --                     report_metapost("version mismatch: %s <> %s", version or "unknown", mpsversion)
 --                 else
 --                     return mpx
 --                 end
 --             end
 --         else
 --             report_metapost("error in loading %a from %a", mpsinput, mpsformatfullname)
 --             metapost.reporterror(result)
 --         end
 --     end
 --     local mpsformatfullname = caches.setfirstwritablefile(mpsformat,"formats")
 --     report_metapost("making %a into %a", mpsinput, mpsformatfullname)
 --     metapost.make(mpsinput,mpsformatfullname,mpsversion) -- somehow return ... fails here
 --     if lfs.isfile(mpsformatfullname) then
 --         report_metapost("loading %a from %a", mpsinput, mpsformatfullname)
 --         return metapost.load(mpsformatfullname)
 --     else
 --         report_metapost("problems with %a from %a", mpsinput, mpsformatfullname)
 --     end
 -- end

else

    local preamble = [[
        boolean mplib ; mplib := true ;
        let dump = endinput ;
        input "%s" ;
    ]]

    local methods = {
        double  = "double",
        scaled  = "scaled",
        default = "scaled",
        decimal = false, -- for the moment
    }

    function metapost.load(name,method)
        starttiming(mplib)
        method = method and methods[method] or "scaled"
        local mpx = mplib.new {
            ini_version = true,
            find_file   = finder,
            math_mode   = method,
        }
        report_metapost("initializing number mode %a",method)
        local result
        if not mpx then
            result = { status = 99, error = "out of memory"}
        else
            result = mpx:execute(format(preamble, file.addsuffix(name,"mp"))) -- addsuffix is redundant
        end
        stoptiming(mplib)
        metapost.reporterror(result)
        return mpx, result
    end

    function metapost.checkformat(mpsinput,method)
        local mpsversion = environment.version or "unset version"
        local mpsinput   = mpsinput or "metafun"
        local foundfile  = ""
        if file.suffix(mpsinput) ~= "" then
            foundfile  = finder(mpsinput) or ""
        end
        if foundfile == "" then
            foundfile  = finder(file.replacesuffix(mpsinput,"mpvi")) or ""
        end
        if foundfile == "" then
            foundfile  = finder(file.replacesuffix(mpsinput,"mpiv")) or ""
        end
        if foundfile == "" then
            foundfile  = finder(file.replacesuffix(mpsinput,"mp")) or ""
        end
        if foundfile == "" then
            report_metapost("loading %a fails, format not found",mpsinput)
        else
            report_metapost("loading %a as %a using method %a",mpsinput,foundfile,method or "default")
            local mpx, result = metapost.load(foundfile,method)
            if mpx then
                return mpx
            else
                report_metapost("error in loading %a",mpsinput)
                metapost.reporterror(result)
            end
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

function metapost.format(instance,name,method)
    if not instance or instance == "" then
        instance = "metafun" -- brrr
    end
    name = name or instance
    local mpx = mpxformats[instance]
    if not mpx then
        report_metapost("initializing instance %a using format %a",instance,name)
        mpx = metapost.checkformat(name,method)
        mpxformats[instance] = mpx
    end
    return mpx
end

function metapost.instance(instance)
    return mpxformats[instance]
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

-- key/values

function metapost.process(mpx, data, trialrun, flusher, multipass, isextrapass, askedfig)
    local converted, result = false, { }
    if type(mpx) == "string" then
        mpx = metapost.format(mpx) -- goody
    end
    if mpx and data then
        starttiming(metapost)
        if trace_graphics then
            if not mp_inp[mpx] then
                mp_tag = mp_tag + 1
                local jobname = tex.jobname
                mp_inp[mpx] = io.open(format("%s-mplib-run-%03i.mp", jobname,mp_tag),"w")
                mp_log[mpx] = io.open(format("%s-mplib-run-%03i.log",jobname,mp_tag),"w")
            end
            local banner = format("%% begin graphic: n=%s, trialrun=%s, multipass=%s, isextrapass=%s\n\n", metapost.n, tostring(trialrun), tostring(multipass), tostring(isextrapass))
            mp_inp[mpx]:write(banner)
            mp_log[mpx]:write(banner)
        end
        if type(data) == "table" then
            -- this hack is needed because the library currently barks on \n\n
            -- eventually we can text for "" in the next loop
            local n = 0
            local nofsnippets = #data
            for i=1,nofsnippets do
                local d = data[i]
                if d ~= "" then
                    n = n + 1
                    data[n] = d
                end
            end
            for i=nofsnippets,n+1,-1 do
                data[i] = nil
            end
            -- and this one because mp cannot handle snippets due to grouping issues
            if metapost.collapse then
                if #data > 1 then
                    data = concat(data,"\n")
                else
                    data = data[1]
                end
            end
            -- end of hacks
        end
        if type(data) == "table" then
            if trace_tracingall then
                mpx:execute("tracingall;")
            end
         -- table.insert(data,2,"")
            for i=1,#data do
                local d = data[i]
             -- d = string.gsub(d,"\r","")
                if d then
                    if trace_graphics then
                        mp_inp[mpx]:write(format("\n%% begin snippet %s\n",i))
                        mp_inp[mpx]:write(d)
                        mp_inp[mpx]:write(format("\n%% end snippet %s\n",i))
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
                            local str = result.term ~= "" and result.term or "no terminal output"
                            if not emptystring(str) then
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
            if trace_tracingall then
                data = "tracingall;" .. data
            end
            if trace_graphics then
                mp_inp[mpx]:write(data)
            end
            starttiming(metapost.exectime)
            result = mpx:execute(data)
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
        report_metapost("unknown file %a",filename)
    else
        local mpx = metapost.checkformat(formatname)
        if not mpx then
            report_metapost("unknown format %a",formatname)
        else
            report_metapost("processing %a",(mpdata and (filename or "data")) or fullname)
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
                            report_metapost("saving %s bytes in %a",#output,outname)
                            io.savedata(outname,output)
                        end
                        return #sorted
                    end
                end
            end
        end
    end
end

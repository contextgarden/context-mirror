if not modules then modules = { } end modules ['mlib-run'] = {
    version   = 1.001,
    comment   = "companion to mlib-ctx.tex",
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

local format = string.format

metapost = metapost or { }

metapost.showlog = false
metapost.lastlog = ""

function metapost.resetlastlog()
    metapost.lastlog = ""
end

local function finder(name, mode, ftype)
    if mode=="w" then
        return name
    elseif file.is_qualified_path(name) then
        return name
    else
        return resolvers.find_file(name,ftype)
    end
end

metapost.finder = finder

--~ statistics = {
--~     ["hash_size"]=1774,
--~     ["main_memory"]=50237,
--~     ["max_in_open"]=5,
--~     ["param_size"]=4,
--~ }

metapost.parameters = {
    hash_size = 100000,
    main_memory = 2000000,
    max_in_open = 50,
    param_size = 100000,
}

metapost.exectime = metapost.exectime or { } -- hack

local preamble = [[
boolean mplib; string mp_parent_version;
mplib := true;
mp_parent_version := "%s";
input %s ; dump ;
]]

if not mplib.pen_info then -- temp compatibility hack

preamble = [[\\ ;
boolean mplib; string mp_parent_version;
mplib := true;
mp_parent_version := "%s";
input %s ; dump ;
]]

end

function metapost.make(name, target, version)
    statistics.starttiming(mplib)
    target = file.replacesuffix(target or name, "mem")
    local mpx = mplib.new ( table.merged (
        metapost.parameters,
        {
            ini_version = true,
            find_file = finder,
            job_name = file.removesuffix(target),
        }
    ) )
    if mpx then
        statistics.starttiming(metapost.exectime)
        local result = mpx:execute(format(preamble,version or "unknown",name))
        statistics.stoptiming(metapost.exectime)
        mpx:finish()
    end
    statistics.stoptiming(mplib)
end

function metapost.load(name)
    statistics.starttiming(mplib)
    local mpx = mplib.new ( table.merged (
        metapost.parameters,
        {
            ini_version = false,
            mem_name = file.replacesuffix(name,"mem"),
            find_file = finder,
        }
    ) )
    local result
    if mpx then
        if not mplib.pen_info then -- temp compatibility hack
            statistics.starttiming(metapost.exectime)
            result = mpx:execute("\\")
            statistics.stoptiming(metapost.exectime)
        end
    else
        result = { status = 99, error = "out of memory"}
    end
    statistics.stoptiming(mplib)
    return mpx, result
end

function metapost.unload(mpx)
    statistics.starttiming(mplib)
    if mpx then
        mpx:finish()
    end
    statistics.stoptiming(mplib)
end

function metapost.reporterror(result)
    if not result then
        metapost.report("mp error: no result object returned")
    elseif result.status > 0 then
        local t, e, l = result.term, result.error, result.log
        if t and t ~= "" then
            metapost.report("mp terminal: %s",t)
        end
        if e then
            metapost.report("mp error: %s",(e=="" and "?") or e)
        end
        if not t and not e and l then
            metapost.lastlog = metapost.lastlog .. "\n" .. l
            metapost.report("mp log: %s",l)
        else
            metapost.report("mp error: unknown, no error, terminal or log messages")
        end
    else
        return false
    end
    return true
end

function metapost.checkformat(mpsinput, mpsformat, dirname)
    mpsinput  = file.addsuffix(mpsinput or "metafun", "mp")
    mpsformat = file.removesuffix(file.basename(mpsformat or texconfig.formatname or (tex and tex.formatname) or mpsinput))
    local mpsbase = file.removesuffix(file.basename(mpsinput))
    if mpsbase ~= mpsformat then
        mpsformat = mpsformat .. "-" .. mpsbase
    end
    mpsformat = file.addsuffix(mpsformat, "mem")
    local pth = dirname or file.dirname(texconfig.formatname or "")
    if pth ~= "" then
        mpsformat = file.join(pth,mpsformat)
    end
    local the_version = environment.version or "unset version"
    if lfs.isfile(mpsformat) then
        commands.writestatus("mplib","loading '%s' from '%s'", mpsinput, mpsformat)
        local mpx, result = metapost.load(mpsformat)
        if mpx then
            local result = mpx:execute("show mp_parent_version ;")
            if not result.log then
                metapost.reporterror(result)
            else
                local version = result.log:match(">> *(.-)[\n\r]") or "unknown"
                version = version:gsub("[\'\"]","")
                if version ~= the_version then
                    commands.writestatus("mplib","version mismatch: %s <> %s", version or "unknown", the_version)
                else
                    return mpx
                end
            end
        else
            commands.writestatus("mplib","error in loading '%s' from '%s'", mpsinput, mpsformat)
            metapost.reporterror(result)
        end
    end
    commands.writestatus("mplib","making '%s' into '%s'", mpsinput, mpsformat)
    metapost.make(mpsinput,mpsformat,the_version) -- somehow return ... fails here
    if lfs.isfile(mpsformat) then
        commands.writestatus("mplib","loading '%s' from '%s'", mpsinput, mpsformat)
        return metapost.load(mpsformat)
    else
        commands.writestatus("mplib","problems with '%s' from '%s'", mpsinput, mpsformat)
    end
end

local mpxformats = { }

function metapost.format(instance,name)
    name = name or instance
    local mpx = mpxformats[instance]
    if not mpx then
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
        for name, instance in pairs(mpxformats) do
            if instance == mpx then
                mpx:finish()
                mpxformats[name] = nil
                break
            end
        end
    end
end

local mp_inp, mp_log, mp_tag = { }, { }, 0

function metapost.process(mpx, data, trialrun, flusher, multipass, isextrapass)
    local converted, result = false, {}
    if type(mpx) == "string" then
        mpx = metapost.format(mpx) -- goody
    end
    if mpx and data then
        statistics.starttiming(metapost)
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
                    statistics.starttiming(metapost.exectime)
                    result = mpx:execute(d)
                    statistics.stoptiming(metapost.exectime)
                    if trace_graphics and result then
                        local str = result.log or result.error
                        if str and str ~= "" then
                            mp_log[mpx]:write(str)
                        end
                    end
                    if not metapost.reporterror(result) then
                        if metapost.showlog then
                            local str = (result.term ~= "" and result.term) or "no terminal output"
                            if not str:is_empty() then
                                metapost.lastlog = metapost.lastlog .. "\n" .. str
                                metapost.report("mp log: %s",str)
                            end
                        end
                        if result.fig then
                            converted = metapost.convert(result, trialrun, flusher, multipass)
                        end
                    end
                else
                    metapost.report("mp error: invalid graphic component %s",i)
                end
            end
       else
            if trace_graphics then
                mp_inp:write(data)
            end
            statistics.starttiming(metapost.exectime)
            result = mpx[mpx]:execute(data)
            statistics.stoptiming(metapost.exectime)
            if trace_graphics and result then
                local str = result.log or result.error
                if str and str ~= "" then
                    mp_log[mpx]:write(str)
                end
            end
            -- todo: error message
            if not result then
                metapost.report("mp error: no result object returned")
            elseif result.status > 0 then
                metapost.report("mp error: %s",(result.term or "no-term") .. "\n" .. (result.error or "no-error"))
            else
                if metapost.showlog then
                    metapost.lastlog = metapost.lastlog .. "\n" .. result.term
                    metapost.report("mp info: %s",result.term or "no-term")
                end
                if result.fig then
                    converted = metapost.convert(result, trialrun, flusher, multipass)
                end
            end
        end
        if trace_graphics then
            local banner = "\n% end graphic\n\n"
            mp_inp[mpx]:write(banner)
            mp_log[mpx]:write(banner)
        end
        statistics.stoptiming(metapost)
    end
    return converted, result
end

function metapost.convert(result, trialrun, multipass)
    metapost.report('mp warning: no converter set')
end

function metapost.report(...)
    logs.report("mplib",...)
end

-- handy

function metapost.directrun(formatname,filename,outputformat,astable,mpdata)
    local fullname = file.addsuffix(filename,"mp")
    local data = mpdata or io.loaddata(fullname)
    if outputformat ~= "svg" then
        outputformat = "mps"
    end
    if not data then
        logs.simple("unknown file '%s'",filename or "?")
    else
        local mpx = metapost.checkformat(formatname,formatname,caches.setpath("formats"))
        if not mpx then
            logs.simple("unknown format '%s'",formatname or "?")
        else
            logs.simple("processing '%s'",(mpdata and (filename or "data")) or fullname)
            local result = mpx:execute(data)
            if not result then
                logs.simple("error: no result object returned")
            elseif result.status > 0 then
                logs.simple("error: %s",(result.term or "no-term") .. "\n" .. (result.error or "no-error"))
            else
                if metapost.showlog then
                    metapost.lastlog = metapost.lastlog .. "\n" .. result.term
                    logs.simple("info: %s",result.term or "no-term")
                end
                local figures = result.fig
                if figures then
                    local sorted = table.sortedkeys(figures)
                    if astable then
                        local result = { }
                        logs.simple("storing %s figures in table",#sorted)
                        for k, v in ipairs(sorted) do
                            if outputformat == "mps" then
                                result[v] = figures[v]:postscript()
                            else
                                result[v] = figures[v]:svg() -- (3) for prologues
                            end
                        end
                        return result
                    else
                        local basename = file.removesuffix(file.basename(filename))
                        for k, v in ipairs(sorted) do
                            local output
                            if outputformat == "mps" then
                                output = figures[v]:postscript()
                            else
                                output = figures[v]:svg() -- (3) for prologues
                            end
                            local outname = format("%s-%s.%s",basename,v,outputformat)
                            logs.simple("saving %s bytes in '%s'",#output,outname)
                            io.savedata(outname,output)
                        end
                        return #sorted
                    end
                end
            end
        end
    end
end

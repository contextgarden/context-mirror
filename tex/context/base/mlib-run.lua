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
much to gain, especially if on ekeeps in mind that when integrated in <l n='tex'/>
only a part of the time is spent in <l n='metapost'/>. Of course an integrated
approach is way faster than an external <l n='metapost'/> and processing time
nears zero.</p>
--ldx]]--

local format = string.format

metapost = metapost or { }

local function finder(name, mode, ftype)
    if mode=="w" then
        return name
    elseif input.aux.qualified_path(name) then
        return name
    else
        return input.find_file((texmf and texmf.instance) or instance,name,ftype)
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

function metapost.make(name, target, version)
    input.starttiming(mplib)
    target = file.replacesuffix(target or name, "mem")
    local mpx = mplib.new ( table.merged (
        metapost.parameters,
        {
            ini_version = true,
            find_file = finder,
            job_name = file.stripsuffix(target),
        }
    ) )
    if mpx then
        input.starttiming(metapost.exectime)
        local result = mpx:execute(format('\\ ; boolean mplib ; mplib := true ; string mp_parent_version ; mp_parent_version := "%s" ; show mp_parent_version ; input %s ;', version or "unknown", name))
        input.stoptiming(metapost.exectime)
        if mpx then
            mpx:finish()
        end
    end
    input.stoptiming(mplib)
    return mpx -- mpx = nil will free memory
end

function metapost.load(name)
    input.starttiming(mplib)
    local mpx = mplib.new ( table.merged (
        metapost.parameters,
        {
            mem_name = file.replacesuffix(name,"mem"),
            find_file = finder,
        }
    ) )
    if mpx then
        input.starttiming(metapost.exectime)
        mpx:execute("\\")
        input.stoptiming(metapost.exectime)
    end
    input.stoptiming(mplib)
    return mpx
end

function metapost.unload(mpx)
    input.starttiming(mplib)
    if mpx then
        mpx:finish()
    end
    input.stoptiming(mplib)
end

function metapost.checkformat(mpsinput, mpsformat)
    mpsinput  = file.addsuffix(mpsinput or "metafun", "mp")
    mpsformat = file.stripsuffix(file.basename(mpsformat or texconfig.formatname or tex.formatname or mpsinput))
    local mpsbase = file.stripsuffix(file.basename(mpsinput))
    if mpsbase ~= mpsformat then
        mpsformat = mpsformat .. "-" .. mpsbase
    end
    mpsformat = file.addsuffix(mpsformat, "mem")
    local pth = file.dirname(texconfig.formatname or "")
    if pth ~= "" then
        mpsformat = file.join(pth,mpsformat)
    end
    local the_version = environment.version or "unset version"
    if io.exists(mpsformat) then
        commands.writestatus("mplib", format("loading format: %s, name: %s", mpsinput, mpsformat))
        local mpx = metapost.load(mpsformat)
        if mpx then
            local result = mpx:execute(format("show mp_parent_version ;"))
            local version = result.log:match(">> *(.-)[\n\r]") or "unknown"
            version = version:gsub("[\'\"]","")
            if version ~= the_version then
                commands.writestatus("mplib", format("version mismatch: %s <> %s", version or "unknown", the_version))
            else
                return mpx
            end
        end
    end
    commands.writestatus("mplib", format("making format: %s, name: %s", mpsinput, mpsformat))
    metapost.make(mpsinput,mpsformat,the_version) -- somehow return ... fails here
    if io.exists(mpsformat) then
        commands.writestatus("mplib", format("loading format: %s, name: %s", mpsinput, mpsformat))
        return metapost.load(mpsformat)
    else
        commands.writestatus("mplib", format("problems with format: %s, name: %s", mpsinput, mpsformat))
    end
end

--~ if environment.initex then
--~     metapost.unload(metapost.checkformat("metafun"))
--~ end

local mpxformats = {}

function metapost.format(name)
    local mpx = mpxformats[name]
    if not mpx then
        mpx = metapost.checkformat(name)
        mpxformats[name] = mpx
    end
    return mpx
end

function metapost.process(mpx, data, trialrun, showlog)
    local result
    if type(mpx) == "string" then
        mpx = metapost.format(mpx) -- goody
    end
    if mpx and data then
        input.starttiming(metapost)
        if type(data) == "table" then
            for i=1,#data do
                local d = data[i]
                if d then
                    input.starttiming(metapost.exectime)
                    result = mpx:execute(d)
--~ print(">>>",d)
                    input.stoptiming(metapost.exectime)
                    if not result then
                        metapost.report("error", "no result object returned")
                    elseif result.status > 0 then
                        metapost.report("error",result.error or result.term or result.log or "unknown")
                    elseif showlog then
                        metapost.report("info",result.term or "unknown")
                    elseif result.fig then
                        metapost.convert(result, trialrun)
                    end
                else
                    metapost.report("error", "invalid graphic component " .. i)
                end
            end
       else
            input.starttiming(metapost.exectime)
            result = mpx:execute(data)
            input.stoptiming(metapost.exectime)
--~ print(">>>",data)
            if not result then
                metapost.report("error", "no result object returned")
            elseif result.status > 0 then
                metapost.report("error",result.error or result.term or result.log or "unknown")
            elseif showlog then
                metapost.report("info",result.term or "unknown")
            elseif result.fig then
                metapost.convert(result, trialrun)
            end
        end
        input.stoptiming(metapost)
    end
    return result
end

function metapost.convert(result, trialrun)
    metapost.report('Warning','no converter set')
end

function metapost.report(...)
    logs.report(...)
end

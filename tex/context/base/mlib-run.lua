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
        return input.find_file(name,ftype)
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
        local result = mpx:execute(format(preamble,version or "unknown",name))
        input.stoptiming(metapost.exectime)
        mpx:finish()
    end
    input.stoptiming(mplib)
end

function metapost.load(name)
    input.starttiming(mplib)
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
        input.starttiming(metapost.exectime)
        result = mpx:execute("\\")
        input.stoptiming(metapost.exectime)
end
    else
        result = { status = 99, error = "out of memory"}
    end
    input.stoptiming(mplib)
    return mpx, result
end

function metapost.unload(mpx)
    input.starttiming(mplib)
    if mpx then
        mpx:finish()
    end
    input.stoptiming(mplib)
end

function metapost.reporterror(result)
    if not result then
        metapost.report("mp error: no result object returned")
    elseif result.status > 0 then
        local t, e, l = result.term, result.error, result.log
        if t then
            metapost.report("mp terminal: %s",t)
        end
        if e then
            metapost.report("mp error: %s",(e=="" and "?") or e)
        end
        if not t and not e and l then
            metapost.report("mp log: %s",l)
        else
            metapost.report("mp error: unknown, no error, terminal or log messages")
        end
    else
        return false
    end
    return true
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
    if lfs.isfile(mpsformat) then
        commands.writestatus("mplib","loading format: %s, name: %s", mpsinput, mpsformat)
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
            commands.writestatus("mplib","error in loading format: %s, name: %s", mpsinput, mpsformat)
            metapost.reporterror(result)
        end
    end
    commands.writestatus("mplib","making format: %s, name: %s", mpsinput, mpsformat)
    metapost.make(mpsinput,mpsformat,the_version) -- somehow return ... fails here
    if lfs.isfile(mpsformat) then
        commands.writestatus("mplib","loading format: %s, name: %s", mpsinput, mpsformat)
        return metapost.load(mpsformat)
    else
        commands.writestatus("mplib","problems with format: %s, name: %s", mpsinput, mpsformat)
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

metapost.showlog = false

function metapost.process(mpx, data, trialrun, flusher, multipass)
    local converted, result = false, {}
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
                    input.stoptiming(metapost.exectime)
                    if not metapost.reporterror(result) then
                        if metapost.showlog then
                            local str = (result.term ~= "" and result.term) or "no terminal output"
                            if not str:is_empty() then
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
            input.starttiming(metapost.exectime)
            result = mpx:execute(data)
            input.stoptiming(metapost.exectime)
            -- todo: error message
            if not result then
                metapost.report("mp error: no result object returned")
            elseif result.status > 0 then
                metapost.report("mp error: %s",(result.term or "no-term") .. "\n" .. (result.error or "no-error"))
            elseif metapost.showlog then
                metapost.report("mp info: %s",result.term or "no-term")
            elseif result.fig then
                converted = metapost.convert(result, trialrun, flusher, multipass)
            end
        end
        input.stoptiming(metapost)
    end
    return converted, result
end

function metapost.convert(result, trialrun, multipass)
    metapost.report('mp warning: no converter set')
end

function metapost.report(...)
    logs.report("mplib",...)
end

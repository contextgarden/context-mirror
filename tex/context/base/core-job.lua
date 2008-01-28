if not modules then modules = { } end modules ['core-job'] = {
    version   = 1.001,
    comment   = "companion to core-job.tex",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- will move

function commands.doifelse(b)
    if b then
        tex.sprint(tex.texcatcodes,"\\firstoftwoarguments")
    else
        tex.sprint(tex.texcatcodes,"\\secondoftwoarguments")
    end
end
function commands.doif(b)
    if b then
        tex.sprint(tex.texcatcodes,"\\firstoftwoarguments")
    end
end
function commands.doifnot(b)
    if not b then
        tex.sprint(tex.texcatcodes,"\\firstoftwoarguments")
    end
end
cs.testcase = commands.doifelse

-- main code

do

    local function find(name,maxreadlevel)
        local n = "./" .. name
        if io.exists(n) then
            return n
        else
            n = file.addsuffix(name,'tex')
            for i=1,maxreadlevel or 0 do
                n = "../" .. n
                if io.exists(n) then
                    return n
                end
            end
        end
        return input.find_file(texmf.instance,name) or ""
    end

    function commands.processfile(name,maxreadlevel)
        name = find(name,maxreadlevel)
        if name ~= "" then
            tex.sprint(tex.ctxcatcodes,string.format("\\input %s\\relax",name))
        end
    end

    function commands.doifinputfileelse(name,maxreadlevel)
        commands.doifelse(find(name,maxreadlevel) ~= "")
    end

    function commands.locatefilepath(name,maxreadlevel)
        tex.sprint(tex.texcatcodes,file.dirname(find(name,maxreadlevel)))
    end

    function commands.usepath(paths,maxreadlevel)
        input.register_extra_path(texmf.instance,paths)
        tex.sprint(tex.texcatcodes,table.concat(texmf.instance.extra_paths or {}, ""))
    end

    function commands.usesubpath(subpaths,maxreadlevel)
        input.register_extra_path(texmf.instance,nil,subpaths)
        tex.sprint(tex.texcatcodes,table.concat(texmf.instance.extra_paths or {}, ""))
    end

end

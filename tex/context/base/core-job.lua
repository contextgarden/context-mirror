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

function commands.processfile(name)
    name = input.find_file(texmf.instance,name) or ""
    if name ~= "" then
        tex.sprint(tex.ctxcatcodes,string.format("\\input %s\\relax",name))
    end
end

function commands.doifinputfileelse(name)
    commands.doifelse((input.find_file(texmf.instance,name) or "") ~= "")
end

function commands.locatefilepath(name)
    tex.sprint(tex.texcatcodes,file.dirname(input.find_file(texmf.instance,name) or ""))
end

function commands.usepath(paths)
    input.register_extra_path(texmf.instance,paths)
    tex.sprint(tex.texcatcodes,table.concat(texmf.instance.extra_paths or {}, ""))
end

function commands.usesubpath(subpaths)
    input.register_extra_path(texmf.instance,nil,subpaths)
    tex.sprint(tex.texcatcodes,table.concat(texmf.instance.extra_paths or {}, ""))
end

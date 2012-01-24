if not modules then modules = { } end modules ['file-syn'] = {
    version   = 1.001,
    comment   = "companion to file-syn.mkvi",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local report_files = logs.reporter("files")

environment.filesynonyms = environment.filesynonyms or { }
local filesynonyms       = environment.filesynonyms

storage.register("environment/filesynonyms", filesynonyms, "environment.filesynonyms")

local function truefilename(name)
    local realname = filesynonyms[name] or name
    if realname ~= name then
        return truefilename(realname)
    else
        return realname
    end
end

environment.truefilename = truefilename

function commands.truefilename(name)
    context(truefilename(name))
end

function commands.definefilesynonym(name,realname)
    local synonym = filesynonyms[name]
    if synonym then
        interfaces.showmessage("files",1,name,realname,synonym)
    end
    filesynonyms[name] = realname
end

function commands.definefilefallback(name,alternatives)
    local names = utilities.parser.settings_to_array(alternatives)
    for i=1,#names do
        local realname = resolvers.findfile(names[i])
        if realname ~= "" then
            filesynonyms[name] = realname
            break
        end
    end
end

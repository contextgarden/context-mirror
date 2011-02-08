if not modules then modules = { } end modules ['mtx-modules'] = {
    version   = 1.002,
    comment   = "companion to mtxrun.lua",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

scripts         = scripts         or { }
scripts.modules = scripts.modules or { }

local helpinfo = [[
--convert             convert source files (tex, mkii, mkiv, mp) to 'ted' files
--process             process source files (tex, mkii, mkiv, mp) to 'pdf' files
--prep                use original name with suffix 'prep' appended
]]

local application = logs.application {
    name     = "mtx-modules",
    banner   = "ConTeXt Module Documentation Generators 1.00",
    helpinfo = helpinfo,
}

local report = application.report

-- Documentation can be woven into a source file. This script can generates
-- a file with the documentation and source fragments properly tagged. The
-- documentation is included as comment:
--
-- %D ......  some kind of documentation
-- %M ......  macros needed for documenation
-- %S B       begin skipping
-- %S E       end skipping
--
-- The generated file is structured as:
--
-- \starttypen
-- \startmodule[type=suffix]
-- \startdocumentation
-- \stopdocumentation
-- \startdefinition
-- \stopdefinition
-- \stopmodule
-- \stoptypen
--
-- Macro definitions specific to the documentation are not surrounded by
-- start-stop commands. The suffix specificaction can be overruled at runtime,
-- but defaults to the file extension. This specification can be used for language
-- depended verbatim typesetting.

local find, format, sub, is_empty, strip = string.find, string.format, string.sub, string.is_empty, string.strip

local function source_to_ted(inpname,outname,filetype)
    local inp = io.open(inpname)
    if not inp then
        report("unable to open '%s'",inpname)
        return
    end
    local out = io.open(outname,"w")
    if not out then
        report("unable to open '%s'",outname)
        return
    end
    report("converting '%s' to '%s'",inpname,outname)
    local skiplevel, indocument, indefinition = 0, false, false
    out:write(format("\\startmodule[type=%s]\n",filetype or file.suffix(inpname)))
    for line in inp:lines() do
--~         line = strip(line)
        if find(line,"^%%D ") or find(line,"^%%D$") then
            if skiplevel == 0 then
                local someline = (#line < 3 and "") or sub(line,4,#line)
                if indocument then
                    out:write(format("%s\n",someline))
                else
                    if indefinition then
                        out:write("\\stopdefinition\n")
                        indefinition = false
                    end
                    if not indocument then
                        out:write("\n\\startdocumentation\n")
                    end
                    out:write(format("%s\n",someline))
                    indocument = true
                end
            end
        elseif find(line,"^%%M ") or find(line,"^%%M$") then
            if skiplevel == 0 then
                local someline = (#line < 3 and "") or sub(line,4,#line)
                out:write(format("%s\n",someline))
            end
        elseif find(line,"^%%S B") then
            skiplevel = skiplevel + 1
        elseif find(line,"^%%S E") then
            skiplevel = skiplevel - 1
        elseif find(line,"^%%") then
            -- nothing
        elseif skiplevel == 0 then
            inlocaldocument = indocument
            inlocaldocument = false
            local someline = line
            if indocument then
                out:write("\\stopdocumentation\n")
                indocument = false
            end
            if indefinition then
                if is_empty(someline) then
                    out:write("\\stopdefinition\n")
                    indefinition = false
                else
                    out:write(format("%s\n",someline))
                end
            elseif not is_empty(someline) then
                out:write("\n\\startdefinition\n")
                indefinition = true
                if inlocaldocument then
                    -- nothing
                else
                    out:write(format("%s\n",someline))
                end
            end
        end
    end
    if indocument then
        out:write("\\stopdocumentation\n")
    end
    if indefinition then
        out:write("\\stopdefinition\n")
    end
    out:write("\\stopmodule\n")
    out:close()
    inp:close()
    return true
end

local suffixes = table.tohash { 'tex','mkii','mkiv', 'mkvi', 'mp' }

function scripts.modules.process(runtex)
    local processed = { }
    local prep = environment.argument("prep")
    local files = environment.files
    for i=1,#files do
        local shortname = files[i]
        local suffix = file.suffix(shortname)
        if suffixes[suffix] then
            local longname
            if prep then
                longname = shortname .. ".prep"
            else
                longname = file.removesuffix(shortname) .. "-" .. suffix .. ".ted"
            end
            local done = source_to_ted(shortname,longname)
            if done and runtex then
                os.execute(format("mtxrun --script context --usemodule=mod-01 %s",longname))
                processed[#processed+1] = longname
            end
        end
    end
    for i=1,#processed do
        local name = processed[i]
        report("modules","processed: %s",name)
    end
end

--  context --ctx=m-modules.ctx xxx.mkiv

if environment.argument("process") then
    scripts.modules.process(true)
elseif environment.argument("convert") then
    scripts.modules.process(false)
else
    application.help()
end

if not modules then modules = { } end modules ['mtx-plain'] = {
    version   = 1.002,
    comment   = "companion to mtxrun.lua",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- something fishy ... different than the texmf.cnf suggests .. hardcoded ?

-- table={
--  ".",
--  "c:/data/develop/tex-context/tex/texmf-local/web2c/luatex",
--  "c:/data/develop/tex-context/tex/texmf-local/web2c",
--  "c:/data/develop/tex-context/tex/texmf-context/web2c",
--  "c:/data/develop/tex-context/tex/texmf-mswin/web2c",
--  "c:/data/develop/tex-context/tex/texmf/web2c",
-- }

local format = string.format

local helpinfo = [[
<?xml version="1.0"?>
<application>
 <metadata>
  <entry name="name">mtx-plain</entry>
  <entry name="detail">Plain TeX Runner</entry>
  <entry name="version">1.00</entry>
 </metadata>
 <flags>
  <category name="basic">
   <subcategory>
    <flag name="make"><short>create format file</short></flag>
    <flag name="run"><short>process file</short></flag>
    <flag name="format" value="string"><short>format name (default: luatex-plain)</short></flag>
    <flag name="engine" value="string"><short>engine to use (default: luatex)</short></flag>
    <flag name="jit"><short>use luajittex</short></flag>
   </subcategory>
  </category>
 </flags>
</application>
]]

local application = logs.application {
    name     = "mtx-plain",
    banner   = "Plain TeX Runner 1.00",
    helpinfo = helpinfo,
}

local report = application.report

scripts       = scripts       or { }
scripts.plain = scripts.plain or { }

function scripts.plain.make(texengine,texformat)
    os.execute("mktexlsr") -- better play safe and use this one
    local fmtpathspec = os.resultof(format("kpsewhich --expand-path=$TEXFORMATS --engine=%s",texengine))
    fmtpathspec = string.splitlines(fmtpathspec)[1] or fmtpathspec
    fmtpathspec = file.splitpath(fmtpathspec)
    local fmtpath = nil
    for i=1,#fmtpathspec do
        local path = fmtpathspec[i]
        if path ~= "." and lfs.isdir(path) and file.is_writable(path) then
            fmtpath = path
            break
        end
    end
    if not fmtpath then
        -- message
    else
        lfs.chdir(fmtpath)
        os.execute(format('%s --ini %s',file.addsuffix(texengine),texformat,"tex"))
        os.execute("mktexlsr")
    end
end

function scripts.plain.run(texengine,texformat,filename)
    os.execute(format('%s --fmt=%s "%s"',"luatex-plain",texengine,file.removesuffix(texformat),filename))
end

local texformat = environment.arguments.texformat or environment.arguments.format
local texengine = environment.arguments.texengine or environment.arguments.engine

if type(texengine) ~= "string" or texengine == "" then
    texengine = environment.arguments.jit and "luajittex" or"luatex"
end

if type(texformat) ~= "string" or texformat == "" then
    texformat = "luatex-plain"
end

local filename = environment.files[1]

if environment.arguments.exporthelp then
    application.export(environment.arguments.exporthelp,filename)
elseif environment.arguments.make then
    scripts.plain.make(texengine,texformat)
elseif filename then
    scripts.plain.run(texengine,texformat,filename)
else
    application.help()
end

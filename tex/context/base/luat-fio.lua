if not modules then modules = { } end modules ['luat-fio'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local texiowrite_nl = (texio and texio.write_nl) or print
local texiowrite    = (texio and texio.write) or print

local format = string.format

texconfig.kpse_init        = false
texconfig.trace_file_names = true -- also influences pdf fonts reporting .. todo
texconfig.max_print_line   = 100000

kpse = { } setmetatable(kpse, { __index = function(k,v) return input[v] end } )

-- if still present, we overload kpse (put it off-line so to say)

if not resolvers.instance then

    resolvers.reset()

    resolvers.instance.progname   = 'context'
    resolvers.instance.engine     = 'luatex'
    resolvers.instance.validfile  = resolvers.validctxfile

    resolvers.load()

    if callback then

        callback.register('find_read_file'      , function(id,name) return resolvers.findtexfile(name) end)
        callback.register('open_read_file'      , function(   name) return resolvers.opentexfile(name) end)

        callback.register('find_data_file'      , function(name) return resolvers.findbinfile(name,"tex") end)
        callback.register('find_enc_file'       , function(name) return resolvers.findbinfile(name,"enc") end)
        callback.register('find_font_file'      , function(name) return resolvers.findbinfile(name,"tfm") end)
        callback.register('find_format_file'    , function(name) return resolvers.findbinfile(name,"fmt") end)
        callback.register('find_image_file'     , function(name) return resolvers.findbinfile(name,"tex") end)
        callback.register('find_map_file'       , function(name) return resolvers.findbinfile(name,"map") end)
        callback.register('find_ocp_file'       , function(name) return resolvers.findbinfile(name,"ocp") end)
        callback.register('find_opentype_file'  , function(name) return resolvers.findbinfile(name,"otf") end)
        callback.register('find_output_file'    , function(name) return name                          end)
        callback.register('find_pk_file'        , function(name) return resolvers.findbinfile(name,"pk")  end)
        callback.register('find_sfd_file'       , function(name) return resolvers.findbinfile(name,"sfd") end)
        callback.register('find_truetype_file'  , function(name) return resolvers.findbinfile(name,"ttf") end)
        callback.register('find_type1_file'     , function(name) return resolvers.findbinfile(name,"pfb") end)
        callback.register('find_vf_file'        , function(name) return resolvers.findbinfile(name,"vf")  end)

        callback.register('read_data_file'      , function(file) return resolvers.loadbinfile(file,"tex") end)
        callback.register('read_enc_file'       , function(file) return resolvers.loadbinfile(file,"enc") end)
        callback.register('read_font_file'      , function(file) return resolvers.loadbinfile(file,"tfm") end)
     -- format
     -- image
        callback.register('read_map_file'       , function(file) return resolvers.loadbinfile(file,"map") end)
        callback.register('read_ocp_file'       , function(file) return resolvers.loadbinfile(file,"ocp") end)
     -- output
        callback.register('read_pk_file'        , function(file) return resolvers.loadbinfile(file,"pk")  end)
        callback.register('read_sfd_file'       , function(file) return resolvers.loadbinfile(file,"sfd") end)
        callback.register('read_vf_file'        , function(file) return resolvers.loadbinfile(file,"vf" ) end)

        callback.register('find_font_file'      , function(name) return resolvers.findbinfile(name,"ofm") end)
        callback.register('find_vf_file'        , function(name) return resolvers.findbinfile(name,"ovf") end)

        callback.register('read_font_file'      , function(file) return resolvers.loadbinfile(file,"ofm") end)
        callback.register('read_vf_file'        , function(file) return resolvers.loadbinfile(file,"ovf") end)

     -- callback.register('read_opentype_file'  , function(file) return resolvers.loadbinfile(file,"otf") end)
     -- callback.register('read_truetype_file'  , function(file) return resolvers.loadbinfile(file,"ttf") end)
     -- callback.register('read_type1_file'     , function(file) return resolvers.loadbinfile(file,"pfb") end)

        callback.register('find_write_file'     , function(id,name) return name end)
        callback.register('find_format_file'    , function(name)    return name end)

    end

end

statistics.register("input load time", function()
    return format("%s seconds", statistics.elapsedtime(resolvers.instance))
end)

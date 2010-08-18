return {

    type    = "configuration",
    version = "1.0.2",
    date    = "2010-06-07",
    time    = "14:49:00",
    comment = "ConTeXt MkIV configuration file",
    author  = "Hans Hagen, PRAGMA-ADE, Hasselt NL",

    content = {

     -- LUACSTRIP       = 'f',
     -- PURGECACHE      = 't',

        TEXMFCACHE      = "$SELFAUTOPARENT/texmf-cache",

        TEXMFOS         = "$SELFAUTODIR",
        TEXMFSYSTEM     = "$SELFAUTOPARENT/texmf-$SELFAUTOSYSTEM",
        TEXMFMAIN       = "$SELFAUTOPARENT/texmf",
        TEXMFCONTEXT    = "$SELFAUTOPARENT/texmf-context",
        TEXMFLOCAL      = "$SELFAUTOPARENT/texmf-local",
        TEXMFFONTS      = "$SELFAUTOPARENT/texmf-fonts",
        TEXMFPROJECT    = "$SELFAUTOPARENT/texmf-project",

        -- I don't like this texmf under home and texmf-home would make more
        -- sense. One never knows what installers put under texmf anywhere and
        -- sorting out problems will be a pain.

        TEXMFHOME       = "$HOME/texmf", -- "tree:///$HOME/texmf

        -- We need texmfos for a few rare files but as I have a few more bin trees
        -- a hack is needed. Maybe other users also have texmf-platform-new trees.

        TEXMF           = "{$TEXMFHOME,!!$TEXMFPROJECT,!!$TEXMFFONTS,!!$TEXMFLOCAL,!!$TEXMFCONTEXT,!!$TEXMFSYSTEM,!!$TEXMFMAIN}",

        TEXFONTMAPS     = ".;$TEXMF/fonts/data//;$TEXMF/fonts/map/{pdftex,dvips}//",
        ENCFONTS        = ".;$TEXMF/fonts/data//;$TEXMF/fonts/enc/{dvips,pdftex}//",
        VFFONTS         = ".;$TEXMF/fonts/{data,vf}//",
        TFMFONTS        = ".;$TEXMF/fonts/{data,tfm}//",
        T1FONTS         = ".;$TEXMF/fonts/{data,type1,pfb}//;$OSFONTDIR",
        AFMFONTS        = ".;$TEXMF/fonts/{data,afm}//;$OSFONTDIR",
        TTFONTS         = ".;$TEXMF/fonts/{data,truetype,ttf}//;$OSFONTDIR",
        OPENTYPEFONTS   = ".;$TEXMF/fonts/{data,opentype}//;$OSFONTDIR",
        CMAPFONTS       = ".;$TEXMF/fonts/cmap//",
        FONTFEATURES    = ".;$TEXMF/fonts/{data,fea}//;$OPENTYPEFONTS;$TTFONTS;$T1FONTS;$AFMFONTS",
        FONTCIDMAPS     = ".;$TEXMF/fonts/{data,cid}//;$OPENTYPEFONTS;$TTFONTS;$T1FONTS;$AFMFONTS",
        OFMFONTS        = ".;$TEXMF/fonts/{data,ofm,tfm}//",
        OVFFONTS        = ".;$TEXMF/fonts/{data,ovf,vf}//",

        TEXINPUTS       = ".;$TEXMF/tex/{context,plain/base,generic}//",
        MPINPUTS        = ".;$TEXMF/metapost/{context,base,}//",

        -- In the next variable the inputs path will go away.

        TEXMFSCRIPTS    = ".;$TEXMF/scripts/context/{lua,ruby,python,perl}//;$TEXINPUTS",
        PERLINPUTS      = ".;$TEXMF/scripts/context/perl",
        PYTHONINPUTS    = ".;$TEXMF/scripts/context/python",
        RUBYINPUTS      = ".;$TEXMF/scripts/context/ruby",
        LUAINPUTS       = ".;$TEXINPUTS;$TEXMF/scripts/context/lua//",
        CLUAINPUTS      = ".;$SELFAUTOLOC/lib/{$progname,$engine,}/lua//",

        -- Not really used by MkIV so they might go away.

        BIBINPUTS       = ".;$TEXMF/bibtex/bib//",
        BSTINPUTS       = ".;$TEXMF/bibtex/bst//",

        -- Experimental

        ICCPROFILES     = ".;$TEXMF/colors/icc/{context,profiles}//;$OSCOLORDIR",

        -- Sort of obsolete.

        OTPINPUTS       = ".;$TEXMF/omega/otp//",
        OCPINPUTS       = ".;$TEXMF/omega/ocp//",

        -- A few special ones that will change some day.

        FONTCONFIG_FILE = "fonts.conf",
        FONTCONFIG_PATH = "$TEXMFSYSTEM/fonts/conf",
        FC_CACHEDIR     = "$TEXMFSYSTEM/fonts/cache", -- not needed

        -- Some of the following parameters will disappear. Also, some are
        -- not used at all as we disable the ocp mechanism. At some point
        -- it makes more sense then to turn then into directives.

        context = {

            hash_extra     =  "100000",
            nest_size      =     "500",
            param_size     =   "10000",
            save_size      =   "50000",
            stack_size     =   "10000",
            expand_depth   =   "10000",
            max_print_line =   "10000",
            max_in_open    =     "256",

            ocp_stack_size =   "10000",
            ocp_list_size  =    "1000",

            buf_size       = "4000000", -- obsolete
            ocp_buf_size   =  "500000", -- obsolete

        },

        -- We have a few reserved subtables. These control runtime behaviour. The
        -- keys have names like 'foo.bar' which means that you have to use keys
        -- like ['foo.bar'] so for convenience we also support 'foo_bar'.

        directives = {
         -- system_checkglobals = "10",
         -- system.nostatistics = "yes",
            system_errorcontext = "10",
            mplib_texerrors     = "yes",
        },

        experiments = {
            fonts_autorscale = "yes",
        },

        trackers = {

        },

        -- The io modes are similar to the traditional ones. Possible values
        -- are all, paranoid and restricted.

        output_mode  = "restricted",
        input_mode   = "any",

        -- The following variable is under consideration. We do have protection
        -- mechanims but it's not enabled by default.

        command_mode = "any", -- any none list
        command_list = "mtxrun, convert, inkscape, gs, imagemagick, curl, bibtex, pstoedit",

    },

    TEXMFCACHE  = "$SELFAUTOPARENT/texmf-cache", -- for old times sake

}

return {

    type    = "configuration",
    version = "1.0.2",
    date    = "2010-06-07",
    time    = "14:49:00",
    comment = "ConTeXt MkIV configuration file",
    author  = "Hans Hagen, PRAGMA-ADE, Hasselt NL",

    content = {

        variables = {

            -- The following variable is predefined (but can be overloaded) and in
            -- most cases you can leve this one untouched. The built-in definition
            -- permits relocation of the tree.
            --
            -- TEXMFCNF     = "{selfautodir:,selfautoparent:}{,{/share,}/texmf{-local,}/web2c}"
            --
            -- more readable than "selfautoparent:{/texmf{-local,}{,/web2c},}}" is:
            --
            -- TEXMFCNF     = {
            --     "selfautoparent:/texmf-local",
            --     "selfautoparent:/texmf-local/web2c",
            --     "selfautoparent:/texmf",
            --     "selfautoparent:/texmf/web2c",
            --     "selfautoparent:",
            -- }

            -- We have only one cache path but there can be more. The first writable one
            -- will be chose but there can be more readable paths.

            TEXMFCACHE      = "$SELFAUTOPARENT/texmf-cache",

            -- I don't like this texmf under home and texmf-home would make more
            -- sense. One never knows what installers put under texmf anywhere and
            -- sorting out problems will be a pain. But on the other hand ... home
            -- mess is normally under the users own responsibility.
            --
            -- By using prefixes we don't get expanded paths in the cache __path__
            -- entry. This makes the tex root relocatable.

            TEXMFOS         = "selfautodir:",
            TEXMFSYSTEM     = "selfautoparent:texmf-$SELFAUTOSYSTEM",
            TEXMFMAIN       = "selfautoparent:texmf",
            TEXMFCONTEXT    = "selfautoparent:texmf-context",
            TEXMFLOCAL      = "selfautoparent:texmf-local",
            TEXMFFONTS      = "selfautoparent:texmf-fonts",
            TEXMFPROJECT    = "selfautoparent:texmf-project",
            TEXMFHOME       = "home:texmf",

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

            TEXINPUTS       = ".;{$CTXDEVTXPATH};$TEXMF/tex/{context,plain/base,generic}//",
            MPINPUTS        = ".;{$CTXDEVMPPATH};$TEXMF/metapost/{context,base,}//",

            -- In the next variable the inputs path will go away.

            TEXMFSCRIPTS    = ".;$CTXDEVLUPATH;$CTXDEVRBPATH;$CTXDEVPLPATH;$TEXMF/scripts/context/{lua,ruby,python,perl}//;$TEXINPUTS",
            PERLINPUTS      = ".;$CTXDEVPLPATH;$TEXMF/scripts/context/perl",
            PYTHONINPUTS    = ".;$CTXDEVPYPATH;$TEXMF/scripts/context/python",
            RUBYINPUTS      = ".;$CTXDEVRBPATH;$TEXMF/scripts/context/ruby",
            LUAINPUTS       = ".;$CTXDEVLUPATH;$TEXINPUTS;$TEXMF/scripts/context/lua//",
            CLUAINPUTS      = ".;$SELFAUTOLOC/lib/{$progname,$engine,}/lua//",

            -- Not really used by MkIV so they might go away.

            BIBINPUTS       = ".;{$CTXDEVTXPATH};$TEXMF/bibtex/bib//",
            BSTINPUTS       = ".;{$CTXDEVTXPATH};$TEXMF/bibtex/bst//",

            -- Experimental

            ICCPROFILES     = ".;$TEXMF/colors/icc/{context,profiles}//;$OSCOLORDIR",

            -- Sort of obsolete.

            OTPINPUTS       = ".;$TEXMF/omega/otp//",
            OCPINPUTS       = ".;$TEXMF/omega/ocp//",

            -- A few special ones that will change some day.

            FONTCONFIG_FILE = "fonts.conf",
            FONTCONFIG_PATH = "$TEXMFSYSTEM/fonts/conf",
            FC_CACHEDIR     = "$TEXMFSYSTEM/fonts/cache", -- not needed

            -- The io modes are similar to the traditional ones. Possible values
            -- are all, paranoid and restricted.

            output_mode  = "restricted",
            input_mode   = "any",

            -- The following variable is under consideration. We do have protection
            -- mechanims but it's not enabled by default.

            command_mode = "any", -- any none list
            command_list = "mtxrun, convert, inkscape, gs, imagemagick, curl, bibtex, pstoedit",

        },

        -- We have a few reserved subtables. These control runtime behaviour. The
        -- keys have names like 'foo.bar' which means that you have to use keys
        -- like ['foo.bar'] so for convenience we also support 'foo_bar'.

        directives = {
            ["luatex.expanddepth"]       =  "10000", -- 10000
            ["luatex.hashextra"]         = "100000", --     0
            ["luatex.nestsize"]          =   "1000", --    50
            ["luatex.maxinopen"]         =    "500", --    15
            ["luatex.maxprintline"]      = " 10000", --    79
            ["luatex.maxstrings"]        = "500000", -- 15000 -- obsolete
            ["luatex.paramsize"]         =  "25000", --    60
            ["luatex.savesize"]          =  "50000", --  4000
            ["luatex.stacksize"]         =  "10000", --   300

         -- ["system.checkglobals"]      = "10",
         -- ["system.nostatistics"]      = "yes",
            ["system.errorcontext"]      = "10",

            ["mplib.texerrors"]          = "yes",

         -- ["fonts.otf.loader.method"]  = "table", -- table mixed sparse
         -- ["fonts.otf.loader.cleanup"] = "0",     -- 0 1 2 3

            ["system.compile.cleanup"]   = "no",    -- remove tma files
            ["system.compile.strip"]     = "yes",   -- strip tmc files

            -- The io modes are similar to the traditional ones. Possible values
            -- are all, paranoid and restricted.

            ["system.outputmode"]        = "restricted",
            ["system.inputmode"]         = "any",

            -- The following variable is under consideration. We do have protection
            -- mechanims but it's not enabled by default.

            ["system.commandmode"]       = "any", -- any none list
            ["system.commandlist"]       = "mtxrun, convert, inkscape, gs, imagemagick, curl, bibtex, pstoedit",

        },

        experiments = {
            ["fonts.autorscale"] = "yes",
        },

        trackers = {
        },

    },

    TEXMFCACHE  = "$SELFAUTOPARENT/texmf-cache", -- for old times sake

}

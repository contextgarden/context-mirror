return {

    type    = "configuration",
    version = "1.1.1",
    date    = "2011-06-02",
    time    = "14:59:00",
    comment = "TeX Live differences",

    parent  = "contextcnf.lua",

    content = {

        -- Keep in mind that MkIV is is relatively new and there is zero change that
        -- (configuration) files will be found on older obsolete locations.

        variables = {

         -- This needs testing and if it works, then we can remove the texmflocal setting later on
         --
         -- TEXMFCNF        = "{selfautodir:{/share,}/texmf-local/web2c,selfautoparent:{/share,}/texmf{-local,}/web2c}",

            TEXMFCACHE      = "selfautoparent:texmf-var;~/.texlive2011/texmf-cache",
            TEXMFCONFIG     = "~/.texlive2011/texmf-config",

            TEXMFSYSTEM     = "selfautoparent:$SELFAUTOSYSTEM",
            TEXMFCONTEXT    = "selfautoparent:texmf-dist",

            TEXMFLOCAL      = string.gsub(resolvers.prefixes.selfautoparent(),"20%d%d$","texmf-local"),

            TEXMFSYSCONFIG  = "selfautoparent:texmf-config",

            TEXMFSYSVAR     = "selfautoparent:texmf-var",

            TEXMF           = "{$TEXMFCONFIG,$TEXMFHOME,!!$TEXMFSYSCONFIG,!!$TEXMFPROJECT,!!$TEXMFFONTS,!!$TEXMFLOCAL,!!$TEXMFCONTEXT,!!$TEXMFSYSTEM,!!$TEXMFMAIN}",

            FONTCONFIG_PATH = "$TEXMFSYSVAR/fonts/conf",

        },
    },
}

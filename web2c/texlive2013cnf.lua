local liveyear = string.match(resolvers.prefixes.selfautoparent(),"(20%d%d)") or "2013"

return {

    type    = "configuration",
    version = "1.1.2",
    date    = "2013-06-02",
    time    = "16:15:00",
    comment = "TeX Live differences",

    parent  = "contextcnf.lua",

    content = {

        -- Keep in mind that MkIV is is relatively new and there is zero change that
        -- (configuration) files will be found on older obsolete locations.

        variables = {

         -- This needs testing and if it works, then we can remove the texmflocal setting later on
         --
         -- TEXMFCNF        = "{selfautodir:{/share,}/texmf-local/web2c,selfautoparent:{/share,}/texmf{-local,}/web2c}",

            TEXMFCACHE      = string.format("selfautoparent:texmf-var;~/.texlive%s/texmf-cache",liveyear),

            TEXMFSYSTEM     = "selfautoparent:$SELFAUTOSYSTEM",
            TEXMFCONTEXT    = "selfautoparent:texmf-dist",

         -- TEXMFLOCAL      = "selfautoparent:../texmf-local"), -- should also work
            TEXMFLOCAL      = string.gsub(resolvers.prefixes.selfautoparent(),"20%d%d$","texmf-local"),

            TEXMFSYSCONFIG  = "selfautoparent:texmf-config",
            TEXMFSYSVAR     = "selfautoparent:texmf-var",
            TEXMFCONFIG     = string.format("home:.texlive%s/texmf-config",liveyear),
            TEXMFVAR        = string.format("home:.texlive%s/texmf-var",liveyear),

            -- We have only one cache path but there can be more. The first writable one
            -- will be chosen but there can be more readable paths.

            TEXMFCACHE      = "$TEXMFSYSVAR;$TEXMFVAR",

            TEXMF           = "{$TEXMFCONFIG,$TEXMFHOME,!!$TEXMFSYSCONFIG,!!$TEXMFPROJECT,!!$TEXMFFONTS,!!$TEXMFLOCAL,!!$TEXMFCONTEXT,!!$TEXMFSYSTEM,!!$TEXMFDIST,!!$TEXMFMAIN}",

            FONTCONFIG_PATH = "$TEXMFSYSVAR/fonts/conf",

        },
    },
}

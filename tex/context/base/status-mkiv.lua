-- colo-run.mkiv colo-imp-*.mkiv ...

return {
    core = {
        {
            filename = "syst-ini",
            marktype = "mkiv",
            status   = "okay",
        },
        {
            filename = "norm-ctx",
            marktype = "mkiv",
            status   = "okay",
        },
        {
            filename = "syst-pln",
            marktype = "mkiv",
            status   = "okay",
        },
        {
            filename = "syst-mes",
            marktype = "mkiv",
            status   = "okay",
        },
        {
            filename = "luat-cod",
            marktype = "mkiv",
            status   = "okay",
        },
        {
            filename = "luat-bas",
            marktype = "mkiv",
            status   = "okay",
            comment  = "maybe combine (3)",
        },
        {
            filename = "luat-lib",
            marktype = "mkiv",
            status   = "okay",
            comment  = "maybe combine (3)",
        },
        {
            filename = "catc-ini",
            marktype = "mkiv",
            status   = "okay",
        },
        {
            filename = "catc-act",
            marktype = "mkiv",
            status   = "okay",
            comment  = "forward dependency",
        },
        {
            filename = "catc-def",
            marktype = "mkiv",
            status   = "okay",
        },
        {
            filename = "catc-ctx",
            marktype = "mkiv",
            status   = "okay",
        },
        {
            filename = "catc-sym",
            marktype = "mkiv",
            status   = "okay",
        },
        {
            filename = "cldf-ini",
            marktype = "mkiv",
            status   = "okay",
            comment  = "maybe combine (1)",
        },
        {
            filename = "syst-aux",
            marktype = "mkiv",
            status   = "okay",
        },
        {
            filename = "syst-lua",
            marktype = "mkiv",
            status   = "okay",
            comment  = "maybe combine (1)",
        },
        {
            filename = "syst-con",
            marktype = "mkiv",
            status   = "okay",
            comment  = "maybe combine (1)",
        },
        {
            filename = "syst-fnt",
            marktype = "mkiv",
            status   = "okay",
            comment  = "maybe combine (1)",
        },
        {
            filename = "syst-rtp",
            marktype = "mkiv",
            status   = "okay",
            comment  = "maybe combine (1)",
        },
        {
            filename = "file-ini",
            marktype = "mkvi",
            status   = "okay",
            comment  = "maybe combine (2)",
        },
        {
            filename = "file-res",
            marktype = "mkvi",
            status   = "okay",
            comment  = "maybe combine (2)",
        },
        {
            filename = "file-lib",
            marktype = "mkvi",
            status   = "okay",
        },
        {
            filename = "supp-dir",
            marktype = "mkiv",
            status   = "okay",
        },
        {
            filename = "char-ini",
            marktype = "mkiv",
            status   = "okay",
        },
        {
            filename = "char-utf",
            marktype = "mkiv",
            status   = "okay",
        },
        {
            filename = "char-act",
            marktype = "mkiv",
            status   = "okay",
            comment  = "forward dependency",
        },
        {
            filename = "mult-ini",
            marktype = "mkiv",
            status   = "okay",
        },
        {
            filename = "mult-sys",
            marktype = "mkiv",
            status   = "okay",
        },
        {
            filename = "mult-aux",
            marktype = "mkiv",
            status   = "okay",
        },
        {
            filename = "mult-def",
            marktype = "mkiv",
            status   = "okay",
        },
        {
            filename = "mult-chk",
            marktype = "mkiv",
            status   = "okay",
        },
        {
            filename = "mult-dim",
            marktype = "mkvi",
            status   = "okay",
        },
        {
            filename = "cldf-int",
            marktype = "mkiv",
            status   = "okay",
        },
        {
            filename = "luat-ini",
            marktype = "mkiv",
            status   = "okay",
        },
        {
            filename = "toks-ini",
            marktype = "mkiv",
            status   = "okay",
            comment  = "maybe this becomes a runtime module",
        },
        {
            filename = "attr-ini",
            marktype = "mkiv",
            status   = "okay",
        },
        {
            filename = "core-ini",
            marktype = "mkiv",
            status   = "okay",
            comment  = "code might move from here",
        },
        {
            filename = "core-env",
            marktype = "mkiv",
            status   = "okay",
            comment  = "might need more redoing",
        },
        {
            filename = "layo-ini",
            marktype = "mkiv",
            status   = "todo",
            comment  = "more might move to here",
        },
        {
            filename = "node-ini",
            marktype = "mkiv",
            status   = "okay",
            comment  = "maybe this becomes a runtime module",
        },
        {
            filename = "cldf-bas",
            marktype = "mkiv",
            status   = "okay",
        },
        {
            filename = "node-fin",
            marktype = "mkiv",
            status   = "okay",
            comment  = "might need more redoing",
        },
        {
            filename = "node-mig",
            marktype = "mkiv",
            status   = "okay",
            comment  = "needs integration and configuration",
        },
        {
            filename = "typo-bld",
            marktype = "mkiv",
            status   = "okay",
        },
        {
            filename = "back-ini",
            marktype = "mkiv",
            status   = "okay",
        },
        {
            filename = "attr-col",
            marktype = "mkiv",
            status   = "okay",
        },
        {
            filename = "attr-lay",
            marktype = "mkiv",
            status   = "okay",
        },
        {
            filename = "attr-neg",
            marktype = "mkiv",
            status   = "okay",
        },
        {
            filename = "attr-eff",
            marktype = "mkiv",
            status   = "okay",
        },
        {
            filename = "trac-tex",
            marktype = "mkiv",
            status   = "okay",
            comment  = "needs more usage",
        },
        {
            filename = "trac-deb",
            marktype = "mkiv",
            status   = "okay",
        },
        {
            filename = "supp-box",
            marktype = "mkiv",
            status   = "okay",
        },
     -- {
     --     filename = "supp-vis",
     --     marktype = "mkiv",
     --     status   = "todo",
     --     comment  = "will become a module (and part will stay in the core)",
     -- },
     -- {
     --     filename = "supp-fun",
     --     marktype = "mkiv",
     --     status   = "todo",
     --     comment  = "will be integrated elsewhere",
     -- },
        {
            filename = "supp-ran",
            marktype = "mkiv",
            status   = "okay",
        },
        {
            filename = "supp-mat",
            marktype = "mkiv",
            status   = "okay",
            comment  = "will be moved to the math-* modules",
        },
     -- {
     --     filename = "supp-num",
     --     marktype = "mkiv",
     --     status   = "obsolete",
     --     comment  = "replaced by units",
     -- },
        {
            filename = "typo-ini",
            marktype = "mkiv",
            status   = "okay",
            comment  = "will grow",
        },
        {
            filename = "page-ins",
            marktype = "mkiv",
            status   = "okay",
            comment  = "dealing with insertions might change",
        },
        {
            filename = "file-syn",
            marktype = "mkvi",
            status   = "okay",
        },
        {
            filename = "file-mod",
            marktype = "mkvi",
            status   = "okay",
        },
        {
            filename = "core-con",
            marktype = "mkiv",
            status   = "okay",
        },
        {
            filename = "cont-fil",
            marktype = "mkiv",
            status   = "okay",
        },
        {
            filename = "cont-nop",
            marktype = "mkiv",
            status   = "okay",
        },
        {
            filename = "cont-yes",
            marktype = "mkiv",
            status   = "okay",
        },
        {
            filename = "regi-ini",
            marktype = "mkiv",
            status   = "okay",
        },
        {
            filename = "enco-ini",
            marktype = "mkiv",
            status   = "okay",
        },
        {
            filename = "hand-ini",
            marktype = "mkiv",
            status   = "okay",
        },
        {
            filename = "lang-ini",
            marktype = "mkiv",
            status   = "okay",
        },
        {
            filename = "lang-lab",
            marktype = "mkiv",
            status   = "okay",
            comment  = "namespace should be languages",
        },
        {
            filename = "unic-ini",
            marktype = "mkiv",
            status   = "okay",
        },
        {
            filename = "core-uti",
            marktype = "mkiv",
            status   = "okay",
        },
        {
            filename = "core-two",
            marktype = "mkiv",
            status   = "okay",
            comment  = "maybe rename to core-two",
        },
        {
            filename = "core-dat",
            marktype = "mkiv",
            status   = "okay",
        },
        {
            filename = "colo-ini",
            marktype = "mkiv",
            status   = "okay",
        },
        {
            filename = "colo-ext",
            marktype = "mkiv",
            status   = "okay",
        },
        {
            filename = "colo-grp",
            marktype = "mkiv",
            status   = "okay",
        },
        {
            filename = "node-bck",
            marktype = "mkiv",
            status   = "okay",
        },
        {
            filename = "pack-cut",
            marktype = "mkiv",
            status   = "okay",
        },
        {
            filename = "lang-mis",
            marktype = "mkiv",
            status   = "okay",
        },
        {
            filename = "lang-url",
            marktype = "mkiv",
            status   = "okay",
        },
        {
            filename = "lang-def",
            marktype = "mkiv",
            status   = "okay",
        },
        {
            filename = "lang-wrd",
            marktype = "mkiv",
            status   = "okay",
        },
        {
            filename = "file-job",
            marktype = "mkvi",
            status   = "okay",
            comment  = "might need more redoing",
        },
        {
            filename = "symb-ini",
            marktype = "mkiv",
            status   = "okay",
        },
        {
            filename = "sort-ini",
            marktype = "mkiv",
            status   = "okay",
        },
        {
            filename = "pack-mis",
            marktype = "mkvi",
            status   = "okay",
        },
        {
            filename = "pack-rul",
            marktype = "mkiv",
            status   = "okay",
        },
        {
            filename = "pack-mrl",
            marktype = "mkiv",
            status   = "okay",
            comment  = "endpar experimental code"
        },
        {
            filename = "pack-bck",
            marktype = "mkvi",
            status   = "okay",
        },
        {
            filename = "pack-fen",
            marktype = "mkiv",
            status   = "okay",
        },
        {
            filename = "lxml-ini",
            marktype = "mkiv",
            status   = "okay",
        },
        {
            filename = "lxml-sor",
            marktype = "mkiv",
            status   = "okay",
        },
        {
            filename = "typo-prc",
            marktype = "mkvi",
            status   = "okay",
        },
        {
            filename = "strc-ini",
            marktype = "mkvi",
            status   = "okay",
        },
        {
            filename = "strc-tag",
            marktype = "mkiv",
            status   = "okay",
        },
        {
            filename = "strc-doc",
            marktype = "mkiv",
            status   = "todo",
        },
        {
            filename = "strc-num",
            marktype = "mkiv",
            status   = "okay",
            comment  = "still some rough edges",
        },
        {
            filename = "strc-mar",
            marktype = "mkiv",
            status   = "okay",
        },
        {
            filename = "strc-sbe",
            marktype = "mkiv",
            status   = "okay",
        },
        {
            filename = "strc-lst",
            marktype = "mkiv",
            status   = "okay",
        },
        {
            filename = "strc-sec",
            marktype = "mkiv",
            status   = "todo",
        },
        {
            filename = "strc-pag",
            marktype = "mkiv",
            status   = "okay",
        },
        {
            filename = "strc-ren",
            marktype = "mkiv",
            status   = "todo",
        },
        {
            filename = "strc-xml",
            marktype = "mkiv",
            status   = "okay",
            comment  = "this module might go away",
        },
        {
            filename = "strc-def",
            marktype = "mkiv",
            status   = "todo",
        },
        {
            filename = "strc-ref",
            marktype = "mkvi",
            status   = "okay",
            comment  = "some more low level names might change",
        },
        {
            filename = "strc-reg",
            marktype = "mkiv",
            status   = "okay",
            comment  = "use setups for rendering",
        },
        {
            filename = "strc-lev",
            marktype = "mkvi",
            status   = "okay",
        },
        {
            filename = "spac-ali",
            marktype = "mkiv",
            status   = "okay",
            comment  = "maybe some tuning is needed / will happen",
        },
        {
            filename = "spac-hor",
            marktype = "mkiv",
            status   = "okay",
            comment  = "probably needs some more work",
        },
        {
            filename = "spac-ver",
            marktype = "mkiv",
            status   = "okay",
            comment  = "maybe some changes will happen"
        },
        {
            filename = "spac-lin",
            marktype = "mkiv",
            status   = "okay",
            comment  = "could be improved if needed"
        },
        {
            filename = "spac-pag",
            marktype = "mkiv",
            status   = "okay",
            comment  = "this needs to be checked occasionally",
        },
        {
            filename = "spac-par",
            marktype = "mkiv",
            status   = "okay",
        },
        {
            filename = "spac-def",
            marktype = "mkiv",
            status   = "todo",
        },
        {
            filename = "spac-grd",
            marktype = "mkiv",
            status   = "todo",
            comment  = "needs thinking and redoing",
        },
        {
            filename = "anch-pos",
            marktype = "mkiv",
            status   = "okay",
            comment  = "in transition",
        },
        {
            filename = "scrn-ini",
            marktype = "mkvi",
            status   = "okay",
            comment  = "maybe change locationattribute names"
        },
        {
            filename = "scrn-ref",
            marktype = "mkvi",
            status   = "okay",
            comment  = "namespace needs checking"
        },
        {
            filename = "pack-obj",
            marktype = "mkiv",
            status   = "okay",
            comment  = "will change when we have objects at lua end",
        },
        {
            filename = "strc-itm",
            marktype = "mkvi",
            status   = "okay",
        },
        {
            filename = "strc-con",
            marktype = "mkiv",
            status   = "todo",
        },
        {
            filename = "strc-des",
            marktype = "mkiv",
            status   = "todo",
        },
        {
            filename = "strc-enu",
            marktype = "mkiv",
            status   = "todo",
        },
        {
            filename = "strc-ind",
            marktype = "mkiv",
            status   = "okay",
        },
        {
            filename = "strc-lab",
            marktype = "mkiv",
            status   = "okay",
            comment  = "needs to be adapted when strc-con/des/enu changes",
        },
        {
            filename = "core-sys",
            marktype = "mkiv",
            status   = "okay",
            comment  = "a funny mix",
        },
        {
            filename = "page-var",
            marktype = "mkiv",
            status   = "okay",
        },
        {
            filename = "page-otr",
            marktype = "mkvi",
            status   = "okay",
        },
        {
            filename = "page-ini",
            marktype = "mkiv",
            status   = "okay",
            comment  = "code might end up elsewhere",
        },
        {
            filename = "page-fac",
            marktype = "mkiv",
            status   = "okay",
        },
        {
            filename = "page-brk",
            marktype = "mkiv",
            status   = "okay",
            comment  = "otr commands will be redone",
        },
        {
            filename = "page-col",
            marktype = "mkiv",
            status   = "okay",
            comment  = "helpers for columns",
        },
        {
            filename = "page-inf",
            marktype = "mkiv",
            status   = "okay",
            comment  = "room for improvement and extension",
        },
        {
            filename = "page-grd",
            marktype = "mkiv",
            status   = "okay",
        },
        {
            filename = "page-flt",
            marktype = "mkiv",
            status   = "okay",
            comment  = "will be extended when columns are redone",
        },
        {
            filename = "page-bck",
            marktype = "mkiv",
            status   = "okay",
        },
        {
            filename = "page-not",
            marktype = "mkiv",
            status   = "todo",
        },
        {
            filename = "page-one",
            marktype = "mkiv",
            status   = "okay",
            comment  = "can probably be improved",
        },
        {
            filename = "page-lay",
            marktype = "mkiv",
            status   = "okay",
        },
        {
            filename = "page-box",
            marktype = "mkvi",
            status   = "okay",
        },
        {
            filename = "page-txt",
            marktype = "mkvi",
            status   = "okay",
            comment  = "a few things left",
        },
        {
            filename = "page-sid",
            marktype = "mkiv",
            status   = "okay",
        },
        {
            filename = "strc-flt",
            marktype = "mkvi",
            status   = "okay",
            comment  = "in due time we need a further cleanup",
        },
        {
            filename = "page-pst",
            marktype = "mkiv",
            status   = "okay",
        },
        {
            filename = "page-mbk",
            marktype = "mkvi",
            status   = "okay",
            comment  = "might be extended",
        },
        {
            filename = "page-mul",
            marktype = "mkiv",
            status   = "todo",
            comment  = "will be reimplemented",
        },
        {
            filename = "page-set",
            marktype = "mkiv",
            status   = "todo",
            comment  = "will be reimplemented",
        },
        {
            filename = "pack-lyr",
            marktype = "mkiv",
            status   = "okay",
        },
        {
            filename = "pack-pos",
            marktype = "mkiv",
            status   = "okay",
        },
        {
            filename = "page-mak",
            marktype = "mkvi",
            status   = "okay",
        },
        {
            filename = "page-lin",
            marktype = "mkiv",
            status   = "okay",
            comment  = "will probably be overhauled some day"
        },
        {
            filename = "page-par",
            marktype = "mkiv",
            status   = "okay",
            comment  = "might get extended",
        },
        {
            filename = "typo-pag",
            marktype = "mkiv",
            status   = "okay",
        },
        {
            filename = "typo-mar",
            marktype = "mkiv",
            status   = "okay",
        },
        {
            filename = "typo-itm",
            marktype = "mkiv",
            status   = "okay",
        },
        {
            filename = "buff-ini",
            marktype = "mkiv",
            status   = "okay",
            comment  = "check other modules for buffer usage",
        },
        {
            filename = "buff-ver",
            marktype = "mkiv",
            status   = "okay",
            comment  = "check obsolete processbuffer"
        },
        {
            filename = "buff-par",
            marktype = "mkvi",
            status   = "okay",
            comment  = "experimental code",
        },
        {
            filename = "buff-imp-tex",
            marktype = "mkiv",
            status   = "okay",
        },
        {
            filename = "buff-imp-mp",
            marktype = "mkiv",
            status   = "okay",
        },
        {
            filename = "buff-imp-lua",
            marktype = "mkiv",
            status   = "okay",
        },
        {
            filename = "buff-imp-xml",
            marktype = "mkiv",
            status   = "okay",
        },
        {
            filename = "buff-imp-parsed-xml",
            marktype = "mkiv",
            status   = "okay",
        },
        {
            filename = "strc-blk",
            marktype = "mkiv",
            status   = "okay",
        },
        {
            filename = "page-imp",
            marktype = "mkiv",
            status   = "okay",
        },
        {
            filename = "page-sel",
            marktype = "mkvi",
            status   = "okay",
            comment  = "maybe some extensions and maybe delayed loading, needs checking",
        },
        {
            filename = "page-com",
            marktype = "mkiv",
            status   = "okay",
        },
        {
            filename = "scrn-pag",
            marktype = "mkvi",
            status   = "okay",
            comment  = "namespace needs checking"
        },
        {
            filename = "scrn-wid",
            marktype = "mkvi",
            status   = "okay",
            comment  = "functionality needs checking"
        },
        {
            filename = "scrn-but",
            marktype = "mkvi",
            status   = "okay",
            comment  = "namespace needs checking"
        },
        {
            filename = "scrn-bar",
            marktype = "mkvi",
            status   = "okay",
            comment  = "namespace needs checking"
        },
        {
            filename = "strc-bkm",
            marktype = "mkiv",
            status   = "okay",
        },
        {
            filename = "tabl-com",
            marktype = "mkiv",
            status   = "okay",
            comment  = "somewhat weird",
        },
        {
            filename = "tabl-pln",
            marktype = "mkiv",
            status   = "okay",
            comment  = "unchecked",
        },
        {
            filename = "tabl-tab",
            marktype = "mkiv",
            status   = "delayed",
        },
        {
            filename = "tabl-tbl",
            marktype = "mkiv",
            status   = "okay",
            comment  = "can probably be improved (names and such)",
        },
        {
            filename = "tabl-ntb",
            marktype = "mkiv",
            status   = "okay",
            comment  = "frozen functionaly so no drastic cleanup",
        },
        {
            filename = "tabl-mis",
            marktype = "mkiv",
            status   = "okay",
        },
        {
            filename = "tabl-nte",
            marktype = "mkiv",
            status   = "okay",
        },
        {
            filename = "tabl-ltb",
            marktype = "mkiv",
            status   = "delayed",
            comment  = "will be redone when needed",
        },
        {
            filename = "tabl-tsp",
            marktype = "mkiv",
            status   = "okay",
            comment  = "will be adapted when needed (and rest is done)",
        },
        {
            filename = "tabl-xtb",
            marktype = "mkvi",
            status   = "okay",
            comment  = "namespace needs checking"
        },
        {
            filename = "java-ini",
            marktype = "mkiv",
            status   = "okay",
        },
        {
            filename = "scrn-fld",
            marktype = "mkvi",
            status   = "okay",
            comment  = "namespace needs checking"
        },
        {
            filename = "scrn-hlp",
            marktype = "mkvi",
            status   = "okay",
            comment  = "namespace needs checking"
        },
        {
            filename = "char-enc",
            marktype = "mkiv",
            status   = "okay",
        },
        {
            filename = "font-lib",
            marktype = "mkvi",
            status   = "okay",
        },
        {
            filename = "font-fil",
            marktype = "mkvi",
            status   = "okay",
        },
        {
            filename = "font-fea",
            marktype = "mkvi",
            status   = "okay",
        },
        {
            filename = "font-mat",
            marktype = "mkvi",
            status   = "okay",
        },
        {
            filename = "font-ini",
            marktype = "mkvi",
            status   = "okay",
            comment  = "needs occasional checking and upgrading",
        },
        {
            filename = "font-sym",
            marktype = "mkvi",
            status   = "okay",
        },
        {
            filename = "font-sty",
            marktype = "mkvi",
            status   = "okay",
        },
        {
            filename = "font-set",
            marktype = "mkvi",
            status   = "okay",
        },
        {
            filename = "font-emp",
            marktype = "mkvi",
            status   = "okay",
        },
        {
            filename = "font-col",
            marktype = "mkvi",
            status   = "okay",
        },
        {
            filename = "font-pre",
            marktype = "mkiv",
            status   = "okay",
        },
        {
            filename = "font-unk",
            marktype = "mkiv",
            status   = "okay",
        },
        {
            filename = "font-tra",
            marktype = "mkiv",
            status   = "okay",
            comment  = "likely this will become a module",
        },
        {
            filename = "font-uni",
            marktype = "mkiv",
            status   = "okay",
            comment  = "this one might be merged",
        },
        {
            filename = "font-col",
            marktype = "mkvi",
            status   = "okay",
        },
        {
            filename = "font-gds",
            marktype = "mkvi",
            status   = "okay",
        },
        {
            filename = "font-aux",
            marktype = "mkvi",
            status   = "okay",
        },
        {
            filename = "lxml-css",
            marktype = "mkiv",
            status   = "okay",
            comment  = "this is work in progress",
        },
        {
            filename = "spac-chr",
            marktype = "mkiv",
            status   = "okay",
        },
        {
            filename = "spac-cha",
            marktype = "mkiv",
            status   = "okay",
        },
        {
            filename = "blob-ini",
            marktype = "mkiv",
            status   = "okay",
            comment  = "work in progress",
        },
        {
            filename = "trac-vis",
            marktype = "mkvi",
            status   = "okay",
        },
        {
            filename = "typo-cln",
            marktype = "mkiv",
            status   = "okay",
        },
        {
            filename = "typo-spa",
            marktype = "mkiv",
            status   = "okay",
        },
        {
            filename = "typo-krn",
            marktype = "mkiv",
            status   = "okay",
            comment  = "do we keep the style and color or not"
        },
        {
            filename = "typo-itc",
            marktype = "mkvi",
            status   = "okay",
        },
        {
            filename = "typo-dir",
            marktype = "mkiv",
            status   = "okay",
            comment  = "maybe singular setup"
        },
        {
            filename = "typo-brk",
            marktype = "mkiv",
            status   = "okay",
        },
        {
            filename = "typo-cap",
            marktype = "mkiv",
            status   = "okay",
        },
        {
            filename = "typo-dig",
            marktype = "mkiv",
            status   = "okay",
        },
        {
            filename = "typo-rep",
            marktype = "mkiv",
            status   = "okay",
        },
        {
            filename = "typo-txt",
            marktype = "mkvi",
            status   = "okay",
            comment  = "maybe there will be a nicer interface",
        },
        {
            filename = "typo-par",
            marktype = "mkiv",
            status   = "okay",
            comment  = "might get extended",
        },
        {
            filename = "type-ini",
            marktype = "mkvi",
            status   = "okay",
        },
        {
            filename = "type-set",
            marktype = "mkiv",
            status   = "okay",
        },
        {
            filename = "scrp-ini",
            marktype = "mkiv",
            status   = "okay",
        },
        {
            filename = "prop-ini",
            marktype = "mkiv",
            status   = "okay",
            comment  = "this module is obsolete",
        },
        {
            filename = "mlib-ctx",
            marktype = "mkiv",
            status   = "okay",
        },
        {
            filename = "meta-ini",
            marktype = "mkiv",
            status   = "okay",
            comment  = "metapost code is always evolving",
        },
        {
            filename = "meta-tex",
            marktype = "mkiv",
            status   = "okay",
        },
        {
            filename = "meta-fun",
            marktype = "mkiv",
            status   = "okay",
            comment  = "maybe this one will be merged"
        },
        {
            filename = "meta-pag",
            marktype = "mkiv",
            status   = "okay",
            comment  = "might get updated when mp code gets cleaned up",
        },
        {
            filename = "meta-grd",
            marktype = "mkiv",
            status   = "okay",
        },
        {
            filename = "page-mrk",
            marktype = "mkiv",
            status   = "okay",
        },
        {
            filename = "page-flw",
            marktype = "mkiv",
            status   = "okay",
        },
        {
            filename = "page-spr",
            marktype = "mkiv",
            status   = "okay",
        },
        {
            filename = "page-plg",
            marktype = "mkiv",
            status   = "okay",
            comment  = "will be made better",
        },
        {
            filename = "page-str",
            marktype = "mkiv",
            status   = "okay",
            comment  = "needs more work (and thinking)",
        },
        {
            filename = "anch-pgr",
            marktype = "mkiv",
            status   = "okay",
            comment  = "in transition",
        },
        {
            filename = "anch-bck",
            marktype = "mkvi",
            status   = "okay",
            comment  = "in transition",
        },
        {
            filename = "anch-tab",
            marktype = "mkiv",
            status   = "okay",
            comment  = "will stay experimental for a while",
        },
        {
            filename = "anch-bar",
            marktype = "mkiv",
            status   = "okay",
        },
        {
            filename = "anch-snc",
            marktype = "mkiv",
            status   = "delayed",
            comment  = "interesting old mechanism to keep around (module?)",
        },
        {
            filename = "math-ini",
            marktype = "mkiv",
            status   = "okay",
        },
        {
            filename = "math-pln",
            marktype = "mkiv",
            status   = "okay",
            comment  = "this file might merge into others",
        },
        {
            filename = "math-for",
            marktype = "mkiv",
            status   = "okay",
        },
        {
            filename = "math-def",
            marktype = "mkiv",
            status   = "okay",
            comment  = "eventually this will be split and spread",
        },
        {
            filename = "math-ali",
            marktype = "mkiv",
            status   = "okay",
            commend  = "will be checked and improved",
        },
        {
            filename = "math-arr",
            marktype = "mkiv",
            status   = "okay",
            comment  = "needs testing",
        },
        {
            filename = "math-frc",
            marktype = "mkiv",
            status   = "okay",
            comment  = "at least for the moment",
        },
        {
            filename = "math-scr",
            marktype = "mkiv",
            status   = "okay",
        },
        {
            filename = "math-int",
            marktype = "mkiv",
            status   = "okay",
        },
        {
            filename = "math-del",
            marktype = "mkiv",
            status   = "okay",
            comment  = "code get replaced (by autodelimiters)",
        },
        {
            filename = "math-inl",
            marktype = "mkiv",
            status   = "okay",
            comment  = "code might move to here",
        },
        {
            filename = "math-dis",
            marktype = "mkiv",
            status   = "okay",
            comment  = "code might move to here",
        },
        {
            filename = "phys-dim",
            marktype = "mkiv",
            status   = "okay",
        },
        {
            filename = "strc-mat",
            marktype = "mkiv",
            status   = "okay",
            comment  = "some more functionality will end up here",
        },
        {
            filename = "chem-ini",
            marktype = "mkiv",
            status   = "okay",
        },
        {
            filename = "chem-str",
            marktype = "mkiv",
            status   = "okay",
        },
        {
            filename = "typo-scr",
            marktype = "mkiv",
            status   = "okay",
        },
     -- {
     --     filename = "core-fnt",
     --     marktype = "mkiv",
     --     status   = "todo",
     -- },
        {
            filename = "node-rul",
            marktype = "mkiv",
            status   = "okay",
            comment  = "maybe some cleanup is needed",
        },
        {
            filename = "font-sol",
            marktype = "mkiv",
            status   = "okay",
            comment  = "needs testing",
        },
        {
            filename = "strc-not",
            marktype = "mkiv",
            status   = "todo",
        },
        {
            filename = "strc-lnt",
            marktype = "mkiv",
            status   = "todo",
        },
     -- {
     --     filename = "core-mis",
     --     marktype = "mkiv",
     --     status   = "todo",
     -- },
        {
            filename = "pack-com",
            marktype = "mkiv",
            status   = "okay",
        },
        {
            filename = "typo-del",
            marktype = "mkiv",
            status   = "okay",
        },
        {
            filename = "grph-trf",
            marktype = "mkiv",
            status   = "okay",
        },
        {
            filename = "grph-inc",
            marktype = "mkiv",
            status   = "okay",
        },
        {
            filename = "grph-fig",
            marktype = "mkiv",
            status   = "okay",
        },
        {
            filename = "grph-raw",
            marktype = "mkiv",
            status   = "okay",
        },
        {
            filename = "pack-box",
            marktype = "mkiv",
            status   = "okay",
        },
        {
            filename = "pack-bar",
            marktype = "mkiv",
            status   = "okay",
        },
        {
            filename = "page-app",
            marktype = "mkiv",
            status   = "okay",
        },
        {
            filename = "meta-fig",
            marktype = "mkiv",
            status   = "okay",
        },
        {
            filename = "lang-spa",
            marktype = "mkiv",
            status   = "okay",
            comment  = "more or less  obsolete"
        },
        {
            filename = "bibl-bib",
            marktype = "mkiv",
            status   = "delayed",
        },
        {
            filename = "bibl-tra",
            marktype = "mkiv",
            status   = "delayed",
        },
        {
            filename = "meta-xml",
            marktype = "mkiv",
            status   = "okay",
            comment  = "not needed"
        },
        {
            filename = "cont-log",
            marktype = "mkiv",
            status   = "okay",
        },
        {
            filename = "task-ini",
            marktype = "mkiv",
            status   = "okay",
        },
        {
            filename = "cldf-ver",
            marktype = "mkiv",
            status   = "okay",
        },
        {
            filename = "cldf-com",
            marktype = "mkiv",
            status   = "okay",
        },
        {
            filename = "core-ctx",
            marktype = "mkiv",
            status   = "okay",
        },
        {
            filename = "core-def",
            marktype = "mkiv",
            status   = "okay",
            comment  = "will always be messy",
        },
        {
            filename = "back-pdf",
            marktype = "mkiv",
            status   = "okay",
            comment  = "object related code might move or change",
        },
        {
            filename = "mlib-pdf",
            marktype = "mkiv",
            status   = "okay",
        },
        {
            filename = "mlib-pps",
            marktype = "mkiv",
            status   = "okay",
        },
        {
            filename = "meta-pdf",
            marktype = "mkiv",
            status   = "okay",
        },
        {
            filename = "grph-epd",
            marktype = "mkiv",
            status   = "okay",
            comment  = "might need more work",
        },
        {
            filename = "back-exp",
            marktype = "mkiv",
            status   = "okay",
            comment  = "some parameters might move from export to backend"
        },
    },
    extra = {
        {
            filename = "tabl-xnt",
            marktype = "mkvi",
            status   = "okay",
        },
    }
}

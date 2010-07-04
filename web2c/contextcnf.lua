-- filename : texmfcnf.lua
-- comment  : companion to luatex/mkiv
-- authors  : Hans Hagen & Taco Hoekwater
-- copyright: not relevant
-- license  : not relevant

-- This file is read bij luatools, mtxrun and context mkiv. This is still
-- somewhat experimental and eventually we will support booleans instead
-- of the 't' strings. The content is similar to that of texmf.cnf. Both
-- namespaces strings
--
--     TEXINPUT.context = "..."
--
-- and subtables (
--
--     context = { TEXINPUT = ".." }
--
-- are supported with the later a being the way to go. You can test settings
-- with:
--
--     luatools --expand-var TEXMFBOGUS
--
-- which should return
--
--     It works!
--
-- We first read the lua configuration file(s) and then do a first variable
-- expansion pass. Next we read the regular cnf files. These are cached
-- in the mkiv cache for faster loading. The lua configuration files are
-- not cached.

return {
--  LUACSTRIP  = 'f',         -- don't strip luc files (only use this for debugging, otherwise slower loading and bigger cache)
--  CACHEINTDS = 't',         -- keep filedatabase and configuration in tds tree
--  PURGECACHE = 't',         -- this saves disk space
    TEXMFCACHE = 'c:/temp',   -- installers can change this
--  TEXMFBOGUS = 'It works!', -- a test string
}

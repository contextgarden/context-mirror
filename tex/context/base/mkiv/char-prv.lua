if not modules then modules = { } end modules ['char-prv'] = {
    version   = 1.001,
    comment   = "companion to char-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files",
    dataonly  = true,
}

characters = characters or { }

-- 0xFE302 -- 0xFE320 for accents (gone with new lm/gyre)
-- 0xFE321 -- 0xFE340 for missing characters

-- [0xFE302] = {
--     category    = "mn",
--     description = "WIDE MATHEMATICAL HAT",
--     direction   = "nsm",
--     linebreak   = "cm",
--     mathclass   = "topaccent",
--     mathname    = "widehat",
--     mathstretch = "h",
--     unicodeslot = 0xFE302,
--     nextinsize  = { 0x00302, 0x0005E },
-- },
-- [0xFE303] = {
--     category    = "mn",
--     cjkwd       = "a",
--     description = "WIDE MATHEMATICAL TILDE",
--     direction   = "nsm",
--     linebreak   = "cm",
--     mathclass   = "topaccent",
--     mathname    = "widetilde",
--     mathstretch = "h",
--     unicodeslot = 0xFE303,
--     nextinsize  = { 0x00303, 0x0007E },
-- },
-- [0xFE304] = {
--     category    = "sm",
--     description = "TOP AND BOTTOM PARENTHESES",
--     direction   = "on",
--     linebreak   = "al",
--     mathclass   = "doubleaccent",
--     mathname    = "doubleparent",
--     unicodeslot = 0xFE304,
--     accents     = { 0x023DC, 0x023DD },
-- },
-- [0xFE305] = {
--     category    = "sm",
--     description = "TOP AND BOTTOM BRACES",
--     direction   = "on",
--     linebreak   = "al",
--     mathclass   = "doubleaccent",
--     mathname    = "doublebrace",
--     unicodeslot = 0xFE305,
--     accents     = { 0x023DE, 0x023DF },
-- },
--  [0xFE941]={
--      category       = "sm",
--      description    = "EXTREMELY IDENTICAL TO",
--      mathclass      = "relation",
--      mathextensible = "h",
--      mathname       = "eqequiv",
--      mathpair       = { 0x2261, 0x3D },
--      unicodeslot    = 0xFE941,
--  },

characters.private={
 [0xFE302]={
  description="EXTENSIBLE OF 0x0302",
  mathclass="topaccent",
  mathstretch="h",
  unicodeslot=0xFE302,
 },
 [0xFE303]={
  description="EXTENSIBLE OF 0x0303",
  mathclass="topaccent",
  mathstretch="h",
  unicodeslot=0xFE303,
 },
 [0xFE321]={
  category="sm",
  description="MATHEMATICAL SHORT BAR",
  mathclass="relation",
  mathname="mapstochar",
  unicodeslot=0xFE321,
 },
 [0xFE322]={
  category="sm",
  description="MATHEMATICAL LEFT HOOK",
  mathclass="relation",
  mathname="lhook",
  unicodeslot=0xFE322,
 },
 [0xFE323]={
  category="sm",
  description="MATHEMATICAL RIGHT HOOK",
  mathclass="relation",
  mathname="rhook",
  unicodeslot=0xFE323,
 },
 [0xFE324]={
  category="sm",
  description="MATHEMATICAL SHORT BAR MIRRORED",
  mathclass="relation",
  mathname="mapsfromchar",
  unicodeslot=0xFE324,
 },
 [0xFE350]={
  category="sm",
  description="MATHEMATICAL DOUBLE ARROW LEFT END",
  mathclass="relation",
  mathname="ctxdoublearrowfillleftend",
  unicodeslot=0xFE350,
 },
 [0xFE351]={
  category="sm",
  description="MATHEMATICAL DOUBLE ARROW MIDDLE PART",
  mathclass="relation",
  mathname="ctxdoublearrowfillmiddlepart",
  unicodeslot=0xFE351,
 },
 [0xFE352]={
  category="sm",
  description="MATHEMATICAL DOUBLE ARROW RIGHT END",
  mathclass="relation",
  mathname="ctxdoublearrowfillrightend",
  unicodeslot=0xFE352,
 },
 [0xFE3B4]={
  description="EXTENSIBLE OF 0x03B4",
  mathclass="topaccent",
  mathextensible="r",
  mathstretch="h",
  unicodeslot=0xFE3B4,
 },
 [0xFE3B5]={
  description="EXTENSIBLE OF 0x03B5",
  mathclass="botaccent",
  mathextensible="r",
  mathstretch="h",
  unicodeslot=0xFE3B5,
 },
 [0xFE3DC]={
  description="EXTENSIBLE OF 0x03DC",
  mathclass="topaccent",
  mathextensible="r",
  mathstretch="h",
  unicodeslot=0xFE3DC,
 },
 [0xFE3DD]={
  description="EXTENSIBLE OF 0x03DD",
  mathclass="botaccent",
  mathextensible="r",
  mathstretch="h",
  unicodeslot=0xFE3DD,
 },
 [0xFE3DE]={
  description="EXTENSIBLE OF 0x03DE",
  mathclass="topaccent",
  mathextensible="r",
  mathstretch="h",
  unicodeslot=0xFE3DE,
 },
 [0xFE3DF]={
  description="EXTENSIBLE OF 0x03DF",
  mathclass="botaccent",
  mathextensible="r",
  mathstretch="h",
  unicodeslot=0xFE3DF,
 },
 [0xFE932]={
  description="SMASHED PRIME 0x02032",
  unicodeslot=0xFE932,
 },
 [0xFE933]={
  description="SMASHED PRIME 0x02033",
  unicodeslot=0xFE933,
 },
 [0xFE934]={
  description="SMASHED PRIME 0x02034",
  unicodeslot=0xFE934,
 },
 [0xFE935]={
  description="SMASHED BACKWARD PRIME 0x02035",
  unicodeslot=0xFE935,
 },
 [0xFE936]={
  description="SMASHED BACKWARD PRIME 0x02036",
  unicodeslot=0xFE936,
 },
 [0xFE937]={
  description="SMASHED BACKWARD PRIME 0x02037",
  unicodeslot=0xFE937,
 },
 [0xFE940]={
  category="mn",
  description="SMALL ANNUITY SYMBOL",
  mathclass="topaccent",
  mathname="smallactuarial",
  unicodeslot=0xFE940,
 },
 [0xFE957]={
  description="SMASHED PRIME 0x02057",
  unicodeslot=0xFE957,
 },
}

-- print(table.serialize(characters.private,"characters.private", { hexify = true, noquotes = true }))

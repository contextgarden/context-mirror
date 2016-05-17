if not modules then modules = { } end modules ['luat-ini'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

--[[ldx--
<p>We cannot load anything yet. However what we will do us reserve a few tables.
These can be used for runtime user data or third party modules and will not be
cluttered by macro package code.</p>
--ldx]]--

userdata      = userdata      or { } -- for users (e.g. functions etc)
thirddata     = thirddata     or { } -- only for third party modules
moduledata    = moduledata    or { } -- only for development team
documentdata  = documentdata  or { } -- for users (e.g. raw data)
parametersets = parametersets or { } -- experimental for team

table.setmetatableindex(moduledata,table.autokey)
table.setmetatableindex(thirddata, table.autokey)

if not global then
    global  = _G
end

LUATEXVERSION = status.luatex_version/100 + tonumber(status.luatex_revision)/1000

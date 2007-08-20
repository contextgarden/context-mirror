if not modules then modules = { } end modules ['luat-ini'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.tex",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

--[[ldx--
<p>We cannot load anything yet. However what we will do us reserve a fewtables.
These can be used for runtime user data or third party modules and will not be
cluttered by macro package code.</p>
--ldx]]--

userdata  = userdata  or { }
thirddata = thirddata or { }
document  = document or { }

--[[ldx--
<p>Please create a namespace within these tables before using them!</p>

<typing>
userdata ['my.name'] = { }
thirddata['tricks' ] = { }
</typing>
--ldx]]--

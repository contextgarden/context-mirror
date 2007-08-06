if not modules then modules = { } end modules ['core-uti'] = {
    version   = 1.001,
    comment   = "companion to core-uti.tex",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

--[[ldx--
<p>A utility file has always been part of <l n='context'/> and with
the move to <l n='luatex'/> we also moved a lot of multi-pass info
to a <l n='lua'/> table. Instead of loading a <l n='tex'/> based
utility file under different setups, we now load a table once. This
saves much runtime but at the cost of more memory usage.</p>
--ldx]]--

if not jobs          then jobs          = { } end
if not job           then jobs['main']  = { } end job = jobs['main']
if not job.variables then job.variables = { } end

--[[ldx--
<p>Variables are saved using in the previously defined table and passed
onto <l n='tex'/> using the following method. Of course one can also
directly access the variable using a <l n='lua'/> call.</p>
--ldx]]--

function job.initializevariable(cs,value)
    tex.sprint("\\xdef\\"..cs.."{"..value.."}")
end

if not modules then modules = { } end modules ['luat-cbk'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.tex",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

--[[ldx--
<p>Callbacks are the real asset of <l n='luatex'/>. They permit you to hook
your own code into the <l n='tex'/> engine. Here we implement a few handy
auxiliary functions.</p>
--ldx]]--

callbacks       = { }
callbacks.stack = { }

--[[ldx--
<p>When you (temporarily) want to install a callback function, and after a
while wants to revert to the original one, you can use the following two
functions.</p>
--ldx]]--

function callbacks.push(name, func)
    if not callbacks.stack[name] then
        callbacks.stack[name] = { }
    end
    table.insert(callbacks.stack[name],callback.find(name))
    callback.register(name, func)
end

function callbacks.pop(name)
--  this fails: callback.register(name, table.remove(callbacks.stack[name]))
    local func = table.remove(callbacks.stack[name])
    callback.register(name, func)
end

--[[ldx--
<p>The simple case is to remove the callback:</p>

<code>
callbacks.push('linebreak_filter')
... some actions ...
callbacks.pop('linebreak_filter')
</code>

<p>Often, in such case, another callback or a macro call will pop
the original.</p>

<p>In practice one will install a new handler, like in:</p>

<code>
callbacks.push('linebreak_filter', function(...)
    return something_done(...)
end)
</code>

<p>Even more interesting is:</p>

<code>
callbacks.push('linebreak_filter', function(...)
    callbacks.pop('linebreak_filter')
    return something_done(...)
end)
</code>

<p>This does a one-shot.</p>
--ldx]]--


--[[ldx--
<p>Callbacks may result in <l n='lua'/> doing some hard work
which takes time and above all resourses. Sometimes it makes
sense to disable or tune the garbage collector in order to
keep the use of resources acceptable.</p>

<p>At some point in the development we did some tests with counting
nodes (in thsi case 121049).</p>

<table>
<tr><td>setstepmul</td><td>seconds</td><td>megabytes</td</tr>
<tr><td>200</td><td>24.0</td><td>80.5</td</tr>
<tr><td>175</td><td>21.0</td><td>78.2</td</tr>
<tr><td>150</td><td>22.0</td><td>74.6</td</tr>
<tr><td>160</td><td>22.0</td><td>74.6</td</tr>
<tr><td>165</td><td>21.0</td><td>77.6</td</tr>
<tr><td>125</td><td>21.5</td><td>89.2</td</tr>
<tr><td>100</td><td>21.5</td><td>88.4</td</tr>
</table>

<p>The following code is kind of experimental. In the documents
that describe the development of <l n='luatex'/> we report
on speed tests. One observation is thta it sometimes helps to
restart the collector.</p>
--ldx]]--

garbagecollector = { }

do
    local level = 0

    collectgarbage("setstepmul", 165)

    garbagecollector.trace = false
    garbagecollector.tune  = false -- for the moment

    function report(format)
        if garbagecollector.trace then
         -- texio.write_nl(string.format(format,level,status.luastate_bytes))
            texio.write_nl(string.format(format,level,collectgarbage("count")))
        end
    end

    function garbagecollector.update()
        report("%s: memory before update: %s")
        collectgarbage("restart")
    end

    function garbagecollector.push()
        if garbagecollector.tune then
            level = level + 1
            if level == 1 then
                collectgarbage("stop")
            end
            report("%s: memory after push: %s")
        else
            garbagecollector.update()
        end
    end

    function garbagecollector.pop()
        if garbagecollector.tune then
            report("%s: memory before pop: %s")
            if level == 1 then
                collectgarbage("restart")
            end
            level = level - 1
        end
    end

    function garbagecollector.cycle()
        if garbagecollector.tune then
            report("%s: memory before collect: %s")
            collectgarbage("collect")
            report("%s: memory after collect: %s")
        end
    end

end


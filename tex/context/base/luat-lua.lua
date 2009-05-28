if not modules then modules = { } end modules ['luat-lua'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.tex",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

if lua then do

    local delayed = { }

    function lua.delay(f)
        delayed[#delayed+1] = f
    end

    function lua.flush_delayed(...)
        local t = delayed
        delayed = { }
        for i=1, #t do
            t[i](...)
        end
    end

    function lua.flush(...)
        tex.sprint("\\directlua0{lua.flush_delayed(",table.concat({...},','),")}")
    end

end end

--~ See mk.pdf for an explanation of the following code:
--~
--~ function test(n)
--~     lua.delay(function(...)
--~         tex.sprint(string.format("pi: %s %s %s\\par",...))
--~     end)
--~     lua.delay(function(...)
--~         tex.sprint(string.format("more pi: %s %s %s\\par",...))
--~     end)
--~     tex.sprint(string.format("\\setbox0=\\hbox{%s}",math.pi*n))
--~     lua.flush(tex.wd[0],tex.ht[0],tex.dp[0])
--~ end

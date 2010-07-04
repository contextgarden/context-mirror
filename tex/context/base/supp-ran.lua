if not modules then modules = { } end modules ['supp-ran'] = {
    version   = 1.001,
    comment   = "companion to supp-ran.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- We cannot ask for the current seed, so we need some messy hack
-- here.

commands = commands or { }

local random, randomseed, round, seed, last = math.random, math.randomseed, math.round, false, 1
local texwrite = tex.write

function math.setrandomseedi(n,comment)
    if n <= 1 then
        n = n*1073741823 -- maxcount
    end
    n = round(n)
    if false then
        logs.report("system","setting random seed to %s (%s)",n,comment or "normal")
    end
    randomseed(n)
    last = random(0,1073741823) -- we need an initial value
end

function commands.getrandomcounta(min,max)
    last = random(min,max)
    texwrite(last)
end

function commands.getrandomcountb(min,max)
    last = random(min,max)/65536
    texwrite(last)
end

function commands.setrandomseed(n)
    last = n
    math.setrandomseedi(n)
end

function commands.getrandomseed(n)
    texwrite(last)
end

-- maybe stack

function commands.freezerandomseed(n)
 -- print("<<<<",seed,last)
    if seed == false or seed == nil then
        seed = last
        math.setrandomseedi(seed,"freeze",seed)
    end
    if n then
        randomseed(n)
    end
end

function commands.defrostrandomseed()
 -- print(">>>>",seed,last)
    if seed ~= false then
        math.setrandomseedi(seed,"defrost",seed) -- was last (bug)
        seed = false
    end
end

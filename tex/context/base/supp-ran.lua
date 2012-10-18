if not modules then modules = { } end modules ['supp-ran'] = {
    version   = 1.001,
    comment   = "companion to supp-ran.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- We cannot ask for the current seed, so we need some messy hack here.

local report_system = logs.reporter("system","randomizer")

local math = math
local context, commands = context, commands

local random, randomseed, round, seed, last = math.random, math.randomseed, math.round, false, 1

local maxcount = 2^30-1 -- 1073741823

local function setrandomseedi(n,comment)
    if not n then
 --     n = 0.5 -- hack
    end
    if n <= 1 then
        n = n * maxcount
    end
    n = round(n)
    if false then
        report_system("setting seed to %s (%s)",n,comment or "normal")
    end
    randomseed(n)
    last = random(0,maxcount) -- we need an initial value
end

math.setrandomseedi = setrandomseedi

function commands.getrandomcounta(min,max)
    last = random(min,max)
    context(last)
end

function commands.getrandomcountb(min,max)
    last = random(min,max)/65536
    context(last)
end

function commands.setrandomseed(n)
    last = n
    setrandomseedi(n)
end

function commands.getrandomseed(n)
    context(last)
end

-- maybe stack

function commands.freezerandomseed(n)
    if seed == false or seed == nil then
        seed = last
        setrandomseedi(seed,"freeze",seed)
    end
    if n then
        randomseed(n)
    end
end

function commands.defrostrandomseed()
    if seed ~= false then
        setrandomseedi(seed,"defrost",seed) -- was last (bug)
        seed = false
    end
end

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

local texwrite, random, seed, last = tex.write, math.random, false, 1

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
    math.randomseed(n)
end

function commands.getrandomseed(n)
    texwrite(last)
end

function commands.freezerandomseed()
    if seed == false then
        seed = last
    end
end

function commands.defrostrandomseed()
    if seed ~= false then
        math.randomseed(last)
        seed = false
    end
end

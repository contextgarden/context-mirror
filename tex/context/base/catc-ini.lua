if not modules then modules = { } end modules ['catc-ini'] = {
    version   = 1.001,
    comment   = "companion to catc-ini.tex",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

catcodes         = catcodes         or { }
catcodes.numbers = catcodes.numbers or { }
catcodes.names   = catcodes.names   or { }

storage.register("catcodes/numbers", catcodes.numbers, "catcodes.numbers")
storage.register("catcodes/names",   catcodes.names,   "catcodes.names")

-- this only happens at initime

function catcodes.register(name,number)
    catcodes.numbers[name] = number
    catcodes.names[number] = name
    tex[name] = number
end

-- this only happens at runtime

for k, v in next, catcodes.numbers do
    tex[k] = v
end

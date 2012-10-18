if not modules then modules = { } end modules ['math-vfu'] = {
    version   = 1.001,
    comment   = "companion to math-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- All these math vectors .. thanks to Aditya and Mojca they become
-- better and better. If you have problems with math fonts or miss
-- characters report it to the ConTeXt mailing list. Also thanks to
-- Boguslaw for finding a couple of errors.

-- 20D6 -> 2190
-- 20D7 -> 2192

local type, next = type, next
local max = math.max
local format = string.format

local fonts, nodes, mathematics = fonts, nodes, mathematics

local trace_virtual = false  trackers.register("math.virtual", function(v) trace_virtual = v end)
local trace_timings = false  trackers.register("math.timings", function(v) trace_timings = v end)

local add_optional  = false  directives.register("math.virtual.optional",function(v) add_optional = v end)

local report_virtual    = logs.reporter("fonts","virtual math")

local allocate          = utilities.storage.allocate
local setmetatableindex = table.setmetatableindex

local mathencodings     = allocate()
fonts.encodings.math    = mathencodings -- better is then: fonts.encodings.vectors
local vfmath            = allocate()
fonts.handlers.vf.math  = vfmath

local shared            = { }

--~ local push, pop, back = { "push" }, { "pop" }, { "slot", 1, 0x2215 }

--~ local function negate(main,characters,id,size,unicode,basecode)
--~     if not characters[unicode] then
--~         local basechar = characters[basecode]
--~         if basechar then
--~             local ht, wd = basechar.height, basechar.width
--~             characters[unicode] = {
--~                 width    = wd,
--~                 height   = ht,
--~                 depth    = basechar.depth,
--~                 italic   = basechar.italic,
--~                 kerns    = basechar.kerns,
--~                 commands = {
--~                     { "slot", 1, basecode },
--~                     push,
--~                     { "down",    ht/5},
--~                     { "right", - wd/2},
--~                     back,
--~                     push,
--~                 }
--~             }
--~         end
--~     end
--~ end

--~ \Umathchardef\braceld="0 "1 "FF07A
--~ \Umathchardef\bracerd="0 "1 "FF07B
--~ \Umathchardef\bracelu="0 "1 "FF07C
--~ \Umathchardef\braceru="0 "1 "FF07D

local function brace(main,characters,id,size,unicode,first,rule,left,right,rule,last)
    if not characters[unicode] then
        characters[unicode] = {
            horiz_variants = {
                { extender = 0, glyph = first },
                { extender = 1, glyph = rule  },
                { extender = 0, glyph = left  },
                { extender = 0, glyph = right },
                { extender = 1, glyph = rule  },
                { extender = 0, glyph = last  },
            }
        }
    end
end

local function arrow(main,characters,id,size,unicode,arrow,minus,isleft)
    local chr = characters[unicode]
    if not chr then
        -- skip
    elseif isleft then
        chr.horiz_variants = {
            { extender = 0, glyph = arrow },
            { extender = 1, glyph = minus },
        }
    else
        chr.horiz_variants = {
            { extender = 1, glyph = minus },
            { extender = 0, glyph = arrow },
        }
    end
end

local function parent(main,characters,id,size,unicode,first,rule,last)
    if not characters[unicode] then
        characters[unicode] = {
            horiz_variants = {
                { extender = 0, glyph = first },
                { extender = 1, glyph = rule  },
                { extender = 0, glyph = last  },
            }
        }
    end
end

local push, pop, step = { "push" }, { "pop" }, 0.2 -- 0.1 is nicer but gives larger files

local function make(main,characters,id,size,n,m)
    local old = 0xFF000+n
    local c = characters[old]
    if c then
        local upslot, dnslot, uprule, dnrule = 0xFF100+n, 0xFF200+n, 0xFF300+m, 0xFF400+m
        local xu = main.parameters.x_height + 0.3*size
        local xd = 0.3*size
        local w, h, d = c.width, c.height, c.depth
        local thickness = h - d
        local rulewidth = step*size -- we could use an overlap
        local slot = { "slot", id, old }
        local rule = { "rule", thickness, rulewidth  }
        local up = { "down", -xu }
        local dn = { "down", xd }
        local ht, dp = xu + 3*thickness, 0
        if not characters[uprule] then
            characters[uprule] = { width = rulewidth, height = ht, depth = dp, commands = { push, up, rule, pop } }
        end
        characters[upslot] = { width = w, height = ht, depth = dp, commands = { push, up, slot, pop } }
        local ht, dp = 0, xd + 3*thickness
        if not characters[dnrule] then
            characters[dnrule] = { width = rulewidth, height = ht, depth = dp, commands = { push, dn, rule, pop } }
        end
        characters[dnslot] = { width = w, height = ht, depth = dp, commands = { push, dn, slot, pop } }
    end
end

local function minus(main,characters,id,size,unicode) -- push/pop needed?
    local minus = characters[0x002D]
    if minus then
        local mu = size/18
        local width = minus.width - 5*mu
        characters[unicode] = {
            width = width, height = minus.height, depth = minus.depth,
            commands = { push, { "right", -3*mu }, { "slot", id, 0x002D }, pop }
        }
    end
end

-- fails: pdf:page: pdf:direct: ... some funny displacement

-- this does not yet work ... { "scale", 2, 0, 0, 3 } .. commented code
--
-- this does not work ... no interpretation going on here
--
-- local nodeinjections = backends.nodeinjections
-- { "node", nodeinjections.save() },
-- { "node", nodeinjections.transform(.7,0,0,.7) },
-- commands[#commands+1] = { "node", nodeinjections.restore() }

local done = { }

local function raise(main,characters,id,size,unicode,private,n) -- this is a real fake mess
    local raised = characters[private]
    if raised then
        if not done[unicode] then
            report_virtual("temporary too large U+%05X due to issues in luatex backend",unicode)
            done[unicode] = true
        end
        local up = 0.85 * main.parameters.x_height
        local slot = { "slot", id, private }
        local commands = {
            push,
            { "down", - up },
         -- { "scale", .7, 0, 0, .7 },
            slot,
        }
        for i=2,n do
            commands[#commands+1] = slot
        end
        commands[#commands+1] = pop
        characters[unicode] = {
            width    = .7 * n * raised.width,
            height   = .7 * (raised.height + up),
            depth    = .7 * (raised.depth  - up),
            commands = commands,
        }
    end
end

local function dots(main,characters,id,size,unicode)
    local c = characters[0x002E]
    if c then
        local w, h, d = c.width, c.height, c.depth
        local mu = size/18
        local right3mu  = { "right", 3*mu }
        local right1mu  = { "right", 1*mu }
        local up1size   = { "down", -.1*size }
        local up4size   = { "down", -.4*size }
        local up7size   = { "down", -.7*size }
        local right2muw = { "right", 2*mu + w }
        local slot = { "slot", id, 0x002E }
        if unicode == 0x22EF then
            local c = characters[0x022C5]
            if c then
                local w, h, d = c.width, c.height, c.depth
                local slot = { "slot", id, 0x022C5 }
                characters[unicode] = {
                    width = 3*w + 2*3*mu, height = h, depth = d,
                    commands = { push, slot, right3mu, slot, right3mu, slot, pop }
                }
            end
        elseif unicode == 0x22EE then
            -- weird height !
            characters[unicode] = {
                width = w, height = h+(1.4)*size, depth = 0,
                commands = { push, push, slot, pop, up4size, push, slot, pop, up4size, slot, pop }
            }
        elseif unicode == 0x22F1 then
            characters[unicode] = {
                width = 3*w + 6*size/18, height = 1.5*size, depth = 0,
                commands = {
                    push,
                        right1mu,
                        push, up7size, slot, pop,
                        right2muw,
                        push, up4size, slot, pop,
                        right2muw,
                        push, up1size, slot, pop,
                        right1mu,
                    pop
                }
            }
        elseif unicode == 0x22F0 then
            characters[unicode] = {
                width = 3*w + 6*size/18, height = 1.5*size, depth = 0,
                commands = {
                    push,
                        right1mu,
                        push, up1size, slot, pop,
                        right2muw,
                        push, up4size, slot, pop,
                        right2muw,
                        push, up7size, slot, pop,
                        right1mu,
                    pop
                }
            }
        else
            characters[unicode] = {
                width = 3*w + 2*3*mu, height = h, depth = d,
                commands = { push, slot, right3mu, slot, right3mu, slot, pop }
            }
        end
    end
end

local function vertbar(main,characters,id,size,parent,scale,unicode)
    local cp = characters[parent]
    if cp then
        local sc = scale * size
        local pc = { "slot", id, parent }
        characters[unicode] = {
            width    = cp.width,
            height   = cp.height + sc,
            depth    = cp.depth + sc,
            commands = {
                push, { "down", -sc }, pc, pop,
                push, { "down",  sc }, pc, pop,
                                       pc,
            },
            next = cp.next -- can be extensible
        }
        cp.next = unicode
    end
end

local function jointwo(main,characters,id,size,unicode,u1,d12,u2)
    local c1, c2 = characters[u1], characters[u2]
    if c1 and c2 then
        local w1, w2 = c1.width, c2.width
        local mu = size/18
        characters[unicode] = {
            width    = w1 + w2 - d12*mu,
            height   = max(c1.height or 0, c2.height or 0),
            depth    = max(c1.depth or 0, c2.depth or 0),
            commands = {
                { "slot", id, u1 },
                { "right", -d12*mu } ,
                { "slot", id, u2 },
            }
        }
    end
end

local function jointhree(main,characters,id,size,unicode,u1,d12,u2,d23,u3)
    local c1, c2, c3 = characters[u1], characters[u2], characters[u3]
    if c1 and c2 and c3 then
        local w1, w2, w3 = c1.width, c2.width, c3.width
        local mu = size/18
        characters[unicode] = {
            width    = w1 + w2 + w3 - d12*mu - d23*mu,
            height   = max(c1.height or 0, c2.height or 0, c3.height or 0),
            depth    = max(c1.depth or 0, c2.depth or 0, c3.depth or 0),
            commands = {
                { "slot", id, u1 },
                { "right", - d12*mu } ,
                { "slot", id, u2 },
                { "right", - d23*mu },
                { "slot", id, u3 },
            }
        }
    end
end

local function stack(main,characters,id,size,unicode,u1,d12,u2)
    local c1, c2 = characters[u1], characters[u2]
    if c1 and c2 then
        local w1, w2 = c1.width, c2.width
        local h1, h2 = c1.height, c2.height
        local d1, d2 = c1.depth, c2.depth
        local mu = size/18
        characters[unicode] = {
            width    = w1,
            height   = h1 + h2 + d12,
            depth    = d1,
            commands = {
                { "slot", id, u1 },
                { "right", - w1/2 - w2/2 } ,
                { "down", -h1 + d2 -d12*mu } ,
                { "slot", id, u2 },
            }
        }
    end
end

function vfmath.addmissing(main,id,size)
    local characters = main.characters
    local shared = main.shared
    local variables = main.goodies.mathematics and main.goodies.mathematics.variables or { }
    local joinrelfactor = variables.joinrelfactor or 3
    for i=0x7A,0x7D do
        make(main,characters,id,size,i,1)
    end
    brace    (main,characters,id,size,0x23DE,0xFF17A,0xFF301,0xFF17D,0xFF17C,0xFF301,0xFF17B)
    brace    (main,characters,id,size,0x23DF,0xFF27C,0xFF401,0xFF27B,0xFF27A,0xFF401,0xFF27D)
    parent   (main,characters,id,size,0x23DC,0xFF17A,0xFF301,0xFF17B)
    parent   (main,characters,id,size,0x23DD,0xFF27C,0xFF401,0xFF27D)
 -- negate   (main,characters,id,size,0x2260,0x003D)
    dots     (main,characters,id,size,0x2026) -- ldots
    dots     (main,characters,id,size,0x22EE) -- vdots
    dots     (main,characters,id,size,0x22EF) -- cdots
    dots     (main,characters,id,size,0x22F1) -- ddots
    dots     (main,characters,id,size,0x22F0) -- udots
    minus    (main,characters,id,size,0xFF501)
    arrow    (main,characters,id,size,0x2190,0x2190,0xFF501,true)  -- left
    arrow    (main,characters,id,size,0x2192,0x2192,0xFF501,false) -- right
    vertbar  (main,characters,id,size,0x0007C,0.10,0xFF601) -- big  : 0.85 bodyfontsize
    vertbar  (main,characters,id,size,0xFF601,0.30,0xFF602) -- Big  : 1.15 bodyfontsize
    vertbar  (main,characters,id,size,0xFF602,0.30,0xFF603) -- bigg : 1.45 bodyfontsize
    vertbar  (main,characters,id,size,0xFF603,0.30,0xFF604) -- Bigg : 1.75 bodyfontsize
    vertbar  (main,characters,id,size,0x02016,0.10,0xFF605)
    vertbar  (main,characters,id,size,0xFF605,0.30,0xFF606)
    vertbar  (main,characters,id,size,0xFF606,0.30,0xFF607)
    vertbar  (main,characters,id,size,0xFF607,0.30,0xFF608)
    jointwo  (main,characters,id,size,0x21A6,0xFE321,0,0x02192)                       -- \mapstochar\rightarrow
    jointwo  (main,characters,id,size,0x21A9,0x02190,joinrelfactor,0xFE323)           -- \leftarrow\joinrel\rhook
    jointwo  (main,characters,id,size,0x21AA,0xFE322,joinrelfactor,0x02192)           -- \lhook\joinrel\rightarrow
    stack    (main,characters,id,size,0x2259,0x0003D,3,0x02227)                       -- \buildrel\wedge\over=
    jointwo  (main,characters,id,size,0x22C8,0x022B3,joinrelfactor,0x022B2)           -- \mathrel\triangleright\joinrel\mathrel\triangleleft (4 looks better than 3)
    jointwo  (main,characters,id,size,0x2260,0x00338,0,0x0003D)                       -- \not\equal
    jointwo  (main,characters,id,size,0x2284,0x00338,0,0x02282)                       -- \not\subset
    jointwo  (main,characters,id,size,0x2285,0x00338,0,0x02283)                       -- \not\supset
    jointwo  (main,characters,id,size,0x22A7,0x0007C,joinrelfactor,0x0003D)           -- \mathrel|\joinrel=
    jointwo  (main,characters,id,size,0x27F5,0x02190,joinrelfactor,0x0002D)           -- \leftarrow\joinrel\relbar
    jointwo  (main,characters,id,size,0x27F6,0x0002D,joinrelfactor,0x02192)           -- \relbar\joinrel\rightarrow
    jointwo  (main,characters,id,size,0x27F7,0x02190,joinrelfactor,0x02192)           -- \leftarrow\joinrel\rightarrow
    jointwo  (main,characters,id,size,0x27F8,0x021D0,joinrelfactor,0x0003D)           -- \Leftarrow\joinrel\Relbar
    jointwo  (main,characters,id,size,0x27F9,0x0003D,joinrelfactor,0x021D2)           -- \Relbar\joinrel\Rightarrow
    jointwo  (main,characters,id,size,0x27FA,0x021D0,joinrelfactor,0x021D2)           -- \Leftarrow\joinrel\Rightarrow
    jointhree(main,characters,id,size,0x27FB,0x02190,joinrelfactor,0x0002D,0,0xFE324) -- \leftarrow\joinrel\relbar\mapsfromchar
    jointhree(main,characters,id,size,0x27FC,0xFE321,0,0x0002D,joinrelfactor,0x02192) -- \mapstochar\relbar\joinrel\rightarrow
    jointwo  (main,characters,id,size,0x2254,0x03A,0,0x03D)                           -- := (≔)

 -- raise    (main,characters,id,size,0x02032,0xFE325,1) -- prime
 -- raise    (main,characters,id,size,0x02033,0xFE325,2) -- double prime
 -- raise    (main,characters,id,size,0x02034,0xFE325,3) -- triple prime

    -- there are more (needs discussion first):

 -- characters[0x20D6] = characters[0x2190]
 -- characters[0x20D7] = characters[0x2192]

    characters[0x02B9] = characters[0x2032] -- we're nice

end

local unique = 0 -- testcase: \startTEXpage \math{!\text{-}\text{-}\text{-}} \stopTEXpage

local reported = { }
local reverse  = { } -- index -> unicode

setmetatableindex(reverse, function(t,name)
    if trace_virtual then
        report_virtual("initializing math vector '%s'",name)
    end
    local m, r = mathencodings[name], { }
    for u, i in next, m do
        r[i] = u
    end
    reverse[name] = r
    return r
end)

function vfmath.define(specification,set,goodies)
    local name = specification.name -- symbolic name
    local size = specification.size -- given size
    local loaded, fontlist, names, main = { }, { }, { }, nil
    local start = (trace_virtual or trace_timings) and os.clock()
    local okset, n = { }, 0
    for s=1,#set do
        local ss = set[s]
        local ssname = ss.name
        if add_optional and ss.optional then
            if trace_virtual then
                report_virtual("loading font %s subfont %s with name %s at %s is skipped",name,s,ssname,size)
            end
        else
            if ss.features then
                ssname = ssname .. "*" .. ss.features
            end
            if ss.main then
                main = s
            end
            local alreadyloaded = names[ssname] -- for px we load one twice (saves .04 sec)
            local f, id
            if alreadyloaded then
                f, id = alreadyloaded.f, alreadyloaded.id
                if trace_virtual then
                    report_virtual("loading font %s subfont %s with name %s is reused",name,s,ssname)
                end
            else
                f, id = fonts.constructors.readanddefine(ssname,size)
                names[ssname] = { f = f, id = id }
            end
            if not f or id == 0 then
                report_virtual("loading font %s subfont %s with name %s at %s is skipped, not found",name,s,ssname,size)
            else
                n = n + 1
                okset[n] = ss
                loaded[n] = f
                fontlist[n] = { id = id, size = size }
                if not shared[s] then
                    shared[n] = { }
                end
                if trace_virtual then
                    report_virtual("loading font %s subfont %s with name %s at %s as id %s using encoding %s",name,s,ssname,size,id,ss.vector or "none")
                end
                if not ss.checked then
                    ss.checked = true
                    local vector = mathencodings[ss.vector]
                    if vector then
                        -- we resolve named glyphs only once as we can assume that vectors
                        -- are unique to a font set (when we read an afm we get those names
                        -- mapped onto the private area)
                        for unicode, index in next, vector do
                            if not tonumber(index) then
                                local u = f.unicodes
                                u = u and u[index]
                                if u then
                                    if trace_virtual then
                                        report_virtual("resolving name %s to %s",index,u)
                                    end
                                else
                                    report_virtual("unable to resolve name %s",index)
                                end
                                vector[unicode] = u
                            end
                        end
                    end
                end
            end
        end
    end
    -- beware, loaded[1] is already passed to tex (we need to make a simple copy then .. todo)
    local parent         = loaded[1] -- a text font
    local characters     = { }
    local parameters     = { }
    local mathparameters = { }
    local descriptions   = { }
    local metadata       = { }
    local properties     = { }
    local goodies        = { }
    local main           = {
        metadata         = metadata,
        properties       = properties,
        characters       = characters,
        descriptions     = descriptions,
        parameters       = parameters,
        mathparameters   = mathparameters,
        fonts            = fontlist,
        goodies          = goodies,
    }
    --
    --
    for key, value in next, parent do
        if type(value) ~= "table" then
            main[key] = value
        end
    end
    --
    if parent.characters then
        for unicode, character in next, parent.characters do
            characters[unicode] = character
        end
    else
        report_virtual("font %s has no characters",name)
    end
    --
    if parent.parameters then
        for key, value in next, parent.parameters do
            parameters[key] = value
        end
    else
        report_virtual("font %s has no parameters",name)
    end
    --
    local description = { name = "<unset>" }
    setmetatableindex(descriptions,function() return description end)
    --
    if parent.properties then
        setmetatableindex(properties,parent.properties)
    end
    --
    if parent.goodies then
        setmetatableindex(goodies,parent.goodies)
    end
    --
    properties.virtualized = true
    properties.hasitalics  = true
    properties.hasmath     = true
    --
    local fullname = properties.fullname -- parent via mt
    if fullname then
        unique = unique + 1
        properties.fullname = fullname .. "-" .. unique
    end
    --
    -- we need to set some values in main as well (still?)
    --
    main.fullname      = properties.fullname
    main.type          = "virtual"
    main.nomath        = false
    --
    parameters.x_height = parameters.x_height or 0
    --
    local already_reported = false
    for s=1,n do
        local ss, fs = okset[s], loaded[s]
        if not fs then
            -- skip, error
        elseif add_optional and ss.optional then
            -- skip, redundant
        else
            local newparameters = fs.parameters
            if not newparameters then
                report_virtual("font %s, no parameters set",name)
            elseif ss.extension then
                mathparameters.math_x_height          = newparameters.x_height or 0        -- math_x_height          : height of x
                mathparameters.default_rule_thickness = newparameters[ 8]      or 0        -- default_rule_thickness : thickness of \over bars
                mathparameters.big_op_spacing1        = newparameters[ 9]      or 0        -- big_op_spacing1        : minimum clearance above a displayed op
                mathparameters.big_op_spacing2        = newparameters[10]      or 0        -- big_op_spacing2        : minimum clearance below a displayed op
                mathparameters.big_op_spacing3        = newparameters[11]      or 0        -- big_op_spacing3        : minimum baselineskip above displayed op
                mathparameters.big_op_spacing4        = newparameters[12]      or 0        -- big_op_spacing4        : minimum baselineskip below displayed op
                mathparameters.big_op_spacing5        = newparameters[13]      or 0        -- big_op_spacing5        : padding above and below displayed limits
            --  report_virtual("loading and virtualizing font %s at size %s, setting ex parameters",name,size)
            elseif ss.parameters then
                mathparameters.x_height      = newparameters.x_height or mathparameters.x_height
                mathparameters.x_height      = mathparameters.x_height or fp.x_height or 0 -- x_height               : height of x
                mathparameters.num1          = newparameters[ 8] or 0                      -- num1                   : numerator shift-up in display styles
                mathparameters.num2          = newparameters[ 9] or 0                      -- num2                   : numerator shift-up in non-display, non-\atop
                mathparameters.num3          = newparameters[10] or 0                      -- num3                   : numerator shift-up in non-display \atop
                mathparameters.denom1        = newparameters[11] or 0                      -- denom1                 : denominator shift-down in display styles
                mathparameters.denom2        = newparameters[12] or 0                      -- denom2                 : denominator shift-down in non-display styles
                mathparameters.sup1          = newparameters[13] or 0                      -- sup1                   : superscript shift-up in uncramped display style
                mathparameters.sup2          = newparameters[14] or 0                      -- sup2                   : superscript shift-up in uncramped non-display
                mathparameters.sup3          = newparameters[15] or 0                      -- sup3                   : superscript shift-up in cramped styles
                mathparameters.sub1          = newparameters[16] or 0                      -- sub1                   : subscript shift-down if superscript is absent
                mathparameters.sub2          = newparameters[17] or 0                      -- sub2                   : subscript shift-down if superscript is present
                mathparameters.sup_drop      = newparameters[18] or 0                      -- sup_drop               : superscript baseline below top of large box
                mathparameters.sub_drop      = newparameters[19] or 0                      -- sub_drop               : subscript baseline below bottom of large box
                mathparameters.delim1        = newparameters[20] or 0                      -- delim1                 : size of \atopwithdelims delimiters in display styles
                mathparameters.delim2        = newparameters[21] or 0                      -- delim2                 : size of \atopwithdelims delimiters in non-displays
                mathparameters.axis_height   = newparameters[22] or 0                      -- axis_height            : height of fraction lines above the baseline
            --  report_virtual("loading and virtualizing font %s at size %s, setting sy parameters",name,size)
            end
            local vectorname = ss.vector
            if vectorname then
                local offset = 0xFF000
                local vector = mathencodings[vectorname]
                local rotcev = reverse[vectorname]
                local isextension = ss.extension
                if vector and rotcev then
                    local fc, fd, si = fs.characters, fs.descriptions, shared[s]
                    local skewchar = ss.skewchar
                    for unicode, index in next, vector do
                        local fci = fc[index]
                        if not fci then
                            local fontname = fs.properties.name or "unknown"
                            local rf = reported[fontname]
                            if not rf then rf = { } reported[fontname] = rf end
                            local rv = rf[vectorname]
                            if not rv then rv = { } rf[vectorname] = rv end
                            local ru = rv[unicode]
                            if not ru then
                                if trace_virtual then
                                    report_virtual( "unicode point U+%05X has no index %04X in vector %s for font %s",unicode,index,vectorname,fontname)
                                elseif not already_reported then
                                    report_virtual( "the mapping is incomplete for '%s' at %s",name,number.topoints(size))
                                    already_reported = true
                                end
                                rv[unicode] = true
                            end
                        else
                            local ref = si[index]
                            if not ref then
                                ref = { { 'slot', s, index } }
                                si[index] = ref
                            end
                            local kerns = fci.kerns
                            local width = fci.width
                            local italic = fci.italic
                            if italic and isextension then
                                -- int_a^b
                                width = width + italic
                            end
                            if kerns then
                                local krn = { }
                                for k, v in next, kerns do -- kerns is sparse
                                    local rk = rotcev[k]
                                    if rk then
                                        krn[rk] = v -- kerns[k]
                                    end
                                end
                                if not next(krn) then
                                    krn = nil
                                end
                                local t = {
                                    width    = width,
                                    height   = fci.height,
                                    depth    = fci.depth,
                                    italic   = italic,
                                    kerns    = krn,
                                    commands = ref,
                                }
                                if skewchar then
                                    local k = kerns[skewchar]
                                    if k then
                                        t.top_accent = width/2 + k
                                    end
                                end
                                characters[unicode] = t
                            else
                                characters[unicode] = {
                                    width    = width,
                                    height   = fci.height,
                                    depth    = fci.depth,
                                    italic   = italic,
                                    commands = ref,
                                }
                            end
--~ report_virtual("%05X %s %s",unicode,fci.height or "NO HEIGHT",fci.depth or "NO DEPTH")
                        end
                    end
                    if isextension then
                        -- todo: if multiple ex, then 256 offsets per instance
                        local extension = mathencodings["large-to-small"]
                        local variants_done = fs.variants_done
                        for index, fci in next, fc do -- the raw ex file
                            if type(index) == "number" then
                                local ref = si[index]
                                if not ref then
                                    ref = { { 'slot', s, index } }
                                    si[index] = ref
                                end
                                local italic = fci.italic
                                local t = {
                                    width    = fci.width + italic, -- watch this !
                                    height   = fci.height,
                                    depth    = fci.depth,
                                    italic   = italic,
                                    commands = ref,
                                }
                                local n = fci.next
                                if n then
                                    t.next = offset + n
                                elseif variants_done then
                                    local vv = fci.vert_variants
                                    if vv then
                                        t.vert_variants = vv
                                    end
                                    local hv = fci.horiz_variants
                                    if hv then
                                        t.horiz_variants = hv
                                    end
                                else
                                    local vv = fci.vert_variants
                                    if vv then
                                        for i=1,#vv do
                                            local vvi = vv[i]
                                            vvi.glyph = vvi.glyph + offset
                                        end
                                        t.vert_variants = vv
                                    end
                                    local hv = fci.horiz_variants
                                    if hv then
                                        for i=1,#hv do
                                            local hvi = hv[i]
                                            hvi.glyph = hvi.glyph + offset
                                        end
                                        t.horiz_variants = hv
                                    end
                                end
                                characters[offset + index] = t
                            end
                        end
                        fs.variants_done = true
                        for unicode, index in next, extension do
                            local cu = characters[unicode]
                            if cu then
                                cu.next = offset + index
                            else
                                local fci = fc[index]
                                if not fci then
                                    -- do nothing
                                else
                                    -- probably never entered
                                    local ref = si[index]
                                    if not ref then
                                        ref = { { 'slot', s, index } }
                                        si[index] = ref
                                    end
                                    local kerns = fci.kerns
                                    if kerns then
                                        local krn = { }
--~                                         for k=1,#kerns do
--~                                             krn[offset + k] = kerns[k]
--~                                         end
                                        for k, v in next, kerns do -- is kerns sparse?
                                            krn[offset + k] = v
                                        end
                                        characters[unicode] = {
                                            width    = fci.width,
                                            height   = fci.height,
                                            depth    = fci.depth,
                                            italic   = fci.italic,
                                            commands = ref,
                                            kerns    = krn,
                                            next     = offset + index,
                                        }
                                    else
                                        characters[unicode] = {
                                            width    = fci.width,
                                            height   = fci.height,
                                            depth    = fci.depth,
                                            italic   = fci.italic,
                                            commands = ref,
                                            next     = offset + index,
                                        }
                                    end
                                end
                            end
                        end
                    end
                else
                    report_virtual("error in loading %s: problematic vector %s",name,vectorname)
                end
            end
            mathematics.extras.copy(main) --not needed here (yet)
        end
    end
    --
    fontlist[#fontlist+1] = {
        id   = font.nextid(),
        size = size,
    }
    --
    main.mathparameters = mathparameters -- still traditional ones
    vfmath.addmissing(main,#fontlist,size)
    mathematics.addfallbacks(main)
    --
    main.properties.math_is_scaled = true -- signal
    fonts.constructors.assignmathparameters(main,main)
    --
    main.MathConstants = main.mathparameters -- we directly pass it to TeX (bypasses the scaler) so this is needed
-- inspect(main.MathConstants)
    --
    if trace_virtual or trace_timings then
        report_virtual("loading and virtualizing font %s at size %s took %0.3f seconds",name,size,os.clock()-start)
    end
    --
    return main
end

function mathematics.makefont(name,set,goodies)
    fonts.definers.methods.variants[name] = function(specification)
        return vfmath.define(specification,set,goodies)
    end
end

-- varphi is part of the alphabet, contrary to the other var*s'

mathencodings["large-to-small"] = {
    [0x00028] = 0x00, -- (
    [0x00029] = 0x01, -- )
    [0x0005B] = 0x02, -- [
    [0x0005D] = 0x03, -- ]
    [0x0230A] = 0x04, -- lfloor
    [0x0230B] = 0x05, -- rfloor
    [0x02308] = 0x06, -- lceil
    [0x02309] = 0x07, -- rceil
    [0x0007B] = 0x08, -- {
    [0x0007D] = 0x09, -- }
    [0x027E8] = 0x0A, -- <
    [0x027E9] = 0x0B, -- >
    [0x0007C] = 0x0C, -- |
--~ [0x0]     = 0x0D, -- lVert rVert Vert
--  [0x0002F] = 0x0E, -- /
    [0x0005C] = 0x0F, -- \
--~ [0x0]     = 0x3A, -- lgroup
--~ [0x0]     = 0x3B, -- rgroup
--~ [0x0]     = 0x3C, -- arrowvert
--~ [0x0]     = 0x3D, -- Arrowvert
    [0x02195] = 0x3F, -- updownarrow
--~ [0x0]     = 0x40, -- lmoustache
--~ [0x0]     = 0x41, -- rmoustache
    [0x0221A] = 0x70, -- sqrt
    [0x021D5] = 0x77, -- Updownarrow
    [0x02191] = 0x78, -- uparrow
    [0x02193] = 0x79, -- downarrow
    [0x021D1] = 0x7E, -- Uparrow
    [0x021D3] = 0x7F, -- Downarrow
    [0x0220F] = 0x59, -- prod
    [0x02210] = 0x61, -- coprod
    [0x02211] = 0x58, -- sum
    [0x0222B] = 0x5A, -- intop
    [0x0222E] = 0x49, -- ointop
    [0xFE302] = 0x62, -- widehat
    [0xFE303] = 0x65, -- widetilde
    [0x022C0] = 0x5E, -- bigwedge
    [0x022C1] = 0x5F, -- bigvee
    [0x022C2] = 0x5C, -- bigcap
    [0x022C3] = 0x5B, -- bigcup
    [0x02044] = 0x0E, -- /
}

-- Beware: these are (in cm/lm) below the baseline due to limitations
-- in the tfm format bu the engien (combined with the mathclass) takes
-- care of it. If we need them in textmode, we should make them virtual
-- and move them up but we're in no hurry with that.

mathencodings["tex-ex"] = {
    [0x0220F] = 0x51, -- prod
    [0x02210] = 0x60, -- coprod
    [0x02211] = 0x50, -- sum
    [0x0222B] = 0x52, -- intop
    [0x0222E] = 0x48, -- ointop
    [0x022C0] = 0x56, -- bigwedge
    [0x022C1] = 0x57, -- bigvee
    [0x022C2] = 0x54, -- bigcap
    [0x022C3] = 0x53, -- bigcup
    [0x02A00] = 0x4A, -- bigodot -- fixed BJ
    [0x02A01] = 0x4C, -- bigoplus
    [0x02A02] = 0x4E, -- bigotimes
 -- [0x02A03] =     , -- bigudot --
    [0x02A04] = 0x55, -- biguplus
    [0x02A06] = 0x46, -- bigsqcup
}

-- only math stuff is needed, since we always use an lm or gyre
-- font as main font

mathencodings["tex-mr"] = {
    [0x00393] = 0x00, -- Gamma
    [0x00394] = 0x01, -- Delta
    [0x00398] = 0x02, -- Theta
    [0x0039B] = 0x03, -- Lambda
    [0x0039E] = 0x04, -- Xi
    [0x003A0] = 0x05, -- Pi
    [0x003A3] = 0x06, -- Sigma
    [0x003A5] = 0x07, -- Upsilon
    [0x003A6] = 0x08, -- Phi
    [0x003A8] = 0x09, -- Psi
    [0x003A9] = 0x0A, -- Omega
--  [0x00060] = 0x12, -- [math]grave
--  [0x000B4] = 0x13, -- [math]acute
--  [0x002C7] = 0x14, -- [math]check
--  [0x002D8] = 0x15, -- [math]breve
--  [0x000AF] = 0x16, -- [math]bar
--  [0x00021] = 0x21, -- !
--  [0x00028] = 0x28, -- (
--  [0x00029] = 0x29, -- )
--  [0x0002B] = 0x2B, -- +
--  [0x0002F] = 0x2F, -- /
--  [0x0003A] = 0x3A, -- :
--  [0x02236] = 0x3A, -- colon
--  [0x0003B] = 0x3B, -- ;
--  [0x0003C] = 0x3C, -- <
--  [0x0003D] = 0x3D, -- =
--  [0x0003E] = 0x3E, -- >
--  [0x0003F] = 0x3F, -- ?
    [0x00391] = 0x41, -- Alpha
    [0x00392] = 0x42, -- Beta
    [0x02145] = 0x44,
    [0x00395] = 0x45, -- Epsilon
    [0x00397] = 0x48, -- Eta
    [0x00399] = 0x49, -- Iota
    [0x0039A] = 0x4B, -- Kappa
    [0x0039C] = 0x4D, -- Mu
    [0x0039D] = 0x4E, -- Nu
    [0x0039F] = 0x4F, -- Omicron
    [0x003A1] = 0x52, -- Rho
    [0x003A4] = 0x54, -- Tau
    [0x003A7] = 0x58, -- Chi
    [0x00396] = 0x5A, -- Zeta
--  [0x0005B] = 0x5B, -- [
--  [0x0005D] = 0x5D, -- ]
--  [0x0005E] = 0x5E, -- [math]hat -- the text one
    [0x00302] = 0x5E, -- [math]hat -- the real math one
--  [0x002D9] = 0x5F, -- [math]dot
    [0x02146] = 0x64,
    [0x02147] = 0x65,
--  [0x002DC] = 0x7E, -- [math]tilde -- the text one
    [0x00303] = 0x7E, -- [math]tilde -- the real one
--  [0x000A8] = 0x7F, -- [math]ddot
}

mathencodings["tex-mr-missing"] = {
    [0x02236] = 0x3A, -- colon
}

mathencodings["tex-mi"] = {
    [0x1D6E4] = 0x00, -- Gamma
    [0x1D6E5] = 0x01, -- Delta
    [0x1D6E9] = 0x02, -- Theta
    [0x1D6F3] = 0x02, -- varTheta (not present in TeX)
    [0x1D6EC] = 0x03, -- Lambda
    [0x1D6EF] = 0x04, -- Xi
    [0x1D6F1] = 0x05, -- Pi
    [0x1D6F4] = 0x06, -- Sigma
    [0x1D6F6] = 0x07, -- Upsilon
    [0x1D6F7] = 0x08, -- Phi
    [0x1D6F9] = 0x09, -- Psi
    [0x1D6FA] = 0x0A, -- Omega
    [0x1D6FC] = 0x0B, -- alpha
    [0x1D6FD] = 0x0C, -- beta
    [0x1D6FE] = 0x0D, -- gamma
    [0x1D6FF] = 0x0E, -- delta
    [0x1D716] = 0x0F, -- epsilon TODO: 1D716
    [0x1D701] = 0x10, -- zeta
    [0x1D702] = 0x11, -- eta
    [0x1D703] = 0x12, -- theta TODO: 1D703
    [0x1D704] = 0x13, -- iota
    [0x1D705] = 0x14, -- kappa
    [0x1D718] = 0x14, -- varkappa, not in tex fonts
    [0x1D706] = 0x15, -- lambda
    [0x1D707] = 0x16, -- mu
    [0x1D708] = 0x17, -- nu
    [0x1D709] = 0x18, -- xi
    [0x1D70B] = 0x19, -- pi
    [0x1D70C] = 0x1A, -- rho
    [0x1D70E] = 0x1B, -- sigma
    [0x1D70F] = 0x1C, -- tau
    [0x1D710] = 0x1D, -- upsilon
    [0x1D719] = 0x1E, -- phi
    [0x1D712] = 0x1F, -- chi
    [0x1D713] = 0x20, -- psi
    [0x1D714] = 0x21, -- omega
    [0x1D700] = 0x22, -- varepsilon (the other way around)
    [0x1D717] = 0x23, -- vartheta
    [0x1D71B] = 0x24, -- varpi
    [0x1D71A] = 0x25, -- varrho
    [0x1D70D] = 0x26, -- varsigma
    [0x1D711] = 0x27, -- varphi (the other way around)
    [0x021BC] = 0x28, -- leftharpoonup
    [0x021BD] = 0x29, -- leftharpoondown
    [0x021C0] = 0x2A, -- rightharpoonup
    [0x021C1] = 0x2B, -- rightharpoondown
    [0xFE322] = 0x2C, -- lhook (hook for combining arrows)
    [0xFE323] = 0x2D, -- rhook (hook for combining arrows)
    [0x025B7] = 0x2E, -- triangleright : cf lmmath / BJ
    [0x025C1] = 0x2F, -- triangleleft  : cf lmmath / BJ
    [0x022B3] = 0x2E, -- triangleright : cf lmmath this a cramped triangles / BJ / see *
    [0x022B2] = 0x2F, -- triangleleft  : cf lmmath this a cramped triangles / BJ / see *
--  [0x00041] = 0x30, -- 0
--  [0x00041] = 0x31, -- 1
--  [0x00041] = 0x32, -- 2
--  [0x00041] = 0x33, -- 3
--  [0x00041] = 0x34, -- 4
--  [0x00041] = 0x35, -- 5
--  [0x00041] = 0x36, -- 6
--  [0x00041] = 0x37, -- 7
--  [0x00041] = 0x38, -- 8
--  [0x00041] = 0x39, -- 9
--~     [0x0002E] = 0x3A, -- .
    [0x0002C] = 0x3B, -- ,
    [0x0003C] = 0x3C, -- <
--  [0x0002F] = 0x3D, -- /, slash, solidus
    [0x02044] = 0x3D, -- / AM: Not sure
    [0x0003E] = 0x3E, -- >
    [0x022C6] = 0x3F, -- star
    [0x02202] = 0x40, -- partial
--
    [0x0266D] = 0x5B, -- flat
    [0x0266E] = 0x5C, -- natural
    [0x0266F] = 0x5D, -- sharp
    [0x02323] = 0x5E, -- smile
    [0x02322] = 0x5F, -- frown
    [0x02113] = 0x60, -- ell
--
    [0x1D6A4] = 0x7B, -- imath (TODO: also 0131)
    [0x1D6A5] = 0x7C, -- jmath (TODO: also 0237)
    [0x02118] = 0x7D, -- wp
    [0x020D7] = 0x7E, -- vec (TODO: not sure)
--              0x7F, -- (no idea what that could be)
}

mathencodings["tex-it"] = {
--  [0x1D434] = 0x41, -- A
    [0x1D6E2] = 0x41, -- Alpha
--  [0x1D435] = 0x42, -- B
    [0x1D6E3] = 0x42, -- Beta
--  [0x1D436] = 0x43, -- C
--  [0x1D437] = 0x44, -- D
--  [0x1D438] = 0x45, -- E
    [0x1D6E6] = 0x45, -- Epsilon
--  [0x1D439] = 0x46, -- F
--  [0x1D43A] = 0x47, -- G
--  [0x1D43B] = 0x48, -- H
    [0x1D6E8] = 0x48, -- Eta
--  [0x1D43C] = 0x49, -- I
    [0x1D6EA] = 0x49, -- Iota
--  [0x1D43D] = 0x4A, -- J
--  [0x1D43E] = 0x4B, -- K
    [0x1D6EB] = 0x4B, -- Kappa
--  [0x1D43F] = 0x4C, -- L
--  [0x1D440] = 0x4D, -- M
    [0x1D6ED] = 0x4D, -- Mu
--  [0x1D441] = 0x4E, -- N
    [0x1D6EE] = 0x4E, -- Nu
--  [0x1D442] = 0x4F, -- O
    [0x1D6F0] = 0x4F, -- Omicron
--  [0x1D443] = 0x50, -- P
    [0x1D6F2] = 0x50, -- Rho
--  [0x1D444] = 0x51, -- Q
--  [0x1D445] = 0x52, -- R
--  [0x1D446] = 0x53, -- S
--  [0x1D447] = 0x54, -- T
    [0x1D6F5] = 0x54, -- Tau
--  [0x1D448] = 0x55, -- U
--  [0x1D449] = 0x56, -- V
--  [0x1D44A] = 0x57, -- W
--  [0x1D44B] = 0x58, -- X
    [0x1D6F8] = 0x58, -- Chi
--  [0x1D44C] = 0x59, -- Y
--  [0x1D44D] = 0x5A, -- Z
--
--  [0x1D44E] = 0x61, -- a
--  [0x1D44F] = 0x62, -- b
--  [0x1D450] = 0x63, -- c
--  [0x1D451] = 0x64, -- d
--  [0x1D452] = 0x65, -- e
--  [0x1D453] = 0x66, -- f
--  [0x1D454] = 0x67, -- g
--  [0x1D455] = 0x68, -- h
    [0x0210E] = 0x68, -- Planck constant (h)
--  [0x1D456] = 0x69, -- i
--  [0x1D457] = 0x6A, -- j
--  [0x1D458] = 0x6B, -- k
--  [0x1D459] = 0x6C, -- l
--  [0x1D45A] = 0x6D, -- m
--  [0x1D45B] = 0x6E, -- n
--  [0x1D45C] = 0x6F, -- o
    [0x1D70A] = 0x6F, -- omicron
--  [0x1D45D] = 0x70, -- p
--  [0x1D45E] = 0x71, -- q
--  [0x1D45F] = 0x72, -- r
--  [0x1D460] = 0x73, -- s
--  [0x1D461] = 0x74, -- t
--  [0x1D462] = 0x75, -- u
--  [0x1D463] = 0x76, -- v
--  [0x1D464] = 0x77, -- w
--  [0x1D465] = 0x78, -- x
--  [0x1D466] = 0x79, -- y
--  [0x1D467] = 0x7A, -- z
}

mathencodings["tex-ss"]           = { }
mathencodings["tex-tt"]           = { }
mathencodings["tex-bf"]           = { }
mathencodings["tex-bi"]           = { }
mathencodings["tex-fraktur"]      = { }
mathencodings["tex-fraktur-bold"] = { }

function vfmath.setletters(font_encoding, name, uppercase, lowercase)
    local enc = font_encoding[name]
    for i = 0,25 do
        enc[uppercase+i] = i + 0x41
        enc[lowercase+i] = i + 0x61
    end
end

function vfmath.setdigits(font_encoding, name, digits)
    local enc = font_encoding[name]
    for i = 0,9 do
        enc[digits+i] = i + 0x30
    end
end

mathencodings["tex-sy"] = {
    [0x0002D] = 0x00, -- -
    [0x02212] = 0x00, -- -
--  [0x02201] = 0x00, -- complement
--  [0x02206] = 0x00, -- increment
--  [0x02204] = 0x00, -- not exists
--  [0x000B7] = 0x01, -- cdot
    [0x022C5] = 0x01, -- cdot
    [0x000D7] = 0x02, -- times
    [0x0002A] = 0x03, -- *
    [0x02217] = 0x03, -- *
    [0x000F7] = 0x04, -- div
    [0x022C4] = 0x05, -- diamond
    [0x000B1] = 0x06, -- pm
    [0x02213] = 0x07, -- mp
    [0x02295] = 0x08, -- oplus
    [0x02296] = 0x09, -- ominus
    [0x02297] = 0x0A, -- otimes
    [0x02298] = 0x0B, -- oslash
    [0x02299] = 0x0C, -- odot
    [0x025EF] = 0x0D, -- bigcirc, Orb (either 25EF or 25CB) -- todo
    [0x02218] = 0x0E, -- circ
    [0x02219] = 0x0F, -- bullet
    [0x02022] = 0x0F, -- bullet
    [0x0224D] = 0x10, -- asymp
    [0x02261] = 0x11, -- equiv
    [0x02286] = 0x12, -- subseteq
    [0x02287] = 0x13, -- supseteq
    [0x02264] = 0x14, -- leq
    [0x02265] = 0x15, -- geq
    [0x02AAF] = 0x16, -- preceq
--  [0x0227C] = 0x16, -- preceq, AM:No see 2AAF
    [0x02AB0] = 0x17, -- succeq
--  [0x0227D] = 0x17, -- succeq, AM:No see 2AB0
    [0x0223C] = 0x18, -- sim
    [0x02248] = 0x19, -- approx
    [0x02282] = 0x1A, -- subset
    [0x02283] = 0x1B, -- supset
    [0x0226A] = 0x1C, -- ll
    [0x0226B] = 0x1D, -- gg
    [0x0227A] = 0x1E, -- prec
    [0x0227B] = 0x1F, -- succ
    [0x02190] = 0x20, -- leftarrow
    [0x02192] = 0x21, -- rightarrow
--~ [0xFE190] = 0x20, -- leftarrow
--~ [0xFE192] = 0x21, -- rightarrow
    [0x02191] = 0x22, -- uparrow
    [0x02193] = 0x23, -- downarrow
    [0x02194] = 0x24, -- leftrightarrow
    [0x02197] = 0x25, -- nearrow
    [0x02198] = 0x26, -- searrow
    [0x02243] = 0x27, -- simeq
    [0x021D0] = 0x28, -- Leftarrow
    [0x021D2] = 0x29, -- Rightarrow
    [0x021D1] = 0x2A, -- Uparrow
    [0x021D3] = 0x2B, -- Downarrow
    [0x021D4] = 0x2C, -- Leftrightarrow
    [0x02196] = 0x2D, -- nwarrow
    [0x02199] = 0x2E, -- swarrow
    [0x0221D] = 0x2F, -- propto
    [0x02032] = 0x30, -- prime
    [0x0221E] = 0x31, -- infty
    [0x02208] = 0x32, -- in
    [0x0220B] = 0x33, -- ni
    [0x025B3] = 0x34, -- triangle, bigtriangleup
    [0x025BD] = 0x35, -- bigtriangledown
    [0x00338] = 0x36, -- not
--              0x37, -- (beginning of arrow)
    [0x02200] = 0x38, -- forall
    [0x02203] = 0x39, -- exists
    [0x000AC] = 0x3A, -- neg, lnot
    [0x02205] = 0x3B, -- empty set
    [0x0211C] = 0x3C, -- Re
    [0x02111] = 0x3D, -- Im
    [0x022A4] = 0x3E, -- top
    [0x022A5] = 0x3F, -- bot, perp
    [0x02135] = 0x40, -- aleph
    [0x1D49C] = 0x41, -- script A
    [0x0212C] = 0x42, -- script B
    [0x1D49E] = 0x43, -- script C
    [0x1D49F] = 0x44, -- script D
    [0x02130] = 0x45, -- script E
    [0x02131] = 0x46, -- script F
    [0x1D4A2] = 0x47, -- script G
    [0x0210B] = 0x48, -- script H
    [0x02110] = 0x49, -- script I
    [0x1D4A5] = 0x4A, -- script J
    [0x1D4A6] = 0x4B, -- script K
    [0x02112] = 0x4C, -- script L
    [0x02133] = 0x4D, -- script M
    [0x1D4A9] = 0x4E, -- script N
    [0x1D4AA] = 0x4F, -- script O
    [0x1D4AB] = 0x50, -- script P
    [0x1D4AC] = 0x51, -- script Q
    [0x0211B] = 0x52, -- script R
    [0x1D4AE] = 0x53, -- script S
    [0x1D4AF] = 0x54, -- script T
    [0x1D4B0] = 0x55, -- script U
    [0x1D4B1] = 0x56, -- script V
    [0x1D4B2] = 0x57, -- script W
    [0x1D4B3] = 0x58, -- script X
    [0x1D4B4] = 0x59, -- script Y
    [0x1D4B5] = 0x5A, -- script Z
    [0x0222A] = 0x5B, -- cup
    [0x02229] = 0x5C, -- cap
    [0x0228E] = 0x5D, -- uplus
    [0x02227] = 0x5E, -- wedge, land
    [0x02228] = 0x5F, -- vee, lor
    [0x022A2] = 0x60, -- vdash
    [0x022A3] = 0x61, -- dashv
    [0x0230A] = 0x62, -- lfloor
    [0x0230B] = 0x63, -- rfloor
    [0x02308] = 0x64, -- lceil
    [0x02309] = 0x65, -- rceil
    [0x0007B] = 0x66, -- {, lbrace
    [0x0007D] = 0x67, -- }, rbrace
    [0x027E8] = 0x68, -- <, langle
    [0x027E9] = 0x69, -- >, rangle
    [0x0007C] = 0x6A, -- |, mid, lvert, rvert
    [0x02225] = 0x6B, -- parallel
 -- [0x02016] = 0x00, -- Vert, lVert, rVert, arrowvert, Arrowvert
    [0x02195] = 0x6C, -- updownarrow
    [0x021D5] = 0x6D, -- Updownarrow
    [0x0005C] = 0x6E, -- \, backslash, setminus
    [0x02216] = 0x6E, -- setminus
    [0x02240] = 0x6F, -- wr
    [0x0221A] = 0x70, -- sqrt. AM: Check surd??
    [0x02A3F] = 0x71, -- amalg
    [0x1D6FB] = 0x72, -- nabla
--  [0x0222B] = 0x73, -- smallint (TODO: what about intop?)
    [0x02294] = 0x74, -- sqcup
    [0x02293] = 0x75, -- sqcap
    [0x02291] = 0x76, -- sqsubseteq
    [0x02292] = 0x77, -- sqsupseteq
    [0x000A7] = 0x78, -- S
    [0x02020] = 0x79, -- dagger, dag
    [0x02021] = 0x7A, -- ddagger, ddag
    [0x000B6] = 0x7B, -- P
    [0x02663] = 0x7C, -- clubsuit
    [0x02662] = 0x7D, -- diamondsuit
    [0x02661] = 0x7E, -- heartsuit
    [0x02660] = 0x7F, -- spadesuit
    [0xFE321] = 0x37, -- mapstochar

    [0xFE325] = 0x30, -- prime 0x02032
}

-- The names in masm10.enc can be trusted best and are shown in the first
-- column, while in the second column we show the tex/ams names. As usual
-- it costs hours to figure out such a table.

mathencodings["tex-ma"] = {
    [0x022A1] = 0x00, -- squaredot             \boxdot
    [0x0229E] = 0x01, -- squareplus            \boxplus
    [0x022A0] = 0x02, -- squaremultiply        \boxtimes
    [0x025A1] = 0x03, -- square                \square \Box
    [0x025A0] = 0x04, -- squaresolid           \blacksquare
    [0x025AA] = 0x05, -- squaresmallsolid      \centerdot
    [0x022C4] = 0x06, -- diamond               \Diamond \lozenge
    [0x02666] = 0x07, -- diamondsolid          \blacklozenge
    [0x021BB] = 0x08, -- clockwise             \circlearrowright
    [0x021BA] = 0x09, -- anticlockwise         \circlearrowleft
    [0x021CC] = 0x0A, -- harpoonleftright      \rightleftharpoons
    [0x021CB] = 0x0B, -- harpoonrightleft      \leftrightharpoons
    [0x0229F] = 0x0C, -- squareminus           \boxminus
    [0x022A9] = 0x0D, -- forces                \Vdash
    [0x022AA] = 0x0E, -- forcesbar             \Vvdash
    [0x022A8] = 0x0F, -- satisfies             \vDash
    [0x021A0] = 0x10, -- dblarrowheadright     \twoheadrightarrow
    [0x0219E] = 0x11, -- dblarrowheadleft      \twoheadleftarrow
    [0x021C7] = 0x12, -- dblarrowleft          \leftleftarrows
    [0x021C9] = 0x13, -- dblarrowright         \rightrightarrows
    [0x021C8] = 0x14, -- dblarrowup            \upuparrows
    [0x021CA] = 0x15, -- dblarrowdwn           \downdownarrows
    [0x021BE] = 0x16, -- harpoonupright        \upharpoonright \restriction
    [0x021C2] = 0x17, -- harpoondownright      \downharpoonright
    [0x021BF] = 0x18, -- harpoonupleft         \upharpoonleft
    [0x021C3] = 0x19, -- harpoondownleft       \downharpoonleft
    [0x021A3] = 0x1A, -- arrowtailright        \rightarrowtail
    [0x021A2] = 0x1B, -- arrowtailleft         \leftarrowtail
    [0x021C6] = 0x1C, -- arrowparrleftright    \leftrightarrows
--  [0x021C5] = 0x00, --                       \updownarrows (missing in lm)
    [0x021C4] = 0x1D, -- arrowparrrightleft    \rightleftarrows
    [0x021B0] = 0x1E, -- shiftleft             \Lsh
    [0x021B1] = 0x1F, -- shiftright            \Rsh
    [0x021DD] = 0x20, -- squiggleright         \leadsto \rightsquigarrow
    [0x021AD] = 0x21, -- squiggleleftright     \leftrightsquigarrow
    [0x021AB] = 0x22, -- curlyleft             \looparrowleft
    [0x021AC] = 0x23, -- curlyright            \looparrowright
    [0x02257] = 0x24, -- circleequal           \circeq
    [0x0227F] = 0x25, -- followsorequal        \succsim
    [0x02273] = 0x26, -- greaterorsimilar      \gtrsim
    [0x02A86] = 0x27, -- greaterorapproxeql    \gtrapprox
    [0x022B8] = 0x28, -- multimap              \multimap
    [0x02234] = 0x29, -- therefore             \therefore
    [0x02235] = 0x2A, -- because               \because
    [0x02251] = 0x2B, -- equalsdots            \Doteq \doteqdot
    [0x0225C] = 0x2C, -- defines               \triangleq
    [0x0227E] = 0x2D, -- precedesorequal       \precsim
    [0x02272] = 0x2E, -- lessorsimilar         \lesssim
    [0x02A85] = 0x2F, -- lessorapproxeql       \lessapprox
    [0x02A95] = 0x30, -- equalorless           \eqslantless
    [0x02A96] = 0x31, -- equalorgreater        \eqslantgtr
    [0x022DE] = 0x32, -- equalorprecedes       \curlyeqprec
    [0x022DF] = 0x33, -- equalorfollows        \curlyeqsucc
    [0x0227C] = 0x34, -- precedesorcurly       \preccurlyeq
    [0x02266] = 0x35, -- lessdblequal          \leqq
    [0x02A7D] = 0x36, -- lessorequalslant      \leqslant
    [0x02276] = 0x37, -- lessorgreater         \lessgtr
    [0x02035] = 0x38, -- primereverse          \backprime
    --  [0x0] = 0x39, -- axisshort             \dabar
    [0x02253] = 0x3A, -- equaldotrightleft     \risingdotseq
    [0x02252] = 0x3B, -- equaldotleftright     \fallingdotseq
    [0x0227D] = 0x3C, -- followsorcurly        \succcurlyeq
    [0x02267] = 0x3D, -- greaterdblequal       \geqq
    [0x02A7E] = 0x3E, -- greaterorequalslant   \geqslant
    [0x02277] = 0x3F, -- greaterorless         \gtrless
    [0x0228F] = 0x40, -- squareimage           \sqsubset
    [0x02290] = 0x41, -- squareoriginal        \sqsupset
    -- wrong: see **
 -- [0x022B3] = 0x42, -- triangleright         \rhd \vartriangleright
 -- [0x022B2] = 0x43, -- triangleleft          \lhd \vartriangleleft
    -- cf lm
    [0x022B5] = 0x44, -- trianglerightequal    \unrhd \trianglerighteq
    [0x022B4] = 0x45, -- triangleleftequal     \unlhd \trianglelefteq
    --
    [0x02605] = 0x46, -- star                  \bigstar
    [0x0226C] = 0x47, -- between               \between
    [0x025BC] = 0x48, -- triangledownsld       \blacktriangledown
    [0x025B6] = 0x49, -- trianglerightsld      \blacktriangleright
    [0x025C0] = 0x4A, -- triangleleftsld       \blacktriangleleft
    --  [0x0] = 0x4B, -- arrowaxisright
    --  [0x0] = 0x4C, -- arrowaxisleft
    [0x025B2] = 0x4D, -- triangle              \triangleup \vartriangle
    [0x025B2] = 0x4E, -- trianglesolid         \blacktriangle
    [0x025BC] = 0x4F, -- triangleinv           \triangledown
    [0x02256] = 0x50, -- ringinequal           \eqcirc
    [0x022DA] = 0x51, -- lessequalgreater      \lesseqgtr
    [0x022DB] = 0x52, -- greaterlessequal      \gtreqless
    [0x02A8B] = 0x53, -- lessdbleqlgreater     \lesseqqgtr
    [0x02A8C] = 0x54, -- greaterdbleqlless     \gtreqqless
    [0x000A5] = 0x55, -- Yen                   \yen
    [0x021DB] = 0x56, -- arrowtripleright      \Rrightarrow
    [0x021DA] = 0x57, -- arrowtripleleft       \Lleftarrow
    [0x02713] = 0x58, -- check                 \checkmark
    [0x022BB] = 0x59, -- orunderscore          \veebar
    [0x022BC] = 0x5A, -- nand                  \barwedge
    [0x02306] = 0x5B, -- perpcorrespond        \doublebarwedge
    [0x02220] = 0x5C, -- angle                 \angle
    [0x02221] = 0x5D, -- measuredangle         \measuredangle
    [0x02222] = 0x5E, -- sphericalangle        \sphericalangle
    --  [0x0] = 0x5F, -- proportional          \varpropto
    --  [0x0] = 0x60, -- smile                 \smallsmile
    --  [0x0] = 0x61, -- frown                 \smallfrown
    [0x022D0] = 0x62, -- subsetdbl             \Subset
    [0x022D1] = 0x63, -- supersetdbl           \Supset
    [0x022D3] = 0x64, -- uniondbl              \doublecup \Cup
    [0x022D2] = 0x65, -- intersectiondbl       \doublecap \Cap
    [0x022CF] = 0x66, -- uprise                \curlywedge
    [0x022CE] = 0x67, -- downfall              \curlyvee
    [0x022CB] = 0x68, -- multiopenleft         \leftthreetimes
    [0x022CC] = 0x69, -- multiopenright        \rightthreetimes
    [0x02AC5] = 0x6A, -- subsetdblequal        \subseteqq
    [0x02AC6] = 0x6B, -- supersetdblequal      \supseteqq
    [0x0224F] = 0x6C, -- difference            \bumpeq
    [0x0224E] = 0x6D, -- geomequivalent        \Bumpeq
    [0x022D8] = 0x6E, -- muchless              \lll \llless
    [0x022D9] = 0x6F, -- muchgreater           \ggg \gggtr
    [0x0231C] = 0x70, -- rightanglenw          \ulcorner
    [0x0231D] = 0x71, -- rightanglene          \urcorner
    [0x024C7] = 0x72, -- circleR               \circledR
    [0x024C8] = 0x73, -- circleS               \circledS
    [0x022D4] = 0x74, -- fork                  \pitchfork
    [0x02214] = 0x75, -- dotplus               \dotplus
    [0x0223D] = 0x76, -- revsimilar            \backsim
    [0x022CD] = 0x77, -- revasymptequal        \backsimeq -- AM: Check this! I mapped it to simeq.
    [0x0231E] = 0x78, -- rightanglesw          \llcorner
    [0x0231F] = 0x79, -- rightanglese          \lrcorner
    [0x02720] = 0x7A, -- maltesecross          \maltese
    [0x02201] = 0x7B, -- complement            \complement
    [0x022BA] = 0x7C, -- intercal              \intercal
    [0x0229A] = 0x7D, -- circlering            \circledcirc
    [0x0229B] = 0x7E, -- circleasterisk        \circledast
    [0x0229D] = 0x7F, -- circleminus           \circleddash
}

mathencodings["tex-mb"] = {
    --  [0x0] = 0x00, -- lessornotequal        \lvertneqq
    --  [0x0] = 0x01, -- greaterornotequal     \gvertneqq
    [0x02270] = 0x02, -- notlessequal          \nleq
    [0x02271] = 0x03, -- notgreaterequal       \ngeq
    [0x0226E] = 0x04, -- notless               \nless
    [0x0226F] = 0x05, -- notgreater            \ngtr
    [0x02280] = 0x06, -- notprecedes           \nprec
    [0x02281] = 0x07, -- notfollows            \nsucc
    [0x02268] = 0x08, -- lessornotdbleql       \lneqq
    [0x02269] = 0x09, -- greaterornotdbleql    \gneqq
    --  [0x0] = 0x0A, -- notlessorslnteql      \nleqslant
    --  [0x0] = 0x0B, -- notgreaterorslnteql   \ngeqslant
    [0x02A87] = 0x0C, -- lessnotequal          \lneq
    [0x02A88] = 0x0D, -- greaternotequal       \gneq
    --  [0x0] = 0x0E, -- notprecedesoreql      \npreceq
    --  [0x0] = 0x0F, -- notfollowsoreql       \nsucceq
    [0x022E8] = 0x10, -- precedeornoteqvlnt    \precnsim
    [0x022E9] = 0x11, -- followornoteqvlnt     \succnsim
    [0x022E6] = 0x12, -- lessornotsimilar      \lnsim
    [0x022E7] = 0x13, -- greaterornotsimilar   \gnsim
    --  [0x0] = 0x14, -- notlessdblequal       \nleqq
    --  [0x0] = 0x15, -- notgreaterdblequal    \ngeqq
    [0x02AB5] = 0x16, -- precedenotslnteql     \precneqq
    [0x02AB6] = 0x17, -- follownotslnteql      \succneqq
    [0x02AB9] = 0x18, -- precedenotdbleqv      \precnapprox
    [0x02ABA] = 0x19, -- follownotdbleqv       \succnapprox
    [0x02A89] = 0x1A, -- lessnotdblequal       \lnapprox
    [0x02A8A] = 0x1B, -- greaternotdblequal    \gnapprox
    [0x02241] = 0x1C, -- notsimilar            \nsim
    [0x02247] = 0x1D, -- notapproxequal        \ncong
    --  [0x0] = 0x1E, -- upslope               \diagup
    --  [0x0] = 0x1F, -- downslope             \diagdown
    --  [0x0] = 0x20, -- notsubsetoreql        \varsubsetneq
    --  [0x0] = 0x21, -- notsupersetoreql      \varsupsetneq
    --  [0x0] = 0x22, -- notsubsetordbleql     \nsubseteqq
    --  [0x0] = 0x23, -- notsupersetordbleql   \nsupseteqq
    [0x02ACB] = 0x24, -- subsetornotdbleql     \subsetneqq
    [0x02ACC] = 0x25, -- supersetornotdbleql   \supsetneqq
    --  [0x0] = 0x26, -- subsetornoteql        \varsubsetneqq
    --  [0x0] = 0x27, -- supersetornoteql      \varsupsetneqq
    [0x0228A] = 0x28, -- subsetnoteql          \subsetneq
    [0x0228B] = 0x29, -- supersetnoteql        \supsetneq
    [0x02288] = 0x2A, -- notsubseteql          \nsubseteq
    [0x02289] = 0x2B, -- notsuperseteql        \nsupseteq
    [0x02226] = 0x2C, -- notparallel           \nparallel
    [0x02224] = 0x2D, -- notbar                \nmid \ndivides
    --  [0x0] = 0x2E, -- notshortbar           \nshortmid
    --  [0x0] = 0x2F, -- notshortparallel      \nshortparallel
    [0x022AC] = 0x30, -- notturnstile          \nvdash
    [0x022AE] = 0x31, -- notforces             \nVdash
    [0x022AD] = 0x32, -- notsatisfies          \nvDash
    [0x022AF] = 0x33, -- notforcesextra        \nVDash
    [0x022ED] = 0x34, -- nottriangeqlright     \ntrianglerighteq
    [0x022EC] = 0x35, -- nottriangeqlleft      \ntrianglelefteq
    [0x022EA] = 0x36, -- nottriangleleft       \ntriangleleft
    [0x022EB] = 0x37, -- nottriangleright      \ntriangleright
    [0x0219A] = 0x38, -- notarrowleft          \nleftarrow
    [0x0219B] = 0x39, -- notarrowright         \nrightarrow
    [0x021CD] = 0x3A, -- notdblarrowleft       \nLeftarrow
    [0x021CF] = 0x3B, -- notdblarrowright      \nRightarrow
    [0x021CE] = 0x3C, -- notdblarrowboth       \nLeftrightarrow
    [0x021AE] = 0x3D, -- notarrowboth          \nleftrightarrow
    [0x022C7] = 0x3E, -- dividemultiply        \divideontimes
    [0x02300] = 0x3F, -- diametersign          \varnothing
    [0x02204] = 0x40, -- notexistential        \nexists
    [0x1D538] = 0x41, -- A                     (blackboard A)
    [0x1D539] = 0x42, -- B
    [0x02102] = 0x43, -- C
    [0x1D53B] = 0x44, -- D
    [0x1D53C] = 0x45, -- E
    [0x1D53D] = 0x46, -- F
    [0x1D53E] = 0x47, -- G
    [0x0210D] = 0x48, -- H
    [0x1D540] = 0x49, -- I
    [0x1D541] = 0x4A, -- J
    [0x1D542] = 0x4B, -- K
    [0x1D543] = 0x4C, -- L
    [0x1D544] = 0x4D, -- M
    [0x02115] = 0x4E, -- N
    [0x1D546] = 0x4F, -- O
    [0x02119] = 0x50, -- P
    [0x0211A] = 0x51, -- Q
    [0x0211D] = 0x52, -- R
    [0x1D54A] = 0x53, -- S
    [0x1D54B] = 0x54, -- T
    [0x1D54C] = 0x55, -- U
    [0x1D54D] = 0x56, -- V
    [0x1D54E] = 0x57, -- W
    [0x1D54F] = 0x58, -- X
    [0x1D550] = 0x59, -- Y
    [0x02124] = 0x5A, -- Z                     (blackboard Z)
    [0x02132] = 0x60, -- finv                  \Finv
    [0x02141] = 0x61, -- fmir                  \Game
    --  [0x0] = 0x62,    tildewide
    --  [0x0] = 0x63,    tildewider
    --  [0x0] = 0x64,    Finv
    --  [0x0] = 0x65,    Gmir
    [0x02127] = 0x66, -- Omegainv              \mho
    [0x000F0] = 0x67, -- eth                   \eth
    [0x02242] = 0x68, -- equalorsimilar        \eqsim
    [0x02136] = 0x69, -- beth                  \beth
    [0x02137] = 0x6A, -- gimel                 \gimel
    [0x02138] = 0x6B, -- daleth                \daleth
    [0x022D6] = 0x6C, -- lessdot               \lessdot
    [0x022D7] = 0x6D, -- greaterdot            \gtrdot
    [0x022C9] = 0x6E, -- multicloseleft        \ltimes
    [0x022CA] = 0x6F, -- multicloseright       \rtimes
    --  [0x0] = 0x70, -- barshort              \shortmid
    --  [0x0] = 0x71, -- parallelshort         \shortparallel
    --  [0x02216] = 0x72, -- integerdivide         \smallsetminus (2216 already part of tex-sy
    --  [0x0] = 0x73, -- similar               \thicksim
    --  [0x0] = 0x74, -- approxequal           \thickapprox
    [0x0224A] = 0x75, -- approxorequal         \approxeq
    [0x02AB8] = 0x76, -- followsorequal        \succapprox
    [0x02AB7] = 0x77, -- precedesorequal       \precapprox
    [0x021B6] = 0x78, -- archleftdown          \curvearrowleft
    [0x021B7] = 0x79, -- archrightdown         \curvearrowright
    [0x003DC] = 0x7A, -- Digamma               \digamma
    [0x003F0] = 0x7B, -- kappa                 \varkappa
    [0x1D55C] = 0x7C, -- k                     \Bbbk (blackboard k)
    [0x0210F] = 0x7D, -- planckover2pi         \hslash
    [0x00127] = 0x7E, -- planckover2pi1        \hbar
    [0x003F6] = 0x7F, -- epsiloninv            \backepsilon
}

mathencodings["tex-mc"] = {
    -- this file has no tfm so it gets mapped in the private space
    [0xFE324] = "mapsfromchar",
}

mathencodings["tex-fraktur"] = {
--  [0x1D504] = 0x41, -- A                     (fraktur A)
--  [0x1D505] = 0x42, -- B
    [0x0212D] = 0x43, -- C
--  [0x1D507] = 0x44, -- D
--  [0x1D508] = 0x45, -- E
--  [0x1D509] = 0x46, -- F
--  [0x1D50A] = 0x47, -- G
    [0x0210C] = 0x48, -- H
    [0x02111] = 0x49, -- I
--  [0x1D50D] = 0x4A, -- J
--  [0x1D50E] = 0x4B, -- K
--  [0x1D50F] = 0x4C, -- L
--  [0x1D510] = 0x4D, -- M
--  [0x1D511] = 0x4E, -- N
--  [0x1D512] = 0x4F, -- O
--  [0x1D513] = 0x50, -- P
--  [0x1D514] = 0x51, -- Q
    [0x0211C] = 0x52, -- R
--  [0x1D516] = 0x53, -- S
--  [0x1D517] = 0x54, -- T
--  [0x1D518] = 0x55, -- U
--  [0x1D519] = 0x56, -- V
--  [0x1D51A] = 0x57, -- W
--  [0x1D51B] = 0x58, -- X
--  [0x1D51C] = 0x59, -- Y
    [0x02128] = 0x5A, -- Z                     (fraktur Z)
--  [0x1D51E] = 0x61, -- a                     (fraktur a)
--  [0x1D51F] = 0x62, -- b
--  [0x1D520] = 0x63, -- c
--  [0x1D521] = 0x64, -- d
--  [0x1D522] = 0x65, -- e
--  [0x1D523] = 0x66, -- f
--  [0x1D524] = 0x67, -- g
--  [0x1D525] = 0x68, -- h
--  [0x1D526] = 0x69, -- i
--  [0x1D527] = 0x6A, -- j
--  [0x1D528] = 0x6B, -- k
--  [0x1D529] = 0x6C, -- l
--  [0x1D52A] = 0x6D, -- m
--  [0x1D52B] = 0x6E, -- n
--  [0x1D52C] = 0x6F, -- o
--  [0x1D52D] = 0x70, -- p
--  [0x1D52E] = 0x71, -- q
--  [0x1D52F] = 0x72, -- r
--  [0x1D530] = 0x73, -- s
--  [0x1D531] = 0x74, -- t
--  [0x1D532] = 0x75, -- u
--  [0x1D533] = 0x76, -- v
--  [0x1D534] = 0x77, -- w
--  [0x1D535] = 0x78, -- x
--  [0x1D536] = 0x79, -- y
--  [0x1D537] = 0x7A, -- z
}

-- now that all other vectors are defined ...

vfmath.setletters(mathencodings, "tex-it",           0x1D434, 0x1D44E)
vfmath.setletters(mathencodings, "tex-ss",           0x1D5A0, 0x1D5BA)
vfmath.setletters(mathencodings, "tex-tt",           0x1D670, 0x1D68A)
vfmath.setletters(mathencodings, "tex-bf",           0x1D400, 0x1D41A)
vfmath.setletters(mathencodings, "tex-bi",           0x1D468, 0x1D482)
vfmath.setletters(mathencodings, "tex-fraktur",      0x1D504, 0x1D51E)
vfmath.setletters(mathencodings, "tex-fraktur-bold", 0x1D56C, 0x1D586)

vfmath.setdigits (mathencodings, "tex-ss", 0x1D7E2)
vfmath.setdigits (mathencodings, "tex-tt", 0x1D7F6)
vfmath.setdigits (mathencodings, "tex-bf", 0x1D7CE)

-- vfmath.setdigits (mathencodings, "tex-bi", 0x1D7CE)

-- todo: add ss, tt, bf etc vectors
-- todo: we can make ss tt etc an option

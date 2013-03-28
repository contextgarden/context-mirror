if not modules then modules = { } end modules ['font-otx'] = {
    version   = 1.001,
    comment   = "companion to font-otf.lua (analysing)",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- context only

local type = type

if not trackers then trackers = { register = function() end } end

----- trace_analyzing = false  trackers.register("otf.analyzing",  function(v) trace_analyzing = v end)

local fonts, nodes, node = fonts, nodes, node

local allocate            = utilities.storage.allocate

local otf                 = fonts.handlers.otf

local analyzers           = fonts.analyzers
local initializers        = allocate()
local methods             = allocate()

analyzers.initializers    = initializers
analyzers.methods         = methods
---------.useunicodemarks = false

local a_state             = attributes.private('state')

local nodecodes           = nodes.nodecodes
local glyph_code          = nodecodes.glyph
local math_code           = nodecodes.math

local traverse_id         = node.traverse_id
local traverse_node_list  = node.traverse
local end_of_math         = node.end_of_math

local fontdata            = fonts.hashes.identifiers
local categories          = characters and characters.categories or { } -- sorry, only in context
local chardata            = characters and characters.data

local otffeatures         = fonts.constructors.newfeatures("otf")
local registerotffeature  = otffeatures.register

--[[ldx--
<p>Analyzers run per script and/or language and are needed in order to
process features right.</p>
--ldx]]--

-- never use these numbers directly

local s_init = 1    local s_rphf =  7
local s_medi = 2    local s_half =  8
local s_fina = 3    local s_pref =  9
local s_isol = 4    local s_blwf = 10
local s_mark = 5    local s_pstf = 11
local s_rest = 6

local states = {
    init = s_init,
    medi = s_medi,
    fina = s_fina,
    isol = s_isol,
    mark = s_mark,
    rest = s_rest,
    rphf = s_rphf,
    half = s_half,
    pref = s_pref,
    blwf = s_blwf,
    pstf = s_pstf,
}

local features = {
    init = s_init,
    medi = s_medi,
    fina = s_fina,
    isol = s_isol,
 -- mark = s_mark,
}

analyzers.states   = states
analyzers.features = features

-- todo: analyzers per script/lang, cross font, so we need an font id hash -> script
-- e.g. latin -> hyphenate, arab -> 1/2/3 analyze -- its own namespace

function analyzers.setstate(head,font)
    local useunicodemarks  = analyzers.useunicodemarks
    local tfmdata = fontdata[font]
    local descriptions = tfmdata.descriptions
    local first, last, current, n, done = nil, nil, head, 0, false -- maybe make n boolean
    while current do
        local id = current.id
        if id == glyph_code and current.font == font then
            done = true
            local char = current.char
            local d = descriptions[char]
            if d then
                if d.class == "mark" or (useunicodemarks and categories[char] == "mn") then
                    done = true
                    current[a_state] = s_mark
                elseif n == 0 then
                    first, last, n = current, current, 1
                    current[a_state] = s_init
                else
                    last, n = current, n+1
                    current[a_state] = s_medi
                end
            else -- finish
                if first and first == last then
                    last[a_state] = s_isol
                elseif last then
                    last[a_state] = s_fina
                end
                first, last, n = nil, nil, 0
            end
        elseif id == disc_code then
            -- always in the middle
            current[a_state] = s_midi
            last = current
        else -- finish
            if first and first == last then
                last[a_state] = s_isol
            elseif last then
                last[a_state] = s_fina
            end
            first, last, n = nil, nil, 0
            if id == math_code then
                current = end_of_math(current)
            end
        end
        current = current.next
    end
    if first and first == last then
        last[a_state] = s_isol
    elseif last then
        last[a_state] = s_fina
    end
    return head, done
end

-- in the future we will use language/script attributes instead of the
-- font related value, but then we also need dynamic features which is
-- somewhat slower; and .. we need a chain of them

local function analyzeinitializer(tfmdata,value) -- attr
    local script, language = otf.scriptandlanguage(tfmdata) -- attr
    local action = initializers[script]
    if not action then
        -- skip
    elseif type(action) == "function" then
        return action(tfmdata,value)
    else
        local action = action[language]
        if action then
            return action(tfmdata,value)
        end
    end
end

local function analyzeprocessor(head,font,attr)
    local tfmdata = fontdata[font]
    local script, language = otf.scriptandlanguage(tfmdata,attr)
    local action = methods[script]
    if not action then
        -- skip
    elseif type(action) == "function" then
        return action(head,font,attr)
    else
        action = action[language]
        if action then
            return action(head,font,attr)
        end
    end
    return head, false
end

registerotffeature {
    name         = "analyze",
    description  = "analysis of (for instance) character classes",
    default      = true,
    initializers = {
        node     = analyzeinitializer,
    },
    processors = {
        position = 1,
        node     = analyzeprocessor,
    }
}

-- latin

methods.latn = analyzers.setstate

local arab_warned = { }

local function warning(current,what)
    local char = current.char
    if not arab_warned[char] then
        log.report("analyze","arab: character %C has no %a class",char,what)
        arab_warned[char] = true
    end
end

local mappers = {
    l = s_init,  -- left
    d = s_medi,  -- double
    c = s_medi,  -- joiner
    r = s_fina,  -- right
    u = s_isol,  -- nonjoiner
}

local classifiers = { } -- we can also use this trick for devanagari

local first_arabic,  last_arabic  = characters.blockrange("arabic")
local first_syriac,  last_syriac  = characters.blockrange("syriac")
local first_mandiac, last_mandiac = characters.blockrange("mandiac")
local first_nko,     last_nko     = characters.blockrange("nko")

table.setmetatableindex(classifiers,function(t,k)
    local c = chardata[k]
    local v = false
    if c then
        local arabic = c.arabic
        if arabic then
            v = mappers[arabic]
            if not v then
                log.report("analyze","error in mapping arabic %C",k)
                --  error
                v = false
            end
        elseif k >= first_arabic  and k <= last_arabic  or k >= first_syriac  and k <= last_syriac  or
               k >= first_mandiac and k <= last_mandiac or k >= first_nko     and k <= last_nko     then
            if categories[k] == "mn" then
                v = s_mark
            else
                v = s_rest
            end
        else
        end
    end
    t[k] = v
    return v
end)

function methods.arab(head,font,attr)
    local first, last = nil, nil
    local c_first, c_last = nil, nil
    local current, done = head, false
    while current do
        local id = current.id
        if id == glyph_code and current.font == font and current.subtype<256 and not current[a_state] then
            done = true
            local char = current.char
            local classifier = classifiers[char]
            if not classifier then
                if last then
                    if c_last == s_medi or c_last == s_fina then
                        last[a_state] = s_fina
                    else
                        warning(last,"fina")
                        last[a_state] = s_error
                    end
                    first, last = nil, nil
                elseif first then
                    if c_first == s_medi or c_first == s_fina then
                        first[a_state] = s_isol
                    else
                        warning(first,"isol")
                        first[a_state] = s_error
                    end
                    first = nil
                end
            elseif classifier == s_mark then
                current[a_state] = s_mark
            elseif classifier == s_isol then
                if last then
                    if c_last == s_medi or c_last == s_fina then
                        last[a_state] = s_fina
                    else
                        warning(last,"fina")
                        last[a_state] = s_error
                    end
                    first, last = nil, nil
                elseif first then
                    if c_first == s_medi or c_first == s_fina then
                        first[a_state] = s_isol
                    else
                        warning(first,"isol")
                        first[a_state] = s_error
                    end
                    first = nil
                end
                current[a_state] = s_isol
            elseif classifier == s_medi then
                if first then
                    last = current
                    c_last = classifier
                    current[a_state] = s_medi
                else
                    current[a_state] = s_init
                    first = current
                    c_first = classifier
                end
            elseif classifier == s_fina then
                if last then
                    if last[a_state] ~= s_init then
                        last[a_state] = s_medi
                    end
                    current[a_state] = s_fina
                    first, last = nil, nil
                elseif first then
                 -- if first[a_state] ~= s_init then
                 --     -- needs checking
                 --     first[a_state] = s_medi
                 -- end
                    current[a_state] = s_fina
                    first = nil
                else
                    current[a_state] = s_isol
                end
            else -- classifier == s_rest
                current[a_state] = s_rest
                if last then
                    if c_last == s_medi or c_last == s_fina then
                        last[a_state] = s_fina
                    else
                        warning(last,"fina")
                        last[a_state] = s_error
                    end
                    first, last = nil, nil
                elseif first then
                    if c_first == s_medi or c_first == s_fina then
                        first[a_state] = s_isol
                    else
                        warning(first,"isol")
                        first[a_state] = s_error
                    end
                    first = nil
                end
            end
        else
            if last then
                if c_last == s_medi or c_last == s_fina then
                    last[a_state] = s_fina
                else
                    warning(last,"fina")
                    last[a_state] = s_error
                end
                first, last = nil, nil
            elseif first then
                if c_first == s_medi or c_first == s_fina then
                    first[a_state] = s_isol
                else
                    warning(first,"isol")
                    first[a_state] = s_error
                end
                first = nil
            end
            if id == math_code then -- a bit duplicate as we test for glyphs twice
                current = end_of_math(current)
            end
        end
        current = current.next
    end
    if last then
        if c_last == s_medi or c_last == s_fina then
            last[a_state] = s_fina
        else
            warning(last,"fina")
            last[a_state] = s_error
        end
    elseif first then
        if c_first == s_medi or c_first == s_fina then
            first[a_state] = s_isol
        else
            warning(first,"isol")
            first[a_state] = s_error
        end
    end
    return head, done
end

methods.syrc = methods.arab
methods.mand = methods.arab
methods.nko  = methods.arab

-- directives.register("otf.analyze.useunicodemarks",function(v)
--     analyzers.useunicodemarks = v
-- end)

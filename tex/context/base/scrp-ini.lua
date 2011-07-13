if not modules then modules = { } end modules ['scrp-ini'] = {
    version   = 1.001,
    comment   = "companion to scrp-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- we need to rewrite this a bit ... rather old code

local attributes, nodes, node = attributes, nodes, node

local trace_analyzing  = false  trackers.register("scripts.analyzing",  function(v) trace_analyzing  = v end)
local trace_injections = false  trackers.register("scripts.injections", function(v) trace_injections = v end)

local report_preprocessing = logs.reporter("scripts","preprocessing")

local allocate = utilities.storage.allocate

local set_attribute   = node.set_attribute
local has_attribute   = node.has_attribute
local first_glyph     = node.first_glyph or node.first_character
local traverse_id     = node.traverse_id

local texsetattribute = tex.setattribute

local nodecodes       = nodes.nodecodes
local unsetvalue      = attributes.unsetvalue

local glyph_code      = nodecodes.glyph
local glue_code       = nodecodes.glue

local a_preproc       = attributes.private('preproc')
local a_prestat       = attributes.private('prestat')

local fontdata        = fonts.hashes.identifiers

local setnodecolor    = nodes.tracers.colors.set

scripts               = scripts or { }
local scripts         = scripts

scripts.hash          = scripts.hash or { }
local hash            = scripts.hash

local handlers        = allocate()
scripts.handlers      = handlers

storage.register("scripts/hash", hash, "scripts.hash")

if not next(hash) then

    hash = { -- no local
        --
        -- half width opening parenthesis
        [0x0028] = "half_width_open",
        [0x005B] = "half_width_open",
        [0x007B] = "half_width_open",
        [0x2018] = "half_width_open", -- ‘
        [0x201C] = "half_width_open", -- “
        --
        -- full width opening parenthesis
        --
        [0x3008] = "full_width_open", -- 〈   Left book quote
        [0x300A] = "full_width_open", -- 《   Left double book quote
        [0x300C] = "full_width_open", -- 「   left quote
        [0x300E] = "full_width_open", -- 『   left double quote
        [0x3010] = "full_width_open", -- 【   left double book quote
        [0x3014] = "full_width_open", -- 〔   left book quote
        [0x3016] = "full_width_open", --〖   left double book quote
        [0x3018] = "full_width_open", --     left tortoise bracket
        [0x301A] = "full_width_open", --     left square bracket
        [0x301D] = "full_width_open", --     reverse double prime qm
        [0xFF08] = "full_width_open", -- （   left parenthesis
        [0xFF3B] = "full_width_open", -- ［   left square brackets
        [0xFF5B] = "full_width_open", -- ｛   left curve bracket
        [0xFF62] = "full_width_open", --     left corner bracket
        --
        -- half width closing parenthesis
        [0x0029] = "half_width_close",
        [0x005D] = "half_width_close",
        [0x007D] = "half_width_close",
        [0x2019] = "half_width_close", -- ’   right quote, right
        [0x201D] = "half_width_close", -- ”   right double quote
        --
        -- full width closing parenthesis
        --
        [0x3009] = "full_width_close", -- 〉   book quote
        [0x300B] = "full_width_close", -- 》   double book quote
        [0x300D] = "full_width_close", -- 」   right quote, right
        [0x300F] = "full_width_close", -- 』   right double quote
        [0x3011] = "full_width_close", -- 】   right double book quote
        [0x3015] = "full_width_close", -- 〕   right book quote
        [0x3017] = "full_width_close", -- 〗  right double book quote
        [0x3019] = "full_width_close", --     right tortoise bracket
        [0x301B] = "full_width_close", --     right square bracket
        [0x301E] = "full_width_close", --     double prime qm
        [0x301F] = "full_width_close", --     low double prime qm
        [0xFF09] = "full_width_close", -- ）   right parenthesis
        [0xFF3D] = "full_width_close", -- ］   right square brackets
        [0xFF5D] = "full_width_close", -- ｝   right curve brackets
        [0xFF63] = "full_width_close", --     right corner bracket
        --
        -- vertical opening vertical
        --
        -- 0xFE35, 0xFE37, 0xFE39,  0xFE3B,  0xFE3D,  0xFE3F,  0xFE41,  0xFE43,  0xFE47,
        --
        -- vertical closing
        --
        -- 0xFE36, 0xFE38, 0xFE3A,  0xFE3C,  0xFE3E,  0xFE40,  0xFE42,  0xFE44,  0xFE48,
        --
        -- half width opening punctuation
        --
        -- <empty>
        --
        -- full width opening punctuation
        --
        --  0x2236, -- ∶
        --  0xFF0C, -- ，
        --
        -- half width closing punctuation_hw
        --
        [0x0021] = "half_width_close", -- !
        [0x002C] = "half_width_close", -- ,
        [0x002E] = "half_width_close", -- .
        [0x003A] = "half_width_close", -- :
        [0x003B] = "half_width_close", -- ;
        [0x003F] = "half_width_close", -- ?
        [0xFF61] = "half_width_close", -- hw full stop
        --
        -- full width closing punctuation
        [0x3001] = "full_width_close", -- 、
        [0x3002] = "full_width_close", -- 。
        [0xFF01] = "full_width_close", -- ！
        [0xFF0C] = "full_width_close", -- ，
        [0xFF0E] = "full_width_close", -- ．
        [0xFF1A] = "full_width_close", -- ：
        [0xFF1B] = "full_width_close", -- ；
        [0xFF1F] = "full_width_close", -- ？
        --
        -- non starter
        --
        [0x3005] = "non_starter", [0x3041] = "non_starter", [0x3043] = "non_starter", [0x3045] = "non_starter", [0x3047] = "non_starter",
        [0x3049] = "non_starter", [0x3063] = "non_starter", [0x3083] = "non_starter", [0x3085] = "non_starter", [0x3087] = "non_starter",
        [0x308E] = "non_starter", [0x3095] = "non_starter", [0x3096] = "non_starter", [0x309B] = "non_starter", [0x309C] = "non_starter",
        [0x309D] = "non_starter", [0x309E] = "non_starter", [0x30A0] = "non_starter", [0x30A1] = "non_starter", [0x30A3] = "non_starter",
        [0x30A5] = "non_starter", [0x30A7] = "non_starter", [0x30A9] = "non_starter", [0x30C3] = "non_starter", [0x30E3] = "non_starter",
        [0x30E5] = "non_starter", [0x30E7] = "non_starter", [0x30EE] = "non_starter", [0x30F5] = "non_starter", [0x30F6] = "non_starter",
        [0x30FC] = "non_starter", [0x30FD] = "non_starter", [0x30FE] = "non_starter", [0x31F0] = "non_starter", [0x31F1] = "non_starter",
        [0x30F2] = "non_starter", [0x30F3] = "non_starter", [0x30F4] = "non_starter", [0x31F5] = "non_starter", [0x31F6] = "non_starter",
        [0x30F7] = "non_starter", [0x30F8] = "non_starter", [0x30F9] = "non_starter", [0x31FA] = "non_starter", [0x31FB] = "non_starter",
        [0x30FC] = "non_starter", [0x30FD] = "non_starter", [0x30FE] = "non_starter", [0x31FF] = "non_starter",
        --
        -- hyphenation
        --
        [0x2026] = "hyphen", -- …   ellipsis
        [0x2014] = "hyphen", -- —   hyphen
    }

    for i=0x03040,0x0309F do if not hash[i] then hash[i] = "chinese"      end end
    for i=0x030A0,0x030FF do if not hash[i] then hash[i] = "chinese"      end end
    for i=0x031F0,0x031FF do if not hash[i] then hash[i] = "chinese"      end end
    for i=0x03400,0x04DFF do if not hash[i] then hash[i] = "chinese"      end end
    for i=0x04E00,0x09FFF do if not hash[i] then hash[i] = "chinese"      end end
    for i=0x0F900,0x0FAFF do if not hash[i] then hash[i] = "chinese"      end end
    for i=0x0FF00,0x0FFEF do if not hash[i] then hash[i] = "chinese"      end end
    for i=0x20000,0x2A6DF do if not hash[i] then hash[i] = "chinese"      end end
    for i=0x2F800,0x2FA1F do if not hash[i] then hash[i] = "chinese"      end end
    for i=0x0AC00,0x0D7A3 do if not hash[i] then hash[i] = "korean"       end end
    for i=0x01100,0x0115F do if not hash[i] then hash[i] = "jamo_initial" end end
    for i=0x01160,0x011A7 do if not hash[i] then hash[i] = "jamo_medial"  end end
    for i=0x011A8,0x011FF do if not hash[i] then hash[i] = "jamo_final"   end end

--  for i=0x03041,0x030FF do if not hash[i] then hash[i] = "japanese"     end end

    for i=0x01200,0x0139F do hash[i] = "ethiopic_syllable" end


    hash[0x01361] = "ethiopic_word"
    hash[0x01362] = "ethiopic_sentence"

    scripts.hash = hash

end

local numbertodataset = allocate()
local numbertohandler = allocate()

--~ storage.register("scripts/hash", hash, "scripts.hash")

scripts.numbertodataset = numbertodataset

function scripts.installmethod(handler)
    local name = handler.name
    handlers[name] = handler
    local attributes = { }
    local datasets = handler.datasets
    if not datasets or not datasets.default then
        report_preprocessing("missing (default) dataset in script '%s'",name)
    end
    setmetatable(attributes, {
        __index = function(t,k)
            local v = datasets[k] or datasets.default
            local a = unsetvalue
            if v then
                v.name = name -- for tracing
                a = #numbertodataset + 1
                numbertodataset[a] = v
                numbertohandler[a] = handler
            end
            t[k] = a
            return a
        end
    } )
    handler.attributes = attributes
end

function scripts.installdataset(specification) -- global overload
    local method  = specification.method
    local name    = specification.name
    local dataset = specification.dataset
    if method and name and dataset then
        local parent  = specification.parent or ""
        local handler = handlers[method]
        if handler then
            local datasets = handler.datasets
            if datasets then
                local defaultset = datasets.default
                if defaultset then
                    if parent ~= "" then
                        local p = datasets[parent]
                        if p then
                            defaultset = p
                        else
                            report_preprocessing("dataset, unknown parent '%s' for method '%s'",parent,method)
                        end
                    end
                    setmetatable(dataset,defaultset)
                    local existing = datasets[name]
                    if existing then
                        for k, v in next, existing do
                            existing[k] = dataset
                        end
                    else
                        datasets[name] = dataset
                    end
                else
                    report_preprocessing("dataset, no default for method '%s'",method)
                end
            else
                report_preprocessing("dataset, no datasets for method '%s'",method)
            end
        else
            report_preprocessing("dataset, no method '%s'",method)
        end
    else
        report_preprocessing("dataset, invalid specification") -- maybe report table
    end
end

function scripts.set(name,method,preset)
    local handler = handlers[method]
    texsetattribute(a_preproc,handler and handler.attributes[preset] or unsetvalue)
end

function scripts.reset()
    texsetattribute(handler.attributes[preset])
end

-- the following tables will become a proper installer (move to cjk/eth)

local scriptcolors = allocate {  -- todo: just named colors
    korean            = "trace:0",
    chinese           = "trace:0",
    full_width_open   = "trace:1",
    full_width_close  = "trace:2",
    half_width_open   = "trace:3",
    half_width_close  = "trace:4",
    hyphen            = "trace:5",
    non_starter       = "trace:6",
    jamo_initial      = "trace:7",
    jamo_medial       = "trace:8",
    jamo_final        = "trace:9",
    ethiopic_syllable = "trace:1",
    ethiopic_word     = "trace:2",
    ethiopic_sentence = "trace:3",
}

scripts.colors = scriptcolors

local numbertocategory = allocate { -- rather bound to cjk ... will be generalized
    "korean",
    "chinese",
    "full_width_open",
    "full_width_close",
    "half_width_open",
    "half_width_close",
    "hyphen",
    "non_starter",
    "jamo_initial",
    "jamo_medial",
    "jamo_final",
    "ethiopic_syllable",
    "ethiopic_word",
    "ethiopic_sentence",
}

local categorytonumber = allocate(table.swapped(numbertocategory)) -- could be one table

scripts.categorytonumber = categorytonumber
scripts.numbertocategory = numbertocategory

local function colorize(start,stop)
    for n in traverse_id(glyph_code,start) do
        local kind = numbertocategory[has_attribute(n,a_prestat)]
        if kind then
            local ac = scriptcolors[kind]
            if ac then
                setnodecolor(n,ac)
            end
        end
        if n == stop then
            break
        end
    end
end

local function traced_process(head,first,last,process,a)
    if start ~= last then
        local f, l = first, last
        local name = numbertodataset[a]
        name = name and name.name or "?"
        report_preprocessing("before %s: %s",name,nodes.tosequence(f,l))
        process(head,first,last)
        report_preprocessing("after %s: %s", name,nodes.tosequence(f,l))
    end
end

-- eventually we might end up with more extensive parsing
-- todo: pass t[start..stop] == original
--
-- one of the time consuming functions:

-- we can have a fonts.hashes.originals

function scripts.preprocess(head)
    local start = first_glyph(head)
    if not start then
        return head, false
    else
        local last_a, normal_process, lastfont, originals = nil, nil, nil, nil
        local done, first, last, ok = false, nil, nil, false
        while start do
            local id = start.id
            if id == glyph_code then
                local a = has_attribute(start,a_preproc)
                if a then
                    if a ~= last_a then
                        if first then
                            if ok then
                                if trace_analyzing then
                                    colorize(first,last)
                                end
                                if trace_injections then
                                    traced_process(head,first,last,normal_process,last_a)
                                else
                                    normal_process(head,first,last)
                                end
                                ok, done = false, true
                            end
                            first, last = nil, nil
                        end
                        last_a = a
                        local handler = numbertohandler[a]
                        normal_process = handler.process
                    end
                    if normal_process then
                        local f = start.font
                        if f ~= lastfont then
                            originals = fontdata[f].resources
                            if resources then
                                originals = resources.originals
                            else
                                -- can't happen
                            end
                            lastfont = f
                        end
                        local c = start.char
                        if originals then
                            c = originals[c] or c
                        end
                        local h = hash[c]
                        if h then
                            set_attribute(start,a_prestat,categorytonumber[h])
                            if not first then
                                first, last = start, start
                            else
                                last = start
                            end
                        --    if cjk == "chinese" or cjk == "korean" then -- we need to prevent too much ( ) processing
                                ok = true
                        --    end
                        elseif first then
                            if ok then
                                if trace_analyzing then
                                    colorize(first,last)
                                end
                                if trace_injections then
                                    traced_process(head,first,last,normal_process,last_a)
                                else
                                    normal_process(head,first,last)
                                end
                                ok, done = false, true
                            end
                            first, last = nil, nil
                        end
                    end
                elseif first then
                    if ok then
                        if trace_analyzing then
                            colorize(first,last)
                        end
                        if trace_injections then
                            traced_process(head,first,last,normal_process,last_a)
                        else
                            normal_process(head,first,last)
                        end
                        ok, done = false, true
                    end
                    first, last = nil, nil
                end
            elseif id == glue_code then
                if ok then
                    -- continue
                elseif first then
                    -- no chinese or korean
                    first, last = nil, nil
                end
            elseif first then
                if ok then
                    -- some chinese or korean
                    if trace_analyzing then
                        colorize(first,last)
                    end
                    if trace_injections then
                        traced_process(head,first,last,normal_process,last_a)
                    else
                        normal_process(head,first,last)
                    end
                    first, last, ok, done = nil, nil, false, true
                elseif first then
                    first, last = nil, nil
                end
            end
            start = start.next
        end
        if ok then
            if trace_analyzing then
                colorize(first,last)
            end
            if trace_injections then
                traced_process(head,first,last,normal_process,last_a)
            else
                normal_process(head,first,last)
            end
            done = true
        end
        return head, done
    end
end

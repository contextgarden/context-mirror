if not modules then modules = { } end modules ['lang-ini'] = {
    version   = 1.001,
    comment   = "companion to lang-ini.tex",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

languages           = languages or { }
languages.patterns  = languages.patterns or { }
languages.version   = 1.009
languages.template  = "words-%s.txt"
languages.number    = nil
languages.current   = nil
languages.attribute = nil

-- We used to have one list: data[word] = pattern but that overflowed lua's function
-- mechanism. Then we split the lists and again we had oveflows. So eventually we
-- ended up with a dedicated reader.
--
-- function languages.set(attribute,number,name)
--     if not languages.patterns[number] then
--         languages.patterns[number] = containers.define("languages","patterns", languages.version, true)
--     end
--     input.start_timing(languages)
--     local data = containers.read(languages.patterns[number],name)
--     if not data then
--         data = { }
--         local fullname = string.format(languages.template,name)
--         local foundname = input.find_file(texmf.instance,fullname,'other text file')
--         if foundname and foundname ~= "" then
--             local ok, blob, size = input.loadbinfile(texmf.instance,foundname)
--             for word in utf.gfind(blob,"(.-)[%s]+") do
--                 local key = word:gsub("-","")
--                 if key == word then
--                     -- skip
--                 else
--                     data[word:gsub("-","")] = word
--                 end
--             end
--         end
--         data = containers.write(languages.patterns[number],name,data)
--     end
--     input.stop_timing(languages)
--     languages.attribute = attribute
--     languages.number    = number
--     languages.current   = data
-- end

function languages.set(attribute,number,name)
    if not languages.patterns[number] then
        input.start_timing(languages)
        local fullname = string.format(languages.template,name)
        local foundname = input.find_file(texmf.instance,fullname,'other text file')
        if foundname and foundname ~= "" then
        --  texio.write_nl(string.format("loading patterns for language %s as %s from %s",name,number,foundname))
            languages.patterns[number] = tex.load_dict(foundname) or { }
        else
            languages.patterns[number] = { }
        end
        input.stop_timing(languages)
    end
    languages.attribute = attribute
    languages.number    = number
    languages.current   = languages.patterns[number]
end

function languages.add(word,pattern)
    if languages.current and word and pattern then
        languages.current[word] = pattern
    end
end

function languages.remove(word)
    if languages.current and word then
        languages.current[word] = nil
    end
end

function languages.hyphenate(str)
    if languages.current then
        local result = languages.current[str]
        if result then
            return result
        else
            -- todo: be clever
        end
    end
    return str
end

function languages.found(number, str)
    local patterns = languages.patterns[number]
    return patterns and patterns[str]
end

do

    local discnode = node.new('disc')

    discnode.pre = node.new('glyph')
    discnode.pre.subtype = 0
    discnode.pre.char = 45 -- will be configurable
    discnode.pre.font = 0

    local glyph, disc, kern = node.id('glyph'), node.id('disc'), node.id('kern')

    local bynode = node.traverse
    local bychar = string.utfcharacters

    local function reconstruct(prev,str,fnt)
        local done = false
        if #str < 4 then
            -- too short
        else
            local wrd = languages.hyphenate(str)
            if wrd == str then
                -- not found
            else
                local pre, post, after, comp = nil, nil, false, nil
                for chr in bychar(wrd) do
                    if prev then
                        if not comp and prev.next and prev.next.subtype > 0 then
                            comp = prev.next.components
                            pre = node.copy(comp)
                            comp = comp.next
                            post, after = nil, false
                        elseif chr == '-' then
                            if not comp then
                                done = true
                                local n = node.copy(discnode)
                                n.pre.font = fnt.font
                                n.pre.attr = fnt.attr
                                if pre then
                                    pre.next = n.pre
                                    n.pre = pre
                                    pre, pos, after = nil, nil, false
                                end
                                n.next = prev.next
                                prev.next = n
                                prev = n
                            else
                                after = true
                            end
                        elseif comp then
                            local g = node.copy(comp)
                            comp = comp.next
                            if after then
                                if post then post.next = g else post = g end
                            else
                                if pre then pre.next = g else pre = g end
                            end
                            if not comp then
                                done = true
                                local n = node.copy(discnode)
                                n.pre.font = fnt.font
                                n.pre.attr = fnt.attr
                                pre.next = n.pre
                                n.pre = pre
                                n.post = post
                                n.replace = 1
                                n.next = prev.next
                                prev.next = n
                                prev = n
                                pre, pos, after = nil, nil, false
                                prev = prev.next -- hm, now we get error 1
                            end
                        else
                            prev = prev.next
                        end
                    else
                    --  print("ERROR 1")
                    end
                end
            end
        end
        return done
    end

    function nodes.hyphenate_words(head) -- we forget about the very first, no head stuff here
        local cd = characters.data
        local uc = utf.char
        local n, p = head, nil
        local done, prev, str, fnt, lan = false, false, "", nil, nil
        local currentlanguage = languages.current
        local att = languages.attribute
        local function action() -- maybe inline
            if reconstruct(prev,str,fnt) then
                done = true
            end
            str, prev = "", false
        end
        while n do
            local id = n.id
            if id == glyph then
                local l = node.has_attribute(n,att)
                if l then
                    if l ~= lan then
                        if prev then action() end
                        lan = l
                        languages.current = languages.patterns[lan]
                    end
                elseif prev then
                    action()
                end
                if not languages.current then
                    -- skip
                elseif n.subtype > 0 then
                    if not prev then
                        prev, fnt = p, n
                    end
                    for g in bynode(n.components) do
                        str = str .. uc(g.char)
                    end
                else
                    local code = n.char
                    if cd[code].lccode then
                        if not prev then
                            prev, fnt = p, n
                        end
                        str = str .. uc(code)
                    elseif prev then
                        action()
                    end
                end
            elseif id == kern and n.subtype == 0 and p then
                p.next = n.next
                node.free(p,n)
                n = p
            elseif prev then
                action()
            end
            p = n
            n = n.next
        end
        if prev then
            action()
        end
        languages.current = currentlanguage
        return head
    end

    function nodes.mark_words(head,attribute,found)
        local cd = characters.data
        local uc = utf.char
        local current, start, str, att, n = head, nil, "", nil, 0
        local function action()
            local f = found(att,str)
            if f then
                for i=1,n do
                    f(start)
                    start = start.next
                end
            end
            str, start, n = "", nil, 0
        end
        while current do
            local id = current.id
            if id == glyph then
                local a = node.has_attribute(current,attribute)
                if a then
                    if a ~= att then
                        if start then
                            action()
                        end
                        att = a
                    end
                elseif start then
                    action()
                    att = a
                end
                if current.subtype > 0 then
                    start = start or current
                    n = n + 1
                    for g in bynode(current.components) do
                        str = str .. uc(g.char)
                    end
                else
                    local code = current.char
                    if cd[code].lccode then
                        start = start or current
                        n = n + 1
                        str = str .. uc(code)
                    else
                        if start then
                            action()
                        end
                    end
                end
            elseif id == disc then
                -- ok
            elseif id == kern and current.subtype == 0 and start then
                -- ok
            elseif start then
                action()
            end
            current = current.next
        end
        if start then
            action()
        end
        return head
    end

    function languages.check(head, attribute, yes, nop)
        local set   = node.set_attribute
        local unset = node.unset_attribute
        local wrong, right = false, false
        if nop then wrong = function(n) set(n,attribute,nop) end end
        if yes then right = function(n) set(n,attribute,yes) end end
        for n in node.traverse(head) do
            unset(n,attribute)
        end
        nodes.mark_words(head, languages.attribute, function(att,str)
            if #str < 4 then
                return false
            elseif languages.found(att,str) then
                return right
            else
                return wrong
            end
        end)
        nodes.hyphenate_words(head)
        return head
    end

end

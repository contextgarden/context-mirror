if not modules then modules = { } end modules ['lang-ini'] = {
    version   = 1.001,
    comment   = "companion to lang-ini.tex",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

languages                  = languages or {}
languages.version          = 1.009

languages.hyphenation      = languages.hyphenation or {}
languages.hyphenation.data = languages.hyphenation.data or { }

do
    -- we can consider hiding data (faster access too)

    local function filter(filename,what)
        local data = io.loaddata(input.find_file(texmf.instance,filename))
        local start, stop = data:find(string.format("\\%s%%s*(%%b{})",what or "patterns"))
        return (start and stop and data:sub(start+1,stop-1)) or ""
    end

    local function record(tag)
        local data = languages.hyphenation.data[tag]
        if not data then
             data = lang.new()
             languages.hyphenation.data[tag] = data
        end
        return data
    end

    languages.hyphenation.record = record

    function languages.hyphenation.number(tag)
        local data = record(tag)
        return data:id()
    end

    function languages.hyphenation.load(tag, patterns, exceptions)
        input.starttiming(languages)
        local data = record(tag)
        patterns   = (patterns   and input.find_file(texmf.instance,patterns  )) or ""
        exceptions = (exceptions and input.find_file(texmf.instance,exceptions)) or ""
        if patterns ~= "" then
            data:patterns(filter(patterns,"patterns"))
        end
        if exceptions ~= "" then
            data:exceptions(string.split(filter(exceptions,"hyphenation"),"%s+"))
            --    local t = { }
            --    for s in string.gmatch(filter(exceptions,"hyphenation"), "(%S+)") do
            --        t[#t+1] = s
            --    end
            --    print(tag,#t)
            --    data:exceptions(t)
        end
        languages.hyphenation.data[tag] = data
        input.stoptiming(languages)
    end

    function languages.hyphenation.exceptions(tag, ...)
        local data = record(tag)
        data:exceptions(...)
    end

    function languages.hyphenation.hyphenate(tag, str)
        local data = record(tag)
        return data:hyphenate(str)
    end

    function languages.hyphenation.lefthyphenmin(tag, value)
        local data = record(tag)
        if value then data:lefthyphenmin(value) end
        return data:lefthyphenmin()
    end
    function languages.hyphenation.righthyphenmin(tag, value)
        local data = record(tag)
        if value then data:righthyphenmin(value) end
        return data:righthyphenmin()
    end

    function languages.n()
        return table.count(languages.hyphenation.data)
    end

end

-- beware, the collowing code has to be adapted, and was used in
-- experiments with loading lists of words; if we keep supporting
-- this, i will add a namespace; this will happen when the hyphenation
-- code is in place

languages.dictionary           = languages.dictionary or {}
languages.dictionary.data      = languages.dictionary.data or { }
languages.dictionary.template  = "words-%s.txt"
languages.dictionary.patterns  = languages.dictionary.patterns or { }

-- maybe not in dictionary namespace

languages.dictionary.current   = nil
languages.dictionary.number    = nil
languages.dictionary.attribute = nil

function languages.dictionary.set(attribute,number,name)
    if not languages.dictionary.patterns[number] then
        input.start_timing(languages)
        local fullname = string.format(languages.dictionary.template,name)
        local foundname = input.find_file(texmf.instance,fullname,'other text file')
        if foundname and foundname ~= "" then
        --  texio.write_nl(string.format("loading patterns for language %s as %s from %s",name,number,foundname))
            languages.dictionary.patterns[number] = tex.load_dict(foundname) or { }
        else
            languages.dictionary.patterns[number] = { }
        end
        input.stop_timing(languages)
    end
    languages.dictionary.attribute = attribute
    languages.dictionary.number    = number
    languages.dictionary.current   = languages.dictionary.patterns[number]
end

function languages.dictionary.add(word,pattern)
    if languages.dictionary.current and word and pattern then
        languages.dictionary.current[word] = pattern
    end
end

function languages.dictionary.remove(word)
    if languages.dictionary.current and word then
        languages.dictionary.current[word] = nil
    end
end

function languages.dictionary.hyphenate(str)
    if languages.dictionary.current then
        local result = languages.dictionary.current[str]
        if result then
            return result
        else
            -- todo: be clever
        end
    end
    return str
end

function languages.dictionary.found(number, str)
    local patterns = languages.dictionary.patterns[number]
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
            local wrd = languages.dictionary.hyphenate(str)
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
        local currentlanguage = languages.dictionary.current
        local att, patterns = languages.dictionary.attribute, languages.dictionary.patterns
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
                        languages.dictionary.current = patterns[lan]
                    end
                elseif prev then
                    action()
                end
                if not languages.dictionary.current then
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
        languages.dictionary.current = currentlanguage
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
        local has_attribute = node.has_attribute
        while current do
            local id = current.id
            if id == glyph then
                local a = has_attribute(current,attribute)
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

    function languages.dictionary.check(head, attribute, yes, nop)
        local set   = node.set_attribute
        local unset = node.unset_attribute
        local wrong, right = false, false
        if nop then wrong = function(n) set(n,attribute,nop) end end
        if yes then right = function(n) set(n,attribute,yes) end end
        for n in node.traverse(head) do
            unset(n,attribute)
        end
        local found = languages.dictionary.found
        nodes.mark_words(head, languages.dictionary.attribute, function(att,str)
            if #str < 4 then
                return false
            elseif found(att,str) then
                return right
            else
                return wrong
            end
        end)
        nodes.hyphenate_words(head)
        return head
    end

end

languages.set       = languages.dictionary.set
languages.add       = languages.dictionary.add
languages.remove    = languages.dictionary.remove
languages.hyphenate = languages.dictionary.hyphenate
languages.found     = languages.dictionary.found
languages.check     = languages.dictionary.check

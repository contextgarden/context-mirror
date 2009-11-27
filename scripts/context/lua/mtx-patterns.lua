if not modules then modules = { } end modules ['mtx-patterns'] = {
    version   = 1.001,
    comment   = "companion to mtxrun.lua",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local format = string.format

scripts          = scripts          or { }
scripts.patterns = scripts.patterns or { }

scripts.patterns.list = {
    { "??",  "hyph-ar.tex",            "arabic" },
    { "bg",  "hyph-bg.tex",            "bulgarian" },
--  { "ca",  "hyph-ca.tex",            "" },
    { "??",  "hyph-cop.tex",           "coptic" },
    { "cs",  "hyph-cs.tex",            "czech" },
    { "??",  "hyph-cy.tex",            "welsh" },
    { "da",  "hyph-da.tex",            "danish" },
    { "deo", "hyph-de-1901.tex",       "german, old spelling" },
    { "de",  "hyph-de-1996.tex",       "german, new spelling" },
--~ { "??",  "hyph-el-monoton.tex",    "" },
--~ { "??",  "hyph-el-polyton.tex",    "" },
--~ { "agr", "hyph-grc",               "ancient greek" },
--~ { "???", "hyph-x-ibycus",          "ancient greek in ibycus encoding" },
--~ { "gr",  "",                       "" },
    { "??",  "hyph-eo.tex",            "esperanto" },
    { "gb",  "hyph-en-gb.tex",         "british english" },
    { "us",  "hyph-en-us.tex",	       "american english" },
    { "es",  "hyph-es.tex",            "spanish" },
    { "et",  "hyph-et.tex",            "estonian" },
    { "eu",  "hyph-eu.tex",            "basque" }, -- ba is Bashkir!
    { "??",  "hyph-fa.tex",            "farsi" },
    { "fi",  "hyph-fi.tex",            "finnish" },
    { "fr",  "hyph-fr.tex",            "french" },
--  { "??",  "hyph-ga.tex",            "" },
--  { "??",  "hyph-gl.tex",            "" },
--  { "??",  "hyph-grc.tex",           "" },
    { "hr",  "hyph-hr.tex",            "croatian" },
    { "??",  "hyph-hsb.tex",           "upper sorbian" },
    { "hu",  "hyph-hu.tex",            "hungarian" },
    { "??",  "hyph-ia.tex",            "interlingua" },
    { "??",  "hyph-id.tex",            "indonesian" },
    { "??",  "hyph-is.tex",            "icelandic" },
    { "it",  "hyph-it.tex",            "italian" },
    { "la",  "hyph-la.tex",            "latin" },
    { "??",  "hyph-mn-cyrl.tex",       "mongolian, cyrillic script" },
    { "??",  "hyph-mn-cyrl-x-new.tex", "mongolian, cyrillic script (new patterns)" },
    { "nb",  "hyph-nb.tex",            "norwegian bokmål" },
    { "nl",  "hyph-nl.tex",            "dutch" },
    { "nn",  "hyph-nn.tex",            "norwegian nynorsk" },
    { "pl",  "hyph-pl.tex",            "polish" },
    { "pt",  "hyph-pt.tex",            "portuguese" },
    { "ro",  "hyph-ro.tex",            "romanian" },
    { "ru",  "hyph-ru.tex",            "russian" },
    { "sk",  "hyph-sk.tex",            "" },
    { "sl",  "hyph-sl.tex",            "slovenian" },
    { "??",  "hyph-sr-cyrl.tex",       "serbian" },
    { "sv",  "hyph-sv.tex",            "swedish" },
    { "tr",  "hyph-tr.tex",            "turkish" },
    { "uk",  "hyph-uk.tex",            "ukrainian" },
    { "??",  "hyph-zh-latn.tex",       "zh-latn, chinese Pinyin" },
}


-- stripped down from lpeg example:

local utf = unicode.utf8

local cont = lpeg.R("\128\191")   -- continuation byte

local utf8 = lpeg.R("\0\127")
           + lpeg.R("\194\223") * cont
           + lpeg.R("\224\239") * cont * cont
           + lpeg.R("\240\244") * cont * cont * cont

local validutf = (utf8^0/function() return true end) * (lpeg.P(-1)/function() return false end)

function utf.check(str)
    return lpeg.match(validutf,str)
end

local permitted_commands = table.tohash {
    "message",
    "endinput"
}

local permitted_characters = table.tohash {
    0x0009, -- tab
    0x0027, -- apostrofe
    0x002D, -- hyphen
    0x200C, --
}

function scripts.patterns.load(path,name,mnemonic,fullcheck)
    local fullname = file.join(path,name)
    local data = io.loaddata(fullname) or ""
    local byte, char = utf.byte, utf.char
    if data ~= "" then
        data = data:gsub("([\n\r])\\input ([^ \n\r]+)", function(previous,subname)
            local subname = file.addsuffix(subname,"tex")
            local subfull = file.join(file.dirname(fullname),subname)
            local subdata = io.loaddata(subfull) or ""
            if subdata == "" then
                if mnemonic then
                    logs.simple("no subfile %s for language %s",subname,mnemonic)
                else
                    logs.simple("no subfile %s",name)
                end
            end
            return previous .. subdata
        end)
        local comment = data:match("^(.-)[\n\r]\\patterns") or ""
        local n, okay = 0, true
        local cd = characters.data
        for line in data:gmatch("[^ \n\r]+") do
            local ok = utf.check(line)
            n = n + 1
            if not ok then
                okay = false
                line = line:gsub("%%","%%%%")
                if fullcheck then
                    if mnemonic then
                        logs.simple("invalid utf in language %s, file %s, line %s: %s",mnemonic,name,n,line)
                    else
                        logs.simple("invalid utf in file %s, line %s: %s",name,n,line)
                    end
                else
                    if mnemonic then
                        logs.simple("file %s for %s contains invalid utf",name,mnemonic)
                    else
                        logs.simple("file %s contains invalid utf",name)
                    end
                    break
                end
            end
        end
        local c, h = { }, { }
        for line in data:gmatch("[^\n\r]+") do
            local txt, cmt = line:match("^(.-)%%(.*)$")
            if not txt then
                txt, cmt = line, ""
            end
            for s in txt:gmatch("\\([a-zA-Z]+)") do
                h[s] = (h[s] or 0) + 1
            end
            for s in cmt:gmatch("\\([a-zA-Z]+)") do
                c[s] = (c[s] or 0) + 1
            end
        end
        h.patterns = nil
        h.hyphenation = nil
        for k, v in pairs(h) do
            if not permitted_commands[k] then okay = false end
            if mnemonic then
                logs.simple("command \\%s found in language %s, file %s, n=%s",k,mnemonic,name,v)
            else
                logs.simple("command \\%s found in file %s, n=%s",k,name,v)
            end
        end
        if not environment.argument("fast") then
            for k, v in pairs(c) do
                if mnemonic then
                    logs.simple("command \\%s found in comment of language %s, file %s, n=%s",k,mnemonic,name,v)
                else
                    logs.simple("command \\%s found in comment of file %s, n=%s",k,name,v)
                end
            end
        end
        data = data:gsub("%%.-[\n\r]","")
        data = data:gsub(" *[\n\r]+","\n")
        local patterns = data:match("\\patterns[%s]*{[%s]*(.-)[%s]*}") or ""
        local hyphenations = data:match("\\hyphenation[%s]*{[%s]*(.-)[%s]*}") or ""
        patterns = patterns:gsub(" +","\n")
        hyphenations = hyphenations:gsub(" +","\n")
        local p, h = { }, { }
        local pats, hyps = { } , { }
        local pused, hused = { } , { }
        local period = byte(".")
        for line in patterns:gmatch("[^ \n\r]+") do
            local ok = true
            for b in line:utfvalues() do
                if b == period then
                    -- ok
                else
                    local ct = cd[b].category
                    if ct == "lu" or ct == "ll" then
                        pused[char(b)] = true
                    elseif ct == "nd" then
                        -- ok
                    else
                        p[b] = (p[b] or 0) + 1
                        ok = false
                    end
                end
            end
            if ok then
                pats[#pats+1] = line
            end
        end
        local hyphen = byte("-")
        for line in hyphenations:gmatch("[^ \n\r]+") do
            local ok = true
            for b in line:utfvalues() do
                if b == hyphen then
                    -- ok
                else
                    local ct = cd[b].category
                    if ct == "lu" or ct == "ll" then
                        hused[char(b)] = true
                    else
                        h[b] = (h[b] or 0) + 1
                        ok = false
                    end
                end
            end
            if ok then
                hyps[#hyps+1] = line
            end
        end
        local stripped = { }
        for k, v in pairs(p) do
            if mnemonic then
                logs.simple("invalid character %s (0x%04X) in patterns of language %s, file %s, n=%s",char(k),k,mnemonic,name,v)
            else
                logs.simple("invalid character %s (0x%04X) in patterns of file %s, n=%s",char(k),k,name,v)
            end
            if not permitted_characters[k] then
                okay = false
            else
                stripped[k] = true
            end
        end
        for k, v in pairs(h) do
            if mnemonic then
                logs.simple("invalid character %s (0x%04X) in exceptions of language %s, file %s, n=%s",char(k),k,mnemonic,name,v)
            else
                logs.simple("invalid character %s (0x%04X) in exceptions of file %s, n=%s",char(k),k,name,v)
            end
            if not permitted_characters[k] then
                okay = false
            else
                stripped[k] = true
            end
        end
        local stripset = ""
        for k, v in pairs(stripped) do
            logs.simple("entries that contain character %s will be omitted",char(k))
            stripset = stripset .. "%" .. char(k)
        end
        return okay, pats, hyps, comment, stripset, pused, hused
    else
        if mnemonic then
            logs.simple("no file %s for language %s",fullname,mnemonic)
        else
            logs.simple("no file %s",fullname)
        end
        return false, { }, { }, "", "", { }, { }
    end
end

function scripts.patterns.save(destination,mnemonic,patterns,hyphenations,comment,stripped,pused,hused)
    local nofpatterns = #patterns
    local nofhyphenations = #hyphenations
    local pu = table.concat(table.sortedkeys(pused), " ")
    local hu = table.concat(table.sortedkeys(hused), " ")
    logs.simple("language %s has %s patterns and %s exceptions",mnemonic,nofpatterns,nofhyphenations)
    if mnemonic ~= "??" then
        local rmefile = file.join(destination,"lang-"..mnemonic..".rme")
        local patfile = file.join(destination,"lang-"..mnemonic..".pat")
        local hypfile = file.join(destination,"lang-"..mnemonic..".hyp")
        local topline = "% generated by mtxrun --script pattern --convert"
        local banner = "% for comment and copyright, see " .. rmefile
        logs.simple("saving language data for %s",mnemonic)
        if not comment or comment == "" then comment = "% no comment" end
        if not type(destination) == "string" then destination = "." end
        os.remove(rmefile)
        os.remove(patfile)
        os.remove(hypfile)
        io.savedata(rmefile,format("%s\n\n%s",topline,comment))
        io.savedata(patfile,format("%s\n\n%s\n\n%% used: %s\n\n\\patterns{\n%s}",topline,banner,pu,table.concat(patterns,"\n")))
        io.savedata(hypfile,format("%s\n\n%s\n\n%% used: %s\n\n\\hyphenation{\n%s}",topline,banner,hu,table.concat(hyphenations,"\n")))
    end
end

function scripts.patterns.prepare()
    dofile(resolvers.find_file("char-def.lua"))
end

function scripts.patterns.check()
    local path = environment.argument("path") or "."
    local found = false
    if #environment.files > 0 then
        for _, name in ipairs(environment.files) do
            logs.simple("checking language file %s", name)
            local okay = scripts.patterns.load(path,name,nil,not environment.argument("fast"))
            if #environment.files > 1 then
                logs.simple("")
            end
        end
    else
        for k, v in pairs(scripts.patterns.list) do
            local mnemonic, name = v[1], v[2]
            logs.simple("checking language %s, file %s", mnemonic, name)
            local okay = scripts.patterns.load(path,name,mnemonic,not environment.argument("fast"))
            if not okay then
                logs.simple("there are errors that need to be fixed")
            end
            logs.simple("")
        end
    end
end

function scripts.patterns.convert()
    local path = environment.argument("path") or "."
    if path == "" then
        logs.simple("provide sourcepath using --path ")
    else
        local destination = environment.argument("destination") or "."
        if path == destination then
            logs.simple("source path and destination path should differ (use --path and/or --destination)")
        else
            for k, v in pairs(scripts.patterns.list) do
                local mnemonic, name = v[1], v[2]
                logs.simple("converting language %s, file %s", mnemonic, name)
                local okay, patterns, hyphenations, comment, stripped, pused, hused = scripts.patterns.load(path,name,false)
                if okay then
                    scripts.patterns.save(destination,mnemonic,patterns,hyphenations,comment,stripped,pused,hused)
                else
                    logs.simple("convertion aborted due to error(s)")
                end
                logs.simple("")
            end
        end
    end
end

logs.extendbanner("ConTeXt Pattern File Management 0.20",true)

messages.help = [[
--convert             generate context language files (mnemonic driven, if not given then all)
--check               check pattern file (or those used by context when no file given)

--fast                only report filenames, no lines
]]

if environment.argument("check") then
    scripts.patterns.prepare()
    scripts.patterns.check()
elseif environment.argument("convert") then
    scripts.patterns.prepare()
    scripts.patterns.convert()
else
    logs.help(messages.help)
end

-- mtxrun --script pattern --check hyph-*.tex
-- mtxrun --script pattern --check          --path=c:/data/develop/svn-hyphen/trunk/hyph-utf8/tex/generic/hyph-utf8/patterns
-- mtxrun --script pattern --check   --fast --path=c:/data/develop/svn-hyphen/trunk/hyph-utf8/tex/generic/hyph-utf8/patterns
-- mtxrun --script pattern --convert        --path=c:/data/develop/svn-hyphen/trunk/hyph-utf8/tex/generic/hyph-utf8/patterns --destination=e:/tmp/patterns

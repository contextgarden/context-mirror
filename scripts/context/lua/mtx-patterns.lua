if not modules then modules = { } end modules ['mtx-patterns'] = {
    version   = 1.001,
    comment   = "companion to mtxrun.lua",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local format, find, concat = string.format, string.find, table.concat

scripts          = scripts          or { }
scripts.patterns = scripts.patterns or { }

scripts.patterns.list = {
    -- no patterns for arabic
--  { "ar",  "hyph-ar.tex",            "arabic" },
    -- not supported
--  { "as",  "hyph-as.tex",            "assamese" },
    { "bg",  "hyph-bg.tex",            "bulgarian" },
    -- not supported
--  { "bn",  "hyph-bn.tex",            "bengali" },
    { "ca",  "hyph-ca.tex",            "catalan" },
    -- not supported
--  { "cop", "hyph-cop.tex",           "coptic" },
    { "cs",  "hyph-cs.tex",            "czech" },
    { "cy",  "hyph-cy.tex",            "welsh" },
    { "da",  "hyph-da.tex",            "danish" },
    { "deo", "hyph-de-1901.tex",       "german, old spelling" },
    { "de",  "hyph-de-1996.tex",       "german, new spelling" },
    { "??",  "hyph-de-ch-1901.tex",    "swiss german" },
--~ { "??",  "hyph-el-monoton.tex",    "" },
--~ { "??",  "hyph-el-polyton.tex",    "" },
    { "agr", "hyph-grc.tex",           "ancient greek" },
    { "gb",  "hyph-en-gb.tex",         "british english" },
    { "us",  "hyph-en-us.tex",	       "american english" },
--~ { "gr",  "",                       "" },
    -- these patterns do not satisfy the rules of 'clean patterns'
--  { "eo",  "hyph-eo.tex",            "esperanto" },
    { "es",  "hyph-es.tex",            "spanish" },
    { "et",  "hyph-et.tex",            "estonian" },
    { "eu",  "hyph-eu.tex",            "basque" },
    -- no patterns for farsi/persian
--  { "fa",  "hyph-fa.tex",            "farsi" },
    { "fi",  "hyph-fi.tex",            "finnish" },
    { "fr",  "hyph-fr.tex",            "french" },
    { "??",  "hyph-ga.tex",            "irish" },
    { "??",  "hyph-gl.tex",            "galician" },
    -- not supported
--  { "gu",  "hyph-gu.tex",            "gujarati" },
    -- not supported
--  { "hi",  "hyph-hi.tex",            "hindi" },
    { "hr",  "hyph-hr.tex",            "croatian" },
    { "??",  "hyph-hsb.tex",           "upper sorbian" },
    { "hu",  "hyph-hu.tex",            "hungarian" },
    -- not supported
--  { "hy",  "hyph-hy.tex",            "armenian" },
    { "??",  "hyph-ia.tex",            "interlingua" },
    { "??",  "hyph-id.tex",            "indonesian" },
    { "is",  "hyph-is.tex",            "icelandic" },
    { "it",  "hyph-it.tex",            "italian" },
    { "??",  "hyph-kmr.tex",           "kurmanji" },
    -- not supported
--  { "kn",  "hyph-kn.tex",            "kannada" },
    { "la",  "hyph-la.tex",            "latin" },
    -- not supported
--  { "lo",  "hyph-lo.tex",            "lao" },
    { "lt",  "hyph-lt.tex",            "lithuanian" },
    { "??",  "hyph-lv.tex",            "latvian" },
    { "mn",  "hyph-mn-cyrl.tex",       "mongolian, cyrillic script" },
    { "nb",  "hyph-nb.tex",            "norwegian bokmål" },
    { "nl",  "hyph-nl.tex",            "dutch" },
    { "nn",  "hyph-nn.tex",            "norwegian nynorsk" },
    -- not supported
--  { "or",  "hyph-or.tex",            "oriya" },
    -- not supported
--  { "pa",  "hyph-pa.tex",            "panjabi" },
    -- not supported
--  { "",  "hyph-.tex",            "" },
    { "pl",  "hyph-pl.tex",            "polish" },
    { "pt",  "hyph-pt.tex",            "portuguese" },
    { "ro",  "hyph-ro.tex",            "romanian" },
    { "ru",  "hyph-ru.tex",            "russian" },
    -- not supported
--  { "sa",  "hyph-sa.tex",            "sanskrit" },
    { "sk",  "hyph-sk.tex",            "slovak" },
    { "sl",  "hyph-sl.tex",            "slovenian" },
    -- TODO: there is both Cyrillic and Latin script available
    { "sr",  "hyph-sr-cyrl.tex",       "serbian" },
    { "sv",  "hyph-sv.tex",            "swedish" },
    -- not supported
--  { "ta",  "hyph-ta.tex",            "tamil" },
    -- not supported
--  { "te",  "hyph-te.tex",            "telugu" },
    { "tk",  "hyph-tk.tex",            "turkmen" },
    { "tr",  "hyph-tr.tex",            "turkish" },
    { "uk",  "hyph-uk.tex",            "ukrainian" },
    { "zh",  "hyph-zh-latn.tex",       "zh-latn, chinese Pinyin" },
}

-- stripped down from lpeg example:

local utf = unicode.utf8

function utf.check(str)
    return lpeg.match(lpeg.patterns.validutf8,str)
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
        for k, v in next, h do
            if not permitted_commands[k] then okay = false end
            if mnemonic then
                logs.simple("command \\%s found in language %s, file %s, n=%s",k,mnemonic,name,v)
            else
                logs.simple("command \\%s found in file %s, n=%s",k,name,v)
            end
        end
        if not environment.argument("fast") then
            for k, v in next, c do
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
        patterns = patterns:gsub("[ \t]+","\n")
        hyphenations = hyphenations:gsub("[ \t]+","\n")
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
        for k, v in next, p do
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
        for k, v in next, h do
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
        for k, v in next, stripped do
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

function scripts.patterns.save(destination,mnemonic,name,patterns,hyphenations,comment,stripped,pused,hused)
    local nofpatterns = #patterns
    local nofhyphenations = #hyphenations
    logs.simple("language %s has %s patterns and %s exceptions",mnemonic,nofpatterns,nofhyphenations)
    if mnemonic ~= "??" then
        local pu = concat(table.sortedkeys(pused), " ")
        local hu = concat(table.sortedkeys(hused), " ")

        local rmefile = file.join(destination,"lang-"..mnemonic..".rme")
        local patfile = file.join(destination,"lang-"..mnemonic..".pat")
        local hypfile = file.join(destination,"lang-"..mnemonic..".hyp")
        local luafile = file.join(destination,"lang-"..mnemonic..".lua") -- suffix might change to llg

        local topline = "% generated by mtxrun --script pattern --convert"
        local banner = "% for comment and copyright, see " .. rmefile
        logs.simple("saving language data for %s",mnemonic)
        if not comment or comment == "" then comment = "% no comment" end
        if not type(destination) == "string" then destination = "." end

        local lines = string.splitlines(comment)
        for i=1,#lines do
            if not find(lines[i],"^%%") then
                lines[i] = "% " .. lines[i]
            end
        end

        local metadata = {
         -- texcomment = comment,
            texcomment = concat(lines,"\n"),
            source     = name,
            mnemonic   = mnemonic,
        }

        local patterndata, hyphenationdata
        if nofpatterns > 0 then
            patterndata = {
                n            = nofpatterns,
                data         = concat(patterns," ") or nil,
                characters   = concat(table.sortedkeys(pused),""),
                minhyphenmin = 1, -- determined by pattern author
                minhyphenmax = 1, -- determined by pattern author
            }
        else
            patterndata = {
                n = nofpatterns,
            }
        end
        if nofhyphenations > 0 then
            hyphenationdata = {
                n          = nofhyphenations,
                data       = concat(hyphenations," "),
                characters = concat(table.sortedkeys(hused),""),
            }
        else
            hyphenationdata = {
                n = nofhyphenations,
            }
        end
        local data = {
            -- a prelude to language goodies, like we have font goodies and in
            -- mkiv we can use this file directly
            version    = "1.001",
            comment    = topline,
            metadata   = metadata,
            patterns   = patterndata,
            exceptions = hyphenationdata,
        }

        os.remove(rmefile)
        os.remove(patfile)
        os.remove(hypfile)
        os.remove(luafile)

        io.savedata(rmefile,format("%s\n\n%s",topline,comment))
        io.savedata(patfile,format("%s\n\n%s\n\n%% used: %s\n\n\\patterns{\n%s}",topline,banner,pu,concat(patterns,"\n")))
        io.savedata(hypfile,format("%s\n\n%s\n\n%% used: %s\n\n\\hyphenation{\n%s}",topline,banner,hu,concat(hyphenations,"\n")))
        io.savedata(luafile,table.serialize(data,true))
    end
end

function scripts.patterns.prepare()
    dofile(resolvers.find_file("char-def.lua"))
end

function scripts.patterns.check()
    local path = environment.argument("path") or "."
    local found = false
    local files = environment.files
    if #files > 0 then
        for i=1,#files do
            local name = files[i]
            logs.simple("checking language file %s", name)
            local okay = scripts.patterns.load(path,name,nil,not environment.argument("fast"))
            if #environment.files > 1 then
                logs.simple("")
            end
        end
    else
        for k, v in next, scripts.patterns.list do
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
            for k, v in next, scripts.patterns.list do
                local mnemonic, name = v[1], v[2]
                logs.simple("converting language %s, file %s", mnemonic, name)
                local okay, patterns, hyphenations, comment, stripped, pused, hused = scripts.patterns.load(path,name,false)
                if okay then
                    scripts.patterns.save(destination,mnemonic,name,patterns,hyphenations,comment,stripped,pused,hused)
                else
                    logs.simple("convertion aborted due to error(s)")
                end
                logs.simple("")
            end
        end
    end
end

logs.extendbanner("ConTeXt Pattern File Management 0.20")

messages.help = [[
--convert             generate context language files (mnemonic driven, if not given then all)
--check               check pattern file (or those used by context when no file given)
--path                source path where hyph-foo.tex files are stored
--destination         destination path

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
-- mtxrun --script pattern --convert        --path=c:/data/develop/svn-hyphen/branches/luatex/hyph-utf8/tex/generic/hyph-utf8/patterns/tex --destination=e:/tmp/patterns

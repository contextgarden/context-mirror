if not modules then modules = { } end modules ['mtx-patterns'] = {
    version   = 1.001,
    comment   = "companion to mtxrun.lua",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local format, find, concat, gsub, match, gmatch = string.format, string.find, table.concat, string.gsub, string.match, string.gmatch
local byte, char = utf.byte, utf.char
local addsuffix = file.addsuffix
local lpegmatch, validutf8 = lpeg.match, lpeg.patterns.validutf8

local helpinfo = [[
<?xml version="1.0"?>
<application>
 <metadata>
  <entry name="name">mtx-patterns</entry>
  <entry name="detail">ConTeXt Pattern File Management</entry>
  <entry name="version">0.20</entry>
 </metadata>
 <flags>
  <category name="basic">
   <subcategory>
    <flag name="convert"><short>generate context language files (mnemonic driven, if not given then all)</short></flag>
    <flag name="check"><short>check pattern file (or those used by context when no file given)</short></flag>
    <flag name="path"><short>source path where hyph-foo.tex files are stored</short></flag>
    <flag name="destination"><short>destination path</short></flag>
    <flag name="specification"><short>additional patterns: e.g.: =cy,hyph-cy,welsh</short></flag>
   </subcategory>
  </category>
 </flags>
 <examples>
  <category>
   <title>Examples</title>
   <subcategory>
    <example><command>mtxrun --script pattern --check hyph-*.tex</command></example>
    <example><command>mtxrun --script pattern --check   --path=c:/data/develop/svn-hyphen/trunk/hyph-utf8/tex/generic/hyph-utf8/patterns</command></example>
    <example><command>mtxrun --script pattern --convert --path=c:/data/develop/svn-hyphen/trunk/hyph-utf8/tex/generic/hyph-utf8/patterns/tex --destination=e:/tmp/patterns</command></example>
    <example><command>mtxrun --script pattern --convert --path=c:/data/develop/svn-hyphen/trunk/hyph-utf8/tex/generic/hyph-utf8/patterns/txt --destination=e:/tmp/patterns</command></example>
   </subcategory>
  </category>
 </examples>
</application>
]]

local application = logs.application {
    name     = "mtx-patterns",
    banner   = "ConTeXt Pattern File Management 0.20",
    helpinfo = helpinfo,
}

local report = application.report

scripts          = scripts          or { }
scripts.patterns = scripts.patterns or { }

local permitted_characters = table.tohash {
    0x0009, -- tab
    0x0027, -- apostrofe
    0x02BC, -- modifier apostrofe (used in greek)
    0x002D, -- hyphen
    0x200C, -- zwnj
    0x2019, -- quote right
    0x1FBD, -- greek, but no letter: symbol modifier
    0x1FBF, -- greek, but no letter: symbol modifier
}

local ignored_ancient_greek = table.tohash {
    0x1FD3, -- greekiotadialytikatonos (also 0x0390)
    0x1FE3, -- greekupsilondialytikatonos (also 0x03B0)
    0x1FBD, -- greek, but no letter: symbol modifier
    0x1FBF, -- greek, but no letter: symbol modifier
    0x03F2, -- greeksigmalunate
    0x02BC, -- modifier apostrofe)
}

local ignored_french = table.tohash {
    0x02BC, -- modifier apostrofe
}

local replaced_whatever =  {
    [char(0x2019)] = char(0x0027)
}

scripts.patterns.list = {
    { "af",  "hyph-af",            "afrikaans" },
 -- { "ar",  "hyph-ar",            "arabic" },
 -- { "as",  "hyph-as",            "assamese" },
    { "bg",  "hyph-bg",            "bulgarian" },
 -- { "bn",  "hyph-bn",            "bengali" },
    { "ca",  "hyph-ca",            "catalan" },
 -- { "??",  "hyph-cop",           "coptic" },
    { "cs",  "hyph-cs",            "czech" },
    { "cy",  "hyph-cy",            "welsh" },
    { "da",  "hyph-da",            "danish" },
    { "deo", "hyph-de-1901",       "german, old spelling" },
    { "de",  "hyph-de-1996",       "german, new spelling" },
 -- { "??",  "hyph-de-ch-1901",    "swiss german" },
 -- { "??",  "hyph-el-monoton",    "greek" },
 -- { "gr",  "hyph-el-polyton",    "greek" },
    { "agr", "hyph-grc",           "ancient greek", ignored_ancient_greek },
    { "gb",  "hyph-en-gb",         "british english" },
    { "us",  "hyph-en-us",	       "american english" },
 -- { "eo",  "hyph-eo",            "esperanto" },
    { "es",  "hyph-es",            "spanish" },
    { "et",  "hyph-et",            "estonian" },
    { "eu",  "hyph-eu",            "basque" },
 -- { "fa",  "hyph-fa",            "farsi" },
    { "fi",  "hyph-fi",            "finnish" },
    { "fr",  "hyph-fr",            "french", ignored_french },
 -- { "??",  "hyph-ga",            "irish" },
 -- { "??",  "hyph-gl",            "galician" },
 -- { "gu",  "hyph-gu",            "gujarati" },
 -- { "hi",  "hyph-hi",            "hindi" },
    { "hr",  "hyph-hr",            "croatian" },
 -- { "??",  "hyph-hsb",           "upper sorbian" },
    { "hu",  "hyph-hu",            "hungarian" },
 -- { "hy",  "hyph-hy",            "armenian" },
 -- { "??",  "hyph-ia",            "interlingua" },
 -- { "??",  "hyph-id",            "indonesian" },
    { "is",  "hyph-is",            "icelandic" },
    { "it",  "hyph-it",            "italian" },
 -- { "??",  "hyph-kmr",           "kurmanji" },
 -- { "kn",  "hyph-kn",            "kannada" },
    { "la",  "hyph-la",            "latin" },
 -- { "lo",  "hyph-lo",            "lao" },
    { "lt",  "hyph-lt",            "lithuanian" },
    { "lv",  "hyph-lv",            "latvian" },
 -- { "ml",  "hyph-ml",            "..." },
    { "mn",  "hyph-mn-cyrl",       "mongolian, cyrillic script" },
 -- { "mr",  "hyph-mr",            "..." },
    { "nb",  "hyph-nb",            "norwegian bokmål" },
    { "nl",  "hyph-nl",            "dutch" },
    { "nn",  "hyph-nn",            "norwegian nynorsk" },
 -- { "or",  "hyph-or",            "oriya" },
 -- { "pa",  "hyph-pa",            "panjabi" },
 -- { "",    "hyph-",              "" },
    { "pl",  "hyph-pl",            "polish" },
    { "pt",  "hyph-pt",            "portuguese" },
    { "ro",  "hyph-ro",            "romanian" },
    { "ru",  "hyph-ru",            "russian" },
 -- { "sa",  "hyph-sa",            "sanskrit" },
    { "sk",  "hyph-sk",            "slovak" },
    { "sl",  "hyph-sl",            "slovenian" },
    { "sr",  "hyph-sr-cyrl",       "serbian" },
 -- { "sr",  "hyph-sr-latn",       "serbian" },
    { "sv",  "hyph-sv",            "swedish" },
 -- { "ta",  "hyph-ta",            "tamil" },
 -- { "te",  "hyph-te",            "telugu" },
    { "tk",  "hyph-tk",            "turkmen" },
    { "tr",  "hyph-tr",            "turkish" },
    { "uk",  "hyph-uk",            "ukrainian" },
    { "zh",  "hyph-zh-latn",       "zh-latn, chinese pinyin" },
}

-- stripped down from lpeg example:

local utf = unicode.utf8

function utf.check(str)
    return lpeg.match(lpeg.patterns.validutf8,str)
end

-- *.tex
-- *.hyp.txt *.pat.txt *.lic.txt *.chr.txt

function scripts.patterns.load(path,name,mnemonic,ignored)
    local fullname = file.join(path,name)
    local texfile = addsuffix(fullname,"tex")
    local hypfile = addsuffix(fullname,"hyp.txt")
    local patfile = addsuffix(fullname,"pat.txt")
    local licfile = addsuffix(fullname,"lic.txt")
 -- local chrfile = addsuffix(fullname,"chr.txt")
    local okay = true
    local hyphenations, patterns, comment, stripset = "", "", "", ""
    local splitpatternsnew, splithyphenationsnew = { }, { }
    local splitpatternsold, splithyphenationsold = { }, { }
    local usedpatterncharactersnew, usedhyphenationcharactersnew = { }, { }
    if lfs.isfile(patfile) then
        report("using txt files %s.[hyp|pat|lic].txt",name)
        comment, patterns, hyphenations = io.loaddata(licfile) or "", io.loaddata(patfile) or "", io.loaddata(hypfile) or ""
        hypfile, patfile, licfile = hypfile, patfile, licfile
    elseif lfs.isfile(texfile) then
        report("using tex file %s.txt",name)
        local data = io.loaddata(texfile) or ""
        if data ~= "" then
            data = gsub(data,"([\n\r])\\input ([^ \n\r]+)", function(previous,subname)
                local subname = addsuffix(subname,"tex")
                local subfull = file.join(file.dirname(texfile),subname)
                local subdata = io.loaddata(subfull) or ""
                if subdata == "" then
                    report("no subfile %s",subname)
                end
                return previous .. subdata
            end)
            data = gsub(data,"%%.-[\n\r]","")
            data = gsub(data," *[\n\r]+","\n")
            patterns = match(data,"\\patterns[%s]*{[%s]*(.-)[%s]*}") or ""
            hyphenations = match(data,"\\hyphenation[%s]*{[%s]*(.-)[%s]*}") or ""
            comment = match(data,"^(.-)[\n\r]\\patterns") or ""
        else
            okay = false
        end
    else
        okay = false
    end
    if okay then
        -- split into lines
        local how = lpeg.patterns.whitespace^1
        splitpatternsnew = lpeg.split(how,patterns)
        splithyphenationsnew = lpeg.split(how,hyphenations)
    end
    if okay then
        -- remove comments
        local function check(data,splitdata,name)
            if find(data,"%%") then
                for i=1,#splitdata do
                    local line = splitdata[i]
                    if find(line,"%%") then
                        splitdata[i] = gsub(line,"%%.*$","")
                        report("removing comment: %s",line)
                    end
                end
            end
        end
        check(patterns,splitpatternsnew,patfile)
        check(hyphenations,splithyphenationsnew,hypfile)
    end
    if okay then
        -- remove lines with commands
        local function check(data,splitdata,name)
            if find(data,"\\") then
                for i=1,#splitdata do
                    local line = splitdata[i]
                    if find(line,"\\") then
                        splitdata[i] = ""
                        report("removing line with command: %s",line)
                    end
                end
            end
        end
        check(patterns,splitpatternsnew,patfile)
        check(hyphenations,splithyphenationsnew,hypfile)
    end
    if okay then
        -- check for valid utf
        local function check(data,splitdata,name)
            for i=1,#splitdata do
                local line = splitdata[i]
                local ok = lpegmatch(validutf8,line)
                if not ok then
                    splitdata[i] = ""
                    report("removing line with invalid utf: %s",line)
                end
            end
            -- check for commands being used in comments
        end
        check(patterns,splitpatternsnew,patfile)
        check(hyphenations,splithyphenationsnew,hypfile)
    end
    if okay then
        -- remove funny lines
        local cd = characters.data
        local stripped = { }
        local function check(splitdata,special,name)
            local used = { }
            for i=1,#splitdata do
                local line = splitdata[i]
                for b in line:utfvalues() do -- could be an lpeg
                    if b == special then
                        -- not registered
                    elseif permitted_characters[b] then
                        used[char(b)] = true
                    else
                        local cdb = cd[b]
                        if not cdb then
                            report("no entry in chardata for character %s (0x%04X)",char(b),b)
                        else
                            local ct = cdb.category
                            if ct == "lu" or ct == "ll" then
                                used[char(b)] = true
                            elseif ct == "nd" then
                                -- number
                            else
                                report("removing line with suspected utf character %s (0x%04X), category %s: %s",char(b),b,ct,line)
                                splitdata[i] = ""
                                break
                            end
                        end
                    end
                end
            end
            return used
        end
        usedpatterncharactersnew = check(splitpatternsnew,byte("."))
        usedhyphenationcharactersnew = check(splithyphenationsnew,byte("-"))
        for k, v in next, stripped do
            report("entries that contain character %s (0x%04X) have been omitted",char(k),k)
        end
    end
    if okay then
        local function stripped(what,ignored)
            -- ignored (per language)
            local p = nil
            if ignored then
                for k, v in next, ignored do
                    if p then
                        p = p + lpeg.P(char(k))
                    else
                        p = lpeg.P(char(k))
                    end
                end
                p = lpeg.P{ p + 1 * lpeg.V(1) } -- anywhere
            end
            -- replaced (all languages)
            local r = nil
            for k, v in next, replaced_whatever do
                if r then
                    r = r + lpeg.P(k)/v
                else
                    r = lpeg.P(k)/v
                end
            end
            r = lpeg.Cs((r + 1)^0)
            local result = { }
            for i=1,#what do
                local line = what[i]
                if p and lpegmatch(p,line) then
                    report("discarding conflicting pattern: %s",line)
                else -- we can speed this up by testing for replacements in the string
                    local l = lpegmatch(r,line)
                    if l ~= line then
                        report("sanitizing pattern: %s -> %s (for old patterns)",line,l)
                    end
                    result[#result+1] = l
                end
            end
            return result
        end

        splitpatternsold = stripped(splitpatternsnew,ignored)
        splithyphenationsold = stripped(splithyphenationsnew,ignored)

    end
    if okay then
        -- discarding duplicates
        local function check(data,splitdata,name)
            local used, collected = { }, { }
            for i=1,#splitdata do
                local line = splitdata[i]
                if line == "" then
                    -- discard
                elseif used[line] then
                    -- discard
                    report("discarding duplicate pattern: %s",line)
                else
                    used[line] = true
                    collected[#collected+1] = line
                end
            end
            return collected
        end
        splitpatternsnew = check(patterns,splitpatternsnew,patfile)
        splithyphenationsnew = check(hyphenations,splithyphenationsnew,hypfile)
        splitpatternsold = check(patterns,splitpatternsold,patfile)
        splithyphenationsold = check(hyphenations,splithyphenationsold,hypfile)
    end
    if not okay then
        report("no valid file %s.*",name)
    end

    local function getused(t)
        local u = { }
        for k, v in next, t do
            if ignored and ignored[k] then
            elseif replaced_whatever[k] then
            else
                u[k] = v
            end
        end
        return u
    end
    local usedpatterncharactersold = getused(usedpatterncharactersnew)
    local usedhyphenationcharactersold = getused(usedhyphenationcharactersnew)

    return okay,
        splitpatternsnew, splithyphenationsnew, splitpatternsold, splithyphenationsold, comment, stripset,
        usedpatterncharactersnew, usedhyphenationcharactersnew, usedpatterncharactersold, usedhyphenationcharactersold
end

function scripts.patterns.save(destination,mnemonic,name,patternsnew,hyphenationsnew,patternsold,hyphenationsold,comment,stripped,
        pusednew,husednew,pusedold,husedold,ignored)
    local nofpatternsnew, nofhyphenationsnew = #patternsnew, #hyphenationsnew
    local nofpatternsold, nofhyphenationsold = #patternsold, #hyphenationsold
    report("language %s has %s old and %s new patterns and %s old and %s new exceptions",mnemonic,nofpatternsold,nofpatternsnew,nofhyphenationsold,nofhyphenationsnew)
    if mnemonic ~= "??" then
        local punew = concat(table.sortedkeys(pusednew), " ")
        local hunew = concat(table.sortedkeys(husednew), " ")
        local puold = concat(table.sortedkeys(pusedold), " ")
        local huold = concat(table.sortedkeys(husedold), " ")

        local rmefile = file.join(destination,"lang-"..mnemonic..".rme")
        local patfile = file.join(destination,"lang-"..mnemonic..".pat")
        local hypfile = file.join(destination,"lang-"..mnemonic..".hyp")
        local luafile = file.join(destination,"lang-"..mnemonic..".lua") -- suffix might change to llg

        local topline = "% generated by mtxrun --script pattern --convert"
        local banner = "% for comment and copyright, see " .. file.basename(rmefile)
        report("saving language data for %s",mnemonic)
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
        if nofpatternsnew > 0 then
            patterndata = {
                n            = nofpatternsnew,
                data         = concat(patternsnew," ") or nil,
                characters   = concat(table.sortedkeys(pusednew),""),
                minhyphenmin = 1, -- determined by pattern author
                minhyphenmax = 1, -- determined by pattern author
            }
        else
            patterndata = {
                n = 0,
            }
        end
        if nofhyphenationsnew > 0 then
            hyphenationdata = {
                n          = nofhyphenationsnew,
                data       = concat(hyphenationsnew," "),
                characters = concat(table.sortedkeys(husednew),""),
            }
        else
            hyphenationdata = {
                n = 0,
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
        io.savedata(patfile,format("%s\n\n%s\n\n%% used: %s\n\n\\patterns{\n%s}",topline,banner,puold,concat(patternsold,"\n")))
        io.savedata(hypfile,format("%s\n\n%s\n\n%% used: %s\n\n\\hyphenation{\n%s}",topline,banner,huold,concat(hyphenationsold,"\n")))
        io.savedata(luafile,table.serialize(data,true))
    end
end

function scripts.patterns.prepare()
    --
    dofile(resolvers.findfile("char-def.lua"))
    --
    local specification = environment.argument("specification")
    if specification then
        local components = utilities.parsers.settings_to_array(specification)
        if #components == 3 then
            table.insert(scripts.patterns.list,1,components)
            report("specification added: %s %s %s",table.unpack(components))
        else
            report('invalid specification: %q, "xx,lang-yy,zzzz" expected',specification)
        end
    end
end

function scripts.patterns.check()
    local path = environment.argument("path") or "."
    local files = environment.files
    local only  = false
    if #files > 0 then
        only = table.tohash(files)
    end
    for k, v in next, scripts.patterns.list do
        local mnemonic, name, ignored = v[1], v[2], v[4]
        if not only or only[mnemonic] then
            report("checking language %s, file %s", mnemonic, name)
            local okay = scripts.patterns.load(path,name,mnemonic,ignored)
            if not okay then
                report("there are errors that need to be fixed")
            end
            report()
        end
    end
end

function scripts.patterns.convert()
    local path = environment.argument("path") or "."
    if path == "" then
        report("provide sourcepath using --path ")
    else
        local destination = environment.argument("destination") or "."
        if path == destination then
            report("source path and destination path should differ (use --path and/or --destination)")
        else
            local files = environment.files
            local only  = false
            if #files > 0 then
                only = table.tohash(files)
            end
            for k, v in next, scripts.patterns.list do
                local mnemonic, name, ignored = v[1], v[2], v[4]
                if not only or only[mnemonic] then
                    report("converting language %s, file %s", mnemonic, name)
                    local okay, patternsnew, hyphenationsnew, patternsold, hyphenationsold, comment, stripped,
                        pusednew, husednew, pusedold, husedold = scripts.patterns.load(path,name,mnemonic,ignored)
                    if okay then
                        scripts.patterns.save(destination,mnemonic,name,patternsnew,hyphenationsnew,patternsold,hyphenationsold,comment,stripped,
                            pusednew,husednew,pusedold,husedold,ignored)
                    else
                        report("convertion aborted due to error(s)")
                    end
                    report()
                end
            end
        end
    end
end

if environment.argument("check") then
    scripts.patterns.prepare()
    scripts.patterns.check()
elseif environment.argument("convert") then
    scripts.patterns.prepare()
    scripts.patterns.convert()
elseif environment.argument("exporthelp") then
    application.export(environment.argument("exporthelp"),environment.files[1])
else
    application.help()
end

-- mtxrun --script pattern --check hyph-*.tex
-- mtxrun --script pattern --check          --path=c:/data/develop/svn-hyphen/trunk/hyph-utf8/tex/generic/hyph-utf8/patterns
-- mtxrun --script pattern --convert        --path=c:/data/develop/svn-hyphen/trunk/hyph-utf8/tex/generic/hyph-utf8/patterns/tex --destination=e:/tmp/patterns
-- mtxrun --script pattern --convert        --path=c:/data/develop/svn-hyphen/trunk/hyph-utf8/tex/generic/hyph-utf8/patterns/txt --destination=e:/tmp/patterns

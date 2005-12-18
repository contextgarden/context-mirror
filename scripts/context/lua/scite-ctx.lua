-- version   : 1.0.0 - 07/2005
-- author    : Hans Hagen - PRAGMA ADE - www.pragma-ade.com
-- copyright : public domain or whatever suits
-- remark    : part of the context distribution

-- todo: name space for local functions

-- loading: scite-ctx.properties

-- # environment variable
-- #
-- #   CTXSPELLPATH=t:/spell
-- #
-- # auto language detection
-- #
-- #   % version =1.0 language=uk
-- #   <?xml version='1.0' language='uk' ?>

-- ext.lua.startup.script=$(SciteDefaultHome)/scite-ctx.lua
--
-- # extension.$(file.patterns.context)=scite-ctx.lua
-- # extension.$(file.patterns.example)=scite-ctx.lua
--
-- # ext.lua.reset=1
-- # ext.lua.auto.reload=1
-- # ext.lua.startup.script=t:/lua/scite-ctx.lua
--
-- ctx.menulist.default=\
--     wrap=wrap_text|\
--     unwrap=unwrap_text|\
--     sort=sort_text|\
--     document=document_text|\
--     quote=quote_text|\
--     compound=compound_text|\
--     check=check_text
--
-- ctx.spellcheck.language=auto
-- ctx.spellcheck.wordsize=4
-- ctx.spellcheck.wordpath=ENV(CTXSPELLPATH)
--
-- ctx.spellcheck.wordfile.all=spell-uk.txt,spell-nl.txt
--
-- ctx.spellcheck.wordfile.uk=spell-uk.txt
-- ctx.spellcheck.wordfile.nl=spell-nl.txt
-- ctx.spellcheck.wordsize.uk=4
-- ctx.spellcheck.wordsize.nl=4
--
-- command.name.21.*=CTX Action List
-- command.subsystem.21.*=3
-- command.21.*=show_menu $(ctx.menulist.default)
-- command.groupundo.21.*=yes
-- command.shortcut.21.*=Shift+F11
--
-- command.name.22.*=CTX Check Text
-- command.subsystem.22.*=3
-- command.22.*=check_text
-- command.groupundo.22.*=yes
-- command.shortcut.22.*=Ctrl+L
--
-- command.name.23.*=CTX Wrap Text
-- command.subsystem.23.*=3
-- command.23.*=wrap_text
-- command.groupundo.23.*=yes
-- command.shortcut.23.*=Ctrl+M
--
-- # command.21.*=check_text
-- # command.21.*=dofile e:\context\lua\scite-ctx.lua

-- generic functions

local crlf = "\n"

function traceln(str)
    trace(str .. crlf)
    io.flush()
end

table.len  = table.getn
table.join = table.concat

function table.found(tab, str)
    local l, r, p
    if string.len(str) == 0 then
        return false
    else
        l, r = 1, table.len(tab)
        while l <= r do
            p = math.floor((l+r)/2)
            if str < tab[p] then
                r = p - 1
            elseif str > tab[p] then
                l = p + 1
            else
                return true
            end
        end
        return false
    end
end

function string.grab(str, delimiter)
    local list = {}
    for snippet in string.gfind(str,delimiter) do
        table.insert(list, snippet)
    end
    return list
end

function string.join(list, delimiter)
    local size, str = table.len(list), ''
    if size > 0 then
        str = list[1]
        for i = 2, size, 1 do
            str = str .. delimiter .. list[i]
        end
    end
    return str
end

function string.spacy(str)
    if string.find(str,"^%s*$") then
        return true
    else
        return false
    end
end

function string.alphacmp(a,b,i) -- slow but ok
    if i and i > 0 then
        return string.lower(string.gsub(string.sub(a,i),'0',' ')) < string.lower(string.gsub(string.sub(b,i),'0',' '))
    else
        return string.lower(a) < string.lower(b)
    end
end

function table.alphasort(list,i)
    table.sort(list, function(a,b) return string.alphacmp(a,b,i) end)
end

function io.exists(filename)
    local ok, result, message = pcall(io.open,filename)
    if result then
        io.close(result)
        return true
    else
        return false
    end
end

function os.envvar(str)
    if os.getenv(str) ~= '' then
        return os.getenv(str)
    elseif os.getenv(string.upper(str)) ~= '' then
        return os.getenv(string.upper(str))
    elseif os.getenv(string.lower(str)) ~= '' then
        return os.getenv(string.lower(str))
    else
        return ''
    end
end

function string.expand(str)
    return string.gsub(str, "ENV%((%w+)%)", os.envvar)
end

function string.strip(str)
    return string.gsub(string.gsub(str,"^%s+",''),"%s+$",'')
end

function string.replace(original,pattern,replacement)
    local str = string.gsub(original,pattern,replacement)
    print(str) -- indirect, since else str + nofsubs
end

-- support functions, maybe editor namespace

--~ function column_of_position(position)
--~     local line = editor:LineFromPosition(position)
--~     local oldposition = editor.CurrentPos
--~     local column = 0
--~     editor:GotoPos(position)
--~     while editor.CurrentPos ~= 0 and line == editor:LineFromPosition(editor.CurrentPos) do
--~         editor:CharLeft()
--~         column = column + 1
--~     end
--~     editor:GotoPos(oldposition)
--~     if line > 0 then
--~         return column -1
--~     else
--~         return column
--~     end
--~ end

--~ function line_of_position(position)
--~     return editor:LineFromPosition(position)
--~ end

function extend_to_start()
    local selectionstart = editor.SelectionStart
    local selectionend = editor.SelectionEnd
    local line = editor:LineFromPosition(selectionstart)
    if line > 0 then
        while line == editor:LineFromPosition(selectionstart-1) do
            selectionstart = selectionstart - 1
            editor:SetSel(selectionstart,selectionend)
        end
    else
        selectionstart = 0
    end
    editor:SetSel(selectionstart,selectionend)
    return selectionstart
end

function extend_to_end() -- editor:LineEndExtend() does not work
    local selectionstart = editor.SelectionStart
    local selectionend = editor.SelectionEnd
    local line = editor:LineFromPosition(selectionend)
    while line == editor:LineFromPosition(selectionend+1) do
        selectionend = selectionend + 1
        editor:SetSel(selectionstart,selectionend)
    end
    editor:SetSel(selectionstart,selectionend)
    return selectionend
end

function getfiletype()
    local firstline = editor:GetLine(0)
    if editor.Lexer == SCLEX_TEX then
        return 'tex'
    elseif editor.Lexer == SCLEX_XML then
        return 'xml'
    elseif string.find(firstline,"^%%") then
        return 'tex'
    elseif string.find(firstline,"^<%?xml") then
        return 'xml'
    else
        return 'unknown'
    end
end

-- banner

print("loading scite-ctx.lua definition file")
print("")
print("-  see scite-ctx.properties for configuring info")
print("")
print("-  ctx.spellcheck.wordpath set to " .. props['ctx.spellcheck.wordpath'])
if string.find(string.lower(props['ctx.spellcheck.wordpath']), "ctxspellpath") then
    if os.getenv('ctxspellpath') then
        print("-  ctxspellpath set to " .. os.getenv('CTXSPELLPATH'))
    else
        print("-  'ctxspellpath is not set")
    end
    print("-  ctx.spellcheck.wordpath expands to " .. string.expand(props['ctx.spellcheck.wordpath']))
end
print("")
print("-  ctx.wraptext.length is set to " .. props['ctx.wraptext.length'])
if props['ctx.helpinfo'] ~= '' then
    print("-  key bindings:")
    print("")
    print(string.replace(string.strip(props['ctx.helpinfo']),"%s*\|%s*","\n")) -- indirect, since else str + nofsubs
end
--~ print("") -- why not needed?
print("-  recognized first lines:")
print("")
print("xml   <?xml version='1.0' language='nl'")
print("tex   % language=nl")


-- text functions

-- written while listening to Talk Talk

local magicstring = string.rep("<ctx-crlf/>", 2)

function wrap_text()

    -- We always go to the end of a line, so in fact some of
    -- the variables set next are not needed.

    local length = props["ctx.wraptext.length"]

    if length == '' then length = 80 else length = tonumber(length) end

    local startposition   = editor.SelectionStart
    local endposition     = editor.SelectionEnd

    if startposition == endposition then return end

    editor:LineEndExtend()

    startposition   = editor.SelectionStart
    endposition     = editor.SelectionEnd

    -- local startline   = line_of_position(startposition)
    -- local endline     = line_of_position(endposition)
    -- local startcolumn = column_of_position(startposition)
    -- local endcolumn   = column_of_position(endposition)
    --
    -- editor:SetSel(startposition,endposition)

    local startline   = props['SelectionStartLine']
    local endline     = props['SelectionEndLine']
    local startcolumn = props['SelectionStartColumn'] - 1
    local endcolumn   = props['SelectionEndColumn']   - 1

    local indentation = string.rep(' ', startcolumn)
--~ local selection   = string.gsub(editor:GetSelText(),"[\n\r][\n\r]+", ' ' .. magicstring .. ' ')
    local selection   = string.gsub(editor:GetSelText(),"[\n\r][\n\r]", "\n")
    local selection   = string.gsub(selection,"\n\n+", ' ' .. magicstring .. ' ')
    local replacement = ''
    local templine    = ''

    selection = string.gsub(selection,"^%s", '')

    for snippet in string.gfind(selection, "%S+") do
        if snippet == magicstring then
            replacement = replacement .. templine .. "\n\n"
            templine = ''
        elseif string.len(templine) + string.len(snippet) > length then
            replacement = replacement .. templine .. "\n"
            templine = indentation .. snippet
        elseif string.len(templine) == 0 then
            templine = indentation .. snippet
        else
            templine = templine .. ' ' .. snippet
        end
    end

    replacement = replacement .. templine
    replacement = string.gsub(replacement, "^%s+", '')

    if endcolumn == 0 then
        replacement = replacement .. "\n"
    end

    editor:ReplaceSel(replacement)

end

function unwrap_text()

    local startposition   = editor.SelectionStart
    local endposition     = editor.SelectionEnd

    if startposition == endposition then return end

    editor:HomeExtend()
    editor:LineEndExtend()

    startposition = editor.SelectionStart
    endposition   = editor.SelectionEnd

    local magicstring = string.rep("<multiplelines/>", 2)
    local selection   = string.gsub(editor:GetSelText(),"[\n\r][\n\r]+", ' ' .. magicstring .. ' ')
    local replacement = ''

    for snippet in string.gfind(selection, "%S+") do
        if snippet == magicstring then
            replacement = replacement .. "\n"
        else
            replacement = replacement .. snippet .. "\n"
        end
    end

    if endcolumn == 0 then replacement = replacement .. "\n" end

    editor:ReplaceSel(replacement)

end

function sort_text()

    local startposition = editor.SelectionStart
    local endposition   = editor.SelectionEnd

    if startposition == endposition then return end

    -- local startcolumn = column_of_position(startposition)
    -- local endcolumn   = column_of_position(endposition)
    --
    -- editor:SetSel(startposition,endposition)

    local startline   = props['SelectionStartLine']
    local endline     = props['SelectionEndLine']
    local startcolumn = props['SelectionStartColumn'] - 1
    local endcolumn   = props['SelectionEndColumn']   - 1

    startposition = extend_to_start()
    endposition   = extend_to_end()

    local selection = string.gsub(editor:GetSelText(), "%s*$", '')

    list = string.grab(selection,"[^\n\r]+")
    table.alphasort(list, startcolumn)
    local replacement = table.concat(list, "\n")

    editor:GotoPos(startposition)
    editor:SetSel(startposition,endposition)

    if endcolumn == 0 then replacement = replacement .. "\n" end

    editor:ReplaceSel(replacement)

end

function document_text()

    local startposition = editor.SelectionStart
    local endposition   = editor.SelectionEnd

    if startposition == endposition then return end

    startposition = extend_to_start()
    endposition   = extend_to_end()

    editor:SetSel(startposition,endposition)

    local filetype = getfiletype()

    local replacement = ''
    for i = editor:LineFromPosition(startposition), editor:LineFromPosition(endposition) do
        local str = editor:GetLine(i)
        if filetype == 'xml' then
            if string.find(str,"^<%!%-%- .* %-%->%s*$") then
                replacement = replacement .. string.gsub(str,"^<%!%-%- (.*) %-%->(%s*)$", "%1\n")
            elseif not string.spacy(str) then
                replacement = replacement .. '<!-- ' .. string.gsub(str,"(%s*)$", '') .. " -->\n"
            else
                replacement = replacement .. str
            end
        else
            if string.find(str,"^%%D%s+$") then
                replacement = replacement .. "\n"
            elseif string.find(str,"^%%D ") then
                replacement = replacement .. string.gsub(str,"^%%D ", '')
            else
                replacement = replacement .. '%D ' .. str
            end
        end
    end

    editor:ReplaceSel(string.gsub(replacement, "[\n\r]$", ''))

end

function quote_text()

    local filetype, leftquotation, rightquotation = getfiletype(), '', ''

    if filetype == 'xml' then
        leftquotation, rightquotation = "<quotation>", "</quotation>"
        leftquote, rightquote = "<quotation>", "</quote>"
    else
        leftquotation, rightquotation = "\\quotation {", "}"
        leftquote, rightquote = "\\quote {", "}"
    end

    local replacement = editor:GetSelText()
    replacement = string.gsub(replacement, "\`\`(.-)\'\'", leftquotation .. "%1" .. rightquotation)
    replacement = string.gsub(replacement, "\"(.-)\"",     leftquotation .. "%1" .. rightquotation)
    replacement = string.gsub(replacement, "\`(.-)\'",     leftquote     .. "%1" .. rightquote    )
    replacement = string.gsub(replacement, "\'(.-)\'",     leftquote     .. "%1" .. rightquote    )
    editor:ReplaceSel(replacement)

end

function compound_text()

    local filetype = getfiletype()

    if filetype == 'xml' then
        editor:ReplaceSel(string.gsub(editor:GetSelText(),"(>[^<%-][^<%-]+)([-\/])(%w%w+)","%1<compound token='%2'/>%3"))
    else
        editor:ReplaceSel(string.gsub(editor:GetSelText(),"([^\|])([-\/]+)([^\|])","%1|%2|%3"))
    end

end

-- written while listening to Alanis Morissette's acoustic
-- Jagged Little Pill and Tori Amos' Beekeeper after
-- reinstalling on my good old ATH-7

local language = props["ctx.spellcheck.language"]
local wordsize = props["ctx.spellcheck.wordsize"]
local wordpath = props["ctx.spellcheck.wordpath"]

if language == '' then language = 'uk' end
if wordsize == '' then wordsize = 4    else wordsize = tonumber(wordsize) end

local wordfile = ""
local wordlist = {}
local worddone = 0

-- we use wordlist as a hash so that we can add entries without the
-- need to sort and also use a fast (built in) search

--~ function kpsewhich_file(filename,filetype,progname)
--~     local progflag, typeflag = '', ''
--~     local tempname = os.tmpname()
--~     if progname then
--~         progflag = " --progname=" .. progname .. " "
--~     end
--~     if filetype then
--~         typeflag = " --format=" .. filetype .. " "
--~     end
--~     local command = "kpsewhich" .. progflag .. typeflag .. " " .. filename .. " > " .. tempname
--~     os.execute(command)
--~     for line in io.lines(tempname) do
--~         return string.gsub(line, "\s*$", '')
--~     end
--~ end

function check_text()

    local dlanguage = props["ctx.spellcheck.language"]
    local dwordsize = props["ctx.spellcheck.wordsize"]
    local dwordpath = props["ctx.spellcheck.wordpath"]

    if dlanguage ~= '' then dlanguage = tostring(language) end
    if dwordsize ~= '' then dwordsize = tonumber(wordsize) end

    local firstline, skipfirst = editor:GetLine(0), false
    local filetype, wordskip, wordgood = getfiletype(), '', ''

    if filetype == 'tex' then
        wordskip  = "\\"
    elseif filetype  == 'xml' then
        wordskip  = "<"
        wordgood  = ">"
    end

    if props["ctx.spellcheck.language"] == 'auto' then
        if filetype == 'tex' then
            -- % version =1.0 language=uk
            firstline = string.gsub(firstline, "^%%%s*", '')
            firstline = string.gsub(firstline, "%s*$", '')
            for key, val in string.gfind(firstline,"(%w+)=(%w+)") do
                if key == "language" then
                    language = val
                    traceln("auto document language "  .. "'" .. language .. "' (tex)")
                end
            end
            skipfirst = true
        elseif filetype == 'xml' then
            -- <?xml version='1.0' language='uk' ?>
            firstline = string.gsub(firstline, "^%<%?xml%s*", '')
            firstline = string.gsub(firstline, "%s*%?%>%s*$", '')
            for key, val in string.gfind(firstline,"(%w+)=[\"\'](.-)[\"\']") do
                if key == "language" then
                    language = val
                    traceln("auto document language "  .. "'" .. language .. "' (xml)")
                end
            end
            skipfirst = true
        end
    end

    local fname = props["ctx.spellcheck.wordfile." .. language]
    local fsize = props["ctx.spellcheck.wordsize." .. language]

    if fsize ~= '' then wordsize = tonumber(fsize) end

    if fname ~= '' and fname ~= wordfile then
        wordfile, worddone, wordlist = fname, 0, {}
        for filename in string.gfind(wordfile,"[^%,]+") do
            if wordpath ~= '' then
                filename = string.expand(wordpath) .. '/' .. filename
            end
            if io.exists(filename) then
                traceln("loading " .. filename)
                for line in io.lines(filename) do
                    if not string.find(line,"^[\%\#\-]") then
                        str = string.gsub(line,"%s*$", '')
                        rawset(wordlist,str,true) -- table.insert(wordlist,str)
                        worddone = worddone + 1
                    end
                end
            else
                traceln("unknown file '" .. filename .."'")
            end
        end
        traceln(worddone .. " words loaded")
    end

    reset_text()

    if worddone == 0 then
        traceln("no (valid) language or wordfile specified")
    else
        traceln("start checking")
        if wordskip ~= '' then
            traceln("ignoring " .. wordskip .. "..." .. wordgood)
        end
        local i, j, lastpos, startpos, endpos, snippet, len, first = 0, 0, -1, 0, 0, '', 0, 0
        local ok, skip, ch = false, false, ''
        if skipfirst then first = string.len(firstline) end
        for k = first, editor.TextLength do
            ch = editor:textrange(k,k+1)
            if wordgood ~= '' and ch == wordgood then
                skip = false
            elseif ch == wordskip then
                skip = true
            end
            if string.find(ch,"%w") and not string.find(ch,"%d") then
                if not skip then
                    if ok then
                        endpos = k
                    else
                        startpos = k
                        endpos = k
                        ok = true
                    end
                end
            elseif ok and not skip then
                len = endpos - startpos + 1
                if len >= wordsize then
                    snippet = editor:textrange(startpos,endpos+1)
                    i = i + 1
                    if wordlist[snippet] or wordlist[string.lower(snippet)] then -- table.found(wordlist,snippet)
                        j = j + 1
                    else
                        editor:StartStyling(startpos,INDICS_MASK)
                        editor:SetStyling(len,INDIC2_MASK) -- INDIC0_MASK+2
                    end
                end
                ok = false
            elseif wordgood == '' then
                skip = (ch == wordskip)
            end
        end
        traceln(i .. " words checked, " .. (i-j) .. " errors")
    end

end

function reset_text()
    editor:StartStyling(0,INDICS_MASK)
    editor:SetStyling(editor.TextLength,INDIC_PLAIN)
end

-- templates

--~ function insert_text()

--~     local templatelist = props["ctx.template.list"]

--~     editor:insert(editor.CurrentPos,templatelist)
--~     show_menu(templatelist)
--~ end


-- menu

local menuactions = {}
local menutrigger = 12

function UserListShow(menuspec)
    local menuentries = {}
    local list = string.grab(menuspec,'[^%|]+')
    props["ctx.menulist.saved"] = menuspec
    for i=1, table.len(list) do
        if list[i] ~= '' then
            for key, val in string.gfind(list[i],"%s*(.+)=(.+)%s*") do
                if not string.find(val,"%(%)$") then
                    val = val .. "()"
                end
                table.insert(menuentries,key)
                rawset(menuactions,key,val)
            end
        end
    end
    editor.AutoCSeparator = string.byte('|')
    editor:UserListShow(menutrigger,table.join(menuentries,'|'))
    editor.AutoCSeparator = string.byte(' ')
end

function DoOnUserListSelection(trigger,choice,redoonerror)
    if trigger == menutrigger then
        if menuactions[choice] then
            assert(loadstring(menuactions[choice]))()
        elseif redoonerror then -- handy when reloaded lua script
        --  traceln("unknown action '" .. choice .. "', retrying")
            UserListShow(props["ctx.menulist.saved"])
            DoOnUserListSelection (trigger,choice,false)
        end
    end
end

function OnUserListSelection(trigger,choice)
    DoOnUserListSelection(trigger,choice,true)
end

function show_menu(menulist)
    UserListShow(menulist)
end

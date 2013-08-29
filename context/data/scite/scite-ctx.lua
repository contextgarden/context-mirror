-- version   : 1.0.0 - 07/2005 (2008: lua 5.1)
-- author    : Hans Hagen - PRAGMA ADE - www.pragma-ade.com
-- copyright : public domain or whatever suits
-- remark    : part of the context distribution, my first lua code

-- todo: name space for local functions
-- todo: the spell checking code is for the built-in lexer, the lpeg one uses its own

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
--     check=check_text\|
--     strip=toggle_strip
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

props = props or { } -- setmetatable(props,{ __index = function(k,v) props[k] = "unknown" return "unknown" end } )

local byte, lower, upper, gsub, sub, find, rep, match, gmatch, format = string.byte, string.lower, string.upper, string.gsub, string.sub, string.find, string.rep, string.match, string.gmatch, string.format
local sort, concat = table.sort, table.concat

local crlf = "\n"

function traceln(str)
    trace(str .. crlf)
    io.flush()
end

local function grab(str,delimiter)
    local list = { }
    for snippet in gmatch(str,delimiter) do
        list[#list+1] = snippet
    end
    return list
end

local function expand(str)
    return (gsub(str,"ENV%((%w+)%)", os.envvar))
end

local function strip(str)
    return (gsub(str,"^%s*(.-)%s*$", "%1"))
end

local function alphasort(list,i)
    if i and i > 0 then
        local function alphacmp(a,b)
            return lower(gsub(sub(a,i),'0',' ')) < lower(gsub(sub(b,i),'0',' '))
        end
        sort(list,alphacmp)
    else
        local function alphacmp(a,b)
            return lower(a) < lower(b)
        end
        sort(list,alphacmp)
    end
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
    local s = os.getenv(str)
    if s ~= '' then
        return s
    end
    s = os.getenv(upper(str))
    if s ~= '' then
        return s
    end
    s = os.getenv(lower(str))
    if s ~= '' then
        return s
    end
end

-- support functions, maybe editor namespace

-- function column_of_position(position)
--     local line = editor:LineFromPosition(position)
--     local oldposition = editor.CurrentPos
--     local column = 0
--     editor:GotoPos(position)
--     while editor.CurrentPos ~= 0 and line == editor:LineFromPosition(editor.CurrentPos) do
--         editor:CharLeft()
--         column = column + 1
--     end
--     editor:GotoPos(oldposition)
--     if line > 0 then
--         return column -1
--     else
--         return column
--     end
-- end

-- function line_of_position(position)
--     return editor:LineFromPosition(position)
-- end

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
        if selectionend ~= editor.SelectionEnd then
            break -- no progress
        end
    end
    editor:SetSel(selectionstart,selectionend)
    return selectionend
end

function getfiletype()
    local firstline = editor:GetLine(0) or ""
    if editor.Lexer == SCLEX_TEX then
        return 'tex'
    elseif editor.Lexer == SCLEX_XML then
        return 'xml'
    elseif find(firstline,"^%%") then
        return 'tex'
    elseif find(firstline,"^<%?xml") then
        return 'xml'
    else
        return 'unknown'
    end
end

-- inspired by LuaExt's scite_Files

function get_dir_list(mask)
    local f
    if props['PLAT_GTK'] and props['PLAT_GTK'] ~= "" then
        f = io.popen('ls -1 ' .. mask)
    else
        mask = gsub(mask,'/','\\')
        local tmpfile = 'scite-ctx.tmp'
        local cmd = 'dir /b "' .. mask .. '" > ' .. tmpfile
        os.execute(cmd)
        f = io.open(tmpfile)
    end
    local files = {}
    if not f then -- path check added
        return files
    end
    for line in f:lines() do
        files[#files+1] = line
    end
    f:close()
    return files
end

-- banner

do

    print("loading scite-ctx.lua definition file\n")
    print("-  see scite-ctx.properties for configuring info\n")
    print("-  ctx.spellcheck.wordpath set to " .. props['ctx.spellcheck.wordpath'])
    if find(lower(props['ctx.spellcheck.wordpath']),"ctxspellpath") then
        if os.getenv('ctxspellpath') then
            print("-  ctxspellpath set to " .. os.getenv('CTXSPELLPATH'))
        else
            print("-  'ctxspellpath is not set")
        end
        print("-  ctx.spellcheck.wordpath expands to " .. expand(props['ctx.spellcheck.wordpath']))
    end
    print("\n-  ctx.wraptext.length is set to " .. props['ctx.wraptext.length'])
    if props['ctx.helpinfo'] ~= '' then
        print("\n-  key bindings:\n")
        print((gsub(strip(props['ctx.helpinfo']),"%s*|%s*","\n")))
    end
    print("\n-  recognized first lines:\n")
    print("xml   <?xml version='1.0' language='nl'")
    print("tex   % language=nl")

end

-- text functions

-- written while listening to Talk Talk

local magicstring = rep("<ctx-crlf/>", 2)

function wrap_text()

    -- We always go to the end of a line, so in fact some of
    -- the variables set next are not needed.

    local length = props["ctx.wraptext.length"]

    if length == '' then length = 80 else length = tonumber(length) end

    local startposition = editor.SelectionStart
    local endposition   = editor.SelectionEnd

    if startposition == endposition then return end

    editor:LineEndExtend()

    startposition = editor.SelectionStart
    endposition   = editor.SelectionEnd

    -- local startline   = line_of_position(startposition)
    -- local endline     = line_of_position(endposition)
    -- local startcolumn = column_of_position(startposition)
    -- local endcolumn   = column_of_position(endposition)
    --
    -- editor:SetSel(startposition,endposition)

    local startline   = props['SelectionStartLine']
    local endline     = props['SelectionEndLine']
    local startcolumn = props['SelectionStartColumn'] - 1
    local endcolumn   = props['SelectionEndColumn'] - 1

    local replacement = { }
    local templine    = ''
    local indentation = rep(' ',startcolumn)
    local selection   = editor:GetSelText()

    selection = gsub(selection,"[\n\r][\n\r]","\n")
    selection = gsub(selection,"\n\n+",' ' .. magicstring .. ' ')
    selection = gsub(selection,"^%s",'')

    for snippet in gmatch(selection,"%S+") do
        if snippet == magicstring then
            replacement[#replacement+1] = templine
            replacement[#replacement+1] = ""
            templine = ''
        elseif #templine + #snippet > length then
            replacement[#replacement+1] = templine
            templine = indentation .. snippet
        elseif #templine == 0 then
            templine = indentation .. snippet
        else
            templine = templine .. ' ' .. snippet
        end
    end

    replacement[#replacement+1] = templine
    replacement[1] = gsub(replacement[1],"^%s+",'')

    if endcolumn == 0 then
        replacement[#replacement+1] = ""
    end

    editor:ReplaceSel(concat(replacement,"\n"))

end

function unwrap_text()

    local startposition = editor.SelectionStart
    local endposition   = editor.SelectionEnd

    if startposition == endposition then return end

    editor:HomeExtend()
    editor:LineEndExtend()

    startposition = editor.SelectionStart
    endposition   = editor.SelectionEnd

    local magicstring = rep("<multiplelines/>", 2)
    local selection   = gsub(editor:GetSelText(),"[\n\r][\n\r]+", ' ' .. magicstring .. ' ')
    local replacement = ''

    for snippet in gmatch(selection,"%S+") do
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

    local selection = gsub(editor:GetSelText(), "%s*$", '')
    local list = grab(selection,"[^\n\r]+")
    alphasort(list, startcolumn)
    local replacement = concat(list, "\n")

    editor:GotoPos(startposition)
    editor:SetSel(startposition,endposition)

    if endcolumn == 0 then replacement = replacement .. "\n" end

    editor:ReplaceSel(replacement)

end

function uncomment_xml()

    local startposition = editor.SelectionStart
    local endposition   = editor.SelectionEnd

    if startposition == endposition then return end

    local startposition = editor.SelectionStart
    local endposition   = editor.SelectionEnd

    local selection = gsub(editor:GetSelText(), "%<%!%-%-.-%-%-%>", '')

    editor:GotoPos(startposition)
    editor:SetSel(startposition,endposition)

    editor:ReplaceSel(selection)
    editor:GotoPos(startposition)

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
            if find(str,"^<%!%-%- .* %-%->%s*$") then
                replacement = replacement .. gsub(str,"^<%!%-%- (.*) %-%->(%s*)$","%1\n")
            elseif find(str,"%S") then
                replacement = replacement .. '<!-- ' .. gsub(str,"(%s*)$",'') .. " -->\n"
            else
                replacement = replacement .. str
            end
        else
            if find(str,"^%%D%s+$") then
                replacement = replacement .. "\n"
            elseif find(str,"^%%D ") then
                replacement = replacement .. gsub(str,"^%%D ",'')
            else
                replacement = replacement .. '%D ' .. str
            end
        end
    end

    editor:ReplaceSel(gsub(replacement,"[\n\r]$",''))

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
    replacement = gsub(replacement,"``(.-)\'\'",   leftquotation .. "%1" .. rightquotation)
    replacement = gsub(replacement,"\"(.-)\"",     leftquotation .. "%1" .. rightquotation)
    replacement = gsub(replacement,"`(.-)`",       leftquote     .. "%1" .. rightquote    )
    replacement = gsub(replacement,"\'(.-)\'",     leftquote     .. "%1" .. rightquote    )
    editor:ReplaceSel(replacement)

end

function compound_text()

    local filetype = getfiletype()

    if filetype == 'xml' then
        editor:ReplaceSel(gsub(editor:GetSelText(),"(>[^<%-][^<%-]+)([-/])(%w%w+)","%1<compound token='%2'/>%3"))
    else
        editor:ReplaceSel(gsub(editor:GetSelText(),"([^|])([-/]+)([^|])","%1|%2|%3"))
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

-- function kpsewhich_file(filename,filetype,progname)
--     local progflag, typeflag = '', ''
--     local tempname = os.tmpname()
--     if progname then
--         progflag = " --progname=" .. progname .. " "
--     end
--     if filetype then
--         typeflag = " --format=" .. filetype .. " "
--     end
--     local command = "kpsewhich" .. progflag .. typeflag .. " " .. filename .. " > " .. tempname
--     os.execute(command)
--     for line in io.lines(tempname) do
--         return gsub(line, "\s*$", '')
--     end
-- end

function check_text() -- obsolete, replaced by lexer

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
            firstline = gsub(firstline,"^%%%s*",'')
            firstline = gsub(firstline,"%s*$",'')
            for key, val in gmatch(firstline,"(%w+)=(%w+)") do
                if key == "language" then
                    language = val
                    traceln("auto document language "  .. "'" .. language .. "' (tex)")
                end
            end
            skipfirst = true
        elseif filetype == 'xml' then
            -- <?xml version='1.0' language='uk' ?>
            firstline = gsub(firstline,"^%<%?xml%s*", '')
            firstline = gsub(firstline,"%s*%?%>%s*$", '')
            for key, val in gmatch(firstline,"(%w+)=[\"\'](.-)[\"\']") do
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
        for filename in gmatch(wordfile,"[^%,]+") do
            if wordpath ~= '' then
                filename = expand(wordpath) .. '/' .. filename
            end
            if io.exists(filename) then
                traceln("loading " .. filename)
                for line in io.lines(filename) do
                    if not find(line,"^[%#-]") then
                        str = gsub(line,"%s*$", '')
                        rawset(wordlist,str,true)
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
        if skipfirst then first = #firstline end
        for k = first, editor.TextLength do
            ch = editor:textrange(k,k+1)
            if wordgood ~= '' and ch == wordgood then
                skip = false
            elseif ch == wordskip then
                skip = true
            end
            if find(ch,"%w") and not find(ch,"%d") then
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
                    if wordlist[snippet] or wordlist[lower(snippet)] then
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

function add_text()

    local startposition = editor.SelectionStart
    local endposition   = editor.SelectionEnd

    if startposition == endposition then return end

    local selection = gsub(editor:GetSelText(), "%s*$", '')

    local n, sum = 0, 0
    for s in gmatch(selection,"[%d%.%,]+") do
        s = gsub(s,",",".")
        local m = tonumber(s)
        if m then
            n = n + 1
            sum = sum + m
            traceln(format("%4i : %s",n,m))
        end
    end
    if n > 0 then
        traceln("")
        traceln(format("sum  : %s",sum))
    else
        traceln("no numbers selected")
    end

end

-- menu

local menuactions   = {}
local menufunctions = {}

function UserListShow(menutrigger, menulist)
    local menuentries = {}
    local list = grab(menulist,"[^%|]+")
    menuactions = {}
    for i=1, #list do
        if list[i] ~= '' then
            for key, val in gmatch(list[i],"%s*(.+)=(.+)%s*") do
                menuentries[#menuentries+1] = key
                menuactions[key] = val
            end
        end
    end
    local menustring = concat(menuentries,'|')
    if menustring == "" then
        traceln("There are no templates defined for this file type.")
    else
        editor.AutoCSeparator = byte('|')
        editor:UserListShow(menutrigger,menustring)
        editor.AutoCSeparator = byte(' ')
    end
end

function OnUserListSelection(trigger,choice)
    if menufunctions[trigger] and menuactions[choice] then
        return menufunctions[trigger](menuactions[choice])
    else
        return false
    end
end

-- main menu

local menutrigger = 12

function show_menu(menulist)
    UserListShow(menutrigger, menulist)
end

function process_menu(action)
    if not find(action,"%(%)$") then
        assert(loadstring(action .. "()"))()
    else
        assert(loadstring(action))()
    end
end

menufunctions[12] = process_menu

-- templates

local templatetrigger = 13

local ctx_template_paths = { "./ctx-templates", "../ctx-templates", "../../ctx-templates" }
local ctx_auto_templates = false
local ctx_template_list  = ""

local ctx_path_list      = {}
local ctx_path_done      = {}
local ctx_path_name      = {}

function ctx_list_loaded(path)
    return ctx_path_list[path] and #ctx_path_list[path] > 0
end

function insert_template(templatelist)
    if props["ctx.template.scan"] == "yes" then
        local path    = props["FileDir"]
        local rescan  = props["ctx.template.rescan"] == "yes"
        local suffix  = props["ctx.template.suffix." .. props["FileExt"]] -- alas, no suffix expansion here
        local current = path .. "+" .. props["FileExt"]
        if rescan then
            print("re-scanning enabled")
        end
        ctx_template_list = ""
        if not ctx_path_done[path] or rescan then
            local pattern = "*.*"
            for i, pathname in ipairs(ctx_template_paths) do
                print("scanning " .. gsub(path,"\\","/") .. "/" .. pathname)
                ctx_path_name[path] = pathname
                ctx_path_list[path] = get_dir_list(pathname .. "/" .. pattern)
                if ctx_list_loaded(path) then
                    print("finished locating template files")
                    break
                end
            end
            if ctx_list_loaded(path) then
                print(#ctx_path_list[path] .. " template files found")
            else
                print("no template files found")
            end
        end
        if ctx_list_loaded(path) then
            ctx_template_list = ""
            local pattern = "%." .. suffix .. "$"
            local n = 0
            for j, filename in ipairs(ctx_path_list[path]) do
                if find(filename,pattern) then
                    n = n + 1
                    local menuname = gsub(filename,"%..-$","")
                    if ctx_template_list ~= "" then
                        ctx_template_list = ctx_template_list .. "|"
                    end
                    ctx_template_list = ctx_template_list .. menuname .. "=" .. ctx_path_name[path] .. "/" .. filename
                end
            end
            if not ctx_path_done[path] then
                print(n .. " suitable template files found")
            end
        end
        ctx_path_done[path] = true
        if ctx_template_list == "" then
            ctx_auto_templates = false
        else
            ctx_auto_templates = true
            templatelist = ctx_template_list
        end
    else
        ctx_auto_templates = false
    end
    if templatelist ~= "" then
        UserListShow(templatetrigger, templatelist)
    end
end


-- ctx.template.[whatever].[filetype]
-- ctx.template.[whatever].data.[filetype]
-- ctx.template.[whatever].file.[filetype]
-- ctx.template.[whatever].list.[filetype]

function process_template_one(action)
    local text = nil
    if ctx_auto_templates then
        local f = io.open(action,"r")
        if f then
            text = gsub(f:read("*all"),"\n$","")
            f:close()
        else
            print("unable to auto load template file " .. text)
            text = nil
        end
    end
    if not text or text == "" then
        text = props["ctx.template." .. action .. ".file"]
        if not text or text == "" then
            text = props["ctx.template." .. action .. ".data"]
            if not text or text == "" then
                text = props["ctx.template." .. action]
            end
        else
            local f = io.open(text,"r")
            if f then
                text = gsub(f:read("*all"),"\n$","")
                f:close()
            else
                print("unable to load template file " .. text)
                text = nil
            end
        end
    end
    if text then
        text = gsub(text,"\\n","\n")
        local pos = find(text,"%?")
        text = gsub(text,"%?","")
        editor:insert(editor.CurrentPos,text)
        if pos then
            editor.CurrentPos = editor.CurrentPos + pos - 1
            editor.SelectionStart = editor.CurrentPos
            editor.SelectionEnd = editor.CurrentPos
            editor:GotoPos(editor.CurrentPos)
        end
    end
end

menufunctions[13] = process_template_one
menufunctions[14] = process_template_two

-- command.name.26.*=Open Logfile
-- command.subsystem.26.*=3
-- command.26.*=open_log
-- command.save.before.26.*=2
-- command.groupundo.26.*=yes
-- command.shortcut.26.*=Ctrl+E

function open_log()
   scite.Open(props['FileName'] .. ".log")
end

if not lpeg then

    local okay, root = pcall(function() return require "lpeg" end)

    if okay then
        lpeg = root
    else
        trace("\nwarning: lpeg not loaded\n")
    end

end

local lists = { -- taken from sort-lan.lua
    en = {
        "a", "b", "c", "d", "e", "f", "g", "h", "i", "j",
        "k", "l", "m", "n", "o", "p", "q", "r", "s", "t",
        "u", "v", "w", "x", "y", "z",

        "A", "B", "C", "D", "E", "F", "G", "H", "I", "J",
        "K", "L", "M", "N", "O", "P", "Q", "R", "S", "T",
        "U", "V", "W", "X", "Y", "Z",
    },
    nl = {
        "a", "b", "c", "d", "e", "f", "g", "h", "i", "j",
        "k", "l", "m", "n", "o", "p", "q", "r", "s", "t",
        "u", "v", "w", "x", "y", "z",

        "A", "B", "C", "D", "E", "F", "G", "H", "I", "J",
        "K", "L", "M", "N", "O", "P", "Q", "R", "S", "T",
        "U", "V", "W", "X", "Y", "Z",
    },
    fr = {
        "a", "b", "c", "d", "e", "f", "g", "h", "i", "j",
        "k", "l", "m", "n", "o", "p", "q", "r", "s", "t",
        "u", "v", "w", "x", "y", "z",

        "A", "B", "C", "D", "E", "F", "G", "H", "I", "J",
        "K", "L", "M", "N", "O", "P", "Q", "R", "S", "T",
        "U", "V", "W", "X", "Y", "Z",
    },
    de = {
        "a", "ä", "b", "c", "d", "e", "f", "g", "h", "i",
        "j", "k", "l", "m", "n", "o", "ö", "p", "q", "r",
        "s", "ß", "t", "u", "ü", "v", "w", "x", "y", "z",

        "A", "Ä", "B", "C", "D", "E", "F", "G", "H", "I",
        "J", "K", "L", "M", "N", "O", "Ö", "P", "Q", "R",
        "S", "SS", "T", "U", "Ü", "V", "W", "X", "Y", "Z",
    },
    fi = { -- finish
        "a", "b", "c", "d", "e", "f", "g", "h", "i", "j",
        "k", "l", "m", "n", "o", "p", "q", "r", "s", "t",
        "u", "v", "w", "x", "y", "z", "å", "ä", "ö",

        "A", "B", "C", "D", "E", "F", "G", "H", "I", "J",
        "K", "L", "M", "N", "O", "P", "Q", "R", "S", "T",
        "U", "V", "W", "X", "Y", "Z", "Å", "Ä", "Ö",
    },
    sl = { -- slovenian
        "a", "b", "c", "č", "ć", "d", "đ", "e", "f", "g", "h", "i",
        "j", "k", "l", "m", "n", "o", "p", "q", "r", "s", "š", "t",
        "u", "v", "w", "x", "y", "z", "ž",

        "A", "B", "C", "Č", "Ć", "D", "Đ", "E", "F", "G", "H", "I",
        "J", "K", "L", "M", "N", "O", "P", "Q", "R", "S", "Š", "T",
        "U", "V", "W", "X", "Y", "Z", "Ž",
    },
    ru = { -- rusian
        "а", "б", "в", "г", "д", "е", "ё", "ж", "з", "и",
        "і", "й", "к", "л", "м", "н", "о", "п", "р", "с",
        "т", "у", "ф", "х", "ц", "ч", "ш", "щ", "ъ", "ы",
        "ь", "ѣ", "э", "ю", "я", "ѳ", "ѵ",

        "А", "Б", "В", "Г", "Д", "Е", "Ё", "Ж", "З", "И",
        "І", "Й", "К", "Л", "М", "Н", "О", "П", "Р", "С",
        "Т", "У", "Ф", "Х", "Ц", "Ч", "Ш", "Щ", "Ъ", "Ы",
        "Ь", "Ѣ", "Э", "Ю", "Я", "Ѳ", "Ѵ",
    },
    uk = { -- ukraninuan
        "а", "б", "в", "г", "ґ", "д", "е", "є", "ж", "з", "и", "і",
        "ї", "й", "к", "л", "м", "н", "о", "п", "р", "с", "т", "у",
        "ф", "х", "ц", "ч", "ш", "щ", "ь", "ю", "я",

        "А", "Б", "В", "Г", "Ґ", "Д", "Е", "Є", "Ж", "З", "И", "І",
        "Ї", "Й", "К", "Л", "М", "Н", "О", "П", "Р", "С", "Т", "У",
        "Ф", "Х", "Ц", "Ч", "Ш", "Щ", "Ь", "Ю", "Я",
    },
    be = { -- belarusia
        "а", "б", "в", "г", "д", "е", "ё", "ж", "з", "і",
        "й", "к", "л", "м", "н", "о", "п", "р", "с", "т",
        "у", "ў", "ф", "х", "ц", "ч", "ш", "ы", "ь", "э",
        "ю", "я",

        "А", "Б", "В", "Г", "Д", "Е", "Ё", "Ж", "З", "І",
        "Й", "К", "Л", "М", "Н", "О", "П", "Р", "С", "Т",
        "У", "Ў", "Ф", "Х", "Ц", "Ч", "Ш", "Ы", "Ь", "Э",
        "Ю", "Я",
    },
    bg = { -- bulgarian
        "а", "б", "в", "г", "д", "е", "ж", "з","и", "й",
        "к", "a", "л", "a", "м", "н", "о", "п", "р", "с",
        "т", "у", "ф", "х", "ц", "ч", "ш", "щ", "ъ", "ь",
        "ю", "я",

        "А", "Б", "В", "Г", "Д", "Е", "Ж", "З","И", "Й",
        "К", "A", "Л", "A", "М", "Н", "О", "П", "Р", "С",
        "Т", "У", "Ф", "Х", "Ц", "Ч", "Ш", "Щ", "Ъ", "Ь",
        "Ю", "Я",
    },
    pl = { -- polish
        "a", "ą", "b", "c", "ć", "d", "e", "ę", "f", "g",
        "h", "i", "j", "k", "l", "ł", "m", "n", "ń", "o",
        "ó", "p", "q", "r", "s", "ś", "t", "u", "v", "w",
        "x", "y", "z", "ź", "ż",

        "A", "Ą", "B", "C", "Ć", "D", "E", "Ę", "F", "G",
        "H", "I", "J", "K", "L", "Ł", "M", "N", "Ń", "O",
        "Ó", "P", "Q", "R", "S", "Ś", "T", "U", "V", "W",
        "X", "Y", "Z", "Ź", "Ż",
    },
    cz = { -- czech
        "a", "á", "b", "c", "č", "d", "ď", "e", "é", "ě",
        "f", "g", "h", "i", "í", "j", "k", "l", "m",
        "n", "ň", "o", "ó", "p", "q", "r", "ř", "s", "š",
        "t", "ť", "u", "ú",  "ů", "v", "w", "x",  "y", "ý",
        "z", "ž",

        "A", "Á", "B", "C", "Č", "D", "Ď", "E", "É", "Ě",
        "F", "G", "H", "I", "Í", "J", "K", "L", "M",
        "N", "Ň", "O", "Ó", "P", "Q", "R", "Ř", "S", "Š",
        "T", "Ť", "U", "Ú",  "Ů", "V", "W", "X",  "Y", "Ý",
        "Z", "Ž",
    },
    sk = { -- slovak
        "a", "á", "ä", "b", "c", "č", "d", "ď",
        "e", "é", "f", "g", "h", ch,  "i", "í", "j", "k",
        "l", "ĺ", "ľ", "m", "n", "ň", "o", "ó", "ô", "p",
        "q", "r", "ŕ", "s", "š", "t", "ť", "u", "ú", "v",
        "w", "x", "y", "ý", "z", "ž",

        "A", "Á", "Ä", "B", "C", "Č", "D", "Ď",
        "E", "É", "F", "G", "H", "I", "Í", "J", "K",
        "L", "Ĺ", "Ľ", "M", "N", "Ň", "O", "Ó", "Ô", "P",
        "Q", "R", "Ŕ", "S", "Š", "T", "Ť", "U", "Ú", "V",
        "W", "X", "Y", "Ý", "Z", "Ž",
    },
    hr = { -- croatian
        "a", "b", "c", "č", "ć", "d", "đ", "e", "f",
        "g", "h", "i", "j", "k", "l", "m", "n",
        "o", "p", "r", "s", "š", "t", "u", "v", "z", "ž",

        "A", "B", "C", "Č", "Ć", "D", "Đ", "E", "F",
        "G", "H", "I", "J", "K", "L", "M", "N",
        "O", "P", "R", "S", "Š", "T", "U", "V", "Z", "Ž",
    },
    sr = { -- serbian
        "а", "б", "в", "г", "д", "ђ", "е", "ж", "з", "и",
        "ј", "к", "л", "љ", "м", "н", "њ", "о", "п", "р",
        "с", "т", "ћ", "у", "ф", "х", "ц", "ч", "џ", "ш",

        "А", "Б", "В", "Г", "Д", "Ђ", "Е", "Ж", "З", "И",
        "Ј", "К", "Л", "Љ", "М", "Н", "Њ", "О", "П", "Р",
        "С", "Т", "Ћ", "У", "Ф", "Х", "Ц", "Ч", "Џ", "Ш",
    },
    no = { -- norwegian
        "a", "b", "c", "d", "e", "f", "g", "h", "i", "j",
        "k", "l", "m", "n", "o", "p", "q", "r", "s", "t",
        "u", "v", "w", "x", "y", "z", "æ", "ø", "å",

        "A", "B", "C", "D", "E", "F", "G", "H", "I", "J",
        "K", "L", "M", "N", "O", "P", "Q", "R", "S", "T",
        "U", "V", "W", "X", "Y", "Z", "Æ", "Ø", "Å",
    },
    da = { --danish
        "a", "b", "c", "d", "e", "f", "g", "h", "i", "j",
        "k", "l", "m", "n", "o", "p", "q", "r", "s", "t",
        "u", "v", "w", "x", "y", "z", "æ", "ø", "å",

        "A", "B", "C", "D", "E", "F", "G", "H", "I", "J",
        "K", "L", "M", "N", "O", "P", "Q", "R", "S", "T",
        "U", "V", "W", "X", "Y", "Z", "Æ", "Ø", "Å",
    },
    sv = { -- swedish
        "a", "b", "c", "d", "e", "f", "g", "h", "i", "j",
        "k", "l", "m", "n", "o", "p", "q", "r", "s", "t",
        "u", "v", "w", "x", "y", "z", "å", "ä", "ö",

        "A", "B", "C", "D", "E", "F", "G", "H", "I", "J",
        "K", "L", "M", "N", "O", "P", "Q", "R", "S", "T",
        "U", "V", "W", "X", "Y", "Z", "Å", "Ä", "Ö",
    },
    is = { -- islandic
        "a", "á", "b", "d", "ð", "e", "é", "f", "g", "h",
        "i", "í", "j", "k", "l", "m", "n", "o", "ó", "p",
        "r", "s", "t", "u", "ú", "v", "x", "y", "ý", "þ",
        "æ", "ö",

        "A", "Á", "B", "D", "Ð", "E", "É", "F", "G", "H",
        "I", "Í", "J", "K", "L", "M", "N", "O", "Ó", "P",
        "R", "S", "T", "U", "Ú", "V", "X", "Y", "Ý", "Þ",
        "Æ", "Ö",
    },
 -- gr = { -- greek
 --     "α", "ά", "ὰ", "ᾶ", "ᾳ", "ἀ", "ἁ", "ἄ", "ἂ", "ἆ",
 --     "ἁ", "ἅ", "ἃ", "ἇ", "ᾁ", "ᾴ", "ᾲ", "ᾷ", "ᾄ", "ᾂ",
 --     "ᾅ", "ᾃ", "ᾆ", "ᾇ", "β", "γ", "δ", "ε", "έ", "ὲ",
 --     "ἐ", "ἔ", "ἒ", "ἑ", "ἕ", "ἓ", "ζ", "η", "η", "ή",
 --     "ὴ", "ῆ", "ῃ", "ἠ", "ἤ", "ἢ", "ἦ", "ᾐ", "ἡ", "ἥ",
 --     "ἣ", "ἧ", "ᾑ", "ῄ", "ῂ", "ῇ", "ᾔ", "ᾒ", "ᾕ", "ᾓ",
 --     "ᾖ", "ᾗ", "θ", "ι", "ί", "ὶ", "ῖ", "ἰ", "ἴ", "ἲ",
 --     "ἶ", "ἱ", "ἵ", "ἳ", "ἷ", "ϊ", "ΐ", "ῒ", "ῗ", "κ",
 --     "λ", "μ", "ν", "ξ", "ο", "ό", "ὸ", "ὀ", "ὄ", "ὂ",
 --     "ὁ", "ὅ", "ὃ", "π", "ρ", "ῤ", "ῥ", "σ", "ς", "τ",
 --     "υ", "ύ", "ὺ", "ῦ", "ὐ", "ὔ", "ὒ", "ὖ", "ὑ", "ὕ",
 --     "ὓ", "ὗ", "ϋ", "ΰ", "ῢ", "ῧ", "φ", "χ", "ψ", "ω",
 --     "ώ", "ὼ", "ῶ", "ῳ", "ὠ", "ὤ", "ὢ", "ὦ", "ᾠ", "ὡ",
 --     "ὥ", "ὣ", "ὧ", "ᾡ", "ῴ", "ῲ", "ῷ", "ᾤ", "ᾢ", "ᾥ",
 --     "ᾣ", "ᾦ", "ᾧ",
 --
 --     "Α", "Ά", "Ὰ", "Α͂", "Ἀ", "Ἁ", "Ἄ", "Ἂ", "Ἆ",
 --     "Ἁ", "Ἅ", "Ἃ", "Ἇ",
 --     "Β", "Γ", "Δ", "Ε", "Έ", "Ὲ",
 --     "Ἐ", "Ἔ", "Ἒ", "Ἑ", "Ἕ", "Ἓ", "Ζ", "Η", "Η", "Ή",
 --     "Ὴ", "Η͂", "Ἠ", "Ἤ", "Ἢ", "Ἦ", "Ἡ", "Ἥ",
 --     "Ἣ", "Ἧ",
 --     "Θ", "Ι", "Ί", "Ὶ", "Ι͂", "Ἰ", "Ἴ", "Ἲ",
 --     "Ἶ", "Ἱ", "Ἵ", "Ἳ", "Ἷ", "Ϊ", "Ϊ́", "Ϊ̀", "Ϊ͂", "Κ",
 --     "Λ", "Μ", "Ν", "Ξ", "Ο", "Ό", "Ὸ", "Ὀ", "Ὄ", "Ὂ",
 --     "Ὁ", "Ὅ", "Ὃ", "Π", "Ρ", "Ρ̓", "Ῥ", "Σ", "Σ", "Τ",
 --     "Υ", "Ύ", "Ὺ", "Υ͂", "Υ̓", "Υ̓́", "Υ̓̀", "Υ̓͂", "Ὑ", "Ὕ",
 --     "Ὓ", "Ὗ", "Ϋ", "Ϋ́", "Ϋ̀", "Ϋ͂", "Φ", "Χ", "Ψ", "Ω",
 --     "Ώ", "Ὼ", "Ω͂", "Ὠ", "Ὤ", "Ὢ", "Ὦ", "Ὡ",
 --     "Ὥ", "Ὣ", "Ὧ",
 --     },
    gr = { -- greek
        "α", "β", "γ", "δ", "ε", "ζ", "η", "θ", "ι", "κ",
        "λ", "μ", "ν", "ξ", "ο", "π", "ρ", "ς", "τ", "υ",
        "φ", "χ", "ψ", "ω",

        "Α", "Β", "Γ", "Δ", "Ε", "Ζ", "Η", "Θ", "Ι", "Κ",
        "Λ", "Μ", "Ν", "Ξ", "Ο", "Π", "Ρ", "Σ", "Τ", "Υ",
        "Χ", "Ψ", "Ω",
        },
    la = { -- latin
        "a", "ā", "ă", "b", "c", "d", "e", "ē", "ĕ", "f",
        "g", "h", "i", "ī", "ĭ", "j", "k", "l", "m", "n",
        "o", "ō", "ŏ", "p", "q", "r", "s", "t", "u", "ū",
        "ŭ", "v", "w", "x", "y", "ȳ", "y̆", "z", "æ",

        "A", "Ā", "Ă", "B", "C", "D", "E", "Ē", "Ĕ", "F",
        "G", "H", "I", "Ī", "Ĭ", "J", "K", "L", "M", "N",
        "O", "Ō", "Ŏ", "P", "Q", "R", "S", "T", "U", "Ū",
        "Ŭ", "V", "W", "X", "Y", "Ȳ", "Y̆", "Z", "Æ",
    },
    it = { -- italian
        "a", "á", "b", "c", "d", "e", "é", "è", "f", "g",
        "h", "i", "í", "ì", "j", "k", "l", "m", "n", "o",
        "ó", "ò", "p", "q", "r", "s", "t", "u", "ú", "ù",
        "v", "w", "x", "y", "z",

        "A", "Á", "B", "C", "D", "E", "É", "È", "F", "G",
        "H", "I", "Í", "Ì", "J", "K", "L", "M", "N", "O",
        "Ó", "Ò", "P", "Q", "R", "S", "T", "U", "Ú", "Ù",
        "V", "W", "X", "Y", "Z",
    },
    ro = { -- romanian
        "a", "ă", "â", "b", "c", "d", "e", "f", "g", "h",
        "i", "î", "j", "k", "l", "m", "n", "o", "p", "q",
        "r", "s", "ș", "t", "ț", "u", "v", "w", "x", "y",
        "z",

        "A", "Ă", "Â", "B", "C", "D", "E", "F", "G", "H",
        "I", "Î", "J", "K", "L", "M", "N", "O", "P", "Q",
        "R", "S", "Ș", "T", "Ț", "U", "V", "W", "X", "Y",
        "Z",
    },
    es = { -- spanish
        "a", "á", "b", "c", "d", "e", "é", "f", "g", "h",
        "i", "í", "j", "k", "l", "m", "n", "ñ", "o", "ó",
        "p", "q", "r", "s", "t", "u", "ú", "ü", "v", "w",
        "x", "y", "z",

        "A", "Á", "B", "C", "D", "E", "É", "F", "G", "H",
        "I", "Í", "J", "K", "L", "M", "N", "Ñ", "O", "Ó",
        "P", "Q", "R", "S", "T", "U", "Ú", "Ü", "V", "W",
        "X", "Y", "Z",
    },
    pt = { -- portuguese
        "a", "á", "â", "ã", "à", "b", "c", "ç", "d", "e",
        "é", "ê", "f", "g", "h", "i", "í", "j", "k", "l",
        "m", "n", "o", "ó", "ô", "õ", "p", "q", "r", "s",
        "t", "u", "ú", "ü", "v", "w", "x", "y", "z",

        "A", "Á", "Â", "Ã", "À", "B", "C", "Ç", "D", "E",
        "É", "Ê", "F", "G", "H", "I", "Í", "J", "K", "L",
        "M", "N", "O", "Ó", "Ô", "Õ", "P", "Q", "R", "S",
        "T", "U", "Ú", "Ü", "V", "W", "X", "Y", "Z",
    },
    lt = { -- lithuanian
        "a", "ą", "b", "c", ch,  "č", "d", "e", "ę", "ė",
        "f", "g", "h", "i", "į", "y", "j", "k", "l", "m",
        "n", "o", "p", "r", "s", "š", "t", "u", "ų", "ū",
        "v", "z", "ž",

        "A", "Ą", "B", "C", CH,  "Č", "D", "E", "Ę", "Ė",
        "F", "G", "H", "I", "Į", "Y", "J", "K", "L", "M",
        "N", "O", "P", "R", "S", "Š", "T", "U", "Ų", "Ū",
        "V", "Z", "Ž",
    },
    lv = { -- latvian
        "a", "ā", "b", "c", "č", "d", "e", "ē", "f", "g",
        "ģ", "h", "i", "ī", "j", "k", "ķ", "l", "ļ", "m",
        "n", "ņ", "o", "ō", "p", "r", "ŗ", "s", "š", "t",
        "u", "ū", "v", "z", "ž",

        "A", "Ā", "B", "C", "Č", "D", "E", "Ē", "F", "G",
        "Ģ", "H", "I", "Ī", "J", "K", "Ķ", "L", "Ļ", "M",
        "N", "Ņ", "O", "Ō", "P", "R", "Ŗ", "S", "Š", "T",
        "U", "Ū", "V", "Z", "Ž",
    },
    hu = { -- hungarian
        "a", "á", "b", "c", "d", "e", "é",
        "f", "g", "h", "i", "í", "j", "k", "l",
        "m", "n", "o", "ó", "ö", "ő", "p", "q", "r",
        "s",  "t", "u", "ú", "ü", "ű", "v", "w",
        "x", "y", "z",

        "A", "Á", "B", "C", "D", "E", "É",
        "F", "G", "H", "I", "Í", "J", "K", "L",
        "M", "N", "O", "Ó", "Ö", "Ő", "P", "Q", "R",
        "S",  "T", "U", "Ú", "Ü", "Ű", "V", "W",
        "X", "Y", "Z",
    },
    et = { -- estonian
        "a", "b", "d", "e", "f", "g", "h", "i", "j", "k",
        "l", "m", "n", "o", "p", "r", "s", "š", "z", "ž",
        "t", "u", "v", "w", "õ", "ä", "ö", "ü", "x", "y",

        "A", "B", "D", "E", "F", "G", "H", "I", "J", "K",
        "L", "M", "N", "O", "P", "R", "S", "Š", "Z", "Ž",
        "T", "U", "V", "W", "Õ", "Ä", "Ö", "Ü", "X", "Y",
    },
 -- jp = { -- japanese
 --     "あ", "い", "う", "え", "お", "か", "き", "く", "け", "こ",
 --     "さ", "し", "す", "せ", "そ", "た", "ち", "つ", "て", "と",
 --     "な", "に", "ぬ", "ね", "の", "は", "ひ", "ふ", "へ", "ほ",
 --     "ま", "み", "む", "め", "も", "や", "ゆ", "よ",
 --     "ら", "り", "る", "れ", "ろ", "わ", "ゐ", "ゑ", "を", "ん",
 -- },
}

local enabled  = false
local language = "en"
local selector = { }

for k, v in next, lists do
    selector[#selector+1] = k
end

table.sort(selector)

local function make_strip()
    local alphabet = lists[language] or lists.en
    local selector = "(hide)(" .. table.concat(selector,")(") .. ")"
    local alphabet = "(" .. language .. ":)(" .. table.concat(alphabet,")(") .. ")"
    scite.StripShow(selector .. "\n" .. alphabet)
    enabled = true
end

local function hide_strip()
    scite.StripShow("")
    enabled = false
end

local function process_strip(control)
    local value = scite.StripValue(control)
    if value == "hide" then
        hide_strip()
    elseif lists[value] then
        language = value
        make_strip()
    elseif value == language .. ":" then
        -- ignore
    else
        local char = value
        trace("inserted character: " .. char .. "\n")
        editor:insert(editor.CurrentPos,char)
    end
end

function toggle_strip()
    if enabled then
        hide_strip()
        OnStrip = function() end
    else
        make_strip()
        OnStrip = process_strip
    end
end

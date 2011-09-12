-- version   : 1.0.0 - 07/2005 (2008: lua 5.1)
-- author    : Hans Hagen - PRAGMA ADE - www.pragma-ade.com
-- copyright : public domain or whatever suits
-- remark    : part of the context distribution, my first lua code

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

props = props or { } setmetatable(props,{ __index = function(k,v) props[k] = "unknown" return "unknown" end } )

local byte, lower, upper, gsub, sub, find, rep, match, gmatch = string.byte, string.lower, string.upper, string.gsub, string.sub, string.find, string.rep, string.match, string.gmatch
local sort, concat = table.sort, table.concat

local crlf = "\n"

function traceln(str)
    trace(str .. crlf)
    io.flush()
end

function string:grab(delimiter)
    local list = {}
    for snippet in self:gmatch(delimiter) do
        list[#list+1] = snippet
    end
    return list
end

function string:expand()
    return (self:gsub("ENV%((%w+)%)", os.envvar))
end

function string:strip()
    return (self:gsub("^%s*(.-)%s*$", "%1"))
end

function table.alphasort(list,i)
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
        print("-  ctx.spellcheck.wordpath expands to " .. string.expand(props['ctx.spellcheck.wordpath']))
    end
    print("\n-  ctx.wraptext.length is set to " .. props['ctx.wraptext.length'])
    if props['ctx.helpinfo'] ~= '' then
        print("\n-  key bindings:\n")
        print((gsub(string.strip(props['ctx.helpinfo']),"%s*\|%s*","\n")))
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

    list = string.grab(selection,"[^\n\r]+")
    table.alphasort(list, startcolumn)
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
    replacement = gsub(replacement,"\`\`(.-)\'\'", leftquotation .. "%1" .. rightquotation)
    replacement = gsub(replacement,"\"(.-)\"",     leftquotation .. "%1" .. rightquotation)
    replacement = gsub(replacement,"\`(.-)\'",     leftquote     .. "%1" .. rightquote    )
    replacement = gsub(replacement,"\'(.-)\'",     leftquote     .. "%1" .. rightquote    )
    editor:ReplaceSel(replacement)

end

function compound_text()

    local filetype = getfiletype()

    if filetype == 'xml' then
        editor:ReplaceSel(gsub(editor:GetSelText(),"(>[^<%-][^<%-]+)([-\/])(%w%w+)","%1<compound token='%2'/>%3"))
    else
        editor:ReplaceSel(gsub(editor:GetSelText(),"([^\|])([-\/]+)([^\|])","%1|%2|%3"))
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
                filename = string.expand(wordpath) .. '/' .. filename
            end
            if io.exists(filename) then
                traceln("loading " .. filename)
                for line in io.lines(filename) do
                    if not find(line,"^[\%\#\-]") then
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

-- menu

local menuactions   = {}
local menufunctions = {}

function UserListShow(menutrigger, menulist)
    local menuentries = {}
    local list = string.grab(menulist,"[^%|]+")
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

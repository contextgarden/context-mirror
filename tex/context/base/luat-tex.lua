-- filename : luat-zip.lua
-- comment  : companion to luat-lib.tex
-- author   : Hans Hagen, PRAGMA-ADE, Hasselt NL
-- copyright: PRAGMA ADE / ConTeXt Development Team
-- license  : see context related readme files

if not versions then versions = { } end versions['luat-tex'] = 1.001

-- special functions that deal with io

if texconfig and not texlua then

    input.level = input.level or 0

    if input.logmode() == 'xml' then
        function input.show_open(name)
            input.level = input.level + 1
            texio.write_nl("<f l='"..input.level.."' n='"..name.."'>")
        end
        function input.show_close(name)
            texio.write("</f> ")
            input.level = input.level - 1
        end
        function input.show_load(name)
            texio.write_nl("<f l='"..(input.level+1).."' n='"..name.."'/>") -- level?
        end
    else
        function input.show_open () end
        function input.show_close() end
        function input.show_load () end
    end

    function input.finders.generic(instance,tag,filename,filetype)
        local foundname = input.find_file(instance,filename,filetype)
        if foundname and foundname ~= "" then
            input.logger('+ ' .. tag .. ' finder',filename,'filetype')
            return foundname
        else
            input.logger('- ' .. tag .. ' finder',filename,'filetype')
            return unpack(input.finders.notfound)
        end
    end

    input.filters.dynamic_translator = nil
    input.filters.frozen_translator  = nil
    input.filters.utf_translator     = nil

    function input.openers.text_opener(filename,file_handle,tag)
        local u = unicode.utftype(file_handle)
        local t = { }
        if u > 0  then
            input.logger('+ ' .. tag .. ' opener (' .. unicode.utfname[u] .. ')',filename)
            local l
            if u > 2 then
                l = unicode.utf32_to_utf8(file_handle:read("*a"),u==4)
            else
                l = unicode.utf16_to_utf8(file_handle:read("*a"),u==2)
            end
            file_handle:close()
            t = {
                utftype = u, -- may go away
                lines = l,
                current = 0, -- line number, not really needed
                handle = nil,
                noflines = #l,
                close = function()
                    input.logger('= ' .. tag .. ' closer (' .. unicode.utfname[u] .. ')',filename)
                    input.show_close(filename)
                end,
                reader = function(self)
                    self = self or t
                    local current, lines = self.current, self.lines
                    if current >= #lines then
                        return nil
                    else
                        self.current = current + 1
                        local line = lines[self.current]
                        if line == "" then
                            return ""
                        else
                            local translator = input.filters.utf_translator
                        --  return (translator and translator(line)) or line
                            if translator then
                                return translator(line)
                            else
                                return line
                            end
                        end
                    end
                end
            }
        else
            input.logger('+ ' .. tag .. ' opener',filename)
            -- todo: file;name -> freeze / eerste regel scannen -> freeze
            local filters = input.filters
            t = {
                reader = function(self)
                    local line = file_handle:read()
                    if line == "" then
                        return ""
                    end
                    local translator = filters.utf_translator
                    if translator then
                        return translator(line)
                    end
                    translator = filters.dynamic_translator
                    if translator then
                        return translator(line)
                    end
                    return line
                end,
                close = function()
                    input.logger('= ' .. tag .. ' closer',filename)
                    input.show_close(filename)
                    file_handle:close()
                end,
                handle = function()
                    return file_handle
                end,
                noflines = function()
                    t.noflines = io.noflines(file_handle)
                    return t.noflines
                end
            }
        end
        return t
    end

    function input.openers.generic(instance,tag,filename)
        if filename and filename ~= "" then
            local f = io.open(filename,"r")
            if f then
                input.show_open(filename)
                return input.openers.text_opener(filename,f,tag)
            end
        end
        input.logger('- ' .. tag .. ' opener',filename)
        return unpack(input.openers.notfound)
    end

    function input.loaders.generic(instance,tag,filename)
        if filename and filename ~= "" then
            local f = io.open(filename,"rb")
            if f then
                input.show_load(filename)
                input.logger('+ ' .. tag .. ' loader',filename)
                local s = f:read("*a")
                f:close()
                if s then
                    return true, s, #s
                end
            end
        end
        input.logger('- ' .. tag .. ' loader',filename)
        return unpack(input.loaders.notfound)
    end

    function input.finders.tex(instance,filename,filetype)
        return input.finders.generic(instance,'tex',filename,filetype)
    end
    function input.openers.tex(instance,filename)
        return input.openers.generic(instance,'tex',filename)
    end
    function input.loaders.tex(instance,filename)
        return input.loaders.generic(instance,'tex',filename)
    end

end

-- callback into the file io and related things; disabling kpse


if texconfig and not texlua then do

    -- this is not the right place, because we refer to quite some not yet defined tables, but who cares ...

    ctx = ctx or { }

    local ss = { }

    function ctx.writestatus(a,b)
        local s = ss[a]
        if not ss[a] then
            s = a:rpadd(15) .. ": "
            ss[a] = s
        end
        texio.write_nl(s .. b .. "\n")
    end

    -- this will become: ctx.install_statistics(fnc() return ..,.. end) etc

    function ctx.show_statistics()
        local function ws(...)
            ctx.writestatus("mkiv lua stats",string.format(...))
        end
        if caches then
            ws("used config path          - %s", caches.configpath(texmf.instance))
            ws("used cache path           - %s", caches.path)
        end
        if status.luabytecodes > 0 and input.storage and input.storage.done then
            ws("modules/dumps/instances   - %s/%s/%s", status.luabytecodes-500, input.storage.done, status.luastates)
        end
        if texmf.instance then
            ws("input load time           - %s seconds", input.loadtime(texmf.instance))
        end
        if fonts then
            ws("fonts load time           - %s seconds", input.loadtime(fonts))
        end
        if xml then
            ws("xml load time             - %s seconds", input.loadtime(lxml))
        end
        if mptopdf then
            ws("mps conversion time       - %s seconds", input.loadtime(mptopdf))
        end
        if nodes then
            ws("node processing time      - %s seconds (including kernel)", input.loadtime(nodes))
        end
        if kernel then
            ws("kernel processing time    - %s seconds", input.loadtime(kernel))
        end
        if attributes then
            ws("attribute processing time - %s seconds", input.loadtime(attributes))
        end
        if languages then
            ws("language load time        - %s seconds (n=%s)", input.loadtime(languages), languages.hyphenation.n())
        end
        if figures then
            ws("graphics processing time  - %s seconds (n=%s) (including tex)", input.loadtime(figures), figures.n or "?")
        end
        if metapost then
            ws("metapost processing time  - %s seconds (loading: %s seconds, execution: %s seconds, n: %s)", input.loadtime(metapost), input.loadtime(mplib), input.loadtime(metapost.exectime), metapost.n)
        end
        if status.luastate_bytes then
            ws("current memory usage      - %s bytes", status.luastate_bytes)
        end
        if nodes then
            ws("cleaned up reserved nodes - %s nodes, %s lists (of %s)", nodes.cleanup_reserved(tex.count[24])) -- \topofboxstack
        end
        if languages then
            ws("loaded patterns           - %s", languages.logger.report())
        end
        if status.node_mem_usage then
            ws("node memory usage         - %s", status.node_mem_usage)
        end
        if fonts then
            ws("loaded fonts              - %s", fonts.logger.report()) -- last because it is often a long list
        end
    end

end end

if texconfig and not texlua then

    texconfig.kpse_init        = false
    texconfig.trace_file_names = input.logmode() == 'tex'
    texconfig.max_print_line   = 100000

    -- if still present, we overload kpse (put it off-line so to say)

    if not texmf then texmf = { } end

    if not texmf.instance then

        if not texmf.instance then -- prevent a second loading

            texmf.instance            = input.reset()
            texmf.instance.progname   = environment.progname or 'context'
            texmf.instance.engine     = environment.engine   or 'luatex'
            texmf.instance.validfile  = input.validctxfile

            input.load(texmf.instance)

        end

        if callback then
            callback.register('find_read_file'      , function(id,name) return input.findtexfile(texmf.instance,name) end)
            callback.register('open_read_file'      , function(   name) return input.opentexfile(texmf.instance,name) end)
        end

        if callback then
            callback.register('find_data_file'      , function(name) return input.findbinfile(texmf.instance,name,"tex") end)
            callback.register('find_enc_file'       , function(name) return input.findbinfile(texmf.instance,name,"enc") end)
            callback.register('find_font_file'      , function(name) return input.findbinfile(texmf.instance,name,"tfm") end)
            callback.register('find_format_file'    , function(name) return input.findbinfile(texmf.instance,name,"fmt") end)
            callback.register('find_image_file'     , function(name) return input.findbinfile(texmf.instance,name,"tex") end)
            callback.register('find_map_file'       , function(name) return input.findbinfile(texmf.instance,name,"map") end)
            callback.register('find_ocp_file'       , function(name) return input.findbinfile(texmf.instance,name,"ocp") end)
            callback.register('find_opentype_file'  , function(name) return input.findbinfile(texmf.instance,name,"otf") end)
            callback.register('find_output_file'    , function(name) return name                                         end)
            callback.register('find_pk_file'        , function(name) return input.findbinfile(texmf.instance,name,"pk")  end)
            callback.register('find_sfd_file'       , function(name) return input.findbinfile(texmf.instance,name,"sfd") end)
            callback.register('find_truetype_file'  , function(name) return input.findbinfile(texmf.instance,name,"ttf") end)
            callback.register('find_type1_file'     , function(name) return input.findbinfile(texmf.instance,name,"pfb") end)
            callback.register('find_vf_file'        , function(name) return input.findbinfile(texmf.instance,name,"vf")  end)

            callback.register('read_data_file'      , function(file) return input.loadbinfile(texmf.instance,file,"tex") end)
            callback.register('read_enc_file'       , function(file) return input.loadbinfile(texmf.instance,file,"enc") end)
            callback.register('read_font_file'      , function(file) return input.loadbinfile(texmf.instance,file,"tfm") end)
         -- format
         -- image
            callback.register('read_map_file'       , function(file) return input.loadbinfile(texmf.instance,file,"map") end)
            callback.register('read_ocp_file'       , function(file) return input.loadbinfile(texmf.instance,file,"ocp") end)
            callback.register('read_opentype_file'  , function(file) return input.loadbinfile(texmf.instance,file,"otf") end)
         -- output
            callback.register('read_pk_file'        , function(file) return input.loadbinfile(texmf.instance,file,"pk")  end)
            callback.register('read_sfd_file'       , function(file) return input.loadbinfile(texmf.instance,file,"sfd") end)
            callback.register('read_truetype_file'  , function(file) return input.loadbinfile(texmf.instance,file,"ttf") end)
            callback.register('read_type1_file'     , function(file) return input.loadbinfile(texmf.instance,file,"pfb") end)
            callback.register('read_vf_file'        , function(file) return input.loadbinfile(texmf.instance,file,"vf" ) end)
        end

        if callback and environment.aleph_mode then
            callback.register('find_font_file'      , function(name) return input.findbinfile(texmf.instance,name,"ofm") end)
            callback.register('read_font_file'      , function(file) return input.loadbinfile(texmf.instance,file,"ofm") end)
            callback.register('find_vf_file'        , function(name) return input.findbinfile(texmf.instance,name,"ovf") end)
            callback.register('read_vf_file'        , function(file) return input.loadbinfile(texmf.instance,file,"ovf") end)
        end

        if callback then
            callback.register('find_write_file'   , function(id,name) return name end)
        end

        if callback and (not config or (#config == 0)) then
            callback.register('find_format_file'  , function(name) return name end)
        end

        if callback and false then
            for k, v in pairs(callback.list()) do
                if not v then texio.write_nl("<w>callback "..k.." is not set</w>") end
            end
        end

        if callback then

            input.start_actions = { }
            input.stop_actions  = { }

            function input.register_start_actions(f) table.insert(input.start_actions, f) end
            function input.register_stop_actions (f) table.insert(input.stop_actions,  f) end

        --~ callback.register('start_run', function() for _, a in pairs(input.start_actions) do a() end end)
        --~ callback.register('stop_run' , function() for _, a in pairs(input.stop_actions ) do a() end end)

        end

        if callback then

            if input.logmode() == 'xml' then

                function input.start_page_number()
                    texio.write_nl("<p real='" .. tex.count[0] .. "' page='"..tex.count[1].."' sub='"..tex.count[2].."'")
                end
                function input.stop_page_number()
                    texio.write("/>")
                    texio.write_nl("")
                end

                callback.register('start_page_number'  , input.start_page_number)
                callback.register('stop_page_number'   , input.stop_page_number )

                function input.report_output_pages(p,b)
                    texio.write_nl("<v k='pages'>"..p.."</v>")
                    texio.write_nl("<v k='bytes'>"..b.."</v>")
                    texio.write_nl("")
                end
                function input.report_output_log()
                end

                callback.register('report_output_pages', input.report_output_pages)
                callback.register('report_output_log'  , input.report_output_log  )

                function input.start_run()
                    texio.write_nl("<?xml version='1.0' standalone='yes'?>")
                    texio.write_nl("<job xmlns='www.tug.org/luatex/schemas/context-job.rng'>")
                    texio.write_nl("")
                end
                function input.stop_run()
                    texio.write_nl("</job>")
                end
                function input.show_statistics()
                    for k,v in pairs(status.list()) do
                        texio.write_nl("log","<v k='"..k.."'>"..tostring(v).."</v>")
                    end
                end

                table.insert(input.start_actions, input.start_run)
                table.insert(input.stop_actions , input.show_statistics)
                table.insert(input.stop_actions , input.stop_run)

            else
                table.insert(input.stop_actions , input.show_statistics)
            end

            callback.register('start_run', function() for _, a in pairs(input.start_actions) do a() end end)
            callback.register('stop_run' , function() for _, a in pairs(input.stop_actions ) do a() end ctx.show_statistics() end)

        end

    end

    if kpse then

        function kpse.find_file(filename,filetype,mustexist)
            return input.find_file(texmf.instance,filename,filetype,mustexist)
        end
        function kpse.expand_path(variable)
            return input.expand_path(texmf.instance,variable)
        end
        function kpse.expand_var(variable)
            return input.expand_var(texmf.instance,variable)
        end
        function kpse.expand_braces(variable)
            return input.expand_braces(texmf.instance,variable)
        end

    end

end

-- program specific configuration (memory settings and alike)

if texconfig and not texlua then

    luatex = luatex or { }

    luatex.variablenames = {
        'main_memory', 'extra_mem_bot', 'extra_mem_top',
        'buf_size','expand_depth',
        'font_max', 'font_mem_size',
        'hash_extra', 'max_strings', 'pool_free', 'pool_size', 'string_vacancies',
        'obj_tab_size', 'pdf_mem_size', 'dest_names_size',
        'nest_size', 'param_size', 'save_size', 'stack_size',
        'trie_size', 'hyph_size', 'max_in_open',
        'ocp_stack_size', 'ocp_list_size', 'ocp_buf_size'
    }

    function luatex.variables()
        local t, x = { }, nil
        for _,v in pairs(luatex.variablenames) do
            x = input.var_value(texmf.instance,v)
            if x and x:find("^%d+$") then
                t[v] = tonumber(x)
            end
        end
        return t
    end

    function luatex.setvariables(tab)
        for k,v in pairs(luatex.variables()) do
            tab[k] = v
        end
    end

    if not luatex.variables_set then
        luatex.setvariables(texconfig)
        luatex.variables_set = true
    end

    texconfig.max_print_line = 100000
    texconfig.max_in_open    = 127

end

-- some tex basics

if not cs then cs = { } end

function cs.def(k,v)
    tex.sprint(tex.texcatcodes, "\\def\\" .. k .. "{" .. v .. "}")
end

function cs.chardef(k,v)
    tex.sprint(tex.texcatcodes, "\\chardef\\" .. k .. "=" .. v .. "\\relax")
end

function cs.boolcase(b)
    if b then tex.write(1) else tex.write(0) end
end

function cs.testcase(b)
    if b then
        tex.sprint(tex.texcatcodes, "\\firstoftwoarguments")
    else
        tex.sprint(tex.texcatcodes, "\\secondoftwoarguments")
    end
end

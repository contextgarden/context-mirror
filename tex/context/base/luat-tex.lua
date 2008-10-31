-- filename : luat-zip.lua
-- comment  : companion to luat-lib.tex
-- author   : Hans Hagen, PRAGMA-ADE, Hasselt NL
-- copyright: PRAGMA ADE / ConTeXt Development Team
-- license  : see context related readme files

if not versions then versions = { } end versions['luat-tex'] = 1.001

-- special functions that deal with io

local format = string.format

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

    function input.finders.generic(tag,filename,filetype)
        local foundname = input.find_file(filename,filetype)
        if foundname and foundname ~= "" then
            if input.trace > 0 then
                input.logger('+ finder: %s, file: %s', tag,filename)
            end
            return foundname
        else
            if input.trace > 0 then
                input.logger('- finder: %s, file: %s', tag,filename)
            end
            return unpack(input.finders.notfound)
        end
    end

    input.filters.dynamic_translator = nil
    input.filters.frozen_translator  = nil -- not used here
    input.filters.utf_translator     = nil
    input.filters.user_translator    = nil

    function input.openers.text_opener(filename,file_handle,tag)
        local u = unicode.utftype(file_handle)
        local t = { }
        if u > 0  then
            if input.trace > 0 then
                input.logger('+ opener: %s (%s), file: %s',tag,unicode.utfname[u],filename)
            end
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
                    if input.trace > 0 then
                        input.logger('= closer: %s (%s), file: %s',tag,unicode.utfname[u],filename)
                    end
                    input.show_close(filename)
                    t = nil
                end,
--~                 getline = function(n)
--~                     local line = t.lines[n]
--~                     if not line or line == "" then
--~                         return ""
--~                     else
--~                         local translator = input.filters.utf_translator
--~                         return (translator and translator(line)) or line
--~                     end
--~                 end,
                reader = function(self)
                    self = self or t
                    local current, lines = self.current, self.lines
                    if current >= #lines then
                        return nil
                    else
                        current = current + 1
                        self.current = current
                        local line = lines[current]
                        if not line then
                            return nil
                        elseif line == "" then
                            return ""
                        else
                            translator = filters.utf_translator
                            if translator then
                                line = translator(line)
                                translator = filters.user_translator
                                if translator then
                                    line = translator(line)
                                end
                            end
                            return line
                        end
                    end
                end
            }
        else
            if input.trace > 0 then
                input.logger('+ opener: %s, file: %s',tag,filename)
            end
            -- todo: file;name -> freeze / eerste regel scannen -> freeze
            local filters = input.filters
            t = {
                reader = function(self)
                    local line = file_handle:read()
                    if not line then
                        return nil
                    elseif line == "" then
                        return ""
                    else
                        translator = filters.dynamic_translator or filters.utf_translator
                        if translator then
                            line = translator(line)
                            translator = filters.user_translator
                            if translator then
                                line = translator(line)
                            end
                        end
                        return line
                    end
                end,
                close = function()
                    if input.trace > 0 then
                        input.logger('= closer: %s, file: %s',tag,filename)
                    end
                    input.show_close(filename)
                    file_handle:close()
                    t = nil
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

    function input.openers.generic(tag,filename)
        if filename and filename ~= "" then
            local f = io.open(filename,"r")
            if f then
                input.show_open(filename)
                return input.openers.text_opener(filename,f,tag)
            end
        end
        if input.trace > 0 then
            input.logger('- opener: %s, file: %s',tag,filename)
        end
        return unpack(input.openers.notfound)
    end

    function input.loaders.generic(tag,filename)
        if filename and filename ~= "" then
            local f = io.open(filename,"rb")
            if f then
                input.show_load(filename)
                if input.trace > 0 then
                    input.logger('+ loader: %s, file: %s',tag,filename)
                end
                local s = f:read("*a")
                if garbagecollector and garbagecollector.check then garbagecollector.check(#s) end
                f:close()
                if s then
                    return true, s, #s
                end
            end
        end
        if input.trace > 0 then
            input.logger('- loader: %s, file: %s',tag,filename)
        end
        return unpack(input.loaders.notfound)
    end

    function input.finders.tex(filename,filetype)
        return input.finders.generic('tex',filename,filetype)
    end
    function input.openers.tex(filename)
        return input.openers.generic('tex',filename)
    end
    function input.loaders.tex(filename)
        return input.loaders.generic('tex',filename)
    end

end

-- callback into the file io and related things; disabling kpse


if texconfig and not texlua then do

    -- this is not the right place, because we refer to quite some not yet defined tables, but who cares ...

    ctx = ctx or { }

    function ctx.writestatus(a,b,c,...)
        if c then
            texio.write_nl(("%-15s: %s\n"):format(a,b:format(c,...)))
        else
            texio.write_nl(("%-15s: %s\n"):format(a,b)) -- b can have %'s
        end
    end

    -- this will become: ctx.install_statistics(fnc() return ..,.. end) etc

    local statusinfo, n = { }, 0

    function ctx.register_statistics(tag,pattern,fnc)
        statusinfo[#statusinfo+1] = { tag, pattern, fnc }
        if #tag > n then n = #tag end
    end

    function ctx.memused() -- no math.round yet -)
    --  collectgarbage("collect")
        local round = math.round or math.floor
        return string.format("%s MB (ctx: %s MB)",round(collectgarbage("count")/1000), round(status.luastate_bytes/1000000))
    end

    function ctx.show_statistics() -- todo: move calls
        local loadtime, register_statistics = input.loadtime, ctx.register_statistics
        if caches then
            register_statistics("used config path", "%s", function() return caches.configpath() end)
            register_statistics("used cache path", "%s", function() return caches.temp() or "?" end)
        end
        if status.luabytecodes > 0 and input.storage and input.storage.done then
            register_statistics("modules/dumps/instances", "%s/%s/%s", function() return status.luabytecodes-500, input.storage.done, status.luastates end)
        end
        if input.instance then
            register_statistics("input load time", "%s seconds", function() return loadtime(input.instance) end)
        end
        if ctx and input.hastimer(ctx) then
            register_statistics("startup time","%s seconds (including runtime option file processing)", function() return loadtime(ctx) end)
        end
        if job then
            register_statistics("jobdata time","%s seconds saving, %s seconds loading", function() return loadtime(job._save_), loadtime(job._load_) end)
        end
        if fonts then
            register_statistics("fonts load time","%s seconds", function() return loadtime(fonts) end)
        end
        if xml then
            register_statistics("xml load time", "%s seconds, lpath calls: %s, cached calls: %s", function()
                local stats = xml.statistics()
                return loadtime(xml), stats.lpathcalls, stats.lpathcached
            end)
            register_statistics("lxml load time", "%s seconds preparation, backreferences: %i", function()
                return loadtime(lxml), #lxml.self
            end)
        end
        if mptopdf then
            register_statistics("mps conversion time", "%s seconds", function() return loadtime(mptopdf) end)
        end
        if nodes then
            register_statistics("node processing time", "%s seconds including kernel", function() return loadtime(nodes) end)
        end
        if kernel then
            register_statistics("kernel processing time", "%s seconds", function() return loadtime(kernel) end)
        end
        if attributes then
            register_statistics("attribute processing time", "%s seconds", function() return loadtime(attributes) end)
        end
        if languages then
            register_statistics("language load time", "%s seconds, n=%s", function() return loadtime(languages), languages.hyphenation.n() end)
        end
        if figures then
            register_statistics("graphics processing time", "%s seconds including tex, n=%s", function() return loadtime(figures), figures.n or "?" end)
        end
        if metapost then
            register_statistics("metapost processing time", "%s seconds, loading: %s seconds, execution: %s seconds, n: %s", function() return loadtime(metapost), loadtime(mplib), loadtime(metapost.exectime), metapost.n end)
        end
        if status.luastate_bytes and ctx.memused then
            register_statistics("current memory usage", "%s", ctx.memused)
        end
        if nodes then
            register_statistics("cleaned up reserved nodes", "%s nodes, %s lists of %s", function() return nodes.cleanup_reserved(tex.count[24]) end) -- \topofboxstack
        end
        if status.node_mem_usage then
            register_statistics("node memory usage", "%s", function() return status.node_mem_usage end)
        end
        if languages then
            register_statistics("loaded patterns", "%s", function() return languages.logger.report() end)
        end
        if fonts then
            register_statistics("loaded fonts", "%s", function() return fonts.logger.report() end)
        end
        if status.cs_count then
            register_statistics("control sequences", "%s of %s", function() return status.cs_count, status.hash_size+status.hash_extra end)
        end
        if status.callbacks and xml then -- xml for being in context -)
            ctx.register_statistics("callbacks", "direct: %s, indirect: %s, total: %s%s", function()
                local total, indirect = status.callbacks, status.indirect_callbacks
                local pages = tex.count['realpageno'] - 1
                if pages > 1 then
                    return total-indirect, indirect, total, format(" (%i per page)",total/pages)
                else
                    return total-indirect, indirect, total, ""
                end
            end)
        else
            ctx.register_statistics("callbacks", "direct: %s, indirect: %s, total: %s", function()
                local total, indirect = status.callbacks, status.indirect_callbacks
                return total-indirect, indirect, total
            end)
        end
        if xml then -- so we are in mkiv, we need a different check
            register_statistics("runtime", "%s seconds, %i processed pages, %i shipped pages, %.3f pages/second", function()
                input.stoptiming(input.instance)
                local runtime = loadtime(input.instance)
                local shipped = tex.count['nofshipouts']
                local pages = tex.count['realpageno'] - 1
                local persecond = shipped / runtime
                return runtime, pages, shipped, persecond
            end)
        end
        for _, t in ipairs(statusinfo) do
            local tag, pattern, fnc = t[1], t[2], t[3]
            ctx.writestatus("mkiv lua stats", "%s - %s", tag:rpadd(n," "), pattern:format(fnc()))
        end-- input.expanded_path_list("osfontdir")
    end

end end

if texconfig and not texlua then

    texconfig.kpse_init        = false
    texconfig.trace_file_names = input.logmode() == 'tex'
    texconfig.max_print_line   = 100000

    -- if still present, we overload kpse (put it off-line so to say)

    input.starttiming(input.instance)

    if not input.instance then

        if not input.instance then -- prevent a second loading

            input.instance            = input.reset()
            input.instance.progname   = 'context'
            input.instance.engine     = 'luatex'
            input.instance.validfile  = input.validctxfile

            input.load()

        end

        if callback then
            callback.register('find_read_file'      , function(id,name) return input.findtexfile(name) end)
            callback.register('open_read_file'      , function(   name) return input.opentexfile(name) end)
        end

        if callback then
            callback.register('find_data_file'      , function(name) return input.findbinfile(name,"tex") end)
            callback.register('find_enc_file'       , function(name) return input.findbinfile(name,"enc") end)
            callback.register('find_font_file'      , function(name) return input.findbinfile(name,"tfm") end)
            callback.register('find_format_file'    , function(name) return input.findbinfile(name,"fmt") end)
            callback.register('find_image_file'     , function(name) return input.findbinfile(name,"tex") end)
            callback.register('find_map_file'       , function(name) return input.findbinfile(name,"map") end)
            callback.register('find_ocp_file'       , function(name) return input.findbinfile(name,"ocp") end)
            callback.register('find_opentype_file'  , function(name) return input.findbinfile(name,"otf") end)
            callback.register('find_output_file'    , function(name) return name                          end)
            callback.register('find_pk_file'        , function(name) return input.findbinfile(name,"pk")  end)
            callback.register('find_sfd_file'       , function(name) return input.findbinfile(name,"sfd") end)
            callback.register('find_truetype_file'  , function(name) return input.findbinfile(name,"ttf") end)
            callback.register('find_type1_file'     , function(name) return input.findbinfile(name,"pfb") end)
            callback.register('find_vf_file'        , function(name) return input.findbinfile(name,"vf")  end)

            callback.register('read_data_file'      , function(file) return input.loadbinfile(file,"tex") end)
            callback.register('read_enc_file'       , function(file) return input.loadbinfile(file,"enc") end)
            callback.register('read_font_file'      , function(file) return input.loadbinfile(file,"tfm") end)
         -- format
         -- image
            callback.register('read_map_file'       , function(file) return input.loadbinfile(file,"map") end)
            callback.register('read_ocp_file'       , function(file) return input.loadbinfile(file,"ocp") end)
--~             callback.register('read_opentype_file'  , function(file) return input.loadbinfile(file,"otf") end)
         -- output
            callback.register('read_pk_file'        , function(file) return input.loadbinfile(file,"pk")  end)
            callback.register('read_sfd_file'       , function(file) return input.loadbinfile(file,"sfd") end)
--~             callback.register('read_truetype_file'  , function(file) return input.loadbinfile(file,"ttf") end)
--~             callback.register('read_type1_file'     , function(file) return input.loadbinfile(file,"pfb") end)
            callback.register('read_vf_file'        , function(file) return input.loadbinfile(file,"vf" ) end)
        end

        if input.aleph_mode == nil then environment.aleph_mode = true end -- some day we will drop omega font support

        if callback and input.aleph_mode then
            callback.register('find_font_file'      , function(name) return input.findbinfile(name,"ofm") end)
            callback.register('read_font_file'      , function(file) return input.loadbinfile(file,"ofm") end)
            callback.register('find_vf_file'        , function(name) return input.findbinfile(name,"ovf") end)
            callback.register('read_vf_file'        , function(file) return input.loadbinfile(file,"ovf") end)
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
            return input.find_file(filename,filetype,mustexist)
        end
        function kpse.expand_path(variable)
            return input.expand_path(variable)
        end
        function kpse.expand_var(variable)
            return input.expand_var(variable)
        end
        function kpse.expand_braces(variable)
            return input.expand_braces(variable)
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
            x = input.var_value(v)
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

-- some tex basics, maybe this will move to ctx

if tex then

    local texsprint, texwrite = tex.sprint, tex.write

    if not cs then cs = { } end

    function cs.def(k,v)
        texsprint(tex.texcatcodes, "\\def\\" .. k .. "{" .. v .. "}")
    end

    function cs.chardef(k,v)
        texsprint(tex.texcatcodes, "\\chardef\\" .. k .. "=" .. v .. "\\relax")
    end

    function cs.boolcase(b)
        if b then texwrite(1) else texwrite(0) end
    end

    function cs.testcase(b)
        if b then
            texsprint(tex.texcatcodes, "\\firstoftwoarguments")
        else
            texsprint(tex.texcatcodes, "\\secondoftwoarguments")
        end
    end

end

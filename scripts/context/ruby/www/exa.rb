require 'fileutils'
require 'www/lib'
require 'www/dir'
require 'www/common'
require 'www/admin'

class WWW

    include Common

    def handle_exadefault
        check_template_file('exalogin','exalogin-template.htm')
        if id = logged_in_session(true) then
            finish_login
        else
            message('Error', 'No default login permitted.')
        end
    end

    def handle_exalogin
        check_template_file('exalogin','exalogin-template.htm')
        if id = logged_in_session(false) then
            finish_login
        else
            message('Error', 'No default login permitted.')
        end
    end

    def finish_login
        get_gui()
        filename, path, task = @session.get('gui'), @session.checked('path','.'), @session.get('task')
        if ! task.empty? then
            save_session
            handle_exatask
        elsif filename and not filename.empty? then
            save_session
            fullname = filename.gsub(/\.\./,'')
            fullname = File.join(path,filename)                                     unless FileTest.file?(fullname)
            fullname = File.join(@interface.get('path:interfaces'), filename)       unless FileTest.file?(fullname)
            fullname = File.join(@interface.get('path:interfaces'), path, filename) unless FileTest.file?(fullname)
            if FileTest.file?(fullname) then
                send_file(fullname,true)
            else
                message('Interface', 'Invalid interface request, no valid interface file.' )
            end
        else
            message('Interface', 'Invalid interface request, no default interface file.')
        end
    end

    def handle_exainterface()
        check_template_file('text','exalogin-template.htm')
        if id = valid_session() then
            filename = @interface.get('process:uri').to_s # kind of dup
            if ! filename.empty? && filename.sub!(/^.*\//,'') then
                path = @session.checked('path', '.')
                fullname = filename.gsub(/\.\./,'')
                fullname = File.join(path,filename) unless FileTest.file?(fullname)
                fullname = File.join(@interface.get('path:interfaces'),filename) unless FileTest.file?(fullname)
                fullname = File.join(@interface.get('path:interfaces'),path,filename) unless FileTest.file?(fullname)
                if FileTest.file?(fullname) then
                    save_session
                    send_file(fullname,true)
                else
                    get_file(filename)
                    filename, path = @session.get('gui'), @session.checked('path','.')
                    if filename and not filename.empty? then
                        save_session
                        fullname = filename.gsub(/\.\./,'')
                        fullname = File.join(path,filename) unless FileTest.file?(fullname)
                        fullname = File.join(@interface.get('path:interfaces'),filename) unless FileTest.file?(fullname)
                        fullname = File.join(@interface.get('path:interfaces'),path,filename) unless FileTest.file?(fullname)
                        send_file(fullname,true) if FileTest.file?(fullname)
                    else
                        message('Interface', 'Invalid interface request, no interface file.')
                    end
                end
            else
                message('Interface', 'Invalid interface request, no resource file.')
            end
        else
            message('Interface', 'Invalid interface request, no login.')
        end
    end

    def handle_exarequest() # todo: check if request is 'command'
        check_template_file('exalogin','exalogin-template.htm')
        if id = client_session() then
            client = true
            @interface.set('log:kind', "remote client request: #{id}")
        elsif id = valid_session() then
            client = false
            @interface.set('log:kind', "remote browser request: #{id}")
        else
            client, id = false, nil
            @interface.set('log:kind', 'unknown kind of request')
        end
        if id then
            dir, tmp = dirname, tmp_path(dirname)
            requestname, replyname = 'request.exa', 'reply.exa'
            requestfile, replyfile = File.join(tmp,requestname), File.join(tmp,replyname)
            lockfile = File.join(dirname,lckname)
            action, filename, command, url, req = '', '', '', '', ''
            extract_sent_files(tmp)
            @variables.each do |key, value|
                case key
                    when 'exa:request' then
                        req = value.dup
                    when 'exa:action' then
                        action = value.dup
                    # when 'exa:command' then
                        # command = value.dup
                    # when 'exa:url' then
                        # url = value.dup
                    when 'exa:filename' then
                        filename = value.dup
                    when 'exa:threshold' then
                        @interface.set('process:threshold', value.dup)
                    when /^fakename/o then
                        @variables.set(key, File.basename(value))
                    when /^filename\-/o then
                        @variables.set(key, filename = File.basename(value))
                    when /^dataname\-/o then
                        @variables.set(key)
                    else # remove varname- prefix from value
                        @variables.set(key, @variables.get(key).sub(/#{key}\-/,''))
                end
            end
            @variables.check('exa:filename', filename)
            @variables.check('exa:action', action)
            if @variables.empty?('exa:filename') then
                @variables.set('exa:filename', @interface.get('log:attachments').split('|').first || '')
            end
            req.gsub!(/<exa:data\s*\/>/i, '')
            dat = "<exa:data>\n"
            @variables.each do |key, value|
                if ['password','exa:request'].include?(key) then
                    # skip
                elsif ! value || value.empty? then
                    dat << "<exa:variable label='#{key}'/>\n"
                else # todo: escape 'm
                    dat << "<exa:variable label='#{key}'>#{value}</exa:variable>\n"
                end
            end
            dat << "</exa:data>\n"
            if req.empty? then
                req << "<?xml version='1.0' ?>\n"
                req << "<exa:request xmlns:exa='#{@@namespace}'>\n"
                req << "<exa:application>\n"
                req << "<exa:action>'#{action}</exa:action>\n"     unless action.empty?
                # req << "<exa:command>'#{command}</exa:command>\n"  unless command.empty?
                # req << "<exa:url>'#{url}</exa:url>\n"              unless url.empty?
                req << "</exa:application>\n"
                req << "<exa:comment>constructed request</exa:comment>\n"
                req << dat
                req << "</exa:request>\n"
            else
                # better use rexml but slower
                if req =~ /<exa:request[^>]*>.*?\s*<exa:threshold>\s*(.*?)\s*<\/exa:threshold>\s*.*?<\/exa:request>/mois then
                    threshold = $1
                    unless threshold.empty? then
                        @interface.set('process:threshold', threshold)
                        @session.set('threshold', threshold)
                    end
                end
                req.sub!(/(<exa:request[^>]*>.*?)\s*<exa:option>\s*\-\-action\=(.*?)\s*<\/exa:option>\s*(.*?<\/exa:request>)/mois) do
                    pre, act, pos = $1, $2, $3
                    action = act.sub(/\.exa$/,'') if action.empty?
                    str = "#{pre}<exa:action>#{action}</exa:action>#{pos}"
                    str.sub(/\s*<exa:command>.*?<\/exa:command>\s*/mois ,'')
                end
                req.sub!(/(<exa:request[^>]*>.*?)<exa:action>\s*(.*?)\s*<\/exa:action>(.*?<\/exa:request>)/mois) do
                    pre, act, pos = $1, $2, $3
                    action = act.sub(/\.exa$/,'') if action.empty?
                    str = "#{pre}<exa:action>#{action}</exa:action>#{pos}"
                    str.sub(/\s*<exa:command>.*?<\/exa:command>\s*/mois ,'')
                end
                unless req =~ /<exa:data>(.*?)<\/exa:data>/mois then
                    req.sub!(/(<\/exa:request>)/) do dat + $1 end
                end
            end
            req.sub!(/<exa:filename>.*?<\/exa:filename>/mois, '')
            unless @variables.empty?('exa:filename') then
                req.sub!(/(<\/exa:application>)/mois) do
                    "<exa:filename>#{@variables.get('exa:filename')}<\/exa:filename>" + $1
                end
            end
            @variables.set('exa:action', action)
            @interface.set("log:#{requestname}", req)
            begin
                File.open(requestfile,'w') do |f|
                    f << req
                end
            rescue
                message('Error', 'There is a problem in handling this request (working path access).')
                return
            end
            File.delete(replyfile) rescue false
            @interface.set('log:action',action)
            get_command(action)
            logdata = ''
            begin
                command = @session.get('command')
                @interface.set('log:command',if command.empty? then '[no command]' else command end)
                if ! command.empty? then
                    @session.set('starttime', Time.now.to_i.to_s) # can be variables and in save list
                    if @interface.true?('process:background') then
                        # background
                        @session.set('status',  'running: background')
                        @session.set('maxtime', @interface.get('process:timeout'))
                        @session.set('threshold', @interface.get('process:threshold'))
                        save_session
                        timeout(@@watch_delay) do
                            save_environment(@interface,tmp)
                            begin
                                starttime = File.mtime(@session_file)
                                # crap
                                loop do
                                    sleep(1)
                                    if starttime != File.mtime(@session_file) then
                                        break unless FileTest.file?(lockfile)
                                    end
                                end
                            rescue TimeoutError
                                if client then
                                    send_reply()
                                else
                                    message('Status', 'Processing your request takes a while',true,5,'exastatus')
                                end
                                return
                            rescue
                            end
                        end
                        if client then send_reply() else send_result() end
                    else
                        # foreground
                        status = 'running: foreground'
                        @session.set('status',  status)
                        @session.set('maxtime', @interface.get('process:timeout'))
                        @session.set('threshold', @interface.get('process:threshold'))
                        save_session
                        timeout(@interface.get('process:timeout').to_i) do
                            begin
                                status = 'running: foreground'
                                set_environment(@interface)
                                save_environment(@interface,tmp)
                                command = command_string(tmp,command)
                                logdata = `#{command}`
                            rescue TimeoutError
                                status = 'running: timeout'
                                logdata = "timeout: #{@interface.get('process:timeout')} seconds"
                            rescue
                                status = 'running: aborted'
                                logdata = 'fatal runtime error'
                            else
                                @session.set('endtime', Time.now.to_i.to_s)
                                status = 'running: finished'
                            end
                        end
                        @session.set('status', status)
                        save_session
                        case @session.get('status')
                            when 'running: finished' then
                                if client then send_reply(logdata) else send_result(logdata) end
                            when 'running: timeout' then
                                message('Error', 'There is a problem in handling this request (timeout).')
                            when 'running: aborted' then
                                message('Error', 'There is a problem in handling this request (aborted).')
                            else
                                message('Error', 'There is a problem in handling this request (unknown).')
                        end
                    end
                else
                    message('Error', 'There is a problem in handling this request (no runner).')
                end
            rescue
                message('Error', 'There is a problem in handling this request (no run).' + $!)
            end
        else
            message('Error', 'Invalid session.')
        end
    end

    def handle_exacommand() # shares code with exarequest
        check_template_file('exalogin','exalogin-template.htm')
        if id = client_session() then
            client = true
            @interface.set('log:kind', "remote client request: #{id}")
        elsif id = valid_session() then
            client = false
            @interface.set('log:kind', "remote browser request: #{id}")
        else
            client, id = false, nil
            @interface.set('log:kind', 'unknown kind of request')
        end
        if id then
            dir, tmp = dirname, tmp_path(dirname)
            requestname, replyname = 'request.exa', 'reply.exa'
            requestfile, replyfile = File.join(tmp,requestname), File.join(tmp,replyname)
            req, command, url = '', '', ''
            @variables.each do |key, value|
                case key
                    when 'exa:request' then
                        req = value.dup
                    when 'exa:command' then
                        command = value.dup
                    when 'exa:threshold' then
                        @interface.set('process:threshold', value.dup)
                    when 'exa:url' then
                        url = value.dup
                end
            end
            unless req.empty? then
                # better use rexml but slower / reuse these : command = filter_from_request('exa:command')
                if req =~ /<exa:request[^>]*>.*?\s*<exa:command>\s*(.*?)\s*<\/exa:command>\s*.*?<\/exa:request>/mois then
                    command = $1
                end
                if req =~ /<exa:request[^>]*>.*?\s*<exa:url>\s*(.*?)\s*<\/exa:url>\s*.*?<\/exa:request>/mois then
                    url = $1
                end
                if req =~ /<exa:request[^>]*>.*?\s*<exa:threshold>\s*(.*?)\s*<\/exa:threshold>\s*.*?<\/exa:request>/mois then
                    threshold = $1
                    unless threshold.empty? then
                        @interface.set('process:threshold', threshold)
                        @session.set('threshold', threshold)
                    end
                end
            end
            @variables.check('exa:command', command)
            @variables.check('exa:url', url)
            File.delete(replyfile) rescue false
            case @variables.get('exa:command')
                when 'fetch' then
                    if @variables.empty?('exa:url') then
                        message('Error', "Problems with fetching, no file given")
                    else
                        # the action starts here
                        filename = @variables.get('exa:url').to_s # kind of dup
                        unless filename.empty? then
                            get_path(filename) # also registers filename as url
                            path = @session.checked('path', '')
                            fullname = filename.gsub(/\.\./,'')
                            fullname = File.join(path,fullname) unless path.empty?
                            if FileTest.file?(fullname) then
                                if client then
                                    send_url(fullname)
                                else
                                    send_file(fullname,true)
                                end
                                @session.set('threshold', @interface.get('process:threshold'))
                                @session.set('url',filename)
                                save_session
                            else
                                message('Error', "Problems with fetching, unknown file #{fullname}.")
                                # message('Error', "Problems with fetching, unknown file #{filename}.")
                            end
                        else
                           message('Error', "Problems with fetching, invalid file #{filename}.")
                        end
                        # and ends here
                    end
            else
                message('Error', "Invalid command #{command}.")
            end
        else
            message('Error', 'Invalid session.')
        end
    end

    def handle_exastatus
        if request_variable('id').empty? then
            if id = valid_session() then
                send_result()
            else
                message('Error', 'Invalid session.')
            end
        else
            if id = valid_session() then
                send_reply()
            else
                send_reply('invalid session')
            end
        end
    end

end

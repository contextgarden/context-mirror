require 'fileutils'

require 'www/lib'
require 'www/dir'
require 'www/common'

class WWW

    include Common

    # klopt nog niet, twee keer task met een verschillend doel

    def handle_exatask
        # case @session.check('task', request_variable('task'))
        task, options, option = @session.get('task'), @session.get('option').split(@@re_bar), request_variable('option')
        option = (options.first || '') if option.empty?
        case task
            when 'exaadmin'
                @session.set('status', 'admin') # admin: status|dir
                touch_session(@session.get('id'))
                if options.include?(option) then
                    case option
                        when 'status' then handle_exaadmin_status
                        when 'dir'    then handle_exaadmin_dir
                        else               handle_exaadmin_status
                        end
                elsif option.empty? then
                    message('Status', "unknown option")
                else
                    message('Status', "option '#{option}' not permitted #{options.inspect}")
                end
            else
                message('Status', "unknown task '#{task}'")
        end
    end

    def handle_exaadmin
        if id = valid_session() then
            handle_exatask
        else
            message('Status', 'no login')
        end
    end

    def handle_exaadmin_dir
        check_template_file('exalogin','exalogin-template.htm')
        @interface.set('path:docroot', work_root)
        @interface.set('dir:uri', 'exaadmin')   # forces the dir handler into cgi mode
        @interface.set('dir:task', 'exaadmin')  # forces the dir handler into cgi mode
        @interface.set('dir:option', 'dir')     # forces the dir handler into cgi mode
        filename = "#{@@session_prefix}#{request_variable('path')}"
        fullname = File.join(work_root,filename)
        if request_variable('path').empty? then
            handle_exaadmin_status
        elsif FileTest.directory?(fullname) then
            handle_dir(filename, [], false)
        elsif File.zero?(fullname) then
            message('Error', "The file '#{filename}' is empty")
        elsif File.size?(fullname) > (4 * 1024 * 1024) then
            if FileTest.file?(File.expand_path(File.join(cache_root,filename))) then
                str = "<br/><br/>Cached alternative: <a href=\"#{File.join('cache',filename)}\">#{File.basename(filename)}</a>"
            else
                str = ''
            end
            message('Error', "The file '#{filename}' is too big to serve over cgi." + str)
        else
            send_file(fullname)
        end
    end

    def handle_exaadmin_status
        check_template_file('exalogin','exalogin-template.htm')
        begin
            n, str, lines, list, start, most, least, cached = 0, '', '', Hash.new, Time.now, 0, 0, false
            filename = File.join(tmp_path(dirname),'sessions.rbd')
            begin
                File.open(filename) do |f|
                    list = Marshal.load(f)
                end
            rescue
                cached, list = false, Hash.new
            else
                cached = true
            end
            files = Dir.glob("{#{work_roots.join(',')}}/#{@@session_prefix}*.ses")
            list.keys.each do |l|
                list.delete(l) unless files.include?(l) # slow
            end
            files.each do |f|
                ctime = File.ctime(f)
                stime = list[f][0] == ctime rescue 0
                unless ctime == stime then
                    begin
                        hash = load_session_file(f)
                    rescue
                    else
                        list[f] = [ctime,hash]
                    end
                end
            end
            begin
                File.open(filename,'w') do |f|
                    f << Marshal.dump(list)
                end
            rescue
                # no save
            end
            begin
                keys = list.keys.sort do |a,b|
                    case list[b][0] <=> list[a][0]
                        when -1 then -1
                        when +1 then +1
                    else
                        a <=> b
                    end
                end
            rescue
                keys = list.keys.sort
            end
            totaltime, totaldone = 0.0, 0
            if keys.length > 0 then
                keys.each do |entry|
                    s, t, session = entry, list[entry][0], list[entry][1]
                    status = session['status'] || ''
                    runtime = (session['runtime'] || '').to_f rescue 0
                    starttime = (start.to_i-session['starttime'].to_i).to_s rescue ''
                    requesttime = session['endtime'].to_i-session['starttime'].to_i rescue 0
                    requesttime = if requesttime > 0 then requesttime.to_s else '' end
                    if runtime > 0.0 then
                        totaltime += runtime
                        totaldone += 1
                        if least > 0 then
                            if runtime < least then least = runtime end
                        else
                            least = runtime
                        end
                        if most > 0 then
                            if runtime > most then most = runtime end
                        else
                            most = runtime
                        end
                    end
                    if status.empty? then
                        # skip, garbage
                    elsif status =~ /^(|exa)admin/o then
                        # skip, useless
                    else
                        begin
                            lines << "<tr>\n"
                            lines << td("<a href=\"exaadmin?option=dir&path=#{session['id']}.dir\">#{session['id']}</a>")
                            lines << td(status)
                            lines << td(session['timeout'])
                            lines << td(starttime)
                            lines << td(session['runtime'])
                            lines << td(requesttime)
                            lines << td(t.strftime("%H:%M:%S %Y-%m-%d"))
                            lines << td(session['domain'])
                            lines << td(session['project'])
                            lines << td(session['username'])
                            lines << td(File.basename(File.dirname(s)))
                            lines << "</tr>\n"
                        rescue
                        else
                            n += 1
                        end
                    end
                end
                if n > 0 then
                    str = "<table cellpadding='0'>\n"
                    str << "<tr>\n"
                    str << th('session identifier')
                    str << th('status')
                    str << th('timeout')
                    str << th('time')
                    str << th('runtime')
                    str << th('total')
                    str << th('modification&nbsp;time')
                    str << th('domain')
                    str << th('project')
                    str << th('username')
                    str << th('process')
                    str << "</tr>\n"
                    str << lines
                    str << "</table>\n"
                end
            end
        rescue
            message('Status', "#{$!} There is currently no status available.", false, @@admin_refresh, 'exaadmin')
        else
            if n > 0 then
                # r = if n > 100 then 60 else @@admin_refresh.to_i end # scanning takes long
                r = @@admin_refresh
                average  = "average = #{if totaldone > 0 then sprintf('%.02f',totaltime/totaldone) else '0' end} (#{sprintf('%.02f',least)} .. #{sprintf('%.02f',most)})"
                sessions = "sessions = #{n}"
                refresh  = "refresh = #{r.to_s} sec"
                loadtime = "loadtime = #{sprintf('%.04f',Time.now-start)} sec"
                cached   = if cached then "cached" else "not cached" end
                message("Status | #{sessions} | #{refresh} | #{loadtime} - #{cached} | #{average} |", str, false, r, 'exaadmin')
            else
                message('Status', "There are no sessions registered.", false, @@admin_refresh, 'exaadmin')
            end
        end
    end

    private

    def th(str)
        "<th align='left'>#{str}&nbsp;&nbsp;&nbsp;</th>\n"
    end

    def td(str)
        "<td><code>#{str || ''}&nbsp;&nbsp;&nbsp</code></td>\n"
    end

end

require 'www/lib'

# dir handling

class WWW

    # borrowed code from webrick demo, patched

    @@dir_name_width = 25

    def handle_dir(dirpath=@variables.get('path'),hidden=[],showdirs=true)
        check_template_file('dir','text-template.htm')
        docroot = @interface.get('path:docroot')
        dirpath = dirpath || ''
        hidden = [] unless hidden
        local_path = dirpath.dup
        title, str = "Index of #{escaped(dirpath)}", ''
        begin
            local_path.gsub!(/[\/\\]+/,'/')
            local_path.gsub!(/\/$/, '')
            if local_path !~ /^(\.|\.\.|\/|[a-zA-Z]\:)$/io then # maybe also /...
                full_path = File.join(docroot,local_path)
                @interface.set('log:dir', full_path)
                begin
                    list = Dir::entries(full_path)
                rescue
                    str << "unable to parse #{local_path}"
                else
                    if list then
                        list.collect! do |name|
                            if name =~ /^\.+/o then
                                nil # no . and ..
                            else
                                st = (File::stat(File.join(docroot,local_path,name)) rescue nil)
                                if st.nil? then
                                    [name, nil, -1, false]
                                elsif st.directory? then
                                    if showdirs then [name + "/", st.mtime, -1, true] else nil end
                                elsif hidden.length > 0 then
                                    if hidden.include?(name) then nil else [name, st.mtime, st.size, false] end
                                else
                                    [name, st.mtime, st.size, false]
                                end
                            end
                        end
                        list.compact!
                        n, m, s = @variables.get('n'), @variables.get('m'), @variables.get('s')
                        if    ! n.empty? then
                            idx, d0 = 0, n
                        elsif ! m.empty? then
                            idx, d0 = 1, m
                        elsif ! s.empty? then
                            idx, d0 = 2, s
                        else
                            idx, d0 = 0, 'a'
                        end
                        d1 = if d0 == 'a' then 'd' else 'a' end
                        if d0 == 'a' then
                            list.sort! do |a,b| a[idx] <=> b[idx] end
                        else
                            list.sort! do |a,b| b[idx] <=> a[idx] end
                        end
                        u = dir_uri(@variables.get('path') || '.')
                        str << "<div class='dir-view'>\n<pre>\n"
                        str << "<a href=\"#{u}&n=#{d1}\">name</A>".ljust(49+u.length)
                        str << "<a href=\"#{u}&m=#{d1}\">last modified</A>".ljust(41+u.length)
                        str << "<a href=\"#{u}&s=#{d1}\">size</A>".rjust(31+u.length) << "\n" << "\n"
                        # parent path
                        if showdirs && ! hidden.include?('..') then
                            dname = "parent directory"
                            fname = "#{File.dirname(dirpath)}"
                            time = File::mtime(File.join(docroot,local_path,"/.."))
                            str << dir_entry(fname,dname,time,-1,true)
                            str << "\n"
                        end
                        # directories
                        done = false
                        list.each do |name, time, size, dir|
                            if dir then
                                if name.size > @@dir_name_width then
                                    dname = name.sub(/^(.#{@@dir_name_width-2})(.*)/) do $1 + ".." end
                                else
                                    dname = name
                                end
                                fname = "#{escaped(dirpath)}/#{escaped(name)}"
                                str << dir_entry(fname,dname,time,size,dir)
                                done = true
                            end
                        end
                        str << "\n" if done
                        # files
                        list.each do |name, time, size, dir|
                            unless dir then
                                if name.size > @@dir_name_width then
                                    dname = name.sub(/^(.#{@@dir_name_width-2})(.*)/) do $1 + ".." end
                                else
                                    dname = name
                                end
                                fname = "#{escaped(dirpath)}/#{escaped(name)}"
                                str << dir_entry(fname,dname,time,size,dir)
                            end
                        end
                        str << "\n"
                        str << '</pre></div>'
                    else
                        str << 'no info'
                    end
                end
            else
                str << 'no access'
            end
        rescue
            str << "error #{$!}<br/><pre>"
            str << $@.join("\n")
            str << "</pre>"
        end
        message(title,str)
    end
    def dir_uri(f='.')
        u, t, o = @interface.get('dir:uri'), @interface.get('dir:task'), @interface.get('dir:option') # takes precedence, in case we run under cgi control
        if u.empty? then
            u, t, o = @interface.get('process:uri'), '', ''
        elsif ! t.empty? then
            t = "task=#{t}&"
            o = "option=#{o}&"
        end
        if u && ! u.empty? then
            u = u.sub(/\?.*$/,'') # frozen string
            if f =~ /^\.+$/ then
                "#{u}?#{t}#{o}path="
            else
                "#{u}?#{t}#{o}path=#{f}"
            end
        else
            ''
        end
    end

    def dir_entry(fname,dname,time,size,dir=false)
        if dir then
            f = fname.sub(/\/+$/,'').sub(/^\/+/,'')
            s = "<a href=\"#{dir_uri(f)}\">#{dname}</a>"
        elsif ! @interface.get('dir:uri').empty? then # takes precedence, in case we run under cgi control
            s = "<a href=\"#{dir_uri(fname.gsub(/\/+/,'/'))}\">#{dname}</a>"
        else
            s = "<a href=\"#{fname.gsub(/\/+/,'/')}\">#{dname}</a>"
        end
        # s << " " * (30 - dname.size)
        s << " " * (@@dir_name_width + 5 - dname.size)
        s << (time ? time.strftime("%Y/%m/%d %H:%M      ") : " " * 22)
        s << (size >= 0 ? size.to_s : "-").rjust(12) << "\n"
        return s
    end

end

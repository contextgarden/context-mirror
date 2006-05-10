# We cannot chdir in threads because it is something
# process wide, so we will run into problems with the
# other threads. The same is true for the global ENV
# pseudo hash, so we cannot communicate the runpath
# via an anvironment either. This leaves texmfstart
# in combination with a path directive and an tmf file.

module Common # can be a mixin

    # we assume that the hash.subset method is defined

    @@re_texmfstart = /^(texmfstart|ruby\s*texmfstart.rb)\s*(.*)$/
    @@re_texmfpath  = /^\-\-path\=/

    def command_string(path,command,log='')
        runner = "texmfstart --path=#{File.expand_path(path)}"
        if command =~ @@re_texmfstart then
            cmd, arg = $1, $2
            if arg =~ @@re_texmfpath then
                # there is already an --path (first switch)
            else
                command = "#{runner} #{arg}"
            end
        else
            command = "#{runner} bin:#{command}"
        end
        if log && ! log.empty? then
            return "#{command} 2>&1 > #{File.expand_path(File.join(path,log))}"
        else
            return command
        end
    end

    def set_os_vars
        begin
            ENV['TEXOS'] = ENV['TEXOS'] || platform
        rescue
            ENV['TEXOS'] = 'texmf-linux'
        else
            ENV['TEXOS'] = 'texmf-' + ENV['TEXOS'] unless ENV['TEXOS'] =~ /^texmf\-/
        ensure
            ENV['EXA:TEXOS'] = ENV['TEXOS']
        end
    end

    def set_environment(hash)
        set_os_vars
        paths = ENV['PATH'].split(File::PATH_SEPARATOR)
        hash.subset('binpath:').keys.each do |key|
            begin
                paths << File.expand_path(hash[key])
            rescue
            end
        end
        ENV['PATH'] = paths.uniq.join(File::PATH_SEPARATOR)
        hash.subset('path:').keys.each do |path|
            key, value = "EXA:#{path.upcase}", File.expand_path(hash[path])
            ENV[key] = value
        end
    end

    def save_environment(hash,path,filename='request.tmf')
        begin
            File.open(File.join(path,filename),'w') do |f|
                set_os_vars
                ['EXA:TEXOS','TEXOS'].each do |key|
                    f.puts("#{key} = #{ENV[key]}")
                end
                hash.subset('binpath:').keys.each do |key|
                    f.puts("PATH < #{File.expand_path(@interface.get(key))}")
                end
                hash.subset('path:').keys.each do |path|
                    f.puts("EXA:#{path.upcase} = #{File.expand_path(@interface.get(path))}")
                end
            end
        rescue
        end
    end

end

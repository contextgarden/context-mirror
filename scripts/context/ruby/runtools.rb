require 'timeout'
require 'fileutils'
# require 'ftools'
require 'rbconfig'

class File

    # we don't want a/b//c
    #
    # puts File.join('a','b','c')
    # puts File.join('/a','b','c')
    # puts File.join('a:','b','c')
    # puts File.join('a/','/b/','c')
    # puts File.join('/a','/b/','c')
    # puts File.join('//a/','/b/','c')

    def File.join(*list)
        path, prefix = [*list].flatten.join(File::SEPARATOR), ''
        path.sub!(/^([\/]+)/) do
            prefix = $1
            ''
        end
        path.gsub!(/([\\\/]+)/) do
            File::SEPARATOR
        end
        prefix + path
    end

end


class Job

    $ownfile, $ownpath = '', ''

    def Job::set_own_path(file)
        $ownfile, $ownpath = File.basename(file), File.expand_path(File.dirname(file))
        $: << $ownpath
    end

    def Job::ownfile
        $ownfile
    end

    def Job::ownpath
        $ownpath
    end

end

class Job

    def initialize
        @startuppath = Dir.getwd
        @log = Array.new
        @testmode = false
        @ownpath = $ownpath
        @paths = Array.new
    end

    def exit(showlog=false)
        Dir.chdir(@startuppath)
        show_log if showlog
        Kernel::exit
    end

    def platform
        case RbConfig::CONFIG['host_os']
            when /mswin/ then :windows
                         else :unix
        end
    end

    def path(*components)
        File.join([*components].flatten)
    end

    def found(name)
        FileTest.file?(path(name)) || FileTest.directory?(path(name))
    end

    def binary(name)
        if platform == :windows then
            name.sub(/\.[^\/]+$/o,'') + '.exe'
        else
            name
        end
    end

    def suffixed(name,suffix)
        if name =~ /\.[^\/]+$/o then
            name
        else
            name + '.' + suffix
        end
    end

    def expanded(*name)
        File.expand_path(File.join(*name))
    end

    def argument(n,default=nil)
        ARGV[n] || default
    end

    def variable(name,default='')
        ENV[name] || default
    end

    def change_dir(*dir)
        dir, old = expanded(path(*dir)), expanded(Dir.getwd)
        unless old == dir then
            begin
                Dir.chdir(dir)
            rescue
                error("unable to change to path #{dir}")
            else
                if old == dir then
                    error("error in changing to path #{dir}")
                else
                    message("changed to path #{dir}")
                end
            end
        end
        # return File.expand_path(Dir.getwd)
    end

    def delete_dir(*dir)
        begin
            dir = path(*dir)
            pattern = "#{dir}/**/*"
            puts("analyzing dir #{pattern}")
            files = Dir.glob(pattern).sort.reverse
            files.each do |f|
                begin
                    # FileTest.file?(f) fails on .whatever files
                    File.delete(f)
                rescue
                    # probably directory
                else
                    puts("deleting file #{f}")
                end
            end
            files.each do |f|
                begin
                    Dir.rmdir(f)
                rescue
                    # strange
                else
                    message("deleting path #{f}")
                end
            end
            begin
                Dir.rmdir(dir)
            rescue
                # strange
            else
                message("deleting parent #{dir}")
            end
            Dir.glob(pattern).sort.each do |f|
                warning("unable to delete #{f}")
            end
        rescue
            warning("unable to delete path #{File.expand_path(dir)} (#{$!})")
        else
            message("path #{File.expand_path(dir)} removed")
        end
    end


    def create_dir(*dir)
        begin
            dir = path(*dir)
            unless FileTest.directory?(dir) then
                File.makedirs(dir)
            else
                return
            end
        rescue
            error("unable to create path #{File.expand_path(dir)}")
        else
            message("path #{File.expand_path(dir)} created")
        end
    end

    def show_dir(delay=0)
        _puts_("\n")
        print Dir.getwd + ' '
        begin
            timeout(delay) do
                loop do
                    print '.'
                    sleep(1)
                end
            end
        rescue TimeoutError
            # ok
        end
        _puts_("\n\n")
    end

    def copy_file(from,to='.',exclude=[])
        to, ex = path(to), [exclude].flatten
        Dir.glob(path(from)).each do |file|
            tofile = to.sub(/[\.\*]$/o) do File.basename(file) end
            _do_copy_(file,tofile) unless ex.include?(File.extname(file))
        end
    end

    def clone_file(from,to)
        if from and to then
            to = File.join(File.basename(from),to) if File.basename(to).empty?
            _do_copy_(from,to)
        end
    end

    def copy_dir(from,to,pattern='*',exclude=[]) # recursive
        pattern = '*' if ! pattern or pattern.empty?
        if from and to and File.expand_path(from) != File.expand_path(to) then
            ex = [exclude].flatten
            Dir.glob("#{from}/**/#{pattern}").each do |file|
                unless ex.include?(File.extname(file)) then
                    _do_copy_(file,File.join(to,file.sub(/^#{from}/, '')))
                end
            end
        end
    end

    def copy_path(from,to,pattern='*',exclude=[]) # non-recursive
        pattern = '*' if ! pattern or pattern.empty?
        if from and to and File.expand_path(from) != File.expand_path(to) then
            ex = [exclude].flatten
            Dir.glob("#{from}/#{pattern}").each do |file|
                unless ex.include?(File.extname(file)) then
                    _do_copy_(file,File.join(to,file.sub(/^#{from}/, '')))
                end
            end
        end
    end

    def _do_copy_(file,tofile)
        if FileTest.file?(file) and File.expand_path(file) != File.expand_path(tofile) then
            begin
                create_dir(File.dirname(tofile))
                File.copy(file,tofile)
            rescue
                error("unable to copy #{file} to #{tofile}")
            else
                message("file #{file} copied to #{tofile}")
            end
        else
            puts("file #{file} is not copied")
        end
    end

    def rename_file(from,to)
        from, to = path(from), path(to)
        begin
            File.move(from,to)
        rescue
            error("unable to rename #{from} to #{to}")
        else
            message("#{from} renamed to #{to}")
        end
    end

    def delete_file(pattern)
        Dir.glob(path(pattern)).each do |file|
            _do_delete_(file)
        end
    end

    def delete_files(*files)
        [*files].flatten.each do |file|
            _do_delete_(file)
        end
    end

    def _do_delete_(file)
        if FileTest.file?(file) then
            begin
                File.delete(file)
            rescue
                error("unable to delete file #{file}")
            else
                message("file #{file} deleted")
            end
        else
            message("no file #{File.expand_path(file)}")
        end
    end

    def show_log(filename=nil)
        if filename then
            begin
                if f = File.open(filename,'w') then
                    @log.each do |line|
                        f.puts(line)
                    end
                    f.close
                end
                message("log data written to #{filename}")
            rescue
                error("unable to write log to #{filename}")
            end
        else
            @log.each do |line|
                _puts_(line)
            end
        end
    end

    def _puts_(str)
        begin
            STDOUT.puts(    str)
        rescue
            STDERR.puts("error while writing '#{str}' to terminal")
        end
    end

    def puts(message)
        @log << message
        _puts_(message)
    end

    def error(message)
        puts("! #{message}")
        exit
    end

    def warning(message)
        puts("- #{message}")
    end

    def message(message)
        puts("+ #{message}")
    end

    def export_variable(variable,value)
        value = path(value) if value.class == Array
        ENV[variable] = value
        message("environment variable #{variable} set to #{value}")
        return value
    end

    def execute_command(*command)
        begin
            command = [*command].flatten.join(' ')
            message("running '#{command}'")
            _puts_("\n")
            ok = system(command)
            _puts_("\n")
            if true then # ok then
                message("finished '#{command}'")
            else
                error("error in running #{command}")
            end
        rescue
            error("unable to run #{command}")
        end
    end

    def pipe_command(*command)
        begin
            command = [*command].flatten.join(' ')
            message("running '#{command}'")
            result = `#{command}`
            _puts_("\n")
            _puts_(result)
            _puts_("\n")
        rescue
            error("unable to run #{command}")
        end
    end

    def execute_script(script)
        script = suffixed(script,'rb')
        script = path(script_path,File.basename(script)) unless found(script)
        if found(script) then
            begin
                message("loading script #{script}")
                load(script)
            rescue
                error("error in loading script #{script} (#{$!})")
            else
                message("script #{script} finished")
            end
        else
            warning("no script #{script}")
        end
    end

    def execute_binary(*command)
        command = [*command].flatten.join(' ').split(' ')
        command[0] = binary(command[0])
        execute_command(command)
    end

    def extend_path(pth)
        export_variable('PATH',"#{path(pth)}#{File::PATH_SEPARATOR}#{ENV['PATH']}")
    end

    def startup_path
        @startuppath
    end

    def current_path
        Dir.getwd
    end

    def script_path
        @ownpath
    end

    def push_path(newpath)
        newpath = File.expand_path(newpath)
        @paths.push(newpath)
        change_dir(newpath)
    end

    def pop_path
        change_dir(if @paths.length > 0 then @paths.pop else @startuppath end)
    end

    # runner = Runner.new
    # runner.texmfstart('texexec','--help')

    def texmfstart(name,args,verbose=false)
        command = ['texmfstart',"#{'--verbose' if verbose}",name,args].flatten.join(' ')
        system(command)
    end

end

class Job

    # copied from texmfstart and patched (message/error), different name

    def use_tree(tree)
        unless tree.empty? then
            begin
                setuptex = File.join(tree,'setuptex.tmf')
                if FileTest.file?(setuptex) then
                    message("tex tree : #{setuptex}")
                    ENV['TEXPATH'] = tree.sub(/\/+$/,'') #  + '/'
                    ENV['TMP'] = ENV['TMP'] || ENV['TEMP'] || ENV['TMPDIR'] || ENV['HOME']
                    case RUBY_PLATFORM
                        when /(mswin|bccwin|mingw|cygwin)/i then ENV['TEXOS'] = ENV['TEXOS'] || 'texmf-mswin'
                        when /(linux)/i                     then ENV['TEXOS'] = ENV['TEXOS'] || 'texmf-linux'
                        when /(darwin|rhapsody|nextstep)/i  then ENV['TEXOS'] = ENV['TEXOS'] || 'texmf-macosx'
                    #   when /(netbsd|unix)/i               then # todo
                        else                                     # todo
                    end
                    ENV['TEXMFOS'] = "#{ENV['TEXPATH']}/#{ENV['TEXOS']}"
                    message("preset   : TEXPATH => #{ENV['TEXPATH']}")
                    message("preset   : TEXOS   => #{ENV['TEXOS']}")
                    message("preset   : TEXMFOS => #{ENV['TEXMFOS']}")
                    message("preset   : TMP => #{ENV['TMP']}")
                    IO.readlines(File.join(tree,'setuptex.tmf')).each do |line|
                        case line
                            when /^[\#\%]/ then
                                # comment
                            when /^(.*?)\s+\=\s+(.*)\s*$/ then
                                k, v = $1, $2
                                ENV[k] = v.gsub(/\%(.*?)\%/) do
                                    ENV[$1] || ''
                                end
                                message("user set : #{k} => #{ENV[k]}")
                        end
                    end
                else
                    warning("no setup file '#{setuptex}', tree not initialized") # no error
                end
            rescue
                warning("error in setup: #{$!}")
            end
        end
    end

end

Job::set_own_path($0)

if Job::ownfile == 'runtools.rb' then

    begin
        script = ARGV.shift
        if script then
            script += '.rb' if File.extname(script).empty?
            fullname = File.expand_path(script)
            fullname = File.join(Job::ownpath,script) unless FileTest.file?(fullname)
            if FileTest.file?(fullname) then
                puts("loading script #{fullname}")
                Job::set_own_path(fullname)
                load(fullname)
            else
                puts("unknown script #{fullname}")
            end
        else
            puts("provide script name")
        end
    rescue
        puts("fatal error: #{$!}")
    end

end

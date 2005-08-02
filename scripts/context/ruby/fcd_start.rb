# Hans Hagen / PRAGMA ADE / 2005 / www.pragma-ade.com
#
# Fast Change Dir
#
# This is a kind of variant of the good old ncd
# program. This script uses the same indirect cmd
# trick as Erwin Waterlander's wcd program.
#
# === windows: fcd.cmd ===
#
# @echo off
# ruby -S fcd_start.rb %1 %2 %3 %4 %5 %6 %7 %8 %9
# if exist "%HOME%/fcd_stage.cmd" call %HOME%/fcd_stage.cmd
#
# === linux: fcd (fcd.sh) ===
#
# !/usr/bin/env sh
# ruby -S fcd_start.rb $1 $2 $3 $4 $5 $6 $7 $8 $9
# if test -f "$HOME/fcd_stage.sh" ; then
#   . $HOME/fcd_stage.sh ;
# fi;
#
# ===
#
# On linux, one should source the file: ". fcd args" in order
# to make the chdir persistent.
#
# You can create a stub with:
#
# ruby fcd_start.rb --stub --verbose

require 'rbconfig'

class FastCD

    @@rootpath = nil

    ['HOME','TEMP','TMP','TMPDIR'].each do |key|
        if ENV[key] then
            if FileTest.directory?(ENV[key]) then
                @@rootpath = ENV[key]
                break
            end
        end
    end

    exit unless @@rootpath

    @@mswindows = Config::CONFIG['host_os'] =~ /mswin/
    @@maxlength = 26

    require 'Win32API' if @@mswindows

    if @@mswindows then
        @@stubcode = [
            '@echo off',
            '',
            'if not exist "%HOME%" goto temp',
            '',
            ':home',
            '',
            'ruby -S fcd_start.rb %1 %2 %3 %4 %5 %6 %7 %8 %9',
            '',
            'if exist "%HOME%\fcd_stage.cmd" call %HOME%\fcd_stage.cmd',
            'goto end',
            '',
            ':temp',
            '',
            'ruby -S fcd_start.rb %1 %2 %3 %4 %5 %6 %7 %8 %9',
            '',
            'if exist "%TEMP%\fcd_stage.cmd" call %TEMP%\fcd_stage.cmd',
            'goto end',
            '',
            ':end'
        ].join("\n")
    else
        @@stubcode = [
            '#!/usr/bin/env sh',
            '',
            'ruby -S fcd_start.rb $1 $2 $3 $4 $5 $6 $7 $8 $9',
            '',
            'if test -f "$HOME/fcd_stage.sh" ; then',
            '  . $HOME/fcd_stage.sh ;',
            'fi;'
        ].join("\n")
    end

    @@selfpath = File.dirname($0)
    @@datafile = File.join(@@rootpath,'fcd_state.dat')
    @@cdirfile = File.join(@@rootpath,if @@mswindows then 'fcd_stage.cmd' else 'fcd_stage.sh' end)
    @@stubfile = File.join(@@selfpath,if @@mswindows then 'fcd.cmd'       else 'fcd'          end)

    def initialize(verbose=false)
        @list = Array.new
        @result = Array.new
        @pattern = ''
        @verbose = verbose
        if f = File.open(@@cdirfile,'w') then
            f << "#{if @@mswindows then 'rem' else '#' end} no dir to change to"
            f.close
        else
            report("unable to create stub #{@@cdirfile}")
        end
    end

    def filename(name)
        File.join(@@root,name)
    end

    def report(str,verbose=@verbose)
        puts(">> #{str}") if verbose
    end

    def flush(str,verbose=@verbose)
        print(str) if verbose
    end

    def scan(dir='.')
        begin
            [dir].flatten.sort.uniq.each do |dir|
                begin
                    Dir.chdir(dir)
                    report("scanning '#{dir}'")
                    # flush(">> ")
                    Dir.glob("**/*").each do |d|
                        if FileTest.directory?(d) then
                            @list << File.expand_path(d)
                            # flush(".")
                        end
                    end
                    # flush("\n")
                    @list = @list.sort.uniq
                    report("#{@list.size} entries found")
                rescue
                    report("unknown directory '#{dir}'")
                end
            end
        rescue
            report("invalid dir specification   ")
        end
    end

    def save
        begin
            if f = File.open(@@datafile,'w') then
                @list.each do |l|
                    f.puts(l)
                end
                f.close
            end
            report("#{@list.size} status bytes saved in #{@@datafile}")
        rescue
            report("error in saving status in #{@@datafile}")
        end
    end

    def load
        begin
            @list = IO.read(@@datafile).split("\n")
            report("#{@list.length} status bytes loaded from #{@@datafile}")
        rescue
            report("error in loading status from #{@@datafile}")
        end
    end

    def show
        begin
            @list.each do |l|
                puts(l)
            end
        rescue
        end
    end

    def find(pattern=nil)
        begin
            if pattern = [pattern].flatten.first then
                if  pattern.length > 0 and @pattern = pattern then
                    @result = @list.grep(/\/#{@pattern}$/i)
                    if @result.length == 0 then
                        @result = @list.grep(/\/#{@pattern}[^\/]*$/i)
                    end
                end
            end
        rescue
        end
    end

    def chdir(dir)
        begin
            if dir then
                if f = File.open(@@cdirfile,'w') then
                    if @@mswindows then
                        f.puts("cd /d #{dir.gsub('/','\\')}")
                    else
                        f.puts("cd #{dir.gsub("\\",'/')}")
                    end
                end
                report("changing to #{dir}",true)
            else
                report("not changing dir")
            end
        rescue
        end
    end

    def choose(args=[])
        unless @pattern.empty? then
            begin
                case @result.size
                    when 0 then
                        report("dir '#{@pattern}' not found",true)
                    when 1 then
                        chdir(@result[0])
                    else
                        list = @result.dup
                        begin
                            if answer = args[1] then
                                index = answer[0] - ?a
                                if dir = list[index] then
                                    chdir(dir)
                                    return
                                end
                            end
                        rescue
                        end
                        loop do
                            print("\n")
                            list.each_index do |i|
                                if i < @@maxlength then
                                    puts("#{(i+?a).chr}  #{list[i]}")
                                else
                                    puts("\n   there are #{list.length-@@maxlength} entries more")
                                    break
                                end
                            end
                            print("\n>> ")
                            if answer = wait then
                                if answer >= ?a and answer <= ?z then
                                    index = answer - ?a
                                    if dir = list[index] then
                                        print("#{answer.chr} ")
                                        chdir(dir)
                                    else
                                        print("quit\n")
                                    end
                                    break
                                elsif list.length >= @@maxlength then
                                    @@maxlength.times do |i| list.shift end
                                    print("next set")
                                    print("\n")
                                else
                                    print("quit\n")
                                    break
                                end
                            end
                        end
                    end
            rescue
                # report($!)
            end
        end
    end

    def wait
        begin
            $stdout.flush
            return getc
        rescue
            return nil
        end
    end

    def getc
        begin
            if @@mswindows then
                ch = Win32API.new('crtdll','_getch',[],'L').call
            else
                system('stty raw -echo')
                ch = $stdin.getc
                system('stty -raw echo')
            end
        rescue
            ch = nil
        end
        return ch
    end

    def check
        unless FileTest.file?(@@stubfile) then
            report("creating stub #{@@stubfile}")
            begin
                if f = File.open(@@stubfile,'w') then
                    f.puts(@@stubcode)
                    f.close
                end
            rescue
                report("unable to create stub #{@@stubfile}")
            else
                unless @mswindows then
                    begin
                        File.chmod(0755,@@stubfile)
                    rescue
                        report("unable to change protections on #{@@stubfile}")
                    end
                end
            end
        else
            report("stub #{@@stubfile} already present")
        end
    end

end

verbose, action, args = false, 30, Array.new

usage = "fcd [--make|add|show|find] [--verbose] [pattern]"

ARGV.each do |a|
    case a
        when '-v', '--verbose' then verbose = true
        when '-m', '--make'    then action = 10
        when '-a', '--add'     then action = 11
        when '-s', '--show'    then action = 20
        when '-l', '--list'    then action = 20
        when '-f', '--find'    then action = 30
        when       '--stub'    then action = 40
        when '-h', '--help'    then puts "usage: #{usage}" ; exit
        when /^\-\-.*/         then puts "unknown switch: #{a}" + "\n" + "usage: #{usage}" ; exit
                               else args << a
    end
end

$stdout.sync = true

fcd = FastCD.new(verbose)

fcd.report("Fast Change Dir / version 1.0")

case action
    when 10 then
        fcd.scan(args)
        fcd.save
    when 11 then
        fcd.load
        fcd.scan(args)
        fcd.save
    when 20 then
        fcd.load
        fcd.show
    when 30 then
        fcd.load
        fcd.find(args)
        fcd.choose(args)
    when 40
        fcd.check
end

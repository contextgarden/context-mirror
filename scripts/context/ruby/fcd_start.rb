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
#
# usage:
#
# fcd --make t:\
# fcd --add f:\project
# fcd [--find] whatever
# fcd [--find] whatever c (c being a list entry)
# fcd [--find] whatever . (last choice with this pattern)
# fcd --list

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
    @@histfile = File.join(@@rootpath,'fcd_state.his')
    @@cdirfile = File.join(@@rootpath,if @@mswindows then 'fcd_stage.cmd' else 'fcd_stage.sh' end)
    @@stubfile = File.join(@@selfpath,if @@mswindows then 'fcd.cmd'       else 'fcd'          end)

    def initialize(verbose=false)
        @list = Array.new
        @hist = Hash.new
        @result = Array.new
        @pattern = ''
        @result = ''
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

    def clear
        if FileTest.file?(@@histfile)
            begin
                File.delete(@@histfile)
            rescue
                report("error in deleting history file '#{@histfile}'")
            else
                report("history file '#{@histfile}' is deleted")
            end
        else
            report("no history file '#{@histfile}'")
        end
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
                report("#{@list.size} status bytes saved in #{@@datafile}")
            else
                report("unable to save status in #{@@datafile}")
            end
        rescue
            report("error in saving status in #{@@datafile}")
        end
    end

    def remember
        if @hist[@pattern] == @result then
            # no need to save result
        else
            begin
                if f = File.open(@@histfile,'w') then
                    @hist[@pattern] = @result
                    @hist.keys.each do |k|
                        f.puts("#{k} #{@hist[k]}")
                    end
                    f.close
                    report("#{@hist.size} history entries saved in #{@@histfile}")
                else
                    report("unable to save history in #{@@histfile}")
                end
            rescue
                report("error in saving history in #{@@histfile}")
            end
        end
    end

    def load
        begin
            @list = IO.read(@@datafile).split("\n")
            report("#{@list.length} status bytes loaded from #{@@datafile}")
        rescue
            report("error in loading status from #{@@datafile}")
        end
        begin
            IO.readlines(@@histfile).each do |line|
                if line =~ /^(.*?)\s+(.*)$/i then
                    @hist[$1] = $2
                end
            end
            report("#{@hist.length} history entries loaded from #{@@histfile}")
        rescue
            report("error in loading history from #{@@histfile}")
        end
    end

    def show
        begin
            puts("directories:")
            puts("\n")
            if @list.length > 0 then
                @list.each do |l|
                    puts(l)
                end
            else
                puts("no entries")
            end
            puts("\n")
            puts("history:")
            puts("\n")
            if @hist.length > 0 then
                @hist.keys.sort.each do |h|
                    puts("#{h} >> #{@hist[h]}")
                end
            else
                puts("no entries")
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
            else
                puts(Dir.pwd.gsub(/\\/o, '/'))
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
                @result = dir
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
                            if answer = args[1] then # assignment & test
                                if answer == '.' and @hist.key?(@pattern) then
                                    if FileTest.directory?(@hist[@pattern]) then
                                        print("last choice ")
                                        chdir(@hist[@pattern])
                                        return
                                    end
                                else
                                    index = answer[0] - ?a
                                    if dir = list[index] then
                                        chdir(dir)
                                        return
                                    end
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
                                    elsif @hist.key?(@pattern) and FileTest.directory?(@hist[@pattern]) then
                                        print("last choice ")
                                        chdir(@hist[@pattern])
                                    else
                                        print("quit\n")
                                    end
                                    break
                                elsif list.length >= @@maxlength then
                                    @@maxlength.times do |i| list.shift end
                                    print("next set")
                                    print("\n")
                                elsif @hist.key?(@pattern) and FileTest.directory?(@hist[@pattern]) then
                                    print("last choice ")
                                    chdir(@hist[@pattern])
                                    break
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

$stdout.sync = true

verbose, action, args = false, :find, Array.new

usage   = "fcd [--add|clear|find|list|make|show|stub] [--verbose] [pattern]"
version = "1.0.2"

def quit(message)
    puts(message)
    exit
end

ARGV.each do |a|
    case a
        when '-a', '--add'     then action = :add
        when '-c', '--clear'   then action = :clear
        when '-f', '--find'    then action = :find
        when '-l', '--list'    then action = :show
        when '-m', '--make'    then action = :make
        when '-s', '--show'    then action = :show
        when       '--stub'    then action = :stub
        when '-v', '--verbose' then verbose = true
        when       '--version' then quit("version: #{version}")
        when '-h', '--help'    then quit("usage: #{usage}")
        when /^\-\-.*/         then quit("error: unknown switch #{a}, try --help")
                               else args << a
    end
end

fcd = FastCD.new(verbose)
fcd.report("Fast Change Dir / version #{version}")

case action
    when :make then
        fcd.clear
        fcd.scan(args)
        fcd.save
    when :clear then
        fcd.clear
    when :add then
        fcd.load
        fcd.scan(args)
        fcd.save
    when :show then
        fcd.load
        fcd.show
    when :find then
        fcd.load
        fcd.find(args)
        fcd.choose(args)
        fcd.remember
    when :stub
        fcd.check
end

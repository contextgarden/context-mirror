#!/usr/bin/env ruby

banner = ['WWWWatch', 'version 1.0.0', '2003-2006', 'PRAGMA ADE/POD']

$: << File.expand_path(File.dirname($0)) ; $: << File.join($:.last,'lib') ; $:.uniq!

require 'base/switch'
require 'base/logger'

require 'www/common'

require 'monitor'
require 'fileutils'
require 'ftools'
require 'tempfile'
require 'timeout'
require 'thread'

class Watch < Monitor

    include Common

    @@session_prefix  = ''
    @@check_factor    = 4
    @@process_timeout = 1*60*60
    @@fast_wait_loop  = false

    @@session_line    = /^\s*(?![\#\%])(.*?)\s*\=\s*(.*?)\s*$/o
    @@session_begin   = 'begin exa session'
    @@session_end     = 'end exa session'

    attr_accessor :root_path, :work_path, :create, :cache_path, :delay, :max_threads, :max_age, :verbose

    def initialize(logger) # we need to register all @vars here becase of the monitor
        @threads     = Hash.new
        @files       = Array.new
        @stats       = Hash.new
        @skips       = Hash.new
        @root_path   = ''
        @work_path   = Dir.tmpdir
        @cache_path  = @work_path
        @last_action = Time.now
        @delay       = 1
        @max_threads = 5
        @max_age     = @@process_timeout
        @logger      = logger
        @verbose     = false
        @create      = false
        @onlyonerun  = false
        # [:INT, :TERM, :EXIT].each do |signal|
            # trap(signal) do
                # kill
                # exit # rescue false
            # end
        # end
        # at_exit do
            # kill
        # end
    end

    def trace
        if @verbose && @logger then
            @logger.report("exception: #{$!})")
            $@.each do |t|
                @logger.report(">> #{t}")
            end
        end
    end

    def report(str)
        @logger.report(str) if @logger
    end

    def setup
        @threads = Hash.new
        @files   = Array.new
        @stats   = Hash.new
        @skips   = Hash.new
        @root_path = File.expand_path(File.join(File.dirname(Dir.pwd),'.')) if @root_path.empty?
        @work_path = File.expand_path(File.join(@root_path,'work','watch')) if @work_path.empty?
        # @cache_path = File.expand_path(File.join(@root_path,'work','cache')) if @cache_path.empty?
        @cache_path = File.expand_path(File.join(File.dirname(@work_path),'cache')) if @cache_path.empty?
        if @create then
            begin File.makedirs(@work_path)  ; rescue ; end
            begin File.makedirs(@cache_path) ; rescue ; end
        end
        unless File.writable?(@work_path) then
            @work_path = File.expand_path(File.join(Dir.tmpdir,'work','watch'))
            if @create then
                begin File.makedirs(@work_path) ; rescue ; end
            end
        end
        unless File.writable?(@cache_path) then
            @cache_path = File.expand_path(File.join(Dir.tmpdir,'work','cache'))
            if @create then
                begin File.makedirs(@cache_path) ; rescue ; end
            end
        end
        unless File.writable?(@work_path) then
            puts "no valid work path: #{@work_path}"
            exit! rescue false # no checking, no at_exit done
        end
        unless File.writable?(@cache_path) then
            puts "no valid cache path: #{@cache_path}" ; # no reason to exit
        end
        @last_action = Time.now
        report("watching path #{@work_path}") if @verbose
    end

    def lock(lck)
        begin
            report("watchdog: locking #{lck}") if @verbose
            File.open(lck,'w') do |f|
                f << Time.now
            end
        rescue
            trace
        end
    end

    def unlock(lck)
        begin
            report("watchdog: unlocking #{lck}") if @verbose
            File.delete(lck)
        rescue
            trace
        end
    end

    def kill
        @threads.each do |t|
            t.kill rescue false
        end
    end

    def restart
        @files = Array.new
        @skips = Hash.new
        @stats = Hash.new
        kill # threads
    end

    def collect
        begin
            @files = Array.new
            Dir.glob("#{@work_path}/#{@@session_prefix}*.ses").each do |sessionfile|
                sessionfile = File.expand_path(sessionfile)
                begin
                    if @threads.key?(sessionfile) then
                        # leave alone
                    elsif (Time.now - File.mtime(sessionfile)) > @max_age.to_i then
                        # delete
                        FileUtils::rm_r(sessionfile) rescue false
                        FileUtils::rm_r(sessionfile.sub(/ses$/,'dir')) rescue false
                        FileUtils::rm_r(sessionfile.sub(/ses$/,'lck')) rescue false
                        begin
                            FileUtils::rm_r(File.join(@cache_path, File.basename(sessionfile.sub(/ses$/,'dir'))))
                        rescue
                            report("watchdog: problems in cache cleanup #{$!}") # if @verbose
                        end
                        @stats.delete(sessionfile) rescue false
                        @skips.delete(sessionfile) rescue false
                        report("watchdog: removing session #{sessionfile}") if @verbose
                    elsif ! @skips.key?(sessionfile) then
                        @files << sessionfile
                        report("watchdog: checking session #{sessionfile}") if @verbose
                    end
                rescue
                    # maybe purged in the meantime
                end
            end
        rescue
            if File.directory?(@work_path) then
                @files = Array.new
            else
                # maybe dir is deleted (manual cleanup)
                restart
            end
        end
        begin
            Dir.glob("#{@cache_path}/*.dir").each do |dirname|
                begin
                    if (Time.now - File.mtime(dirname)) > @max_age.to_i then
                        begin
                            FileUtils::rm_r(dirname)
                        rescue
                            report("watchdog: problems in cache cleanup #{$!}") # if @verbose
                        end
                    end
                rescue
                    # maybe purged in the meantime
                end
            end
        rescue
        end
    end

    def purge
        begin
            Dir.glob("#{@work_path}/#{@@session_prefix}*").each do |sessionfile|
                sessionfile = File.expand_path(sessionfile)
                begin
                    if (Time.now - File.mtime(sessionfile)) > @max_age.to_i then
                        begin
                            if FileTest.directory?(sessionfile) then
                                FileUtils::rm_r(sessionfile)
                            else
                                File.delete(sessionfile)
                            end
                        rescue
                        end
                        begin
                            @stats.delete(sessionfile)
                            @skips.delete(sessionfile)
                        rescue
                        end
                        report("watchdog: purging session #{sessionfile}") if @verbose
                    end
                rescue
                    # maybe purged in the meantime
                end
            end
        rescue
        end
    end

    def loaded_session_data(filename)
        begin
            if data = IO.readlines(filename) then
                return data if (data.first =~ /^[\#\%]\s*#{@@session_begin}/o) && (data.last =~ /^[\#\%]\s*#{@@session_end}/o)
            end
        rescue
            trace
        end
        return nil
    end

    def load(sessionfile)
        # we assume that we get an exception when the file is locked
        begin
            if data = loaded_session_data(sessionfile) then
                report("watchdog: loading session #{sessionfile}") if @verbose
                vars = Hash.new
                data.each do |line|
                    begin
                        if line.chomp =~ /^(.*?)\s*\=\s*(.*?)\s*$/o then
                            key, value = $1, $2
                            vars[key] = value
                        end
                    rescue
                    end
                end
                return vars
            else
                return nil
            end
        rescue
            trace
            return nil
        end
    end

    def save(sessionfile, vars)
        begin
            report("watchdog: saving session #{sessionfile}") if @verbose
            if @stats.key?(sessionfile) then
                @stats[sessionfile] = File.mtime(sessionfile)
            elsif @stats[sessionfile] == File.mtime(sessionfile) then
            else
                # construct data first
                str = "\# #{@@session_begin}\n"
                for k,v in vars do
                    str << "#{k}=#{v}\n"
                end
                str << "\# #{@@session_end}\n"
                # save as fast as possible
                File.open(sessionfile,'w') do |f|
                    f.puts(str)
                end
            end
        rescue
            report("watchdog: unable to save session #{sessionfile}") if @verbose
            trace
            return false
        else
            return true
        end
    end

    def launch
        begin
            @files.each do |sessionfile|
                if @threads.length < @max_threads then
                    begin
                        if ! @skips.key?(sessionfile) && (vars = load(sessionfile)) then
                            if (id = vars['id']) && vars['status'] then
                                if vars['status'] == 'running: background' then
                                    @last_action = Time.now
                                    @threads[sessionfile] = Thread.new(vars, sessionfile) do |vars, sessionfile|
                                        begin
                                            report("watchdog: starting thread #{sessionfile}") if @verbose
                                            dir = File.expand_path(sessionfile.sub(/ses$/,'dir'))
                                            lck = File.expand_path(sessionfile.sub(/ses$/,'lck'))
                                            start_of_run = Time.now
                                            start_of_job = start_of_run.dup
                                            max_time = @max_age
                                            begin
                                                start_of_job = vars['starttime'].to_i || start_of_run
                                                start_of_job = start_of_run if start_of_job == 0
                                            rescue
                                                start_of_job = Time.now
                                            end
                                            begin
                                                max_runtime = vars['maxtime'].to_i || @max_age
                                                max_runtime = @max_age if max_runtime == 0
                                                max_runtime = max_runtime - (Time.now.to_i - start_of_job.to_i)
                                            rescue
                                                max_runtime = @max_age
                                            end
                                            lock(lck)
                                            if max_runtime > 0 then
                                                command = vars['command'] || ''
                                                if ! command.empty? then
                                                    vars['status'] = 'running: busy'
                                                    vars['timeout'] = max_runtime.to_s
                                                    save(sessionfile,vars)
                                                    timeout(max_runtime) do
                                                        begin
                                                            command = command_string(dir,command,'process.log')
                                                            report("watchdog: #{command}") if @verbose
                                                            system(command)
                                                        rescue TimeoutError
                                                            vars['status'] = 'running: timeout'
                                                        rescue
                                                            trace
                                                            vars['status'] = 'running: aborted'
                                                        else
                                                            vars['status'] = 'running: finished'
                                                            vars['runtime'] = sprintf("%.02f",(Time.now - start_of_run))
                                                            vars['endtime'] = Time.now.to_i.to_s
                                                        end
                                                    end
                                                else
                                                    vars['status'] = 'running: aborted' # no command
                                                end
                                            else
                                                vars['status'] = 'running: aborted' # not enough time
                                            end
                                            save(sessionfile,vars)
                                            unlock(lck)
                                            report("watchdog: ending thread #{sessionfile}") if @verbose
                                            @threads.delete(sessionfile)
                                        rescue
                                            trace
                                        end
                                    end
                                else
                                    report("watchdog: skipping - id (#{vars['id']}) / status (#{vars['status']})") if @verbose
                                end
                                if @onlyonerun then
                                    @skips[sessionfile] = true
                                else
                                    @skips.delete(sessionfile)
                                end
                            else
                                # not yet ok
                            end
                        else
                            # maybe a lock
                        end
                    rescue
                        trace
                    end
                else
                    break
                end
            end
        rescue
            trace
        end
    end

    def wait
        begin
            # report(Time.now.to_s) if @verbose
            loop do
                @threads.delete_if do |k,v|
                    begin
                        v == nil || v.stop?
                    rescue
                        true
                    else
                        false
                    end
                end
                if @threads.length == @max_threads then
                    if @delay > @max_threads then
                        sleep(@delay)
                    else
                        sleep(@max_threads)
                    end
                    break if @@fast_wait_loop
                else
                    sleep(@delay)
                    break
                end
            end
        rescue
            trace
        end
    end

    def check
        begin
            time = Time.now
            if (time - @last_action) > @@check_factor*@max_age then
                report("watchdog: cleanup") if @verbose
                @stats = Hash.new
                @last_action = time
                kill
            end
        rescue
            trace
        end
    end

    def cycle
        loop do
            begin
                collect
                launch
                wait
                check
            rescue
                trace
                report("watchdog: some problem, restarting loop")
            end
        end
    end

end

class Commands

    include CommandBase

    def watch
        if watch = setup then
            watch.cycle
        else
            report("provide valid work path")
        end
    end
    def main
        watch
    end

    private

    def setup
        if watch = Watch.new(logger) then
            watch.root_path  = @commandline.option('root')
            watch.work_path  = @commandline.option('work')
            watch.cache_path = @commandline.option('cache')
            watch.create     = @commandline.option('create')
            watch.verbose    = @commandline.option('verbose')
            begin
                watch.max_threads = @commandline.option('threads').to_i
            rescue
                watch.max_threads = 5
            end
            watch.setup
        end
        return watch
    end

end

logger      = Logger.new(banner.shift)
commandline = CommandLine.new

commandline.registervalue('root', '')
commandline.registervalue('work', '')
commandline.registervalue('cache', '')
commandline.registervalue('threads', '5')

commandline.registerflag('create')

commandline.registeraction('watch', '[--work=path] [--root=path] [--create]')

commandline.registerflag('verbose')
commandline.registeraction('help')
commandline.registeraction('version')

commandline.expand

Commands.new(commandline,logger,banner).send(commandline.action || 'main')

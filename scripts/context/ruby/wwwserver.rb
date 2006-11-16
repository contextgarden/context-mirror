#!/usr/env ruby

banner = ['WWWServer', 'version 1.0.0', '2003-2006', 'PRAGMA ADE/POD']

$: << File.expand_path(File.dirname($0)) ; $: << File.join($:.last,'lib') ; $:.uniq!

require 'base/switch'
require 'base/logger'

require 'monitor'

# class WWW < Monitor
# end
# class Server < Monitor
# end

require 'www/lib'
require 'www/dir'
require 'www/login'
require 'www/exa'

require 'tempfile'
require 'ftools'
require 'webrick'

class Server

    attr_accessor :document_root, :work_path, :logs_path, :port_number, :exa_url, :verbose, :trace, :direct

    def initialize(logger)
        @httpd = nil
        @document_root = ''
        @work_path = ''
        @logs_path = ''
        @port_number = 8061
        @exa_url = 'http://localhost:8061'
        @logger = logger
        @n_of_clients = 500
        @request_timeout = 5*60
        @verbose = false
        @trace = false
        @direct = false
    end

    def report(str)
        @logger.report(str) if @logger
    end

    def setup
        if @document_root.empty? then
            rootpath = File.expand_path($0)
            @document_root = File.expand_path(File.join(File.dirname(rootpath),'..','documents'))
            unless FileTest.directory?(@document_root) then # todo: optional
                loop do
                    prevpath = rootpath.dup
                    rootpath = File.dirname(rootpath)
                    if prevpath == rootpath then
                        break
                    else
                        checkpath = File.join(rootpath,'documents')
                        # report("locating: #{checkpath}")
                        if FileTest.directory?(checkpath) then
                            @document_root = checkpath
                            break
                        else
                            checkpath = File.join(rootpath,'docroot/documents')
                            # report("locating: #{checkpath}")
                            if FileTest.directory?(checkpath) then
                                @document_root = checkpath
                                break
                            end
                        end
                    end
                end
            end
        end
        @document_root = File.join(Dir.pwd, 'documents') unless FileTest.directory?(@document_root)
        unless FileTest.directory?(@document_root) then
            report("invalid document root: #{@document_root}")
            exit
        else
            report("using document root: #{@document_root}")
        end
        #
        @work_path = File.expand_path(File.join(@document_root,'..','work')) if @work_path.empty?
        # begin File.makedirs(@work_path) ; rescue ; end # no, let's auto-temp
        if ! FileTest.directory?(@work_path) || ! FileTest.writable?(@work_path) then
            @work_path = File.expand_path(File.join(Dir.tmpdir,'exaserver','work'))
            begin File.makedirs(@logs_path) ; rescue ; end
        end
        report("using work path: #{@work_path}")
        #
        @logs_path = File.expand_path(File.join(@document_root,'..','logs')) if @logs_path.empty?
        # begin File.makedirs(@logs_path) ; rescue ; end # no, let's auto-temp
        if ! FileTest.directory?(@logs_path) || ! FileTest.writable?(@logs_path) then
            @logs_path = File.expand_path(File.join(Dir.tmpdir,'exaserver','logs'))
            begin File.makedirs(@logs_path) ; rescue ; end
        end
        report("using log path: #{@logs_path}")
        #
        if @logs_path.empty? then
            @logfile = $stderr
            @accfile = $stderr
        else
            @logfile = File.join(@logs_path,'exa-info.log')
            @accfile = File.join(@logs_path,'exa-access.log')
            begin File.delete(@logfile) ; rescue ; end
            begin File.delete(@accfile) ; rescue ; end
        end
        #
        begin
            @httpd = WEBrick::HTTPServer.new(
                :DocumentRoot        => @document_root,
                :DocumentRootOptions => { :FancyIndexing => false },
                :DirectoryIndex      => ['index.html','index.htm','showcase.pdf'],
                :Port                => @port_number.to_i,
                :Logger              => WEBrick::Log.new(@logfile, WEBrick::Log::INFO), # DEBUG
                :RequestTimeout      => @request_timeout,
                :MaxClients          => @n_of_clients,
                :AccessLog           => [
                    [ @accfile, WEBrick::AccessLog::COMMON_LOG_FORMAT  ],
                    [ @accfile, WEBrick::AccessLog::REFERER_LOG_FORMAT ],
                    [ @accfile, WEBrick::AccessLog::AGENT_LOG_FORMAT   ],
                # :CGIPathEnv   => ENV["PATH"]   # PATH environment variable for CGI.
                ]
            )
        rescue
            report("starting server at port: #{@port_number} failed")
            exit
        else
            report("running server at port: #{@port_number}")
        end

        begin
            #
            @httpd.mount_proc("/dir") do |request,reply|
                report("accepting /dir") if @verbose
                web_session(request,reply).handle_dir
            end
            @httpd.mount_proc("/login") do |request,reply|
                report("accepting /login") if @verbose
                web_session(request,reply).handle_login
            end
            @httpd.mount("/cache", WEBrick::HTTPServlet::FileHandler, File.join(@work_path,'cache'))
            # @httpd.mount_proc("/cache") do |request,reply|
                # WEBrick::HTTPServlet::FileHandler(@httpd,@work_path) # not ok
            # end
            @httpd.mount_proc("/exalogin") do |request,reply|
                report("accepting /exalogin") if @verbose
                web_session(request,reply).handle_exalogin
            end
            @httpd.mount_proc("/exadefault") do |request,reply|
                report("accepting /exadefault") if @verbose
                web_session(request,reply).handle_exadefault
            end
            @httpd.mount_proc("/exainterface") do |request,reply|
                report("accepting /exainterface") if @verbose
                web_session(request,reply).handle_exainterface
            end
            @httpd.mount_proc("/exarequest") do |request,reply|
                report("accepting /exarequest") if @verbose
                web_session(request,reply).handle_exarequest
            end
            @httpd.mount_proc("/exacommand") do |request,reply|
                report("accepting /exacommand") if @verbose
                web_session(request,reply).handle_exacommand
            end
            @httpd.mount_proc("/exastatus") do |request,reply|
                report("accepting /exastatus") if @verbose
                web_session(request,reply).handle_exastatus
            end
            @httpd.mount_proc("/exaadmin") do |request,reply|
                report("accepting /exaadmin") if @verbose
                web_session(request,reply).handle_exaadmin
            end
            #
        rescue
            report("problem in starting server: #{$!}")
        end
        [:INT, :TERM, :EXIT].each do |signal|
            trap(signal) do
                @httpd.shutdown
            end
        end
    end

    def start
        unless @httpd then
            setup
            @httpd.start
        end
    end

    def stop
        @httpd.shutdown if @httpd
    end

    def restart
        stop
        start
    end

    private

    def web_session(request,reply)
        www = WWW.new(@httpd,request,reply)
        www.set('path:work', @work_path)
        www.set('path:logs', @logs_path)
        www.set('path:root', File.dirname(@document_root))
        www.set('process:exaurl', @exa_url)
        www.set('trace:errors','yes') if @trace
        www.set('process:background', 'no') if @direct
        return www
    end

end

class Commands

    include CommandBase

    def start
        if server = setup then server.start end
    end

    def stop
        if server = setup then server.stop end
    end

    def restart
        if server = setup then server.restart end
    end

    private

    def setup
        server = Server.new(logger)
        server.document_root = @commandline.option('root')
        server.verbose = @commandline.option('verbose')
        if @commandline.option('forcetemp') then
            server.work_path = Dir.tmpdir + '/exa/work'
            server.logs_path = Dir.tmpdir + '/exa/logs'
            [server.work_path,server.logs_path].each do |d|
                begin
                    File.makedirs(d) unless FileTest.directory?(d)
                rescue
                    report("unable to create #{d}")
                    exit
                end
                unless FileTest.writable?(d) then
                    report("unable to access #{d}")
                    exit
                end
            end
        else
            server.work_path = @commandline.option('work')
            server.logs_path = @commandline.option('logs')
        end
        server.port_number = @commandline.option('port')
        server.exa_url = @commandline.option('url')
        server.trace = @commandline.option('trace')
        server.direct = @commandline.option('direct')
        return server
    end

end

logger      = Logger.new(banner.shift)
commandline = CommandLine.new

commandline.registervalue('root'   , '')
commandline.registervalue('work'   , '')
commandline.registervalue('logs'   , '')
commandline.registervalue('address', 'localhost')
commandline.registervalue('port'   , '8061')
commandline.registervalue('url'    , 'http://localhost:8061')

commandline.registeraction('start'  , 'start the server [--root --forcetemp --work --logs --address --port --url]')
commandline.registeraction('stop'   , 'stop the server')
commandline.registeraction('restart', 'restart the server')

commandline.registerflag('forcetemp')
commandline.registerflag('direct')
commandline.registerflag('verbose')
commandline.registerflag('trace')

commandline.registeraction('help')
commandline.registeraction('version')

commandline.expand

Commands.new(commandline,logger,banner).send(commandline.action || 'start')


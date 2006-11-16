#!/usr/bin/env ruby

# a direct request is just passed on
#
#   exaclient --direct --request=somerequest.exa --result=somefile.pdf
#
# in an extended request the filename in the template file is replaced by the filename
# given on the command line; templates are located on the current path and at parent
# directories (two levels); the filename is expanded to a full path
#
#   exaclient --extend --template=tmicare-l-h.exa --file=somefile.xml --result=somefile.pdf
#
# a constructed request is build out of the provided filename and action; the filename is
# expanded to a full path
#
#   exaclient --construct --action=tmicare-s-h.exa --file=somefile.xml --result=somefile.pdf
#
# in all cases, the result is either determined by a switch or taken from a reply file

banner = ['WWWClient', 'version 1.0.0', '2003-2006', 'PRAGMA ADE/POD']

$: << File.expand_path(File.dirname($0)) ; $: << File.join($:.last,'lib') ; $:.uniq!

require 'base/switch'
require 'base/logger'

require 'timeout'
require 'thread'
require 'rexml/document'
require 'net/http'

class File

    def File.backtracked(filename,level=3)
        if level > 0 && filename && ! filename.empty? then
            if FileTest.file?(filename) then
                filename
            else
                File.backtracked('../'+filename,level-1)
            end
        else
            filename
        end
    end

    def File.expanded(filename)
          File.expand_path(filename)
    end

end

class Commands

    include CommandBase

end

class Commands

    @@namespace = "xmlns:exa='http://www.pragma-ade.com/schemas/example.rng'"
    @@randchars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ" + "0123456789" + "abcdefghijklmnopqrstuvwxyz"

    def traceback
        "(error: #{$!})" + "\n  -- " + $@.join("\n  >>")
    end

    def pdf(action,filename,enabled)
        if enabled && FileTest.file?(filename) then
            begin
                report("pdf action #{action} on #{filename}")
                case action
                    when 'close' then system("pdfclose --all")
                    when 'open'  then system("pdfopen --file #{filename}")
                end
            rescue
                # forget about it
            end
        end
    end

    def status(replyfile,str) # when block, then ok
        begin
            # def status(*whatever)
            # end
            File.open(replyfile,'w') do |f|
                report("saving reply info in '#{replyfile}'")
                f.puts("<?xml version='1.0'?>\n\n")
                f.puts("<exa:reply #{@@namespace}>\n")
                if block_given? then
                    f.puts("  <exa:status>ok</exa:status>\n")
                    f.puts("  #{yield}\n")
                else
                    f.puts("  <exa:status>error</exa:status>\n")
                end
                f.puts("  <exa:comment>" + str + "</exa:comment>\n")
                f.puts("</exa:reply>\n")
                f.close
                report("saving status: #{str}")
            end
        rescue
            report("saving reply info in '#{replyfile}' fails")
        ensure
            exit
        end
        exit # to be real sure
    end


    def boundary_string (length) # copied from webrick/utils
        rand_max = @@randchars.size
        ret = ""
        length.times do
            ret << @@randchars[rand(rand_max)]
        end
        ret.upcase
    end

end

class Commands

    @@connecttimeout = 10*60 # ten minutes
    @@processtimeout = 60*60 # an hour
    @@polldelay      =  5    # 5 seconds

    def main

        datatemplate = @commandline.option('template')
        datafile     = @commandline.option('file')
        dataaction   = @commandline.option('action')

        if ! datatemplate.empty? then
            report("template '#{datatemplate}' specified without --construct")
            report("aborting")
        elsif ! dataaction.empty? then
            report("action data '#{dataaction}' specified without --construct or --extend")
            report("aborting")
        elsif ! datafile.empty? then
            report("action file '#{datafile}' specified without --construct or --extend")
            report("aborting")
        else
            report("assuming --direct")
            direct()
        end

    end

    def construct

        requestfile  = @commandline.option('request')
        replyfile    = @commandline.option('reply')

        datatemplate = @commandline.option('template')
        datafile     = @commandline.option('file')
        dataaction   = @commandline.option('action')

        domain       = @commandline.option('domain')
        project      = @commandline.option('project')
        username     = @commandline.option('username')
        password     = @commandline.option('password')

        threshold    = @commandline.option('threshold')

        datablob     = ''

        begin
            datablob = IO.read(datatemplate)
        rescue
            datablob = ''
        else
            begin
                request = REXML::Document.new(datablob)
                if e = REXML::XPath.match(request.root,"/exa:request/exa:data") then
                    datablob = e.to_s.chomp
                end
            rescue
                datablob = ''
            end
        end

        begin
            File.open(requestfile,'w') do |f|
                f.puts "<?xml version='1.0'?>\n"
                f.puts "<exa:request #{@@namespace}>\n"
                f.puts "  <exa:application>\n"
                f.puts "    <exa:action>#{dataaction}</exa:action>\n"      unless dataaction.empty?
                f.puts "    <exa:filename>#{datafile}</exa:filename>\n"    unless datafile.empty?
                f.puts "    <exa:threshold>#{threshold}</exa:threshold>\n" unless threshold.empty?
                f.puts "  </exa:application>\n"
                f.puts "  <exa:client>\n"
                f.puts "    <exa:domain>#{domain}</exa:domain>\n"
                f.puts "    <exa:project>#{project}</exa:project>\n"
                f.puts "    <exa:username>#{username}</exa:username>\n"
                f.puts "    <exa:password>#{password}</exa:password>\n"
                f.puts "  </exa:client>\n"
                if datablob.empty? then
                    f.puts "  <exa:data/>\n"
                else
                    f.puts "  #{datablob.chomp}\n"
                end
                f.puts "</exa:request>"
            end
        rescue
            status(replyfile,"unable to create '#{requestfile}'")
        end

        direct()

    end

    def extend

        requestfile  = @commandline.option('request')
        replyfile    = @commandline.option('reply')

        datatemplate = @commandline.option('template')
        datafile     = @commandline.option('file')
        dataaction   = @commandline.option('action')

        threshold    = @commandline.option('threshold')

        if datatemplate.empty? then
            status(replyfile,"invalid data template '#{datatemplate}'")
        else
            begin
                if FileTest.file?(datatemplate) && oldrequest = IO.read(datatemplate) then
                    request, done = REXML::Document.new(oldrequest), false
                    if ! threshold.empty? && e = REXML::XPath.match(request.root,"/exa:request/exa:application/exa:threshold") then
                        e.text, done = threshold, true
                    end
                    if ! dataaction.empty? && e = REXML::XPath.match(request.root,"/exa:request/exa:application/exa:action") then
                        e.text, done = dataaction, true
                    end
                    if ! datafile.empty? && e = REXML::XPath.match(request.root,"/exa:request/exa:application/exa:filename") then
                        e.text, done = datafile, true
                    end
                    #
                    if ! threshold.empty? && e = REXML::XPath.match(request.root,"/exa:request/exa:application") then
                        e = e.add_element('exa:threshold')
                        e.add_text(threshold.to_s)
                        done = true
                    end
                    #
                    report("nothing replaced in template file") unless done
                    begin
                        File.open(requestfile,'w') do |f|
                            f.puts(newrequest.to_s)
                        end
                    rescue
                        status(replyfile,"unable to create '#{requestfile}'")
                    end
                else
                    status(replyfile,"unable to read data template '#{datatemplate}'")
                end
            rescue
                status(replyfile,"unable to handle data template '#{datatemplate}'")
            end
        end

        direct()

    end

    def direct

        requestpath  = @commandline.option('path')
        requestfile  = @commandline.option('request')
        replyfile    = @commandline.option('reply')
        resultfile   = @commandline.option('result')
        datatemplate = @commandline.option('template')
        datafile     = @commandline.option('file')
        threshold    = @commandline.option('threshold')
        address      = @commandline.option('address')
        port         = @commandline.option('port')
        session_id   = @commandline.option('session')
        exaurl       = @commandline.option('exaurl')

        exaurl = "/#{exaurl}" unless exaurl =~ /^\//

        address.sub!(/^http\:\/\//io) do
            ''
        end
        address.sub!(/\:(\d+)$/io) do
            port = $1
            ''
        end

        autopdf      = @commandline.option('autopdf')

        dialogue     = nil

        resultfile.sub!(/\.[a-z]+?$/, '') # don't overwrite the source

        unless requestpath.empty? then
            begin
                if FileTest.directory?(requestpath) then
                    if Dir.chdir(requestpath) then
                        report("gone to path '#{requestpath}'")
                    else
                        status(replyfile,"unable to go to path '#{requestpath}")
                    end
                else
                    status(replyfile,"unable to locate '#{requestpath}'")
                end
            rescue
                status(replyfile,"unable to handle '#{requestpath}'")
            end
        end

        datafile     = File.expand_path(datafile)       unless datafile.empty?
        datatemplate = File.backtracked(datatemplate,3) unless datatemplate.empty?

        # request must be valid

        status(replyfile,'no request file') if requestfile.empty?
        status(replyfile,"invalid request file '#{requestfile}'") unless FileTest.file?(requestfile)

        begin
            request = IO.readlines(requestfile).join('')
            request = REXML::Document.new(request)
            status(replyfile,'invalid request (no request)')           unless request.root.fully_expanded_name=='exa:request'
            status(replyfile,'invalid request (no application block)') unless request.elements['exa:request'].elements['exa.application'] == nil # explicit nil test needed
        rescue REXML::ParseException
            status(replyfile,'invalid request (invalid xml file)')
        rescue
            status(replyfile,'invalid request (invalid file)')
        else
            report("using request file '#{requestfile}'")
        end

        # request can force session_id

        if session_id && session_id.empty? then
            begin
                id = request.elements['exa:request'].elements['exa:application'].elements['exa:session'].text
            rescue Exception
                id = ''
            ensure
                if id && ! id.empty? then
                    session_id = id
                end
            end
        end

        # request can overload reply name

        begin
            rreplyfile = request.elements['exa:request'].elements['exa:application'].elements['exa:output'].text
        rescue Exception
            rreplyfile = nil
        ensure
            if rreplyfile && ! rreplyfile.empty? then
                replyfile = rreplyfile
                report("reply file '#{replyfile} set by request'")
            else
                report("using reply file '#{replyfile}'")
            end
        end

        # request can overload result name

        begin
            rresultfile = request.elements['exa:request'].elements['exa:application'].elements['exa:result']
        rescue Exception
            rresultfile = nil
        ensure
            if rresultfile && ! rresultfile.empty? then
                resultfile = rresultfile
                report("result file '#{resultfile}' set by request")
            else
                report("using result file '#{resultfile}'")
            end
        end

        # try to connect to server

        start_time = Time.now

        processtimeout = begin @commandline.option('timeout').to_i rescue @@processtimeout end
        processtimeout = @@processtimeout if processtimeout == 0 # 'xx'.to_i => 0

        dialogue = start_dialogue(address, port, processtimeout)

        if dialogue then
            # continue
        else
            status(replyfile,'no connection')
        end

        # post request

        timeout (@@processtimeout-10) do # -10 so that we run into this one first
            begin
                report("posting request of type '#{exaurl}'")
                report("using session id '#{session_id}'") if session_id && ! session_id.empty?
                firstline, chunks, total = nil, 0, 0
                body, boundary, crlf = '', boundary_string(32), "\x0d\x0a"
                body << '--' + boundary + crlf
                body << "Content-Disposition: form-data; name=\"exa:request\""
                body << crlf
                body << "Content-Type: text/plain"
                body << crlf + crlf
                body << request.to_s
                body << crlf + '--' + boundary + crlf
if session_id && ! session_id.empty? then
    body << "Content-Disposition: form-data; name=\"exa:session\""
    body << "Content-Type: text/plain"
    body << crlf + crlf
    body << session_id
    body << crlf + '--' + boundary + crlf
end
                begin
                    File.open(datafile,'rb') do |df|
                        body << "Content-Disposition: form-data; name=\"filename\""
                        body << "Content-Type: text/plain"
                        body << crlf + crlf
                        body << datafile
                        body << crlf + '--' + boundary + crlf
                        body << "Content-Disposition: form-data; name=\"fakename\" ; filename=\"#{datafile}\""
                        body << "Content-Type: application/octetstream"
                        body << "Content-Transfer-Encoding: binary"
                        body << crlf + crlf
                        body << df.read
                        body << crlf + '--' + boundary + '--' + crlf
                    end
                rescue
                    # skip
                end
                headers = Hash.new
                headers['content-type']   = "multipart/form-data; boundary=#{boundary}"
                headers['content-length'] = body.length.to_s
                begin
                    File.open(resultfile,'wb') do |rf|
                        begin
                            # firstline is max 1024 but ok for reply
                            dialogue.post(exaurl,body,headers) do |str|
                                if ! firstline || firstline.empty? then
                                    report('receiving result') if total == 0
                                    firstline = str
                                end
                                total += 1
                                rf.write(str)
                            end
                        rescue
                            report("forced close #{traceback}")
                        end
                    end
                rescue
                    status(replyfile,'cannot open file')
                end
                begin
                    File.delete(resultfile) if File.zero?(resultfile)
                rescue
                end
                unless FileTest.file?(resultfile) then
                    report("deleting empty resultfile")
                    begin
                        File.delete(resultfile)
                    rescue
                        # nice try, an error anyway
                    end
                    status(replyfile,'empty file')
                else
                    n, id, status = 0, '', ''
                    loop do
                        again = false
                        if ! dialogue then
                            again = true
                        elsif firstline =~ /(\<exa:reply)/moi then
                            begin
                                reply = REXML::Document.new(firstline)
                                id = (REXML::XPath.match(reply.root,"/exa:reply/exa:session/text()") || '').to_s
                                status = (REXML::XPath.match(reply.root,"/exa:reply/exa:status/text()") || '').to_s
                            rescue
                                report("error in parsing reply #{traceback}")
                                break
                            else
                                report("status: #{status}")
                                if (status =~ /^running\s*\:\s*(background|busy)$/i) && (! id.empty?) then
                                    report("waiting for status reply (#{n*@@polldelay})")
                                    again = true
                                end
                            end
                        end
                        if again then
                            n += 1
                            sleep(@@polldelay) # todo: duplicate when n > 1
                            unless dialogue then
                                report('reestablishing connection')
                                dialogue = start_dialogue(address, port, processtimeout)
                            end
                            if dialogue then
                                begin
                                    File.open(resultfile,'wb') do |rf|
                                        begin
                                            body = "id=#{id}"
                                            headers = Hash.new
                                            headers['content-type']   = "application/x-www-form-urlencoded"
                                            headers['content-length'] = body.length.to_s
                                            total, firstline = 0, ''
                                            dialogue.post("/exastatus",body,headers) do |str|
                                                if ! firstline || firstline.empty? then
                                                    firstline = str
                                                end
                                                total += 1
                                                rf.write(str)
                                            end
                                        rescue
                                            report("forced close #{traceback}")
                                            dialogue = nil
                                            again = true
                                        end
                                    end
                                    begin
                                        File.delete(resultfile) if File.zero?(resultfile)
                                    rescue
                                    end
                                rescue
                                    report("error in opening file #{traceback}")
                                    status(replyfile,'cannot open file')
                                end
                            else
                                report("unable to make a connection")
                                status(replyfile,'unable to make a connection') # exit
                            end
                        else
                            break
                        end
                    end
                    case firstline
                        when /<\?xml\s*version=.*?\?>\s*<exa:reply/moi then
                            begin
                                File.delete(replyfile) if FileTest.file?(replyfile)
                                resultfile = replyfile if File.rename(resultfile,replyfile)
                            rescue
                            end
                            report("reply saved in '#{resultfile}'")
                        when /\%PDF\-/io then
                            report("done, file #{resultfile}, type pdf, #{total} chunks, #{File.size? rescue 0} bytes")
                            if resultfile =~ /\.pdf$/i then
                                report("file identified as 'pdf'")
                            elsif resultfile =~ /\..*$/o
                                report("result file suffix should be 'pdf'")
                            else
                                newresultfile = resultfile + '.pdf'
                                newresultfile.sub!(/\.pdf\.pdf/io, '.pdf')
                                pdf('close',newresultfile,autopdf)
                                begin
                                    File.delete(newresultfile) if FileTest.file?(newresultfile)
                                    resultfile = newresultfile if File.rename(resultfile,newresultfile)
                                rescue
                                    report("adding 'pdf' suffix to result name failed")
                                else
                                    report("'pdf' suffix added to result name")
                                end
                            end
                            report("result saved in '#{resultfile}'")
                            pdf('open',resultfile,autopdf)
                            status(replyfile,'ok') do
                                "<exa:filename>#{resultfile}</exa:filename>"
                            end
                        when /html/io then
                            report("done, file #{resultfile}, type html, #{total} chunks, #{File.size? rescue 0} bytes")
                            if resultfile =~ /\.(htm|html)$/i then
                                report("file identified as 'html'")
                            elsif resultfile =~ /\..*$/o
                                report("result file suffix should be 'htm'")
                            else
                                newresultfile = resultfile + '.htm'
                                begin
                                    File.delete(newresultfile) if FileTest.file?(newresultfile)
                                    resultfile = newresultfile if File.rename(resultfile,newresultfile)
                                rescue
                                    report("adding 'htm' suffix to result name failed")
                                else
                                    report("'htm' suffix added to result name")
                                end
                            end
                            report("result saved in '#{resultfile}'")
                            status(replyfile,'ok') do
                                "<exa:filename>#{resultfile}</exa:filename>"
                            end
                        else
                            report("no result file, first line #{firstline}")
                            status(replyfile,'no result file')
                    end
                end
            rescue TimeoutError
                report("aborted due to time out")
                status(replyfile,'time out')
            rescue
                report("aborted due to some problem #{traceback}")
                status(replyfile,"no answer #{traceback}")
            end
        end

        begin
            report("run time: #{Time.now-start_time} seconds")
        rescue
        end

    end

    def start_dialogue(address, port, processtimeout)
        timeout(@@connecttimeout) do
            report("trying to connect to #{address}:#{port}")
            begin
                begin
                    if dialogue = Net::HTTP.new(address, port) then
                        # dialogue.set_debug_output $stderr
                        dialogue.read_timeout = processtimeout # set this before start
                        if dialogue.start then
                            report("connected to #{address}:#{port}, timeout: #{processtimeout}")
                        else
                            retry
                        end
                    else
                        retry
                    end
                rescue
                    sleep(2)
                    retry
                else
                    return dialogue
                end
            rescue TimeoutError
                return nil
            rescue
                return nil
            end
        end
    end

end

logger      = Logger.new(banner.shift)
commandline = CommandLine.new

commandline.registerflag('autopdf')

commandline.registervalue('path'      , '')

commandline.registervalue('request'   , 'request.exa')
commandline.registervalue('reply'     , 'reply.exa')
commandline.registervalue('result'    , 'result')

commandline.registervalue('template'  , '')
commandline.registervalue('file'      , '')
commandline.registervalue('action'    , '')
commandline.registervalue('timeout'   , '')

commandline.registervalue('domain'    , 'default')
commandline.registervalue('project'   , 'default')
commandline.registervalue('username'  , 'guest')
commandline.registervalue('password'  , 'anonymous')
commandline.registervalue('exaurl'    , 'exarequest')
commandline.registervalue('threshold' , '0')
commandline.registervalue('session'   , '')

commandline.registervalue('address'   , 'localhost')
commandline.registervalue('port'      , '80')

commandline.registeraction('direct'   , '[--path --request --reply --result --autopdf]')
commandline.registeraction('construct', '[--path --request --reply --result --autopdf] --file --action')
commandline.registeraction('extend'   , '[--path --request --reply --result --autopdf] --file --action --template')

commandline.registeraction('direct')
commandline.registeraction('construct')
commandline.registeraction('extend')

commandline.registerflag('verbose')
commandline.registeraction('help')
commandline.registeraction('version')

commandline.expand

Commands.new(commandline,logger,banner).send(commandline.action || 'main')

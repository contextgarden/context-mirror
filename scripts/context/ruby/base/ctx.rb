# module    : base/ctx
# copyright : PRAGMA Advanced Document Engineering
# version   : 2005
# author    : Hans Hagen
#
# project   : ConTeXt / eXaMpLe
# concept   : Hans Hagen
# info      : j.hagen@xs4all.nl
# www       : www.pragma-ade.com

# todo: write systemcall for mpost to file so that it can be run
# faster

# report ?

require 'base/system'
require 'base/file'
require 'base/switch' # has needsupdate, bad place

require 'rexml/document'

class CtxRunner

    attr_reader :environments, :modules, :filters

    def initialize(jobname=nil,logger=nil)
        if @logger = logger then
            def report(str='')
                @logger.report(str)
            end
        else
            def report(str='')
                puts(str)
            end
        end
        @jobname = jobname
        @ctxname = nil
        @xmldata = nil
        @prepfiles = Hash.new
        @environments = Array.new
        @modules = Array.new
        @filters = Array.new
    end

    def manipulate(ctxname=nil,defaultname=nil)

        if ctxname then
            @ctxname = ctxname
            @jobname = File.suffixed(@ctxname,'tex') unless @jobname
        else
            @ctxname = File.suffixed(@jobname,'ctx') if @jobname
        end

        if not @ctxname then
            report('provide ctx file')
            return
        end

        if not FileTest.file?(@ctxname) and defaultname and FileTest.file?(defaultname) then
            @ctxname = defaultname
        end

        if not FileTest.file?(@ctxname) then
            report('provide ctx file')
            return
        end

        @xmldata = IO.read(@ctxname)

        unless @xmldata =~ /^.*<\?xml.*?\?>/moi then
            report("ctx file #{@ctxname} is no xml file, skipping")
            return
        else
            report("loading ctx file #{@ctxname}")
        end

        begin
            @xmldata = REXML::Document.new(@xmldata)
        rescue
            report('provide valid ctx file (xml error)')
            return
        else
            include(@xmldata,'ctx:include','name')
        end

        begin
            variables = Hash.new
            if @jobname then
                variables['job'] = @jobname
            end
            REXML::XPath.each(@xmldata.root,"//ctx:value[@name='job']") do |val|
                substititute(val,variables['job'])
            end
            REXML::XPath.each(@xmldata.root,"/ctx:job/ctx:message") do |mes|
                report("preprocessing: #{justtext(mes)}")
            end
            REXML::XPath.each(@xmldata.root,"/ctx:job/ctx:process/ctx:resources/ctx:environment") do |sty|
                @environments << justtext(sty)
            end
            REXML::XPath.each(@xmldata.root,"/ctx:job/ctx:process/ctx:resources/ctx:module") do |mod|
                @modules << justtext(mod)
            end
            REXML::XPath.each(@xmldata.root,"/ctx:job/ctx:process/ctx:resources/ctx:filter") do |fil|
                @filters << justtext(fil)
            end
            REXML::XPath.each(@xmldata.root,"/ctx:job/ctx:preprocess/ctx:files") do |files|
                REXML::XPath.each(files,"ctx:file") do |pattern|
                    preprocessor = pattern.attributes['processor']
                    if preprocessor and not preprocessor.empty? then
                        pattern = justtext(pattern)
                        Dir.glob(pattern).each do |oldfile|
                            newfile = "#{oldfile}.prep"
                            if File.needsupdate(oldfile,newfile) then
                                begin
                                    File.delete(newfile)
                                rescue
                                    # hope for the best
                                end
                                # there can be a sequence of processors
                                preprocessor.split(',').each do |pp|
                                    if command = REXML::XPath.first(@xmldata.root,"/ctx:job/ctx:preprocess/ctx:processors/ctx:processor[@name='#{pp}']") then
                                        # a lie: no <?xml ...?>
                                        command = REXML::Document.new(command.to_s) # don't infect original
                                        command = command.elements["ctx:processor"]
                                        report("preprocessing #{oldfile} using #{pp}")
                                        REXML::XPath.each(command,"ctx:old") do |value| replace(value,oldfile) end
                                        REXML::XPath.each(command,"ctx:new") do |value| replace(value,newfile) end
                                        variables['old'] = oldfile
                                        variables['new'] = newfile
                                        REXML::XPath.each(command,"ctx:value") do |value|
                                            if name = value.attributes['name'] then
                                                substititute(value,variables[name.to_s])
                                            end
                                        end
                                        command = justtext(command)
                                        report(command)
                                        unless ok = System.run(command) then
                                            report("error in preprocessing file #{oldfile}")
                                        end
                                    end
                                end
                                if FileTest.file?(newfile) then
                                    File.syncmtimes(oldfile,newfile)
                                else
                                    report("preprocessing #{oldfile} gave no #{newfile}")
                                end
                            else
                                report("#{oldfile} needs no preprocessing")
                            end
                            @prepfiles[oldfile] = FileTest.file?(newfile)
                        end
                    end
                end
            end
        rescue
            report("fatal error in preprocessing #{@ctxname}: #{$!}")
        end
    end

    def savelog(ctlname=nil)
        unless ctlname then
            if @jobname then
                ctlname = File.suffixed(@jobname,'ctl')
            elsif @ctxname then
                ctlname = File.suffixed(@ctxname,'ctl')
            else
                return
            end
        end
        if @prepfiles.length > 0 then
            if log = File.open(ctlname,'w') then
                log << "<?xml version='1.0' standalone='yes'?>\n\n"
                log << "<ctx:preplist>\n"
                @prepfiles.keys.sort.each do |prep|
                    log << "\t<ctx:prepfile done='#{yes_or_no(@prepfiles[prep])}'>#{File.basename(prep)}</ctx:prepfile>\n"
                end
                log << "</ctx:preplist>\n"
                log.close
            end
        else
            begin
                File.delete(ctlname)
            rescue
            end
        end
    end

    private

    def include(xmldata,element='ctx:include',attribute='name')
        loop do
            begin
                more = false
                REXML::XPath.each(xmldata.root,element) do |e|
                    begin
                        name = e.attributes.get_attribute(attribute).to_s
                        name = e.text.to_s if name.empty?
                        name.strip! if name
                        if name and not name.empty? and FileTest.file?(name) then
                            if f = File.open(name,'r') and i = REXML::Document.new(f) then
                                report("including ctx file #{name}")
                                REXML::XPath.each(i.root,"*") do |ii|
                                    xmldata.root.insert_after(e,ii)
                                    more = true
                                end
                            end
                        else
                            report("no valid ctx inclusion file #{name}")
                        end
                    rescue Exception
                        # skip this file
                    ensure
                        xmldata.root.delete(e)
                    end
                end
                break unless more
            rescue Exception
                break # forget about inclusion
            end
        end
    end

    private

    def yes_or_no(b)
        if b then 'yes' else 'no' end
    end

    private # copied from rlxtools.rb

    def justtext(str)
        str = str.to_s
        str.gsub!(/<[^>]*?>/o, '')
        str.gsub!(/\s+/o, ' ')
        str.gsub!(/&lt;/o, '<')
        str.gsub!(/&gt;/o, '>')
        str.gsub!(/&amp;/o, '&')
        str.gsub!(/&quot;/o, '"')
        str.gsub!(/[\/\\]+/o, '/')
        return str.strip
    end

    def substititute(value,str)
        if str then
            begin
                if value.attributes.key?('method') then
                    str = filtered(str.to_s,value.attributes['method'].to_s)
                end
                if str.empty? && value.attributes.key?('default') then
                    str = value.attributes['default'].to_s
                end
                value.insert_after(value,REXML::Text.new(str.to_s))
            rescue Exception
            end
        end
    end

    def replace(value,str)
        if str then
            begin
                value.insert_after(value,REXML::Text.new(str.to_s))
            rescue Exception
            end
        end
    end

    def filtered(str,method)
        str = str.to_s # to be sure
        case method
            when 'name' then # no path, no suffix
                case str
                    when /^.*[\\\/](.+?)\..*?$/o then $1
                    when /^.*[\\\/](.+?)$/o      then $1
                    when /^(.*)\..*?$/o          then $1
                    else                              str
                end
            when 'path'     then if str =~ /^(.+)([\\\/])(.*?)$/o then $1 else ''  end
            when 'suffix'   then if str =~ /^.*\.(.*?)$/o         then $1 else ''  end
            when 'nosuffix' then if str =~ /^(.*)\..*?$/o         then $1 else str end
            when 'nopath'   then if str =~ /^.*[\\\/](.*?)$/o     then $1 else str end
            else                                                               str
        end
    end

end

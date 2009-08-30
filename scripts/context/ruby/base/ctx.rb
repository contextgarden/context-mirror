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

    attr_reader :environments, :modules, :filters, :flags, :modes

    @@suffix = 'prep'

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
        @flags = Array.new
        @modes = Array.new
        @local = false
        @paths = Array.new
    end

    def register_path(str)
        @paths << str
    end

    def manipulate(ctxname=nil,defaultname=nil)

        if ctxname then
            @ctxname = ctxname
            @jobname = File.suffixed(@ctxname,'tex') unless @jobname
        else
            @ctxname = File.suffixed(@jobname,'ctx') if @jobname
        end

        if not @ctxname then
            report('no ctx file specified')
            return
        end

        if @ctxname !~ /\.[a-z]+$/ then
            @ctxname += ".ctx"
        end

        # name can be kpse:res-make.ctx
        if not FileTest.file?(@ctxname) then
            fullname, done = '', false
            if @ctxname =~ /^kpse:/ then
                begin
                    if fullname = Kpse.found(@ctxname.sub(/^kpse:/,'')) then
                        @ctxname, done = fullname, true
                    end
                rescue
                    # should not happen
                end
            else
                ['..','../..'].each do |path|
                    begin
                        fullname = File.join(path,@ctxname)
                        if FileTest.file?(fullname) then
                            @ctxname, done = fullname, true
                        end
                    rescue
                        # probably strange join
                    end
                    break if done
                end
                if ! done then
                    fullname = Kpse.found(@ctxname)
                    if FileTest.file?(fullname) then
                        @ctxname, done = fullname, true
                    end
                end
            end
            if ! done && defaultname && FileTest.file?(defaultname) then
                report("using default ctxfile #{defaultname}")
                @ctxname, done = defaultname, true
            end
            if not done then
                report('no ctx file found')
                return false
            end
        end

        if FileTest.file?(@ctxname) then
            @xmldata = IO.read(@ctxname)
        else
            report('no ctx file found')
            return false
        end

        unless @xmldata =~ /^.*<\?xml.*?\?>/moi then
            report("ctx file #{@ctxname} is no xml file, skipping")
            return
        else
            report("loading ctx file #{@ctxname}")
        end

        if @xmldata then
            # out if a sudden rexml started to be picky about namespaces
            @xmldata.gsub!(/<ctx:job>/,"<ctx:job xmlns:ctx='http://www.pragma-ade.com/rng/ctx.rng'>")
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
            root = @xmldata.root
            REXML::XPath.each(root,"/ctx:job//ctx:flags/ctx:flag") do |flg|
                @flags << justtext(flg)
            end
            REXML::XPath.each(root,"/ctx:job//ctx:resources/ctx:environment") do |sty|
                @environments << justtext(sty)
            end
            REXML::XPath.each(root,"/ctx:job//ctx:resources/ctx:module") do |mod|
                @modules << justtext(mod)
            end
            REXML::XPath.each(root,"/ctx:job//ctx:resources/ctx:filter") do |fil|
                @filters << justtext(fil)
            end
            REXML::XPath.each(root,"/ctx:job//ctx:resources/ctx:mode") do |fil|
                @modes << justtext(fil)
            end
            begin
                REXML::XPath.each(root,"//ctx:block") do |blk|
                    if @jobname && blk.attributes['pattern'] then
                        root.delete(blk) unless @jobname =~ /#{blk.attributes['pattern']}/
                    else
                        root.delete(blk)
                    end
                end
            rescue
            end
            REXML::XPath.each(root,"//ctx:value[@name='job']") do |val|
                substititute(val,variables['job'])
            end
            REXML::XPath.each(root,"/ctx:job//ctx:message") do |mes|
                report("preprocessing: #{justtext(mes)}")
            end
            REXML::XPath.each(root,"/ctx:job//ctx:process/ctx:resources/ctx:environment") do |sty|
                @environments << justtext(sty)
            end
            REXML::XPath.each(root,"/ctx:job//ctx:process/ctx:resources/ctx:module") do |mod|
                @modules << justtext(mod)
            end
            REXML::XPath.each(root,"/ctx:job//ctx:process/ctx:resources/ctx:filter") do |fil|
                @filters << justtext(fil)
            end
            REXML::XPath.each(root,"/ctx:job//ctx:process/ctx:resources/ctx:mode") do |fil|
                @modes << justtext(fil)
            end
            REXML::XPath.each(root,"/ctx:job//ctx:process/ctx:flags/ctx:flag") do |flg|
                @flags << justtext(flg)
            end
            commands = Hash.new
            REXML::XPath.each(root,"/ctx:job//ctx:preprocess/ctx:processors/ctx:processor") do |pre|
                begin
                    commands[pre.attributes['name']] = pre
                rescue
                end
            end
            suffix = @@suffix
            begin
                suffix = REXML::XPath.match(root,"/ctx:job//ctx:preprocess/@suffix").to_s
            rescue
                suffix = @@suffix
            else
                if suffix && suffix.empty? then suffix = @@suffix end
            end
            if (REXML::XPath.first(root,"/ctx:job//ctx:preprocess/ctx:processors/@local").to_s =~ /(yes|true)/io rescue false) then
                @local = true
            else
                @local = false
            end
            REXML::XPath.each(root,"/ctx:job//ctx:preprocess/ctx:files") do |files|
                REXML::XPath.each(files,"ctx:file") do |pattern|
                    suffix = @@suffix
                    begin
                        suffix = REXML::XPath.match(root,"/ctx:job//ctx:preprocess/@suffix").to_s
                    rescue
                        suffix = @@suffix
                    else
                        if suffix && suffix.empty? then suffix = @@suffix end
                    end
                    preprocessor = pattern.attributes['processor']
                    if preprocessor and not preprocessor.empty? then
                        begin
                            variables['old'] = @jobname
                            variables['new'] = ""
                            REXML::XPath.each(pattern,"ctx:value") do |value|
                                if name = value.attributes['name'] then
                                    substititute(value,variables[name.to_s])
                                end
                            end
                        rescue
                            report('unable to resolve file pattern')
                            return
                        end
                        pattern = justtext(pattern)
                        oldfiles = Dir.glob(pattern)
                        pluspath = false
                        if oldfiles.length == 0 then
                            report("no files match #{pattern}")
                            if @paths.length > 0 then
                                @paths.each do |p|
                                    oldfiles = Dir.glob("#{p}/#{pattern}")
                                    if oldfiles.length > 0 then
                                        pluspath = true
                                        break
                                    end
                                end
                                if oldfiles.length == 0 then
                                    report("no files match #{pattern} on path")
                                end
                            end
                        end
                        oldfiles.each do |oldfile|
                            newfile = "#{oldfile}.#{suffix}"
                            newfile = File.basename(newfile) if @local # or pluspath
                            if File.expand_path(oldfile) != File.expand_path(newfile) && File.needsupdate(oldfile,newfile) then
                                report("#{oldfile} needs preprocessing")
                                begin
                                    File.delete(newfile)
                                rescue
                                    # hope for the best
                                end
                                # there can be a sequence of processors
                                preprocessor.split(',').each do |pp|
                                    if command = commands[pp] then
                                        # a lie: no <?xml ...?>
                                        command = REXML::Document.new(command.to_s) # don't infect original
                                        # command = command.deep_clone() # don't infect original
                                        command = command.elements["ctx:processor"]
                                        if suf = command.attributes['suffix'] then
                                            newfile = "#{oldfile}.#{suf}"
                                        end
                                        begin
                                            newfile = File.basename(newfile) if @local
                                        rescue
                                        end
                                        REXML::XPath.each(command,"ctx:old") do |value| replace(value,oldfile) end
                                        REXML::XPath.each(command,"ctx:new") do |value| replace(value,newfile) end
                                        report("preprocessing #{oldfile} into #{newfile} using #{pp}")
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
                                        begin
                                            oldfile = File.basename(oldfile) if @local
                                        rescue
                                        end
                                    end
                                end
                                if FileTest.file?(newfile) then
                                    File.syncmtimes(oldfile,newfile)
                                else
                                    report("check target location of #{newfile}")
                                end
                            else
                                report("#{oldfile} needs no preprocessing (same file)")
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
                if @local then
                    log << "<ctx:preplist local='yes'>\n"
                else
                    log << "<ctx:preplist local='no'>\n"
                end
                @prepfiles.keys.sort.each do |prep|
                    # log << "\t<ctx:prepfile done='#{yes_or_no(@prepfiles[prep])}'>#{File.basename(prep)}</ctx:prepfile>\n"
                    log << "\t<ctx:prepfile done='#{yes_or_no(@prepfiles[prep])}'>#{prep}</ctx:prepfile>\n"
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
                        done = false
                        if name and not name.empty? then
                            ['.',File.dirname(@ctxname),'..','../..'].each do |path|
                                begin
                                    fullname = if path == '.' then name else File.join(path,name) end
                                    if FileTest.file?(fullname) then
                                        if f = File.open(fullname,'r') and i = REXML::Document.new(f) then
                                            report("including ctx file #{name}")
                                            REXML::XPath.each(i.root,"*") do |ii|
                                                xmldata.root.insert_before(e,ii)
                                                more = true
                                            end
                                        end
                                        done = true
                                    end
                                rescue
                                end
                                break if done
                            end
                        end
                        report("no valid ctx inclusion file #{name}") unless done
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
            when 'base'     then if str =~ /^.*[\\\/](.*?)$/o     then $1 else str end
            when 'full'     then str
            when 'complete' then str
            when 'expand'   then File.expand_path(str).gsub(/\\/,"/")
            else                 str
        end
    end

end

#!/usr/bin/env ruby

# program   : rlxtools
# copyright : PRAGMA Advanced Document Engineering
# version   : 2004-2005
# author    : Hans Hagen
#
# project   : ConTeXt / eXaMpLe
# concept   : Hans Hagen
# info      : j.hagen@xs4all.nl
# www       : www.pragma-ade.com

banner = ['RlxTools', 'version 1.0.1', '2004/2005', 'PRAGMA ADE/POD']

$: << File.expand_path(File.dirname($0)) ; $: << File.join($:.last,'lib') ; $:.uniq!

require 'base/switch'
require 'base/logger'
require 'base/system'
require 'base/kpse'

require 'fileutils'
# require 'ftools'
require 'rexml/document'

class Commands

    include CommandBase

    # <?xml version='1.0 standalone='yes'?>
    # <rl:manipulators>
    #    <rl:manipulator name='lowres' suffix='pdf'>
    #         <rl:step>
    #             texmfstart
    #             --verbose
    #             --iftouched=<rl:value name='path'/>/<rl:value name='file'/>,<rl:value name='path'/>/<rl:value name='prefix'/><rl:value name='file'/>
    #             pstopdf
    #             --method=5
    #             --inputpath=<rl:value name='path'/>
    #             --outputpath=<rl:value name='path'/>/<rl:value name='prefix'/>
    #             <rl:value name='file'/>
    #         </rl:step>
    #     </rl:manipulator>
    # </rl:manipulators>
    #
    # <?xml version='1.0' standalone='yes'?>
    # <rl:library>
    #     <rl:usage>
    #         <rl:type>figure</rl:type>
    #         <rl:state>found</rl:state>
    #         <rl:file>cow.pdf</rl:file>
    #         <rl:suffix>pdf</rl:suffix>
    #         <rl:path>.</rl:path>
    #         <rl:conversion>lowres</rl:conversion>
    #         <rl:prefix>lowres/</rl:prefix>
    #         <rl:width>276.03125pt</rl:width>
    #         <rl:height>200.75pt</rl:height>
    #     </rl:usage>
    # </r:library>

    def manipulate

        procname = @commandline.argument('first')  || ''
        filename = @commandline.argument('second') || ''

        procname = Kpse.found(procname)

        if procname.empty? || ! FileTest.file?(procname) then
            report('provide valid manipulator file')
        elsif filename.empty? || ! FileTest.file?(filename) then
            report('provide valid resource log file')
        else
            begin
                data = REXML::Document.new(File.new(filename))
            rescue
                report('provide valid resource log file (xml error)')
                return
            end
            begin
                proc = REXML::Document.new(File.new(procname))
            rescue
                report('provide valid manipulator file (xml error)')
                return
            end
            report("manipulator file: #{procname}")
            report("resourcelog file: #{filename}")
            begin
                nofrecords, nofdone = 0, 0
                REXML::XPath.each(data.root,"/rl:library/rl:usage") do |usage|
                    nofrecords += 1
                    variables = Hash.new
                    usage.elements.each do |e|
                        variables[e.name] = e.text.to_s
                    end
                    report("processing record #{nofrecords} (#{variables['file'] || 'noname'}: #{variables.size} entries)")
                    if conversion = variables['conversion'] then
                        report("testing for conversion #{conversion}")
                        if suffix = variables['suffix'] then
                            suffix.downcase!
                            if ! suffix.empty? && variables['file'] && variables['file'] !~ /\.([a-z]+)$/i then
                                variables['file'] += ".#{suffix}"
                            end
                            if file = variables['file'] then
                                report("conversion #{conversion} for suffix #{suffix} for file #{file}")
                            else
                                report("conversion #{conversion} for suffix #{suffix}")
                            end
                            pattern = "@name='#{conversion}' and @suffix='#{suffix}'"
                            if steps = REXML::XPath.first(proc.root,"/rl:manipulators/rl:manipulator[#{pattern}]") then
                                localsteps = steps.deep_clone
                                ['rl:old','rl:new'].each do |tag|
                                    REXML::XPath.each(localsteps,tag) do |extras|
                                        REXML::XPath.each(extras,"rl:value") do |value|
                                            if name = value.attributes['name'] then
                                                substitute(value,variables[name.to_s] || '')
                                            end
                                        end
                                    end
                                end
                                old = REXML::XPath.first(localsteps,"rl:old")
                                new = REXML::XPath.first(localsteps,"rl:new")
                                if old && new then
                                    old, new = justtext(old.to_s), justtext(new.to_s)
                                    variables['old'], variables['new'] = old, new
                                    begin
                                        [old,new].each do |d|
                                            File.makedirs(File.dirname(d))
                                        end
                                    rescue
                                        report("error during path creation")
                                    end
                                    report("old file #{old}")
                                    report("new file #{new}")
                                    level = if File.needsupdate(old,new) then 2 else 0 end
                                else
                                    level = 1
                                end
                                if level>0 then
                                    REXML::XPath.each(localsteps,"rl:step") do |command|
                                        REXML::XPath.each(command,"rl:old") do |value|
                                            replace(value,old)
                                        end
                                        REXML::XPath.each(command,"rl:new") do |value|
                                            replace(value,new)
                                        end
                                        REXML::XPath.each(command,"rl:value") do |value|
                                            if name = value.attributes['name'] then
                                                substitute(value,variables[name.to_s])
                                            end
                                        end
                                        str = justtext(command.to_s)
                                        # str.gsub!(/(\.\/)+/io, '')
                                        report("command #{str}")
                                        System.run(str) unless @commandline.option('test')
                                        report("synchronizing #{old} and #{new}")
                                        File.syncmtimes(old,new) if level > 1
                                        nofdone += 1
                                    end
                                else
                                    report("no need for a manipulation")
                                end
                            else
                                report("no manipulator found")
                            end
                        else
                            report("no suffix specified")
                        end
                    else
                        report("no conversion needed")
                    end
                end
                if nofdone > 0 then
                    jobname = filename.gsub(/\.(.*?)$/,'') # not 'tuo' here
                    tuoname = jobname + '.tuo'
                    if FileTest.file?(tuoname) && (f = File.open(tuoname,'a')) then
                        f.puts("%\n% number of rlx manipulations: #{nofdone}\n")
                        f.close
                    end
                end
            rescue
                report("error in manipulating files: #{$!}")
            end
            begin
                logname = "#{filename}.log"
                File.delete(logname) if FileTest.file?(logname)
                File.copy(filename,logname)
            rescue
            end
        end

    end

    private

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

    def substitute(value,str='')
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

class Commands

    include CommandBase

    @@xmlbanner = "<?xml version='1.0' standalone='yes'?>"

    def identify(resultfile='rlxtools.rli')
        if @commandline.option('collect') then
            begin
                File.open(resultfile,'w') do |f|
                    f << "#{@@xmlbanner}\n"
                    f << "<rl:identification>\n"
                    @commandline.arguments.each do |filename|
                        if state = do_identify(filename) then
                            report("#{filename} is identified")
                            f << state
                        else
                            report("unable to identify #{filename}")
                        end
                    end
                    f << "</rl:identification>\n"
                    report("result saved in #{resultfile}")
                end
            rescue
                report("error in writing result")
            end
        else
            @commandline.arguments.each do |filename|
                if state = do_identify(filename) then
                    begin
                        File.open(filename+'.rli','w') do |f|
                            f << "#{@@xmlbanner}\n"
                            f << state
                        end
                    rescue
                        report("error in identifying #{filename}")
                    else
                        report("#{filename} is identified")
                    end
                else
                    report("unable to identify #{filename}")
                end
            end
        end
    end

    private

    def do_identify(filename,centimeters=false)
        begin
            str = nil
            if FileTest.file?(filename) then
                # todo: use pdfinto for pdf files, identify is bugged
                if centimeters then
                    result = `identify -units PixelsPerCentimeter -format \"x=%x,y=%y,w=%w,h=%h,b=%b\" #{filename}`.chomp.split(',')
                else
                    result = `identify -units PixelsPerInch       -format \"x=%x,y=%y,w=%w,h=%h,b=%b\" #{filename}`.chomp.split(',')
                end
                tags = Hash.new
                result.each do |r|
                    if rr = r.split("=") then
                        tags[rr[0]] = rr[1]
                    end
                end
                size   = (tags['b']||0).to_i
                width  = unified(tags['w']||0,tags['x']||'1')
                height = unified(tags['h']||0,tags['y']||'1')
                if size > 0 then
                    str = ''
                    str << "<rl:identify name='#{File.basename(filename)}'>\n"
                    str << "  <rl:size>#{size}</rl:size>\n"
                    str << "  <rl:path>#{File.dirname(filename).sub(/\\/o,'/')}</rl:path>\n"
                    str << "  <rl:width>#{width}</rl:width>\n"
                    str << "  <rl:height>#{height}</rl:height>\n"
                    str << "</rl:identify>\n"
                end
            else
                str = nil
            end
        rescue
            str = nil
        end
        return str
    end

    def unified(dim,res)
        case res
            when /([\d\.]+)\s*PixelsPerInch/io then
                sprintf("%.4fin",dim.to_f/$1.to_f)
            when /([\d\.]+)\s*PixelsPerCentimeter/io then
                sprintf("%.4fcm",dim.to_f/$1.to_f)
            when /([\d\.]+)\s*PixelsPerMillimeter/io then
                sprintf("%.4fmm",dim.to_f/$1.to_f)
            when /([\d\.]+)\s*PixelsPerPoint/io then
                sprintf("%.4fbp",dim.to_f/$1.to_f)
            else
                sprintf("%.4fbp",dim.to_f)
        end
    end

end

logger      = Logger.new(banner.shift)
commandline = CommandLine.new

commandline.registeraction('manipulate', '[--test] manipulatorfile resourselog')
commandline.registeraction('identify'  , '[--collect] filename')

commandline.registeraction('help')
commandline.registeraction('version')

commandline.registerflag('test')
commandline.registerflag('collect')

commandline.expand

Commands.new(commandline,logger,banner).send(commandline.action || 'help')

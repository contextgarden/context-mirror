#!/usr/bin/env ruby

# program   : xmltools
# copyright : PRAGMA Advanced Document Engineering
# version   : 2002-2005
# author    : Hans Hagen
#
# project   : ConTeXt / eXaMpLe
# concept   : Hans Hagen
# info      : j.hagen@xs4all.nl
# www       : www.pragma-ade.com

# todo : use kpse lib

# This script will harbor some handy manipulations on tex
# related files.

banner = ['XMLTools', 'version 1.2.2', '2002/2007', 'PRAGMA ADE/POD']

$: << File.expand_path(File.dirname($0)) ; $: << File.join($:.last,'lib') ; $:.uniq!

require 'base/switch'
require 'base/logger'

class String

    def astring(n=10)
        gsub(/(\d+)/o) do $1.to_s.rjust(n) end.gsub(/ /o, '0')
    end

    def xstring
        if self =~ /\'/o then
            "\"#{self.gsub(/\"/, '&quot;')}\""
        else
            "\'#{self}\'"
        end
    end

end

class Array

    def asort(n=10)
        sort {|x,y| x.astring(n) <=> y.astring(n)}
    end

end

class Commands

    include CommandBase

    def dir

        @xmlns     = "xmlns='http://www.pragma-ade.com/rlg/xmldir.rng'"

        pattern    = @commandline.option('pattern')
        recurse    = @commandline.option('recurse')
        stripname  = @commandline.option('stripname')
        longname   = @commandline.option('longname')
        url        = @commandline.option('url')
        outputfile = @commandline.option('output')
        root       = @commandline.option('root')

        def generate(output,files,url,root,longname)

            class << output
                def xputs(str,n=0)
                    puts("#{' '*n}#{str}")
                end
            end

            dirname = ''
            output.xputs("<?xml version='1.0'?>\n\n")
            if ! root || root.empty? then
                rootatt = @xmlns
            else
                rootatt = " #{@xmlns} root='#{root}'"
            end
            rootatt += " timestamp='#{Time.now}'"
            if url.empty? then
                output.xputs("<files #{rootatt}>\n")
            else
                output.xputs("<files url='#{url}'#{rootatt}>\n")
            end
            files.each do |f|
                bn, dn = File.basename(f), File.dirname(f)
                if dirname != dn then
                    output.xputs("</directory>\n", 2) if dirname != ''
                    output.xputs("<directory name='#{dn}'>\n", 2)
                    dirname = dn
                end
                if longname && dn != '.' then
                    output.xputs("<file name='#{dn}/#{bn}'>\n", 4)
                else
                    output.xputs("<file name='#{bn}'>\n", 4)
                end
                output.xputs("<base>#{bn.sub(/\..*$/,'')}</base>\n", 6)
                if File.stat(f).file? then
                    bt = bn.sub(/^.*\./,'')
                    if bt != bn then
                        output.xputs("<type>#{bt}</type>\n", 6)
                    end
                    output.xputs("<size>#{File.stat(f).size}</size>\n", 6)
                    permissions = ''
                    permissions << 'r' if File.readable?(f)
                    permissions << 'w' if File.writable?(f)
                    permissions << 'x' if File.executable?(f)
                    output.xputs("<permissions>#{permissions}</permissions>\n", 6) unless permissions.empty?
                end
                output.xputs("<date>#{File.stat(f).mtime.strftime("%Y-%m-%d %H:%M")}</date>\n", 6)
                output.xputs("</file>\n", 4)
            end
            output.xputs("</directory>\n", 2) if dirname != ''
            output.xputs("</files>\n")

        end

        if pattern.empty? then
            report('provide --pattern=')
            return
        end

        unless outputfile.empty? then
            begin
                output = File.open(outputfile,'w')
            rescue
                report("unable to open #{outputfile}")
                return
            end
        else
            report('provide --output')
            return
        end

        if stripname && pattern.class == String && ! pattern.empty? then
            pattern = File.dirname(pattern)
        end

        pattern = '*' if pattern.empty?

        unless root.empty? then
            unless FileTest.directory?(root) then
                report("unknown root #{root}")
                return
            end
            begin
                Dir.chdir(root)
            rescue
                report("unable to change to root #{root}")
                return
            end
        end

        generate(output, globbed(pattern, recurse), url, root, longname)

        output.close if output

    end

    alias ls :dir

    def mmlpages

        file  = @commandline.argument('first')
        eps   = @commandline.option('eps')
        jpg   = @commandline.option('jpg')
        png   = @commandline.option('png')
        style = @commandline.option('style')
        modes = @commandline.option('modes')

        file = file.sub(/\.xml/io, '')
        long = "#{file}-mmlpages"
        if FileTest.file?(file+'.xml') then
            style = "--arg=\"style=#{style}\"" unless style.empty?
            modes = "--mode=#{modes}" unless modes.empty?
            if system("texmfstart texexec --batch --pdf --once --result=#{long} --use=mmlpag #{style} #{modes} #{file}.xml") then
                if eps then
                    if f = open("#{file}-mmlpages.txt") then
                        while line = f.gets do
                            data = Hash.new
                            if fields = line.split then
                                fields.each do |fld|
                                    key, value = fld.split('=')
                                    data[key] = value if key && value
                                end
                                if data.key?('p') then
                                    page = data['p']
                                    name = "#{long}-#{page.to_i-1}"
                                    if eps then
                                        report("generating eps file #{name}")
                                        if system("pdftops -eps -f #{page} -l #{page} #{long}.pdf #{name}.eps") then
                                            if data.key?('d') then
                                                if epsfile = IO.read("#{name}.eps") then
                                                    epsfile.sub!(/^(\%\%BoundingBox:.*?$)/i) do
                                                        newline = $1 + "\n%%Baseline: #{data['d']}\n"
                                                        if data.key?('w') && data.key?('h') then
                                                            newline += "%%PositionWidth: #{data['w']}\n"
                                                            newline += "%%PositionHeight: #{data['h']}\n"
                                                            newline += "%%PositionDepth: #{data['d']}"
                                                        end
                                                        newline
                                                    end
                                                    if g = File.open("#{name}.eps",'wb') then
                                                        g.write(epsfile)
                                                        g.close
                                                    end
                                                end
                                            end
                                        else
                                            report("error in generating eps from #{name}")
                                        end
                                    end
                                end
                            end
                        end
                        f.close
                    else
                        report("missing data log file #{file}")
                    end
                end
                if png then
                    report("generating png file for #{long}")
                    system("imagemagick #{long}.pdf #{long}-%d.png")
                end
                if jpg then
                    report("generating jpg files for #{long}")
                    system("imagemagick #{long}.pdf #{long}-%d.jpg")
                end
            else
                report("error in processing file #{file}")
            end
            system("texmfstart ctxtools --purge")
        else
            report("error in processing file #{file}")
        end

    end

    def analyze

        file    = @commandline.argument('first')
        result  = @commandline.option('output')
        utf     = @commandline.option('utf')
        process = @commandline.option('process')

        if FileTest.file?(file) then
            if data = IO.read(file) then
                if data =~ /<?xml.*?version\=/ then
                    report("xml file #{file} loaded")
                    elements   = Hash.new
                    attributes = Hash.new
                    entities   = Hash.new
                    chars      = Hash.new
                    unicodes   = Hash.new
                    names      = Hash.new
                    data.scan(/<([^>\s\/\!\?]+)([^>]*?)>/o) do
                        element, attributelist = $1, $2
                        if elements.key?(element) then
                            elements[element] += 1
                        else
                            elements[element] = 1
                        end
                        attributelist.scan(/\s*([^\=]+)\=([\"\'])(.*?)(\2)/) do
                            key, value = $1, $3
                            attributes[element] = Hash.new unless attributes.key?(element)
                            attributes[element][key] = Hash.new unless attributes[element].key?(key)
                            if attributes[element][key].key?(value) then
                                attributes[element][key][value] += 1
                            else
                                attributes[element][key][value] = 1
                            end
                        end
                    end
                    data.scan(/\&([^\;]+)\;/o) do
                        entity = $1
                        if entities.key?(entity) then
                            entities[entity] += 1
                        else
                            entities[entity] = 1
                        end
                    end
                    if utf then
                        data.scan(/(\w)/u) do
                            chars[$1] = (chars[$1] || 0) + 1
                        end
                        if chars.size > 0 then
                            begin
                                # todo : use kpse lib
                                filename, ownpath, foundpath = 'contextnames.txt', File.dirname($0), ''
                                begin
                                    foundpath = File.dirname(`kpsewhich -progname=context -format=\"other text files\" #{filename}`.chomp)
                                rescue
                                    foundpath = '.'
                                else
                                    foundpath = '.' if foundpath.empty?
                                end
                                [foundpath,ownpath,File.join(ownpath,'../../../context/data')].each do |path|
                                    fullname = File.join(path,filename)
                                    if FileTest.file?(fullname) then
                                        report("loading '#{fullname}'")
                                        # rough scan, we assume no valid lines after comments
                                        IO.read(fullname).scan(/^([0-9A-F][0-9A-F][0-9A-F][0-9A-F])\s*\;\s*(.*?)\s*\;\s*(.*?)\s*\;\s*(.*?)\s*$/) do
                                            names[$1.hex.to_i.to_s] = [$2,$3,$4]
                                        end
                                        break
                                    end
                                end
                            rescue
                            end
                        end
                    end
                    result = file.gsub(/\..*?$/, '') + '.xlg' if result.empty?
                    if f = File.open(result,'w') then
                        report("saving report in #{result}")
                        f.puts "<?xml version='1.0'?>\n"
                        f.puts "<document>\n"
                        if entities.length>0 then
                            total = 0
                            entities.each do |k,v|
                                total += v
                            end
                            f.puts "  <entities n=#{total.to_s.xstring}>\n"
                            entities.keys.asort.each do |entity|
                                f.puts "    <entity name=#{entity.xstring} n=#{entities[entity].to_s.xstring}/>\n"
                            end
                            f.puts "  </entities>\n"
                        end
                        if utf && (chars.size > 0) then
                            total = 0
                            chars.each do |k,v|
                                total += v
                            end
                            f.puts "  <characters n=#{total.to_s.xstring}>\n"
                            chars.each do |k,v|
                                if k.length > 1 then
                                    begin
                                        u = k.unpack('U')
                                        unicodes[u] = (unicodes[u] || 0) + v
                                    rescue
                                        report("invalid utf codes")
                                    end
                                end
                            end
                            unicodes.keys.sort.each do |u|
                                ustr = u.to_s
                                if names[ustr] then
                                    f.puts "    <character number=#{ustr.xstring} pname=#{names[ustr][0].xstring} cname=#{names[ustr][1].xstring} uname=#{names[ustr][2].xstring} n=#{unicodes[u].to_s.xstring}/>\n"
                                else
                                    f.puts "    <character number=#{ustr.xstring} n=#{unicodes[u].to_s.xstring}/>\n"
                                end
                            end
                            f.puts "  </characters>\n"
                        end
                        if elements.length>0 then
                            f.puts "  <elements>\n"
                            elements.keys.sort.each do |element|
                                if attributes.key?(element) then
                                    f.puts "    <element name=#{element.xstring} n=#{elements[element].to_s.xstring}>\n"
                                    if attributes.key?(element) then
                                        attributes[element].keys.asort.each do |attribute|
                                            f.puts "      <attribute name=#{attribute.xstring}>\n"
                                            if attribute =~ /id$/o then
                                                nn = 0
                                                attributes[element][attribute].keys.asort.each do |value|
                                                    nn += attributes[element][attribute][value].to_i
                                                end
                                                f.puts "        <instance value=#{"*".xstring} n=#{nn.to_s.xstring}/>\n"
                                            else
                                                attributes[element][attribute].keys.asort.each do |value|
                                                    f.puts "        <instance value=#{value.xstring} n=#{attributes[element][attribute][value].to_s.xstring}/>\n"
                                                end
                                            end
                                            f.puts "      </attribute>\n"
                                        end
                                    end
                                    f.puts "    </element>\n"
                                else
                                    f.puts "    <element name=#{element.xstring} n=#{elements[element].to_s.xstring}/>\n"
                                end
                            end
                            f.puts "  </elements>\n"
                        end
                        f.puts "</document>\n"
                        f.close
                        if process then
                            system("texmfstart texexec --purge --pdf --use=xml-analyze #{result}")
                        end
                    else
                        report("unable to open file '#{result}'")
                    end
                else
                    report("invalid xml file '#{file}'")
                end
            else
                report("unable to load file '#{file}'")
            end
        else
            report("unknown file '#{file}'")
        end
    end

    def filter

        require "rexml/document"

        element = @commandline.option('element')
        files   = @commandline.arguments
        result  = "xmltools.xlg"

        if element.empty? then
            report("provide element using --element")
        elsif files.length == 0 then
            report("provide filename(s)")
        else
            begin
                File.open(result,'w') do |f|
                    f << "<?xml version='1.0'?>\n\n"
                    f << "<xlg:document>\n\n"
                    total = 0
                    files.sort.each do |file|
                        begin
                            report("loading: #{file}")
                            data = REXML::Document.new(IO.read(file))
                        rescue
                            report("error: invalid xml")
                        else
                            found = 0
                            report("filtering: #{element}")
                            REXML::XPath.each(data,"//#{element}") do |table|
                                str = table.to_s
                                if str.length > 0 then
                                    total += 1
                                    found += 1
                                    report("found: #{total} / #{found} / #{str.length} bytes")
                                    f << "<xlg:file name='#{file}'>\n\n" unless found > 1
                                    f << "<xlg:filtered n='#{total}' m='#{found}'>"
                                    f << "#{str.gsub(/^\s*/m,'').gsub(/\s*$/m,'')}"
                                    f << "</xlg:filtered>\n\n"
                                end
                            end
                            f << "</xlg:file>\n\n" if found > 0
                        end
                    end
                    f << "</xlg:document>\n"
                end
                report("result: #{result}")
            rescue
                report("error in opening #{result}")
            end
        end

    end

    def enhance
        oldname = @commandline.argument('first')
        newname = @commandline.argument('second')
        verbose = @commandline.option('verbose')
        # todo: options, maybe a config file
        if ! newname || newname.empty? then
            newname = oldname + ".prep"
        end
        if FileTest.file?(oldname) then
            report("") if verbose
            data     = IO.read(oldname)
            elements = Array.new
            preamble = ""
            done     = false
            data.sub!(/^(.*?)\s*(<[a-z])/moi) do
                preamble = $1
                $2
            end
            # hide elements
            data.gsub!(/<([^>]*?)>/moi) do
                elements << $1
                "<#{elements.length}>"
            end
            # abc[-/]def
            data.gsub!(/([a-z]{3,})([\/\-\(\)]+)([a-z]{3,})/moi) do
                done = true
                report("compound: #{$1}#{$2}#{$3}") if verbose
                "#{$1}<compound token='#{$2}'/>#{$3}"
            end
            # (abcd
            # data.gsub!(/(\()([a-z]{4,})/moi) do
                # done = true
                # report("compound: #{$1}#{$2}") if verbose
                # "<compound token='#{$1}'/>#{$2}"
            # end
            # abcd)
            # data.gsub!(/(\()([a-z]{4,})/moi) do
                # done = true
                # report("compound: #{$1}#{$2}") if verbose
                # "#{$2}<compound token='#{$2}'/>"
            # end
            # roll back elements
            data.gsub!(/<(\d+)>/moi) do
                "<#{elements.shift}>"
            end
            File.open(newname,'wb') do |f|
                f << preamble
                f << "\n"
                f << data
            end
            if verbose then
                if done then
                    report("")
                    report(oldname," converted to ",newname)
                else
                    report(oldname," copied to ",newname)
                end
            end
        end
    end

    def cleanup # todo, share loading/saving with previous

        file    = @commandline.argument('first')
        force   = @commandline.option('force')
        verbose = @commandline.option('verbose')

        if FileTest.file?(file) then
            if data = IO.read(file) then
                if data =~ /<?xml.*?version\=/ then
                    data = doxmlcleanup(data,verbose)
                    result = if force then file else file.gsub(/\..*?$/, '') + '.xlg' end
                    begin
                        if f = File.open(result,'w') then
                            f << data
                            f.close
                        end
                    rescue
                        report("unable to open file '#{result}'")
                    end
                else
                    report("invalid xml file '#{file}'")
                end
            else
                report("unable to load file '#{file}'")
            end
        else
            report("unknown file '#{file}'")
        end

    end

    def doxmlreport(str,verbose=false)
        if verbose then
            result = str
            report(result)
            return result
        else
            return str
        end
    end

    def doxmlcleanup(data="",verbose=false)

        # remove funny spaces (looks cleaner)
        #
        # data = "<whatever ></whatever ><whatever />"

        data.gsub!(/\<(\/*\w+)\s*(\/*)>/o) do
            "<#{$1}#{$2}>"
        end

        # remove funny ampersands
        #
        # data = "<x> B&W </x>"

        data.gsub!(/\&([^\<\>\&]*?)\;/mo) do
            "<entity name='#{$1}'/>"
        end
        data.gsub!(/\&/o) do
            doxmlreport("&amp;",verbose)
        end
        data.gsub!(/\<entity name=\'(.*?)\'\/\>/o) do
            doxmlreport("&#{$1};",verbose)
        end

        # remove funny < >
        #
        # data = "<x> < 5% </x>"

        data.gsub!(/<([^>].*?)>/o) do
            tag = $1
            case tag
                when /^\//o then
                    "<#{tag}>" # funny tag but ok
                when /\/$/o then
                    "<#{tag}>" # funny tag but ok
                when /</o then
                    doxmlreport("&lt;#{tag}>",verbose)
                else
                    "<#{tag}>"
            end
        end

        # remove funny < >
        #
        # data = "<x> > 5% </x>"

        data.gsub!(/<([^>].*?)>([^\>\<]*?)>/o) do
            doxmlreport("<#{$1}>#{$2}&gt;",verbose)
        end

        return data
    end

    # puts doxmlcleanup("<whatever ></whatever ><whatever />")
    # puts doxmlcleanup("<x> B&W </x>")
    # puts doxmlcleanup("<x> < 5% </x>")
    # puts doxmlcleanup("<x> > 5% </x>")

end

logger      = Logger.new(banner.shift)
commandline = CommandLine.new

commandline.registeraction('dir',     'generate directory listing')
commandline.registeraction('mmlpages','generate graphic from mathml')
commandline.registeraction('analyze', 'report entities and elements [--utf --process]')
commandline.registeraction('cleanup', 'cleanup xml file [--force]')
commandline.registeraction('enhance', 'enhance xml file (partial)')
commandline.registeraction('filter', 'filter elements from xml file [element=]')

# commandline.registeraction('dir',     'filename --pattern= --output= [--recurse --stripname --longname --url --root]')
# commandline.registeraction('mmlpages','filename [--eps --jpg --png --style= --mode=]')

commandline.registeraction('ls')

commandline.registeraction('help')
commandline.registeraction('version')

commandline.registerflag('stripname')
commandline.registerflag('longname')
commandline.registerflag('recurse')
commandline.registerflag('verbose')

commandline.registervalue('pattern')
commandline.registervalue('element')
commandline.registervalue('url')
commandline.registervalue('output')
commandline.registervalue('root')

commandline.registerflag('eps')
commandline.registerflag('png')
commandline.registerflag('jpg')
commandline.registerflag('utf')
commandline.registerflag('process')
commandline.registervalue('style')
commandline.registervalue('modes')

commandline.expand

Commands.new(commandline,logger,banner).send(commandline.action || 'help')

#!/usr/bin/env ruby

# program   : xmltools
# copyright : PRAGMA Advanced Document Engineering
# version   : 1.0 - 2002/2004
# author    : Hans Hagen

# This script will harbor some handy manipulations on tex
# related files.

banner = ['XMLTools', 'version 1.1', '2002/2004', 'PRAGMA ADE/POD']

unless defined? ownpath
    ownpath = $0.sub(/[\\\/][a-z0-9\-]*?\.rb/i,'')
    $: << ownpath
end

require 'xmpl/switch'
require 'exa/logger'

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
            if system("texmfstart texexec.pl --batch --pdf --once --result=#{long} --use=mmlpag #{style} #{modes} #{file}.xml") then
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
            system("texmfstart texutil --purge")
        else
            report("error in processing file #{file}")
        end

    end

    def analyze

        file   = @commandline.argument('first')
        result = @commandline.option('output')

        if FileTest.file?(file) then
            if data = IO.read(file) then
                report("xml file #{file} loaded")
                elements   = Hash.new
                attributes = Hash.new
                entities   = Hash.new
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
                result = file.gsub(/\..*?$/, '') + '.xlg' if result.empty?
                if f = File.open(result,'w') then
                    report("saving report in #{result}")
                    f.puts "<?xml version='1.0'?>\n"
                    f.puts "<document>\n"
                    if entities.length>0 then
                        f.puts "  <entities>\n"
                        entities.keys.asort.each do |entity|
                            f.puts "    <entity name=#{entity.xstring} n=#{entities[entity].to_s.xstring}/>\n"
                        end
                        f.puts "  </entities>\n"
                    end
                    if elements.length>0 then
                        f.puts "  <elements>\n"
                        elements.keys.sort.each do |element|
                            if attributes.key?(element) then
                                f.puts "    <element name=#{element.xstring} n=#{elements[element].to_s.xstring}>\n"
                                if attributes.key?(element) then
                                    attributes[element].keys.asort.each do |attribute|
                                        f.puts "      <attribute name=#{attribute.xstring}>\n"
                                        attributes[element][attribute].keys.asort.each do |value|
                                            f.puts "        <instance value=#{value.xstring} n=#{attributes[element][attribute][value].to_s.xstring}/>\n"
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
                else
                    report("unable to open file '#{result}'")
                end
            else
                report("unable to load file '#{file}'")
            end
        else
            report("unknown file '#{file}'")
        end
    end

end

logger      = EXA::ExaLogger.new(banner.shift)
commandline = CommandLine.new

commandline.registeraction('dir',     'generate directory listing')
commandline.registeraction('mmlpages','generate graphic from mathml')
commandline.registeraction('analyze', 'report entities and elements')

# commandline.registeraction('dir',     'filename --pattern= --output= [--recurse --stripname --longname --url --root]')
# commandline.registeraction('mmlpages','filename [--eps --jpg --png --style= --mode=]')

commandline.registeraction('ls')

commandline.registeraction('help')
commandline.registeraction('version')

commandline.registerflag('stripname')
commandline.registerflag('longname')
commandline.registerflag('recurse')

commandline.registervalue('pattern')
commandline.registervalue('url')
commandline.registervalue('output')
commandline.registervalue('root')

commandline.registerflag('eps')
commandline.registerflag('png')
commandline.registerflag('jpg')
commandline.registervalue('style')
commandline.registervalue('modes')

commandline.expand

Commands.new(commandline,logger,banner).send(commandline.action || 'help')

#!/usr/bin/env ruby

# program   : ctxtools
# copyright : PRAGMA Advanced Document Engineering
# version   : 1.0 - 2002/2004
# author    : Hans Hagen

# This script will harbor some handy manipulations on context
# related files.

# todo: move scite here

banner = ['CtxTools', 'version 1.0', '2004', 'PRAGMA ADE/POD']

unless defined? ownpath
    ownpath = $0.sub(/[\\\/][a-z0-9\-]*?\.rb/i,'')
    $: << ownpath
end

require 'ftools'
require 'xmpl/switch'
require 'exa/logger'

class String

    def i_translate(element, attribute, category)
        self.gsub!(/(<#{element}.*?#{attribute}=)([\"\'])(.*?)\2/) do
            if category.key?($3) then
                "#{$1}#{$2}#{category[$3]}#{$2}"
            else
                "#{$1}#{$2}#{$3}#{$2}" # unchanged
            end
        end
    end

    def i_load(element, category)
        self.scan(/<#{element}.*?name=([\"\'])(.*?)\1.*?value=\1(.*?)\1/) do
            category[$2] = $3
        end
    end

end

class Commands

    include CommandBase

    def touchcontextfile
        maincontextfile = 'context.tex'
        unless FileTest.file?(maincontextfile) then
            begin
                maincontextfile = `kpsewhich -progname=context #{maincontextfile}`.chomp
            rescue
                maincontextfile = ''
            end
        end
        touchfile(maincontextfile) unless maincontextfile.empty?
    end

    private

    def touchfile(filename)

        if FileTest.file?(filename) then
            if data = IO.read(filename) then
                timestamp = Time.now.strftime('%Y.%m.%d')
                prevstamp = ''
                begin
                    data.gsub!(/\\contextversion\{(\d+\.\d+\.\d+)\}/) do
                        prevstamp = $1
                        "\\contextversion{#{timestamp}}"
                    end
                rescue
                else
                    begin
                        File.delete(filename+'.old')
                    rescue
                    end
                    begin
                        File.copy(filename,filename+'.old')
                    rescue
                    end
                    begin
                        if f = File.open(filename,'w') then
                            f.puts(data)
                            f.close
                        end
                    rescue
                    end
                end
                if prevstamp.empty? then
                    report("#{filename} is not updated, no timestamp found")
                else
                    report("#{filename} is updated from #{prevstamp} to #{timestamp}")
                end
            end
        else
            report("#{filename} is not found")
        end

    end

    def jeditinterface

        return unless FileTest.file?("cont-en.xml")

        interfaces = @commandline.arguments

        if interfaces.empty? then
            interfaces = ['en', 'cz','de','it','nl','ro']
        end

        interfaces.each do |interface|
            begin
                collection = Hash.new
                mappings   = Hash.new
                if f = open("keys-#{interface}.xml") then
                    while str = f.gets do
                        if str =~ /\<cd\:command\s+name=\"(.*?)\"\s+value=\"(.*?)\".*?\>/o then
                            mappings[$1] = $2
                        end
                    end
                    f.close
                    if f = open("cont-en.xml") then
                        while str = f.gets do
                            if str =~ /\<cd\:command\s+name=\"(.*?)\"\s+type=\"environment\".*?\>/o then
                                collection["start#{mappings[$1]}"] = ''
                                collection["stop#{mappings[$1]}"]  = ''
                            elsif str =~ /\<cd\:command\s+name=\"(.*?)\".*?\>/o then
                                collection["#{mappings[$1]}"] = ''
                            end
                        end
                        f.close
                        if f = open("context-jedit-#{interface}.xml", 'w') then
                            f.puts("<?xml version='1.0'?>\n\n")
                            f.puts("<!DOCTYPE MODE SYSTEM 'xmode.dtd'>\n\n")
                            f.puts("<MODE>\n")
                            f.puts("  <RULES>\n")
                            f.puts("    <KEYWORDS>\n")
                            collection.keys.sort.each do |name|
                                f.puts("      <KEYWORD2>\\#{name}</KEYWORD2>\n") unless name.empty?
                            end
                            f.puts("    </KEYWORDS>\n")
                            f.puts("  </RULES>\n")
                            f.puts("</MODE>\n")
                            f.close
                        end
                    end
                end
            end
        end

    end

    def translateinterface

        # since we know what kind of file we're dealing with,
        # we do it quick and dirty instead of using rexml or
        # xslt

        interfaces = @commandline.arguments

        if interfaces.empty? then
            interfaces = ['cz','de','it','nl','ro']
        else
            interfaces.delete('en')
        end

        interfaces.flatten.each do |interface|

            variables, constants, strings, list, data = Hash.new, Hash.new, Hash.new, '', ''

            keyfile, intfile, outfile = "keys-#{interface}.xml", "cont-en.xml", "cont-#{interface}.xml"

            report("generating #{keyfile}")

            begin
                one = "texexec --make --alone --all #{interface}"
                two = "texexec --batch --silent --interface=#{interface} x-set-01"
                if @commandline.option("force") then
                    system(one)
                    system(two)
                elsif not system(two) then
                    system(one)
                    system(two)
                end
            rescue
            end

                unless File.file?(keyfile) then
                report("no #{keyfile} generated")
                next
            end

            report("loading #{keyfile}")

            begin
                list = IO.read(keyfile)
            rescue
                list = empty
            end

            if list.empty? then
                report("error in loading #{keyfile}")
                next
            end

            list.i_load('cd:variable', variables)
            list.i_load('cd:constant', constants)
            # list.i_load('cd:command' , strings)
            list.i_load('cd:element' , strings)

            report("loading #{intfile}")

            begin
                data = IO.read(intfile)
            rescue
                data = empty
            end

            if data.empty? then
                report("error in loading #{intfile}")
                next
            end

            report("translating interface en to #{interface}")

            data.i_translate('cd:string'   , 'value', strings)
            data.i_translate('cd:variable' , 'value', variables)
            data.i_translate('cd:parameter', 'name' , constants)
            data.i_translate('cd:constant' , 'type' , variables)
            data.i_translate('cd:variable' , 'type' , variables)
            data.i_translate('cd:inherit'  , 'name' , strings)
            data.i_translate('cd:command'  , 'name' , strings)

            report("saving #{outfile}")

            begin
                if f = File.open(outfile, 'w') then
                    f.write(data)
                    f.close
                end
            rescue
            end

        end

    end

end

logger      = EXA::ExaLogger.new(banner.shift)
commandline = CommandLine.new

commandline.registeraction('touchcontextfile', '')
commandline.registeraction('translateinterface', '')
commandline.registeraction('jeditinterface', '')

commandline.registeraction('help')
commandline.registeraction('version')

commandline.registerflag('recurse')
commandline.registerflag('force')

commandline.expand

Commands.new(commandline,logger,banner).send(commandline.action || 'help')

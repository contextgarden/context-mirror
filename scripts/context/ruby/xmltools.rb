#!/usr/bin/env ruby

# program   : xmltools
# copyright : PRAGMA Advanced Document Engineering
# version   : 1.0 - 2002/2004
# author    : Hans Hagen

# This script will harbor some handy manipulations on tex
# related files.

banner = ['XMLTools', 'version 1.0', '2002/2004', 'PRAGMA ADE/POD']

unless defined? ownpath
    ownpath = $0.sub(/[\\\/]\w*?\.rb/i,'')
    $: << ownpath
end

require 'xmpl/switch'
require 'exa/logger'

class Commands

    include CommandBase

    def dir

        pattern    = @commandline.option('pattern')
        recurse    = @commandline.option('recurse')
        stripname  = @commandline.option('stripname')
        url        = @commandline.option('url')
        outputfile = @commandline.option('output')
        root       = @commandline.option('root')

        def generate(output,files,url,root)

            class << output
                def xputs(str,n=0)
                    puts("#{' '*n} #{str}")
                end
            end

            dirname = ''
            output.xputs("<?xml xmlns='http://www.pragma-ade.com/rlg/xmldir.rng'?>\n\n")
            if ! root || root.empty? then
                rootatt = ''
            else
                rootatt = " root='#{root}'"
            end
            if url.empty? then
                output.xputs("<files#{rootatt}>\n")
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
                output.xputs("<file name='#{bn}'>\n", 4)
                output.xputs("<base>#{bn.sub(/\..*$/,'')}</base>\n", 6)
                output.xputs("<type>#{bn.sub(/^.*\./,'')}</type>\n", 6)
                output.xputs("<size>#{File.stat(f).size}</size>\n", 6)
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

        generate(output, globbed(pattern, recurse), url, root)

        output.close if output

    end

    alias ls :dir

end

logger      = EXA::ExaLogger.new(banner.shift)
commandline = CommandLine.new

commandline.registeraction('dir','generate directory listing')
commandline.registeraction('ls')

commandline.registeraction('help')
commandline.registeraction('version')

commandline.registerflag('stripname')
commandline.registerflag('recurse')

commandline.registervalue('pattern')
commandline.registervalue('url')
commandline.registervalue('output')
commandline.registervalue('root')

commandline.expand

Commands.new(commandline,logger,banner).send(commandline.action || 'help')
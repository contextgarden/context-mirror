#!/usr/bin/env ruby

# program   : ctxtools
# copyright : PRAGMA Advanced Document Engineering
# version   : 1.0 - 2002/2004
# author    : Hans Hagen

# This script will harbor some handy manipulations on context
# related files.

banner = ['CtxTools', 'version 1.0', '2004', 'PRAGMA ADE/POD']

unless defined? ownpath
    ownpath = $0.sub(/[\\\/][a-z0-9\-]*?\.rb/i,'')
    $: << ownpath
end

require 'ftools'
require 'xmpl/switch'
require 'exa/logger'

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

end

logger      = EXA::ExaLogger.new(banner.shift)
commandline = CommandLine.new

commandline.registeraction('touchcontextfile', '')

commandline.registeraction('help')
commandline.registeraction('version')

commandline.registerflag('recurse')
commandline.registerflag('force')

commandline.expand

Commands.new(commandline,logger,banner).send(commandline.action || 'help')

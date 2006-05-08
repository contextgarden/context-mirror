#!/usr/bin/env ruby

# program   : newimgtopdf
# copyright : PRAGMA Advanced Document Engineering
# version   : 2002-2006
# author    : Hans Hagen
#
# project   : ConTeXt / eXaMpLe
# concept   : Hans Hagen
# info      : j.hagen@xs4all.nl
# www       : www.pragma-ade.com

unless defined? ownpath
  ownpath = $0.sub(/[\\\/]\w*?\.rb/i,'')
  $: << ownpath
end

require 'base/switch'
require 'base/logger'

require 'graphics/magick'

banner = ['ImgToPdf', 'version 1.1.2', '2002-2006', 'PRAGMA ADE/POD']

class Commands

    include CommandBase

    # nowadays we would force a directive, but
    # for old times sake we handle default usage

    def main
        filename = @commandline.argument('first')

        if filename.empty? then
            help
        else
            convert
        end
    end

    # actions

    def convert

        magick = Magick.new(session)

        ['compression','depth','colorspace','quality','inputpath','outputpath'].each do |v|
            magick.setvariable(v,@commandline.option(v))
        end

        @commandline.arguments.each do |fullname|
            magick.setvariable('inputfile',fullname)
            magick.setvariable('outputfile',fullname.gsub(/(\..*?$)/io, '.pdf'))
            if @commandline.option('auto') then
                magick.autoconvert
            else
                magick.convert
            end
        end
    end

end

logger      = Logger.new(banner.shift)
commandline = CommandLine.new

commandline.registerflag('auto')

commandline.registervalue('compression')
commandline.registervalue('depth')
commandline.registervalue('colorspace')
commandline.registervalue('quality')

commandline.registervalue('inputpath')
commandline.registervalue('outputpath')


commandline.registeraction('help')
commandline.registeraction('version')

commandline.registeraction('convert', 'convert image into pdf')

commandline.expand

Commands.new(commandline,logger,banner).send(commandline.action || 'main')

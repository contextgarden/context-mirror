#!/usr/bin/env ruby

# program   : texsync
# copyright : PRAGMA Advanced Document Engineering
# version   : 2003-2005
# author    : Hans Hagen
#
# project   : ConTeXt / eXaMpLe
# concept   : Hans Hagen
# info      : j.hagen@xs4all.nl
# www       : www.pragma-ade.com

# For the moment this script only handles the 'minimal' context
# distribution. In due time I will add a few more options, like
# synchronization of the iso image.

banner = ['TeXSync', 'version 1.1.1', '2002/2004', 'PRAGMA ADE/POD']

$: << File.expand_path(File.dirname($0)) ; $: << File.join($:.last,'lib') ; $:.uniq!

require 'base/switch'
require 'base/logger'
# require 'base/tool'

require 'rbconfig'

class Commands

    include CommandBase

    @@formats = ['en','nl','de','cz','it','ro']
    @@always  = ['metafun','mptopdf','en','nl']
    @@rsync   = 'rsync -r -z -c --progress --stats  "--exclude=*.fmt" "--exclude=*.efmt" "--exclude=*.mem"'

    @@kpsewhich  = Hash.new

    @@kpsewhich['minimal']       = 'SELFAUTOPARENT'
    @@kpsewhich['context']       = 'TEXMFLOCAL'
    @@kpsewhich['documentation'] = 'TEXMFLOCAL'
    @@kpsewhich['unknown']       = 'SELFAUTOPARENT'

    def update

        report

        return unless destination = getdestination

        texpaths = gettexpaths
        address  = option('address')
        user     = option('user')
        tree     = option('tree')
        force    = option('force')

        ok = true
        begin
            report("synchronizing '#{tree}' from '#{address}' to '#{destination}'")
            report
            if texpaths then
                texpaths.each do |path|
                    report("synchronizing path '#{path}' of '#{tree}' from '#{address}' to '#{destination}'")
                    command = "#{rsync} #{user}@#{address}::#{tree}/#{path} #{destination}/{path}"
                    ok = ok && system(command) if force
                end
            else
                command = "#{@@rsync} #{user}@#{address}::#{tree} #{destination}"
                ok = system(command) if force
            end
        rescue
            report("error in running rsync")
            ok = false
        ensure
            if force then
                if ok then
                    if option('make') then
                        report("generating tex and metapost formats")
                        report
                        @@formats.delete_if do |f|
                            begin
                                `kpsewhich cont-#{f}`.chomp.empty?
                            rescue
                            end
                        end
                        str = [@@formats,@@always].flatten.uniq.join(' ')
                        begin
                            system("texexec --make --alone #{str}")
                        rescue
                            report("unable to generate formats '#{str}'")
                        else
                            report
                        end
                    else
                        report("regenerate the formats files if needed")
                    end
                else
                    report("error in synchronizing '#{tree}'")
                end
            else
                report("provide --force to execute '#{command}'") unless force
            end
        end

    end

    def list

        report

        address = option('address')
        user    = option('user')
        result  = nil

        begin
            report("fetching list of trees from '#{address}'")
            command = "#{@@rsync} #{user}@#{address}::"
            if option('force') then
                result = `#{command}`.chomp
            else
                report("provide --force to execute '#{command}'")
            end
        rescue
            result = nil
        else
            if result then
                report("available trees:")
                report
                reportlines(result)
            end
        ensure
            report("unable to fetch list") unless result
        end

    end

    private

    def gettexpaths
        if option('full') then
            texpaths = ['texmf','texmf-local','texmf-fonts','texmf-mswin','texmf-linux','texmf-macos']
        elsif option('terse') then
            texpaths = ['texmf','texmf-local','texmf-fonts']
            case Config::CONFIG['host_os'] # or: Tool.ruby_platform
                when /mswin/  then texpaths.push('texmf-mswin')
                when /linux/  then texpaths.push('texmf-linux')
                when /darwin/ then texpaths.push('texmf-macosx')
            end
        else
            texpaths = nil
        end
        texpaths
    end

    def getdestination
       if (destination = option('destination')) && ! destination.empty? then
            begin
                if @@kpsewhich.key?(destination) then
                    destination = @@kpsewhich[option('tree')] || @@kpsewhich['unknown']
                    destination = `kpsewhich --expand-var=$#{destination}`.chomp
                elsif ! FileTest.directory?(destination) then
                    destination = nil
                end
            rescue
                report("unable to determine destination tex root")
            else
                if ! destination || destination.empty? then
                    report("no destination is specified")
                elsif not FileTest.directory?(destination) then
                    report("invalid destination '#{destination}'")
                elsif not FileTest.writable?(destination) then
                    report("destination '#{destination}' is not writable")
                else
                    report("using destination '#{destination}'")
                    return destination
                end
            end
       else
           report("unknown destination")
       end
        return nil
    end

end

logger      = Logger.new(banner.shift)
commandline = CommandLine.new

commandline.registeraction('update', 'update installed tree')
commandline.registeraction('list', 'list available trees')

commandline.registerflag('terse', 'download as less as possible (esp binaries)')
commandline.registerflag('full', 'download everything (all binaries)')
commandline.registerflag('force', 'confirm action')
commandline.registerflag('make', 'remake formats')

commandline.registervalue('address', 'www.pragma-ade.com', 'adress of repository (www.pragma-ade)')
commandline.registervalue('user', 'guest', 'user account (guest)')
commandline.registervalue('tree', 'tex', 'tree to synchronize (tex)')
commandline.registervalue('destination', nil, 'destination of tree (kpsewhich)')

commandline.registeraction('help')
commandline.registeraction('version')

commandline.expand

Commands.new(commandline,logger,banner).send(commandline.action || 'help')

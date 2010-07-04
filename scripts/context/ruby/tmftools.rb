#!/usr/bin/env ruby

# program   : tmftools
# copyright : PRAGMA Advanced Document Engineering
# version   : 2005
# author    : Hans Hagen
#
# project   : ConTeXt
# concept   : Hans Hagen
# info      : j.hagen@xs4all.nl
# www       : www.pragma-ade.com

# The script based alternative is not slower than the kpse one.
# Loading is a bit faster when the log file is used.

# todo: create database

# tmftools [some of the kpsewhich switches]

# tmftools --analyze
# tmftools --analyze > kpsewhat.log
# tmftools --analyze --strict > kpsewhat.log
# tmftools --analyze --delete --force "texmf-local/fonts/.*/somename"
# tmftools --serve

# the real thing

banner = ['TMFTools', 'version 1.1.0 (experimental, no help yet)', '2005/2006', 'PRAGMA ADE/POD']

$: << File.expand_path(File.dirname($0)) ; $: << File.join($:.last,'lib') ; $:.uniq!

require 'base/switch'
require 'base/logger'

class Commands

    include CommandBase

    def init_kpse
        # require 'base/kpseremote'
        # if KpseRemote::available? then
        if ENV['KPSEMETHOD'] && ENV['KPSEPORT'] then
            require 'base/kpseremote'
            k = KpseRemote.new
        else
            k = nil
        end
        if k && k.okay? then
            k.progname = @commandline.option('progname')
            k.engine   = @commandline.option('engine')
            k.format   = @commandline.option('format')
        else
            require 'base/kpsefast'
            k = KpseFast.new
            k.rootpath   = @commandline.option('rootpath')
            k.treepath   = @commandline.option('treepath')
            k.progname   = @commandline.option('progname')
            k.engine     = @commandline.option('engine')
            k.format     = @commandline.option('format')
            k.diskcache  = @commandline.option('diskcache')
            k.renewcache = @commandline.option('renewcache')
            k.load_cnf
            k.expand_variables
            k.load_lsr
        end
        return k
    end

    def serve
        if ENV['KPSEMETHOD'] && ENV['KPSEPORT'] then
            require 'base/kpseremote'
            begin
                KpseRemote::start_server
            rescue
            end
        end
    end

    def reload
        begin
            init_kpse.load
        rescue
        end
    end

    def main
        if    option = @commandline.option('expand-braces') and not option.empty? then
            puts init_kpse.expand_braces(option)
        elsif option = @commandline.option('expand-path')   and not option.empty? then
            puts init_kpse.expand_path(option)
        elsif option = @commandline.option('expand-var')    and not option.empty? then
            if option == '*' then
                init_kpse.list_expansions()
            else
                puts init_kpse.expand_var(option)
            end
        elsif option = @commandline.option('show-path')     and not option.empty? then
            puts init_kpse.show_path(option)
        elsif option = @commandline.option('var-value')     and not option.empty? then
            if option == '*' then
                init_kpse.list_variables()
            else
                puts init_kpse.expand_var(option)
            end
        elsif @commandline.arguments.size > 0 then
            kpse = init_kpse
            @commandline.arguments.each do |option|
                puts kpse.find_file(option)
            end
        else
            help
        end
    end

    def analyze
        pattern = @commandline.argument('first')
        strict  = @commandline.option('strict')
        sort    = @commandline.option('sort')
        delete  = @commandline.option('delete') and @commandline.option('force')
        init_kpse.analyze_files(pattern, strict, sort, delete)
    end

end

logger      = Logger.new(banner.shift)
commandline = CommandLine.new

# kpsewhich compatible options

commandline.registervalue('expand-braces','')
commandline.registervalue('expand-path','')
commandline.registervalue('expand-var','')
commandline.registervalue('show-path','')
commandline.registervalue('var-value','')

commandline.registervalue('engine','')
commandline.registervalue('progname','')
commandline.registervalue('format','')

# additional goodies

commandline.registervalue('rootpath','')
commandline.registervalue('treepath','')
commandline.registervalue('sort','')

commandline.registerflag('diskcache')
commandline.registerflag('renewcache')
commandline.registerflag('strict')
commandline.registerflag('delete')
commandline.registerflag('force')

commandline.registeraction('analyze', "[--strict --sort --rootpath --treepath]\n[--delete [--force]] [pattern]")

# general purpose options

commandline.registerflag('verbose')
commandline.registeraction('help')
commandline.registeraction('version')

commandline.registeraction('reload', 'reload file database')
commandline.registeraction('serve', 'act as kpse server')

commandline.expand

Commands.new(commandline,logger,banner).send(commandline.action || 'main')

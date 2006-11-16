banner = ['TeXUtil  ', 'version 9.1.0', '1997-2005', 'PRAGMA ADE/POD']

$: << File.expand_path(File.dirname($0)) ; $: << File.join($:.last,'lib') ; $:.uniq!

require 'base/switch'
require 'base/logger'
require 'base/file'
require 'base/texutil'

class Commands

    include CommandBase

    def references
        filename = @commandline.argument('first')
        if not filename.empty? and FileTest.file?(File.suffixed(filename,'tuo')) then
            if tu = TeXUtil::Converter.new(logger) and tu.loaded(filename) then
                tu.saved if tu.processed
            end
        end
    end

    def main
        if @commandline.arguments.length>0 then
            references
        else
            help
        end
    end

    def purgefiles
        system("texmfstart ctxtools --purge #{@commandline.arguments.join(' ')}")
    end

    def purgeallfiles
        system("texmfstart ctxtools --purge --all #{@commandline.arguments.join(' ')}")
    end

    def documentation
        system("texmfstart ctxtools --document #{@commandline.arguments.join(' ')}")
    end

    def analyzefile
        system("texmfstart pdftools --analyze #{@commandline.arguments.join(' ')}")
    end

    def filterpages # obsolete
        system("texmfstart ctxtools --purge #{@commandline.arguments.join(' ')}")
    end

    def figures
        report("this code is not yet converted from perl to ruby")
    end

    def logfile
        report("this code is not yet converted from perl to ruby")
    end

end

logger      = Logger.new(banner.shift)
commandline = CommandLine.new

# main feature

commandline.registeraction('references', 'convert tui file into tuo file')

# todo features

commandline.registeraction('figures', 'generate figure dimensions file')
commandline.registeraction('logfile', 'filter essential log messages')

# backward compatibility features

commandline.registeraction('purgefiles', 'remove most temporary files')
commandline.registeraction('purgeallfiles', 'remove all temporary files')
commandline.registeraction('documentation', 'generate documentation file from source')
commandline.registeraction('analyzefile', 'analyze pdf file')

# old feature, not needed any longer due to extension of pdftex

commandline.registeraction('filterpages')

# generic features

commandline.registeraction('help')
commandline.registeraction('version')

commandline.registerflag('verbose')

commandline.expand

Commands.new(commandline,logger,banner).send(commandline.action || 'main')

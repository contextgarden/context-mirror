#!/usr/bin/env ruby

# program   : pstopdf
# copyright : PRAGMA Advanced Document Engineering
# version   : 2002-2005
# author    : Hans Hagen
#
# project   : ConTeXt / eXaMpLe
# concept   : Hans Hagen
# info      : j.hagen@xs4all.nl
# www       : www.pragma-ade.com

banner = ['PsToPdf', 'version 2.0.1', '2002-2006', 'PRAGMA ADE/POD']

$: << File.expand_path(File.dirname($0)) ; $: << File.join($:.last,'lib') ; $:.uniq!

# todo: paden/prefix in magick and inkscape
# todo: clean up method handling (pass strings, no numbers)
# --method=crop|bounded|raw|...
# --resolution=low|normal|medium|high|printer|print|screen|ebook|default
# + downward compatible flag handling

require 'base/switch'
require 'base/tool'
require 'base/logger'

require 'graphics/gs'
require 'graphics/magick'
require 'graphics/inkscape'

require 'rexml/document'

exit if defined?(REQUIRE2LIB)

class Commands

    include CommandBase

    # nowadays we would force a directive, but
    # for old times sake we handle default usage

    def main
        filename = @commandline.argument('first')
        pattern  = @commandline.option('pattern')
        if filename.empty? && ! pattern.empty? then
            pattern = "**/#{pattern}" if @commandline.option('recurse')
            globfiles(pattern)
        end
        filename = @commandline.argument('first')
        if filename.empty? then
            help
        elsif filename =~ /\.exa$/ then
            request
        else
            convert
        end
    end

    # actions

    def convert

        ghostscript = GhostScript.new(logger)
        magick      = ImageMagick.new(logger)
        inkscape    = InkScape.new(logger)

        outpath = @commandline.option('outputpath')
        unless outpath.empty? then
            begin
                File.expand_path(outpath)
                outpath = File.makedirs(outpath) unless FileTest.directory?(outpath)
            rescue
                # sorry
            end
        end

        @commandline.arguments.each do |filename|

            filename = Tool.cleanfilename(filename,@commandline) # brrrr
            inppath = @commandline.option('inputpath')
            if inppath.empty? then
               inppath = '.'
               fullname = filename # avoid duplicate './'
            else
               fullname = File.join(inppath,filename)
            end
            if FileTest.file?(fullname) then
                handle_whatever(ghostscript,inkscape,magick,filename)
            else
                report("file #{fullname} does not exist")
            end

        end

    end

    def request

        # <exa:request>
        #   <exa:application>
        #     <exa:command>pstopdf</exa:command>
        #     <exa:filename>E:/tmp/demo.ps</exa:filename>
        #   </exa:application>
        #   <exa:data>
        #     <exa:variable label='gs:DoThumbnails'>false</exa:variable>
        #     <exa:variable label='gs:ColorImageDepth'>-1</exa:variable>
        #   </exa:data>
        # </exa:request>

        ghostscript = GhostScript.new(logger)
        magick      = ImageMagick.new(logger)
        inkscape    = InkScape.new(logger)

        dataname = @commandline.argument('first')  || ''
        filename = @commandline.argument('second') || ''

        if dataname.empty? || ! FileTest.file?(dataname) then
            report('provide valid exa file')
            return
        else
            begin
                request = REXML::Document.new(File.new(dataname))
            rescue
                report('provide valid exa file (xml error)')
                return
            end
        end
        if filename.empty? then
            begin
                if filename = REXML::XPath.first(request.root,"exa:request/exa:application/exa:filename/text()") then
                    filename = filename.to_s
                else
                    report('no filename found in exa file')
                    return
                end
            rescue
                filename = ''
            end
        end
        if filename.empty? then
            report('provide valid filename')
            return
        elsif ! FileTest.file?(filename) then
            report("invalid filename #{filename}")
            return
        end

        [ghostscript,inkscape,magick].each do |i|
            i.setvariable('inputfile',filename)
        end

        # set ghostscript variables
        REXML::XPath.each(request.root,"/exa:request/exa:data/exa:variable") do |v|
            begin
                if (key = v.attributes['label']) and (value = v.text.to_s) then
                    case key
                        when /gs[\:\.](var[\:\.])*(offset)/io then ghostscript.setoffset(value)
                        when /gs[\:\.](var[\:\.])*(method)/io then ghostscript.setvariable('method',value)
                        when /gs[\:\.](var[\:\.])*(.*)/io     then ghostscript.setpsoption($2,value)
                    end
                end
            rescue
            end
        end

        # no inkscape and magick variables (yet)

        handle_whatever(ghostscript,inkscape,magick,filename)

    end

    def watch

        ghostscript = GhostScript.new(logger)
        magick      = ImageMagick.new(logger)
        inkscape    = InkScape.new(logger)

        pathname = commandline.option('watch')

        unless pathname and not pathname.empty? then
            report('empty watchpath is not supported')
            exit
        end

        if pathname == '.' then
            report("watchpath #{pathname} is not supported")
            exit
        end

        if FileTest.directory?(pathname) then
            if Dir.chdir(pathname) then
                report("watching path #{pathname}")
            else
                report("unable to change to path #{pathname}")
                exit
            end
        else
            report("invalid path #{pathname}")
            exit
        end

        waiting = false

        loop do

            if waiting then
                report("waiting #{getvariable('delay')}")
                waiting = false
                sleep(getvariable('delay').to_i)
            end

            files = Dir.glob("**/*.*")

            if files and files.length > 0 then

                files.each do |fullname|

                    next unless fullname

                    if FileTest.directory?(fullname) then
                        debug('skipping path', fullname)
                        next
                    end

                    unless magick.supported(fullname) then
                        debug('not supported', fullname)
                        next
                    end

                    if (! FileTest.file?(fullname)) || (FileTest.size(fullname) < 100) then
                        debug("skipping small crap file #{fullname}")
                        next
                    end

                    debug("handling file #{fullname}")

                    begin
                        next unless File.rename(fullname,fullname) # access trick
                    rescue
                        next                                       # being written
                    end

                    fullname = Tool.cleanfilename(fullname,@commandline)

                    fullname.gsub!(/\\/io, '/')

                    filename = File.basename(fullname)
                    filepath = File.dirname(fullname)

                    next if filename =~ /gstemp.*/io

                    if filepath !~ /(result|done|raw|crop|bound|bitmap)/io then
                        begin
                            File.makedirs(filepath+'/raw')
                            File.makedirs(filepath+'/bound')
                            File.makedirs(filepath+'/crop')
                            File.makedirs(filepath+'/bitmap')
                            debug("creating prefered input paths on #{filepath}")
                        rescue
                            debug("creating input paths on #{filepath} failed")
                        end
                    end

                    if filepath =~ /^(.*\/|)(done|result)$/io then
                        debug("skipping file #{fullname}")
                    else
                        report("start processing file #{fullname}")
                        if filepath =~ /^(.*\/*)(raw|crop|bound)$/io then
                            donepath = $1 + 'done'
                            resultpath = $1 + 'result'
                            case $2
                                when 'raw'   then method = 1
                                when 'bound' then method = 2
                                when 'crop'  then method = 3
                                else              method = 2
                            end
                            report("forcing method #{method}")
                        else
                            method = 2
                            donepath = filepath + '/done'
                            resultpath = filepath + '/result'
                            report("default method #{method}")
                        end

                        begin
                            File.makedirs(donepath)
                            File.makedirs(resultpath)
                        rescue
                            report('result path creation fails')
                        end

                        if FileTest.directory?(donepath) && FileTest.directory?(resultpath) then

                            resultname = resultpath + '/' + filename.sub(/\.[^\.]*$/,'') + '.pdf'

                            @commandline.setoption('inputpath',  filepath)
                            @commandline.setoption('outputpath', resultpath)
                            @commandline.setoption('method',     method)

                            if ghostscript.psfile?(fullname) then
                                handle_ghostscript(ghostscript,filename)
                            else
                                handle_magick(magick,filename)
                            end

                            sleep(1) # calm down

                            if FileTest.file?(fullname) then
                                begin
                                    File.copy(fullname,donepath + '/' + filename)
                                    File.delete(fullname)
                                rescue
                                    report('cleanup fails')
                                end
                            end

                        end

                    end

                end

            end

            waiting = true
        end

    end

    private

    def handle_whatever(ghostscript,inkscape,magick,filename)
        if ghostscript.psfile?(filename) then
            # report("processing ps file #{filename}")
            ghostscript.setvariable('pipe',false) if @commandline.option('nopipe')
            # ghostscript.setvariable('pipe',not @commandline.option('nopipe'))
            ghostscript.setvariable('colormodel',@commandline.option('colormodel'))
            ghostscript.setvariable('offset',@commandline.option('offset'))
            handle_ghostscript(ghostscript,filename)
        elsif ghostscript.pdffile?(filename) && ghostscript.pdfmethod?(@commandline.option('method')) then
            # report("processing pdf file #{filename}")
            handle_ghostscript(ghostscript,filename)
        elsif inkscape.supported?(filename) then
            # report("processing non ps/pdf file #{filename}")
            handle_inkscape(inkscape,filename)
        elsif magick.supported?(filename) then
            # report("processing non ps/pdf file #{filename}")
            handle_magick(magick,filename)
        else
            report("option not supported for #{filename}")
        end
    end

    def handle_magick(magick,filename)

        report("converting non-ps file #{filename} into pdf")

        inppath = @commandline.option('inputpath')
        outpath = @commandline.option('outputpath')

        inppath = inppath + '/' if not inppath.empty?
        outpath = outpath + '/' if not outpath.empty?

        prefix = @commandline.option('prefix')
        suffix = @commandline.option('suffix')

        inpfilename = "#{inppath}#{filename}"
        outfilename = "#{outpath}#{prefix}#{filename.sub(/\.([^\.]*?)$/, '')}#{suffix}.pdf"

        magick.setvariable('inputfile' , inpfilename)
        magick.setvariable('outputfile', outfilename)

        magick.autoconvert

    end

    def handle_inkscape(inkscape,filename)

        report("converting svg(z) file #{filename} into pdf")

        inppath = @commandline.option('inputpath')
        outpath = @commandline.option('outputpath')

        inppath = inppath + '/' if not inppath.empty?
        outpath = outpath + '/' if not outpath.empty?

        prefix = @commandline.option('prefix')
        suffix = @commandline.option('suffix')

        inpfilename = "#{inppath}#{filename}"
        outfilename = "#{outpath}#{prefix}#{filename.sub(/\.([^\.]*?)$/, '')}#{suffix}.pdf"

        inkscape.setvariable('inputfile' , inpfilename)
        inkscape.setvariable('outputfile', outfilename)

        if @commandline.option('verbose') || @commandline.option('debug') then
            logname = filename.gsub(/\.[^\.]*?$/, '.log')
            report("log info saved in #{logname}")
            inkscape.convert(logname) # logname ook doorgeven
        else
            inkscape.convert
        end

    end

    def handle_ghostscript(ghostscript,filename)

        ghostscript.reset

        method = ghostscript.method(@commandline.option('method'))
        force = ghostscript.method(@commandline.option('force'))

        ghostscript.setvariable('method', method)
        ghostscript.setvariable('force', force)

        # report("conversion method #{method}")

        inppath = @commandline.option('inputpath')
        outpath = @commandline.option('outputpath')

        inppath = inppath + '/' if not inppath.empty?
        outpath = outpath + '/' if not outpath.empty?

        prefix = @commandline.option('prefix')
        suffix = @commandline.option('suffix')

        ok = false

        if ghostscript.pdfmethod?(method) then

            report("converting pdf file #{filename} into pdf")

            if prefix.empty? && suffix.empty? && inppath.empty? && outpath.empty? then
                prefix = ghostscript.pdfprefix(method)
            end

            if ghostscript.pdffile?(filename) then

                filename = filename.sub(/\.pdf$/, '')

                inpfilename = "#{inppath}#{filename}.pdf"
                outfilename = "#{outpath}#{prefix}#{filename}#{suffix}.pdf"

                ghostscript.setvariable('inputfile' ,inpfilename)
                ghostscript.setvariable('outputfile',outfilename)

                if FileTest.file?(inpfilename) then
                    ok = ghostscript.convert
                else
                    report("no file found #{filename}")
                end

            else
                report("no pdf file #{filename}")
            end

        elsif ghostscript.psfile?(filename) then

            if filename =~ /(.*)\.([^\.]*?)$/io then
                filename, filesuffix = $1, $2
            else
                filesuffix = 'eps'
            end

            report("converting #{filesuffix} (ps) into pdf")

            inpfilename = "#{inppath}#{filename}.#{filesuffix}"
            outfilename = "#{outpath}#{prefix}#{filename}#{suffix}.pdf"

            ghostscript.setvariable('inputfile' , inpfilename)
            ghostscript.setvariable('outputfile', outfilename)

            if FileTest.file?(inpfilename) then
                ok = ghostscript.convert
                if ! ok && FileTest.file?(outfilename) then
                    begin
                        File.delete(outfilename)
                    rescue
                    end
                end
            else
                report("no file with name #{filename} found")
            end

        else
            report('file must be of type eps/ps/ai/pdf')
        end

        return ok

    end

end

# ook pdf -> pdf onder optie 0, andere kleurruimte

logger      = Logger.new(banner.shift)
commandline = CommandLine.new

commandline.registerflag('debug')
commandline.registerflag('verbose')
commandline.registerflag('nopipe')

commandline.registervalue('method',2)
commandline.registervalue('offset',0)

commandline.registervalue('prefix')
commandline.registervalue('suffix')

commandline.registervalue('inputpath')
commandline.registervalue('outputpath')

commandline.registerflag('watch')
commandline.registerflag('force')
commandline.registerflag('recurse')

commandline.registervalue('delay',2)

commandline.registervalue('colormodel','cmyk')
commandline.registervalue('pattern','')

commandline.registeraction('help')
commandline.registeraction('version')

commandline.registeraction('convert', 'convert ps into pdf')
commandline.registeraction('request', 'handles exa request file')
commandline.registeraction('watch',   'watch folders for conversions (untested)')

commandline.expand

logger.verbose if (commandline.option('verbose') || commandline.option('debug'))

Commands.new(commandline,logger,banner).send(commandline.action || 'main')

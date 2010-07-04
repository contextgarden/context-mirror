#!/usr/bin/env ruby

# program   : pdftools
# copyright : PRAGMA Advanced Document Engineering
# version   : 2003-2005
# author    : Hans Hagen
#
# project   : ConTeXt / eXaMpLe
# concept   : Hans Hagen
# info      : j.hagen@xs4all.nl
# www       : www.pragma-ade.com

# This script will harbor some handy manipulations on tex
# related files.

banner = ['PDFTools', 'version 1.2.1', '2003/2005', 'PRAGMA ADE/POD']

$: << File.expand_path(File.dirname($0)) ; $: << File.join($:.last,'lib') ; $:.uniq!

require 'base/switch'
require 'base/logger'

require 'fileutils'
# require 'ftools'

class File

    def File.deletefiles(*filenames)
        filenames.flatten.each do |filename|
            begin
                delete(filename) if FileTest.file?(filename)
            rescue
            end
        end
    end

    def File.needsupdate(oldname,newname)
        begin
            return File.stat(oldname).mtime != File.stat(newname).mtime
        rescue
            return true
        end
    end

    def File.syncmtimes(oldname,newname)
        begin
            t = Time.now # i'm not sure if the time is frozen, so we do it here
            File.utime(0,t,oldname,newname)
        rescue
        end
    end

    def File.replacesuffix(oldname,subpath='')
        newname = File.expand_path(oldname.sub(/\.\w+?$/,'.pdf'))
        File.join(File.dirname(newname),subpath,File.basename(newname))
    end

end

class ImageMagick

    def initialize

        begin
            version = `convert -version`
        rescue
            @binary = nil
        ensure
            if (version) && (! version.empty?) && (version =~ /ImageMagick/mo) && (version =~ /version/mio) then
                @binary = 'convert'
            else
                @binary = 'imagemagick'
            end
        end

    end

    def process(arguments)
        begin
            @binary && system("#{@binary} #{arguments}")
        rescue
            false
        end
    end

end

class TexExec

    def initialize
        @binary = 'texmfstart texexec.pl --pdf --batch --silent --purge'
    end

    def process(arguments,once=true)
       begin
            if once then
                @binary && system("#{@binary} --once #{arguments}")
            else
                @binary && system("#{@binary} #{arguments}")
            end
       rescue
            false
       end
    end

end

class PdfImages

    def initialize
        @binary = "pdfimages"
    end

    def process(arguments)
       begin
            @binary && system("#{@binary} #{arguments}")
       rescue
            false
       end
    end

end

class ConvertImage

    def initialize(command=nil)
        @command = command
    end

    def convertimage(filename)

        return if filename =~ /\.(pdf)$/io

        retain = @command.option('retain')
        subpath = @command.option('subpath')

        if filename =~ /\s/ then
            @command.report("skipping strange filename '#{filename}'")
        else
            newname = File.replacesuffix(filename,subpath)
            # newname.gsub!(s/[^a-zA-Z0-9\_-\.]/o, '-')
            begin
                File.makedirs(File.dirname(newname))
            rescue
            end
            if ! retain || File.needsupdate(filename,newname) then
                imagemagick = ImageMagick.new
                if imagemagick then
                    ok = imagemagick.process("-compress zip -quality 99 #{filename} #{newname}")
                    File.syncmtimes(oldname,newname) if retain
                end
            end
        end
    end

end

class DownsampleImage

    def initialize(command=nil)
        @command = command
    end

    def convertimage(filename)

        return if filename =~ /\.(pdf)$/io

        retain  = @command.option('retain')
        subpath = @command.option('subpath')

        if @command.option('lowres') then
            method = '4'
        elsif @command.option('medres') || @command.option('normal') then
            method = '5'
        else
            method = '4'
        end

        if filename =~ /\s/ then
            @command.report("skipping strange filename '#{filename}'")
        else
            newname = File.replacesuffix(filename,subpath)
            begin
                File.makedirs(File.dirname(newname))
            rescue
            end
            if ! retain || File.needsupdate(filename,newname) then
                ok = system("texmfstart pstopdf.rb --method=#{method} #{filename} #{newname}")
                File.syncmtimes(oldname,newname) if retain
            end
        end
    end

end

class ColorImage

    def initialize(command=nil,tmpname='pdftools')
        @command    = command
        @tmpname    = tmpname
        @colorname  = nil
        @colorspec  = nil
        @colorspace = nil
    end

    def registercolor(spec='.5',name='c')
        name = name || 'c'
        spec = spec.split(',')
        case spec.length
            when 4
                @colorname, @colorspec, @colorspace = name, spec.join('/'), 'cmyk'
            when 3
                @colorname, @colorspec, @colorspace = name, spec.join('/'), 'rgb'
            when 1
                @colorname, @colorspec, @colorspace = name, spec.join('/'), 'gray'
            else
                @colorname, @colorspec, @colorspace = nil, nil, nil
        end
    end

    def convertimage(filename)

        invert = @command.option('invert')
        retain = @command.option('retain')
        subpath = @command.option('subpath')

        subpath += '/' unless subpath.empty?

        if @colorname && ! @colorname.empty? && @colorspec && ! @colorspec.empty? then
            basename = filename.sub(/\.\w+?$/,'')
            oldname = filename
            ppmname = @tmpname + '-000.ppm'
            jpgname = @tmpname + '-000.jpg'
            newname = File.expand_path(oldname)
            newname = File.dirname(newname) + '/' + subpath + @colorname + '-' + File.basename(newname)
            newname.sub!(/\.\w+?$/, '.pdf')
            begin
                File.makedirs(File.dirname(newname))
            rescue
            end
            if ! retain || File.needsupdate(filename,newname) then
                pdfimages = PdfImages.new
                imagemagick = ImageMagick.new
                if pdfimages && imagemagick then
                    File.deletefiles(ppmname,jpgname,newname)
                    if filename =~ /\.(pdf)$/io then
                        ok = pdfimages.process("-j -f 1 -l 1 #{filename} #{@tmpname}")
                        if ok then
                            if FileTest.file?(ppmname) then
                                inpname = ppmname
                            elsif FileTest.file?(jpgname) then
                                inpname = jpgname
                            else
                                ok = false
                            end
                            if ok then
                                switch = if ! invert then '-negate' else '' end
                                # make sure that we keep the format
                                tmpname = File.basename(inpname)
                                tmpname = tmpname.sub(/(.*)\..*?$/,@tmpname) # somehow sub! fails here
                                ok = imagemagick.process("-colorspace gray #{switch} #{inpname} #{tmpname}")
                                if ! ok || ! FileTest.file?(tmpname) then
                                    # problems
                                else
                                    ok = imagemagick.process("-colorspace #{switch} #{@colorspace} -colorize #{@colorspec} -compress zip #{tmpname} #{newname}")
                                    if ! ok || ! FileTest.file?(newname) then
                                        # unable to colorize image
                                    else
                                        # conversion done
                                    end
                                end
                            end
                        end
                    else
                        # make sure that we keep the format
                        tmpname = File.basename(basename)
                        tmpname = tmpname.sub(/(.*)\..*?$/,@tmpname) # somehow sub! fails here
                        ok = imagemagick.process("-colorspace gray #{oldname} #{tmpname}")
                        if ! ok || ! FileTest.file?(tmpname) then
                            # unable to convert color to gray
                        else
                            ok = imagemagick.process("-colorspace #{@colorspace} -colorize #{@colorspec} -compress zip #{tmpname} #{newname}")
                            if ! ok || ! FileTest.file?(newname) then
                                # unable to colorize image
                            else
                                # conversion done
                            end
                        end
                    end
                    File.deletefiles(ppmname,jpgname,tmpname)
                    File.syncmtimes(filename,newname) if retain
                end
            end
        end
    end

end

class SpotColorImage

    def initialize(command=nil, tmpname='pdftools')
        @command    = command
        @tmpname    = tmpname
        @colorname  = nil
        @colorspec  = nil
        @colorspace = nil
        @colorfile  = nil
    end

    def registercolor(spec='.5',name='unknown')
        name = name || 'unknown'
        if spec =~ /^[\d\.\,]+$/ then
            spec = spec.split(',')
            case spec.length
                when 4
                    @colorname, @colorspec, @colorspace = name, ["c=#{spec[0]}","m=#{spec[1]}","y=#{spec[2]}","k=#{spec[3]}"].join(','), 'cmyk'
                when 3
                    @colorname, @colorspec, @colorspace = name, ["r=#{spec[0]}","g=#{spec[1]}","b=#{spec[2]}"].join(','), 'rgb'
                when 1
                    @colorname, @colorspec, @colorspace = name, ["s=#{spec[0]}"].join(','), 'gray'
                else
                    @colorname, @colorspec, @colorspace = nil, nil, nil
            end
        else
            @colorname, @colorfile = name, spec
        end
    end

    def convertgrayimage(filename)

        invert  = @command.option('invert')
        retain  = @command.option('retain')
        subpath = @command.option('subpath')

        subpath += '/' unless subpath.empty?

        if @colorname && ! @colorname.empty? && ((@colorspec && ! @colorspec.empty?) || (@colorfile && ! @colorfile.empty?))  then
            basename = filename.sub(/\.\w+?$/,'')
            oldname  = filename # png jpg pdf
            newname  = File.expand_path(oldname)
            ppmname  = @tmpname + '-000.ppm'
            jpgname  = @tmpname + '-000.jpg'
            outname  = @tmpname + '-000.pdf'
            texname  = @tmpname + '-temp.tex'
            pdfname  = @tmpname + '-temp.pdf'
            newname  = File.dirname(newname) + '/' + subpath + @colorname + '-' + File.basename(newname)
            newname.sub!(/\.\w+?$/, '.pdf')
            begin
                File.makedirs(File.dirname(newname))
            rescue
            end
            if ! retain || File.needsupdate(filename,newname) then
                pdfimages = PdfImages.new
                imagemagick = ImageMagick.new
                texexec  = TexExec.new
                if pdfimages && imagemagick && texexec then
                    if filename =~ /\.(jpg|png|pdf)$/io then
                        @command.report("processing #{basename}")
                        File.deletefiles(ppmname,jpgname,newname)
                        switch = if ! invert then '-negate' else '' end
                        if filename =~ /\.(pdf)$/io then
                            ok = pdfimages.process("-j -f 1 -l 1 #{oldname} #{@tmpname}")
                            if ok then
                                if FileTest.file?(ppmname) then
                                    inpname = ppmname
                                elsif FileTest.file?(jpgname) then
                                    inpname = jpgname
                                else
                                    ok = false
                                end
                                if ok then
                                    ok = imagemagick.process("-colorspace gray #{switch} -compress zip #{inpname} #{outname}")
                                end
                            end
                        else
                            ok = imagemagick.process("-colorspace gray #{switch} -compress zip #{oldname} #{outname}")
                        end
                        if ok then
                            ok = false unless FileTest.file?(outname)
                        end
                        if ok then
                            if f = File.open(texname, 'w') then
                                f.puts(conversionfile(filename,outname,newname))
                                f.close
                                ok = texexec.process(texname)
                            else
                                ok = false
                            end
                            @command.report("error in processing #{newname}") unless ok
                            if FileTest.file?(pdfname) then
                                if f = File.open(pdfname,'r') then
                                    f.binmode
                                    begin
                                        if g = File.open(newname,'w') then
                                            g.binmode
                                            data = f.read
                                            # pdftex (direct) & imagemagick (indirect)
                                            if data =~ /(\d+)\s+0\s+obj\s+\[\/Separation\s+\/#{@colorname}/mos then
                                                @command.report("replacing separation color")
                                                object = $1
                                                data.gsub!(/(\/Type\s+\/XObject.*?)(\/ColorSpace\s*(\/DeviceGray|\/DeviceCMYK|\/DeviceRGB|\d+\s+\d+\s+R))/moi) do
                                                    $1 + "/ColorSpace #{object} 0 R".ljust($2.length)
                                                end
                                            elsif data =~ /(\d+)\s+0\s+obj\s+\[\/Indexed\s*\[/mos then
                                                @command.report("replacing indexed color")
                                                # todo: more precise check on color
                                                object = $1
                                                data.gsub!(/(\/Type\s+\/XObject.*?)(\/ColorSpace\s*(\/DeviceGray|\/DeviceCMYK|\/DeviceRGB|\d+\s+\d+\s+R))/moi) do
                                                    $1 + "/ColorSpace #{object} 0 R".ljust($2.length)
                                                end
                                            elsif data =~ /(\d+)\s+0\s+obj\s+\[\/Separation/mos then
                                                @command.report("replacing separation color")
                                                object = $1
                                                data.gsub!(/(\/Type\s+\/XObject.*?)(\/ColorSpace\s*(\/DeviceGray|\/DeviceCMYK|\/DeviceRGB|\d+\s+\d+\s+R))/moi) do
                                                    $1 + "/ColorSpace #{object} 0 R".ljust($2.length)
                                                end
                                            end
                                            g.write(data)
                                            g.close
                                        end
                                    rescue
                                        @command.report("error in converting #{newname}")
                                    else
                                        @command.report("#{newname} is converted")
                                    end
                                    f.close
                                end
                            else
                                @command.report("error in writing #{newname}")
                            end
                        else
                            @command.report("error in producing #{newname}")
                        end
                        File.deletefiles(ppmname,jpgname,outname)
                        # File.deletefiles(texname,pdfname)
                        File.syncmtimes(filename,newname) if retain
                    end
                else
                    @command.report("error in locating binaries")
                end
            else
                @command.report("#{newname} is not changed")
            end
        end
    end

    private

    # % example colorfile:
    #
    # \definecolor [darkblue]   [c=1,m=.38,y=0,k=.64] % pantone pms 2965 uncoated m
    # \definecolor [darkyellow] [c=0,m=.28,y=1,k=.06] % pantone pms  124 uncoated m
    #
    # % \definecolor [darkblue-100]    [darkblue]   [p=1]
    # % \definecolor [darkyellow-100]  [darkyellow] [p=1]
    #
    # \definecolorcombination [pdftoolscolor] [darkblue=.12,darkyellow=.28] [c=.1,m=.1,y=.3,k=.1]

    def conversionfile(originalname,filename,finalname)
        tex = "\\setupcolors[state=start]\n"
        if @colorfile then
            tex += "\\readfile{#{@colorfile}}{}{}\n"
            tex += "\\starttext\n"
            # tex += "\\predefineindexcolor[pdftoolscolor]\n"
            tex += "\\startTEXpage\n"
            tex += "\\pdfimage{#{filename}}\n"
            tex += "\\stopTEXpage\n"
            tex += "\\stoptext\n"
        else
            tex += "\\definecolor[#{@colorname}][#{@colorspec}]\n"
            tex += "\\definecolor[pdftoolscolor][#{@colorname}][p=1]\n"
            tex += "\\starttext\n"
            tex += "\\startTEXpage\n"
            tex += "\\hbox{\\color[pdftoolscolor]{\\pdfimage{#{filename}}}}\n"
            tex += "\\stopTEXpage\n"
            tex += "\\stoptext\n"
        end
        tex += "\n"
        tex += "% old: #{originalname}\n"
        tex += "% new: #{finalname}\n"
        return tex
    end

end

module XML

    def XML::version
        "<?xml version='1.0'?>"
    end

    def XML::start(element, attributes='')
        if attributes.empty? then
            "<#{element}>"
        else
            "<#{element} #{attributes}>"
        end
    end

    def XML::end(element)
        "</#{element}>"
    end

    def XML::empty(element, attributes='')
        if attributes && attributes.empty? then
            "<#{element}/>"
        else
            "<#{element} #{attributes}/>"
        end
    end

    def XML::element(element, attributes='', content='')
        if content && ! content.empty? then
            XML::start(element,attributes) + content + XML::end(element)
        else
            XML::empty(element,attributes)
        end
    end

    def XML::box(tag, rect, type=1)
        case type
            when 1
                if rect && ! rect.empty? then
                    rect = rect.split(' ')
                    XML::element("#{tag}box", '',
                        XML::element("llx", '', rect[0]) +
                        XML::element("lly", '', rect[1]) +
                        XML::element("ulx", '', rect[2]) +
                        XML::element("uly", '', rect[3]) )
                else
                    XML::empty("#{tag}box")
                end
            when 2
                if rect && ! rect.empty? then
                    rect = rect.split(' ')
                    XML::element("box", "type='#{tag}'",
                        XML::element("llx", '', rect[0]) +
                        XML::element("lly", '', rect[1]) +
                        XML::element("ulx", '', rect[2]) +
                        XML::element("uly", '', rect[3]) )
                else
                    XML::empty("box", "type='#{tag}'")
                end
            when 3
                if rect && ! rect.empty? then
                    rect = rect.split(' ')
                    XML::element("box", "type='#{tag}' llx='#{rect[0]}' lly='#{rect[1]}' ulx='#{rect[2]}' uly='#{rect[3]}'")
                else
                    XML::empty("box", "type='#{tag}'")
                end
            else
                ''
        end
    end

    def XML::crlf
        "\n"
    end

    def XML::skip(n=1)
        '  '*n
    end

end

class Commands

    include CommandBase

    # alias savedhelp :help

    # def help
        # savedhelp
        # report("under construction (still separate tools)")
    # end

    # filename.pdf --spotimage --colorname=darkblue --colorspec=1,0.38,0,0.64

    def spotimage

        if ! @commandline.argument('first').empty? && files = findfiles() then
            colorname = @commandline.option('colorname')
            colorspec = @commandline.option('colorspec')
            if colorname && ! colorname.empty? && colorspec && ! colorspec.empty? then
                files.each do |filename|
                    s = SpotColorImage.new(self)
                    s.registercolor(colorspec,colorname)
                    s.convertgrayimage(filename)
                end
            else
                report("provide --colorname=somename --colorspec=c,m,y,k")
            end
        else
            report("provide filename (png, jpg, pdf)")
        end

    end

    def colorimage

        if ! @commandline.argument('first').empty? && files = findfiles() then
            colorname = @commandline.option('colorname')
            colorspec = @commandline.option('colorspec')
            if colorspec && ! colorspec.empty? then
                files.each do |filename|
                    s = ColorImage.new(self)
                    s.registercolor(colorspec,colorname) # name optional
                    s.convertimage(filename)
                end
            else
                report("provide --colorspec=c,m,y,k")
            end
        else
            report("provide filename")
        end

    end

    def convertimage

        if ! @commandline.argument('first').empty? && files = findfiles() then
            files.each do |filename|
                s = ConvertImage.new(self)
                s.convertimage(filename)
            end
        else
            report("provide filename")
        end

    end

    def downsampleimage

        if ! @commandline.argument('first').empty? && files = findfiles() then
            files.each do |filename|
                s = DownsampleImage.new(self)
                s.convertimage(filename)
            end
        else
            report("provide filename")
        end

    end

    def info

        if files = findfiles() then

            print(XML.version + XML.crlf)
            print(XML.start('pdfinfo', "xmlns='http://www.pragma-ade.com/schemas/pdfinfo.rng'") + XML.crlf)

            files.each do |filename|

                if filename =~ /\.pdf$/io then

                    begin
                        data = `pdfinfo -box #{filename}`.chomp.split("\n")
                    rescue
                        data = nil
                    end

                    if data then

                        pairs = Hash.new

                        data.each do |d|
                            if (d =~ /^\s*(.*?)\s*\:\s*(.*?)\s*$/moi) then
                                key, val = $1, $2
                                pairs[key.downcase.sub(/ /,'')] = val
                            end
                        end

                        print(XML.skip(1) + XML.start('pdffile', "filename='#{filename}'") + XML.crlf)

                        print(XML.skip(2) + XML.element('path', '', File.expand_path(filename)) + XML.crlf)

                        if pairs.key?('error') then

                            print(XML.skip(2) + XML.element('comment', '', pairs['error']) + XML.crlf)

                        else

                            print(XML.skip(2) + XML.element('version',  '', pairs['pdfversion']) + XML.crlf)
                            print(XML.skip(2) + XML.element('pages',    '', pairs['pages'     ]) + XML.crlf)
                            print(XML.skip(2) + XML.element('title',    '', pairs['title'     ]) + XML.crlf)
                            print(XML.skip(2) + XML.element('subject',  '', pairs['subject'   ]) + XML.crlf)
                            print(XML.skip(2) + XML.element('author',   '', pairs['author'    ]) + XML.crlf)
                            print(XML.skip(2) + XML.element('producer', '', pairs['producer'  ]) + XML.crlf)

                            if pairs.key?('creationdate') then
                                pairs['creationdate'].sub!(/(\d\d)\/(\d\d)\/(\d\d)/) do
                                    '20' + $3 + '-' + $1 + '-' +$2
                                end
                                pairs['creationdate'].sub!(/(\d\d)\/(\d\d)\/(\d\d\d\d)/) do
                                    $3 + '-' + $1 + '-' + $2
                                end
                                print(XML.skip(2) + XML.element('creationdate', '', pairs['creationdate']) + XML.crlf)
                            end

                            if pairs.key?('moddate') then
                                if pairs['moddate'] =~ /(\d\d\d\d)(\d\d)(\d\d)/ then
                                    pairs['moddate'] = "#{$1}-#{$2}-#{$3}"
                                end
                                print(XML.skip(2) + XML.element('modificationdate', '', pairs['moddate']) + XML.crlf)
                            end

                            print(XML.skip(2) + XML.element('tagged',    '', pairs['tagged'   ]) + XML.crlf)
                            print(XML.skip(2) + XML.element('encrypted', '', pairs['encrypted']) + XML.crlf)
                            print(XML.skip(2) + XML.element('optimized', '', pairs['optimized']) + XML.crlf)

                            if pairs.key?('PageSize') then
                                print(XML.skip(2) + XML.element('width',  '', pairs['pagesize'].sub(/\s*(.*?)\s+(.*?)\s+.*/, $1)) + XML.crlf)
                                print(XML.skip(2) + XML.element('height', '', pairs['pagesize'].sub(/\s*(.*?)\s+(.*?)\s+.*/, $2)) + XML.crlf)
                            end

                            if pairs.key?('FileSize') then
                                print(XML.skip(2) + XML.element('size', '', pairs['filesize'].sub(/\s*(.*?)\s+.*/, $1)) + XML.crlf)
                            end

                            print(XML.skip(2) + XML.box('media', pairs['mediabox']) + XML.crlf)
                            print(XML.skip(2) + XML.box('crop' , pairs['cropbox' ]) + XML.crlf)
                            print(XML.skip(2) + XML.box('bleed', pairs['bleedbox']) + XML.crlf)
                            print(XML.skip(2) + XML.box('trim' , pairs['trimBox' ]) + XML.crlf)
                            print(XML.skip(2) + XML.box('art'  , pairs['artbox'  ]) + XML.crlf)

                        end

                        print(XML.skip(1) + XML.end('pdffile') + XML.crlf)

                    end

                end

            end

            print(XML.end('pdfinfo') + XML.crlf)

        end

    end

    # name                                 type         emb sub uni object ID
    # ------------------------------------ ------------ --- --- --- ---------
    # EOPLBP+TimesNewRomanPSMT             TrueType     yes yes no     167  0
    # Times-Roman                          TrueType     no  no  no      95  0
    # EPBAAB+Helvetica                     Type 1C      yes yes yes    108  0
    # EPBMLE+Helvetica-Oblique             Type 1C      yes yes yes    111  0
    # Helvetica                            TrueType     no  no  no     112  0

    def checkembedded
        $stderr = $stdout
        $stdout.flush
        if @commandline.option('pattern') then
            # **/*.pdf
            filenames, n = globfiles(@commandline.option('pattern'),'pdf'), 0
        else
            filenames, n = findfiles('pdf'), 0
        end
        filenames.sort.each do |file|
            report("= checking #{File.expand_path(file)}")
            result = `pdffonts #{file}`.chomp
            lines = result.split(/\n/)
            if result =~ /emb\s+sub\s+uni/io then
                lines.each do |line|
                    report("! #{line}") if line =~ /no\s+(no|yes)\s+(no|yes)/io
                end
            else
                lines.each do |line|
                    report("? #{line}")
                end
            end
            report("")
        end
    end

    def countpages
        if @commandline.option('pattern') then
            filenames, n = globfiles(@commandline.option('pattern'),'pdf'), 0
        else
            filenames, n = findfiles('pdf'), 0
        end
        threshold = @commandline.option('threshold').to_i rescue 0
        filenames.each do |filename|
            if `pdfinfo #{filename}`.chomp =~ /^pages\s*\:\s*(\d+)/moi then
                p = $1
                m = p.to_i rescue 0
                if threshold == 0 or m > threshold then
                    report("#{p.rjust(4)} pages found in #{filename}")
                    n += m
                end
           end
        end
        report("")
        report("#{n.to_s.rjust(4)} pages in total")
    end

    def analyzefile
        # needs an update
        filenames = @commandline.arguments
        filenames.each do |filename|
            if filename && FileTest.file?(filename) && filename =~ /\.pdf/io then
                filesize = FileTest.size(filename)
                report("analyzing file : #{filename}")
                report("file size : #{filesize}")
                if pdf = File.open(filename) then
                    pdf.binmode
                    nofobject, nofxform, nofannot, noflink, nofwidget, nofnamed, nofscript, nofcross = 0, 0, 0, 0, 0, 0, 0, 0
                    while data = pdf.gets do
                        data.scan(/\d+\s+\d+\s+obj/o)      do nofobject += 1 end
                        data.scan(/\/Type\s*\/XObject/o)   do nofxform  += 1 end
                        data.scan(/\/Type\s*\/Annot/o)     do nofannot  += 1 end
                        data.scan(/\/GoToR\s*\/F/o)        do nofcross  += 1 end
                        data.scan(/\/Subtype\s*\/Link/o)   do noflink   += 1 end
                        data.scan(/\/Subtype\s*\/Widget/o) do nofwidget += 1 end
                        data.scan(/\/S\s*\/Named/o)        do nofnamed  += 1 end
                        data.scan(/\/S\s*\/JavaScript/o)   do nofscript += 1 end
                    end
                    pdf.close
                    report("objects : #{nofobject}")
                    report("xforms : #{nofxform}")
                    report("annotations : #{nofannot}")
                    report("links : #{noflink} (#{nofnamed} named / #{nofscript} scripts / #{nofcross} files)")
                    report("widgets : #{nofwidget}")
                end
            end
        end
    end

end

logger      = Logger.new(banner.shift)
commandline = CommandLine.new

commandline.registeraction('spotimage' ,      'filename --colorspec=  --colorname=  [--retain --invert --subpath=]')
commandline.registeraction('colorimage',      'filename --colorspec= [--retain --invert --colorname= ]')
commandline.registeraction('convertimage',    'filename [--retain --subpath]')
commandline.registeraction('downsampleimage', 'filename [--retain --subpath --lowres --normal]')
commandline.registeraction('info',            'filename')
commandline.registeraction('countpages',      '[--pattern --threshold]')
commandline.registeraction('checkembedded',   '[--pattern]')

commandline.registeraction('analyzefile' ,    'filename')

commandline.registeraction('help')
commandline.registeraction('version')

commandline.registervalue('colorname')
commandline.registervalue('colorspec')
commandline.registervalue('subpath')
commandline.registervalue('pattern')
commandline.registervalue('threshold',0)

commandline.registerflag('lowres')
commandline.registerflag('medres')
commandline.registerflag('normal')
commandline.registerflag('invert')
commandline.registerflag('retain')

commandline.expand

Commands.new(commandline,logger,banner).send(commandline.action || 'help')

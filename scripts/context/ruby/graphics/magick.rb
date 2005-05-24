# module    : graphics/inkscape
# copyright : PRAGMA Advanced Document Engineering
# version   : 2002-2005
# author    : Hans Hagen
#
# project   : ConTeXt / eXaMpLe
# concept   : Hans Hagen
# info      : j.hagen@xs4all.nl
# www       : www.pragma-ade.com

# ['base/variables','variables'].each do |r| begin require r ; rescue Exception ; else break ; end ; end

require 'base/variables'

class ImageMagick

    include Variables

    def initialize(logger=nil)

        unless logger then
            puts('magick class needs a logger')
            exit
        end

        @variables = Hash.new
        @logger    = logger

        reset

    end

    def reset
        ['compression','depth','colorspace','quality'].each do |key|
            setvariable(key)
        end
    end

    def supported?(filename) # ? pdf
        filename =~ /.*\.(png|gif|tif|tiff|jpg|jpeg|eps|ai\d*)/io
    end

    def convert(suffix='pdf')

        inpfilename = getvariable('inputfile').dup
        outfilename = getvariable('outputfile').dup
        outfilename = inpfilename.dup if outfilename.empty?
        outfilename.gsub!(/(\.[^\.]*?)$/, ".#{suffix}")

        if inpfilename.empty? || outfilename.empty? then
            report("no filenames given")
            return false
        end
        if inpfilename == outfilename then
            report("filenames must differ (#{inpfilename} #{outfilename})")
            return false
        end
        unless FileTest.file?(inpfilename) then
            report("unknown file #{inpfilename}")
            return false
        end

        if inpfilename =~ /\.tif+$/io then
            tmpfilename = 'temp.png'
            arguments = "#{inpfilename} #{tmpfilename}"
            begin
                debug("imagemagick: #{arguments}")
                ok = System.run('imagemagick',arguments)
            rescue
                report("aborted due to error")
                return false
            else
                return false unless ok
            end
            inpfilename = tmpfilename
        end

        compression = depth = colorspace = quality = ''

        if getvariable('compression') =~ /(zip|jpeg)/o then
            compression = " -compress #{$1}"
        end
        if getvariable('depth') =~ /(8|16)/o then
            depth = "-depth #{$1}"
        end
        if getvariable('colorspace') =~ /(gray|rgb|cmyk)/o then
            colorspace = "-colorspace #{$1}"
        end
        case getvariable('quality')
            when 'low'    then quality = '-quality 0'
            when 'medium' then quality = '-quality 75'
            when 'high'   then quality = '-quality 100'
        end

        report("converting #{inpfilename} to #{outfilename}")

        arguments = [compression,depth,colorspace,quality,inpfilename,outfilename].join(' ').gsub(/\s+/,' ')

        begin
            debug("imagemagick: #{arguments}")
            ok = System.run('imagemagick',arguments)
        rescue
            report("aborted due to error")
            return false
        else
            return ok
        end

    end

    def autoconvert

        inpfilename = getvariable('inputfile')
        outfilename = getvariable('outputfile')

        if inpfilename.empty? || ! FileTest.file?(inpfilename) then
            report("missing file #{inpfilename}")
            return
        end

        outfilename = inpfilename.dup if outfilename.empty?
        tmpfilename = 'temp.jpg'

        reset

        megabyte = 1024*1024

        ok = false

        if FileTest.size(inpfilename)>2*megabyte
            setvariable('compression','zip')
            ok = convert
        else
            setvariable('compression','jpeg')
            if FileTest.size(inpfilename)>10*megabyte then
                setvariable('quality',85)
            elsif FileTest.size(inpfilename)>5*megabyte then
                setvariable('quality',90)
            else
                setvariable('quality',95)
            end
            report("auto quality #{getvariable('quality')}")
            setvariable('outputfile', tmpfilename)
            ok = convert('jpg')
            setvariable('inputfile', tmpfilename)
            setvariable('outputfile', outfilename)
            ok = convert
            begin
                File.delete(tmpfilename)
            rescue
                report("#{tmpfilename} cannot be deleted")
            end
        end

        reset

        return ok

 end

end

# module    : graphics/gs
# copyright : PRAGMA Advanced Document Engineering
# version   : 2002-2005
# author    : Hans Hagen
#
# project   : ConTeXt / eXaMpLe
# concept   : Hans Hagen
# info      : j.hagen@xs4all.nl
# www       : www.pragma-ade.com

# ['base/variables','../variables','variables'].each do |r| begin require r ; rescue Exception ; else break ; end ; end
# ['base/system',   '../system',   'system'   ].each do |r| begin require r ; rescue Exception ; else break ; end ; end

require 'base/variables'
require 'base/system'
require 'fileutils'
# Require 'ftools'

class GhostScript

    include Variables

    @@pdftrimwhite = 'pdftrimwhite.pl'

    @@pstopdfoptions = [
        'AntiAliasColorImages',
        'AntiAliasGrayImages',
        'AntiAliasMonoImages',
        'ASCII85EncodePages',
        'AutoFilterColorImages',
        'AutoFilterGrayImages',
        'AutoPositionEPSFiles',
        'AutoRotatePages',
        'Binding',
        'ColorConversionStrategy',
        'ColorImageDepth',
        'ColorImageDownsampleThreshold',
        'ColorImageDownsampleType',
        'ColorImageFilter',
        'ColorImageResolution',
        'CompatibilityLevel',
        'CompressPages',
        #'ConvertCMYKImagesToRGB', # buggy
        #'ConvertImagesToIndexed', # buggy
        'CreateJobTicket',
        'DetectBlends',
        'DoThumbnails',
        'DownsampleColorImages',
        'DownsampleGrayImages',
        'DownsampleMonoImages',
        'EmbedAllFonts',
        'EncodeColorImages',
        'EncodeGrayImages',
        'EncodeMonoImages',
        'EndPage',
        'FirstPage',
        'GrayImageDepth',
        'GrayImageDownsampleThreshold',
        'GrayImageDownsampleType',
        'GrayImageFilter',
        'GrayImageResolution',
        'MaxSubsetPct',
        'MonoImageDepth',
        'MonoImageDownsampleThreshold',
        'MonoImageDownsampleType',
        'MonoImageFilter',
        'MonoImageResolution',
        'Optimize',
        'ParseDCSComments',
        'ParseDCSCommentsForDocInfo',
        'PreserveCopyPage',
        'PreserveEPSInfo',
        'PreserveHalftoneInfo',
        'PreserveOPIComments',
        'PreserveOverprintSettings',
        'SubsetFonts',
        'UseFlateCompression'
    ]

    @@methods = Hash.new

    @@methods['raw']         = '1'
    @@methods['bound']       = '2'
    @@methods['bounded']     = '2'
    @@methods['crop']        = '3'
    @@methods['cropped']     = '3'
    @@methods['down']        = '4'
    @@methods['downsample']  = '4'
    @@methods['downsampled'] = '4'
    @@methods['simplify']    = '5'
    @@methods['simplified']  = '5'

    @@tempfile    = 'gstemp'
    @@pstempfile  = @@tempfile + '.ps'
    @@pdftempfile = @@tempfile + '.pdf'

    @@bboxspec = '\s*([\-\d\.]+)' + '\s+([\-\d\.]+)'*3

    def initialize(logger=nil)

        unless logger then
            puts('gs class needs a logger')
            exit
        end

        @variables = Hash.new
        @psoptions = Hash.new
        @logger    = logger

        setvariable('profile',    'gsprofile.ini')
        setvariable('pipe',       true)
        setvariable('method',     2)
        setvariable('force',      false)
        setvariable('colormodel', 'cmyk')
        setvariable('inputfile',  '')
        setvariable('outputfile', '')

        @@pstopdfoptions.each do |key|
            @psoptions[key] = ''
        end

        reset

    end

    def reset
        @llx = @lly = @ulx = @uly = 0
        @oldbbox = [@llx,@lly,@urx,@ury]
        @width = @height = @xoffset = @yoffset = @offset = 0
        @rs = Tool.default_line_separator
    end

    def supported?(filename)
        psfile?(filename) || pdffile?(filename)
    end

    def psfile?(filename)
        filename =~ /\.(eps|epsf|ps|ai\d*)$/io
    end

    def pdffile?(filename)
        filename =~ /\.(pdf)$/io
    end

    def setpsoption(key,value)
        @psoptions[key] = value unless value.empty?
    end

    def setdimensions (llx,lly,urx,ury)
        @oldbbox = [llx,lly,urx,ury]
        @llx, @lly = llx.to_f-@offset, lly.to_f-@offset
        @urx, @ury = urx.to_f+@offset, ury.to_f+@offset
        @width,   @height  = @urx - @llx, @ury - @lly
        @xoffset, @yoffset =    0 - @llx,    0 - @lly
    end

    def setoffset (offset=0)
        @offset = offset.to_f
        setdimensions(@llx,@lly,@urx,@ury) if dimensions?
    end

    def resetdimensions
        setdimensions(0,0,0,0)
    end

    def dimensions?
        (@width>0) && (@height>0)
    end

    def convert

        inpfile = getvariable('inputfile')

        if inpfile.empty? then
            report('no inputfile specified')
            return false
        end

        unless FileTest.file?(inpfile) then
            report("unknown input file #{inpfile}")
            return false
        end

        outfile = getvariable('outputfile')

        if outfile.empty? then
            outfile = inpfile
            outfile = outfile.sub(/^.*[\\\/]/,'')
        end

        outfile = outfile.sub(/\.(pdf|eps|ps|ai)/i, "")
        resultfile = outfile + '.pdf'
        setvariable('outputfile', resultfile)

        # flags

        saveprofile(getvariable('profile'))

        begin
            gsmethod = method(getvariable('method')).to_i
            report("conversion method #{gsmethod}")
        rescue
            gsmethod = 1
            report("fallback conversion method #{gsmethod}")
        end

        debug('piping data') if getvariable('pipe')

        ok = false
        begin
            case gsmethod
                when 0, 1 then ok = convertasis(inpfile,resultfile)
                when 2    then ok = convertbounded(inpfile,resultfile)
                when 3    then ok = convertcropped(inpfile,resultfile)
                when 4    then ok = downsample(inpfile,resultfile,'screen')
                when 5    then ok = downsample(inpfile,resultfile,'prepress')
                else report("invalid conversion method #{gsmethod}")
            end
        rescue
            report("job aborted due to some error: #{$!}")
            begin
                File.delete(resultfile) if FileTest.file?(resultfile)
            rescue
                report("unable to delete faulty #{resultfile}")
            end
            ok = false
        ensure
            deleteprofile(getvariable('profile'))
            File.delete(@@pstempfile)  if FileTest.file?(@@pstempfile)
            File.delete(@@pdftempfile) if FileTest.file?(@@pdftempfile)
        end
        return ok
    end

    # private

    def method (str)
        if @@methods.key?(str) then
            @@methods[str]
        else
            str
        end
    end

    def pdfmethod? (str)
        case method(str).to_i
            when 1, 3, 4, 5 then return true
        end
        return false
    end

    def pdfprefix (str)
        case method(str).to_i
            when 1 then return 'raw-'
            when 4 then return 'lowres-'
            when 5 then return 'normal-'
        end
        return ''
    end

    def psmethod? (str)
        ! pdfmethod?(str)
    end

    def insertprofile (flags)
        for key in flags.keys do
            replacevariable("flag.#{key}", flags[key])
        end
    end

    def deleteprofile (filename)
        begin
            File.delete(filename) if FileTest.file?(filename)
        rescue
        end
    end

    def saveprofile (filename)
        return if filename.empty? || ! (ini = open(filename,"w"))
        @@pstopdfoptions.each do |k|
            str = @psoptions[k]
            # beware, booleans are translated, but so are yes/no which is dangerous
            if str.class == String then
                if ! str.empty? && (str != 'empty') then
                    str.sub!(/(.+)\-/io, '')
                    str = "/" + str unless str =~ /^(true|false|none|[\d\.\-\+]+)$/
                    ini.puts("-d#{k}=#{str}\n")
                end
            end
        end
        ini.close
        debug("gs profile #{filename} saved")
    end

    def gsstream # private
        if getvariable('pipe') then '-' else @@pstempfile end
    end

    def gscolorswitch
        case getvariable('colormodel')
            when 'cmyk' then '-dProcessColorModel=/DeviceCMYK -dColorConversionStrategy=/CMYK '
            when 'rgb'  then '-dProcessColorModel=/DeviceRGB  -dColorConversionStrategy=/RGB '
            when 'gray' then '-dProcessColorModel=/DeviceGRAY -dColorConversionStrategy=/GRAY '
        else
            ''
        end
    end

    def gsdefaults
        defaults = ''
        begin
            defaults << '-dAutoRotatePages=/None ' if @psoptions['AutoRotatePages'].empty?
        rescue
            defaults << '-dAutoRotatePages=/None '
        end
        return defaults
    end

    def convertasis (inpfile, outfile)

        report("converting #{inpfile} as-is")

        @rs = Tool.line_separator(inpfile)
        debug("platform mac") if @rs == "\r"

        arguments = ''
        arguments << "\@gsprofile.ini "
        arguments << "-q -sDEVICE=pdfwrite -dNOPAUSE -dNOCACHE -dBATCH "
        arguments << "#{gsdefaults} "
        arguments << "#{gscolorswitch} "
        arguments << "-sOutputFile=#{outfile} #{inpfile} -c quit "

        debug("ghostscript: #{arguments}")
        unless ok = System.run('ghostscript',arguments) then
            begin
                report("removing file #{outfile}")
                File.delete(outfile) if FileTest.file?(outfile)
            rescue
                debug("file #{outfile} may be invalid")
            end
        end
        return ok

    end

    def convertbounded(inpfile, outfile)
        report("converting #{inpfile} bounded")
        do_convertbounded(inpfile, outfile)
    end

    def do_convertbounded(inpfile, outfile)

        begin
            return false if FileTest.file?(outfile) && (! File.delete(outfile))
        rescue
            return false
        end

        arguments = ''
        arguments << "\@gsprofile.ini "
        arguments << "-q -sDEVICE=pdfwrite -dNOPAUSE -dNOCACHE -dBATCH -dSAFER "
        arguments << "#{gscolorswitch} "
        arguments << "#{gsdefaults} "
        arguments << "-sOutputFile=#{outfile} #{gsstream} -c quit "

        debug("ghostscript: #{arguments}")
        debug('opening input file')

        @rs = Tool.line_separator(inpfile)
        debug("platform mac") if @rs == "\r"

        if FileTest.file?(outfile) and not File.writable?(outfile) then
            report("output file cannot be written")
            return false
        elsif not tmp = open(inpfile, 'rb') then
            report("input file cannot be opened")
            return false
        end

        debug('opening pipe/file')

        if getvariable('pipe') then

            return false unless eps = IO.popen(System.command('ghostscript',arguments),'wb')
            debug('piping data')
            unless pipebounded(tmp,eps) then
                debug('something went wrong in the pipe')
                File.delete(outfile) if FileTest.file?(outfile)
            end
            debug('closing pipe')
            eps.close_write

        else

            return false unless eps = File.open(@@pstempfile, 'wb')

            debug('copying data')

            if pipebounded(tmp,eps) then
                eps.close
                debug('processing temp file')
                begin
                    ok = System.run('ghostscript',arguments)
                rescue
                    ok = false
                    # debug("fatal error: #{$!}")
                ensure
                end
            else
                eps.close
                ok = false
            end

            unless ok then
                begin
                    report('no output file due to error')
                    File.delete(outfile) if FileTest.file?(outfile)
                rescue
                    # debug("fatal error: #{$!}")
                    debug('file',outfile,'may be invalid')
                end
            end

            debug('deleting temp file')
            begin
                File.delete(@@pstempfile) if FileTest.file?(@@pstempfile)
            rescue
            end

        end

        tmp.close
        return FileTest.file?(outfile)

    end

    # hm, strange, no execute here, todo ! ! !

    def getdimensions (inpfile)

        # -dEPSFitPage and -dEPSCrop behave weird (don't work)

        arguments = "-sDEVICE=bbox -dSAFER -dNOPAUSE -dBATCH #{inpfile} "

        debug("ghostscript: #{arguments}")

        begin
            bbox = System.run('ghostscript',arguments,true,true)
        rescue
            bbox = ''
        end

        resetdimensions

        debug('bbox spec', bbox)

        if bbox =~ /(Exact|HiRes)BoundingBox:#{@@bboxspec}/moi then
            debug("high res bbox #{$2} #{$3} #{$4} #{$5}")
            setdimensions($2,$3,$4,$5)
        elsif bbox =~ /BoundingBox:#{@@bboxspec}/moi
            debug("low res bbox #{$1} #{$2} #{$3} #{$4}")
            setdimensions($1,$2,$3,$4)
        end

        return dimensions?

    end

    # def convertcropped (inpfile, outfile)
        # report("converting #{inpfile} cropped")
        # do_convertbounded(inpfile, @@pdftempfile)
        # return unless FileTest.file?(@@pdftempfile)
        # arguments = " --offset=#{@offset} #{@@pdftempfile} #{outfile}"
        # report("calling #{@@pdftrimwhite}")
        # unless ok = System.run(@@pdftrimwhite,arguments) then
            # report('cropping failed')
            # begin
                # File.delete(outfile)
            # rescue
            # end
            # begin
                # File.move(@@pdftempfile,outfile)
            # rescue
                # File.copy(@@pdftempfile,outfile)
                # File.delete(@@pdftempfile)
            # end
        # end
        # return ok
    # end

    def convertcropped (inpfile, outfile)
        report("converting #{inpfile} cropped")
        if File.expand_path(inpfile) == File.expand_path(outfile) then
            report("output filename must be different")
        elsif inpfile =~ /\.pdf$/io then
            System.run("pdftops -eps #{inpfile} #{@@pstempfile}")
            if getdimensions(@@pstempfile) then
                report("tight boundingbox found")
            end
            do_convertbounded(@@pstempfile, outfile)
            File.delete(@@pstempfile) if FileTest.file?(@@pstempfile)
        else
            if getdimensions(inpfile) then
                report("tight boundingbox found")
            end
            do_convertbounded(inpfile, outfile)
        end
        resetdimensions
        return true
    end


    def pipebounded (eps, out)

        epsbbox, skip, buffer = false, false, ''

        while str = eps.gets(rs=@rs) do
            if str =~ /^%!PS/oi then
                debug("looks like a valid ps file")
                break
            elsif str =~ /%PDF\-\d+\.\d+/oi then
                debug("looks like a pdf file, so let\'s quit")
                return false
            end
        end

        # why no BeginData check

        eps.rewind

if dimensions? then

        debug('using found boundingbox')

else

        debug('locating boundingbox')
        while str = eps.gets(rs=@rs) do
            case str
                when /^%%Page:/io then
                    break
                when /^%%(Crop|HiResBounding|ExactBounding)Box:#{@@bboxspec}/moi then
                    debug('high res boundingbox found')
                    setdimensions($2,$3,$4,$5)
                    break
                when /^%%BoundingBox:#{@@bboxspec}/moi then
                    debug('low res boundingbox found')
                    setdimensions($1,$2,$3,$4)
            end
        end
        debug('no boundingbox found') if @width == 0

end

        eps.rewind

        while str = eps.gets(rs=@rs) do
            if str.sub!(/^(.*)%!PS/moi, "%!PS") then
                debug("removing pre banner data")
                out.puts(str)
                break
            end
        end

        while str = eps.gets(rs=@rs) do
            if skip then
                skip = false if str =~ /^%+(EndData|EndPhotoshop|BeginProlog).*$/o
                out.puts(str) if $1 == "BeginProlog"
            elsif str =~ /^%(BeginPhotoshop)\:\s*\d+.*$/o then
                skip = true
            elsif str =~ /^%%/mos then
                if ! epsbbox && str =~ /^%%(Page:|EndProlog)/io then
                    out.puts(str) if $1 == "EndProlog"
                    debug('faking papersize')
                    # out.puts("<< /PageSize [#{@width} #{@height}] >> setpagedevice\n")
                    if ! dimensions? then
                        out.puts("<< /PageSize [1 1] >> setpagedevice\n")
                    else
                        out.puts("<< /PageSize [#{@width} #{@height}] >> setpagedevice\n")
                    end
                    out.puts("gsave #{@xoffset} #{@yoffset} translate\n")
                    epsbbox = true
                elsif str =~ /^%%BeginBinary\:\s*\d+\s*$/o then
                    debug('copying binary data')
                    out.puts(str)
                    while str = eps.gets(rs=@rs)
                        if str =~ /^%%EndBinary\s*$/o then
                            out.puts(str)
                        else
                            out.write(str)
                        end
                    end
                elsif str =~ /^%AI9\_PrivateDataBegin/o then
                    debug('ignore private ai crap')
                    break
                elsif str =~ /^%%EOF/o then
                    debug('ignore post eof crap')
                    break
                # elsif str =~ /^%%PageTrailer/o then
                    # debug('ignoring post page trailer crap')
                    # break
                elsif str =~ /^%%Trailer/o then
                    debug('ignoring post trailer crap')
                    break
                elsif str =~ /^%%Creator.*Illustrator.*$/io then
                    debug('getting rid of problematic creator spec')
                    str = "% Creator: Adobe Illustrator ..."
                    out.puts(str)
                elsif str =~ /^%%AI.*(PaperRect|Margin)/io then
                    debug('removing AI paper crap')
                elsif str =~ /^%%AI.*Version.*$/io then
                    debug('removing dangerous version info')
                elsif str =~ /^(%+AI.*Thumbnail.*)$/o then
                    debug('skipping AI thumbnail')
                    skip = true
                else
                    out.puts(str)
                end
            else
                out.puts(str)
            end
        end

        debug('done, sending EOF')

        out.puts "grestore\n%%EOF\n"

        # ok = $? == 0
        # report('process aborted, broken pipe, fatal error') unless ok
        # return ok

resetdimensions

        return true

    end

    def downsample (inpfile, outfile, method='screen')

        # gs <= 8.50

        report("downsampling #{inpfile}")

        doit = true
        unless getvariable('force') then
            begin
                if f = File.open(inpfile) then
                    f.binmode
                    while doit && (data = f.gets) do
                        if data =~ /\/ArtBox\s*\[\s*[\d\.]+\s+[\d\.]+\s+[\d\.]+\s+[\d\.]+\s*\]/io then
                            doit = false
                        end
                    end
                    f.close
                end
            rescue
            end
        end

        if doit then
            arguments = ''
            arguments << "-dPDFSETTINGS=/#{method} -dEmbedAllFonts=true "
            arguments << "#{gscolorswitch} "
            arguments << "#{gsdefaults} "
            arguments << "-q -sDEVICE=pdfwrite -dNOPAUSE -dNOCACHE -dBATCH -dSAFER "
            arguments << "-sOutputFile=#{outfile} #{inpfile} -c quit "
            unless ok = System.run('ghostscript',arguments) then
                begin
                    File.delete(outfile) if FileTest.file?(outfile)
                    report("removing file #{outfile}")
                rescue
                    debug("file #{outfile} may be invalid")
                end
            end
            return ok
        else
            report("crop problem, straight copying #{inpfile}")
            File.copy(inpfile,outfile)
            return false
        end

    end

end

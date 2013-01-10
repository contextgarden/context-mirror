# module    : base/tool
# copyright : PRAGMA Advanced Document Engineering
# version   : 2002-2005
# author    : Hans Hagen
#
# project   : ConTeXt / eXaMpLe
# concept   : Hans Hagen
# info      : j.hagen@xs4all.nl
# www       : www.pragma-ade.com

require 'timeout'
require 'socket'
require 'rbconfig'

module Tool

    $constructedtempdir = ''

    def Tool.constructtempdir(create,mainpath='',fallback='')
        begin
            mainpath += '/' unless mainpath.empty?
            timeout(5) do
                begin
                    t = Time.now
                    u = t.usec.to_s % [1..2] [0..3]
                    pth = t.strftime("#{mainpath}%Y%m%d-%H%M%S-#{u}-#{Process.pid}")
                #
                #    problems with 1.9
                #
                #    if pth == $constructedtempdir
                #        # sleep(0.01)
                #        retry
                #    end
                    pth == $constructedtempdir
                #
                    Dir.mkdir(pth) if create
                    $constructedtempdir = pth
                    return pth
                rescue
                    # sleep(0.01)
                    retry
                end
            end
        rescue TimeoutError
            # ok
        rescue
            # ok
        end
        unless fallback.empty?
            begin
                pth = "#{mainpath}#{fallback}"
                mkdir(pth) if create
                $constructedtempdir = path
                return pth
            rescue
                return '.'
            end
        else
            return '.'
        end

    end

    def Tool.findtempdir(*vars)
        constructtempdir(false,*vars)
    end

    def Tool.maketempdir(*vars)
        constructtempdir(true,*vars)
    end

    # print maketempdir + "\n"
    # print maketempdir + "\n"
    # print maketempdir + "\n"
    # print maketempdir + "\n"
    # print maketempdir + "\n"


    def Tool.ruby_platform
        case RUBY_PLATFORM
            when /(mswin|bccwin|mingw|cygwin)/i then 'mswin'
            when /(linux)/i                     then 'linux'
            when /(netbsd|unix)/i               then 'unix'
            when /(darwin|rhapsody|nextstep)/i  then 'macosx'
            else                                     'unix'
        end
    end

    $defaultlineseparator = $/ # $RS in require 'English'

    def Tool.file_platform(filename)

        begin
            if f = open(filename,'rb') then
                str = f.read(4000)
                str.gsub!(/(.*?)\%\!PS/mo, "%!PS") # don't look into preamble crap
                f.close
                nn = str.count("\n")
                nr = str.count("\r")
                if nn>nr then
                    return 2
                elsif nn<nr then
                    return 3
                else
                    return 1
                end
            else
                return 0
            end
        rescue
            return 0
        end

    end

    def Tool.path_separator
        return File::PATH_SEPARATOR
    end

    def Tool.line_separator(filename)

        case file_platform(filename)
            when 1 then return $defaultlineseparator
            when 2 then return "\n"
            when 3 then return "\r"
            else        return $defaultlineseparator
        end

    end

    def Tool.default_line_separator
        $defaultlineseparator
    end

    def Tool.simplefilename(old)

        return old # too fragile

        return old if not FileTest.file?(old)

        new = old.downcase
        new.gsub!(/[^A-Za-z0-9\_\-\.\\\/]/o) do # funny chars
            '-'
        end
        if old =~ /[a-zA-Z]\:/o
            # seems like we have a dos/windows drive prefix, so roll back
            new.sub!(/^(.)\-/) do
                $1 + ':'
            end
        end
        # fragile for a.b.c.d.bla-bla.e.eps
        # new.gsub!(/(.+?)\.(.+?)(\..+)$/o)  do # duplicate .
            # $1 + '-' + $2 + $3
        # end
        new.gsub!(/\-+/o)                  do # duplicate -
            '-'
        end
        new

    end

    if RbConfig::CONFIG['host_os'] =~ /mswin/ then

        require 'Win32API'

        GetShortPathName = Win32API.new('kernel32', 'GetShortPathName', ['P','P','N'], 'N')
        GetLongPathName = Win32API.new('kernel32', 'GetLongPathName', ['P','P','N'], 'N')

        def Tool.dowith_pathname (filename,filemethod)
            filename.gsub!(/\\/o,'/')
            case filename
                when /\;/o then
                    # could be a path spec
                    return filename
                when /\s+/o then
                    # danger lurking
                    buffer = ' ' * 260
                    length = filemethod.call(filename,buffer,buffer.size)
                    if length>0 then
                        return buffer.slice(0..length-1)
                    else
                        # when the path or file does not exist, nothing is returned
                        # so we try to handle the path separately from the basename
                        basename = File.basename(filename)
                        pathname = File.dirname(filename)
                        length = filemethod.call(pathname,buffer,260)
                        if length>0 then
                            return buffer.slice(0..length-1) + '/' + basename
                        else
                            return filename
                        end
                    end
                else
                    # no danger
                    return filename
            end
        end

        def Tool.shortpathname(filename)
            dowith_pathname(filename,GetShortPathName)
        end

        def Tool.longpathname(filename)
            dowith_pathname(filename,GetLongPathName)
        end

    else

        def Tool.shortpathname(filename)
            filename
        end

        def Tool.longpathname(filename)
            filename
        end

    end

    # print shortpathname("C:/Program Files/ABBYY FineReader 6.0/matrix.str")+ "!\n"
    # print shortpathname("C:/Program Files/ABBYY FineReader 6.0/matrix.strx")+ "!\n"

    def Tool.checksuffix(old)

        return old unless FileTest.file?(old)

        new = old

        unless new =~ /\./io # no suffix
            f = open(filename,'rb')
            if str = f.gets
                case str
                    when /^\%\!PS/io
                        # logging.report(filename, 'analyzed as EPS')
                        new = new + '.eps'
                    when /^\%PDF/io
                        # logging.report(filename, 'analyzed as PDF')
                        new = new + '.pdf'
                    else
                        # logging.report(filename, 'fallback as TIF')
                        new = new + '.tif'
                end
            end
            f.close
        end

        new.sub!(/\.jpeg$/io) do
            '.jpg'
        end
        new.sub!(/\.tiff$/io) do
            '.tif'
        end
        new.sub!(/\.ai$/io) do
            '.eps'
        end
        new.sub!(/\.ai([a-z0-9]*)$/io) do
            '-' + $1 + '.eps'
        end
        new

    end

    def Tool.cleanfilename(old,logging=nil)

        return old if not FileTest.file?(old)

        new = checksuffix(simplefilename(old))
        unless new == old
            begin # bugged, should only be name, not path
                File.rename(old,new)
                logging.report("renaming fuzzy name #{old} to #{new}") unless logging
                return old
            rescue
                logging.report("unable to rename fuzzy name #{old} to #{new}") unless logging
            end
        end
        return new

    end

    def Tool.servername
        host = Socket::gethostname
        begin
            Socket::gethostbyname(host)[0]
        rescue
            host
        end
    end

    # print file_platform(ARGV[0])

end

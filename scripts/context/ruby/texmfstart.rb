#!/usr/bin/env ruby

# program   : texmfstart
# copyright : PRAGMA Advanced Document Engineering
# version   : 1.04 - 2003/2004
# author    : Hans Hagen
#
# project   : ConTeXt / eXaMpLe
# info      : j.hagen@xs4all.nl
# www       : www.pragma-pod.com / www.pragma-ade.com

# no special requirements, i.e. no exa modules/classes used

# texmfstart [switches] filename [optional arguments]
#
# ruby2exe texmfstart --help -> avoids stub test
#
# Of couse I can make this into a nice class, which i'll undoubtely will
# do when I feel the need. In that case it will be part of a bigger game.

# turning this into a service would be nice, so some day ...

require "rbconfig"

$mswindows = Config::CONFIG['host_os'] =~ /mswin/
$separator = File::PATH_SEPARATOR

if $mswindows then

    require "win32ole"
    require "Win32API"

    GetShortPathName = Win32API.new('kernel32', 'GetShortPathName', ['P','P','N'], 'N')
    GetLongPathName  = Win32API.new('kernel32', 'GetLongPathName',  ['P','P','N'], 'N')

    def dowith_pathname (filename,filemethod)
        filename = filename.gsub(/\\/o,'/') # no gsub! because filename can be frozen
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

    def shortpathname (filename)
        dowith_pathname(filename,GetShortPathName)
    end

    def longpathname (filename)
        dowith_pathname(filename,GetLongPathName)
    end

else

    def shortpathname (filename)
        filename
    end

    def longpathname (filename)
        filename
    end

end

$applications = Hash.new
$suffixinputs = Hash.new
$predefined   = Hash.new

$suffixinputs['pl']  = 'PERLINPUTS'
$suffixinputs['rb']  = 'RUBYINPUTS'
$suffixinputs['py']  = 'PYTHONINPUTS'
$suffixinputs['jar'] = 'JAVAINPUTS'
$suffixinputs['pdf'] = 'PDFINPUTS'

$predefined['texexec']  = 'texexec.pl'
$predefined['texutil']  = 'texutil.pl'
$predefined['texfont']  = 'texfont.pl'
$predefined['examplex'] = 'examplex.rb'
$predefined['concheck'] = 'concheck.rb'
$predefined['textools'] = 'textools.rb'
$predefined['pdftools'] = 'pdftools.rb'
$predefined['exatools'] = 'exatools.rb'
$predefined['xmltools'] = 'xmltools.rb'

$scriptlist   = 'rb|pl|py|jar'
$documentlist = 'pdf|ps|eps|htm|html'

def hashed (arr=[])
    arg = if arr.class == String then arr.split(' ') else arr.dup end
    hsh = Hash.new
    if arg.length > 0
        hsh['arguments'] = ''
        done = false
        arg.each do |s|
            if done then
                hsh['arguments'] += ' ' + s
            else
                kvl = s.split('=')
                if kvl[0].sub!(/^\-+/,'') then
                    hsh[kvl[0]] = if kvl.length > 1 then kvl[1] else true end
                else
                    hsh['file'] = s
                    done = true
                end
            end
        end
    end
    return hsh
end

def launch(filename)
    if $browser && $mswindows then
        filename.gsub!(/\.[\/\\]/) do
            Dir.getwd + '/'
        end
        report("launching #{filename}")
        ie = WIN32OLE.new("InternetExplorer.Application")
        ie.visible = true
        ie.navigate(filename)
        return true
    else
        return false
    end
end

def expanded(arg)
    arg.gsub(/kpse\:(\S+)/o) do
        original, resolved = $1, ''
        begin
            resolved = `kpsewhich -progname=#{program} -format=\"other text files\" #{file}`.chomp
        rescue
            resolved = ''
        end
        if resolved.empty? then
            report("#{original} is not resolved") unless $report
            original
        else
            report("#{original} is resolved to #{resolved}") unless $report
            resolved
        end
    end
end

def runcommand(command)
    if $execute then
        report("using 'exec' instead of 'system' call") if $verbose
        exec(command)
    else
        system(command)
    end
end

def runoneof(application,fullname,browserpermitted)
    if browserpermitted && launch(fullname) then
        return true
    else
        report("starting #{$filename}") unless $report
        print "\n" if $report && $verbose
        applications = $applications[application]
        if applications.class == Array then
            if $report then
                print [fullname,expanded($arguments)].join(' ')
                return true
            else
                applications.each do |a|
                    if runcommand([a,fullname,expanded($arguments)].join(' ')) then
                        return true
                    end
                end
            end
        elsif applications.empty? then
            if $report then
                print [fullname,expanded($arguments)].join(' ')
                return true
            else
                return runcommand([fullname,expanded($arguments)].join(' '))
            end
        else
            if $report then
                print [applications,fullname,expanded($arguments)].join(' ')
                return true
            else
                return runcommand([applications,fullname,expanded($arguments)].join(' '))
            end
        end
        return false
    end
end

def report(str)
    print str + "\n" if $verbose ;
end

def usage
    print "version  : 1.05 - 2003/2004 - www.pragma-ade.com\n"
    print("\n")
    print("usage    : texmfstart [switches] filename [optional arguments]\n")
    print("\n")
    print("switches : --verbose --report --browser --direct --execute\n")
    print("           --program --file   --page    --arguments\n")
    print("           --make    --lmake  --wmake\n")
    print("\n")
    print("example  : texmfstart pstopdf.rb cow.eps\n")
    print("           texmfstart --browser examplap.pdf\n")
    print("           texmfstart showcase.pdf\n")
    print("           texmfstart --page=2 --file=showcase.pdf\n")
    print("           texmfstart --program=yourtex yourscript.pl arg-1 arg-2\n")
    print("           texmfstart --direct xsltproc kpse:somefile.xsl somefile.xml\n")
    print("           texmfstart bin:xsltproc kpse:somefile.xsl somefile.xml\n")
end

# somehow registration does not work out (at least not under windows)

def registered?(filename)
    return ENV["texmfstart.#{filename}"] != nil
end

def registered(filename)
    return ENV["texmfstart.#{filename}"]
end

def register(filename,fullname)
    if fullname && ! fullname.empty? then # && FileTest.file?(fullname)
        ENV["texmfstart.#{filename}"] = fullname
        return true
    else
        return false
    end
end

def find(filename,program)
    if $predefined.key?(filename) then
        report("expanding '#{filename}' to '#{$predefined[filename]}'")
        filename = $predefined[filename]
    end
    if registered?(filename) then
        report("already located '#{filename}'")
        return registered(filename)
    end
    # create suffix list
    if filename =~ /^(.*)\.(.+)$/ then
        filename = $1
        suffixlist = [$2]
    else
        suffixlist = [$scriptlist.split('|'),$documentlist.split('|')].flatten
    end
    # first we honor a given path
    if filename =~ /[\\\/]/ then
        report("trying to honor '#{filename}'")
        suffixlist.each do |suffix|
            fullname = filename+'.'+suffix
            if FileTest.file?(fullname) && register(filename,fullname)
                return shortpathname(fullname)
            end
        end
    end
    filename.sub!(/^.*[\\\/]/, '')
    # next we look at the current path
    suffixlist.each do |suffix|
        report("locating '#{filename}.#{suffix}' in currentpath")
        fullname = './'+filename+'.'+suffix
        if FileTest.file?(fullname) && register(filename,fullname) then
            report("'#{filename}.#{suffix}' located in currentpath")
            return shortpathname(fullname)
        end
    end
    # now we consult environment settings
    fullname = nil
    suffixlist.each do |suffix|
        begin
            break unless $suffixinputs[suffix]
            environment = ENV[$suffixinputs[suffix]] || ENV[$suffixinputs[suffix]+".#{$program}"]
            if ! environment || environment.empty? then
                begin
                    environment = `kpsewhich -expand-path=\$#{$suffixinputs[suffix]}`.chomp
                rescue
                    environment = nil
                else
                    if environment && ! environment.empty? then
                        report("using kpsewhich variable #{$suffixinputs[suffix]}")
                    end
                end
            elsif environment && ! environment.empty? then
                report("using environment variable #{$suffixinputs[suffix]}")
            end
            if environment && ! environment.empty? then
                environment.split($separator).each do |e|
                    e.strip!
                    e = '.' if e == '\.' # somehow . gets escaped
                    e += '/' unless e =~ /[\\\/]$/
                    fullname = e + filename + '.' + suffix
                    report("testing '#{fullname}'")
                    if FileTest.file?(fullname) then
                        break
                    else
                        fullname = nil
                    end
                end
            end
        rescue
            report("environment string '#{$suffixinputs[suffix]}' cannot be used to locate '#{filename}'")
            fullname = nil
        else
            return shortpathname(fullname) if register(filename,fullname)
        end
    end
    return shortpathname(fullname) if register(filename,fullname)
    # then we fall back on kpsewhich
    suffixlist.each do |suffix|
        # TDS script scripts location as per 2004
        if suffix =~ /(#{$scriptlist})/ then
            begin
                report("using 'kpsewhich' to locate '#{filename}' in suffix space '#{suffix}' (1)")
                fullname = `kpsewhich -progname=#{program} -format=texmfscripts #{filename}.#{suffix}`.chomp
            rescue
                report("kpsewhich cannot locate '#{filename}' in suffix space '#{suffix}' (1)")
                fullname = nil
            else
                return shortpathname(fullname) if register(filename,fullname)
            end
        end
        # old TDS location: .../texmf/context/...
        begin
            report("using 'kpsewhich' to locate '#{filename}' in suffix space '#{suffix}' (2)")
            fullname = `kpsewhich -progname=#{program} -format="other text files" #{filename}.#{suffix}`.chomp
        rescue
            report("kpsewhich cannot locate '#{filename}' in suffix space '#{suffix}' (2)")
            fullname = nil
        else
            return shortpathname(fullname) if register(filename,fullname)
        end
    end
    return fullname if register(filename,fullname)
    # bad luck, we need to search the tree ourselves
    if (suffixlist.length == 1) && (suffixlist.first =~ /(#{$documentlist})/) then
        report("aggressively locating '#{filename}' in document trees")
        begin
            texroot = `kpsewhich -expand-var=$SELFAUTOPARENT`.chomp
        rescue
            texroot = ''
        else
            texroot.sub!(/[\\\/][^\\\/]*?$/, '')
        end
        if not texroot.empty? then
            sffxlst = suffixlist.join(',')
            begin
                report("locating '#{filename}' in document tree '#{texroot}/doc*'")
                if (result = Dir.glob("#{texroot}/doc*/**/#{filename}.{#{sffxlst}}")) && result && result[0] && FileTest.file?(result[0]) then
                    fullname = result[0]
                end
            rescue
                report("locating '#{filename}.#{suffix}' in tree '#{texroot}' aborted")
            end
        end
        return shortpathname(fullname) if register(filename,fullname)
    end
    report("aggressively locating '#{filename}' in tex trees")
    begin
        textrees = `kpsewhich -expand-var=$TEXMF`.chomp
    rescue
        textrees = ''
    end
    if not textrees.empty? then
        textrees.gsub!(/[\{\}\!]/, '')
        textrees = textrees.split(',')
        if (suffixlist.length == 1) && (suffixlist.first =~ /(#{$documentlist})/) then
            speedup = ['doc**','**']
        else
            speedup = ['**']
        end
        sffxlst = suffixlist.join(',')
        speedup.each do |speed|
            textrees.each do |tt|
                tt.gsub!(/[\\\/]$/, '')
                if FileTest.directory?(tt) then
                    begin
                        report("locating '#{filename}' in tree '#{tt}/#{speed}/#{filename}.{#{sffxlst}}'")
                        if (result = Dir.glob("#{tt}/#{speed}/#{filename}.{#{sffxlst}}")) && result && result[0] && FileTest.file?(result[0]) then
                            fullname = result[0]
                            break
                        end
                    rescue
                        report("locating '#{filename}' in tree '#{tt}' aborted")
                        next
                    end
                end
            end
            break if fullname && ! fullname.empty?
        end
    end
    if register(filename,fullname) then
        return shortpathname(fullname)
    else
        return ''
    end
end

def run(fullname)
    if ! fullname || fullname.empty? then
        report("the file '#{$filename}' is not found")
    elsif FileTest.file?(fullname) then
        begin
            case fullname
                when /\.(#{$scriptlist})$/ then
                    return runoneof($1,fullname,false)
                when /\.(#{$documentlist})$/ then
                    return runoneof($1,fullname,true)
                else
                    return runoneof('unknown',fullname,false)
            end
        rescue
            report("starting '#{$filename}' in program space '#{$program}' fails")
        end
    else
        report("the file '#{$filename}' in program space '#{$program}' is not accessible")
    end
    return false
end

def direct(fullname)
    begin
        return runcommand([fullname.sub(/^bin\:/, ''),expanded($arguments)].join(' '))
    rescue
        return false
    end
end

def make(filename,windows=false,linux=false)
    basename = filename.dup
    basename.sub!(/\.[^.]+?$/, '')
    basename.sub!(/^.*[\\\/]/, '')
    basename = $stubpath + '/' + basename unless $stubpath.empty?
    if basename == filename then
        report('nothing made')
    else
        program = nil
        if filename =~ /[\\\/]/ && filename =~ /\.(#{$scriptlist})$/ then
            program = $applications[$1]
        end
        filename = "\"#{filename}\"" if filename =~ /\s/
        program = 'texmfstart' if $indirect || ! program || program.empty?
        begin
            if windows && f = open(basename+'.bat','w') then
                f.binmode
                f.write("@echo off\015\012")
                f.write("#{program} #{filename} %*\015\012")
                f.close
                report("windows stub '#{basename}.bat' made")
            elsif linux && f = open(basename,'w') then
                f.binmode
                f.write("#!/bin/sh\012")
                f.write("#{program} #{filename} $@\012")
                f.close
                report("unix stub '#{basename}' made")
            end
        rescue
            report("failed to make stub '#{basename}'")
        else
            return true
        end
    end
    return false
end

$stdout.sync = true
$directives  = hashed(ARGV)

$help        = $directives['help']      || false
$filename    = $directives['file']      || ''
$program     = $directives['program']   || 'context'
$direct      = $directives['direct']    || false
$page        = $directives['page']      || 0
$browser     = $directives['browser']   || false
$report      = $directives['report']    || false
$verbose     = $directives['verbose']   || false
$arguments   = $directives['arguments'] || ''
$execute     = $directives['execute']   || $directives['exec'] || false

$make        = $directives['make']      || false
$unix        = $directives['unix']      || false
$windows     = $directives['windows']   || false
$stubpath    = $directives['stubpath']  || ''
$indirect    = $directives['indirect']  || false

$applications['unknown']  = ''
$applications['perl']     = $applications['pl']  = 'perl'
$applications['ruby']     = $applications['rb']  = 'ruby'
$applications['python']   = $applications['py']  = 'python'
$applications['java']     = $applications['jar'] = 'java'

if $mswindows then
    $applications['pdf']  = ['',"pdfopen --page #{$page} --file",'acroread']
    $applications['html'] = ['','netscape','mozilla','opera','iexplore']
    $applications['ps']   = ['','gview32','gv','gswin32','gs']
else
    $applications['pdf']  = ["pdfopen --page #{$page} --file",'acroread']
    $applications['html'] = ['netscape','mozilla','opera']
    $applications['ps']   = ['gview','gv','gs']
end

$applications['htm']      = $applications['html']
$applications['eps']      = $applications['ps']

if $help || ! $filename || $filename.empty? then
    usage
elsif $make then
    if $windows then
        make($filename,true,false)
    elsif $unix then
        make($filename,false,true)
    else
        make($filename,$mswindows,!$mswindows)
    end
elsif $browser && $filename =~ /^http\:\/\// then
    launch($filename)
elsif $direct || $filename =~ /^bin\:/ then
    direct($filename)
else
    run(find(shortpathname($filename),$program))
end

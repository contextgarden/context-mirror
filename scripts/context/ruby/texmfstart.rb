#!/usr/bin/env ruby

# program   : texmfstart
# copyright : PRAGMA Advanced Document Engineering
# version   : 1.5.5 - 2003/2005
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

# --locate        => provides location
# --exec          => exec instead of system
# --iftouched=a,b => only if timestamp a<>b
#
# file: path: bin:

# we don't depend on other libs

$ownpath = File.expand_path(File.dirname($0)) unless defined? $ownpath

require "rbconfig"

$mswindows = Config::CONFIG['host_os'] =~ /mswin/
$separator = File::PATH_SEPARATOR
$version   = "1.6.2"

if $mswindows then

    require "win32ole"
    require "Win32API"

end

exit if defined?(REQUIRE2LIB)

$stdout.sync = true
$stderr.sync = true

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
$predefined['ctxtools'] = 'ctxtools.rb'
$predefined['rlxtools'] = 'rlxtools.rb'
$predefined['pdftools'] = 'pdftools.rb'
$predefined['exatools'] = 'exatools.rb'
$predefined['xmltools'] = 'xmltools.rb'
$predefined['pstopdf']  = 'pstopdf.rb'

$scriptlist   = 'rb|pl|py|jar'
$documentlist = 'pdf|ps|eps|htm|html'

$crossover = true # to other tex tools, else only local

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

if $mswindows then

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

class File

    def File.needsupdate(oldname,newname)
        begin
            if $mswindows then
                return File.stat(oldname).mtime > File.stat(newname).mtime
            else
                return File.stat(oldname).mtime != File.stat(newname).mtime
            end
        rescue
            return true
        end
    end

    def File.syncmtimes(oldname,newname)
        begin
            if $mswindows then
                # does not work (yet)
            else
                t = File.mtime(oldname) # i'm not sure if the time is frozen, so we do it here
                File.utime(0,t,oldname,newname)
            end
        rescue
        end
    end

    def File.timestamp(name)
        begin
            "#{File.stat(name).mtime}"
        rescue
            return 'unknown'
        end
    end

end

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
        filename = filename.gsub(/\.[\/\\]/) do
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

def expanded(arg) # no "other text files", too restricted
    arg.gsub(/(env|environment)\:([a-zA-Z\-\_\.0-9]+)/o) do
        method, original, resolved = $1, $2, ''
        if resolved = ENV[original] then
            report("environment variable #{original} expands to #{resolved}") unless $report
            resolved
        else
            report("environment variable #{original} cannot be resolved") unless $report
            original
        end
    end . gsub(/(kpse|loc|file|path)\:([a-zA-Z\-\_\.0-9]+)/o) do # was: \S
        method, original, resolved = $1, $2, ''
        if $program && ! $program.empty? then
            pstrings = ["-progname=#{$program}"]
        else
            pstrings = ['','progname=context']
        end
        # auto suffix with texinputs as fall back
        if ENV["_CTX_K_V_#{original}_"] then
            resolved = ENV["_CTX_K_V_#{original}_"]
            report("environment provides #{original} as #{resolved}") unless $report
            resolved
        else
            pstrings.each do |pstr|
                if resolved.empty? then
                    command = "kpsewhich #{pstr} #{original}"
                    report("running #{command}")
                    begin
                        resolved = `#{command}`.chomp
                    rescue
                        resolved = ''
                    end
                end
                # elsewhere in the tree
                if resolved.empty? then
                    command = "kpsewhich #{pstr} -format=\"other text files\" #{original}"
                    report("running #{command}")
                    begin
                        resolved = `#{command}`.chomp
                    rescue
                        resolved = ''
                    end
                end
            end
            if resolved.empty? then
                original = File.dirname(original) if method =~ /path/
                report("#{original} is not resolved") unless $report
                ENV["_CTX_K_V_#{original}_"] = original if $crossover
                original
            else
                resolved = File.dirname(resolved) if method =~ /path/
                report("#{original} is resolved to #{resolved}") unless $report
                ENV["_CTX_K_V_#{original}_"] = resolved if $crossover
                resolved
            end
        end
    end
end

def runcommand(command)
    if $locate then
        command = command.split(' ').collect do |c|
            if c =~ /\//o then
                begin
                    cc = File.expand_path(c)
                    c = cc if FileTest.file?(cc)
                rescue
                end
            end
            c
        end . join(' ')
        print command # to stdout and no newline
    elsif $execute then
        report("using 'exec' instead of 'system' call: #{command}")
        begin
            Dir.chdir($path) if ! $path.empty?
        rescue
            report("unable to chdir to: #{$path}")
        end
        exec(command)
    else
        report("using 'system' call: #{command}")
        begin
            Dir.chdir($path) if ! $path.empty?
        rescue
            report("unable to chdir to: #{$path}")
        end
        system(command)
    end
end

def runoneof(application,fullname,browserpermitted)
    if browserpermitted && launch(fullname) then
        return true
    else
        report("starting #{$filename}") unless $report
        output("\n") if $report && $verbose
        applications = $applications[application]
        if applications.class == Array then
            if $report then
                output([fullname,expanded($arguments)].join(' '))
                return true
            else
                applications.each do |a|
                    return true if runcommand([a,fullname,expanded($arguments)].join(' '))
                end
            end
        elsif applications.empty? then
            if $report then
                output([fullname,expanded($arguments)].join(' '))
                return true
            else
                return runcommand([fullname,expanded($arguments)].join(' '))
            end
        else
            if $report then
                output([applications,fullname,expanded($arguments)].join(' '))
                return true
            else
                return runcommand([applications,fullname,expanded($arguments)].join(' '))
            end
        end
        return false
    end
end

def report(str)
    $stderr.puts(str) if $verbose
end

def output(str)
    $stderr.puts(str)
end

def usage
    print "version  : #{$version} - 2003/2004 - www.pragma-ade.com\n"
    print("\n")
    print("usage    : texmfstart [switches] filename [optional arguments]\n")
    print("\n")
    print("switches : --verbose --report --browser --direct --execute --locate\n")
    print("           --program --file   --page    --arguments\n")
    print("           --make    --lmake  --wmake\n")
    print("\n")
    print("example  : texmfstart pstopdf.rb cow.eps\n")
    print("           texmfstart --locate examplex.rb\n")
    print("           texmfstart --execute examplex.rb\n")
    print("           texmfstart --browser examplap.pdf\n")
    print("           texmfstart showcase.pdf\n")
    print("           texmfstart --page=2 --file=showcase.pdf\n")
    print("           texmfstart --program=yourtex yourscript.pl arg-1 arg-2\n")
    print("           texmfstart --direct xsltproc kpse:somefile.xsl somefile.xml\n")
    print("           texmfstart bin:xsltproc env:somepreset kpse:somefile.xsl somefile.xml\n")
    print("           texmfstart --iftouched=normal,lowres downsample.rb normal lowres\n")
end

# somehow registration does not work out (at least not under windows)

def registered?(filename)
    if $crossover then
        return ENV["_CTX_K_S_#{filename}_"] != nil
    else
        return ENV["TEXMFSTART.#{filename}"] != nil
    end
end

def registered(filename)
    if $crossover then
        return ENV["_CTX_K_S_#{filename}_"]
    else
        return ENV["TEXMFSTART.#{filename}"]
    end
end

def register(filename,fullname)
    if fullname && ! fullname.empty? then # && FileTest.file?(fullname)
        if $crossover then
            ENV["_CTX_K_S_#{filename}_"] = fullname
        else
            ENV["TEXMFSTART.#{filename}"] = fullname
        end
        return true
    else
        return false
    end
end

def find(filename,program)
    filename = filename.sub(/script:/o, '') # so we have bin: and script: and nothing
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
    # next we look at the current path and the callerpath
    [['.','current'],[$ownpath,'caller'],[registered("THREAD"),'thread']].each do |p|
        if p && ! p.empty? then
            suffixlist.each do |suffix|
                fname = "#{filename}.#{suffix}"
                fullname = File.expand_path(File.join(p[0],fname))
                report("locating '#{fname}' in #{p[1]} path '#{p[0]}'")
                if FileTest.file?(fullname) && register(filename,fullname) then
                    report("'#{fname}' located in #{p[1]} path")
                    return shortpathname(fullname)
                end
            end
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
    return shortpathname(fullname) if register(filename,fullname)
    # let's take a look at the path
    paths = ENV['PATH'].split($separator)
    suffixlist.each do |s|
        paths.each do |p|
            report("checking #{p} for suffix #{s}")
            if FileTest.file?(File.join(p,"#{filename}.#{s}")) then
                fullname = File.join(p,"#{filename}.#{s}")
                return  shortpathname(fullname) if register(filename,fullname)
            end
        end
    end
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
        return runcommand([fullname.sub(/^(bin|binary)\:/, ''),expanded($arguments)].join(' '))
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

def process(&block)

    if $iftouched then
        files = $directives['iftouched'].split(',')
        oldname, newname = files[0], files[1]
        if oldname && newname && File.needsupdate(oldname,newname) then
            report("file #{oldname}: #{File.timestamp(oldname)}")
            report("file #{newname}: #{File.timestamp(newname)}")
            report("file is touched, processing started")
            yield
            File.syncmtimes(oldname,newname)
        else
            report("file #{oldname} is untouched")
        end
    else
        yield
    end

end

def execute(arguments)

    arguments = arguments.split(/\s+/) if arguments.class == String

    $directives = hashed(arguments)

    $help        = $directives['help']      || false
    $batch       = $directives['batch']     || false
    $filename    = $directives['file']      || ''
    $program     = $directives['program']   || 'context'
    $direct      = $directives['direct']    || false
    $page        = $directives['page']      || 0
    $browser     = $directives['browser']   || false
    $report      = $directives['report']    || false
    $verbose     = $directives['verbose']   || (ENV['_CTX_VERBOSE_'] =~ /(y|yes|t|true|on)/io) || false
    $arguments   = $directives['arguments'] || ''
    $execute     = $directives['execute']   || $directives['exec'] || false
    $locate      = $directives['locate']    || false

    $path        = $directives['path']      || ''

    $make        = $directives['make']      || false
    $unix        = $directives['unix']      || false
    $windows     = $directives['windows']   || false
    $stubpath    = $directives['stubpath']  || ''
    $indirect    = $directives['indirect']  || false

    $before      = $directives['before']    || ''
    $after       = $directives['after']     || ''

    $iftouched   = $directives['iftouched'] || false

    $openoffice  = $directives['oo']        || false

    $crossover   = false if $directives['clear']

    ENV['_CTX_VERBOSE_'] = 'yes' if $verbose

    if $openoffice then
        if ENV['OOPATH'] then
            if FileTest.directory?(ENV['OOPATH']) then
                report("using open office python")
                if $mswindows then
                    $applications['python'] = $applications['py']  = "\"#{File.join(ENV['OOPATH'],'program','python.bat')}\""
                else
                    $applications['python'] = $applications['py']  = File.join(ENV['OOPATH'],'python')
                end
                report("python path #{$applications['python']}")
            else
                report("environment variable 'OOPATH' does not exist")
            end
        else
            report("environment variable 'OOPATH' is not set")
        end
    end

    if $help || ! $filename || $filename.empty? then
        usage
    elsif $batch && $filename && ! $filename.empty? then
        # todo, take commands from file and avoid multiple starts and checks
    else
        report("texmfstart version #{$version}")
        if $make then
            if $windows then
                make($filename,true,false)
            elsif $unix then
                make($filename,false,true)
            else
                make($filename,$mswindows,!$mswindows)
            end
        elsif $browser && $filename =~ /^http\:\/\// then
            launch($filename)
        else
            begin
                process do
                    if $direct || $filename =~ /^bin\:/ then
                        direct($filename)
                    else # script: or no prefix
                        command = find(shortpathname($filename),$program)
                        register("THREAD",File.dirname(command))
                        run(command)
                    end
                end
            rescue
                report('fatal error in starting process')
            end
        end
    end

end

execute(ARGV)

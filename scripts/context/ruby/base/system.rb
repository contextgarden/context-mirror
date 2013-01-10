# module    : base/system
# copyright : PRAGMA Advanced Document Engineering
# version   : 2002-2005
# author    : Hans Hagen
#
# project   : ConTeXt / eXaMpLe
# concept   : Hans Hagen
# info      : j.hagen@xs4all.nl
# www       : www.pragma-ade.com

require "rbconfig"

module System

    @@mswindows   = RbConfig::CONFIG['host_os'] =~ /mswin/
    @@binpaths    = ENV['PATH'].split(File::PATH_SEPARATOR)
    @@binsuffixes = if $mswindows then ['.exe','.com','.bat'] else ['','.sh','.csh'] end
    @@located     = Hash.new
    @@binnames    = Hash.new

    if @@mswindows then
        @@binnames['ghostscript'] = ['gswin32c.exe','gs.cmd','gs.bat']
        @@binnames['imagemagick'] = ['imagemagick.exe','convert.exe']
        @@binnames['inkscape']    = ['inkscape.exe']
    else
        @@binnames['ghostscript'] = ['gs']
        @@binnames['imagemagick'] = ['convert']
        @@binnames['inkscape']    = ['inkscape']
    end


    def System.null
        if @@mswindows then 'nul' else '/dev/null' end
    end

    def System.unix?
        not @@mswindows
    end
    def System.mswin?
        @@mswindows
    end

    def System.binnames(str)
        if @@binnames.key?(str) then
            @@binnames[str]
        else
            [str]
        end
    end

    def System.prependengine(str)
        if str =~ /^\S+\.(pl|rb|lua|py)/io then
            case $1
                when 'pl'  then return "perl #{str}"
                when 'rb'  then return "ruby #{str}"
                when 'lua' then return "lua #{str}"
                when 'py'  then return "python #{str}"
            end
        end
        return str
    end

    def System.locatedprogram(program)
        if @@located.key?(program) then
            return @@located[program]
        else
            System.binnames(program).each do |binname|
                if binname =~ /\..*$/io then
                    @@binpaths.each do |path|
                        if FileTest.file?(str = File.join(path,binname)) then
                            return @@located[program] = System.prependengine(str)
                        end
                    end
                end
                binname.gsub!(/\..*$/io, '')
                @@binpaths.each do |path|
                    @@binsuffixes.each do |suffix|
                        if FileTest.file?(str = File.join(path,"#{binname}#{suffix}")) then
                            return @@located[program] = System.prependengine(str)
                        end
                    end
                end
            end
        end
        return @@located[program] = "texmfstart #{program}"
    end

    def System.command(program,arguments='')
        if program =~ /^(.*?) (.*)$/ then
            program = System.locatedprogram($1) + ' ' + $2
        else
            program = System.locatedprogram(program)
        end
        program = program + ' ' + arguments if ! arguments.empty?
        program.gsub!(/\s+/io, ' ')
        #program.gsub!(/(\/\.\/)+/io, '/')
        program.gsub!(/\\/io, '/')
        return program
    end

    def System.run(program,arguments='',pipe=false,collect=false)
        if pipe then
            if collect then
                `#{System.command(program,arguments)} 2>&1`
            else
                `#{System.command(program,arguments)}`
            end
        else
            system(System.command(program,arguments))
        end
    end

    def System.pipe(program,arguments='',collect=false)
        System.run(program,arguments,true)
    end

    def System.safepath(path)
        if path.match(/ /o) then "\"#{path}\"" else path end
    end

end

# module    : base/kpse
# copyright : PRAGMA Advanced Document Engineering
# version   : 2002-2005
# author    : Hans Hagen
#
# project   : ConTeXt / eXaMpLe
# concept   : Hans Hagen
# info      : j.hagen@xs4all.nl
# www       : www.pragma-ade.com

# rename this one to environment
#
# todo: web2c vs miktex module and include in kpse

require 'rbconfig'

# beware $engine is lowercase in kpse
#
# miktex has mem|fmt|base paths

module Kpse

    @@located       = Hash.new
    @@paths         = Hash.new
    @@scripts       = Hash.new
    @@formats       = ['tex','texmfscripts','other text files']
    @@progname      = 'context'
    @@ownpath       = $0.sub(/[\\\/][a-z0-9\-]*?\.rb/i,'')
    @@problems      = false
    @@tracing       = false
    @@distribution  = 'web2c'
    @@crossover     = true
    @@mswindows     = Config::CONFIG['host_os'] =~ /mswin/

    @@distribution  = 'miktex' if ENV['PATH'] =~ /miktex[\\\/]bin/o

    @@usekpserunner = false || ENV['KPSEFAST'] == 'yes'

    require 'base/tool' if @@usekpserunner

    if @@crossover then
        ENV.keys.each do |k|
            case k
                when /\_CTX\_KPSE\_V\_(.*?)\_/io then @@located[$1] = ENV[k].dup
                when /\_CTX\_KPSE\_P\_(.*?)\_/io then @@paths  [$1] = ENV[k].dup.split(';')
                when /\_CTX\_KPSE\_S\_(.*?)\_/io then @@scripts[$1] = ENV[k].dup
            end
        end
    end

    def Kpse.distribution
        @@distribution
    end

    def Kpse.miktex?
        @@distribution == 'miktex'
    end

    def Kpse.web2c?
        @@distribution == 'web2c'
    end

    def Kpse.inspect
        @@located.keys.sort.each do |k| puts("located : #{k} -> #{@@located[k]}\n") end
        @@paths  .keys.sort.each do |k| puts("paths   : #{k} -> #{@@paths  [k]}\n") end
        @@scripts.keys.sort.each do |k| puts("scripts : #{k} -> #{@@scripts[k]}\n") end
    end

    def Kpse.found(filename, progname=nil, format=nil)
        begin
            tag = Kpse.key(filename) # all
            if @@located.key?(tag) then
                return @@located[tag]
            elsif FileTest.file?(filename) then
                setvariable(tag,filename)
                return filename
            elsif FileTest.file?(File.join(@@ownpath,filename)) then
                setvariable(tag,File.join(@@ownpath,filename))
                return @@located[tag]
            else
                [progname,@@progname].flatten.compact.uniq.each do |prg|
                    [format,@@formats].flatten.compact.uniq.each do |fmt|
                        begin
                            tag = Kpse.key(filename,prg,fmt)
                            if @@located.key?(tag) then
                                return @@located[tag]
                            elsif p = Kpse.kpsewhich(filename,prg,fmt) then
                                setvariable(tag,p.chomp)
                                return @@located[tag]
                            end
                        rescue
                        end
                    end
                end
                setvariable(tag,filename)
                return filename
            end
        rescue
            filename
        end
    end

    def Kpse.kpsewhich(filename,progname,format)
        Kpse.run("-progname=#{progname} -format=\"#{format}\" #{filename}")
    end

    def Kpse.which
        Kpse.kpsewhich
    end

    def Kpse.run(arguments)
        puts arguments if @@tracing
        begin
            if @@problems then
                results = ''
            else
                if @@usekpserunner then
                    results = KpseRunner.kpsewhich(arguments).chomp
                else
                    results = `kpsewhich #{arguments}`.chomp
                end
            end
        rescue
            puts "unable to run kpsewhich" if @@tracing
            @@problems, results = true, ''
        end
        puts results if @@tracing
        return results
    end

    def Kpse.formatpaths
        # maybe we should check for writeability
        unless @@paths.key?('formatpaths') then
            begin
                setpath('formatpaths',run("--show-path=fmt").gsub(/\\/,'/').split(File::PATH_SEPARATOR))
            rescue
                setpath('formatpaths',[])
            end
        end
        return @@paths['formatpaths']
    end

    def Kpse.key(filename='',progname='all',format='all')
        [progname,format,filename].join('-')
    end

    def Kpse.formatpath(engine='pdfetex',enginepath=true)

        # because engine support in distributions is not always
        # as we expect, we need to check for it;

        # todo: miktex

        if miktex? then
            return '.'
        else
            unless @@paths.key?(engine) then
                # savedengine = ENV['engine']
                if ENV['TEXFORMATS'] && ! ENV['TEXFORMATS'].empty? then
                    # make sure that we have a lowercase entry
                    ENV['TEXFORMATS'] = ENV['TEXFORMATS'].sub(/\$engine/io,"\$engine")
                    # well, we will append anyway, so we could also strip it
                    # ENV['TEXFORMATS'] = ENV['TEXFORMATS'].sub(/\$engine/io,"")
                end
                # use modern method
                if enginepath then
                    formatpath = run("--engine=#{engine} --show-path=fmt")
                else
                    # ENV['engine'] = engine if engine
                    formatpath = run("--show-path=fmt")
                end
                # use ancient method
                if formatpath.empty? then
                    if enginepath then
                        if @@mswindows then
                            formatpath = run("--engine=#{engine} --expand-path=\$TEXFORMATS")
                        else
                            formatpath = run("--engine=#{engine} --expand-path=\\\$TEXFORMATS")
                        end
                    end
                    # either no enginepath or failed run
                    if formatpath.empty? then
                        if @@mswindows then
                            formatpath = run("--expand-path=\$TEXFORMATS")
                        else
                            formatpath = run("--expand-path=\\\$TEXFORMATS")
                        end
                    end
                end
                # locate writable path
                if ! formatpath.empty? then
                    formatpath.split(File::PATH_SEPARATOR).each do |fp|
                        fp.gsub!(/\\/,'/')
                        # remove funny patterns
                        fp.sub!(/^!!/,'')
                        fp.sub!(/\/+$/,'')
                        fp.sub!(/unsetengine/,if enginepath then engine else '' end)
                        if ! fp.empty? && (fp != '.') then
                            # strip (possible engine) and test for writeability
                            fpp = fp.sub(/#{engine}\/*$/,'')
                            if FileTest.directory?(fpp) && FileTest.writable?(fpp) then
                                # use this path
                                formatpath = fp.dup
                                break
                            end
                        end
                    end
                end
                # needed !
                begin File.makedirs(formatpath) ; rescue ; end ;
                # fall back to current path
                formatpath = '.' if formatpath.empty? || ! FileTest.writable?(formatpath)
                # append engine but prevent duplicates
                formatpath = File.join(formatpath.sub(/\/*#{engine}\/*$/,''), engine) if enginepath
                begin File.makedirs(formatpath) ; rescue ; end ;
                setpath(engine,formatpath)
                # ENV['engine'] = savedengine
            end
            return @@paths[engine].first
        end
    end

    def Kpse.update
        system('initexmf -u') if Kpse.miktex?
        system('mktexlsr')
    end

    # engine support is either broken of not implemented in some
    # distributions, so we need to take care of it ourselves (without
    # delays due to kpse calls); there can be many paths in the string
    #
    # in a year or so, i will drop this check

    def Kpse.fixtexmfvars(engine=nil)
        ENV['ENGINE'] = engine if engine
        texformats = if ENV['TEXFORMATS'] then ENV['TEXFORMATS'].dup else '' end
        if texformats.empty? then
            if engine then
                if @@mswindows then
                    texformats = `kpsewhich --engine=#{engine} --expand-var=\$TEXFORMATS`.chomp
                else
                    texformats = `kpsewhich --engine=#{engine} --expand-var=\\\$TEXFORMATS`.chomp
                end
            else
                if @@mswindows then
                    texformats = `kpsewhich --expand-var=\$TEXFORMATS`.chomp
                else
                    texformats = `kpsewhich --expand-var=\\\$TEXFORMATS`.chomp
                end
            end
        end
        if engine then
            texformats.sub!(/unsetengine/,engine)
        else
            texformats.sub!(/unsetengine/,"\$engine")
        end
        if engine && (texformats =~ /web2c[\/\\].*#{engine}/o) then
            # ok, engine is seen
            return false
        elsif texformats =~ /web2c[\/\\].*\$engine/io then
            # shouldn't happen
            return false
        else
            ENV['TEXFORMATS'] = texformats.gsub(/(web2c\/\{)(,\})/o) do
                "#{$1}\$engine#{$2}"
            end
            if texformats !~ /web2c[\/\\].*\$engine/io then
                ENV['TEXFORMATS'] = texformats.gsub(/web2c\/*/, "web2c/{\$engine,}")
            end
            return true
        end
    end

    def Kpse.runscript(name,filename=[],options=[])
        setscript(name,`texmfstart --locate #{name}`) unless @@scripts.key?(name)
        cmd = "#{@@scripts[name]} #{[options].flatten.join(' ')} #{[filename].flatten.join(' ')}"
        system(cmd)
    end

    def Kpse.pipescript(name,filename=[],options=[])
        setscript(name,`texmfstart --locate #{name}`) unless @@scripts.key?(name)
        cmd = "#{@@scripts[name]} #{[options].flatten.join(' ')} #{[filename].flatten.join(' ')}"
        `#{cmd}`
    end

    private

    def Kpse.setvariable(key,value)
        @@located[key] = value
        ENV["_CTX_K_V_#{key}_"] = @@located[key] if @@crossover
    end

    def Kpse.setscript(key,value)
        @@scripts[key] = value
        ENV["_CTX_K_S_#{key}_"] = @@scripts[key] if @@crossover
    end

    def Kpse.setpath(key,value)
        @@paths[key] = [value].flatten.uniq.collect do |p|
            p.sub(/^!!/,'').sub(/\/*$/,'')
        end
        ENV["_CTX_K_P_#{key}_"] = @@paths[key].join(';') if @@crossover
    end

end

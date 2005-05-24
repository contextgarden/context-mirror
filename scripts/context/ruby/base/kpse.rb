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

module Kpse

    @@located      = Hash.new
    @@paths        = Hash.new
    @@scripts      = Hash.new
    @@formats      = ['tex','texmfscripts','other text files']
    @@progname     = 'context'
    @@ownpath      = $0.sub(/[\\\/][a-z0-9\-]*?\.rb/i,'')
    @@problems     = false
    @@tracing      = false
    @@distribution = 'web2c'
    @@crossover    = true
    @@mswindows    = Config::CONFIG['host_os'] =~ /mswin/

    # check first in bin path

    ENV['PATH'].split(File::PATH_SEPARATOR).each do |path|
        @@distribution = 'miktex' if path =~ /miktex/o
    end

    # if @@crossover then
        # ENV.keys.each do |k|
            # case k
                # when /\_CTX\_KPSE\_V\_(.*?)\_/io then @@located[$1] = ENV[k].dup
                # when /\_CTX\_KPSE\_P\_(.*?)\_/io then @@paths  [$1] = ENV[k].dup.split(';')
                # when /\_CTX\_KPSE\_S\_(.*?)\_/io then @@scripts[$1] = ENV[k].dup
            # end
        # end
    # end

    if @@crossover then
        ENV.keys.each do |k|
            case k
                when /\_CTX\_KPSE\_V\_(.*?)\_/io then @@located[$1] = ENV[k].dup
                when /\_CTX\_KPSE\_P\_(.*?)\_/io then @@paths  [$1] = ENV[k].dup.split(';')
                when /\_CTX\_KPSE\_S\_(.*?)\_/io then @@scripts[$1] = ENV[k].dup
            end
        end
    end

    def Kpse.inspect
        @@located.keys.sort.each do |k| puts("located : #{k} -> #{@@located[k]}\n") end
        @@paths  .keys.sort.each do |k| puts("paths   : #{k} -> #{@@paths  [k]}\n") end
        @@scripts.keys.sort.each do |k| puts("scripts : #{k} -> #{@@scripts[k]}\n") end
    end

    def Kpse.distribution
        @@distribution
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
        Kpse.Kpsewhich
    end

    def Kpse.run(arguments)
        puts arguments if @@tracing
        begin
            if @@problems then
                results = ''
            else
                results = `kpsewhich #{arguments}`.chomp
            end
        rescue
            puts "unable to run kpsewhich" if @@tracing
            @@problems, results = true, ''
        end
        puts results if @@tracing
        return results
    end

    def Kpse.formatpaths
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

        unless @@paths.key?(engine) then
            # overcome a bug/error in web2c/distributions/kpse
            if ENV['TEXFORMATS'] then
                ENV['TEXFORMATS'] = ENV['TEXFORMATS'].sub(/\$ENGINE/io,'')
            end
            # use modern method
            if enginepath then
                formatpath = run("--engine=#{engine} --show-path=fmt")
            else
                formatpath = run("--show-path=fmt")
            end
            # use ancient method
            if formatpath.empty? then
                if enginepath then
                    if @@mswindows then
                        formatpath = run("--engine=#{engine} --expand-var=\$TEXFORMATS")
                    else
                        formatpath = run("--engine=#{engine} --expand-var=\\\$TEXFORMATS")
                    end
                else
                    if enginepath then
                        formatpath = run("--expand-var=\$TEXFORMATS")
                    else
                        formatpath = run("--expand-var=\\\$TEXFORMATS")
                    end
                end
            end
            # overcome a bug/error in web2c/distributions/kpse
            formatpath.sub!(/unsetengine/, engine)
            # take first one
            if ! formatpath.empty? then
                formatpath = formatpath.split(File::PATH_SEPARATOR).first
                # remove clever things
                formatpath.gsub!(/[\!\{\}\,]/, '')
                unless formatpath.empty? then
                    if enginepath then
                        newformatpath = File.join(formatpath,engine).gsub(/[\/\\]+/, '/')
                        if FileTest.directory?(newformatpath) then
                            formatpath = newformatpath
                        else
                            begin
                                File.makedirs(newformatpath)
                            rescue
                            else
                                formatpath = newformatpath if FileTest.directory?(newformatpath)
                            end
                        end
                    else
                        formatpath = formatpath.gsub(/[\/\\]+/, '/').gsub(/\/$/, '')
                    end
                end
            end
            setpath(engine,formatpath)
        end
        return @@paths[engine]
    end

    def Kpse.update
        case @@distribution
            when 'miktex' then
                system('initexmf --update-fndb')
            else
                # always mktexlsr anyway

        end
        system('mktexlsr')
    end

    def Kpse.distribution
        ENV['PATH'].split(File::PATH_SEPARATOR).each do |path|
            if path =~ /miktex/ then
                return 'miktex'
            end
        end
        return 'web2c'
    end

    def Kpse.miktex?
        distribution == 'miktex'
    end

    def Kpse.web2c?
        distribution == 'web2c'
    end

    # engine support is either broken of not implemented in some
    # distributions, so we need to take care of it ourselves

    def Kpse.fixtexmfvars(engine=nil)
        ENV['ENGINE'] = engine if engine
        texformats = if ENV['TEXFORMATS'] then ENV['TEXFORMATS'].dup else '' end
        if @@mswindows then
            texformats = `kpsewhich --expand-var=\$TEXFORMATS`.chomp if texformats.empty?
        else
            texformats = `kpsewhich --expand-var=\\\$TEXFORMATS`.chomp if texformats.empty?
        end
        if texformats !~ /web2c[\/\\].*\$ENGINE/ then
            ENV['TEXFORMATS'] = texformats.gsub(/web2c/, "web2c/{\$ENGINE,}")
            return true
        else
            return false
        end

    end

    def Kpse.runscript(name,filename=[],options=[])
        setscript(name,`texmfstart --locate #{name}`) unless @@scripts.key?(name)
        system("#{@@scripts[name]} #{[options].flatten.join(' ')} #{[filename].flatten.join(' ')}")
    end

    def Kpse.pipescript(name,filename=[],options=[])
        setscript(name,`texmfstart --locate #{name}`) unless @@scripts.key?(name)
        `#{@@scripts[name]} #{[options].flatten.join(' ')} #{[filename].flatten.join(' ')}`
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
        @@paths[key] = [value].flatten.uniq
        ENV["_CTX_K_P_#{key}_"] = @@paths[key].join(';') if @@crossover
    end

end

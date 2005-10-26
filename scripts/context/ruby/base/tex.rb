# module    : base/tex
# copyright : PRAGMA Advanced Document Engineering
# version   : 2005
# author    : Hans Hagen
#
# project   : ConTeXt / eXaMpLe
# concept   : Hans Hagen
# info      : j.hagen@xs4all.nl
# www       : www.pragma-ade.com

# todo: write systemcall for mpost to file so that it can be run
# faster

# report ?

require 'base/variables'
require 'base/kpse'
require 'base/system'
require 'base/state'
require 'base/pdf'
require 'base/file'
require 'base/ctx'

class String

    def standard?
        begin
            self == 'standard'
        rescue
            false
        end
    end

end

class Array

    def standard?
        begin
            self.include?('standard')
        rescue
            false
        end
    end

end

class TEX

    # The make-part of this class was made on a rainy day while listening
    # to "10.000 clowns on a rainy day" by Jan Akkerman. Unfortunately the
    # make method is not as swinging as this live cd.

    include Variables

    @@texengines = Hash.new
    @@mpsengines = Hash.new
    @@backends   = Hash.new
    @@runoptions = Hash.new
    @@texformats = Hash.new
    @@mpsformats = Hash.new
    @@prognames  = Hash.new
    @@texmakestr = Hash.new
    @@texprocstr = Hash.new
    @@mpsmakestr = Hash.new
    @@mpsprocstr = Hash.new

    @@texmethods = Hash.new
    @@mpsmethods = Hash.new

    ['tex','pdftex','pdfetex','standard']          .each do |e| @@texengines[e] = 'pdfetex'   end
    ['aleph','omega']                              .each do |e| @@texengines[e] = 'aleph'     end
    ['xetex']                                      .each do |e| @@texengines[e] = 'xetex'     end

    ['metapost','mpost','standard']                .each do |e| @@mpsengines[e] = 'mpost'     end

    ['pdfetex','pdftex','pdf','pdftex','standard'] .each do |b| @@backends[b]   = 'pdftex'    end
    ['dvipdfmx','dvipdfm','dpx','dpm']             .each do |b| @@backends[b]   = 'dvipdfmx'  end
    ['xetex','xtx']                                .each do |b| @@backends[b]   = 'xetex'     end
    ['dvips','ps']                                 .each do |b| @@backends[b]   = 'dvips'     end
    ['dvipsone']                                   .each do |b| @@backends[b]   = 'dvipsone'  end
    ['acrobat','adobe','distiller']                .each do |b| @@backends[b]   = 'acrobat'   end

    # todo norwegian (no)

    ['plain']                                      .each do |f| @@texformats[f] = 'plain'     end
    ['cont-en','en','english','context','standard'].each do |f| @@texformats[f] = 'cont-en'   end
    ['cont-nl','nl','dutch']                       .each do |f| @@texformats[f] = 'cont-nl'   end
    ['cont-de','de','german']                      .each do |f| @@texformats[f] = 'cont-de'   end
    ['cont-it','it','italian']                     .each do |f| @@texformats[f] = 'cont-it'   end
    ['cont-cz','cz','czech']                       .each do |f| @@texformats[f] = 'cont-cz'   end
    ['cont-ro','ro','romanian']                    .each do |f| @@texformats[f] = 'cont-ro'   end
    ['cont-uk','uk','brittish']                    .each do |f| @@texformats[f] = 'cont-uk'   end
    ['mptopdf']                                    .each do |f| @@texformats[f] = 'mptopdf'   end

    ['latex']                                      .each do |f| @@texformats[f] = 'latex.ltx' end

    ['plain','mpost']                              .each do |f| @@mpsformats[f] = 'plain'     end
    ['metafun','context','standard']               .each do |f| @@mpsformats[f] = 'metafun'   end

    ['pdfetex','aleph','omega']                    .each do |p| @@prognames[p]  = 'context'   end
    ['mpost']                                      .each do |p| @@prognames[p]  = 'metafun'   end

    ['plain','default','standard','mptopdf']       .each do |f| @@texmethods[f] = 'plain'     end
    ['cont-en','cont-nl','cont-de','cont-it',
     'cont-cz','cont-ro','cont-uk']                .each do |f| @@texmethods[f] = 'context'   end
    ['latex']                                      .each do |f| @@texmethods[f] = 'latex'     end

    ['plain','default','standard']                 .each do |f| @@mpsmethods[f] = 'plain'     end
    ['metafun']                                    .each do |f| @@mpsmethods[f] = 'metafun'   end

    @@texmakestr['plain'] = "\\dump"
    @@mpsmakestr['plain'] = "\\dump"

    ['cont-en','cont-nl','cont-de','cont-it',
     'cont-cz','cont-ro','cont-uk']                .each do |f| @@texprocstr[f] = "\\emergencyend"  end

    @@runoptions['xetex'] = ['--no-pdf']

    @@booleanvars = [
        'batchmode', 'nonstopmode', 'fast', 'fastdisabled', 'silentmode', 'final',
        'paranoid', 'notparanoid', 'nobanner', 'once', 'allpatterns',
        'nompmode', 'nomprun', 'automprun',
        'nomapfiles', 'local',
        'arrange', 'noarrange',
        'forcexml', 'foxet',
        'mpyforce', 'forcempy',
        'forcetexutil', 'texutil',
        'globalfile', 'autopath',
        'purge', 'purgeall', 'autopdf', 'simplerun', 'verbose',
        'nooptionfile'
    ]
    @@stringvars = [
        'modefile', 'result', 'suffix', 'response', 'path',
        'filters', 'usemodules', 'environments', 'separation', 'setuppath',
        'arguments', 'input', 'output', 'randomseed', 'modes', 'filename',
        'modefile', 'ctxfile'
    ]
    @@standardvars = [
        'mainlanguage', 'bodyfont', 'language'
    ]
    @@knownvars = [
        'engine', 'distribution', 'texformats', 'mpsformats', 'progname', 'interface',
        'runs', 'backend'
    ]

    @@extrabooleanvars = []
    @@extrastringvars = []

    def booleanvars
        [@@booleanvars,@@extrabooleanvars].flatten
    end
    def stringvars
        [@@stringvars,@@extrastringvars].flatten
    end
    def standardvars
        @@standardvars
    end
    def knownvars
        @@knownvars
    end

    def setextrastringvars(vars)
        @@extrastringvars << vars
    end
    def setextrabooleanvars(vars)
        @@extrabooleanvars << vars
    end

    @@temprunfile = 'texexec'
    @@temptexfile = 'texexec.tex'

    def initialize(logger=nil)
        if @logger = logger then
            def report(str='')
                @logger.report(str)
            end
        else
            def report(str='')
                puts(str)
            end
        end
        @cleanups    = Array.new
        @variables   = Hash.new
        @startuptime = Time.now
        # options
        booleanvars.each do |k|
            setvariable(k,false)
        end
        stringvars.each do |k|
            setvariable(k,'')
        end
        standardvars.each do |k|
            setvariable(k,'standard')
        end
        setvariable('distribution', Kpse.distribution)
        setvariable('texformats',   defaulttexformats)
        setvariable('mpsformats',   defaultmpsformats)
        setvariable('progname',     'context')
        setvariable('interface',    'standard')
        setvariable('engine',       'standard') # replaced by tex/mpsengine
        setvariable('backend',      'pdftex')
        setvariable('runs',         '8')
        setvariable('randomseed',    rand(1440).to_s)
        # files
        setvariable('files',        [])
        # defaults
        setvariable('texengine',    'standard')
        setvariable('mpsengine',    'standard')
        setvariable('backend',      'standard')
    end

    def runtime
        Time.now - @startuptime
    end

    def reportruntime
        report("runtime: #{runtime}")
    end

    def inspect(name=nil)
        if ! name || name.empty? then
            name = [booleanvars,stringvars,standardvars,knownvars]
        end
        [name].flatten.each do |n|
            if str = getvariable(n) then
                unless (str.class == String) && str.empty? then
                    report("option '#{n}' is set to '#{str}'")
                end
            end
        end
    end

    def tempfilename(suffix='')
        @@temprunfile + if suffix.empty? then '' else ".#{suffix}" end
    end

    def cleanup
        @cleanups.each do |name|
            begin
                File.delete(name) if FileTest.file?(name)
            rescue
                report("unable to delete #{name}")
            end
        end
    end

    def cleanuptemprunfiles
        begin
            Dir.glob("#{@@temprunfile}*").each do |name|
                if File.file?(name) && (File.splitname(name)[1] !~ /(pdf|dvi)/o) then
                    begin File.delete(name) ; rescue ; end
                end
            end
        rescue
        end
    end

    def backends() @@backends.keys.sort end

    def texengines() @@texengines.keys.sort end
    def mpsengines() @@mpsengines.keys.sort end
    def texformats() @@texformats.keys.sort end
    def mpsformats() @@mpsformats.keys.sort end

    def defaulttexformats() ['en','nl','mptopdf'] end
    def defaultmpsformats() ['metafun']           end

    def texmakeextras(format) @@texmakestr[format] || '' end
    def mpsmakeextras(format) @@mpsmakestr[format] || '' end
    def texprocextras(format) @@texprocstr[format] || '' end
    def mpsprocextras(format) @@mpsprocstr[format] || '' end

    def texmethod(format) @@texmethods[str] || @@texmethods['standard'] end
    def mpsmethod(format) @@mpsmethods[str] || @@mpsmethods['standard'] end

    def runoptions(engine)
        if @@runoptions.key?(engine) then @@runoptions[engine].join(' ') else '' end
    end

    # private

    def cleanuplater(name)
        begin
            @cleanups.push(File.expand_path(name))
        rescue
            @cleanups.push(name)
        end
    end

    def openedfile(name)
        begin
            f = File.open(name,'w')
        rescue
            report("file '#{File.expand_path(name)}' cannot be opened for writing")
            return nil
        else
            cleanuplater(name) if f
            return f
        end
    end

    def prefixed(format,engine)
        case engine
            when /etex|eetex|pdfetex|pdfeetex|pdfxtex|xpdfetex|eomega|aleph|xetex/io then
                "*#{format}"
            else
                format
        end
    end

    def quoted(str)
        if str =~ /^[^\"].* / then "\"#{str}\"" else str end
    end

    def getarrayvariable(str='')
        str = getvariable(str)
        if str.class == String then str.split(',') else str.flatten end
    end

    def validtexformat(str) validsomething(str,@@texformats) end
    def validmpsformat(str) validsomething(str,@@mpsformats) end
    def validtexengine(str) validsomething(str,@@texengines) end
    def validmpsengine(str) validsomething(str,@@mpsengines) end

    def validtexmethod(str) [validsomething(str,@@texmethods)].flatten.first end
    def validmpsmethod(str) [validsomething(str,@@mpsmethods)].flatten.first end

    def validsomething(str,something)
        if str then
            list = [str].flatten.collect do |s|
                something[s]
            end .compact.uniq
            if list.length>0 then
                if str.class == String then list.first else list end
            else
                false
            end
        else
            false
        end
    end

    def validbackend(str)
        if str && @@backends.key?(str) then
            @@backends[str]
        else
            @@backends['standard']
        end
    end

    def validprogname(str,engine='standard')
        if str && @@prognames.key?(str) then
            @@prognames[str]
        elsif (engine != 'standard') && @@prognames.key?(engine) then
            @@prognames[engine]
        else
            str
        end
    end

    # we no longer support the & syntax

    def formatflag(engine=nil,format=nil)
        case getvariable('distribution')
            when 'standard' then prefix = "--fmt"
            when /web2c/io  then prefix = web2cformatflag(engine)
            when /miktex/io then prefix = "--undump"
                            else return ""
        end
        if format then
            # if engine then
                # "#{prefix}=#{engine}/#{format}"
            # else
                "#{prefix}=#{format}"
            # end
        else
            prefix
        end
    end

    def web2cformatflag(engine=nil)
        # funny that we've standardized on the fmt suffix (at the cost of
        # upward compatibility problems) but stuck to the bas/mem/fmt flags
        if engine then
            case validmpsengine(engine)
                when /mpost/ then "--mem"
                when /mfont/ then "--bas"
                else              "--fmt"
            end
        else
            "--fmt"
        end
    end

    def prognameflag(progname=nil)
        case getvariable('distribution')
            when 'standard' then prefix = "--progname"
            when /web2c/io  then prefix = "--progname"
            when /miktex/io then prefix = "--alias"
                            else return ""
        end
        if progname then
            if progname = validprogname(progname) then
                "#{prefix}=#{progname}"
            else
                ""
            end
        else
            prefix
        end
    end

    def iniflag() # should go to kpse and kpse should become texenv
        if Kpse.miktex? then
            "-initialize"
        else
            "--ini"
        end
    end
    def tcxflag(file="natural.tcx")
        if Kpse.miktex? then
            "-tcx=#{file}"
        else
            "--translate-file=#{file}"
        end
    end

    def filestate(file)
        File.mtime(file).strftime("%d/%m/%Y %H:%M:%S")
    end

    # will go to context/process context/listing etc

    def contextversion # ook elders gebruiken
        filename = Kpse.found('context.tex')
        version = 'unknown'
        begin
            if FileTest.file?(filename) && IO.read(filename).match(/\\contextversion\{(\d+\.\d+\.\d+)\}/) then
                version = $1
            end
        rescue
        end
        return version
    end

    def makeformats
        if getvariable('fast') then
            report('using existing database')
        else
            report('updating file database')
            Kpse.update
        end
        # goody
        if getvariable('texformats') == 'standard' then
            setvariable('texformats',[getvariable('interface')]) unless getvariable('interface').empty?
        end
        # prepare
        texformats = validtexformat(getarrayvariable('texformats'))
        mpsformats = validmpsformat(getarrayvariable('mpsformats'))
        texengine  = validtexengine(getvariable('texengine'))
        mpsengine  = validmpsengine(getvariable('mpsengine'))
        # save current path
        savedpath = Dir.getwd
        # generate tex formats
        if texformats && texengine && (progname = validprogname(getvariable('progname'),texengine)) then
            report("using tex engine #{texengine}")
            texformatpath = if getvariable('local') then '.' else Kpse.formatpath(texengine,true) end
            # can be empty, to do
            report("using tex format path #{texformatpath}")
            begin
                Dir.chdir(texformatpath)
            rescue
            end
            if texformats.length > 0 then
                makeuserfile
                makeresponsefile
            end
            texformats.each do |texformat|
                report("generating tex format #{texformat}")
                command = [quoted(texengine),prognameflag(progname),iniflag,tcxflag,prefixed(texformat,texengine),texmakeextras(texformat)].join(' ')
                report(command) if getvariable('verbose')
                system(command)
            end
        else
            texformatpath = ''
        end
        # generate mps formats
        if mpsformats && mpsengine && (progname = validprogname(getvariable('progname'),mpsengine)) then
            report("using mp engine #{mpsengine}")
            mpsformatpath = if getvariable('local') then '.' else Kpse.formatpath(mpsengine,false) end
            report("using mps format path #{mpsformatpath}")
            begin
                Dir.chdir(mpsformatpath)
            rescue
            end
            mpsformats.each do |mpsformat|
                report("generating mps format #{mpsformat}")
                command = [quoted(mpsengine),prognameflag(progname),iniflag,tcxflag,mpsformat,mpsmakeextras(mpsformat)].join(' ')
                report(command) if getvariable('verbose')
                system(command)
            end
        else
            mpsformatpath = ''
        end
        # check for problems
        report("tex engine path: #{texformatpath}") unless texformatpath.empty?
        report("mps engine path: #{mpsformatpath}") unless mpsformatpath.empty?
        [['fmt','tex'],['mem','mps']].each do |f|
            [[texformatpath,'global'],[mpsformatpath,'global'],[savedpath,'current']].each do |p|
                begin
                    Dir.chdir(p[0])
                rescue
                else
                    Dir.glob("*.#{f[0]}").each do |file|
                        report("#{f[1]}format: #{filestate(file)} > #{File.expand_path(file)}")
                    end
                end
            end
        end
        # to be sure, go back to current path
        begin
            Dir.chdir(savedpath)
        rescue
        end
        # finalize
        cleanup
        reportruntime
    end

    def checkcontext

        # todo : report texmf.cnf en problems

        # basics
        report("current distribution: #{Kpse.distribution}")
        report("context source date: #{contextversion}")
        formatpaths = Kpse.formatpaths
        globpattern = "**/{#{formatpaths.join(',')}}/*/*.{fmt,efmt,ofmt,xfmt,mem}"
        report("format path: #{formatpaths.join(' ')}")
        # utilities
        report('start of analysis')
        results = Array.new
        ['texexec','texutil','ctxtools'].each do |program|
            result = `texmfstart #{program} --help`
            result.sub!(/.*?(#{program}[^\n]+)\n.*/mi) do $1 end
            results.push("#{result}")
        end
        # formats
        cleanuptemprunfiles
        if formats = Dir.glob(globpattern) then
            formats.sort.each do |name|
                cleanuptemprunfiles
                if f = open(tempfilename('tex'),'w') then
                    # kind of aleph-run-out-of-par safe
                    f << "\\starttext\n"
                    f << "  \\relax test \\relax\n"
                    f << "\\stoptext\n"
                    f << "\\endinput\n"
                    f.close
                    if FileTest.file?(tempfilename('tex')) then
                        format = File.basename(name)
                        engine = if name =~ /(pdfetex|aleph|xetex)[\/\\]#{format}/ then $1 else '' end
                        if engine.empty? then
                            engineflag = ""
                        else
                            engineflag = "--engine=#{$1}"
                        end
                        case format
                            when /cont\-([a-z]+)/ then
                                interface = $1.sub(/cont\-/,'')
                                results.push('')
                                results.push("testing interface #{interface}")
                                flags = ['--process','--batch','--once',"--interface=#{interface}",engineflag]
                                # result = Kpse.pipescript('newtexexec',tempfilename,flags)
                                result = runtexexec([tempfilename], flags, 1)
                                if FileTest.file?("#{@@temprunfile}.log") then
                                    logdata = IO.read("#{@@temprunfile}.log")
                                    if logdata =~ /^\s*This is (.*?)[\s\,]+(.*?)$/mois then
                                        if validtexengine($1.downcase) then
                                            results.push("#{$1} #{$2.gsub(/\(format.*$/,'')}".strip)
                                        end
                                    end
                                    if logdata =~ /^\s*(ConTeXt)\s+(.*int:\s+[a-z]+.*?)\s*$/mois then
                                        results.push("#{$1} #{$2}".gsub(/\s+/,' ').strip)
                                    end
                                else
                                    results.push("format #{format} does not work")
                                end
                            when /metafun/ then
                                # todo
                            when /mptopdf/ then
                                # todo
                        end
                    else
                        results.push("error in creating #{tempfilename('tex')}")
                    end
                end
                cleanuptemprunfiles
            end
        end
        report('end of analysis')
        report
        results.each do |line|
            report(line)
        end
        cleanuptemprunfiles

    end

    private

    def makeuserfile
        language = getvariable('language')
        mainlanguage = getvariable('mainlanguage')
        bodyfont = getvariable('bodyfont')
        if f = openedfile("cont-fmt.tex") then
            f << "\\unprotect"
            case language
                when 'all' then
                    f << "\\preloadallpatterns\n"
                when '' then
                    f << "% no language presets\n"
                when 'standard'
                    f << "% using defaults\n"
                else
                    languages = language.split(',')
                    languages.each do |l|
                        f << "\\installlanguage[\\s!#{l}][\\c!state=\\v!start]\n"
                    end
                    mainlanguage = languages.first
            end
            unless mainlanguage == 'standard' then
                f << "\\setupcurrentlanguage[\\s!#{mainlanguage}]\n";
            end
            unless bodyfont == 'standard' then
                # ~ will become obsolete when lmr is used
                f << "\\definetypescriptsynonym[cmr][#{bodyfont}]"
                # ~ is already obsolete for some years now
                f << "\\definefilesynonym[font-cmr][font-#{bodyfont}]\n"
            end
            f << "\\protect\n"
            f << "\\endinput\n"
            f.close
        end
    end

    def makeresponsefile
        interface = getvariable('interface')
        if f = openedfile("mult-def.tex") then
            case interface
                when 'standard' then
                    f << "% using default response interface"
                else
                    f << "\\def\\currentresponses\{#{interface}\}\n"
            end
            f << "\\endinput\n"
            f.close
        end
    end

    private  # will become baee/context

    @@preamblekeys = [
        ['tex','texengine'],
        ['program','texengine'],
        ['translate','tcxfilter'],
        ['tcx','tcxfilter'],
        ['output','backend'],
        ['mode','mode'],
        ['ctx','ctxfile'],
        ['version','contextversion'],
        ['format','texformat'],
        ['interface','texformat']
    ]

    def scantexpreamble(filename)
        begin
            if FileTest.file?(filename) and tex = File.open(filename) then
                while str = tex.gets and str.chomp! do
                    if str =~ /^\%\s*(.*)/o then
                        vars = Hash.new
                        $1.split(/\s+/o).each do |s|
                            k, v = s.split('=')
                            vars[k] = v
                        end
                        @@preamblekeys.each do |v|
                            setvariable(v[1],vars[v[0]]) if vars.key?(v[0])
                        end
                    else
                        break
                    end
                end
                tex.close
            end
        rescue
            # well, let's not worry too much
        end
    end

    def scantexcontent(filename)
        if FileTest.file?(filename) and  tex = File.open(filename) then
            while str = tex.gets do
                case str.chomp
                    when /^\%/o then
                        # next
                    when /\\(starttekst|stoptekst|startonderdeel|startdocument|startoverzicht)/o then
                        setvariable('texformat','nl') ; break
                    when /\\(stelle|verwende|umgebung|benutze)/o then
                        setvariable('texformat','de') ; break
                    when /\\(stel|gebruik|omgeving)/o then
                        setvariable('texformat','nl') ; break
                    when /\\(use|setup|environment)/o then
                        setvariable('texformat','en') ; break
                    when /\\(usa|imposta|ambiente)/o then
                        setvariable('texformat','it') ; break
                    when /(height|width|style)=/o then
                        setvariable('texformat','en') ; break
                    when /(hoehe|breite|schrift)=/o then
                        setvariable('texformat','de') ; break
                    when /(hoogte|breedte|letter)=/o then
                        setvariable('texformat','nl') ; break
                    when /(altezza|ampiezza|stile)=/o then
                        setvariable('texformat','it') ; break
                    when /externfiguur/o then
                        setvariable('texformat','nl') ; break
                    when /externalfigure/o then
                        setvariable('texformat','en') ; break
                    when /externeabbildung/o then
                        setvariable('texformat','de') ; break
                    when /figuraesterna/o then
                        setvariable('texformat','it') ; break
                end
            end
            tex.close
        end

    end

    private # will become base/context

    def pushresult(filename,resultname)
        fname = File.unsuffixed(filename)
        rname = File.unsuffixed(resultname)
        if ! rname.empty? && (rname != fname) then
            report("outputfile #{rname}")
            ['tuo','log','dvi','pdf'].each do |s|
                File.silentrename(File.suffixed(fname,s),File.suffixed('texexec',s))
            end
            ['tuo'].each do |s|
                File.silentrename(File.suffixed(rname,s),File.suffixed(fname,s)) if FileTest.file?(File.suffixed(rname,s))
            end
        end
    end

    def popresult(filename,resultname)
        fname = File.unsuffixed(filename)
        rname = File.unsuffixed(resultname)
        if ! rname.empty? && (rname != fname) then
            report("renaming #{fname} to #{rname}")
            ['tuo','log','dvi','pdf'].each do |s|
                File.silentrename(File.suffixed(fname,s),File.suffixed(rname,s))
            end
            report("restoring #{fname}")
            unless $fname == 'texexec' then
                ['tuo','log','dvi','pdf'].each do |s|
                    File.silentrename(File.suffixed('texexec',s),File.suffixed(fname,s))
                end
            end
        end
    end

    def makestubfile(rawname,forcexml=false)
        if tmp = File.open(File.suffixed(rawname,'run'),'w') then
            tmp << "\\starttext\n"
            if forcexml then
                if FileTest.file?(rawname) && (xml = File.open(rawname)) then
                    xml.each do |line|
                        case line
                            when /<\?context\-directive\s+(\S+)\s+(\S+)\s+(\S+)\s*(.*?)\s*\?>/o then
                                category, key, value, rest = $1, $2, $3, $4
                                case category
                                    when 'job' then
                                        case key
                                            when 'control' then
                                                setvariable(value,if rest.empty? then true else rest end)
                                            when 'mode', 'modes' then
                                                tmp << "\\enablemode[#{value}]\n"
                                            when 'stylefile', 'environment' then
                                                tmp << "\\environment #{value}\n"
                                            when 'module' then
                                                tmp << "\\usemodule[#{value}]\n"
                                            when 'interface' then
                                                contextinterface = value
                                        end
                                end
                            when /<[a-z]+/io then # beware of order, first pi test
                                break
                        end
                    end
                    xml.close
                end
                tmp << "\\processXMLfilegrouped{#{rawname}}\n"
            else
                tmp << "\\processfile{#{rawname}}\n"
            end
            tmp << "\\stoptext\n"
            tmp.close
            return "run"
        else
            return File.splitname(rawname)[1]
        end
    end

end

class TEX

    def processtex # much to do: mp, xml, runs etc
        setvariable('texformats',[getvariable('interface')]) unless getvariable('interface').empty?
        getarrayvariable('files').each do |filename|
            setvariable('filename',filename)
            report("processing document '#{filename}'")
            processfile
        end
        reportruntime
    end

    def processmptex
        getarrayvariable('files').each do |filename|
            setvariable('filename',filename)
            report("processing graphic '#{filename}'")
            runtexmp(filename)
        end
        reportruntime
    end

    def processmpxtex
        getarrayvariable('files').each do |filename|
            setvariable('filename',filename)
            report("processing text of graphic '#{filename}'")
            processmpx(filename,true)
        end
        reportruntime
    end

    def deleteoptionfile(rawname)
        begin
            File.delete(File.suffixed(rawname,'top'))
        rescue
        end
    end

    def makeoptionfile(rawname, jobname, jobsuffix, finalrun, fastdisabled, kindofrun)
        # jobsuffix = orisuffix
        if topname = File.suffixed(rawname,'top') and opt = File.open(topname,'w') then
            # local handies
            opt << "\% #{topname}\n"
            opt << "\\unprotect\n"
            opt << "\\setupsystem[\\c!n=#{kindofrun}]\n"
            opt << "\\def\\MPOSTformatswitch\{#{prognameflag('metafun')} #{formatflag('mpost')}=\}\n"
            if getvariable('batchmode') then
                opt << "\\batchmode\n"
            end
            if getvariable('nonstopmode') then
                opt << "\\nonstopmode\n"
            end
            if getvariable('paranoid') then
                opt << "\\def\\maxreadlevel{1}\n"
            end
            if (str = File.unixfied(getvariable('modefile'))) && ! str.empty? then
                opt << "\\readlocfile{#{str}}{}{}\n"
            end
            if (str = File.unixfied(getvariable('result'))) && ! str.empty? then
                opt << "\\setupsystem[file=#{str}]\n"
            elsif (str = getvariable('suffix')) && ! str.empty? then
                opt << "\\setupsystem[file=#{jobname}.#{str}]\n"
            end
            if (str = File.unixfied(getvariable('path'))) && ! str.empty? then
                opt << "\\usepath[#{str}]\n" unless str.empty?
            end
            if (str = getvariable('mainlanguage').downcase) && ! str.empty? && ! str.standard? then
                opt << "\\setuplanguage[#{str}]\n"
            end
            if str = validbackend(getvariable('backend')) then
                opt << "\\setupoutput[#{str}]\n"
            end
            if getvariable('color') then
                opt << "\\setupcolors[\\c!state=\\v!start]\n"
            end
            if getvariable('nompmode') || getvariable('nomprun') || getvariable('automprun') then
                opt << "\\runMPgraphicsfalse\n"
            end
            if getvariable('fast') && ! getvariable('fastdisabled') then
                opt << "\\fastmode\n"
            end
            if getvariable('silentmode') then
                opt << "\\silentmode\n"
            end
            if (str = getvariable('separation')) && ! str.empty? then
                opt << "\\setupcolors[\\c!split=#{str}]\n"
            end
            if (str = getvariable('setuppath')) && ! str.empty? then
                opt << "\\setupsystem[\\c!directory=\{#{str}\}]\n"
            end
            if (str = getvariable('paperformat')) && ! str.empty? && ! str.standard? then
                if str =~ /^([a-z]+\d+)([a-z]+\d+)$/io then # A5A4 A4A3 A2A1 ...
                    opt << "\\setuppapersize[#{$1.upcase}][#{$2.upcase}]\n"
                else # ...*...
                    pf = str.upcase.split(/[x\*]/o)
                    pf << pf[0] if pd.size == 1
                    opt << "\\setuppapersize[#{pf[0]}][#{pf[1]}]\n"
                end
            end
            if (str = getvariable('background')) && ! str.empty? then
                opt << "\\defineoverlay[whatever][{\\externalfigure[#{str}][\\c!factor=\\v!max]}]\n"
                opt << "\\setupbackgrounds[\\v!page][\\c!background=whatever]\n"
            end
            if getvariable('centerpage') then
                opt << "\\setuplayout[\\c!location=\\v!middle,\\c!marking=\\v!on]\n"
            end
            if getvariable('nomapfiles') then
                opt << "\\disablemapfiles\n"
            end
            if getvariable('noarrange') then
                opt << "\\setuparranging[\\v!disable]\n"
            elsif getvariable('arrange') then
                arrangement = Array.new
                if finalrun then
                    arrangement << "\\v!doublesided" unless getvariable('noduplex')
                    case printformat
                        when ''         then arrangement << "\\v!normal"
                        when /.*up/oi   then arrangement << "\\v!rotated"
                        when /.*down/oi then arrangement << ["2DOWN","\\v!rotated"]
                        when /.*side/oi then arrangement << ["2SIDE","\\v!rotated"]
                    end
                else
                    arrangement << "\\v!disable"
                end
                opt << "\\setuparranging[#{arrangement.flatten.join(',')}]\n" if arrangement.size > 0
            end
            if (str = getvariable('modes')) && ! str.empty? then
                opt << "\\enablemode[#{modes}]\n"
            end
            if (str = getvariable('arguments')) && ! str.empty? then
                opt << "\\setupenv[#{str}]\n"
            end
            if (str = getvariable('randomseed')) && ! str.empty? then
                opt << "\\setupsystem[\\c!random=#{str}]\n"
            end
            if (str = getvariable('input')) && ! str.empty? then
                opt << "\\setupsystem[inputfile=#{str}]\n"
            else
                opt << "\\setupsystem[inputfile=#{rawname}]\n"
            end
            if (str = getvariable('pages')) && ! str.empty? then
                if str.downcase == 'odd' then
                    opt << "\\chardef\\whichpagetoshipout=1\n"
                elsif str.downcase == 'even' then
                    opt << "\\chardef\\whichpagetoshipout=2\n"
                else
                    pagelist = Array.new
                    str.split(/\,/).each do |page|
                        pagerange = page.split(/(\:|\.\.)/o )
                        if pagerange.size > 1 then
                            pagerange.first.to_i.upto(pagerange.last.to_i) do |p|
                                pagelist << p.to_s
                            end
                        else
                            pagelist << page
                        end
                    end
                    opt << "\\def\\pagestoshipout\{pagelist.join(',')\}\n";
                end
            end
            opt << "\\protect\n";
            begin getvariable('filters'     ).split(',').uniq.each do |f| opt << "\\useXMLfilter[#{f}]\n"   end ; rescue ; end
            begin getvariable('usemodules'  ).split(',').uniq.each do |m| opt << "\\usemodule[#{m}]\n"      end ; rescue ; end
            begin getvariable('environments').split(',').uniq.each do |e| opt << "\\environment #{e}\n"     end ; rescue ; end
          # this will become:
          # begin getvariable('environments').split(',').uniq.each do |e| opt << "\\useenvironment[#{e}]\n" end ; rescue ; end
            opt << "\\endinput\n"
            opt.close
        end
    end

    def takeprecautions
        ENV['MPXCOMAND'] = '0' # else loop
        if getvariable('paranoid') then
            ENV['SHELL_ESCAPE'] = ENV['SHELL_ESCAPE'] || 'f'
            ENV['OPENOUT_ANY']  = ENV['OPENOUT_ANY']  || 'p'
            ENV['OPENIN_ANY']   = ENV['OPENIN_ANY']   || 'p'
        elsif getvariable('notparanoid') then
            ENV['SHELL_ESCAPE'] = ENV['SHELL_ESCAPE'] || 't'
            ENV['OPENOUT_ANY']  = ENV['OPENOUT_ANY']  || 'a'
            ENV['OPENIN_ANY']   = ENV['OPENIN_ANY']   || 'a'
        end
        if ENV['OPENIN_ANY'] && (ENV['OPENIN_ANY'] == 'p') then # first test redundant
            setvariable('paranoid', true)
        end
        if ENV.key?('SHELL_ESCAPE') && (ENV['SHELL_ESCAPE'] == 'f') then
            setvariable('automprun',true)
        end
        ['TXRESOURCES','MPRESOURCES','MFRESOURCES'].each do |res|
            [getvariable('runpath'),getvariable('path')].each do |pat|
                unless pat.empty? then
                    if ENV.key?(res) then
                        ENV[res] = if ENV[res].empty? then pat else pat + ":" + ENV[res] end
                    else
                        ENV[res] = pat
                    end
                end
            end
        end
    end

    def runtex(filename)
        texengine = validtexengine(getvariable('texengine'))
        texformat = validtexformat(getarrayvariable('texformats').first)
        progname  = validprogname(getvariable('progname'))
        report("tex engine: #{texengine}")
        report("tex format: #{texformat}")
        report("progname: #{progname}")
        if texengine && texformat && progname then
            command = [quoted(texengine),prognameflag(progname),formatflag(texengine,texformat),runoptions(texengine),filename,texprocextras(texformat)].join(' ')
            report(command) if getvariable('verbose')
            system(command)
        else
            false
        end
    end

    def runmp(filename)
        mpsengine = validmpsengine(getvariable('mpsengine'))
        mpsformat = validmpsformat(getarrayvariable('mpsformats').first)
        progname  = validprogname(getvariable('progname'))
        if mpsengine && mpsformat && progname then
            command = [quoted(mpsengine),prognameflag(progname),formatflag(mpsengine,mpsformat),runoptions(mpsengine),filename,mpsprocextras(mpsformat)].join(' ')
            report(command) if getvariable('verbose')
            system(command)
        else
            false
        end
    end

    def runtexmp(filename,filetype='')
        mpfile = File.suffixed(filename,filetype,'mp')
        if File.atleast?(mpfile,25) then
            # first run needed
            File.silentdelete(File.suffixed(mpfile,'mpt'))
            doruntexmp(mpfile,false)
            mpgraphics = checkmpgraphics(mpfile)
            mplabels = checkmplabels(mpfile)
            if mpgraphics || mplabels then
                # second run needed
                doruntexmp(mpfile,mplabels)
            end
        end
    end

    def runtexmpjob(filename,filetype='')
        mpfile = File.suffixed(filename,filetype,'mp')
        if File.atleast?(mpfile,25) && (data = File.silentread(mpfile)) then
            textranslation = if data =~ /^\%\s+translate.*?\=([\w\d\-]+)/io then $1 else '' end
            mpjobname = if data =~ /collected graphics of job \"(.+?)\"/io then $1 else '' end
            if ! mpjobname.empty? and File.unsuffixed(filename) =~ /#{mpjobname}/ then # don't optimize
                options = Array.new
                options.push("--mptex")
                options.push("--nomp")
                options.push("--mpyforce") if getvariable('forcempy') || getvariable('mpyforce')
                options.push("--translate=#{textranslation}") unless textranslation.empty?
                options.push("--batch") if getvariable('batchmode')
                options.push("--nonstop") if getvariable('nonstopmode')
                options.push("--output=ps")
                return runtexexec(mpfile,options,2)
            end
        end
        return false
    end

    def runtexutil(filename=[], options=['--ref','--ij','--high'], old=false)
        filename.each do |fname|
            if old then
                Kpse.runscript('texutil',fname,options)
            else
                begin
                    logger = Logger.new('TeXUtil')
                    if tu = TeXUtil::Converter.new(logger) and tu.loaded(fname) then
                        tu.saved if tu.processed
                    end
                rescue
                    Kpse.runscript('texutil',fname,options)
                end
            end
        end
    end

    # 1=tex 2=mptex 3=mpxtex

    def runtexexec(filename=[], options=[], mode=nil)
        begin
            if mode and job = TEX.new(@logger) then
                options.each do |option|
                    if option=~ /^\-*(.*?)\=(.*)$/o then
                        job.setvariable($1,$2)
                    else
                        job.setvariable(option,true)
                    end
                end
                job.setvariable("files",filename)
                case mode
                    when 1 then job.processtex
                    when 2 then job.processmptex
                    when 3 then job.processmpxtex
                end
                job.inspect && Kpse.inspect if getvariable('verbose')
                return true
            else
                Kpse.runscript('texexec',filename,options)
            end
        rescue
            Kpse.runscript('texexec',filename,options)
        end
    end

    def fixbackendvars(backend)
        ENV['backend']     = backend ;
        ENV['progname']    = backend unless validtexengine(backend)
        ENV['TEXFONTMAPS'] = ".;\$TEXMF/fonts/map/{#{backend},pdftex,dvips,}//"
    end

    def runbackend(rawname)
        case validbackend(getvariable('backend'))
            when 'dvipdfmx' then
                fixbackendvars('dvipdfm')
                system("dvipdfmx -d 4 #{File.unsuffixed(rawname)}")
            when 'xetex'    then
                fixbackendvars('xetex')
                system("xdv2pdf #{File.suffixed(jrawname,'xdv')}")
            when 'dvips'    then
                fixbackendvars('dvips')
                mapfiles = ''
                begin
                    if tuifile = File.suffixed(rawname,'tui') and FileTest.file?(tuifile) then
                        IO.read(tuifile).scan(/^c \\usedmapfile\{.\}\{(.*?)\}\s*$/o) do
                            mapfiles += "-u +#{$1} " ;
                        end
                    end
                rescue
                    mapfiles = ''
                end
                system("dvips #{mapfiles} #{File.unsuffixed(rawname)}")
            when 'pdftex'   then
                # no need for postprocessing
            else
                report("no postprocessing needed")
        end
    end

    def processfile

        takeprecautions

        rawname = getvariable('filename')

        jobname = getvariable('filename')
        suffix  = getvariable('suffix')
        result  = getvariable('result')

        runonce    = getvariable('once')
        finalrun   = getvariable('final') || (getvariable('arrange') && ! getvariable('noarrange'))
        globalfile = getvariable('globalfile')

        if getvariable('autopath') then
            jobname = File.basename(jobname)
            inppath = File.dirname(jobname)
        else
            inppath = ''
        end

        jobname, jobsuffix = File.splitname(jobname,'tex')

        jobname = File.unixfied(jobname)
        inppath = File.unixfied(inppath)
        result  = File.unixfied(result)

        orisuffix = jobsuffix # still needed ?

        setvariable('nomprun',true) if orisuffix == 'mpx' # else cylic run

        PDFview.closeall if getvariable('autopdf')

        forcexml = jobsuffix.match(/^(xml|fo|fox|rlg|exa)$/io) # nil or match

        dummyfile = false

        # fuzzy code snippet: (we kunnen kpse: prefix gebruiken)

        unless FileTest.file?(File.suffixed(jobname,jobsuffix)) then
            if FileTest.file?(rawname + '.tex') then
                jobname = rawname.dup
                jobsuffix  = 'tex'
            end
        end

        # we can have funny names, like 2005.10.10 (given without suffix)

        rawname = jobname + '.' + jobsuffix

        unless FileTest.file?(rawname) then
            inppath.split(',').each do |ip|
                break if dummyfile = FileTest.file?(File.join(ip,rawname))
            end
        end

        # preprocess files

        ctx = CtxRunner.new(rawname,@logger)
        if getvariable('ctxfile').empty? then
            ctx.manipulate(File.suffixed(rawname,'ctx'),'jobname.ctx')
        else
            ctx.manipulate(File.suffixed(getvariable('ctxfile'),'ctx'))
        end
        ctx.savelog(File.suffixed(rawname,'ctl'))

        envs = ctx.environments
        mods = ctx.modules

        # merge environment and module specs

        envs << getvariable('environments') unless getvariable('environments').empty?
        mods << getvariable('modules')      unless getvariable('modules')     .empty?

        envs = envs.uniq.join(',')
        mods = mods.uniq.join(',')

        report("using environments #{envs}") if envs.length > 0
        report("using modules #{mods}")      if mods.length > 0

        setvariable('environments', envs)
        setvariable('modules',      mods)

        # end of preprocessing and merging

        jobsuffix = makestubfile(rawname,forcexml) if dummyfile || forcexml

        if globalfile || FileTest.file?(rawname) then

            if not dummyfile and not globalfile then
                scantexpreamble(rawname)
                scantexcontent(rawname) if getvariable('texformats').standard?
            end

            result = File.suffixed(rawname,suffix) unless suffix.empty?

            pushresult(rawname,result)

            method = validtexmethod(validtexformat(getvariable('texformats')))

            report("tex processing method: #{method}")

            case method

                when 'context' then
                    if getvariable('simplerun') || runonce then
                        makeoptionfile(rawname,jobname,orisuffix,true,true,3) unless getvariable('nooptionfile')
                        ok = runtex(rawname)
                        if ok then
                            ok = runtexutil(rawname) if getvariable('texutil') || getvariable('forcetexutil')
                            runbackend(rawname)
                            popresult(rawname,result)
                        end
                        File.silentdelete(File.suffixed(rawname,'tmp'))
                        File.silentrename(File.suffixed(rawname,'top'),File.suffixed(rawname,'tmp'))
                    else
                        mprundone, ok, stoprunning = false, true, false
                        texruns, nofruns = 0, getvariable('runs').to_i
                        state = FileState.new
                        ['tub','tuo'].each do |s|
                            state.register(File.suffixed(rawname,s))
                        end
                        if getvariable('automprun') then # check this
                            ['mprun','mpgraph'].each do |s|
                                state.register(File.suffixed(rawname,s,'mp'),'randomseed')
                            end
                        end
                        while ! stoprunning && (texruns < nofruns) && ok do
                            texruns += 1
                            report("TeX run #{texruns}")
                            if texruns == 1 then
                                makeoptionfile(rawname,jobname,orisuffix,false,false,1) unless getvariable('nooptionfile')
                            else
                                makeoptionfile(rawname,jobname,orisuffix,false,false,2) unless getvariable('nooptionfile')
                            end
                            ok = runtex(File.suffixed(rawname,jobsuffix))
                            if ok && (nofruns > 1) then
                                unless getvariable('nompmode') then
                                    mprundone = runtexmpjob(rawname, "mpgraph")
                                    mprundone = runtexmpjob(rawname, "mprun")
                                end
                                ok = runtexutil(rawname)
                                state.update
                                stoprunning = state.stable?
                            end
                        end
                        ok = runtexutil(rawname) if (nofruns == 1) && getvariable('texutil')
                        if ok && finalrun && (nofruns > 1) then
                            makeoptionfile(rawname,jobname,orisuffix,true,finalrun,4) unless getvariable('nooptionfile')
                            report("final TeX run #{texruns}")
                            ok = runtex(File.suffixed(rawname,jobsuffix))
                        end
                        ['tmp','top'].each do |s| # previous tuo file / runtime option file
                             File.silentdelete(File.suffixed(rawname,s))
                        end
                        File.silentrename(File.suffixed(rawname,'top'),File.suffixed(rawname,'tmp'))
                        if ok then
                            runbackend(rawname)
                            popresult(rawname,result)
                        end
                    end

                    Kpse.runscript('ctxtools',rawname,'--purge')    if getvariable('purge')
                    Kpse.runscript('ctxtools',rawname,'--purgeall') if getvariable('purgeall')

                when 'latex' then

                    ok = runtex(rawname)

                else

                    ok = runtex(rawname)

            end

            if (dummyfile or forcexml) and FileTest.file?(rawname) then
                begin
                    File.delete(File.suffixed(rawname,'run'))
                rescue
                    report("unable to delete stub file")
                end
            end

            if ok and getvariable('autopdf') then
                PDFview.open(File.suffixed(if result.empty? then rawname else result end,'pdf'))
            end

        end

    end

    # mp specific

    def doruntexmp(mpname,mergebe=true,context=true)
        texfound = false
        mpbetex = Hash.new
        mpfile = File.suffixed(mpname,'mp')
        mpcopy = File.suffixed(mpname,'copy','mp')
        setvariable('mp.file',mpfile)
        setvariable('mp.line','')
        setvariable('mp.error','')
        if mpdata = File.silentread(mpfile) then
            mpdata.gsub!(/^\#.*\n/o,'')
            File.silentrename(mpfile,mpcopy)
            texfound = mergebe || mpdata =~ /btex .*? etex/o
            if mp = File.silentopen(mpfile,'w') then
                mpdata.gsub!(/(btex.*?)\;(.*?etex)/o) do "#{$1}@@@#{$2}" end
                mpdata.gsub!(/(\".*?)\;(.*?\")/o) do "#{$1}@@@#{$2}" end
                mpdata.gsub!(/\;/o, "\;\n")
                mpdata.gsub!(/\n+/o, "\n")
                mpdata.gsub!(/(btex.*?)@@@(.*?etex)/o) do "#{$1}\;#{$2}" end
                mpdata.gsub!(/(\".*?)@@@(.*?\")/o) do "#{$1};#{$2}" end
                if mergebe then
                    mpdata.gsub!(/beginfig\s*\((\d+)\)\s*\;(.*?)endfig\s*\;/o) do
                        n, str = $1, $2
                        if str =~ /(.*?)(verbatimtex.*?etex)\s*\;(.*)/o then
                            "beginfig(#{n})\;\n$1$2\;\n#{mpbetex(n)}\n$3\;endfig\;\n"
                        else
                            "beginfig(#{n})\;\n#{mpbetex(n)}\n#{str}\;endfig\;\n"
                        end
                    end
                end
                unless mpdata =~ /beginfig\s*\(\s*0\s*\)/o then
                    mp << mpbetex[0] if mpbetex.key?(0)
                end
                mp << mpdata # ??
                mp << "\n"
                mp << "end"
                mp << "\n"
                mp.close
            end
            processmpx(mpname) if texfound
            if getvariable('batchmode') then
                options = ' --interaction=batch'
            elsif getvariable('nonstopmode') then
                options = ' --interaction=nonstop'
            else
                options = ''
            end
            # todo plain|mpost|metafun
            ok = runmp(mpname)
            if f = File.silentopen(File.suffixed(mpfile,'log')) then
                while str = f.gets do
                    if str =~ /^l\.(\d+)\s(.*?)\n/o then
                        setvariable('mp.line',$1)
                        setvariable('mp.error',$2)
                        break
                    end
                end
                f.close
            end
            File.silentrename(mpfile,"mptrace.tmp")
            File.silentrename(mpcopy, mpfile)
        end
    end

    def processmpx(mpname,context=true)
        mpname = File.suffixed(mpname,'mp')
        if File.atleast?(mpname,10) && (data = File.silentread(mpname)) then
            begin
                if data =~ /(btex|etex|verbatimtex)/o then
                    mptex = File.suffixed(mpname,'temp','tex')
                    mpdvi = File.suffixed(mpname,'temp','dvi')
                    mplog = File.suffixed(mpname,'temp','log')
                    mpmpx = File.suffixed(mpname,'temp','mpx')
                    ok = system("mpto #{mpname} > #{mptex}")
                    if ok && File.appended(mptex, "\\end\n") then
                        if context then
                            ok = RunConTeXtFile(mptex)
                        else
                            ok = RunSomeTeXFile(mptex)
                        end
                        ok = ok && FileTest.file?(mpdvi) && system("dvitomp #{mpdvi} #{mpmpx}")
                        [mptex,mpdvi,mplog].each do |mpfil|
                            File.silentdelete(mpfil)
                        end
                    end
                end
            rescue
                # error in processing mpx file
            end
        end
    end

    def checkmpgraphics(mpname)
        mpoptions = ''
        if getvariable('makempy') then
            mpoptions += " --makempy "
        end
        if getvariable('mpyforce') || getvariable('forcempy') then
            mpoptions += " --force "
        else
            mponame = File.suffixed(mpname,'mpo')
            mpyname = File.suffixed(mpname,'mpy')
            return false unless File.atleast?(mponame,32)
            mpochecksum = State.new.checksum(mponame)
            return false if mpochecksum.empty?
            # where does the checksum get into the file?
            # maybe let texexec do it?
            # solution: add one if not present or update when different
            if f = File.open(mpyname) then
                str = f.gets.chomp
                f.close
                if str =~ /^\%\s*mpochecksum\s*\:\s*(\d+)/o then
                    return false if mpochecksum == $1
                end
            end
        end
        return Kpse.runscript('makempy',mpname)
    end

    def checkmplabels(mpname)
        mpname = File.suffixed(mpname,'mpt')
        if File.atleast?(mpname,10) && (mp = File.open(mpname)) then
            labels = Hash.new
            while str = mp.gets do
                if str =~ /%\s*setup\s*:\s*(.*)/o then
                    t = $1
                else
                    t = ''
                end
                if str =~ /%\s*figure\s*(\d+)\s*:\s*(.*)/o then
                    unless t.empty? then
                        labels[$1] += "#{t}\n"
                        t = ''
                    end
                    labels[$1] += "$2\n"
                end
            end
            mp.close
            return labels if labels.size>0
        end
        return nil
    end

end

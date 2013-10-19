#encoding: ASCII-8BIT

# module    : base/tex
# copyright : PRAGMA Advanced Document Engineering
# version   : 2005
# author    : Hans Hagen
#
# project   : ConTeXt / eXaMpLe
# concept   : Hans Hagen
# info      : j.hagen@xs4all.nl
# www       : www.pragma-ade.com

# todo:
#
# - write systemcall for mpost to file so that it can be run faster
# - use -8bit and -progname
#

# report ?

require 'fileutils'

require 'base/variables'
require 'base/kpse'
require 'base/system'
require 'base/state'
require 'base/pdf'
require 'base/file'
require 'base/ctx'
require 'base/mp'

class String

    def standard?
        begin
            self == 'standard'
        rescue
            false
        end
    end

end

# class String
    # def utf_bom?
        # self.match(/^\357\273\277/o).length>0 rescue false
    # end
# end

class Array

    def standard?
        begin
            self.include?('standard')
        rescue
            false
        end
    end

    def join_path
        self.join(File::PATH_SEPARATOR)
    end

end

class TEX

    # The make-part of this class was made on a rainy day while listening
    # to "10.000 clowns on a rainy day" by Jan Akkerman. Unfortunately the
    # make method is not as swinging as this live cd.

    include Variables

    @@texengines      = Hash.new
    @@mpsengines      = Hash.new
    @@backends        = Hash.new
    @@mappaths        = Hash.new
    @@runoptions      = Hash.new
    @@draftoptions    = Hash.new
    @@synctexcoptions = Hash.new
    @@texformats      = Hash.new
    @@mpsformats      = Hash.new
    @@prognames       = Hash.new
    @@texmakestr      = Hash.new
    @@texprocstr      = Hash.new
    @@mpsmakestr      = Hash.new
    @@mpsprocstr      = Hash.new
    @@texmethods      = Hash.new
    @@mpsmethods      = Hash.new
    @@pdftex          = 'pdftex'

    @@platformslash = if System.unix? then "\\\\" else "\\" end

    ['tex','etex','pdftex','standard']             .each do |e| @@texengines[e] = 'pdftex'    end
    ['aleph','omega']                              .each do |e| @@texengines[e] = 'aleph'     end
    ['xetex']                                      .each do |e| @@texengines[e] = 'xetex'     end
    ['petex']                                      .each do |e| @@texengines[e] = 'petex'     end

    ['metapost','mpost', 'standard']               .each do |e| @@mpsengines[e] = 'mpost'     end

    ['pdftex','pdf','pdftex','standard']           .each do |b| @@backends[b]   = 'pdftex'    end
    ['dvipdfmx','dvipdfm','dpx','dpm']             .each do |b| @@backends[b]   = 'dvipdfmx'  end
    ['xetex','xtx']                                .each do |b| @@backends[b]   = 'xetex'     end
    ['petex']                                      .each do |b| @@backends[b]   = 'dvipdfmx'  end
    ['aleph']                                      .each do |b| @@backends[b]   = 'dvipdfmx'  end
    ['dvips','ps','dvi']                           .each do |b| @@backends[b]   = 'dvips'     end
    ['dvipsone']                                   .each do |b| @@backends[b]   = 'dvipsone'  end
    ['acrobat','adobe','distiller']                .each do |b| @@backends[b]   = 'acrobat'   end
    ['xdv','xdv2pdf']                              .each do |b| @@backends[b]   = 'xdv2pdf'   end

    ['tex','standard']                             .each do |b| @@mappaths[b]   = 'dvips'     end
    ['pdftex']                                     .each do |b| @@mappaths[b]   = 'pdftex'    end
    ['aleph','omega','xetex','petex']              .each do |b| @@mappaths[b]   = 'dvipdfmx'  end
    ['dvipdfm', 'dvipdfmx', 'xdvipdfmx']           .each do |b| @@mappaths[b]   = 'dvipdfmx'  end
    ['xdv','xdv2pdf']                              .each do |b| @@mappaths[b]   = 'dvips'     end

    # todo norwegian (no)

    ['plain']                                      .each do |f| @@texformats[f] = 'plain'        end
    ['cont-en','en','english','context','standard'].each do |f| @@texformats[f] = 'cont-en.mkii' end
    ['cont-nl','nl','dutch']                       .each do |f| @@texformats[f] = 'cont-nl.mkii' end
    ['cont-de','de','german']                      .each do |f| @@texformats[f] = 'cont-de.mkii' end
    ['cont-it','it','italian']                     .each do |f| @@texformats[f] = 'cont-it.mkii' end
    ['cont-fr','fr','french']                      .each do |f| @@texformats[f] = 'cont-fr.mkii' end
    ['cont-cs','cs','cont-cz','cz','czech']        .each do |f| @@texformats[f] = 'cont-cs.mkii' end
    ['cont-ro','ro','romanian']                    .each do |f| @@texformats[f] = 'cont-ro.mkii' end
    ['cont-gb','gb','cont-uk','uk','british']      .each do |f| @@texformats[f] = 'cont-gb.mkii' end
    ['mptopdf']                                    .each do |f| @@texformats[f] = 'mptopdf'      end

    ['latex']                                      .each do |f| @@texformats[f] = 'latex.ltx' end

    ['plain','mpost']                              .each do |f| @@mpsformats[f] = 'mpost'     end
    ['metafun','context','standard']               .each do |f| @@mpsformats[f] = 'metafun'   end

    ['pdftex','aleph','omega','petex','xetex']     .each do |p| @@prognames[p]  = 'context'   end
    ['mpost']                                      .each do |p| @@prognames[p]  = 'metafun'   end
    ['latex','pdflatex']                           .each do |p| @@prognames[p]  = 'latex'     end

    ['plain','default','standard','mptopdf']       .each do |f| @@texmethods[f] = 'plain'     end
    ['cont-en','cont-en.mkii',
     'cont-nl','cont-nl.mkii',
     'cont-de','cont-de.mkii',
     'cont-it','cont-it.mkii',
     'cont-fr','cont-fr.mkii',
     'cont-cs','cont-cs.mkii',
     'cont-ro','cont-ro.mkii',
     'cont-gb','cont-gb.mkii']                     .each do |f| @@texmethods[f] = 'context'   end
    ['latex','latex.ltx','pdflatex']               .each do |f| @@texmethods[f] = 'latex'     end # untested

    ['plain','default','standard']                 .each do |f| @@mpsmethods[f] = 'plain'     end
    ['metafun']                                    .each do |f| @@mpsmethods[f] = 'metafun'   end

    @@texmakestr['plain'] = @@platformslash + "dump"
    @@mpsmakestr['plain'] = @@platformslash + "dump"

    ['cont-en','cont-nl','cont-de','cont-it',
     'cont-fr','cont-cs','cont-ro','cont-gb',
     'cont-pe','cont-xp']                         .each do |f| @@texprocstr[f] = @@platformslash + "emergencyend"  end

    @@runoptions['aleph']      = ['--8bit']
    @@runoptions['mpost']      = ['--8bit']
    @@runoptions['pdftex']     = ['--8bit']
  # @@runoptions['petex']      = []
    @@runoptions['xetex']      = ['--8bit','-output-driver="xdvipdfmx -E -d 4 -V 5"']
    @@draftoptions['pdftex']   = ['--draftmode']
    @@synctexcoptions['pdftex'] = ['--synctex=1']
    @@synctexcoptions['xetex']  = ['--synctex=1']

    @@mainbooleanvars = [
        'batchmode', 'nonstopmode', 'fast', 'final',
        'paranoid', 'notparanoid', 'nobanner', 'once', 'allpatterns', 'draft',
        'nompmode', 'nomprun', 'automprun', 'combine',
        'nomapfiles', 'local',
        'arrange', 'noarrange',
        'forcexml', 'foxet',
        'alpha', 'beta',
        'mpyforce', 'forcempy',
        'forcetexutil', 'texutil',
        'globalfile', 'autopath',
        'purge', 'purgeall', 'keep', 'autopdf', 'xpdf', 'simplerun', 'verbose',
        'nooptionfile', 'nobackend', 'noctx', 'utfbom',
        'mkii','mkiv',
        'synctex',
    ]
    @@mainstringvars = [
        'modefile', 'result', 'suffix', 'response', 'path',
        'filters', 'usemodules', 'environments', 'separation', 'setuppath',
        'arguments', 'input', 'output', 'randomseed', 'modes', 'mode', 'filename',
        'ctxfile', 'printformat', 'paperformat', 'paperoffset',
        'timeout', 'passon', 'pdftitle'
    ]
    @@mainstandardvars = [
        'mainlanguage', 'bodyfont', 'language'
    ]
    @@mainknownvars = [
        'engine', 'distribution', 'texformats', 'mpsformats', 'progname', 'interface',
        'runs', 'backend'
    ]

    @@extrabooleanvars = []
    @@extrastringvars = []

    def booleanvars
        [@@mainbooleanvars,@@extrabooleanvars].flatten.uniq
    end
    def stringvars
        [@@mainstringvars,@@extrastringvars].flatten.uniq
    end
    def standardvars
        [@@mainstandardvars].flatten.uniq
    end
    def knownvars
        [@@mainknownvars].flatten.uniq
    end
    def allbooleanvars
        [@@mainbooleanvars,@@extrabooleanvars].flatten.uniq
    end
    def allstringvars
        [@@mainstringvars,@@extrastringvars,@@mainstandardvars,@@mainknownvars].flatten.uniq
    end

    def setextrastringvars(vars)
        # @@extrastringvars << vars -- problems in 1.9
        @@extrastringvars = [@@extrastringvars,vars].flatten
    end
    def setextrabooleanvars(vars)
        # @@extrabooleanvars << vars -- problems in 1.9
        @@extrabooleanvars = [@@extrabooleanvars,vars].flatten
    end

    # def jobvariables(names=nil)
        # if [names ||[]].flatten.size == 0 then
            # names = [allbooleanvars,allstringvars].flatten
        # end
        # data = Hash.new
        # names.each do |name|
            # if allbooleanvars.include?(name) then
                # data[name] = if getvariable(name) then "yes" else "no" end
            # else
                # data[name] = getvariable(name)
            # end
        # end
        # data
    # end

    # def setjobvariables(names=nil)
        # assignments = Array.new
        # jobvariables(names).each do |k,v|
            # assignments << "#{k}=\{#{v}\}"
        # end
        # "\setvariables[exe][#{assignments.join(", ")}]"
    # end

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
        setvariable('progname',     'standard') # or ''
        setvariable('interface',    'standard')
        setvariable('engine',       'standard') # replaced by tex/mpsengine
        setvariable('backend',      'pdftex')
        setvariable('runs',         '8')
        setvariable('randomseed',   rand(1440).to_s) # we want the same seed for one run
        # files
        setvariable('files',        [])
        # defaults
        setvariable('texengine',    'standard')
        setvariable('mpsengine',    'standard')
        setvariable('backend',      'standard')
        setvariable('error',        '')
    end

    def error?
        not getvariable('error').empty?
    end

    def runtime
        Time.now - @startuptime
    end

    def reportruntime
        report("runtime: #{runtime}")
    end

    def runcommand(something)
        command = [something].flatten.join(' ')
        report("running: #{command}") if getvariable('verbose')
        system(command)
    end

    def inspect(name=nil)
        if ! name || name.empty? then
            name = [booleanvars,stringvars,standardvars,knownvars]
        end
        str = '' # allocate
        [name].flatten.each do |n|
            if str = getvariable(n) then
                str = str.join(" ") if str.class == Array
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
                    File.delete(name) rescue false
                end
            end
        rescue
        end
        # ['mpgraph.mp'].each do |file|
            # (File.delete(file) if (FileTest.size?(file) rescue 10) < 10) rescue false
        # end
    end

    def backends() @@backends.keys.sort end

    def texengines() @@texengines.keys.sort end
    def mpsengines() @@mpsengines.keys.sort end
    def texformats() @@texformats.keys.sort end
    def mpsformats() @@mpsformats.keys.sort end

    def defaulttexformats() ['en','nl','mptopdf'] end
    def defaultmpsformats() ['metafun']           end # no longer formats

    def texmakeextras(format) @@texmakestr[format] || '' end
    def mpsmakeextras(format) @@mpsmakestr[format] || '' end
    def texprocextras(format) @@texprocstr[format] || '' end
    def mpsprocextras(format) @@mpsprocstr[format] || '' end

    def texmethod(format) @@texmethods[str] || @@texmethods['standard'] end
    def mpsmethod(format) @@mpsmethods[str] || @@mpsmethods['standard'] end

    def runoptions(engine)
        options = if getvariable('draft') then @@draftoptions[engine] else [] end
        options = if getvariable('synctex') then @@synctexcoptions[engine] else [] end
        begin
            if str = getvariable('passon') then
                options = [options,str.split(' ')].flatten
            end
        rescue
        end
        if @@runoptions.key?(engine) then
            [options,@@runoptions[engine]].flatten.join(' ')
        else
            options.join(' ')
        end
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
        # format
        case engine
           when /etex|pdftex|aleph|xetex/io then
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

    def validsomething(str,something,type=nil)
        if str then
            list = [str].flatten.collect do |s|
                if something[s] then
                    something[s]
                elsif type && s =~ /\.#{type}$/ then
                    s
                else
                    nil
                end
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

    def validtexformat(str) validsomething(str,@@texformats,'tex')    ||
                            validsomething(str,@@texformats,'mkii')   end
    def validmpsformat(str) validsomething(str,@@mpsformats,'mp' )    end
    def validtexengine(str) validsomething(str,@@texengines,'pdftex') end
    def validmpsengine(str) validsomething(str,@@mpsengines,'mpost' ) end

    def validtexmethod(str) [validsomething(str,@@texmethods)].flatten.first end
    def validmpsmethod(str) [validsomething(str,@@mpsmethods)].flatten.first end

    def validbackend(str)
        if str && @@backends.key?(str) then
            @@backends[str]
        else
            @@backends['standard']
        end
    end

    def validprogname(str)
        if str then
            [str].flatten.each do |s|
                s = s.sub(/\.\S*/,"")
                return @@prognames[s] if @@prognames.key?(s)
            end
            return str[0].sub(/\.\S*/,"")
        else
            return nil
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
            "#{prefix}=#{format.sub(/\.\S+$/,"")}"
        else
            prefix
        end
    end

    def web2cformatflag(engine=nil)
        # funny that we've standardized on the fmt suffix (at the cost of
        # upward compatibility problems) but stuck to the bas/mem/fmt flags
        if engine then
            case validmpsengine(engine)
                when /mpost/ then "-mem"
                when /mfont/ then "-bas"
                else              "-fmt"
            end
        else
            "-fmt"
        end
    end

    def prognameflag(progname=nil)
        case getvariable('distribution')
            when 'standard' then prefix = "-progname"
            when /web2c/io  then prefix = "-progname"
            when /miktex/io then prefix = "-alias"
                            else return ""
        end
        if progname and not progname.empty? then
            "#{prefix}=#{progname}"
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

  # # obsolete
  #
  # def tcxflag(engine)
  #     if @@tcxflag[engine] then
  #         file = "natural.tcx"
  #         if Kpse.miktex? then
  #             "-tcx=#{file}"
  #         else
  #             "-translate-file=#{file}"
  #         end
  #     else
  #         ""
  #     end
  # end

    def filestate(file)
        File.mtime(file).strftime("%d/%m/%Y %H:%M:%S")
    end

    # will go to context/process context/listing etc

    def contextversion # ook elders gebruiken
        filename = Kpse.found('context.mkii')
        version = 'unknown'
        begin
            if FileTest.file?(filename) && IO.read(filename).match(/\\contextversion\{(\d+\.\d+\.\d+.*?)\}/) then
                version = $1
            end
        rescue
        end
        return version
    end

    # we need engine methods

    def makeformats

        checktestversion

        report("using search method '#{Kpse.searchmethod}'")
        if getvariable('fast') then
            report('using existing database')
        else
            report('updating file database')
            Kpse.update # obsolete here
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
        unless texformats || mpsformats then
            report('provide valid format (name.tex, name.mp, ...) or format id (metafun, en, nl, ...)')
            setvariable('error','no format specified')
        end
        if texformats && texengine then
            report("using tex engine #{texengine}")
            texformatpath = if getvariable('local') then '.' else Kpse.formatpath(texengine,true) end
            # can be empty, to do
            report("using tex format path #{texformatpath}")
            Dir.chdir(texformatpath) rescue false
            if FileTest.writable?(texformatpath) then
            # from now on we no longer support this; we load
            # all patterns and if someone wants another
            # interface language ... cook up a fmt or usr file
            #
            #   if texformats.length > 0 then
            #       makeuserfile
            #       makeresponsefile
            #   end
                texformats.each do |texformat|
                    report("generating tex format #{texformat}")
                    progname = validprogname([getvariable('progname'),texformat,texengine])
                    runcommand([quoted(texengine),prognameflag(progname),iniflag,prefixed(texformat,texengine),texmakeextras(texformat)])
                end
            else
                report("unable to make format due to lack of permissions")
                texformatpath = ''
                setvariable('error','no permissions to write')
            end
            if not mpsformats then
                # we want metafun to be in sync
                setvariable('mpsformats',defaultmpsformats)
                mpsformats = validmpsformat(getarrayvariable('mpsformats'))
            end
        else
            texformatpath = ''
        end
        # generate mps formats
     #  if mpsformats && mpsengine then
     #      report("using mp engine #{mpsengine}")
     #      mpsformatpath = if getvariable('local') then '.' else Kpse.formatpath(mpsengine,false) end
     #      report("using mps format path #{mpsformatpath}")
     #      Dir.chdir(mpsformatpath) rescue false
     #      if FileTest.writable?(mpsformatpath) then
     #          mpsformats.each do |mpsformat|
     #              report("generating mps format #{mpsformat}")
     #              progname = validprogname([getvariable('progname'),mpsformat,mpsengine])
     #              if not runcommand([quoted(mpsengine),prognameflag(progname),iniflag,runoptions(mpsengine),mpsformat,mpsmakeextras(mpsformat)]) then
     #                  setvariable('error','no format made')
     #              end
     #          end
     #      else
     #          report("unable to make format due to lack of permissions")
     #          mpsformatpath = ''
     #          setvariable('error','file permission problem')
     #      end
     #   else
     #      mpsformatpath = ''
     #  end
        # check for problems
        report("")
        report("tex engine path: #{texformatpath}") unless texformatpath.empty?
     #  report("mps engine path: #{mpsformatpath}") unless mpsformatpath.empty?
        report("")
     #  [['fmt','tex'],['mem','mps']].each do |f|
     #      [[texformatpath,'global'],[mpsformatpath,'global'],[savedpath,'current']].each do |p|
        [['fmt','tex']].each do |f|
            [[texformatpath,'global'],[savedpath,'current']].each do |p|
                begin
                    Dir.chdir(p[0])
                rescue
                else
                    Dir.glob("*.#{f[0]}").each do |file|
                        report("#{f[1]}: #{filestate(file)} > #{File.expand_path(file)} (#{File.size(file)})")
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
        report("")
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
        # ['texexec','texutil','ctxtools'].each do |program|
        ['texexec'].each do |program|
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
                        engine = if name =~ /(pdftex|aleph|xetex)[\/\\]#{format}/ then $1 else '' end
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
                                flags = ['--noctx','--process','--batch','--once',"--interface=#{interface}",engineflag]
                                # result = Kpse.pipescript('texexec',tempfilename,flags)
                                result = runtexexec([tempfilename], flags, 1)
                                if FileTest.file?("#{@@temprunfile}.log") then
                                    logdata = IO.read("#{@@temprunfile}.log")
                                    if logdata =~ /^\s*This is (.*?)[\s\,]+(.*?)$/moi then
                                        if validtexengine($1.downcase) then
                                            results.push("#{$1} #{$2.gsub(/\(format.*$/,'')}".strip)
                                        end
                                    end
                                    if logdata =~ /^\s*(ConTeXt)\s+(.*int:\s+[a-z]+.*?)\s*$/moi then
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
            f << "\\unprotect\n"
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

    private  # will become base/context

    @@preamblekeys = [
        ['tex','texengine'],
        ['engine','texengine'],
        ['program','texengine'],
      # ['translate','tcxfilter'],
      # ['tcx','tcxfilter'],
        ['output','backend'],
        ['mode','mode'],
        ['ctx','ctxfile'],
        ['version','contextversion'],
        ['format','texformats'],
        ['interface','texformats'],
    ]

    @@re_utf_bom = /^\357\273\277/o

    def scantexpreamble(filename)
        begin
            if FileTest.file?(filename) and tex = File.open(filename,'rb') then
                bomdone = false
                while str = tex.gets and str.chomp! do
                    unless bomdone then
                        if str.sub!(@@re_utf_bom, '')
                            report("utf mode forced (bom found)")
                            setvariable('utfbom',true)
                        end
                        bomdone = true
                    end
                    if str =~ /^\%\s*(.*)/o then
                        # we only accept lines with key=value pairs
                        vars, ok = Hash.new, true
                        $1.split(/\s+/o).each do |s|
                            k, v = s.split('=')
                            if k && v then
                                vars[k] = v
                            else
                                ok = false
                                break
                            end
                        end
                        if ok then
                            # we have a valid line

                            @@preamblekeys.each do |v|
                                setvariable(v[1],vars[v[0]]) if vars.key?(v[0]) && vars[v[0]]
                            end

if getvariable('given.backend') == "standard" or getvariable('given.backend') == "" then
    setvariable('backend',@@backends[getvariable('texengine')] || 'standard')
end
                            break
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
        if FileTest.file?(filename) and tex = File.open(filename,'rb') then
            while str = tex.gets do
                case str.chomp
                    when /^\%/o then
                        # next
                #   when /\\(starttekst|stoptekst|startonderdeel|startdocument|startoverzicht)/o then
                    when /\\(starttekst|stoptekst|startonderdeel|startoverzicht)/o then
                        setvariable('texformats','nl') ; break
                    when /\\(stelle|verwende|umgebung|benutze)/o then
                        setvariable('texformats','de') ; break
                    when /\\(stel|gebruik|omgeving)/o then
                        setvariable('texformats','nl') ; break
                    when /\\(use|setup|environment)/o then
                        setvariable('texformats','en') ; break
                    when /\\(usa|imposta|ambiente)/o then
                        setvariable('texformats','it') ; break
                    when /(height|width|style)=/o then
                        setvariable('texformats','en') ; break
                    when /(hoehe|breite|schrift)=/o then
                        setvariable('texformats','de') ; break
                    when /(hoogte|breedte|letter)=/o then
                        setvariable('texformats','nl') ; break
                    when /(altezza|ampiezza|stile)=/o then
                        setvariable('texformats','it') ; break
                    when /externfiguur/o then
                        setvariable('texformats','nl') ; break
                    when /externalfigure/o then
                        setvariable('texformats','en') ; break
                    when /externeabbildung/o then
                        setvariable('texformats','de') ; break
                    when /figuraesterna/o then
                        setvariable('texformats','it') ; break
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
            ['tuo','tuc','log','dvi','pdf'].each do |s|
                File.silentrename(File.suffixed(fname,s),File.suffixed('texexec',s))
            end
            ['tuo','tuc'].each do |s|
                File.silentrename(File.suffixed(rname,s),File.suffixed(fname,s)) if FileTest.file?(File.suffixed(rname,s))
            end
        end
    end

    def popresult(filename,resultname)
        fname = File.unsuffixed(filename)
        rname = File.unsuffixed(resultname)
        if ! rname.empty? && (rname != fname) then
            report("renaming #{fname} to #{rname}")
            ['tuo','tuc','log','dvi','pdf'].each do |s|
                File.silentrename(File.suffixed(fname,s),File.suffixed(rname,s))
            end
            report("restoring #{fname}")
            unless $fname == 'texexec' then
                ['tuo','tuc','log','dvi','pdf'].each do |s|
                    File.silentrename(File.suffixed('texexec',s),File.suffixed(fname,s))
                end
            end
        end
    end

    def makestubfile(rawname,rawbase,forcexml=false)
        if tmp = openedfile(File.suffixed(rawbase,'run')) then
            tmp << "\\starttext\n"
            if forcexml then
                # tmp << checkxmlfile(rawname)
                if getvariable('mkiv') then
                    tmp << "\\xmlprocess{\\xmldocument}{#{rawname}}{}\n"
                else
                    tmp << "\\processXMLfilegrouped{#{rawname}}\n"
                end
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

    # def checkxmlfile(rawname)
        # tmp = ''
        # if FileTest.file?(rawname) && (xml = File.open(rawname)) then
            # xml.each do |line|
                # case line
                    # when /<\?context\-directive\s+(\S+)\s+(\S+)\s+(\S+)\s*(.*?)\s*\?>/o then
                        # category, key, value, rest = $1, $2, $3, $4
                        # case category
                            # when 'job' then
                                # case key
                                    # when 'control' then
                                        # setvariable(value,if rest.empty? then true else rest end)
                                    # when 'mode', 'modes' then
                                        # tmp << "\\enablemode[#{value}]\n"
                                    # when 'stylefile', 'environment' then
                                        # tmp << "\\environment #{value}\n"
                                    # when 'module' then
                                        # tmp << "\\usemodule[#{value}]\n"
                                    # when 'interface' then
                                        # contextinterface = value
                                    # when 'ctxfile' then
                                        # setvariable('ctxfile', value)
                                        # report("using source driven ctxfile #{value}")
                                # end
                        # end
                    # when /<[a-z]+/io then # beware of order, first pi test
                        # break
                # end
            # end
            # xml.close
        # end
        # return tmp
    # end

    def extendvariable(name,value)
        set = getvariable(name).split(',')
        set << value
        str = set.uniq.join(',')
        setvariable(name,str)
    end

    def checkxmlfile(rawname)
        if FileTest.file?(rawname) && (xml = File.open(rawname,'rb')) then
            xml.each do |line|
                case line
                    when /<\?context\-directive\s+(\S+)\s+(\S+)\s+(\S+)\s*(.*?)\s*\?>/o then
                        category, key, value, rest = $1, $2, $3, $4
                        case category
                            when 'job' then
                                case key
                                    when 'control' then
                                        setvariable(value,if rest.empty? then true else rest end)
                                    when /^(mode)(s|)$/ then
                                        extendvariable('modes',value)
                                    when /^(stylefile|environment)(s|)$/ then
                                        extendvariable('environments',value)
                                    when /^(use|)(module)(s|)$/ then
                                        extendvariable('usemodules',value)
                                    when /^(filter)(s|)$/ then
                                        extendvariable('filters',value)
                                    when 'interface' then
                                        contextinterface = value
                                    when 'ctxfile' then
                                        setvariable('ctxfile', value)
                                        report("using source driven ctxfile #{value}")
                                end
                        end
                    when /<[a-z]+/io then # beware of order, first pi test
                        break
                end
            end
            xml.close
        end
    end

end

class TEX

    def timedrun(delay, &block)
        delay = delay.to_i rescue 0
        if delay > 0 then
            begin
                report("job started with timeout '#{delay}'")
                timeout(delay) do
                    yield block
                end
            rescue TimeoutError
                report("job aborted due to timeout '#{delay}'")
                setvariable('error','timeout')
            rescue
                report("job aborted due to error")
                setvariable('error','fatal error')
            else
                report("job finished within timeout '#{delay}'")
            end
        else
            yield block
        end
    end

    def processtex # much to do: mp, xml, runs etc
        setvariable('texformats',[getvariable('interface')]) unless getvariable('interface').empty?
        getarrayvariable('files').each do |filename|
            setvariable('filename',filename)
            report("processing document '#{filename}'")
            timedrun(getvariable('timeout')) do
                processfile
            end
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

    private

    def load_map_files(filename) # tui basename
        # c \usedmapfile{=}{lm-texnansi}
        begin
            str = ""
            IO.read(filename).scan(/^c\s+\\usedmapfile\{(.*?)\}\{(.*?)\}\s*$/o) do
                str << "\\loadmapfile[#{$2}.map]\n"
            end
        rescue
            return ""
        else
            return str
        end
    end

    public

    def processmpgraphic
        getarrayvariable('files').each do |filename|
            setvariable('filename',filename)
            report("processing graphic '#{filename}'")
            runtexmp(filename,'',false) # no purge
            mapspecs = load_map_files(File.suffixed(filename,'temp','tui'))
            unless getvariable('keep') then
                # not enough: purge_mpx_files(filename)
                Dir.glob(File.suffixed(filename,'temp*','*')).each do |fname|
                    File.delete(fname) unless File.basename(filename) == File.basename(fname)
                end
            end
            begin
                data = IO.read(File.suffixed(filename,'log'))
                basename = filename.sub(/\.mp$/, '')
                if data =~ /output files* written\:\s*(.*)$/moi then
                    files, number, range, list = $1.split(/\s+/), 0, false, []
                    files.each do |fname|
                        if fname =~ /^.*\.(\d+)$/ then
                            if range then
                                (number+1 .. $1.to_i).each do |i|
                                    list << i
                                end
                                range = false
                            else
                                number = $1.to_i
                                list << number
                            end
                        elsif fname =~ /\.\./ then
                            range = true
                        else
                            range = false
                            next
                        end
                    end
                    begin
                        if getvariable('combine') then
                            fullname = "#{basename}.#{number}"
                            File.open("texexec.tex",'w') do |f|
                                f << "\\setupoutput[pdftex]\n"
                                f << "\\setupcolors[state=start]\n"
                                f << mapspecs
                                f << "\\starttext\n"
                                list.each do |number|
                                    f << "\\startTEXpage\n"
                                    f << "\\convertMPtoPDF{#{fullname}}{1}{1}"
                                    f << "\\stopTEXpage\n"
                                end
                                f << "\\stoptext\n"
                            end
                            report("converting graphic '#{fullname}'")
                            runtex("texexec.tex")
                            pdffile = File.suffixed(basename,'pdf')
                            File.silentrename("texexec.pdf",pdffile)
                            report ("#{basename}.* converted to #{pdffile}")
                        else
                            list.each do |number|
                                begin
                                    fullname = "#{basename}.#{number}"
                                    File.open("texexec.tex",'w') do |f|
                                        f << "\\setupoutput[pdftex]\n"
                                        f << "\\setupcolors[state=start]\n"
                                        f << mapspecs
                                        f << "\\starttext\n"
                                        f << "\\startTEXpage\n"
                                        f << "\\convertMPtoPDF{#{fullname}}{1}{1}"
                                        f << "\\stopTEXpage\n"
                                        f << "\\stoptext\n"
                                    end
                                    report("converting graphic '#{fullname}'")
                                    runtex("texexec.tex")
                                    if files.length>1 then
                                        pdffile = File.suffixed(basename,number.to_s,'pdf')
                                    else
                                        pdffile = File.suffixed(basename,'pdf')
                                    end
                                    File.silentrename("texexec.pdf",pdffile)
                                    report ("#{fullname} converted to #{pdffile}")
                                end
                            end
                        end
                    rescue
                        report ("error when converting #{fullname} (#{$!})")
                    end
                end
            rescue
                report("error in converting #{filename}")
            end
        end
        reportruntime
    end

    def processmpstatic
        if filename = getvariable('filename') then
            filename += ".mp" unless filename =~ /\..+?$/
            if FileTest.file?(filename) then
                begin
                    data = IO.read(filename)
                    File.open("texexec.tex",'w') do |f|
                        f << "\\setupoutput[pdftex]\n"
                        f << "\\setupcolors[state=start]\n"
                        data.sub!(/^%mpenvironment\:\s*(.*?)$/moi) do
                            f << $1
                            "\n"
                        end
                        f << "\\starttext\n"
                        f << "\\startMPpage\n"
                        f << data.gsub(/end\.*\s*$/m, '') # a bit of a hack
                        f << "\\stopMPpage\n"
                        f << "\\stoptext\n"
                    end
                    report("converting static '#{filename}'")
                    runtex("texexec.tex")
                    pdffile = File.suffixed(filename,'pdf')
                    File.silentrename("texexec.pdf",pdffile)
                    report ("#{filename} converted to #{pdffile}")
                rescue
                    report("error in converting #{filename} (#{$!}")
                end
            end
        end
        reportruntime
    end

    def processmpxtex
        getarrayvariable('files').each do |filename|
            setvariable('filename',filename)
            report("processing text of graphic '#{filename}'")
            processmpx(filename,false,true,true)
        end
        reportruntime
    end

    def deleteoptionfile(rawname)
        ['top','top.keep'].each do |suffix|
            begin
                File.delete(File.suffixed(rawname,suffix))
            rescue
            end
        end
    end

    def makeoptionfile(rawname, jobname, jobsuffix, finalrun, fastdisabled, kindofrun, currentrun=1)
        begin
            # jobsuffix = orisuffix
            if topname = File.suffixed(rawname,'top') and opt = File.open(topname,'w') then
                report("writing option file #{topname}")
                # local handies
                opt << "\% #{topname}\n"
                opt << "\\unprotect\n"
                #
                # feedback and basic control
                #
                if getvariable('batchmode') then
                    opt << "\\batchmode\n"
                end
                if getvariable('nonstopmode') then
                    opt << "\\nonstopmode\n"
                end
                if getvariable('paranoid') then
                    opt << "\\def\\maxreadlevel{1}\n"
                end
                if getvariable('nomapfiles') then
                    opt << "\\disablemapfiles\n"
                end
                if getvariable('nompmode') || getvariable('nomprun') || getvariable('automprun') then
                    opt << "\\runMPgraphicsfalse\n"
                end
                if getvariable('utfbom') then
                    opt << "\\enableregime[utf]"
                end
                progname = validprogname(['metafun']) # [getvariable('progname'),mpsformat,mpsengine]
                opt << "\\def\\MPOSTformatswitch\{#{prognameflag(progname)} #{formatflag('mpost')}=\}\n"
                #
                # process info
                #
                opt << "\\setupsystem[\\c!n=#{kindofrun},\\c!m=#{currentrun}]\n"
                if (str = File.unixfied(getvariable('modefile'))) && ! str.empty? then
                    opt << "\\readlocfile{#{str}}{}{}\n"
                end
                if (str = File.unixfied(getvariable('result'))) && ! str.empty? then
                    opt << "\\setupsystem[file=#{str}]\n"
                elsif (str = getvariable('suffix')) && ! str.empty? then
                    opt << "\\setupsystem[file=#{jobname}.#{str}]\n"
                end
                opt << "\\setupsystem[\\c!method=2]\n" # 1=oldtexexec 2=newtexexec (obsolete)
                opt << "\\setupsystem[\\c!type=#{Tool.ruby_platform()}]\n"
                if (str = File.unixfied(getvariable('path'))) && ! str.empty? then
                    opt << "\\usepath[#{str}]\n" unless str.empty?
                end
                if (str = getvariable('mainlanguage').downcase) && ! str.empty? && ! str.standard? then
                    opt << "\\setuplanguage[#{str}]\n"
                end
                if (str = getvariable('arguments')) && ! str.empty? then
                    opt << "\\setupenv[#{str}]\n"
                end
                if (str = getvariable('setuppath')) && ! str.empty? then
                    opt << "\\setupsystem[\\c!directory=\{#{str}\}]\n"
                end
                if (str = getvariable('randomseed')) && ! str.empty? then
                    report("using randomseed #{str}")
                    opt << "\\setupsystem[\\c!random=#{str}]\n"
                end
                if (str = getvariable('input')) && ! str.empty? then
                    opt << "\\setupsystem[inputfile=#{str}]\n"
                else
                    opt << "\\setupsystem[inputfile=#{rawname}]\n"
                end
                #
                # modes
                #
                # we handle both "--mode" and "--modes", else "--mode" is mapped onto "--modefile"
                if (str = getvariable('modes')) && ! str.empty? then
                    opt << "\\enablemode[#{str}]\n"
                end
                if (str = getvariable('mode')) && ! str.empty? then
                    opt << "\\enablemode[#{str}]\n"
                end
                #
                # options
                #
                opt << "\\startsetups *runtime:options\n"
                if str = validbackend(getvariable('backend')) then
                    opt << "\\setupoutput[#{str}]\n"
                elsif str = validbackend(getvariable('output')) then
                    opt << "\\setupoutput[#{str}]\n"
                end
                if getvariable('color') then
                    opt << "\\setupcolors[\\c!state=\\v!start]\n"
                end
                if (str = getvariable('separation')) && ! str.empty? then
                    opt << "\\setupcolors[\\c!split=#{str}]\n"
                end
                if (str = getvariable('paperformat')) && ! str.empty? && ! str.standard? then
                    if str =~ /^([a-z]+\d+)([a-z]+\d+)$/io then # A5A4 A4A3 A2A1 ...
                        opt << "\\setuppapersize[#{$1.upcase}][#{$2.upcase}]\n"
                    else # ...*...
                        pf = str.upcase.split(/[x\*]/o)
                        pf << pf[0] if pf.size == 1
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
                if getvariable('noarrange') then
                    opt << "\\setuparranging[\\v!disable]\n"
                elsif getvariable('arrange') then
                    arrangement = Array.new
                    if finalrun then
                        arrangement << "\\v!doublesided" unless getvariable('noduplex')
                        case getvariable('printformat')
                            when ''         then arrangement << "\\v!normal"
                            when /.*up/oi   then arrangement << ["2UP","\\v!rotated"]
                            when /.*down/oi then arrangement << ["2DOWN","\\v!rotated"]
                            when /.*side/oi then arrangement << ["2SIDE","\\v!rotated"]
                        end
                    else
                        arrangement << "\\v!disable"
                    end
                    opt << "\\setuparranging[#{arrangement.flatten.join(',')}]\n" if arrangement.size > 0
                end
                if (str = getvariable('pages')) && ! str.empty? then
                    if str.downcase == 'odd' then
                        opt << "\\chardef\\whichpagetoshipout=1\n"
                    elsif str.downcase == 'even' then
                        opt << "\\chardef\\whichpagetoshipout=2\n"
                    else
                        pagelist = Array.new
                        str.split(/\,/).each do |page|
                            pagerange = page.split(/\D+/o)
                            if pagerange.size > 1 then
                                pagerange.first.to_i.upto(pagerange.last.to_i) do |p|
                                    pagelist << p.to_s
                                end
                            else
                                pagelist << page
                            end
                        end
                        opt << "\\def\\pagestoshipout\{#{pagelist.join(',')}\}\n";
                    end
                end
                opt << "\\stopsetups\n"
                #
                # styles and modules
                #
                opt << "\\startsetups *runtime:modules\n"
                begin getvariable('filters'     ).split(',').uniq.each do |f| opt << "\\useXMLfilter[#{f}]\n" end ; rescue ; end
                begin getvariable('usemodules'  ).split(',').uniq.each do |m| opt << "\\usemodule   [#{m}]\n" end ; rescue ; end
                begin getvariable('environments').split(',').uniq.each do |e| opt << "\\environment  #{e} \n" end ; rescue ; end
                opt << "\\stopsetups\n"
                #
                opt << "\\protect \\endinput\n"
                #
                opt.close
           else
                report("unable to write option file #{topname}")
            end
        rescue
            report("fatal error in writing option file #{topname} (#{$!})")
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
        done = false
        ['TXRESOURCES','MPRESOURCES','MFRESOURCES'].each do |res|
            [getvariable('runpath'),getvariable('path')].each do |pat|
                unless pat.empty? then
                    if ENV.key?(res) then
                        # ENV[res] = if ENV[res].empty? then pat else pat + ":" + ENV[res] end
if ENV[res].empty? then
    ENV[res] = pat
elsif ENV[res] == pat || ENV[res] =~ /^#{pat}\:/ || ENV[res] =~ /\:#{pat}\:/ then
    # skip
else
    ENV[res] = pat + ":" + ENV[res]
end
                    else
                        ENV[res] = pat
                    end
                    report("setting #{res} to #{ENV[res]}") unless done
                end
            end
            done = true
        end
    end

    def checktestversion
        #
        # one can set TEXMFALPHA and TEXMFBETA for test versions
        # but keep in mind that the format as well as the test files
        # then need the --alpha or --beta flag
        #
        done, tree = false, ''
        ['alpha', 'beta'].each do |what|
            if getvariable(what) then
                if ENV["TEXMF#{what.upcase}"] then
                    done, tree = true, ENV["TEXMF#{what.upcase}"]
                elsif ENV["TEXMFLOCAL"] then
                    done, tree = true, File.join(File.dirname(ENV['TEXMFLOCAL']), "texmf-#{what}")
                end
            end
            break if done
        end
        if done then
            tree = tree.strip
            ENV['TEXMFPROJECT'] = tree
            report("using test tree '#{tree}'")
            ['MP', 'MF', 'TX'].each do |ctx|
                ENV['CTXDEV#{ctx}PATH'] = ''
            end
            unless (FileTest.file?(File.join(tree,'ls-r')) || FileTest.file?(File.join(tree,'ls-R'))) then
                report("no ls-r/ls-R file for tree '#{tree}' (run: mktexlsr #{tree})")
            end
        end
        # puts `kpsewhich --expand-path=$TEXMF`
        # exit
    end

    def runtex(filename)
        checktestversion
        texengine = validtexengine(getvariable('texengine'))
        texformat = validtexformat(getarrayvariable('texformats').first)
        report("tex engine: #{texengine}")
        report("tex format: #{texformat}")
        if texengine && texformat then
            fixbackendvars(@@mappaths[texengine])
            progname = validprogname([getvariable('progname'),texformat,texengine])
            runcommand([quoted(texengine),prognameflag(progname),formatflag(texengine,texformat),runoptions(texengine),filename,texprocextras(texformat)])
        else
            false
        end
    end

    def runmp(mpname,mpx=false)
        checktestversion
        mpsengine = validmpsengine(getvariable('mpsengine'))
        mpsformat = validmpsformat(getarrayvariable('mpsformats').first)
        if mpsengine && mpsformat then
            ENV["MPXCOMMAND"] = "0" unless mpx
            progname = validprogname([getvariable('progname'),mpsformat,mpsengine])
            mpname.gsub!(/\.mp$/,"") # temp bug in mp
            runcommand([quoted(mpsengine),prognameflag(progname),formatflag(mpsengine,mpsformat),runoptions(mpsengine),mpname,mpsprocextras(mpsformat)])
            true
        else
            false
        end
    end

    def runtexmp(filename,filetype='',purge=true)
        checktestversion
        mpname = File.suffixed(filename,filetype,'mp')
        if File.atleast?(mpname,10) then
            # first run needed
            File.silentdelete(File.suffixed(mpname,'mpt'))
            doruntexmp(mpname,nil,true,purge)
            mpgraphics = checkmpgraphics(mpname)
            mplabels = checkmplabels(mpname)
            if mpgraphics || mplabels then
                # second run needed
                doruntexmp(mpname,mplabels,true,purge)
            else
                # no labels
            end
        end
    end

    def runtexmpjob(filename,filetype='')
        checktestversion
        mpname = File.suffixed(filename,filetype,'mp')
        if File.atleast?(mpname,25) && (data = File.silentread(mpname)) then
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
                options.push("--output=ps") # options.push("--dvi")
                options.push("--nobackend")
                return runtexexec(mpname,options,2)
            end
        end
        return false
    end

    def runtexutil(filename=[], options=['--ref','--ij','--high'], old=false)
        [filename].flatten.each do |fname|
            if old then
                Kpse.runscript('texutil',fname,options)
            else
                begin
                    logger = Logger.new('TeXUtil')
                    if tu = TeXUtil::Converter.new(logger) and tu.loaded(fname) then
                        ok = tu.processed && tu.saved && tu.finalized
                    end
                rescue
                    Kpse.runscript('texutil',fname,options)
                end
            end
        end
    end

    # 1=tex 2=mptex 3=mpxtex 4=mpgraphic 5=mpstatic

    def runtexexec(filename=[], options=[], mode=nil)
        begin
            if mode and job = TEX.new(@logger) then
                options.each do |option|
                    case option
                        when /^\-*(.*?)\=(.*)$/o then
                            job.setvariable($1,$2)
                        when /^\-*(.*?)$/o then
                            job.setvariable($1,true)
                    end
                end
                job.setvariable("files",filename)
                case mode
                    when 1 then job.processtex
                    when 2 then job.processmptex
                    when 3 then job.processmpxtex
                    when 4 then job.processmpgraphic
                    when 5 then job.processmpstatic
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
        if backend then
            ENV['backend']     = backend ;
            ENV['progname']    = backend unless validtexengine(backend)
            ENV['TEXFONTMAPS'] = ['.',"\$TEXMF/fonts/{data,map}/{#{backend},pdftex,dvips,}//",'./fonts//'].join_path
            report("fixing backend map path for #{backend}: #{ENV['TEXFONTMAPS']}") if getvariable('verbose')
        else
            report("unable to fix backend map path") if getvariable('verbose')
        end
    end

    def runbackend(rawname)
        unless getvariable('nobackend') then
            case validbackend(getvariable('backend'))
                when 'dvipdfmx' then
                    fixbackendvars('dvipdfm')
                    runcommand("dvipdfmx -d 4 -V 5 #{File.unsuffixed(rawname)}")
                when 'xetex'    then
                    # xetex now runs its own backend
                    xdvfile = File.suffixed(rawname,'xdv')
                    if FileTest.file?(xdvfile) then
                        fixbackendvars('dvipdfm')
                        runcommand("xdvipdfmx -q -d 4 -V 5 -E #{xdvfile}")
                    end
                when 'xdv2pdf' then
                    xdvfile = File.suffixed(rawname,'xdv')
                    if FileTest.file?(xdvfile) then
                        fixbackendvars('xdv2pdf')
                        runcommand("xdv2pdf #{xdvfile}")
                    end
                when 'dvips' then
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
                    runcommand("dvips #{mapfiles} #{File.unsuffixed(rawname)}")
                when 'pdftex'   then
                    # no need for postprocessing
                else
                    report("no postprocessing needed")
            end
        end
    end

    def processfile

        takeprecautions
        report("using search method '#{Kpse.searchmethod}'") if getvariable('verbose')

        rawname    = getvariable('filename')
        jobname    = getvariable('filename')

        if getvariable('autopath') then
            jobname = File.basename(jobname)
            inppath = File.dirname(jobname)
        else
            inppath = ''
        end

        jobname, jobsuffix = File.splitname(jobname,'tex')

        jobname = File.unixfied(jobname)
        inppath = File.unixfied(inppath)

        orisuffix = jobsuffix # still needed ?

        if jobsuffix =~ /^(htm|html|xhtml|xml|fo|fox|rlg|exa)$/io then
            setvariable('forcexml',true)
        end

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
        rawpath = File.dirname(rawname)
        rawbase = File.basename(rawname)

        unless FileTest.file?(rawname) then
            inppath.split(',').each do |ip|
                break if dummyfile = FileTest.file?(File.join(ip,rawname))
            end
        end

        forcexml   = getvariable('forcexml')

        if dummyfile || forcexml then # after ctx?
            jobsuffix = makestubfile(rawname,rawbase,forcexml)
            checkxmlfile(rawname)
        end

        # preprocess files

        unless getvariable('noctx') then
            ctx = CtxRunner.new(rawname,@logger)
            if pth = getvariable('path') then
                pth.split(',').each do |p|
                    ctx.register_path(p)
                end
            end
            if getvariable('ctxfile').empty? then
                if rawname == rawbase then
                    ctx.manipulate(File.suffixed(rawname,'ctx'),'jobname.ctx')
                else
                    ctx.manipulate(File.suffixed(rawname,'ctx'),File.join(rawpath,'jobname.ctx'))
                end
            else
                ctx.manipulate(File.suffixed(getvariable('ctxfile'),'ctx'))
            end
            ctx.savelog(File.suffixed(rawbase,'ctl'))

            envs  = ctx.environments
            mods  = ctx.modules
            flags = ctx.flags
            mdes  = ctx.modes

            flags.each do |f|
                f.sub!(/^\-+/,'')
                if f =~ /^(.*?)=(.*)$/ then
                    setvariable($1,$2)
                else
                    setvariable(f,true)
                end
            end

            report("using flags #{flags.join(' ')}") if flags.size > 0

            # merge environment and module specs

            envs << getvariable('environments') unless getvariable('environments').empty?
            mods << getvariable('usemodules')   unless getvariable('usemodules')  .empty?
            mdes << getvariable('modes')        unless getvariable('modes')       .empty?

            envs = envs.uniq.join(',')
            mods = mods.uniq.join(',')
            mdes = mdes.uniq.join(',')

            report("using search method '#{Kpse.searchmethod}'") if getvariable('verbose')

            report("using environments #{envs}") if envs.length > 0
            report("using modules #{mods}")      if mods.length > 0
            report("using modes #{mdes}")        if mdes.length > 0

            setvariable('environments', envs)
            setvariable('usemodules',   mods)
            setvariable('modes',        mdes)
        end

        # end of preprocessing and merging

        setvariable('nomprun',true) if orisuffix == 'mpx' # else cylic run
        PDFview.setmethod('xpdf') if getvariable('xpdf')
        PDFview.closeall if getvariable('autopdf')

        runonce    = getvariable('once')
        finalrun   = getvariable('final') || (getvariable('arrange') && ! getvariable('noarrange'))
        suffix     = getvariable('suffix')
        result     = getvariable('result')
        globalfile = getvariable('globalfile')
        forcexml   = getvariable('forcexml') # can be set in ctx file

if dummyfile || forcexml then # after ctx?
    jobsuffix = makestubfile(rawname,rawbase,forcexml)
    checkxmlfile(rawname)
end

        result     = File.unixfied(result)

        if globalfile || FileTest.file?(rawname) then

            if not dummyfile and not globalfile and not forcexml then
                scantexpreamble(rawname)
                scantexcontent(rawname) if getvariable('texformats').standard?
            end
            result = File.suffixed(rawname,suffix) unless suffix.empty?

            pushresult(rawbase,result)

            method = validtexmethod(validtexformat(getvariable('texformats')))

            report("tex processing method: #{method}")

            case method

                when 'context' then
                    if getvariable('simplerun') || runonce then
                        makeoptionfile(rawbase,jobname,orisuffix,true,true,3,1) unless getvariable('nooptionfile')
                        ok = runtex(if dummyfile || forcexml then rawbase else rawname end)
                        if ok then
                            ok = runtexutil(rawbase) if getvariable('texutil') || getvariable('forcetexutil')
                            runbackend(rawbase)
                            popresult(rawbase,result)
                        end
                        if getvariable('keep') then
                            ['top','log','run'].each do |suffix|
                                File.silentrename(File.suffixed(rawbase,suffix),File.suffixed(rawbase,suffix+'.keep'))
                            end
                        end
                    else
# goto tmp/jobname when present
                        mprundone, ok, stoprunning = false, true, false
                        texruns, nofruns = 0, getvariable('runs').to_i
                        state = FileState.new
                        ['tub','tuo','tuc'].each do |s|
                            state.register(File.suffixed(rawbase,s))
                        end
                        if getvariable('automprun') then # check this
                            ['mprun','mpgraph'].each do |s|
                                state.register(File.suffixed(rawbase,s,'mp'),'randomseed')
                            end
                        end
                        while ! stoprunning && (texruns < nofruns) && ok do
                            texruns += 1
                            report("TeX run #{texruns}")
                            unless getvariable('nooptionfile') then
                                if texruns == nofruns then
                                    makeoptionfile(rawbase,jobname,orisuffix,false,false,4,texruns) # last
                                elsif texruns == 1 then
                                    makeoptionfile(rawbase,jobname,orisuffix,false,false,1,texruns) # first
                                else
                                    makeoptionfile(rawbase,jobname,orisuffix,false,false,2,texruns) # unknown
                                end
                            end
# goto .

                            ok = runtex(File.suffixed(if dummyfile || forcexml then rawbase else rawname end,jobsuffix))

if getvariable('texengine') == "xetex" then
    ok = true
end

############################

# goto tmp/jobname when present
                            if ok && (nofruns > 1) then
                                unless getvariable('nompmode') then
                                    mprundone = runtexmpjob(rawbase, "mpgraph")
                                    mprundone = runtexmpjob(rawbase, "mprun")
                                end
                                ok = runtexutil(rawbase)
                                state.update
                                stoprunning = state.stable?
                            end
                        end
                        if not ok then
                            setvariable('error','error in tex file')
                        end
                        if (nofruns == 1) && getvariable('texutil') then
                            ok = runtexutil(rawbase)
                        end
                        if ok && finalrun && (nofruns > 1) then
                            makeoptionfile(rawbase,jobname,orisuffix,true,finalrun,4,texruns) unless getvariable('nooptionfile')
                            report("final TeX run #{texruns}")
# goto .
                            ok = runtex(File.suffixed(if dummyfile || forcexml then rawbase else rawname end,jobsuffix))
# goto tmp/jobname when present
                        end
                        if getvariable('keep') then
                            ['top','log','run'].each do |suffix|
                                File.silentrename(File.suffixed(rawbase,suffix),File.suffixed(rawbase,suffix+'.keep'))
                            end
                        else
                            File.silentrename(File.suffixed(rawbase,'top'),File.suffixed(rawbase,'tmp'))
                        end
                        # ['tmp','top','log'].each do |s| # previous tuo file / runtime option file / log file
                             # File.silentdelete(File.suffixed(rawbase,s))
                        # end
                        if ok then
# goto .
                            runbackend(rawbase)
                            popresult(rawbase,result)
# goto tmp/jobname when present
# skip next
                        end
                        if true then # autopurge
                            begin
                                File.open(File.suffixed(rawbase, 'tuo'),'rb') do |f|
                                    ok = 0
                                    f.each do |line|
                                        case ok
                                            when 1 then
                                                # next line is empty
                                                ok = 2
                                            when 2 then
                                                if line =~ /^\%\s+\>\s+(.*?)\s+(\d+)/moi then
                                                    filename, n = $1, $2
                                                    done = File.delete(filename) rescue false
                                                    if done && getvariable('verbose') then
                                                        report("deleting #{filename} (#{n} times used)")
                                                    end
                                                else
                                                    break
                                                end
                                            else
                                                if line =~ /^\%\s+temporary files\:\s+(\d+)/moi then
                                                    if $1.to_i == 0 then
                                                        break
                                                    else
                                                        ok = 1
                                                    end
                                                end
                                        end
                                    end
                                end
                            rescue
                                # report("fatal error #{$!}")
                            end
                        end
                    end

                    Kpse.runscript('ctxtools',rawbase,'--purge')       if getvariable('purge')
                    Kpse.runscript('ctxtools',rawbase,'--purge --all') if getvariable('purgeall')

                    # runcommand('mtxrun','--script','ctxtools',rawbase,'--purge')       if getvariable('purge')
                    # runcommand('mtxrun','--script','ctxtools',rawbase,'--purge --all') if getvariable('purgeall')

                when 'latex' then

                    ok = runtex(rawname)

                else

                    ok = runtex(rawname)

            end

            if (dummyfile or forcexml) and FileTest.file?(rawbase) then
                begin
                    File.delete(File.suffixed(rawbase,'run'))
                rescue
                    report("unable to delete stub file")
                end
            end

            if ok and getvariable('autopdf') then
                PDFview.open(File.suffixed(if result.empty? then rawbase else result end,'pdf'))
            end

        else
            report("nothing to process")
        end

    end

    # The labels are collected in the mergebe hash. Here we merge the relevant labels
    # into beginfig/endfig. We could as well do this in metafun itself. Maybe some
    # day ... (it may cost a bit of string space but that is cheap nowadays).

    def doruntexmp(mpname,mergebe=nil,context=true,purge=true)
        texfound = false
        mpname = File.suffixed(mpname,'mp')
        mpcopy = File.suffixed(mpname,'mp.copy')
        mpkeep = File.suffixed(mpname,'mp.keep')
        setvariable('mp.file',mpname)
        setvariable('mp.line','')
        setvariable('mp.error','')
        if mpdata = File.silentread(mpname) then
        #   mpdata.gsub!(/^\%.*\n/o,'')
            File.silentrename(mpname,mpcopy)
            texfound = mergebe || (mpdata =~ /btex .*? etex/mo)
            if mp = openedfile(mpname) then
                if mergebe then
                    mpdata.gsub!(/beginfig\s*\((\d+)\)\s*\;(.+?)endfig\s*\;/mo) do
                        n, str = $1, $2
                        if str =~ /^(.*?)(verbatimtex.*?etex)\s*\;(.*)$/mo then
                            "beginfig(#{n})\;\n#{$1}#{$2}\;\n#{mergebe[n]}\n#{$3}\;endfig\;\n"
                        else
                            "beginfig(#{n})\;\n#{mergebe[n]}\n#{str}\;endfig\;\n"
                        end
                    end
                    unless mpdata =~ /beginfig\s*\(\s*0\s*\)/o then
                        mp << mergebe['0'] if mergebe.key?('0')
                    end
                end
        #       mp << MPTools::splitmplines(mpdata)
                mp << mpdata
                mp << "\n"
        #        mp << "end"
        #        mp << "\n"
                mp.close
            end
            processmpx(mpname,true,true,purge) if texfound
            if getvariable('batchmode') then
                options = ' --interaction=batch'
            elsif getvariable('nonstopmode') then
                options = ' --interaction=nonstop'
            else
                options = ''
            end
            # todo plain|mpost|metafun
            begin
                ok = runmp(mpname)
            rescue
            end
            if f = File.silentopen(File.suffixed(mpname,'log')) then
                while str = f.gets do
                    if str =~ /^l\.(\d+)\s(.*?)\n/o then
                        setvariable('mp.line',$1)
                        setvariable('mp.error',$2)
                        break
                    end
                end
                f.close
            end
            File.silentrename(mpname, mpkeep)
            File.silentrename(mpcopy, mpname)
        end
    end

    # todo: use internal mptotext function and/or turn all btex/etex into textexts

    def processmpx(mpname,force=false,context=true,purge=true)
        unless force then
            mpname = File.suffixed(mpname,'mp')
            if File.atleast?(mpname,10) && (data = File.silentread(mpname)) then
                if data =~ /(btex|etex|verbatimtex|textext)/o then
                    force = true
                end
            end
        end
        if force then
            begin
                mptex = File.suffixed(mpname,'temp','tex')
                mpdvi = File.suffixed(mpname,'temp','dvi')
                mplog = File.suffixed(mpname,'temp','log')
                mpmpx = File.suffixed(mpname,'mpx')
                File.silentdelete(mptex)
                if true then
                    report("using internal mptotex converter")
                    ok = MPTools::mptotex(mpname,mptex,'context')
                else
                    command = "mpto #{mpname} > #{mptex}"
                    report(command) if getvariable('verbose')
                    ok = system(command)
                end
                # not "ok && ..." because of potential problem with return code and redirect (>)
                if FileTest.file?(mptex) && File.appended(mptex, "\\end\n") then
                    # to be replaced by runtexexec([filenames],options,1)
                    if localjob = TEX.new(@logger) then
                        localjob.setvariable('files',mptex)
                        localjob.setvariable('backend','dvips')
                        localjob.setvariable('engine',getvariable('engine')) unless getvariable('engine').empty?
                        localjob.setvariable('once',true)
                        localjob.setvariable('nobackend',true)
                        if context then
                            localjob.setvariable('texformats',[getvariable('interface')]) unless getvariable('interface').empty?
                        elsif getvariable('interface').empty? then
                            localjob.setvariable('texformats',['plain'])
                        else
                            localjob.setvariable('texformats',[getvariable('interface')])
                        end
                        localjob.processtex
                        ok = true # todo
                    else
                        ok = false
                    end
                    # so far
                    command = "dvitomp #{mpdvi} #{mpmpx}"
                    report(command) if getvariable('verbose')
                    ok = ok && FileTest.file?(mpdvi) && system(command)
                    purge_mpx_files(mpname) if purge
                end
            rescue
                # error in processing mpx file
            end
        end
    end

    def purge_mpx_files(mpname)
        unless getvariable('keep') then
            ['tex', 'log', 'tui', 'tuo', 'tuc', 'top'].each do |suffix|
                File.silentdelete(File.suffixed(mpname,'temp',suffix))
            end
        end
    end

    def checkmpgraphics(mpname)
        # in practice the checksums will differ because of multiple instances
        # ok, we could save the mpy/mpo files by number, but not now
        mpoptions = ''
        if getvariable('makempy') then
            mpoptions += " --makempy "
        end
        mponame = File.suffixed(mpname,'mpo')
        mpyname = File.suffixed(mpname,'mpy')
        pdfname = File.suffixed(mpname,'pdf')
        tmpname = File.suffixed(mpname,'tmp')
        if getvariable('mpyforce') || getvariable('forcempy') then
            mpoptions += " --force "
        else
            return false unless File.atleast?(mponame,32)
            mpochecksum = FileState.new.checksum(mponame)
            return false if mpochecksum.empty?
            # where does the checksum get into the file?
            # maybe let texexec do it?
            # solution: add one if not present or update when different
            begin
                mpydata = IO.read(mpyname)
                if mpydata then
                    if mpydata =~ /^\%\s*mpochecksum\s*\:\s*([A-Z0-9]+)$/mo then
                        checksum = $1
                        if mpochecksum == checksum then
                            return false
                        end
                    end
                end
            rescue
                # no file
            end
        end
        # return Kpse.runscript('makempy',mpname)
        # only pdftex
        flags = ['--noctx','--process','--batch','--once']
        result = runtexexec([mponame], flags, 1)
        runcommand(["pstoedit","-ssp -dt -f mpost", pdfname,tmpname])
        tmpdata = IO.read(tmpname)
        if tmpdata then
            if mpy = openedfile(mpyname) then
                mpy << "% mpochecksum: #{mpochecksum}\n"
                tmpdata.scan(/beginfig(.*?)endfig/mo) do |s|
                    mpy << "begingraphictextfig#{s}endgraphictextfig\n"
                end
                mpy.close()
            end
        end
        File.silentdelete(tmpname)
        File.silentdelete(pdfname)
        return true
    end

    def checkmplabels(mpname)
        mpname = File.suffixed(mpname,'mpt')
        if File.atleast?(mpname,10) && (mp = File.silentopen(mpname)) then
            labels = Hash.new
            while str = mp.gets do
                t = if str =~ /^%\s*setup\s*:\s*(.*)$/o then $1 else '' end
                if str =~ /^%\s*figure\s*(\d+)\s*:\s*(.*)$/o then
                    labels[$1] = labels[$1] || ''
                    unless t.empty? then
                        labels[$1] += "#{t}\n"
                        t = ''
                    end
                    labels[$1] += "#{$2}\n"
                end
            end
            mp.close
            if labels.size>0 then
                return labels
            else
                return nil
            end
        end
        return nil
    end

end

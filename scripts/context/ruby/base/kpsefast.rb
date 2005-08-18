# module    : base/kpsefast
# copyright : PRAGMA Advanced Document Engineering
# version   : 2005
# author    : Hans Hagen
#
# project   : ConTeXt / eXaMpLe
# concept   : Hans Hagen
# info      : j.hagen@xs4all.nl
# www       : www.pragma-ade.com

# todo: multiple cnf files

class File

    def File.locate_file(path,name)
        begin
            files = Dir.entries(path)
            if files.include?(name) then
                fullname = File.join(path,name)
                return fullname if FileTest.file?(fullname)
            end
            files.each do |p|
                fullname = File.join(path,p)
                if p != '.' and p != '..' and FileTest.directory?(fullname) and result = locate_file(fullname,name) then
                    return result
                end
            end
        rescue
            # bad path
        end
        return nil
    end

    def File.glob_file(pattern)
        return Dir.glob(pattern).first
    end

end

class KPSEFAST

    # formats are an incredible inconsistent mess

    @@suffixes  = Hash.new
    @@formats   = Hash.new
    @@suffixmap = Hash.new

    @@suffixes['gf']                       = ['.<resolution>gf'] # todo
    @@suffixes['pk']                       = ['.<resolution>pk'] # todo
    @@suffixes['tfm']                      = ['.tfm']
    @@suffixes['afm']                      = ['.afm']
    @@suffixes['base']                     = ['.base']
    @@suffixes['bib']                      = ['.bib']
    @@suffixes['bst']                      = ['.bst']
    @@suffixes['cnf']                      = ['.cnf']
    @@suffixes['ls-R']                     = ['ls-R', 'ls-r']
    @@suffixes['fmt']                      = ['.fmt', '.efmt', '.efm', '.ofmt', '.ofm', '.oft', '.eofmt', '.eoft', '.eof', '.pfmt', '.pfm', '.epfmt', '.epf', '.xpfmt', '.xpf', '.afmt', '.afm']
    @@suffixes['map']                      = ['.map']
    @@suffixes['mem']                      = ['.mem']
    @@suffixes['mf']                       = ['.mf']
    @@suffixes['mfpool']                   = ['.pool']
    @@suffixes['mft']                      = ['.mft']
    @@suffixes['mp']                       = ['.mp']
    @@suffixes['mppool']                   = ['.pool']
    @@suffixes['ocp']                      = ['.ocp']
    @@suffixes['ofm']                      = ['.ofm', '.tfm']
    @@suffixes['opl']                      = ['.opl']
    @@suffixes['otp']                      = ['.otp']
    @@suffixes['ovf']                      = ['.ovf']
    @@suffixes['ovp']                      = ['.ovp']
    @@suffixes['graphic/figure']           = ['.eps', '.epsi']
    @@suffixes['tex']                      = ['.tex']
    @@suffixes['texpool']                  = ['.pool']
    @@suffixes['PostScript header']        = ['.pro']
    @@suffixes['type1 fonts']              = ['.pfa', '.pfb']
    @@suffixes['vf']                       = ['.vf']
    @@suffixes['ist']                      = ['.ist']
    @@suffixes['truetype fonts']           = ['.ttf', '.ttc']
    @@suffixes['web']                      = ['.web', '.ch']
    @@suffixes['cweb']                     = ['.w', '.web', '.ch']
    @@suffixes['enc files']                = ['.enc']
    @@suffixes['cmap files']               = ['.cmap']
    @@suffixes['subfont definition files'] = ['.sfd']
    @@suffixes['lig files']                = ['.lig']
    @@suffixes['bitmap font']              = []
    @@suffixes['MetaPost support']         = []
    @@suffixes['TeX system documentation'] = []
    @@suffixes['TeX system sources']       = []
    @@suffixes['Troff fonts']              = []
    @@suffixes['dvips config']             = []
    @@suffixes['type42 fonts']             = []
    @@suffixes['web2c files']              = []
    @@suffixes['other text files']         = []
    @@suffixes['other binary files']       = []
    @@suffixes['misc fonts']               = []
    @@suffixes['opentype fonts']           = []
    @@suffixes['pdftex config']            = []
    @@suffixes['texmfscripts']             = []

    # replacements

    @@suffixes['fmt']                      = ['.fmt']
    @@suffixes['type1 fonts']              = ['.pfa', '.pfb', '.pfm']
    @@suffixes['tex']                      = ['.tex', '.xml']
    @@suffixes['texmfscripts']             = ['rb','lua','py','pl']

    @@suffixes.keys.each do |k| @@suffixes[k].each do |s| @@suffixmap[s] = k end end

    # TTF2TFMINPUTS
    # MISCFONTS
    # TEXCONFIG
    # DVIPDFMINPUTS
    # OTFFONTS

    @@formats['gf']                       = ''
    @@formats['pk']                       = ''
    @@formats['tfm']                      = 'TFMFONTS'
    @@formats['afm']                      = 'AFMFONTS'
    @@formats['base']                     = 'MFBASES'
    @@formats['bib']                      = ''
    @@formats['bst']                      = ''
    @@formats['cnf']                      = ''
    @@formats['ls-R']                     = ''
    @@formats['fmt']                      = ''
    @@formats['map']                      = 'TEXFONTMAPS'
    @@formats['mem']                      = 'MPMEMS'
    @@formats['mf']                       = 'MFINPUTS'
    @@formats['mfpool']                   = 'MFPOOL'
    @@formats['mft']                      = ''
    @@formats['mp']                       = 'MPINPUTS'
    @@formats['mppool']                   = 'MPPOOL'
    @@formats['ocp']                      = 'OCPINPUTS'
    @@formats['ofm']                      = 'OFMFONTS'
    @@formats['opl']                      = 'OPLFONTS'
    @@formats['otp']                      = 'OTPINPUTS'
    @@formats['ovf']                      = 'OVFFONTS'
    @@formats['ovp']                      = 'OVPFONTS'
    @@formats['graphic/figure']           = ''
    @@formats['tex']                      = 'TEXINPUTS'
    @@formats['texpool']                  = 'TEXPOOL'
    @@formats['PostScript header']        = 'TEXPSHEADERS'
    @@formats['type1 fonts']              = 'T1FONTS'
    @@formats['vf']                       = 'VFFONTS'
    @@formats['ist']                      = ''
    @@formats['truetype fonts']           = 'TTFONTS'
    @@formats['web']                      = ''
    @@formats['cweb']                     = ''
    @@formats['enc files']                = 'ENCFONTS'
    @@formats['cmap files']               = 'CMAPFONTS'
    @@formats['subfont definition files'] = 'SFDFONTS'
    @@formats['lig files']                = 'LIGFONTS'
    @@formats['bitmap font']              = ''
    @@formats['MetaPost support']         = ''
    @@formats['TeX system documentation'] = ''
    @@formats['TeX system sources']       = ''
    @@formats['Troff fonts']              = ''
    @@formats['dvips config']             = ''
    @@formats['type42 fonts']             = 'T42FONTS'
    @@formats['web2c files']              = 'WEB2C'
    @@formats['other text files']         = ''
    @@formats['other binary files']       = ''
    @@formats['misc fonts']               = ''
    @@formats['opentype fonts']           = 'OPENTYPEFONTS'
    @@formats['pdftex config']            = 'PDFTEXCONFIG'
    @@formats['texmfscripts']             = 'TEXMFSCRIPTS'

    attr_accessor :progname, :engine, :format, :rootpath, :treepath,
        :verbose, :remember, :scandisk, :diskcache, :renewcache

    @@cacheversion = '1'

    def initialize
        @rootpath   = ''
        @treepath   = ''
        @progname   = 'kpsewhich'
        @engine     = 'pdfetex'
        @variables  = Hash.new
        @expansions = Hash.new
        @files      = Hash.new
        @found      = Hash.new
        @kpsevars   = Hash.new
        @lsrfiles   = Array.new
        @cnffiles   = Array.new
        @verbose    = true
        @remember   = true
        @scandisk   = true
        @diskcache  = true
        @renewcache = false
        @isolate    = false

        @diskcache  = false
        @cachepath  = nil
        @cachefile  = 'tmftools.log'
    end

    # {$SELFAUTOLOC,$SELFAUTODIR,$SELFAUTOPARENT}{,{/share,}/texmf{-local,}/web2c}
    #
    # $SELFAUTOLOC    : /usr/tex/bin/platform
    # $SELFAUTODIR    : /usr/tex/bin
    # $SELFAUTOPARENT : /usr/tex
    #
    # since we live in scriptpath we need a slightly different method

    def load_cnf
        ownpath = File.expand_path($0)
        if ownpath.gsub!(/texmf.*?$/o, '') then
            ENV['SELFAUTOPARENT'] = ownpath
        else
            ENV['SELFAUTOPARENT'] = '.'
        end
        unless @treepath.empty? then
            unless @rootpath.empty? then
                @treepath = @treepath.split(',').collect do |p| File.join(@rootpath,p) end.join(',')
            end
            ENV['TEXMF'] = @treepath
            ENV['TEXMFCNF'] = File.join(@treepath.split(',').first,'texmf/web2c')
        end
        unless @rootpath.empty? then
            ENV['TEXMFCNF'] = File.join(@rootpath,'texmf/web2c')
            ENV['SELFAUTOPARENT'] = @rootpath
            @isolate = true
        end
        filenames = Array.new
        if ENV['TEXMFCNF'] and not ENV['TEXMFCNF'].empty? then
            filenames << File.join(ENV['TEXMFCNF'],'texmf.cnf')
        elsif ENV['SELFAUTOPARENT'] == '.' then
            filenames << File.join('.','texmf.cnf')
        else
            ['texmf-local','texmf'].each do |tree|
                filenames << File.join(ENV['SELFAUTOPARENT'],tree,'web2c','texmf.cnf')
            end
        end
        # <root>/texmf/web2c/texmf.cnf
        @rootpath = filenames.first
        3.times do
            @rootpath = File.dirname(@rootpath)
        end
        filenames.collect! do |f|
            f.gsub("\\", '/')
        end
        filenames.each do |fname|
            if FileTest.file?(fname) and f = File.open(fname) then
                @cnffiles << fname
                while line = f.gets do
                    loop do
                        # concatenate lines ending with \
                        break unless line.sub!(/\\\s*$/o) do
                            f.gets || ''
                        end
                    end
                    case line
                        when /^[\%\#]/o then
                            # comment
                        when /^\s*(.*?)\s*\=\s*(.*?)\s*$/o then
                            key, value = $1, $2
                            unless @variables.key?(key) then
                                value.sub!(/\%.*$/,'')
                                value.sub!(/\~/, "$HOME")
                                @variables[key] = value
                            end
                            @kpsevars[key] = true
                    end
                end
                f.close
            end
        end
    end

    def load_lsr
        @lsrfiles = []
        simplified_list(expansion('TEXMF')).each do |p|
            ['ls-R','ls-r'].each do |f|
                filename = File.join(p,f)
                if FileTest.file?(filename) then
                    @lsrfiles << [filename,File.size(filename)]
                    break
                end
            end
        end
        @files = Hash.new
        if @diskcache then
            ['HOME','TEMP','TMP','TMPDIR'].each do |key|
                if ENV[key] then
                    if FileTest.directory?(ENV[key]) then
                        @cachepath = ENV[key]
                        @cachefile = [@rootpath.gsub(/[^A-Z0-9]/io, '-').gsub(/\-+/,'-'),File.basename(@cachefile)].join('-')
                        break
                    end
                end
            end
            if @cachepath and not @renewcache and FileTest.file?(File.join(@cachepath,@cachefile)) then
                begin
                    if f = File.open(File.join(@cachepath,@cachefile)) then
                        cacheversion = Marshal.load(f)
                        if cacheversion == @@cacheversion then
                            lsrfiles = Marshal.load(f)
                            if lsrfiles == @lsrfiles then
                                @files = Marshal.load(f)
                            end
                        end
                        f.close
                    end
                rescue
                   @files = Hash.new
               end
            end
        end
        return if @files.size > 0
        @lsrfiles.each do |filedata|
            filename, filesize = filedata
            filepath = File.dirname(filename)
            begin
                path = '.'
                data = IO.readlines(filename)
                if data[0].chomp =~ /% ls\-R \-\- filename database for kpathsea\; do not change this line\./io then
                    data.each do |line|
                        case line
                            when /^[a-zA-Z0-9]/o then
                                line.chomp!
                                if @files[line] then
                                    @files[line] << path
                                else
                                    @files[line] = [path]
                                end
                            when /^\.\/(.*?)\:$/o then
                                path = File.join(filepath,$1)
                        end
                    end
                end
            rescue
                # sorry
            end
        end
        if @diskcache and @cachepath and f = File.open(File.join(@cachepath,@cachefile),'wb') then
            f << Marshal.dump(@@cacheversion)
            f << Marshal.dump(@lsrfiles)
            f << Marshal.dump(@files)
            f.close
        end
    end

    def expand_variables
        @expansions = Hash.new
        if @isolate then
            @variables['TEXMFCNF'] = ENV['TEXMFCNF'].dup
            @variables['SELFAUTOPARENT'] = ENV['SELFAUTOPARENT'].dup
        else
            ENV.keys.each do |e|
                if e =~ /^([a-zA-Z]+)\_(.*)\s*$/o then
                    @expansions["#{$1}.#{$2}"] = ENV[e].dup
                else
                    @expansions[e] = ENV[e].dup
                end
            end
        end
        @variables.keys.each do |k|
            @expansions[k] = @variables[k].dup unless @expansions[k]
        end
        loop do
            busy = false
            @expansions.keys.each do |k|
                @expansions[k].gsub!(/\$([a-zA-Z0-9\_\-]*)/o) do
                    busy = true
                    @expansions[$1] || ''
                end
                @expansions[k].gsub!(/\$\{([a-zA-Z0-9\_\-]*)\}/o) do
                    busy = true
                    @expansions[$1] || ''
                end
            end
            break unless busy
        end
        @expansions.keys.each do |k|
            @expansions[k] = @expansions[k].gsub("\\", '/')
        end
    end

    def variable(name='')
        (name and not name.empty? and @variables[name.sub('$','')]) or  ''
    end

    def expansion(name='')
        (name and not name.empty? and @expansions[name.sub('$','')]) or ''
    end

    def variable?(name='')
        name and not name.empty? and @variables.key?(name.sub('$',''))
    end

    def expansion?(name='')
        name and not name.empty? and @expansions.key?(name.sub('$',''))
    end

    def simplified_list(str)
        lst = str.gsub(/^\{/o,'').gsub(/\}$/o,'').split(",")
        lst.collect do |l|
            l.sub(/^[\!]*/,'').sub(/[\/\\]*$/o,'')
        end
    end

    def original_variable(variable)
        if variable?("#{@progname}.#{variable}") then
            variable("#{@progname}.#{variable}")
        elsif variable?(variable) then
            variable(variable)
        else
            ''
        end
    end

    def expanded_variable(variable)
        if expansion?("#{variable}.#{@progname}") then
            expansion("#{variable}.#{@progname}")
        elsif expansion?(variable) then
            expansion(variable)
        else
            ''
        end
    end

    def original_path(filename='')
        _expanded_path_(original_variable(var_of_format_or_suffix(filename)).split(";"))
    end

    def expanded_path(filename='')
        _expanded_path_(expanded_variable(var_of_format_or_suffix(filename)).split(";"))
    end

    def _expanded_path_(pathlist)
        i, n = 0, 0
        pathlist.collect! do |mainpath|
            mainpath.gsub(/([\{\}])/o) do
                if $1 == "{" then
                    i += 1 ; n = i if i > n ; "<#{i}>"
                else
                    i -= 1 ; "</#{i+1}>"
                end
            end
        end
        n.times do |i|
            loop do
                more = false
                newlist = []
                pathlist.each do |path|
                    unless path.sub!(/^(.*?)<(#{n-i})>(.*?)<\/\2>(.*?)$/) do
                        pre, mid, post = $1, $3, $4
                        mid.gsub!(/\,$/,',.')
                        mid.split(',').each do |m|
                            more = true
                            if m == '.' then
                                newlist << "#{pre}#{post}"
                            else
                                newlist << "#{pre}#{m}#{post}"
                            end
                        end
                    end then
                        newlist << path
                    end
                end
                if more then
                    pathlist = [newlist].flatten # copy -)
                else
                    break
                end
            end
        end
        pathlist = pathlist.uniq.collect do |path|
            p = path.gsub(/^\/+/o) do '' end
            # p.gsub!(/(.)\/\/(.)/o) do "#{$1}/#{$2}" end
            # p.gsub!(/\/\/+$/o) do '//' end
            p.gsub!(/\/\/+/o) do '//' end
            p
        end
        pathlist
    end

    # todo: ignore case

    def var_of_format(str)
        @@formats[str] || ''
    end

    def var_of_suffix(str) # includes .
        if @@suffixmap.key?(str) then @@formats[@@suffixmap[str]] else '' end
    end

    def var_of_format_or_suffix(str)
        if @@formats.key?(@format) then
            @@formats[@format]
        elsif @@suffixmap.key?(File.extname(str)) then # extname includes .
            @@formats[@@suffixmap[File.extname(str)]]  # extname includes .
        else
            ''
        end
    end

end

class KPSEFAST

    # test things

    def list_variables(kpseonly=true)
        @variables.keys.sort.each do |k|
            if kpseonly then
                puts("#{k} = #{@variables[k]}") if @kpsevars[k]
            else
                puts("#{if @kpsevars[k] then 'K' else 'E' end} #{k} = #{@variables[k]}")
            end
        end
    end

    def list_expansions(kpseonly=true)
        @expansions.keys.sort.each do |k|
            if kpseonly then
                puts("#{k} = #{@expansions[k]}") if @kpsevars[k]
            else
                puts("#{if @kpsevars[k] then 'K' else 'E' end} #{k} = #{@expansions[k]}")
            end
        end
    end

    def list_lsr
        puts("files = #{@files.size}")
    end

    def set_test_patterns
        @variables["KPSE_TEST_PATTERN_A"] = "foo/{1,2}/bar//"
        @variables["KPSE_TEST_PATTERN_B"] = "!!x{A,B{1,2}}y"
        @variables["KPSE_TEST_PATTERN_C"] = "x{A,B//{1,2}}y"
        @variables["KPSE_TEST_PATTERN_D"] = "x{A,B//{1,2,}}//y"
    end

    def show_test_patterns
        ['A','B','D'].each do |i|
            puts ""
            puts @variables ["KPSE_TEST_PATTERN_#{i}"]
            puts ""
            puts expand_path("KPSE_TEST_PATTERN_#{i}").split(File::PATH_SEPARATOR)
            puts ""
        end
    end

end

class KPSEFAST

    # kpse stuff

    def expand_braces(str) # output variable and brace expansion of STRING.
        _expanded_path_(original_variable(str).split(";")).join(File::PATH_SEPARATOR)
    end

    def expand_path(str)   # output complete path expansion of STRING.
        _expanded_path_(expanded_variable(str).split(";")).join(File::PATH_SEPARATOR)
    end

    def expand_var(str)    # output variable expansion of STRING.
        expanded_variable(str)
    end

    def show_path(str)     # output search path for file type NAME
        expanded_path(var_of_format(str)).join(File::PATH_SEPARATOR)
    end

    def var_value(str)     # output the value of variable $STRING.
        original_variable(str)
    end

end

class KPSEFAST

    def find_file(filename)
        find_files(filename,true)
    end

    def find_files(filename,first=false)
        if @remember then
            stamp = "#{filename}--#{@format}--#{@engine}--#{@progname}"
            return @found[stamp] if @found.key?(stamp)
        end
        pathlist = expanded_path(filename)
        result = []
        filelist = if @files.key?(filename) then @files[filename].uniq else nil end
        done = false
        pathlist.each do |path|
            doscan = if path =~ /^\!\!/o then false else true end
            recurse = if path =~ /\/\/$/o then true else false end
            pathname = path.dup
            pathname.gsub!(/^\!+/o, '')
            done = false
            if not done and filelist then
                # checking for exact match
                if filelist.include?(pathname) then
                    result << pathname
                    done = true
                end
                if not done and recurse then
                    # checking for fuzzy //
                    pathname.gsub!(/\/+$/o, '/.*')
                    # pathname.gsub!(/\/\//o,'/[\/]*/')
                    pathname.gsub!(/\/\//o,'/.*?/')
                    re = /^#{pathname}/
                    filelist.each do |f|
                        if re =~ f then
                            result << f # duplicates will be filtered later
                            done = true
                        end
                        break if done
                    end
                end
            end
            if not done and doscan then
                # checking for path itself
                pname = pathname.sub(/\.\*$/,'')
                if not pname =~ /\*/o and FileTest.file?(File.join(pname,filename)) then
                    result << pname
                    done = true
                end
            end
            break if done and first
        end
        if not done and @scandisk then
            pathlist.each do |path|
                pathname = path.dup
                unless pathname.gsub!(/^\!+/o, '') then # !! prevents scan
                    recurse = pathname.gsub!(/\/+$/o, '')
                    complex = pathname.gsub!(/\/\//o,'/*/')
                    if recurse then
                        if complex then
                            if ok = File.glob_file("#{pathname}/**/#{filename}") then
                                result << File.dirname(ok)
                                done = true
                            end
                        elsif ok = File.locate_file(pathname,filename) then
                            result << File.dirname(ok)
                            done = true
                        end
                    elsif complex then
                        if ok = File.glob_file("#{pathname}/#{filename}") then
                            result << File.dirname(ok)
                            done = true
                        end
                    elsif FileTest.file?(File.join(pathname,filename)) then
                        result << pathname
                        done = true
                    end
                    break if done and first
                end
            end
        end
        result = result.uniq.collect do |pathname|
            File.join(pathname,filename)
        end
        @found[stamp] = result if @remember
        return result # redundant
    end

end

class KPSEFAST

    class FileData
        attr_accessor :tag, :name, :size, :date
        def initialize(tag=0,name=nil,size=nil,date=nil)
            @tag, @name, @size, @date = tag, name, size, date
        end
        def FileData.sizes(a)
            a.collect do |aa|
                aa.size
            end
        end
        def report
            case @tag
                when 1
                    "deleted  | #{@size.to_s.rjust(8)} | #{@date.strftime('%m/%d/%Y %I:%M')} | #{@name}"
                when 2
                    "present  | #{@size.to_s.rjust(8)} | #{@date.strftime('%m/%d/%Y %I:%M')} | #{@name}"
                when 3
                    "obsolete | #{' '*8} | #{' '*16} | #{@name}"
            end
        end
    end

    def analyze_files(filter='',strict=false,sort='',delete=false)
        puts("command line     = #{ARGV.join(' ')}")
        puts("number of files  = #{@files.size}")
        puts("filter pattern   = #{filter}")
        puts("loaded cnf files = #{@cnffiles.join(' ')}")
        puts('')
        if filter.gsub!(/^not:/,'') then
            def the_same(filter,filename)
                not filter or filter.empty? or /#{filter}/ !~ filename
            end
        else
            def the_same(filter,filename)
                not filter or filter.empty? or /#{filter}/ =~ filename
            end
        end
        @files.keys.each do |name|
            if @files[name].size > 1 then
                data = Array.new
                @files[name].each do |path|
                    filename = File.join(path,name)
                    # if not filter or filter.empty? or /#{filter}/ =~ filename then
                    if the_same(filter,filename) then
                        if FileTest.file?(filename) then
                            if delete then
                                data << FileData.new(1,filename,File.size(filename),File.mtime(filename))
                                begin
                                    File.delete(filename) if delete
                                rescue
                                end
                            else
                                data << FileData.new(2,filename,File.size(filename),File.mtime(filename))
                            end
                        else
                            data << FileData.new(3,filename)
                        end
                    end
                end
                if data.length > 1 then
                    if strict then
                        # if data.collect do |d| d.size end.uniq! then
                            # data.sort! do |a,b| b.size <=> a.size end
                            # data.each do |d| puts d.report end
                            # puts ''
                        # end
                        data.sort! do |a,b| b.size <=> a.size end
                        bunch = Array.new
                        done = false
                        data.each do |d|
                            if bunch.size == 0 then
                                bunch << d
                            elsif bunch[0].size == d.size then
                                bunch << d
                            else
                                if bunch.size > 1 then
                                    bunch.each do |b|
                                        puts b.report
                                    end
                                    done = true
                                end
                                bunch = [d]
                            end
                        end
                        puts '' if done
                    else
                        case sort
                            when 'size'    then data.sort! do |a,b| a.size <=> b.size end
                            when 'revsize' then data.sort! do |a,b| b.size <=> a.size end
                            when 'date'    then data.sort! do |a,b| a.date <=> b.date end
                            when 'revdate' then data.sort! do |a,b| b.date <=> a.date end
                        end
                        data.each do |d| puts d.report end
                        puts ''
                    end
                end
            end
        end
    end

end

module KpseRunner

    @@kpse = nil

    def KpseRunner.kpsewhich(arg='')
        options, arguments = split_args(arg)
        unless @@kpse then
            @@kpse = KPSEFAST.new
            @@kpse.load_cnf
            @@kpse.progname = options['progname'] || ''
            @@kpse.engine   = options['engine']   || ''
            @@kpse.format   = options['format']   || ''
            @@kpse.expand_variables
            @@kpse.load_lsr
        else
            @@kpse.progname = options['progname'] || ''
            @@kpse.engine   = options['engine']   || ''
            @@kpse.format   = options['format']   || ''
            @@kpse.expand_variables
        end
        if    option = options['expand-braces'] and not option.empty? then
            @@kpse.expand_braces(option)
        elsif option = options['expand-path']   and not option.empty? then
            @@kpse.expand_path(option)
        elsif option = options['expand-var']    and not option.empty? then
            @@kpse.expand_var(option)
        elsif option = options['show-path']     and not option.empty? then
            @@kpse.show_path(option)
        elsif option = options['var-value']     and not option.empty? then
            @@kpse.expand_var(option)
        elsif arguments.size > 0 then
            files = Array.new
            arguments.each do |option|
                if file = @@kpse.find_file(option) and not file.empty? then
                    files << file
                end
            end
            files.join("\n")
        else
            ''
        end
    end

    def KpseRunner.kpsereset
        @@kpse = nil
    end

    private

    def KpseRunner.split_args(arg)
        vars, args = Hash.new, Array.new
        arg.gsub!(/([\"\'])(.*?)\1/o) do
            $2.gsub(' ','<space/>')
        end
        arg = arg.split(/\s+/o)
        arg.collect! do |a|
            a.gsub('<space/>',' ')
        end
        arg.each do |a|
            if a =~ /^(.*?)\=(.*?)$/o then
                k, v = $1, $2
                vars[k.sub(/^\-+/,'')] = v
            else
                args << a
            end
        end
        # puts vars.inspect
        # puts args.inspect
        return vars, args
    end

end

if false then

    k = KPSEFAST.new # (root)
    k.set_test_patterns
    k.load_cnf
    k.expand_variables
    k.load_lsr

    k.show_test_patterns
    # puts k.list_variables
    # puts k.list_expansions
    # k.list_lsr
    # puts k.expansion("$TEXMF")
    # puts k.expanded_path("TEXINPUTS","context")

    # k.progname, k.engine, k.format = 'context', 'pdfetex', 'tfm'
    # k.scandisk = false # == must_exist
    # k.expand_variables

    # 10.times do |i| puts k.find_file('texnansi-lmr10.tfm') end

    # puts "expand braces $TEXMF"
    # puts k.expand_braces("$TEXMF")
    # puts "expand path $TEXMF"
    # puts k.expand_path("$TEXMF")
    # puts "expand var $TEXMF"
    # puts k.expand_var("$TEXMF")
    # puts "expand path $TEXMF"
    # puts k.show_path('tfm')
    # puts "expand value $TEXINPUTS"
    # puts k.var_value("$TEXINPUTS")
    # puts "expand value $TEXINPUTS.context"
    # puts k.var_value("$TEXINPUTS.context")

    exit

end

require "base/file"
require "base/logger"

class String

    # real dirty, but inspect does a pretty good escaping but
    # unfortunately puts quotes around the string so we need
    # to strip these

    # def escaped
    #     self.inspect[1,self.inspect.size-2]
    # end

    def escaped
        str = self.inspect ; str[1,str.size-2]
    end

    def splitdata
        if self =~ /^\s*(.*?)\s*\{(.*)\}\s*$/o then
            first, second = $1, $2
            if first.empty? then
                [second.split(/\} \{/o)].flatten
            else
                [first.split(/\s+/o)] + [second.split(/\} \{/o)]
            end
        else
            []
        end
    end

end

class Logger
    def banner(str)
        report(str)
        return "%\n% #{str}\n%\n"
    end
end

class TeXUtil

    class Plugin

        # we need to reset module data for each run; persistent data is
        # possible, just don't reinitialize the data structures that need
        # to be persistent; we reset afterwards becausethen we know what
        # plugins are defined

        def initialize(logger)
            @plugins = Array.new
            @logger = logger
        end

        def report(str)
            @logger.report("fatal error in plugin (#{str}): #{$!}")
            puts("\n")
            $@.each do |line|
                puts("  #{line}")
            end
            puts("\n")
        end

        def reset(name)
            if @plugins.include?(name) then
                begin
                    eval("#{name}").reset(@logger)
                rescue Exception
                    report("resetting")
                end
            else
               @logger.report("no plugin #{name}")
            end
        end

        def resets
            @plugins.each do |p|
                reset(p)
            end
        end

        def register(name, file=nil) # maybe also priority
            if file then
                begin
                    require("#{file.downcase.sub(/\.rb$/,'')}.rb")
                rescue Exception
                    @logger.report("no plugin file #{file} for #{name}")
                else
                    @plugins.push(name)
                end
            else
                @plugins.push(name)
            end
            return self
        end

        def reader(name, data=[])
            if @plugins.include?(name) then
                begin
                    eval("#{name}").reader(@logger,data.flatten)
                rescue Exception
                    report("reading")
                end
            else
               @logger.report("no plugin #{name}")
            end
        end

        def readers(data=[])
            @plugins.each do |p|
                reader(p,data.flatten)
            end
        end

        def writers(handle)
            @plugins.each do |p|
                begin
                    eval("#{p}").writer(@logger,handle)
                rescue Exception
                    report("writing")
                end
            end
        end

        def processors
            @plugins.each do |p|
                begin
                    eval("#{p}").processor(@logger)
                rescue Exception
                    report("processing")
                end
            end
        end

        def finalizers
            @plugins.each do |p|
                begin
                    eval("#{p}").finalizer(@logger)
                rescue Exception
                    report("finalizing")
                end
            end
        end

    end

    class Sorter

        @@downcase = true

        def initialize(max=12)
            @rep, @map, @exp, @div = Hash.new, Hash.new, Hash.new, Hash.new
            @max = max
            @rexa, @rexb = nil, nil
        end

        def replacer(from,to='') # and expand
            @max = [@max,to.length+1].max if to
            @rep[from.escaped] = to || ''
        end

        # sorter.reducer('ch', 'c')
        # sorter.reducer('ij', 'y')

        def reducer(from,to='')
            @max = [@max,to.length+1].max if to
            @map[from] = to || ''
        end

        # sorter.expander('aeligature', 'ae')
        # sorter.expander('ijligature', 'y')

        def expander(from,to=nil)
            to = converted(to) # not from !!!
            @max = [@max,to.length+1].max if to
            @exp[from] = to || from || ''
        end

        def division(from,to=nil)
            from, to = converted(from), converted(to)
            @max = [@max,to.length+1].max if to
            @div[from] = to || from || ''
        end

        # shortcut("\\ab\\cd\\e\\f", 'iacute')
        # shortcut("\\\'\\i", 'iacute')
        # shortcut("\\\'i", 'iacute')
        # shortcut("\\\"e", 'ediaeresis')
        # shortcut("\\\'o", 'oacute')

        def hextoutf(str)
            str.gsub(/^(0x[A-F\d]+)$/) do
                [$1.hex()].pack("U")
            end
        end

        def shortcut(from,to)
            from = hextoutf(from)
            replacer(from,to)
            expander(to)
        end

        def prepare
            if @rep.size > 0 then
                @rexa = /(#{@rep.keys.join('|')})/ # o
            else
                @rexa = nil
            end
            if @map.size > 0 then
                # watch out, order of match matters
                if @@downcase then
                    @rexb = /(\\[a-zA-Z]+|#{@map.keys.join('|')}|.)\s*/i # o
                else
                    @rexb = /(\\[a-zA-Z]+|#{@map.keys.join('|')}|.)\s*/ # o
                end
            else
                if @@downcase then
                    @rexb = /(\\[a-zA-Z]+|.)\s*/io
                else
                    @rexb = /(\\[a-zA-Z]+|.)\s*/o
                end
            end
            if false then
                @exp.keys.each do |e|
                    @exp[e].downcase!
                end
            end
        end

        def replace(str)
            if @rexa then
                str.gsub(@rexa) do
                    @rep[$1.escaped]
                end
            else
                str
            end
        end

        def normalize(str)
            # replace(str).gsub(/ +/,' ')
            replace(str).gsub(/\s\s+/," \\space")
        end

        def tokenize(str)
            if str then
                str.gsub(/\\strchr\{(.*?)\}/o) do "\\#{$1}" end
            else
                ""
            end
        end

        def remap(str)
            s = str.dup
            if true then # numbers are treated special
                s.gsub!(/(\d+)/o) do
                    $1.rjust(10,'a') # rest is b .. k
                end
            end
            if @rexa then
                s.gsub!(@rexa) do
                    @rep[$1.escaped]
                end
            end
            if @rexb then
                s.gsub!(@rexb) do
                    token = $1.sub(/\\/o, '')
                    if @@downcase then
                        token.downcase!
                    end
                    if @exp.key?(token) then
                        @exp[token].ljust(@max,' ')
                    elsif @map.key?(token) then
                        @map[token].ljust(@max,' ')
                    else
                        ''
                    end
                end
            end
            s
        end

        def preset(shortcuts=[],expansions=[],reductions=[],divisions=[],language='')
            'a'.upto('z') do |c| expander(c) ; division(c) end
            'A'.upto('Z') do |c| expander(c) ; division(c) end
            expander('1','b') ; expander('2','c') ; expander('3','e') ; expander('4','f')
            expander('5','g') ; expander('6','h') ; expander('7','i') ; expander('8','i')
            expander('9','j') ; expander('0','a') ; expander('-','-') ;
            shortcuts.each  do |s| shortcut(s[1],s[2]) if s[0] == '' || s[0] == language end
            expansions.each do |e| expander(e[1],e[2]) if e[0] == '' || e[0] == language end
            reductions.each do |r|  reducer(r[1],r[2]) if r[0] == '' || r[0] == language end
            divisions.each  do |d| division(d[1],d[2]) if d[0] == '' || d[0] == language end
        end

        def simplify(str)
            s = str.dup
            # ^^
            # s.gsub!(/\^\^([a-f0-9][a-f0-9])/o, $1.hex.chr)
            # \- ||
            s.gsub!(/(\\\-|\|\|)/o) do '-' end
            # {}
            s.gsub!(/\{\}/o) do '' end
            # <*..> (internal xml entity)
            s.gsub!(/<\*(.*?)>/o) do $1 end
            # entities
            s.gsub!(/\\getXMLentity\s*\{(.*?)\}/o) do $1 end
            # elements
            s.gsub!(/\<.*?>/o) do '' end
            # what to do with xml and utf-8
            # \"e etc
            # unknown \cs
            s.gsub!(/\\[a-zA-Z][a-zA-Z]+\s*\{(.*?)\}/o) do $1 end
            return s
        end

        def getdivision(str)
            @div[str] || str
        end

        def division?(str)
            @div.key?(str)
        end

        private

        def converted(str)
            if str then
                # puts str
                str.gsub(/([\+\-]*\d+)/o) do
                    n = $1.to_i
                    if n > 0 then
                        'z'*n
                    elsif n < 0 then
                        '-'*(-n) # '-' precedes 'a'
                    else
                        ''
                    end
                end
            else
                nil
            end
        end

    end

    class Plugin

        module MyFiles

            @@files, @@temps = Hash.new, Hash.new

            def MyFiles::reset(logger)
                @@files, @@temps = Hash.new, Hash.new
            end

            def MyFiles::reader(logger,data)
                case data[0]
                    when 'b', 'e' then
                        @@files[data[1]] = (@@files[data[1]] ||0) + 1
                    when 't' then # temporary file
                        @@temps[data[1]] = (@@temps[data[1]] ||0) + 1
                end
            end

            def MyFiles::writer(logger,handle)
                handle << logger.banner("loaded files: #{@@files.size}")
                @@files.keys.sort.each do |k|
                    handle << "% > #{k} #{@@files[k]/2}\n"
                end
                handle << logger.banner("temporary files: #{@@temps.size}")
                @@temps.keys.sort.each do |k|
                    handle << "% > #{k} #{@@temps[k]}\n"
                end
            end

            def MyFiles::processor(logger)
                @@files.keys.sort.each do |k|
                    unless (@@files[k] % 2) == 0 then
                        logger.report("check loading of file '#{k}', begin/end problem")
                    end
                end
                @@temps.keys.sort.each do |k|
                    # logger.report("temporary file '#{k}' can be deleted")
                end
            end

            def MyFiles::finalizer(logger)
            end

        end

    end

    class Plugin

        module MyCommands

            @@commands = []

            def MyCommands::reset(logger)
                @@commands = []
            end

            def MyCommands::reader(logger,data)
                @@commands.push(data.shift+data.collect do |d| "\{#{d}\}" end.join)
            end

            def MyCommands::writer(logger,handle)
                handle << logger.banner("commands: #{@@commands.size}")
                @@commands.each do |c|
                    handle << "#{c}%\n"
                end
            end

            def MyCommands::processor(logger)
            end

            def MyCommands::finalizer(logger)
            end

        end

    end

    class Plugin

        module MyExtras

            @@programs = []

            def MyExtras::reset(logger)
                @@programs = []
            end

            def MyExtras::reader(logger,data)
                case data[0]
                    when 'p' then
                        @@programs.push(data[1]) if data[0]
                end
            end

            def MyExtras::writer(logger,handle)
                handle << logger.banner("programs: #{@@programs.size}")
                @@programs.each_with_index do |cmd, p|
                    handle << "% #{p+1} (#{cmd})\n"
                end
            end

            def MyExtras::processor(logger)
                @@programs.each do |p|
                    # cmd = @@programs[p.to_i]
                    # logger.report("running #{cmd}")
                    # system(cmd)
                end
            end

            def MyExtras::finalizer(logger)
                unless (ENV["CTX.TEXUTIL.EXTRAS"] =~ /^(no|off|false|0)$/io) || (ENV["CTX_TEXUTIL_EXTRAS"] =~ /^(no|off|false|0)$/io) then
                    @@programs.each do |cmd|
                        logger.report("running #{cmd}")
                        system(cmd)
                    end
                end
            end

        end

    end

    class Plugin

        module MySynonyms

            class Synonym

                @@debug = false

                def initialize(t, c, k, d)
                    @type, @command, @key, @sortkey, @data = t, c, k, c, d
                end

                attr_reader :type, :command, :key, :data
                attr_reader :sortkey
                attr_writer :sortkey

                # def build(sorter)
                    # if @key then
                        # @sortkey = sorter.normalize(sorter.tokenize(@sortkey))
                        # @sortkey = sorter.remap(sorter.simplify(@key.downcase)) # ??
                        # if @sortkey.empty? then
                            # @sortkey = sorter.remap(@command.downcase)
                        # end
                    # else
                        # @key = ""
                        # @sortkey = ""
                    # end
                # end

                def build(sorter)
                    if @sortkey and not @sortkey.empty? then
                        @sortkey = sorter.normalize(sorter.tokenize(@sortkey))
                        @sortkey = sorter.remap(sorter.simplify(@sortkey.downcase)) # ??
                    end
                    if not @sortkey or @sortkey.empty? then
                        @sortkey = sorter.normalize(sorter.tokenize(@key))
                        @sortkey = sorter.remap(sorter.simplify(@sortkey.downcase)) # ??
                    end
                    if not @sortkey or @sortkey.empty? then
                        @sortkey = @key.dup
                    end
                end

                def <=> (other)
                    @sortkey <=> other.sortkey
                end

                def Synonym.flush(list,handle)
                    if @@debug then
                        list.each do |entry|
                            handle << "% [#{entry.sortkey}]\n"
                        end
                    end
                    list.each do |entry|
                        handle << "\\synonymentry{#{entry.type}}{#{entry.command}}{#{entry.key}}{#{entry.data}}%\n"
                    end
                end

            end

            @@synonyms  = Hash.new
            @@sorter    = Hash.new
            @@languages = Hash.new

            def MySynonyms::reset(logger)
                @@synonyms  = Hash.new
                @@sorter    = Hash.new
                @@languages = Hash.new
            end

            def MySynonyms::reader(logger,data)
                case data[0]
                    when 'e' then
                        @@synonyms[data[1]] = Array.new unless @@synonyms.key?(data[1])
                        @@synonyms[data[1]].push(Synonym.new(data[1],data[2],data[3],data[4]))
                    when 'l' then
                        @@languages[data[1]] = data[2] || ''
                end
            end

            def MySynonyms::writer(logger,handle)
                if @@synonyms.size > 0 then
                    @@synonyms.keys.sort.each do |s|
                        handle << logger.banner("synonyms: #{s} #{@@synonyms[s].size}")
                        Synonym.flush(@@synonyms[s],handle)
                    end
                end
            end

            def MySynonyms::processor(logger)
                @@synonyms.keys.each do |s|
                    @@sorter[s] = Sorter.new
                    @@sorter[s].preset(
                        eval("MyKeys").shortcuts,
                        eval("MyKeys").expansions,
                        eval("MyKeys").reductions,
                        eval("MyKeys").divisions,
                        @@languages[s] || '')
                    @@sorter[s].prepare
                    @@synonyms[s].each_index do |i|
                        @@synonyms[s][i].build(@@sorter[s])
                    end
                    @@synonyms[s] = @@synonyms[s].sort
                end
            end

            def MySynonyms::finalizer(logger)
            end

        end

    end

    class Plugin

        module MyRegisters

            class Register

                @@specialsymbol = "\000"
                @@specialbanner = "" # \\relax"

                @@debug = false

                @@howto = /^(.*?)\:\:(.*)$/o
                @@split = ' && '

                def initialize(state, t, l, k, e, s, p, r)
                    @state, @type, @location, @key, @entry, @seetoo, @page, @realpage = state, t, l, k, e, s, p, r
                    if @key   =~ @@howto then @pagehowto, @key   = $1, $2 else @pagehowto = '' end
                    if @entry =~ @@howto then @texthowto, @entry = $1, $2 else @texthowto = '' end
                    @key = @entry.dup if @key.empty?
                    @sortkey = @key.dup
                    @nofentries, @nofpages = 0, 0
                    @normalizeentry = false
                end

                attr_reader :state, :type, :location, :key, :entry, :seetoo, :page, :realpage, :texthowto, :pagehowto
                attr_reader :sortkey
                attr_writer :sortkey

                def build(sorter)
                    # @entry, @key = sorter.normalize(@entry), sorter.normalize(sorter.tokenize(@key))
                    @entry = sorter.normalize(sorter.tokenize(@entry)) if @normalizeentry
                    @key   = sorter.normalize(sorter.tokenize(@key))
                    if false then
                        @entry, @key = [@entry, @key].collect do |target|
                            # +a+b+c &a&b&c a+b+c a&b&c
                            case target[0,1]
                                when '&' then target = target.sub(/^./o,'').gsub(/([^\\])\&/o)     do "#{$1}#{@@split}" end
                                when '+' then target = target.sub(/^./o,'').gsub(/([^\\])\+/o)     do "#{$1}#{@@split}" end
                                else          target = target              .gsub(/([^\\])[\&\+]/o) do "#{$1}#{@@split}" end
                            end
                            # {a}{b}{c}
                            # if target =~ /^\{(.*)\}$/o then
                                # $1.split(/\} \{/o).join(@@split) # space between } { is mandate
                            # else
                                target
                            # end
                        end
                    else
                        # @entry, @key = cleanupsplit(@entry), cleanupsplit(@key)
                        @entry, @key = cleanupsplit(@entry), xcleanupsplit(@key)
                    end
                    @sortkey = sorter.simplify(@key)
                    # special = @sortkey =~ /^([^a-zA-Z\\])/o
                    special = @sortkey =~ /^([\`\~\!\@\#\$\%\^\&\*\(\)\_\-\+\=\{\}\[\]\:\;\"\'\|\<\,\>\.\?\/\d])/o
                    @sortkey = @sortkey.split(@@split).collect do |c| sorter.remap(c) end.join(@@split)
                    if special then
                        @sortkey = "#{@@specialsymbol}#{@sortkey}"
                    end
                    if @realpage == 0 then
                        @realpage = 999999
                    end
                    @sortkey = [
                        @sortkey.downcase,
                        @sortkey,
                        @entry,
                        @texthowto.ljust(10,' '),
                        # @state, # no, messes up things
                        (@realpage.to_s || '').rjust(6,' ').gsub(/0/,' '),
                        # (@realpage ||'').rjust(6,' '),
                        @pagehowto
                    ].join(@@split)
                end

                def cleanupsplit(target)
                    # +a+b+c &a&b&c a+b+c a&b&c
                    case target[0,1]
                        when '&' then target.sub(/^./o,'').gsub(/([^\\])\&/o)     do "#{$1}#{@@split}" end
                        when '+' then target.sub(/^./o,'').gsub(/([^\\])\+/o)     do "#{$1}#{@@split}" end
                        else          target              .gsub(/([^\\])[\&\+]/o) do "#{$1}#{@@split}" end
                    end
                end

                def xcleanupsplit(target) # +a+b+c &a&b&c a+b+c a&b&c
                    t = Array.new
                    case target[0,1]
                        when '&' then
                            t = target.sub(/^./o,'').split(/([^\\])\&/o)
                        when '+' then
                            t = target.sub(/^./o,'').split(/([^\\])\+/o)
                        else
                            # t = target.split(/([^\\])[\&\+]/o)
                            # t = target.split(/[\&\+]/o)
                            t = target.split(/(?!\\)[\&\+]/o) # lookahead
                    end
                    if not t[1] then t[1] = " " end # we need some entry else we get subentries first
                    if not t[2] then t[2] = " " end # we need some entry else we get subentries first
                    if not t[3] then t[3] = " " end # we need some entry else we get subentries first
                    return t.join(@@split)
                end
                def <=> (other)
                    @sortkey <=> other.sortkey
                end

                # more module like

                @@savedhowto, @@savedfrom, @@savedto, @@savedentry = '', '', '', '', ''
                @@collapse = false

                def Register.flushsavedline(handle)
                    if @@collapse && ! @@savedfrom.empty? then
                        if ! @@savedto.empty? then
                            handle << "\\registerfrom#{@@savedfrom}%"
                            handle << "\\registerto#{@@savedto}%"
                        else
                            handle << "\\registerpage#{@@savedfrom}%"
                        end
                    end
                    @@savedhowto, @@savedfrom, @@savedto, @@savedentry = '', '', '', ''
                end

                def Register.flush(list,handle,sorter)
                    # a bit messy, quite old mechanism, maybe some day ...
                    # alphaclass can go, now flushed per class
                    if list.size > 0 then
                        @nofentries, @nofpages = 0, 0
                        current, previous, howto  = Array.new, Array.new, Array.new
                        lastpage, lastrealpage = '', ''
                        alphaclass, alpha = '', ''
                        @@savedhowto, @@savedfrom, @@savedto, @@savedentry = '', '', '', ''
                        if @@debug then
                            list.each do |entry|
                                handle << "% [#{entry.sortkey.gsub(/#{@@split}/o,'] [')}]\n"
                            end
                        end
                        list.each do |entry|
# puts(entry.sortkey.gsub(/\s+/,""))
                            if entry.sortkey =~ /^(\S+)/o then
                                if sorter.division?($1) then
                                    testalpha = sorter.getdivision($1)
                                else
                                    testalpha = entry.sortkey[0,1].downcase
                                end
                            else
                                testalpha = entry.sortkey[0,1].downcase
                            end
                            if (testalpha != alpha.downcase) || (alphaclass != entry.class) then
                                alpha = testalpha
                                alphaclass = entry.class
                                if alpha != ' ' then
                                    flushsavedline(handle)
                                    if alpha =~ /^[a-zA-Z]$/o then
                                        character = alpha.dup
                                    elsif alpha == @@specialsymbol then
                                        character = @@specialbanner
                                    elsif alpha.length > 1 then
                                        # character = "\\getvalue\{#{alpha}\}"
                                        character = "\\#{alpha}"
                                    else
                                        character = "\\unknown"
                                    end
                                    handle << "\\registerentry{#{entry.type}}{#{character}}%\n"
                                end
                            end
                            current = [entry.entry.split(@@split),'','','',''].flatten
                            howto = current.collect do |e|
                                e + '::' + entry.texthowto
                            end
                            if howto[0] == previous[0] then
                                current[0] = ''
                            else
                                previous[0] = howto[0].dup
                                previous[1] = ''
                                previous[2] = ''
                                previous[3] = ''
                            end
                            if howto[1] == previous[1] then
                                current[1] = ''
                            else
                                previous[1] = howto[1].dup
                                previous[2] = ''
                                previous[3] = ''
                            end
                            if howto[2] == previous[2] then
                                current[2] = ''
                            else
                                previous[2] = howto[2].dup
                                previous[3] = ''
                            end
                            if howto[3] == previous[3] then
                                current[3] = ''
                            else
                                previous[3] = howto[3].dup
                            end
                            copied = false
                            unless current[0].empty? then
                                Register.flushsavedline(handle)
                                handle << "\\registerentrya{#{entry.type}}{#{current[0]}}%\n"
                                copied = true
                            end
                            unless current[1].empty? then
                                Register.flushsavedline(handle)
                                handle << "\\registerentryb{#{entry.type}}{#{current[1]}}%\n"
                                copied = true
                            end
                            unless current[2].empty? then
                                Register.flushsavedline(handle)
                                handle << "\\registerentryc{#{entry.type}}{#{current[2]}}%\n"
                                copied = true
                            end
                            unless current[3].empty? then
                                Register.flushsavedline(handle)
                                handle << "\\registerentryd{#{entry.type}}{#{current[3]}}%\n"
                                copied = true
                            end
                            @nofentries += 1 if copied
                            # if entry.realpage.to_i == 0 then
                            if entry.realpage.to_i == 999999 then
                                Register.flushsavedline(handle)
                                handle << "\\registersee{#{entry.type}}{#{entry.pagehowto},#{entry.texthowto}}{#{entry.seetoo}}{#{entry.page}}%\n" ;
                                lastpage, lastrealpage = entry.page, entry.realpage
                                copied = false # no page !
                            elsif @@savedhowto != entry.pagehowto and ! entry.pagehowto.empty? then
                                @@savedhowto = entry.pagehowto
                            end
                            # beware, we keep multiple page entries per realpage because of possible prefix usage
                            if copied || ! ((lastpage == entry.page) && (lastrealpage == entry.realpage)) then
                                nextentry = "{#{entry.type}}{#{previous[0]}}{#{previous[1]}}{#{previous[2]}}{#{previous[3]}}{#{entry.pagehowto},#{entry.texthowto}}"
                                savedline = "{#{entry.type}}{#{@@savedhowto},#{entry.texthowto}}{#{entry.location}}{#{entry.page}}{#{entry.realpage}}"
                                if entry.state == 1 then # from
                                    Register.flushsavedline(handle)
                                    handle << "\\registerfrom#{savedline}%\n"
                                elsif entry.state == 3 then # to
                                    Register.flushsavedline(handle)
                                    handle << "\\registerto#{savedline}%\n"
                                    @@savedhowto = '' # test
                                elsif @@collapse then
                                    if savedentry != nextentry then
                                        savedFrom = savedline
                                    else
                                        savedTo, savedentry = savedline, nextentry
                                    end
                                else
                                    handle << "\\registerpage#{savedline}%\n"
                                    @@savedhowto = '' # test
                                end
                                @nofpages += 1
                                lastpage, lastrealpage = entry.page, entry.realpage
                            end
                        end
                        Register.flushsavedline(handle)
                    end
                end

            end

            @@registers = Hash.new
            @@sorter    = Hash.new
            @@languages = Hash.new

            def MyRegisters::reset(logger)
                @@registers = Hash.new
                @@sorter    = Hash.new
                @@languages = Hash.new
            end

            def MyRegisters::reader(logger,data)
                case data[0]
                    when 'f' then
                        @@registers[data[1]] = Array.new unless @@registers.key?(data[1])
                        @@registers[data[1]].push(Register.new(1,data[1],data[2],data[3],data[4],nil,data[5],data[6]))
                    when 'e' then
                        @@registers[data[1]] = Array.new unless @@registers.key?(data[1])
                        @@registers[data[1]].push(Register.new(2,data[1],data[2],data[3],data[4],nil,data[5],data[6]))
                    when 't' then
                        @@registers[data[1]] = Array.new unless @@registers.key?(data[1])
                        @@registers[data[1]].push(Register.new(3,data[1],data[2],data[3],data[4],nil,data[5],data[6]))
                    when 's' then
                        @@registers[data[1]] = Array.new unless @@registers.key?(data[1])
                        # was this but wrong sort order       (4,data[1],data[2],data[3],data[4],data[5],data[6],nil))
                        @@registers[data[1]].push(Register.new(4,data[1],data[2],data[3],data[4],data[5],data[6],0))
                    when 'l' then
                        @@languages[data[1]] = data[2] || ''
                end
            end

            def MyRegisters::writer(logger,handle)
                if @@registers.size > 0 then
                    @@registers.keys.sort.each do |s|
                        handle << logger.banner("registers: #{s} #{@@registers[s].size}")
                        Register.flush(@@registers[s],handle,@@sorter[s])
                        # report("register #{@@registers[s].class}: #{@@registers[s].@nofentries} entries and #{@@registers[s].@nofpages} pages")
                    end
                end
            end

            def MyRegisters::processor(logger)
                @@registers.keys.each do |s|
                    @@sorter[s] = Sorter.new
                    @@sorter[s].preset(
                        eval("MyKeys").shortcuts,
                        eval("MyKeys").expansions,
                        eval("MyKeys").reductions,
                        eval("MyKeys").divisions,
                        @@languages[s] || '')
                    @@sorter[s].prepare
                    @@registers[s].each_index do |i|
                        @@registers[s][i].build(@@sorter[s])
                    end
                    # @@registers[s].uniq!
                    @@registers[s] = @@registers[s].sort
                end
            end

            def MyRegisters::finalizer(logger)
            end

        end

    end

    class Plugin

        module MyPlugins

            @@plugins = nil

            def MyPlugins::reset(logger)
                @@plugins = nil
            end

            def MyPlugins::reader(logger,data)
                @@plugins = Plugin.new(logger) unless @@plugins
                case data[0]
                    when 'r' then
                        logger.report("registering plugin #{data[1]}")
                        @@plugins.register(data[1],data[2])
                    when 'd' then
                        begin
                            @@plugins.reader(data[1],data[2,data.length-1])
                        rescue
                            @@plugins.reader(data[1],['error'])
                        end
                end
            end

            def MyPlugins::writer(logger,handle)
                @@plugins.writers(handle) if @@plugins
            end

            def MyPlugins::processor(logger)
                @@plugins.processors if @@plugins
            end

            def MyPlugins::finalizer(logger)
                @@plugins.finalizers if @@plugins
            end

        end

    end

    class Plugin

        module MyKeys

            @@shortcuts  = Array.new
            @@expansions = Array.new
            @@reductions = Array.new
            @@divisions  = Array.new

            def MyKeys::shortcuts
                @@shortcuts
            end
            def MyKeys::expansions
                @@expansions
            end
            def MyKeys::reductions
                @@reductions
            end
            def MyKeys::divisions
                @@divisions
            end

            def MyKeys::reset(logger)
                @@shortcuts  = Array.new
                @@expansions = Array.new
                @@reductions = Array.new
            end

            def MyKeys::reader(logger,data)
                key = data.shift
                # grp = data.shift # language code, todo
                case key
                    when 's' then @@shortcuts.push(data)
                    when 'e' then @@expansions.push(data)
                    when 'r' then @@reductions.push(data)
                    when 'd' then @@divisions.push(data)
                end
            end

            def MyKeys::writer(logger,handle)
            end

            def MyKeys::processor(logger)
                logger.report("shortcuts : #{@@shortcuts.size}")  # logger.report(@@shortcuts.inspect)
                logger.report("expansions: #{@@expansions.size}") # logger.report(@@expansions.inspect)
                logger.report("reductions: #{@@reductions.size}") # logger.report(@@reductions.inspect)
                logger.report("divisions : #{@@divisions.size}")  # logger.report(@@divisions.inspect)
            end

            def MyKeys::finalizer(logger)
            end

        end

    end

    class Converter

        def initialize(logger=nil)
            if @logger = logger then
                def report(str)
                    @logger.report(str)
                end
                def banner(str)
                    @logger.banner(str)
                end
            else
                @logger = self
                def report(str)
                    puts(str)
                end
                def banner(str)
                    puts(str)
                end
            end
            @filename = 'texutil'
            @fatalerror = false
            @plugins = Plugin.new(@logger)
            ['MyFiles', 'MyCommands', 'MySynonyms', 'MyRegisters', 'MyExtras', 'MyPlugins', 'MyKeys'].each do |p|
                @plugins.register(p)
            end
        end

        def loaded(filename)
            begin
                tuifile = File.suffixed(filename,'tui')
                if FileTest.file?(tuifile) then
                    report("parsing file #{tuifile}")
                    if f = File.open(tuifile,'rb') then
                        f.each do |line|
                            case line.chomp
                                when /^f (.*)$/o then @plugins.reader('MyFiles',    $1.splitdata)
                                when /^c (.*)$/o then @plugins.reader('MyCommands', [$1])
                                when /^e (.*)$/o then @plugins.reader('MyExtras',   $1.splitdata)
                                when /^s (.*)$/o then @plugins.reader('MySynonyms', $1.splitdata)
                                when /^r (.*)$/o then @plugins.reader('MyRegisters',$1.splitdata)
                                when /^p (.*)$/o then @plugins.reader('MyPlugins',  $1.splitdata)
                                when /^x (.*)$/o then @plugins.reader('MyKeys',     $1.splitdata)
                                when /^r (.*)$/o then # nothing, not handled here
                            else
                                # report("unknown entry #{line[0,1]} in line #{line.chomp}")
                            end
                        end
                        f.close
                    end
                else
                    report("unable to locate #{tuifile}")
                end
            rescue
                report("fatal error in parsing #{tuifile}")
                @filename = 'texutil'
            else
                @filename = filename
            end
        end

        def processed
            @plugins.processors
            return true # for the moment
        end

        def saved(filename=@filename)
            if @fatalerror then
                report("fatal error, no tuo file saved")
                return false
            else
                begin
                    if f = File.open(File.suffixed(filename,'tuo'),'w') then
                        @plugins.writers(f)
                        f << "\\endinput\n"
                        f.close
                    end
                rescue
                    report("fatal error when saving file (#{$!})")
                    return false
                else
                    report("tuo file saved")
                    return true
                end
            end
        end

        def finalized
            @plugins.finalizers
            @plugins.resets
            return true # for the moment
        end

        def reset
            @plugins.resets
        end

    end

end

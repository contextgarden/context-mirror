#D Plugins
#D
#D test.pm:
#D
#D \starttypen
#D see plugtest.pm
#D \stoptypen
#D
#D utility format:
#D
#D \starttypen
#D p u {name} {data} {data} ...
#D \stoptypen

# my $pm_path ;

# BEGIN
  # { $pm_path = "$FindBin::Bin/" ;
    # if ($pm_path eq "") { $pm_path = "./" } }

# use lib $pm_path ;

# my %UserPlugIns ;

# sub HandlePlugIn
  # { if ($RestOfLine =~ /\s*u\s*\{(.*?)\}\s*(.*)\s*/io)
      # { my $tag = $1 ;
        # my $arg = $2 ;
        # if (! defined($UserPlugIns{$tag}))
          # { $UserPlugIns{$tag} = 1 ;
            # eval("use $tag") ;
            # my $result = $tag->identify ;
            # if ($result ne "")
              # { Report ("PlugInInit", "$tag -> $result") }
            # else
              # { Report ("PlugInInit", $tag ) }
            # $tag->initialize() }
        # if (defined($UserPlugIns{$tag}))
          # { $arg =~ s/\{(.*)\}/$1/o ;
            # my @args = split(/\}\s*\{/o, $arg) ;
            # $tag->handle(@args) } } }

# sub FlushPlugIns
  # { foreach my $tag (keys %UserPlugIns)
      # { my @report = $tag->report ;
        # foreach $rep (@report)
          # { my ($key,$val) = split (/\s*\:\s*/,$rep) ;
            # if ($val ne "")
              # { Report ("PlugInReport", "$tag -> $key -> $val") }
            # else
              # { Report ("PlugInReport", "$tag -> $key") } }
        # $tag->process ;
        # print TUO "%\n" . "% $Program / " . $tag->identify . "\n" . "%\n" ;
        # foreach my $str ($tag->results)
          # { print TUO "\\plugincommand\{$str\}\n" } } }

require "base/file"

def report(str)
    puts(str)
end

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

end

class Sorter

    def initialize(max=12)
        @rep, @map, @exp = Hash.new, Hash.new, Hash.new
        @max = max
        @rexa, @rexb = nil, nil
    end

    def replace(from,to='') # and expand
        @rep[from.escaped] = to || ''
    end

    # sorter.reduce('ch', 'c')
    # sorter.reduce('ij', 'y')

    def reduce(from,to='')
        @map[from] = to || ''
    end

    # sorter.expand('aeligature', 'ae')
    # sorter.expand('ijligature', 'y')

    def expand(from,to=nil)
        @exp[from] = to || from || ''
    end

    # shortcut("\\ab\\cd\\e\\f", 'iacute')
    # shortcut("\\\'\\i", 'iacute')
    # shortcut("\\\'i", 'iacute')
    # shortcut("\\\"e", 'ediaeresis')
    # shortcut("\\\'o", 'oacute')

    def shortcut(from,to)
        replace(from,to)
        expand(to)
    end

    def prepare
        @rexa = /(#{@rep.keys.join('|')})/o
        if @map.size > 0 then
            # watch out, order of match matters
            @rexb = /(\\[a-zA-Z]+|#{@map.keys.join('|')}|.)\s*/o
        else
            @rexb = /(\\[a-zA-Z]+|.)\s*/o
        end
    end

    def remap(str)
        str.gsub(@rexa) do
            @rep[$1.escaped]
        end.gsub(@rexb) do
            token = $1.sub(/\\/o, '')
            if @map.key?(token) then
                @map[token].ljust(@max,' ')
            elsif @exp.key?(token) then
                @exp[token].split('').collect do |t|
                    t.ljust(@max,' ')
                end.join('')
            else
                ''
            end
        end
    end

    def remap(str)
        str.gsub(@rexa) do
            @rep[$1.escaped]
        end.gsub(@rexb) do
            token = $1.sub(/\\/o, '')
            if @exp.key?(token) then
                @exp[token].ljust(@max,' ')
            elsif @map.key?(token) then
                @map[token].ljust(@max,' ')
            else
                ''
            end
        end
    end

    def preset(language='')
        'a'.upto('z') do |c|
            expand(c)
        end
        shortcut("\\\'\\i", 'iacute')
        shortcut("\\\'i", 'iacute')
        shortcut("\\\"e", 'ediaeresis')
        shortcut("\\\'o", 'oacute')
        expand('aeligature', 'ae')
        expand('ijligature', 'y')
        expand('eacute')
        expand('egrave')
        expand('ediaeresis')
        # reduce('ch', 'c')
        # reduce('ij', 'y')
        # expand('aeligature', 'ae')
        # expand('ijligature', 'y')
        # expand('tex')
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
        s.gsub!(/\\[a-z][a-z]+\s*\{(.*?)\}/o) do $1 end
        return s
    end

end

class Synonym

    @@debug = true

    def initialize(t, c, k, d)
        @type, @command, @key, @sortkey, @data = t, c, k, k, d
    end

    attr_reader :type, :command, :key, :data
    attr_reader :sortkey
    attr_writer :sortkey

    def build(sorter)
        @sortkey = sorter.remap(sorter.simplify(@key.downcase))
        if @sortkey.empty? then
            @sortkey = sorter.remap(@command.downcase)
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
            handle << "\\synonymentry{#{entry.type}}{#{entry.command}}{#{entry.key}}{#{entry.data}}\n"
        end
    end

end

class Register

    @@debug = true

    @@howto = /^(.*?)\:\:(.*)$/o
    @@split = ' && '

    def initialize(state, t, l, k, e, s, p, r)
        @state, @type, @location, @key, @entry, @seetoo, @page, @realpage = state, t, l, k, e, s, p, r
        if @key   =~ @@howto then @pagehowto, @key   = $1, $2 else @pagehowto = '' end
        if @entry =~ @@howto then @texthowto, @entry = $1, $2 else @texthowto = '' end
        @key = @entry.dup if @key.empty?
        @sortkey = @key.dup
    end

    attr_reader :state, :type, :location, :key, :entry, :seetoo, :page, :realpage, :texthowto, :pagehowto
    attr_reader :sortkey
    attr_writer :sortkey

    def build(sorter)
        @entry, @key = [@entry, @key].collect do |target|
            # +a+b+c &a&b&c a+b+c a&b&c
            case target[0,1]
                when '&' then target = target.sub(/^./o,'').gsub(/([^\\])\&/o)     do "#{$1}#{@@split}" end
                when '+' then target = target.sub(/^./o,'').gsub(/([^\\])\+/o)     do "#{$1}#{@@split}" end
                else          target = target              .gsub(/([^\\])[\&\+]/o) do "#{$1}#{@@split}" end
            end
            # {a}{b}{c}
            if target =~ /^\{(.*)\}$/o then
                $1.split(/\} \{/o).join(@@split) # space between } { is mandate
            else
                target
            end
        end
        @sortkey = sorter.simplify(@key)
        @sortkey = @sortkey.split(@@split).collect do |c| sorter.remap(c) end.join(@@split)
        # if ($Key eq "")  { $Key = SanitizedString($Entry) }
        # if ($ProcessHigh){ $Key = HighConverted($Key) }
        @sortkey = [
            @sortkey.downcase,
            @sortkey,
            @texthowto.ljust(10,' '),
            @state,
            @realpage.rjust(6,' '),
            @pagehowto
        ].join(@@split)
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
                handle << "\\registerfrom#{@@savedfrom}"
                handle << "\\registerto#{@@savedto}"
            else
                handle << "\\registerpage#{@@savedfrom}"
            end
        end
        @@savedhowto, @@savedfrom, @@savedto, @@savedentry = '', '', '', ''
    end

    def Register.flush(list,handle)
        #
        # alphaclass can go, now flushed per class
        #
        if list.size > 0 then
            nofentries, nofpages = 0, 0
            current, previous, howto  = Array.new, Array.new, Array.new
            lastpage, lastrealpage = '', ''
            alphaclass, alpha = '', ''
            @@savedhowto, @@savedfrom, @@savedto, @@savedentry = '', '', '', ''

            if @@debug then
                list.each do |entry|
                    handle << "% [#{entry.sortkey[0,1]}] [#{entry.sortkey.gsub(/#{@@split}/o,'] [')}]\n"
                end
            end
            list.each do |entry|
                testalpha = entry.sortkey[0,1].downcase
                if testalpha != alpha.downcase or alphaclass != entry.class then
                    alpha = testalpha
                    alphaclass = entry.class
                    if alpha != ' ' then
                        flushsavedline(handle)
                        character = alpha.sub(/([^a-zA-Z])/o) do "\\" + $1 end
                        handle << "\\registerentry{#{entry.type}}{#{character}}\n"
                    end
                end
                current = [entry.entry.split(@@split),'','',''].flatten
                howto = current.collect do |e|
                    e + '::' + entry.texthowto
                end
                if howto[0] == previous[0] then
                    current[0] = ''
                else
                    previous[0] = howto[0].dup
                    previous[1] = ''
                    previous[2] = ''
                end
                if howto[1] == previous[1] then
                    current[1] = ''
                else
                    previous[1] = howto[1].dup
                    previous[2] = ''
                end
                if howto[2] == previous[2] then
                    current[2] = ''
                else
                    previous[2] = howto[2].dup
                end
                copied = false
                unless current[0].empty? then
                    Register.flushsavedline(handle)
                    handle << "\\registerentrya{#{entry.type}}{#{current[0]}}\n"
                    copied = true
                end
                unless current[1].empty? then
                    Register.flushsavedline(handle)
                    handle << "\\registerentryb{#{entry.type}}{#{current[1]}}\n"
                    copied = true
                end
                unless current[2].empty? then
                    Register.flushsavedline(handle)
                    handle << "\\registerentryc{#{entry.type}}{#{current[2]}}\n"
                    copied = true
                end
                nofentries += 1 if copied
                if entry.realpage.to_i == 0 then
                    Register.flushsavedline(handle)
                    handle << "\\registersee{#{entry.type}}{#{entry.pagehowto},#{entry.texthowto}}{#{entry.seetoo}}{#{entry.page}}\n" ;
                    lastpage, lastrealpage = entry.page, entry.realpage
                elsif @@savedhowto != entry.pagehowto and ! entry.pagehowto.empty? then
                    @@savedhowto = entry.pagehowto
                end
                if copied || ! ((lastpage == entry.page) && (lastrealpage == entry.realpage)) then
                    nextentry = "{#{entry.type}}{#{previous[0]}}{#{previous[1]}}{#{previous[2]}}{#{entry.pagehowto},#{entry.texthowto}}"
                    savedline = "{#{entry.type}}{#{@@savedhowto},#{entry.texthowto}}{#{entry.location}}{#{entry.page}}{#{entry.realpage}}"
                    if entry.state == 1 then # from
                        Register.flushsavedline(handle)
                        handle << "\\registerfrom#{savedline}\n"
                    elsif entry.state == 3 then # to
                        Register.flushsavedline(handle)
                        handle << "\\registerto#{savedline}\n"
                    elsif @@collapse then
                        if savedentry != nextentry then
                            savedFrom = savedline
                        else
                            savedTo, savedentry = savedline, nextentry
                        end
                    else
                        handle << "\\registerpage#{savedline}\n"
                    end
                    nofpages += 1
                    lastpage, lastrealpage = entry.page, entry.realpage
                end
            end
            Register.flushsavedline(handle)
            report("register #{list[0].class}: #{nofentries} entries and #{nofpages} pages")
        end
    end

end

class TeXUtil

    # how to deal with encoding:
    #
    # load context enco-* file

    def initialize
        @commands = []
        @programs = []
        @synonyms = Hash.new
        @registers = Hash.new
        @files = Hash.new
        @filename = 'texutil'
        @fatalerror = false
    end

    def loaded(filename)
        # begin
            File.open(File.suffixed(filename,'tui')).each do |line|
                case line.chomp
                    # f b|e {filename}
                    when /^f (b|e) \{(.*)\}$/o then
                        if @files.key?($2) then @files[$2] += 1 else @files[$2] = 1 end
                    # c commmand
                    when /^c (.*)$/o then
                        @commands.push($1)
                    # e p {program data}
                    when /^e p \{(.*)\}$/o then
                        @programs.push($1)
                    # s e {type}{command}{key}{associated data}
                    when /^s e \{(.*)\}\s*\{(.*)\}\s*\{(.*)\}\s*\{(.*)\}\s*$/o then
                        @synonyms[$1] = Array.new unless @synonyms.key?($1)
                        @synonyms[$1].push(Synonym.new($1,$2,$3,$4))
                    # from: r f
                    when /^r f \{(.*)\}\s*\{(.*)\}\s*\{(.*)\}\s*\{(.*)\}\s*\{(.*)\}\s*\{(.*)\}\s*/o then
                        @registers[$1] = Array.new unless @registers.key?($1)
                        @registers[$1].push(Register.new(1,$1,$2,$3,$4,nil,$5,$6))
                    # entry: r e {type}{location}{key}{entry}{page}{realpage}
                    when /^r e \{(.*)\}\s*\{(.*)\}\s*\{(.*)\}\s*\{(.*)\}\s*\{(.*)\}\s*\{(.*)\}\s*/o then
                        @registers[$1] = Array.new unless @registers.key?($1)
                        @registers[$1].push(Register.new(2,$1,$2,$3,$4,nil,$5,$6))
                    # from: r t
                    when /^r t \{(.*)\}\s*\{(.*)\}\s*\{(.*)\}\s*\{(.*)\}\s*\{(.*)\}\s*\{(.*)\}\s*/o then
                        @registers[$1] = Array.new unless @registers.key?($1)
                        @registers[$1].push(Register.new(3,$1,$2,$3,$4,nil,$5,$6))
                    # see: r s {type}{location}{key}{entry}{seetoo}{page}
                    when /^r s \{(.*)\}\s*\{(.*)\}\s*\{(.*)\}\s*\{(.*)\}\s*\{(.*)\}\s*\{(.*)\}\s*/o then
                        @registers[$1] = Array.new unless @registers.key?($1)
                        @registers[$1].push(Register.new(4,$1,$2,$3,$4,$5,$6,nil))
                    when /^k /o then
                        # key
                    when /^p /o then
                        # plugin
                    when /^q/o then
                        break
                    else
                        report("unknown entry #{line}")
                end
            end
        # rescue
            # report("error in parsing file (#{$!})")
            # @filename = 'texutil'
        # else
            @filename = filename
        # end
    end

    def sorted
        sorter = Sorter.new
        sorter.preset
        sorter.prepare
        [@synonyms,@registers].each do |target|
            target.keys.each do |s|
                target[s].each_index do |i|
                    target[s][i].build(sorter)
                end
                target[s] = target[s].sort
            end
        end
    end

    def banner(str)
        report(str)
        return "%\n% #{str}\n%\n"
    end

    def saved(filename=@filename)
        if @fatalerror then
            report("fatal error, no tuo file saved")
        else
           # begin
                if f = File.open(File.suffixed(filename,'tuo'),'w') then
                    if @files.size > 0 then
                        f << banner("loaded files: #{@files.size}")
                        @files.keys.sort.each do |k|
                            unless (@files[k] % 2) == 0 then
                                report("check loading of file #{k}, begin/end problem")
                            end
                            f << "% > #{k} #{@files[k]/2}\n"
                        end
                    end
                    if @commands.size > 0 then
                        f << banner("commands: #{@commands.size}")
                        @commands.each do |c|
                            f << "#{c}\n"
                        end
                    end
                    if @synonyms.size > 0 then
                        @synonyms.keys.sort.each do |s|
                            f << banner("synonyms: #{s} #{@synonyms[s].size}")
                            Synonym.flush(@synonyms[s],f)
                        end
                    end
                    if @registers.size > 0 then
                        @registers.keys.sort.each do |s|
                            f << banner("registers: #{s} #{@registers[s].size}")
                            Register.flush(@registers[s],f)
                        end
                    end
                    if @programs.size > 0 then
                        f << banner("programs: #{@programs.size}")
                        @programs.each do |p|
                            f << "% #{p} (#{@programs[p]})\n"
                        end
                    end
                    f.close
                    @programs.each do |p|
                        cmd = "texmfstart #{@programs[p]}"
                        report("running #{cmd}")
                        system(cmd)
                    end
                end
            # rescue
                # report("fatal error when saving file (#{$!})")
            # end
        end
    end

end

if tu = TeXUtil.new and tu.loaded('tuitest') then
    tu.sorted
    tu.saved
end

                              # ShowBanner       ;

# if     ($UnknownOptions   ) { ShowHelpInfo     } # not yet done
# elsif  ($ProcessReferences) { HandleReferences }
# elsif  ($ProcessFigures   ) { HandleFigures    }
# elsif  ($ProcessLogFile   ) { HandleLogFile    }
# elsif  ($PurgeFiles       ) { my $args = @ARGV.join(' ') ; system("texmfstart ctxtools --purge    $args") }
# elsif  ($PurgeAllFiles    ) { my $args = @ARGV.join(' ') ; system("texmfstart ctxtools --purgeall $args") }
# elsif  ($ProcessDocuments ) { my $args = @ARGV.join(' ') ; system("texmfstart ctxtools --document $args") }
# elsif  ($AnalyzeFile      ) { my $args = @ARGV.join(' ') ; system("texmfstart pdftools --analyze  $args") }
# elsif  ($FilterPages      ) { my $args = @ARGV.join(' ') ; system("texmfstart ctxtools --filter   $args") }
# elsif  ($ProcessHelp      ) { ShowHelpInfo     } # redundant
# else                        { ShowHelpInfo     }

#D So far.


# # # # keep

# sorter = Sorter.new
# sorter.reduce('ch', 'c')
# sorter.reduce('ij', 'y')

# sorter.expand('aeligature', 'ae')
# sorter.expand('ijligature', 'y')

# str = Array.new

# str.push 'aex c abc'
# str.push 'aex h abc'
# str.push 'aex ch abc'
# str.push 'aex a abc'
# str.push 'aex b abc'
# str.push 'aex c def'
# str.push 'aex h def'
# str.push 'aex ch def'
# str.push 'aex a def'
# str.push 'aex b def'
# str.push 'a\eacute x'
# str.push 'a\egrave x'
# str.push 'a\ediaeresis x'
# str.push 'a\ediaeresis'
# str.push '\aeligature xx'
# str.push '+abc'
# str.push 'ijs'
# str.push 'ijverig'
# str.push '\ijligature verig'
# str.push 'ypsilon'

# old = str.dup

# str.collect! do |s|
    # sorter.remap(s)
# end

# str.sort.each do |i|
    # puts i
# end


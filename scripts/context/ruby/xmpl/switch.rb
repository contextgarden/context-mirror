# module    : xmpl/switch
# copyright : PRAGMA Publishing On Demand
# version   : 1.00 - 2002
# author    : Hans Hagen
#
# project   : eXaMpLe
# concept   : Hans Hagen
# info      : j.hagen@xs4all.nl
# www       : www.pragma-pod.com / www.pragma-ade.com

# we cannot use getoptlong because we want to be more
# tolerant; also we want to be case insensitive.

# we could make each option a class itself, but this is
# simpler; also we can put more in the array

# beware: regexps/o in methods are optimized globally

class String

    def has_suffix?(suffix)
        self =~ /\.#{suffix}$/i
    end

end

module CommandBase

    # this module can be used as a mixin in a command handler

    $stdout.sync = true

    def initialize(commandline,logger,banner)
        @commandline, @logger, @banner = commandline, logger, banner
        @forcenewline, @versiondone = false, false
        version if @commandline.option('version')
    end

    def reportlines(*str)
        @logger.reportlines(str)
    end

    # only works in 1.8
    #
    # def report(*str)
        # @logger.report(str)
    # end
    #
    # def version # just a bit of playing with defs
        # report(@banner.join(' - '))
        # def report(*str)
            # @logger.report
            # @logger.report(str)
            # def report(*str)
                # @logger.report(str)
            # end
        # end
        # def version
        # end
    # end

    def report(*str)
        if @forcenewline then
            @logger.report
            @forcenewline = false
        end
        @logger.report(str)
    end

    def version # just a bit of playing with defs
        unless @versiondone then
            report(@banner.join(' - '))
            @forcenewline = true
            @versiondone = true
        end
    end

    def help
        version # is nilled when already given
        @commandline.helpkeys.each do |k|
            report("#{('--'+k).ljust(@commandline.helplength+2)} #{@commandline.helptext(k)}") if @commandline.help?(k)
        end
    end

    def option(key)
        @commandline.option(key)
    end

    private

    def findfiles(suffix=nil)

        if @commandline.arguments.length>1 then
            return @commandline.arguments
        else
            pattern  = @commandline.argument('first')
            pattern  = '*' if pattern.empty?
            if suffix && ! pattern.match(/\..+$/o) then
                suffix   = '.' + suffix
                pattern += suffix unless pattern =~ /#{suffix}$/
            end
            pattern = '**/' + pattern if @commandline.option('recurse')
            files = Dir[pattern]
            if files && files.length>0 then
                return files
            else
                report("no files match pattern #{pattern}")
                return nil
            end
        end

    end

    def globbed(pattern,recurse=false)

        files = Array.new
        pattern.split(' ').each do |p|
            if recurse then
                if p =~ /^(.*)(\/.*?)$/i then
                    p = $1 + '/**' + $2
                else
                    p = '**/' + p
                end
                p.gsub!(/[\\\/]+/, '/')
            end
            files.push(Dir.glob(p))
        end
        files.flatten.sort do |a,b|
            pathcompare(a,b)
        end
    end

    def pathcompare(a,b)

        aa, bb = a.split('/'), b.split('/')
        if aa.length == bb.length then
            aa.each_index do |i|
                if aa[i]<bb[i] then
                    return -1
                elsif aa[i]>bb[i] then
                    return +1
                end
            end
            return 0
        else
            return aa.length <=> bb.length
        end

    end

end

class CommandLine

    VALUE, FLAG = 1, 2

    def initialize(prefix='-')

        @registered = Array.new
        @options    = Hash.new
        @unchecked  = Hash.new
        @arguments  = Array.new
        @original   = ARGV.join(' ')
        @helptext   = Hash.new
        @mandated   = Hash.new
        @provided   = Hash.new
        @prefix     = prefix
        @actions    = Array.new

        # The quotes in --switch="some value" get lost in ARGV, so we need to do some trickery here.

        @original = ''
        ARGV.each do |a|
            aa = a.strip.gsub(/^([#{@prefix}]+\w+\=)([^\"].*?\s+.*[^\"])$/) do
                $1 + "\"" + $2 + "\""
            end
            @original += if @original.empty? then '' else ' ' end + aa
        end

    end

    def register (option,shortcut,kind,default=false,action=false,helptext='')
        if kind == FLAG then
            @options[option] = default
        elsif not default then
            @options[option] = ''
        else
            @options[option] = default
        end
        @registered.push([option,shortcut,kind])
        @mandated[option] = false
      # @provided[option] = false
        @helptext[option] = helptext
        @actions.push(option) if action
    end

    def registerflag(option,default=false,helptext='')
        if default.class == String then
            register(option,'',FLAG,false,false,default)
        else
            register(option,'',FLAG,false,false,helptext)
        end
    end

    def registervalue(option,default='',helptext='')
        register(option,'',VALUE,default,false,helptext)
    end

    def registeraction(option,helptext='')
        register(option,'',FLAG,false,true,helptext)
    end

    def registermandate(*option)
        [*option].each do |o|
            [o].each do |oo|
                @mandated[oo] = true
            end
        end
    end

    def actions
        a = @actions.delete_if do |t|
            ! option(t)
        end
        if a && a.length>0 then
            return a
        else
            return nil
        end
    end

    def action
        @actions.each do |t|
            return t if option(t)
        end
        return nil
    end

    def forgotten
        @mandated.keys.sort - @provided.keys.sort
    end

    def registerhelp(option,text='')
        @helptext['unknown'] = if text.empty? then option else text end
    end

    def helpkeys(option='.*')
        @helptext.keys.sort.grep(/#{option}/)
    end

    def helptext(option)
        @helptext.fetch(option,'')
    end

    def help?(option)
        @helptext[option] && ! @helptext[option].empty?
    end

    def helplength
        n = 0
        @helptext.keys.each do |h|
            n = h.length if h.length>n
        end
        return n
    end

    def expand

        # todo : '' or false, depending on type
        # @options.clear
        # @arguments.clear

        dirtyvalue(@original).split(' ').each do |arg|
            case arg
                when /^[#{@prefix}][#{@prefix}](.+?)\=(.*?)$/ then locatedouble($1,$2)
                when /^[#{@prefix}][#{@prefix}](.+?)$/        then locatedouble($1,false)
                when /^[#{@prefix}](.)\=(.)$/                 then locatesingle($1,$2)
                when /^[#{@prefix}](.+?)$/                    then locateseries($1,false)
                when /^[\+\-]+/o                              then # do nothing
            else
                arguments.push(arg)
            end
        end

        @options or @unchecked or @arguments

    end

    def extend (str)
        @original = @original + ' ' + str
    end

    def replace (str)
        @original = str
    end

    def show
      # print "-- options --\n"
        @options.keys.sort.each do |key|
            print "option: #{key} -> #{@options[key]}\n"
        end
      # print "-- arguments --\n"
        @arguments.each_index do |key|
            print "argument: #{key} -> #{@arguments[key]}\n"
        end
    end

    def option(str)
        @options[str] # @options.fetch(str,'')
    end

    def argument(n=0)
        if n.class == String then
            case n
                when 'first'  then argument(0)
                when 'second' then argument(1)
                when 'third'  then argument(2)
            else
                argument(0)
            end
        elsif @arguments[n] then
            @arguments[n]
        else
            ''
        end
    end

      # a few local methods, cannot be defined nested (yet)

    private

    def dirtyvalue(value)
        if value then
            value.gsub(/([\"\'])(.*?)\1/) do
                $2.gsub(/\s+/o, "\xFF")
            end
        else
            ''
        end
    end

    def cleanvalue(value)
        if value then
            # value.sub(/^([\"\'])(.*?)\1$/) { $2.gsub(/\xFF/o, ' ') }
            value.gsub(/\xFF/o, ' ')
        else
            ''
        end
    end

    def locatedouble(key, value)

        foundkey, foundkind = nil, nil

        @registered.each do |option, shortcut, kind|
            if option == key then
                foundkey, foundkind = option, kind
                break
            end
        end
        unless foundkey then
            @registered.each do |option, shortcut, kind|
                n = 0
                if option =~ /^#{key}/i then
                    case n
                        when 0
                            foundkey, foundkind = option, kind
                            n = 1
                        when 1
                            # ambiguous matches, like --fix => --fixme --fixyou
                            foundkey, foundkind = nil, nil
                            break
                    end
                end
            end
        end
        if foundkey then
            @provided[foundkey] = true
            # if value.class == FalseClass then
                # @options[foundkey] = true
            # else
                # @options[foundkey] = if foundkind == VALUE then cleanvalue(value) else true end
            # end
            if foundkind == VALUE then
                @options[foundkey] = cleanvalue(value)
            else
                @options[foundkey] = true
            end
        else
            if value.class == FalseClass then
                @unchecked[key] = true
            else
                @unchecked[key] = cleanvalue(value)
            end
        end

    end

    def locatesingle(key, value)

        @registered.each do |option, shortcut, kind|
            if shortcut == key then
                @provided[option] = true
                @options[option] = if kind == VALUE then '' else cleanvalue(value) end
                break
            end
        end

    end

    def locateseries(series, value)

        series.each do |key|
            locatesingle(key,cleanvalue(value))
        end

    end

    public

    attr_reader :arguments, :options, :original, :unchecked

end

# options = CommandLine.new
#
# options.register("filename", "f", CommandLine::VALUE)
# options.register("request" , "r", CommandLine::VALUE)
# options.register("verbose" , "v", CommandLine::FLAG)
#
# options.expand
# options.extend(str)
# options.show
#
# c = CommandLine.new
#
# c.registervalue('aaaa')
# c.registervalue('test')
# c.registervalue('zzzz')
#
# c.registerhelp('aaaa','some aaaa to enter')
# c.registerhelp('test','some text to enter')
# c.registerhelp('zzzz','some zzzz to enter')
#
# c.registermandate('test')
#
# c.expand
#
# class CommandLine
#
# def showhelp (banner,*str)
#   if helpkeys(*str).length>0
#     print banner
#     helpkeys(*str).each do |h|
#       print helptext(h) + "\n"
#     end
#     true
#   else
#     false
#   end
# end
#
# def showmandate(banner)
#   if forgotten.length>0
#     print banner
#     forgotten.each do |f|
#       print helptext(f) + "\n"
#     end
#     true
#   else
#     false
#   end
# end
#
# end
#
# c.showhelp("you can provide:\n\n")
# c.showmandate("you also need to provide:\n\n")

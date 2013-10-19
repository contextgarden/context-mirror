#encoding: ASCII-8BIT

# module    : base/switch
# copyright : PRAGMA Advanced Document Engineering
# version   : 2002-2005
# author    : Hans Hagen
#
# project   : ConTeXt / eXaMpLe
# concept   : Hans Hagen
# info      : j.hagen@xs4all.nl
# www       : www.pragma-ade.com

# we cannot use getoptlong because we want to be more
# tolerant; also we want to be case insensitive (2002).

# we could make each option a class itself, but this is
# simpler; also we can put more in the array

# beware: regexps/o in methods are optimized globally

require "rbconfig"

$mswindows = RbConfig::CONFIG['host_os'] =~ /mswin/
$separator = File::PATH_SEPARATOR

class String

    def has_suffix?(suffix)
        self =~ /\.#{suffix}$/i
    end

end

# may move to another module

class File

    @@update_eps = 1

    def File.needsupdate(oldname,newname)
        begin
            oldtime = File.stat(oldname).mtime.to_i
            newtime = File.stat(newname).mtime.to_i
            if newtime >= oldtime then
                return false
            elsif oldtime-newtime < @@update_eps then
                return false
            else
                return true
            end
        rescue
            return true
        end
    end

    def File.syncmtimes(oldname,newname)
        return
        begin
            if $mswindows then
                # does not work (yet) / gives future timestamp
                # t = File.mtime(oldname) # i'm not sure if the time is frozen, so we do it here
                # File.utime(0,t,oldname,newname)
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

# main thing

module CommandBase

    # this module can be used as a mixin in a command handler

    $stdout.sync = true

    def initialize(commandline,logger,banner)
        @commandline, @logger, @banner = commandline, logger, banner
        @forcenewline, @versiondone, @error = false, false, false
        version if @commandline.option('version')
    end

    def reportlines(*str)
        @logger.reportlines(str)
    end

    # only works in 1.8
    #
    # def report(*str)
    #     @logger.report(str)
    # end
    #
    # def version # just a bit of playing with defs
    #    report(@banner.join(' - '))
    #    def report(*str)
    #        @logger.report
    #        @logger.report(str)
    #        def report(*str)
    #            @logger.report(str)
    #        end
    #    end
    #    def version
    #    end
    # end

    def report(*str)
        initlogger ; @logger.report(str)
    end

    def seterror
        @error = true
    end

    def error?
        return @error
    end

    def exit
        if @error then Kernel.exit(1) else Kernel.exit(0) end
    end

    def execute(str=nil)
        send(str || action || 'main')
        exit
    end

    def debug(*str)
        initlogger ; @logger.debug(str)
    end

    def error(*str)
        initlogger ; @logger.error(str)
    end

    def initlogger
        if @forcenewline then
            @logger.report
            @forcenewline = false
        end
    end

    def logger
        @logger
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
            if @commandline.help?(k) then
                kstr = ('--'+k).ljust(@commandline.helplength+2)
                message = @commandline.helptext(k)
                message = '' if message == CommandLine::NOHELP
                message = message.split(/\s*\n\s*/)
                loop do
                    report("#{kstr} #{message.shift}")
                    kstr = ' '*kstr.length
                    break if message.length == 0
                end
            end
        end
    end

    def option(key)
        @commandline.option(key)
    end
    def oneof(*key)
        @commandline.oneof(*key)
    end

    def globfiles(pattern='*',suffix=nil)
        @commandline.setarguments([pattern].flatten)
        if files = findfiles(suffix) then
            @commandline.setarguments(files)
        else
            @commandline.setarguments
        end
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
            # not {} safe
            pattern = '**/' + pattern if @commandline.option('recurse')
            files = Dir[pattern]
            if files && files.length>0 then
                return files
            else
                pattern = @commandline.argument('first')
                if FileTest.file?(pattern) then
                    return [pattern]
                else
                    report("no files match pattern #{pattern}")
                    return nil
                end
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
    NOHELP = 'no arguments'

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

    def setarguments(args=[])
        @arguments = if args then args else [] end
    end

    def register(option,shortcut,kind,default=false,action=false,helptext='')
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

    def option(str,default=nil)
        if @options.key?(str) then
            @options[str]
        elsif default then
            default
        else
            @options[str]
        end
    end

    def checkedoption(str,default='')
        if @options.key?(str) then
            if @options[str].empty? then default else @options[str] end
        else
            default
        end
    end

    def foundoption(str,default='')
        str = str.split(',') if str.class == String
        str.each do |s|
            return str if @options.key?(str)
        end
        return default
    end

    def oneof(*key)
        [*key].flatten.compact.each do |k|
           return true if @options.key?(k) && @options[k]
        end
        return false
    end

    def setoption(str,value)
        @options[str] = value
    end

    def getoption(str,value='') # value ?
        @options[str]
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

    def dirtyvalue(value) # \xFF suddenly doesn't work any longer
        if value then
            value.gsub(/([\"\'])(.*?)\1/) do
                $2.gsub(/\s+/o, "\0xFF")
            end
        else
            ''
        end
    end

    def cleanvalue(value) # \xFF suddenly doesn't work any longer
        if value then
            # value.sub(/^([\"\'])(.*?)\1$/) { $2.gsub(/\xFF/o, ' ') }
            value.gsub(/\0xFF/o, ' ')
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
                begin
                    re = /^#{key}/i
                rescue
                    key = key.inspect.sub(/^\"(.*)\"$/) do $1 end
                    re = /^#{key}/i
                ensure
                    if option =~ re then
                        case n
                            when 0
                                foundkey, foundkind, n = option, kind, 1
                            when 1
                                # ambiguous matches, like --fix => --fixme --fixyou
                                foundkey, foundkind = nil, nil
                                break
                        end
                    end
                end
            end
        end
        if foundkey then
            @provided[foundkey] = true
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

        series.each_char do |key| # was .each but there is no alias to each_char any longer
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

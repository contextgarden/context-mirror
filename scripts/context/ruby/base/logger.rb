# module    : base/logger
# copyright : PRAGMA Advanced Document Engineering
# version   : 2002-2005
# author    : Hans Hagen
#
# project   : ConTeXt / eXaMpLe
# concept   : Hans Hagen
# info      : j.hagen@xs4all.nl
# www       : www.pragma-ade.com

require 'thread'

# The next calls are valid:

# @log.report('a','b','c', 'd')
# @log.report('a','b',"c #{d}")
# @log.report("a b c #{d}")

# Keep in mind that "whatever #{something}" is two times faster than
# 'whatever ' + something or ['whatever',something].join and that
# when verbosity is not needed the following is much faster too:

# @log.report('a','b','c', 'd') if @log.verbose?
# @log.report('a','b',"c #{d}") if @log.verbose?
# @log.report("a b c #{d}")     if @log.verbose?

# The last three cases are equally fast when verbosity is turned off.

# Under consideration: verbose per instance

class Logger

    @@length  = 0
    @@verbose = false

    def initialize(tag=nil,length=0,verbose=false)
        @tag = tag || ''
        @@verbose = @@verbose || verbose
        @@length = @tag.length if @tag.length > @@length
        @@length =      length if      length > @@length
    end

    def report(*str)
        begin
            case str.length
                when 0
                    print("\n")
                    return true
                when 1
                  # message = str.first
                    message = str.first.join(' ')
                else
                    message = [str].flatten.collect{|s| s.to_s}.join(' ').chomp
            end
            if @tag.empty? then
                print("#{message}\n")
            else
                # try to avoid too many adjustments
                @tag = @tag.ljust(@@length) unless @tag.length == @@length
                print("#{@tag} | #{message}\n")
            end
        rescue
        end
        return true
    end

    def reportlines(*str)
        unless @tag.empty? then
            @tag = @tag.ljust(@@length) unless @tag.length == @@length
        end
        report([str].flatten.collect{|s| s.gsub(/\n/,"\n#{@tag} | ")}.join(' '))
    end

    def debug(*str)
        report(str) if @@verbose
    end

    def error(*str)
        if ! $! || $!.to_s.empty? then
            report(str)
        else
            report(str,$!)
        end
    end

    def verbose
        @@verbose = true
    end

    def silent
        @@verbose = false
    end

    def verbose?
        @@verbose
    end

    # attr_reader :tag

    # alias fatal  error
    # alias info   debug
    # alias warn   debug
    # alias debug? :verbose?

end

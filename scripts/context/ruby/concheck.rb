# Program   : concheck (tex & context syntax checker)
# Copyright : PRAGMA ADE / Hasselt NL / www.pragma-ade.com
# Author    : Hans Hagen
# Version   : 1.1 / 2003.08.18

# remarks:
#
# - the error messages are formatted like tex's messages so that scite can see them
# - begin and end tags are only tested on a per line basis because we assume clean sources
# - maybe i'll add begin{something} ... end{something} checking

# # example validation file
#
# begin interface en
#
# 1 text
# 4 Question
# 0 endinput
# 0 setupsomething
# 0 chapter
#
# end interface en

# nicer

# class Interface

    # def initialize (language = 'unknown')
        # @valid = Array.new
        # @language = language
    # end

    # def register (left, right)
        # @valid.push([left,right])
    # end

# end

# $interfaces = Hash.new

# $interfaces['en'] = Interface.new('english')
# $interfaces['nl'] = Interface.new('dutch')

# $interfaces['en'].add('\\\\start','\\\\stop')
# $interfaces['en'].add('\\\\begin','\\\\end')
# $interfaces['en'].add('\\\\Start','\\\\Stop')
# $interfaces['en'].add('\\\\Begin','\\\\End')

# $interfaces['nl'].add('\\\\start','\\\\stop')
# $interfaces['nl'].add('\\\\beginvan','\\\\eindvan')
# $interfaces['nl'].add('\\\\Start','\\\\Stop')
# $interfaces['nl'].add('\\\\BeginVan','\\\\Eindvan')

# rest todo

$valid = Hash.new

$valid['en'] = Array.new
$valid['nl'] = Array.new

#$valid['en'].push(['',''])
$valid['en'].push(['\\\\start','\\\\stop'])
$valid['en'].push(['\\\\begin','\\\\end'])
$valid['en'].push(['\\\\Start','\\\\Stop'])
$valid['en'].push(['\\\\Begin','\\\\End'])

#$valid['nl'].push(['',''])
$valid['nl'].push(['\\\\start','\\\\stop'])
$valid['nl'].push(['\\\\beginvan','\\\\eindvan'])
$valid['nl'].push(['\\\\Start','\\\\Stop'])
$valid['nl'].push(['\\\\BeginVan','\\\\Eindvan'])

$valid_tex = "\\\\end\(input|insert|csname|linechar|graf|buffer|strut\)"
$valid_mp  = "(enddef||end||endinput)"

$start_verbatim = Hash.new
$stop_verbatim  = Hash.new

$start_verbatim['en'] = '\\\\starttyping'
$start_verbatim['nl'] = '\\\\starttypen'

$stop_verbatim['en'] = '\\\\stoptyping'
$stop_verbatim['nl'] = '\\\\stoptypen'

def message(str, filename=nil, line=nil, column=nil)
    if filename then
        if line then
            if column then
                puts("error in file #{filename} at line #{line} in column #{column}: #{str}\n")
            else
                puts("error in file #{filename} at line #{line}: #{str}\n")
            end
        else
            puts("file #{filename}: #{str}\n")
        end
    else
        puts(str+"\n")
    end
end

def load_file (filename='')
    begin
        data = IO.readlines(filename)
        data.collect! do |d|
            if d =~ /^\s*%/o then
                ''
            elsif d =~ /(.*?[^\\])%.*$/o then
                $1
            else
                d
            end
        end
    rescue
        message("provide proper filename")
        return nil
    end
    # print data.to_s + "\n"
    return data
end

def guess_interface(data)
    if data.first =~ /^%.*interface\=(.*)\s*/ then
        return $1
    else
        data.each do |line|
            case line
                when /\\(starttekst|stoptekst|startonderdeel|startdocument|startoverzicht)/o then return 'nl'
                when /\\(stelle|verwende|umgebung|benutze)/o                                 then return 'de'
                when /\\(stel|gebruik|omgeving)/                                             then return 'nl'
                when /\\(use|setup|environment)/                                             then return 'en'
                when /\\(usa|imposta|ambiente)/                                              then return 'it'
                when /(height|width|style)=/                                                 then return 'en'
                when /(hoehe|breite|schrift)=/                                               then return 'de'
                when /(hoogte|breedte|letter)=/                                              then return 'nl'
                when /(altezza|ampiezza|stile)=/                                             then return 'it'
                when /externfiguur/                                                          then return 'nl'
                when /externalfigure/                                                        then return 'en'
                when /externeabbildung/                                                      then return 'de'
                when /figuraesterna/                                                         then return 'it'
            end
        end
        return 'en'
    end
end

def cleanup_data(data, interface='en')
    verbatim = 0
    re_start = /^\s*#{$start_verbatim[interface]}/
    re_stop = /^\s*#{$stop_verbatim[interface]}/
    data.collect! do |d|
        if d =~ re_start then
            verbatim += 1
            if verbatim>1 then
                ''
            else
                d
            end
        elsif d =~ re_stop then
            verbatim -= 1
            if verbatim>0 then
                ''
            else
                d
            end
        elsif verbatim > 0 then
            ''
        else
            d
        end
    end
    return data
end

def load_valid(data, interface=nil)
    if data && (data.first =~ /^%.*valid\=(.*)\s*/)
        filename = $1
        filename = '../' + filename unless test(?f,filename)
        filename = '../' + filename unless test(?f,filename)
        if test(?f,filename) then
            interface = guess_interface(data) unless interface
            if $valid.has_key?(interface) then
                interface = $valid[interface]
            else
                interface = $valid['en']
            end
            begin
                message("loading validation file",filename)
                validkeys = Hash.new
                line = 1
                IO.readlines(filename).each do |l|
                    if l =~ /\s+[\#\%]/io then
                        # ignore line
                    elsif l =~ /^\s*(begin|end)\s+interface\s+([a-z][a-z])/o then
                        # not yet supported
                    elsif l =~ /^\s*(\d+)\s+([a-zA-Z]*)$/o then
                        type, key = $1.to_i, $2.strip
                        if interface[type] then
                            validkeys[interface[type].first+key] = true
                            validkeys[interface[type].last+key]  = true
                        else
                            error_message(filename,line,nil,'wrong definition')
                        end
                    end
                    line += 1
                end
                if validkeys then
                    message("#{validkeys.length} validation keys loaded",filename)
                end
                return validkeys
            rescue
                message("invalid validation file",filename)
            end
        else
            message("unknown validation file", filename)
        end
    else
        message("no extra validation file specified")
    end
    return nil
end

def some_chr_error(data, filename, left, right)
    levels = Array.new
    for line in 0..data.length-1 do
         str = data[line]
         # str = data[line].gsub(/\\[\#{left}\#{right}]/,'')
         column = 0
         while column<str.length do
            case str[column].chr
                when "\%" then
                    break
                when "\\" then
                    column += 2
                when left then
                    levels.push([line,column])
                    column += 1
                when right then
                    if levels.pop
                        column += 1
                    else
                        message("missing #{left} for #{right}",filename,line+1,column+1)
                        return true
                    end
                else
                    column += 1
            end
        end
    end
    if levels && levels.length>0 then
        levels.each do |l|
            column = l.pop
            line = l.pop
            message("missing #{right} for #{left}",filename,line+1,column+1)
        end
        return true
    else
        return false
    end
end

def some_wrd_error(data, filename, start, stop, ignore)
    levels = Array.new
    len = 0
    re_start = /[^\%]*(#{start})([a-zA-Z]*)/
    re_stop = /[^\%]*(#{stop})([a-zA-Z]*)/
    re_ignore = /#{ignore}.*/
    str_start = start.gsub(/\\+/,'\\')
    str_stop = stop.gsub(/\\+/,'\\')
    line = 0
    while line<data.length do
        dataline = data[line].split(/[^\\A-Za-z]/)
        if dataline.length>0 then
            # todo: more on one line
            dataline.each do |dataword|
                case dataword
                    when re_ignore then
                        # just go on
                    when re_start then
                        levels.push([line,$2])
                        # print ' '*levels.length + '>' + $2 + "\n"
                    when re_stop then
                        # print ' '*levels.length + '<' + $2 + "\n"
                        if levels && levels.last && (levels.last[1] == $2) then
                            levels.pop
                        elsif levels && levels.last then
                            message("#{str_stop}#{levels.last[1]} expected instead of #{str_stop}#{$2}",filename,line+1)
                            return true
                        else
                            message("missing #{str_start}#{$2} for #{str_stop}#{$2}",filename,line+1)
                            return true
                        end
                    else
                        # just go on
                end
            end
        end
        line += 1
    end
    if levels && levels.length>0 then
        levels.each do |l|
            text = l.pop
            line = l.pop
            message("missing #{str_stop}#{text} for #{str_start}#{text}",filename,line+1)
        end
        return true
    else
        return false
    end
end

def some_sym_error (data, filename, symbol, template=false)
    saved = Array.new
    inside = false
    level = 0
    for line in 0..data.length-1 do
         str = data[line]
         column = 0
         while column<str.length do
            case str[column].chr
                when "[" then
                    level += 1 if template
                when "]" then
                    level -= 1 if template && level > 0
                when "\%" then
                    break
                when "\\" then
                    column += 1
                when symbol then
                    if level == 0 then
                        inside = ! inside
                        saved = [line,column]
                    else
                        # we're in some kind of template or so
                    end
                else
                    # go on
            end
            column += 1
        end
    end
    if inside && saved && level == 0 then
        column = saved.pop
        line = saved.pop
        message("missing #{symbol} for #{symbol}",filename,line+1)
        return true
    else
        return false
    end
end

def some_key_error(data, filename, valid)
    return if (! valid) || (valid.length == 0)
    error = false
    # data.foreach do |line| ... end
    for line in 0..data.length-1 do
        data[line].scan(/\\([a-zA-Z]+)/io) do
            unless valid.has_key?($1) then
                message("unknown command \\#{$1}",filename,line+1)
                error = true
            end
        end
    end
    return error
end

# todo : language dependent

def check_file_tex (filename)
    error = false
    if data = load_file(filename) then
        message("checking tex file", filename)
        interface = guess_interface(data)
        valid = load_valid(data,interface)
        data = cleanup_data(data,interface)
        # data.each do |d| print d  end
        $valid[interface].each do |v|
            if some_wrd_error(data, filename, v[0], v[1] ,$valid_tex) then
                error = true
                break
            end
        end
        # return false if some_wrd_error(data, filename, '\\\\start'   , '\\\\stop'   , $valid_tex)
        # return false if some_wrd_error(data, filename, '\\\\Start'   , '\\\\Stop'   , $valid_tex)
        # return false if some_wrd_error(data, filename, '\\\\beginvan', '\\\\eindvan', $valid_tex)
        # return false if some_wrd_error(data, filename, '\\\\begin'   , '\\\\end|\\\\eind', $valid_tex)
        error = true if some_sym_error(data, filename, '$', false)
        error = true if some_sym_error(data, filename, '|', true)
        error = true if some_chr_error(data, filename, '{', '}')
        error = true if some_chr_error(data, filename, '[', ']')
        error = true if some_chr_error(data, filename, '(', ')')
        error = true if some_key_error(data, filename, valid)
        message("no errors in tex code", filename) unless error
        return error
    else
        return false
    end
end

def check_file_mp (filename)
    error = false
    if data = load_file(filename) then
        message("checking metapost file", filename)
        interface = guess_interface(data)
        valid = load_valid(data,interface)
        $valid[interface].each do |v|
            if some_wrd_error(data, filename, v[0], v[1] ,$valid_tex) then
                error = true
                break
            end
        end
        # return false if some_wrd_error(data, filename, '', 'begin', 'end', $valid_mp)
        error = true if some_chr_error(data, filename, '{', '}')
        error = true if some_chr_error(data, filename, '[', ']')
        error = true if some_chr_error(data, filename, '(', ')')
        error = true if some_key_error(data, filename, valid)
        message("no errors in metapost code", filename) unless error
        return error
    else
        return false
    end
end

def check_file_text(filename='')
    if data = load_file(filename) then
        for line in 0..data.length-1 do
            # case data[line]
                # when /\s([\:\;\,\.\?\!])/ then
                    # message("space before #{$1}",filename,line+1)
                # when /\D([\:\;\,\.\?\!])\S/ then
                    # message("no space after #{$1}",filename,line+1)
            # end
            if data[line] =~ /\s([\:\;\,\.\?\!])/ then
                message("space before #{$1}",filename,line+1)
            else
                data[line].gsub!(/\[.*?\]/o, '')
                data[line].gsub!(/\(.*?\)/o, '')
                data[line].gsub!(/\[.*?$/o, '')
                data[line].gsub!(/^.*?\]/o, '')
                if data[line] =~ /\D([\:\;\,\.\?\!])\S/ then
                    message("no space after #{$1}",filename,line+1)
                end
            end
        end
    end
end

def check_file(filename='')
    case filename
        when '' then
            message("provide filename")
            return false
        when /\.(tex|mk.+)$/i then
            return check_file_tex(filename) # && check_file_text(filename)
        when /\.mp$/i then
            return check_file_mp(filename)
        else
            message("only tex and metapost files are checked")
            return false
    end
end

if ARGV.size > 0 then
    someerror = false
    ARGV.each do |filename|
         somerror = true if check_file(filename)
    end
    exit (if someerror then 1 else 0 end)
else
    exit 1
end


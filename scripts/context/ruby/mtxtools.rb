#!/usr/bin/env ruby

# program   : mtxtools
# copyright : PRAGMA Advanced Document Engineering
# version   : 2004-2005
# author    : Hans Hagen
#
# info      : j.hagen@xs4all.nl
# www       : www.pragma-ade.com

# This script hosts MetaTeX related features.

banner = ['MtxTools', 'version 1.0.0', '2006', 'PRAGMA ADE/POD']

$: << File.expand_path(File.dirname($0)) ; $: << File.join($:.last,'lib') ; $:.uniq!

require 'base/switch'
require 'base/logger'
require 'base/system'
require 'base/kpse'

class Reporter
    def report(str)
        puts(str)
    end
end

module ConTeXt

    def ConTeXt::banner(filename,companionname,compact=false)
        "-- filename : #{File.basename(filename)}\n" +
        "-- comment  : companion to #{File.basename(companionname)} (in ConTeXt)\n" +
        "-- author   : Hans Hagen, PRAGMA-ADE, Hasselt NL\n" +
        "-- copyright: PRAGMA ADE / ConTeXt Development Team\n" +
        "-- license  : see context related readme files\n" +
        if compact then "\n-- remark   : compact version\n" else "" end
    end

end

class UnicodeTables

    @@version = "1.001"

    @@shape_a = /^((GREEK|LATIN|HEBREW)\s*(SMALL|CAPITAL|)\s*LETTER\s*[A-Z]+)$/
    @@shape_b = /^((GREEK|LATIN|HEBREW)\s*(SMALL|CAPITAL|)\s*LETTER\s*[A-Z]+)\s*(.+)$/

    @@shape_a = /^(.*\s*LETTER\s*[A-Z]+)$/
    @@shape_b = /^(.*\s*LETTER\s*[A-Z]+)\s+WITH\s+(.+)$/

    attr_accessor :context, :comment

    def initialize(logger=Reporter.new)
        @data    = Array.new
        @logger  = logger
        @error   = false
        @context = true
        @comment = true
        @shapes  = Hash.new
    end

    def load_unicode_data(filename='unicodedata.txt')
        # beware, the unicodedata table is bugged, sometimes ending
        @logger.report("reading base data from #{filename}") if @logger
        begin
            IO.readlines(filename).each do |line|
                if line =~ /^[0-9A-F]{4,4}/ then
                    d = line.chomp.sub(/\;$/, '').split(';')
                    if d then
                        while d.size < 15 do d << '' end
                        n = d[0].hex
                        @data[n] = d
                        if d[1] =~ @@shape_a then
                            @shapes[$1] = d[0]
                        end
                    end
                end
            end
        rescue
            @error = true
            @logger.report("error while reading base data from #{filename}") if @logger
        end
    end

    def load_context_data(filename='contextnames.txt')
        @logger.report("reading data from #{filename}") if @logger
        begin
            IO.readlines(filename).each do |line|
                if line =~ /^[0-9A-F]{4,4}/ then
                    d = line.chomp.split(';')
                    if d then
                        n = d[0].hex
                        if @data[n] then
                            @data[d[0].hex] << d[1] # adobename   == 15
                            @data[d[0].hex] << d[2] # contextname == 16
                        else
                            @logger.report("missing information about #{d} in #{filename}") if @logger
                        end
                    end
                end
            end
        rescue
            @error = true
            @logger.report("error while reading context data from #{filename}") if @logger
        end
    end

    def save_metatex_data(filename='char-def.lua',compact=false)
        if not @error then
            begin
                File.open(filename,'w') do |f|
                    @logger.report("saving data in #{filename}") if @logger
                    f << ConTeXt::banner(filename,'char-def.tex',compact)
                    f << "\n"
                    f << "\nif not versions then versions = { } end versions['#{filename.gsub(/\..*?$/,'')}'] = #{@@version}\n"
                    f << "\n"
                    f << "if not characters      then characters      = { } end\n"
                    f << "if not characters.data then characters.data = { } end\n"
                    f << "\n"
                    f << "characters.data = {\n" if compact
                    @data.each do |d|
                        if d then
                            r = metatex_data(d)
                            if compact then
                                f << "\t" << "[0x#{d[0]}]".rjust(8,' ') << " = { #{r.join(", ").gsub(/\t/,'')} }, \n"
                            else
                                f << "characters.define { -- #{d[0].hex}" << "\n"
                                f << r.join(",\n") << "\n"
                                f << "}" << "\n"
                            end
                        end
                    end
                    f << "}\n" if compact
                end
            rescue
                @logger.report("error while saving data in #{filename}") if @logger
            else
                @logger.report("#{@data.size} (#{sprintf('%X',@data.size)}) entries saved in #{filename}") if @logger
            end
        else
            @logger.report("not saving data in #{filename} due to previous error") if @logger
        end
    end

    def metatex_data(d)
        r = Array.new
        r << "\tunicodeslot=0x#{d[0]}"
        if d[2] && ! d[2].empty? then
            r << "\tcategory='#{d[2].downcase}'"
        end
        if @context then
            if d[15] && ! d[15].empty? then
                r << "\tadobename='#{d[15]}'"
            end
            if d[16] && ! d[16].empty? then
                r << "\tcontextname='#{d[16]}'"
            end
        end
        if @comment then
            if d[1] == "<control>" then
                r << "\tdescription='#{d[10]}'" unless d[10].empty?
            else
                r << "\tdescription='#{d[1]}'" unless d[1].empty?
            end
        end
        if d[1] =~ @@shape_b then
            r << "\tshcode=0x#{@shapes[$1]}" if @shapes[$1]
        end
        if d[12] && ! d[12].empty? then
            r << "\tuccode=0x#{d[12]}"
        elsif d[14] && ! d[14].empty? then
            r << "\tuccode=0x#{d[14]}"
        end
        if d[13] && ! d[13].empty? then
            r << "\tlccode=0x#{d[13]}"
        end
        if d[5] && ! d[5].empty? then
            special, specials = '', Array.new
            c = d[5].split(/\s+/).collect do |cc|
                if cc =~ /^\<(.*)\>$/io then
                    special = $1.downcase
                else
                    specials << "0x#{cc}"
                end
            end
            if specials.size > 0 then
                special = 'char' if special.empty?
                r << "\tspecials={'#{special}',#{specials.join(',')}}"
            end
        end
        return r
    end

    def save_xetex_data(filename='enco-utf.tex')
        if not @error then
            begin
                minnumber, maxnumber, n = 0x001F, 0xFFFF, 0
                File.open(filename,'w') do |f|
                    @logger.report("saving data in #{filename}") if @logger
                    f << "% filename : #{filename}\n"
                    f << "% comment  : poor man's alternative for a proper enco file\n"
                    f << "%            this file is generated by mtxtools and can be\n"
                    f << "%            used in xetex and luatex mkii mode\n"
                    f << "% author   : Hans Hagen, PRAGMA-ADE, Hasselt NL\n"
                    f << "% copyright: PRAGMA ADE / ConTeXt Development Team\n"
                    f << "% license  : see context related readme files\n"
                    f << "\n"
                    f << "\\ifx\\setcclcucx\\undefined\n"
                    f << "\n"
                    f << "  \\def\\setcclcucx #1 #2 #3 %\n"
                    f << "    {\\global\\catcode\"#1=11 \n"
                    f << "     \\global\\lccode \"#1=\"#2 \n"
                    f << "     \\global\\uccode \"#1=\"#3 }\n"
                    f << "\n"
                    f << "\\fi\n"
                    f << "\n"
                    @data.each do |d|
                        if d then
                            number, type = d[0], d[2].downcase
                            if number.hex >= minnumber && number.hex <= maxnumber && type =~ /^l(l|u|t)$/o then
                                if d[13] && ! d[13].empty? then
                                    lc = d[13]
                                else
                                    lc = number
                                end
                                if d[12] && ! d[12].empty? then
                                    uc = d[12]
                                elsif d[14] && ! d[14].empty? then
                                    uc = d[14]
                                else
                                    uc = number
                                end
                                if @comment then
                                    f << "\\setcclcuc #{number} #{lc} #{uc} % #{d[1]}\n"
                                else
                                    f << "\\setcclcuc #{number} #{lc} #{uc} \n"
                                end
                                n += 1
                            end
                        end
                    end
                    f << "\n"
                    f << "\\endinput\n"
                end
            rescue
                @logger.report("error while saving data in #{filename}") if @logger
            else
                @logger.report("#{n} entries saved in #{filename}") if @logger
            end
        else
            @logger.report("not saving data in #{filename} due to previous error") if @logger
        end
    end

end

class RegimeTables

    @@version = "1.001"

    def initialize(logger=Reporter.new)
        @logger = logger
        reset
    end

    def reset
        @code, @regime, @filename, @loaded = Array.new(256), '', '', false
        (32..127).each do |i|
            @code[i] = [sprintf('%04X',i), i.chr]
        end
    end

    def load(filename)
        begin
            reset
            if filename =~ /regi\-(ini|run|uni|utf|syn)/ then
                report("skipping #{filename}")
            else
                report("loading file #{filename}")
                @regime, unicodeset = File.basename(filename).sub(/\..*?$/,''), false
                IO.readlines(filename).each do |line|
                    case line
                        when /^\#/ then
                            # skip
                        when /^(0x[0-9A-F]+)\s+(0x[0-9A-F]+)\s+\#\s+(.*)$/ then
                            @code[$1.hex], unicodeset = [$2, $3], true
                        when /^(0x[0-9A-F]+)\s+(0x[0-9A-F]+)\s+/ then
                            @code[$1.hex], unicodeset = [$2, ''], true
                    end
                end
                reset if not unicodeset
            end
        rescue
            report("problem in loading file #{filename}")
            reset
        else
            if ! @regime.empty? then
                @loaded = true
            else
                reset
            end
        end
    end

    def save(filename,compact=false)
        begin
            if @loaded && ! @regime.empty? then
                if File.expand_path(filename) == File.expand_path(@filename) then
                    report("saving in #{filename} is blocked")
                else
                    report("saving file #{filename}")
                    File.open(filename,'w') do |f|
                        f << ConTeXt::banner(filename,'regi-ini.tex',compact)
                        f << "\n"
                        f << "\nif not versions then versions = { } end versions['#{filename.gsub(/\..*?$/,'')}'] = #{@@version}\n"
                        f << "\n"
                        f << "if not regimes      then regimes      = { } end\n"
                        f << "if not regimes.data then regimes.data = { } end\n"
                        f << "\n"
                        if compact then
                            f << "regimes.data[\"#{@regime}\"] = { [0] = \n\t"
                            i = 17
                            @code.each_index do |c|
                                if (i-=1) == 0 then
                                    i = 16
                                    f << "\n\t"
                                end
                                if @code[c] then
                                    f << @code[c][0].rjust(6,' ')
                                else
                                    f << "0x0000".rjust(6,' ')
                                end
                                f << ', ' if c<@code.length-1
                            end
                            f << "\n}\n"
                        else
                            @code.each_index do |c|
                                if @code[c] then
                                    f << someregimeslot(@regime,c,@code[c][0],@code[c][1])
                                else
                                    f << someregimeslot(@regime,c,'','')
                                end
                            end
                        end
                    end
                end
            end
        rescue
            report("problem in saving file #{filename} #{$!}")
        end
    end

    def report(str)
        @logger.report(str)
    end

    private

    def someregimeslot(regime,slot,unicodeslot,comment)
        "regimes.define { #{if comment.empty? then '' else '-- ' end} #{comment}\n" +
            "\tregime='#{regime}',\n" +
            "\tslot='#{sprintf('0x%02X',slot)}',\n" +
            "\tunicodeslot='#{if unicodeslot.empty? then '0x0000' else unicodeslot end}'\n" +
        "}\n"
    end

    public

    def RegimeTables::convert(filenames,compact=false)
        filenames.each do |filename|
            txtfile = File.expand_path(filename)
            luafile = File.join(File.dirname(txtfile),'regi-'+File.basename(txtfile.sub(/\..*?$/, '.lua')))
            unless txtfile == luafile then
                regime = RegimeTables.new
                regime.load(txtfile)
                regime.save(luafile,compact)
            end
        end
    end

end

class Commands

    include CommandBase

    def unicodetable
        unicode = UnicodeTables.new(logger)
        unicode.load_unicode_data
        unicode.load_context_data
        unicode.save_metatex_data('char-def.lua',@commandline.option('compact'))
    end

    def xetextable
        unicode = UnicodeTables.new(logger)
        unicode.load_unicode_data
        unicode.load_context_data
        # unicode.comment = false
        unicode.save_xetex_data
    end

    def regimetable
        if @commandline.arguments.length > 0 then
            RegimeTables::convert(@commandline.arguments, @commandline.option('compact'))
        else
            RegimeTables::convert(Dir.glob("cp*.txt")   , @commandline.option('compact'))
            RegimeTables::convert(Dir.glob("8859*.txt") , @commandline.option('compact'))
        end
    end

    def pdftextable
        # instead of directly saving the data, we use luatex (kind of test)
        pdfrdef = 'pdfr-def.tex'
        tmpfile = 'mtxtools.tmp'
        File.delete(pdfrdef) rescue false
        if f = File.open(tmpfile,'w') then
            f << "\\starttext\n"
            f << "\\ctxlua{characters.pdftex.make_pdf_to_unicodetable('#{pdfrdef}')}\n"
            f << "\\stoptext\n"
            f.close()
            system("texmfstart texexec --luatex --once --purge mtxtools.tmp")
            report("vecor saved in #{pdfrdef}")
        end
        File.delete(tmpfile) rescue false
    end

    def xmlmapfile
        # instead of directly saving the data, we use luatex (kind of test)
        tmpfile   = 'mtxtools.tmp'
        xmlsuffix = 'frx'
        @commandline.arguments.each do |mapname|
            if f = File.open(tmpfile,'w') then
                xmlname = mapname.gsub(/\.map$/,".#{xmlsuffix}")
                File.delete(xmlname) rescue false
                f << "\\starttext\n"
                f << "\\ctxlua{\n"
                f << "  mapname = input.find_file(texmf.instance,'#{mapname}') or ''\n"
                f << "  xmlname = '#{xmlname}'\n"
                f << "  if mapname and not mapname:is_empty() then\n"
                f << "    ctx.fonts.map.convert_file(mapname,xmlname)\n"
                f << "  end\n"
                f << "}\n"
                f << "\\stoptext\n"
                f.close()
                system("texmfstart texexec --luatex --once --purge mtxtools.tmp")
                if FileTest.file?(xmlname) then
                    report("map file #{mapname} converted to #{xmlname}")
                else
                    report("no valid map file #{mapname}")
                end
            end
        end
        File.delete(tmpfile) rescue false
    end

end

logger      = Logger.new(banner.shift)
commandline = CommandLine.new

commandline.registeraction('unicodetable', 'create unicode table for metatex/luatex')
commandline.registeraction('regimetable' , 'create regime table(s) for metatex/luatex [--compact]')
commandline.registeraction('xetextable'  , 'create unicode table for xetex')
commandline.registeraction('pdftextable' , 'create unicode table for xetex')
commandline.registeraction('xmlmapfile'  , 'convert traditional mapfile to xml font resourse')

# general

commandline.registeraction('help')
commandline.registeraction('version')
commandline.registerflag('compact')

commandline.expand

Commands.new(commandline,logger,banner).send(commandline.action || 'help')

#!/usr/bin/env ruby

# program   : ctxtools
# copyright : PRAGMA Advanced Document Engineering
# version   : 2004-2005
# author    : Hans Hagen
#
# project   : ConTeXt / eXaMpLe
# concept   : Hans Hagen
# info      : j.hagen@xs4all.nl
# www       : www.pragma-ade.com

# This script will harbor some handy manipulations on context
# related files.

# todo: move scite here
#
# todo: move kpse call to kpse class/module

banner = ['CtxTools', 'version 1.2.2', '2004/2005', 'PRAGMA ADE/POD']

unless defined? ownpath
    ownpath = $0.sub(/[\\\/][a-z0-9\-]*?\.rb/i,'')
    $: << ownpath
end

require 'base/switch'
require 'base/logger'
require 'base/system'

require 'rexml/document'
require 'ftools'
require 'kconv'

exit if defined?(REQUIRE2LIB)

class String

    def i_translate(element, attribute, category)
        self.gsub!(/(<#{element}.*?#{attribute}=)([\"\'])(.*?)\2/) do
            if category.key?($3) then
                # puts "#{element} #{$3} -> #{category[$3]}\n" if element == 'cd:inherit'
                # puts "#{element} #{$3} => #{category[$3]}\n" if element == 'cd:command'
                "#{$1}#{$2}#{category[$3]}#{$2}"
            else
                # puts "#{element} #{$3} -> ?\n" if element == 'cd:inherit'
                # puts "#{element} #{$3} => ?\n" if element == 'cd:command'
                "#{$1}#{$2}#{$3}#{$2}" # unchanged
            end
        end
    end

    def i_load(element, category)
        self.scan(/<#{element}.*?name=([\"\'])(.*?)\1.*?value=\1(.*?)\1/) do
            category[$2] = $3
        end
    end

end

class Commands

    include CommandBase

    public

    def touchcontextfile
        dowithcontextfile(1)
    end

    def contextversion
        dowithcontextfile(2)
    end

    private

    def dowithcontextfile(action)
        maincontextfile = 'context.tex'
        unless FileTest.file?(maincontextfile) then
            begin
                maincontextfile = `kpsewhich -progname=context #{maincontextfile}`.chomp
            rescue
                maincontextfile = ''
            end
        end
        unless maincontextfile.empty? then
            case action
                when 1 then touchfile(maincontextfile)
                when 2 then reportversion(maincontextfile)
            end
        end

    end

    def touchfile(filename)

        if FileTest.file?(filename) then
            if data = IO.read(filename) then
                timestamp = Time.now.strftime('%Y.%m.%d')
                prevstamp = ''
                begin
                    data.gsub!(/\\contextversion\{(\d+\.\d+\.\d+)\}/) do
                        prevstamp = $1
                        "\\contextversion{#{timestamp}}"
                    end
                rescue
                else
                    begin
                        File.delete(filename+'.old')
                    rescue
                    end
                    begin
                        File.copy(filename,filename+'.old')
                    rescue
                    end
                    begin
                        if f = File.open(filename,'w') then
                            f.puts(data)
                            f.close
                        end
                    rescue
                    end
                end
                if prevstamp.empty? then
                    report("#{filename} is not updated, no timestamp found")
                else
                    report("#{filename} is updated from #{prevstamp} to #{timestamp}")
                end
            end
        else
            report("#{filename} is not found")
        end

    end

    def reportversion(filename)

        version = 'unknown'
        begin
            if FileTest.file?(filename) && IO.read(filename).match(/\\contextversion\{(\d+\.\d+\.\d+)\}/) then
                version = $1
            end
        rescue
        end
        if @commandline.option("pipe") then
            print version
        else
            report("context version: #{version}")
        end

    end

end

class Commands

    include CommandBase

    public

    def jeditinterface
        editinterface('jedit')
    end

    def bbeditinterface
        editinterface('bbedit')
    end

    def sciteinterface
        editinterface('scite')
    end

    def rawinterface
        editinterface('raw')
    end

    private

    def editinterface(type='raw')

        return unless FileTest.file?("cont-en.xml")

        interfaces = @commandline.arguments

        if interfaces.empty? then
            interfaces = ['en', 'cz','de','it','nl','ro']
        end

        interfaces.each do |interface|
            begin
                collection = Hash.new
                mappings   = Hash.new
                if f = open("keys-#{interface}.xml") then
                    while str = f.gets do
                        if str =~ /\<cd\:command\s+name=\"(.*?)\"\s+value=\"(.*?)\".*?\>/o then
                            mappings[$1] = $2
                        end
                    end
                    f.close
                    if f = open("cont-en.xml") then
                        while str = f.gets do
                            if str =~ /\<cd\:command\s+name=\"(.*?)\"\s+type=\"environment\".*?\>/o then
                                collection["start#{mappings[$1]}"] = ''
                                collection["stop#{mappings[$1]}"]  = ''
                            elsif str =~ /\<cd\:command\s+name=\"(.*?)\".*?\>/o then
                                collection["#{mappings[$1]}"] = ''
                            end
                        end
                        f.close
                        case type
                            when 'jedit' then
                                if f = open("context-jedit-#{interface}.xml", 'w') then
                                    f.puts("<?xml version='1.0'?>\n\n")
                                    f.puts("<!DOCTYPE MODE SYSTEM 'xmode.dtd'>\n\n")
                                    f.puts("<MODE>\n")
                                    f.puts("  <RULES>\n")
                                    f.puts("    <KEYWORDS>\n")
                                    collection.keys.sort.each do |name|
                                        f.puts("      <KEYWORD2>\\#{name}</KEYWORD2>\n") unless name.empty?
                                    end
                                    f.puts("    </KEYWORDS>\n")
                                    f.puts("  </RULES>\n")
                                    f.puts("</MODE>\n")
                                    f.close
                                end
                            when 'bbedit' then
                                if f = open("context-bbedit-#{interface}.xml", 'w') then
                                    f.puts("<?xml version='1.0'?>\n\n")
                                    f.puts("<key>BBLMKeywordList</key>\n")
                                    f.puts("<array>\n")
                                    collection.keys.sort.each do |name|
                                        f.puts("    <string>\\#{name}</string>\n") unless name.empty?
                                    end
                                    f.puts("</array>\n")
                                    f.close
                                end
                            when 'scite' then
                                if f = open("cont-#{interface}-scite.properties", 'w') then
                                    i = 0
                                    f.write("keywordclass.macros.context.#{interface}=")
                                    collection.keys.sort.each do |name|
                                        unless name.empty? then
                                            if i==0 then
                                                f.write("\\\n    ")
                                                i = 5
                                            else
                                                i = i - 1
                                            end
                                            f.write("#{name} ")
                                        end
                                    end
                                    f.write("\n")
                                    f.close
                                end
                            else # raw
                                collection.keys.sort.each do |name|
                                    puts("\\#{name}\n") unless name.empty?
                                end
                        end
                    end
                end
            end
        end

    end

end

class Commands

    include CommandBase

    public

    def translateinterface

        # since we know what kind of file we're dealing with,
        # we do it quick and dirty instead of using rexml or
        # xslt

        interfaces = @commandline.arguments

        if interfaces.empty? then
            interfaces = ['cz','de','it','nl','ro']
        else
            interfaces.delete('en')
        end

        interfaces.flatten.each do |interface|

            variables, constants, strings, list, data = Hash.new, Hash.new, Hash.new, '', ''

            keyfile, intfile, outfile = "keys-#{interface}.xml", "cont-en.xml", "cont-#{interface}.xml"

            report("generating #{keyfile}")

            begin
                one = "texexec --make --alone --all #{interface}"
                two = "texexec --batch --silent --interface=#{interface} x-set-01"
                if @commandline.option("force") then
                    system(one)
                    system(two)
                elsif not system(two) then
                    system(one)
                    system(two)
                end
            rescue
            end

                unless File.file?(keyfile) then
                report("no #{keyfile} generated")
                next
            end

            report("loading #{keyfile}")

            begin
                list = IO.read(keyfile)
            rescue
                list = empty
            end

            if list.empty? then
                report("error in loading #{keyfile}")
                next
            end

            list.i_load('cd:variable', variables)
            list.i_load('cd:constant', constants)
            list.i_load('cd:command' , strings)
            # list.i_load('cd:element' , strings)

            report("loading #{intfile}")

            begin
                data = IO.read(intfile)
            rescue
                data = empty
            end

            if data.empty? then
                report("error in loading #{intfile}")
                next
            end

            report("translating interface en to #{interface}")

            data.i_translate('cd:string'   , 'value', strings)
            data.i_translate('cd:variable' , 'value', variables)
            data.i_translate('cd:parameter', 'name' , constants)
            data.i_translate('cd:constant' , 'type' , variables)
            data.i_translate('cd:variable' , 'type' , variables)
            data.i_translate('cd:inherit'  , 'name' , strings)
            # data.i_translate('cd:command'  , 'name' , strings)

            report("saving #{outfile}")

            begin
                if f = File.open(outfile, 'w') then
                    f.write(data)
                    f.close
                end
            rescue
            end

        end

    end

end

class Commands

    include CommandBase

    public

    def purgefiles(all=false)

        pattern  = @commandline.arguments
        purgeall = @commandline.option("all") || all
        recurse  = @commandline.option("recurse")

        $dontaskprefixes.push(Dir.glob("mpx-*"))
        $dontaskprefixes.flatten!
        $dontaskprefixes.sort!

        if purgeall then
          $forsuresuffixes.push($texnonesuffixes)
          $texnonesuffixes = []
          $forsuresuffixes.flatten!
        end

        if ! pattern || pattern.empty? then
            globbed = if recurse then "**/*.*" else "*.*" end
            files = Dir.glob(globbed)
            report("purging files : #{globbed}")
        else
            pattern.each do |pat|
                globbed = if recurse then "**/#{pat}-*.*" else "#{pat}-*.*" end
                files = Dir.glob(globbed)
                globbed = if recurse then "**/#{pat}.*" else "#{pat}.*" end
                files.push(Dir.glob(globbed))
            end
            report("purging files : #{pattern.join(' ')}")
        end
        files.flatten!
        files.sort!

        $dontaskprefixes.each do |file|
            removecontextfile(file)
        end
        $dontasksuffixes.each do |suffix|
            files.each do |file|
                removecontextfile(file) if file =~ /#{suffix}$/i
            end
        end
        $forsuresuffixes.each do |suffix|
            files.each do |file|
                removecontextfile(file) if file =~ /\.#{suffix}$/i
            end
        end
        files.each do |file|
            if file =~ /(.*?)\.\d+$/o then
                basename = $1
                if file =~ /mp(graph|run)/o || FileTest.file?("#{basename}.mp") then
                    removecontextfile($file)
                end
            end
        end
        $texnonesuffixes.each do |suffix|
            files.each do |file|
                if file =~ /(.*)\.#{suffix}$/i then
                    if FileTest.file?("#{$1}.tex") || FileTest.file?("#{$1}.xml") || FileTest.file?("#{$1}.fo") then
                        keepcontextfile(file)
                    else
                        strippedname = $1.gsub(/\-[a-z]$/io, '')
                        if FileTest.file?("#{strippedname}.tex") || FileTest.file?("#{strippedname}.xml") then
                            keepcontextfile("#{file} (potential result file)")
                        else
                            removecontextfile(file)
                        end
                    end
                end
            end
        end

        files = Dir.glob("*.*")
        $dontasksuffixes.each do |suffix|
            files.each do |file|
                removecontextfile(file) if file =~ /^#{suffix}$/i
            end
        end

        if $removedfiles || $keptfiles || $persistentfiles then
            report("removed files : #{$removedfiles}")
            report("kept files : #{$keptfiles}")
            report("persistent files : #{$persistentfiles}")
            report("reclaimed bytes : #{$reclaimedbytes}")
        end

    end

    def purgeallfiles
        purgefiles(true) # for old times sake
    end

    private

    $removedfiles    = 0
    $keptfiles       = 0
    $persistentfiles = 0
    $reclaimedbytes  = 0

    $dontaskprefixes = [
        # "tex-form.tex", "tex-edit.tex", "tex-temp.tex",
        "texexec.tex", "texexec.tui", "texexec.tuo",
        "texexec.ps", "texexec.pdf", "texexec.dvi",
        "cont-opt.tex", "cont-opt.bak"
    ]
    $dontasksuffixes = [
        "mp(graph|run)\\.mp", "mp(graph|run)\\.mpd", "mp(graph|run)\\.mpo", "mp(graph|run)\\.mpy",
        "mp(graph|run)\\.\\d+",
        "xlscript\\.xsl"
    ]
    $forsuresuffixes = [
        "tui", "tup", "ted", "tes", "top",
        "log", "tmp", "run", "bck", "rlg",
        "mpt", "mpx", "mpd", "mpo"
    ]
    $texonlysuffixes = [
        "dvi", "ps", "pdf"
    ]
    $texnonesuffixes = [
        "tuo", "tub", "top"
    ]

    def removecontextfile (filename)
        if filename && FileTest.file?(filename) then
            begin
                filesize = FileTest.size(filename)
                File.delete(filename)
            rescue
                report("problematic : #{filename}")
            else
                if FileTest.file?(filename) then
                    $persistentfiles += 1
                    report("persistent : #{filename}")
                else
                    $removedfiles += 1
                    $reclaimedbytes += filesize
                    report("removed : #{filename}")
                end
            end
        end
    end

    def keepcontextfile (filename)
        if filename && FileTest.file?(filename)  then
            $keptfiles += 1
            report("not removed : #{filename}")
        end
    end

end

#D Documentation can be woven into a source file. The next
#D routine generates a new, \TEX\ ready file with the
#D documentation and source fragments properly tagged. The
#D documentation is included as comment:
#D
#D \starttypen
#D %D ......  some kind of documentation
#D %M ......  macros needed for documenation
#D %S B       begin skipping
#D %S E       end skipping
#D \stoptypen
#D
#D The most important tag is \type {%D}. Both \TEX\ and \METAPOST\
#D files use \type{%} as a comment chacacter, while \PERL, \RUBY\
#D and alike use \type{#}. Therefore \type{#D} is also handled.
#D
#D The generated file gets the suffix \type{ted} and is
#D structured as:
#D
#D \starttypen
#D \startmodule[type=suffix]
#D \startdocumentation
#D \stopdocumentation
#D \startdefinition
#D \stopdefinition
#D \stopmodule
#D \stoptypen
#D
#D Macro definitions specific to the documentation are not
#D surrounded by start||stop commands. The suffix specifaction
#D can be overruled at runtime, but defaults to the file
#D extension. This specification can be used for language
#D depended verbatim typesetting.

class Commands

    include CommandBase

    public

    def documentation
        files = @commandline.arguments
        processtype = @commandline.option("type")
        files.each do |fullname|
            if fullname =~ /(.*)\.(.+?)$/o then
                filename, filesuffix = $1, $2
            else
                filename, filesuffix = fullname, 'tex'
            end
            filesuffix = 'tex' if filesuffix.empty?
            fullname, resultname = "#{filename}.#{filesuffix}", "#{filename}.ted"
            if ! FileTest.file?(fullname)
                report("empty input file #{fullname}")
            elsif ! tex = File.open(fullname)
                report("invalid input file #{fullname}")
            elsif ! ted = File.open(resultname,'w') then
                report("unable to openresult file #{resultname}")
            else
                report("input file : #{fullname}")
                report("output file : #{resultname}")
                nofdocuments, nofdefinitions, nofskips = 0, 0, 0
                skiplevel, indocument, indefinition, skippingbang = 0, false, false, false
                if processtype.empty? then
                  filetype = filesuffix.downcase
                else
                  filetype = processtype.downcase
                end
                report("filetype : #{filetype}")
                # we need to signal to texexec what interface to use
                firstline = tex.gets
                if firstline =~ /^\%.*interface\=/ then
                  ted.puts(firstline)
                else
                  tex.rewind # seek(0)
                end
                ted.puts("\\startmodule[type=#{filetype}]\n")
                while str = tex.gets do
                    if skippingbang then
                        skippingbang = false
                    else
                        str.chomp!
                        str.sub!(/\s*$/o, '')
                        case str
                            when /^[%\#]D/io then
                                if skiplevel == 0 then
                                    someline = if str.length < 3 then "" else str[3,str.length-1] end
                                    if indocument then
                                        ted.puts("#{someline}\n")
                                    else
                                        if indefinition then
                                            ted.puts("\\stopdefinition\n")
                                            indefinition = false
                                        end
                                        unless indocument then
                                            ted.puts("\n\\startdocumentation\n")
                                        end
                                        ted.puts("#{someline}\n")
                                        indocument = true
                                        nofdocuments += 1
                                    end
                                end
                            when /^[%\#]M/io then
                                if skiplevel == 0 then
                                    someline = if str.length < 3 then "" else str[3,str.length-1] end
                                    ted.puts("#{someline}\n")
                                end
                            when /^[%\%]S B/io then
                                skiplevel += 1
                                nofskips += 1
                            when /^[%\%]S E/io then
                                  skiplevel -= 1
                            when /^[%\#]/io then
                                  #nothing
                            when /^eval \'\(exit \$\?0\)\' \&\& eval \'exec perl/o then
                                skippingbang = true
                            else
                                if skiplevel == 0 then
                                    inlocaldocument = indocument
                                    someline = str
                                    if indocument then
                                        ted.puts("\\stopdocumentation\n")
                                        indocument = false
                                    end
                                    if someline.empty? && indefinition then
                                        ted.puts("\\stopdefinition\n")
                                        indefinition = false
                                    elsif indefinition then
                                        ted.puts("#{someline}\n")
                                    elsif ! someline.empty? then
                                        ted.puts("\n\\startdefinition\n")
                                        indefinition = true
                                        unless inlocaldocument then
                                            nofdefinitions += 1
                                            ted.puts("#{someline}\n")
                                        end
                                    end
                                end
                        end
                    end
                end
                if indocument then
                    ted.puts("\\stopdocumentation\n")
                end
                if indefinition then
                    ted.puts("\\stopdefinition\n")
                end
                ted.puts("\\stopmodule\n")
                ted.close

                if nofdocuments == 0 && nofdefinitions == 0 then
                    begin
                        File.delete(resultname)
                    rescue
                    end
                end
                report("documentation sections : #{nofdocuments}")
                report("definition sections : #{nofdefinitions}")
                report("skipped sections : #{nofskips}")
            end
        end
    end

end

#D This feature was needed when \PDFTEX\ could not yet access page object
#D numbers (versions prior to 1.11).

class Commands

    include CommandBase

    public

    def filterpages # temp feature / no reporting
        filename = @commandline.argument('first')
        filename.sub!(/\.([a-z]+?)$/io,'')
        pdffile = "#{filename}.pdf"
        tuofile = "#{filename}.tuo"
        if FileTest.file?(pdffile) then
            begin
                prevline, n = '', 0
                if (pdf = File.open(pdffile)) && (tuo = File.open(tuofile,'a')) then
                    report('filtering page object numbers')
                    pdf.binmode
                    while line = pdf.gets do
                        line.chomp
                        # typical pdftex search
                        if (line =~ /\/Type \/Page/o) && (prevline =~ /^(\d+)\s+0\s+obj/o) then
                            p = $1
                            n += 1
                            tuo.puts("\\objectreference{PDFP}{#{n}}{#{p}}{#{n}}\n")
                        else
                            prevline = line
                        end
                    end
                end
                pdf.close
                tuo.close
                report("number of pages : #{n}")
            rescue
                report("fatal error in filtering pages")
            end
        end
    end

end

# This script is used to generate hyphenation pattern files
# that suit ConTeXt. One reason for independent files is that
# over the years too many uncommunicated changes took place
# as well that inconsistency in content, naming, and location
# in the texmf tree takes more time than I'm willing to spend
# on it. Pattern files are normally shipped for LaTeX (and
# partially plain). A side effect of independent files is that
# we can make them encoding independent.
#
# Maybe I'll make this hyptools.tex

class Language

    include CommandBase

    def initialize(commandline=nil, language='en', filenames=nil, encoding='ec')
        @commandline= commandline
        @language = language
        @filenames = filenames
        @remapping = Array.new
        @unicode = Hash.new
        @encoding = encoding
        @data = ''
        @read = ''
        preload_accents()
        preload_unicode() if @commandline.option('utf8')
        case @encoding.downcase
            when 't1', 'ec', 'cork' then preload_vector('ec')
            when 'y', 'texnansi'    then preload_vector('texnansi')
        end
    end

    def report(str)
        if @commandline then
            @commandline.report(str)
        else
            puts("#{str}\n")
        end
    end

    def remap(from, to)
        @remapping.push([from,to])
    end

    def load(filenames=@filenames)
        begin
            if filenames then
                @filenames.each do |fileset|
                    [fileset].flatten.each do |filename|
                        begin
                            if fname = located(filename) then
                                data = IO.read(fname)
                                @data += data.gsub(/\%.*$/, '')
                                data.gsub!(/(\\patterns|\\hyphenation)\s*\{.*/mo) do '' end
                                @read += "\n% preamble of file #{fname}\n\n#{data}\n"
                                report("file #{fname} is loaded")
                                break # next fileset
                            end
                        rescue
                            report("file #{filename} is not readable")
                        end
                    end
                end
            end
        rescue
        end
    end

    def valid?
        ! @data.empty?
    end

    def convert
        if @data then
            n = 0
            @remapping.each do |k|
                @data.gsub!(k[0]) do
                    # report("#{k[0]} => #{k[1]}")
                    n += 1
                    k[1]
                end
            end
            report("#{n} changes in patterns and exceptions")
            if @commandline.option('utf8') then
                n = 0
                @data.gsub!(/\[(.*?)\]/o) do
                    n += 1
                    @unicode[$1] || $1
                end
                report("#{n} unicode utf8 entries")
            end
            return true
        else
            return false
        end
    end

    def comment(str)
        str.gsub!(/^\n/o, '')
        str.chomp!
        if @commandline.option('xml') then
            "<!-- #{str.strip} -->\n\n"
        else
            "% #{str.strip}\n\n"
        end
    end

    def content(tag, str)
        lst = str.split(/\s+/)
        lst.collect! do |l|
            l.strip
        end
        if lst.length>0 then
            lst = "\n#{lst.join("\n")}\n"
        else
            lst = ""
        end
        if @commandline.option('xml') then
            lst.gsub!(/\[(.*?)\]/o) do
                "&#{$1};"
            end
            "<#{tag}>#{lst}</#{tag}>\n\n"
        else
            "\\#{tag} \{#{lst}\}\n\n"
        end
    end

    def banner
        if @commandline.option('xml') then
            "<?xml version='1.0' standalone='yes' ?>\n\n"
        end
    end

    def triggerunicode
        if @commandline.option('utf8') then
            "% xetex needs utf8 encoded patterns and for patterns\n" +
            "% coded as such we need to enable this regime when\n" +
            "% not in xetex; this code will be moved into context\n" +
            "% as soon as we've spread the generic patterns\n" +
            "\n" +
            "\\ifx\\XeTeXversion\\undefined \\else\n" +
            "  \\ifx\\enableregime\\undefined \\else\n" +
            "    \\enableregime[utf]\n" +
            "  \\fi\n" +
            "\\fi\n" +
            "\n"
        end
    end

    def save
        xml = @commandline.option("xml")

        patname = "lang-#{@language}.pat"
        hypname = "lang-#{@language}.hyp"
        rmename = "lang-#{@language}.rme"
        logname = "lang-#{@language}.log"

        desname = "lang-all.xml"

        @data.gsub!(/\\[nc]\{(.+?)\}/)  do $1    end
        @data.gsub!(/\{\}/)             do ''    end
        @data.gsub!(/\n+/mo)            do "\n"  end
        @read.gsub!(/\n+/mo)            do "\n"  end

        description = ''
        commentfile = rmename.dup

        begin
            desfile = `kpsewhich -progname=context #{desname}`.chomp
            if f = File.new(desfile) then
                if doc = REXML::Document.new(f) then
                    if e = REXML::XPath.first(doc.root,"/descriptions/description[@language='#{@language}']") then
                        description = e.to_s
                    end
                end
            end
        rescue
            description = ''
        else
            unless description.empty? then
                commentfile = desname.dup
                str  = "<!-- copied from lang-all.xml\n\n"
                str << "<?xml version='1.0' standalone='yes'?>\n\n"
                str << description.chomp
                str << "\n\nend of copy -->\n"
                str.gsub!(/^/io, "% ") unless @commandline.option('xml')
                description =  comment("begin description data")
                description << str + "\n"
                description << comment("end description data")
                report("description found for language #{@language}")
            end
        end

        begin
            if description.empty? || @commandline.option('log') then
                if f = File.open(logname,'w') then
                    report("saving #{@remapping.length} remap patterns in #{logname}")
                    @remapping.each do |m|
                        f.puts("#{m[0].inspect} => #{m[1]}\n")
                    end
                    f.close
                end
            else
                File.delete(logname) if FileTest.file?(logname)
            end
        rescue
        end

        begin
            if description.empty? || @commandline.option('log') then
                if f = File.open(rmename,'w') then
                    data = @read.dup
                    data.gsub!(/(\s*\n\s*)+/mo, "\n")
                    f << comment("comment copied from public hyphenation files}")
                    f << comment("source of data: #{@filenames.join(' ')}")
                    f << comment("begin original comment")
                    f << "#{data}\n"
                    f << comment("end original comment")
                    f.close
                    report("comment saved in file #{rmename}")
                else
                    report("file #{rmename} is not writable")
                end
            else
                File.delete(rmename) if FileTest.file?(rmename)
            end
        rescue
        end

        begin
            if f = File.open(patname,'w') then
                data = ''
                @data.scan(/\\patterns\s*\{\s*(.*?)\s*\}/m) do
                    report("merging patterns")
                    data += $1 + "\n"
                end
                data.gsub!(/(\s*\n\s*)+/mo, "\n")

                f << banner
                f << comment("context pattern file, see #{commentfile} for original comment")
                f << comment("source of data: #{@filenames.join(' ')}")
                f << description
                f << comment("begin pattern data")
                f << triggerunicode
                f << content('patterns', data)
                f << comment("end pattern data")
                f.close
                report("patterns saved in file #{patname}")
            else
                report("file #{patname} is not writable")
            end
        rescue
            report("problems with file #{patname}")
        end

        begin
            if f = File.open(hypname,'w') then
                data = ''
                @data.scan(/\\hyphenation\s*\{\s*(.*?)\s*\}/m) do
                    report("merging exceptions")
                    data += $1 + "\n"
                end
                data.gsub!(/(\s*\n\s*)+/mo, "\n")
                f << banner
                f << comment("context hyphenation file, see #{commentfile} for original comment")
                f << comment("source of data: #{@filenames.join(' ')}")
                f << description
                f << comment("begin hyphenation data")
                f << triggerunicode
                f << content('hyphenation', data)
                f << comment("end hyphenation data")
                f.close
                report("exceptions saved in file #{hypname}")
            else
                report("file #{hypname} is not writable")
            end
        rescue
            report("problems with file #{hypname}")
        end
    end

    def process
        load
        if valid? then
            convert
            save
        else
            report("aborted due to missing files")
        end
    end

    def Language::generate(commandline, language='', filenames='', encoding='ec')
        if ! language.empty? && ! filenames.empty? then
            commandline.report("processing language #{language}")
            commandline.report("")
            language = Language.new(commandline,language,filenames,encoding)
            language.load
            language.convert
            language.save
            commandline.report("")
        end
    end

    private

    def located(filename)
        begin
            fname = `kpsewhich -progname=context #{filename}`.chomp
            if FileTest.file?(fname) then
                report("using file #{fname}")
                return fname
            else
                report("file #{filename} is not present")
                return nil
            end
        rescue
            report("file #{filename} cannot be located using kpsewhich")
            return nil
        end
    end

    def preload_accents

        begin
            if filename = located("enco-acc.tex") then
                if data = IO.read(filename) then
                    report("preloading accent conversions")
                    data.scan(/\\defineaccent\s*\\*(.+?)\s*\{*(.+?)\}*\s*\{\\(.+?)\}/o) do
                        one, two, three = $1, $2, $3
                        one.gsub!(/[\`\~\!\^\*\_\-\+\=\:\;\"\'\,\.\?]/o) do
                            "\\#{one}"
                        end
                        remap(/\\#{one} #{two}/, "[#{three}]")
                        remap(/\\#{one}#{two}/, "[#{three}]")  unless one =~ /[a-zA-Z]/o
                        remap(/\\#{one}\{#{two}\}/, "[#{three}]")
                    end
                end
            end
        rescue
        end

    end

    def preload_unicode

        # \definecharacter Agrave {\uchar0{192}}

        begin
            if filename = located("enco-uc.tex") then
                if data = IO.read(filename) then
                    report("preloading unicode conversions")
                    data.scan(/\\definecharacter\s*(.+?)\s*\{\\uchar\{*(\d+)\}*\s*\{(\d+)\}/o) do
                        one, two, three = $1, $2.to_i, $3.to_i
                        @unicode[one] = [(two*256 + three)].pack("U")
                    end
                end
            end
        rescue
            report("error in loading unicode mapping (#{$!})")
        end

    end

    def preload_vector(encoding='')

        # funny polish

        case @language
            when 'pl' then
                remap(/\/a/, "[aogonek]")    ; remap(/\/A/, "[Aogonek]")
                remap(/\/c/, "[cacute]")     ; remap(/\/C/, "[Cacute]")
                remap(/\/e/, "[eogonek]")    ; remap(/\/E/, "[Eogonek]")
                remap(/\/l/, "[lstroke]")    ; remap(/\/L/, "[Lstroke]")
                remap(/\/n/, "[nacute]")     ; remap(/\/N/, "[Nacute]")
                remap(/\/o/, "[oacute]")     ; remap(/\/O/, "[Oacute]")
                remap(/\/s/, "[sacute]")     ; remap(/\/S/, "[Sacute]")
                remap(/\/x/, "[zacute]")     ; remap(/\/X/, "[Zacute]")
                remap(/\/z/, "[zdotaccent]") ; remap(/\/Z/, "[Zdotaccent]")
            when 'sl' then
                remap(/\"c/,"[ccaron]")  ; remap(/\"C/,"[Ccaron]")
                remap(/\"s/,"[scaron]")  ; remap(/\"S/,"[Scaron]")
                remap(/\"z/,"[zcaron]")  ; remap(/\"Z/,"[Zcaron]")
            when 'da' then
                remap(/X/, "[aeligature]")
                remap(/Y/, "[ostroke]")
                remap(/Z/, "[aring]")
            when 'ca' then
                remap(/\\c\{.*?\}/, "")
            when 'de', 'deo' then
                remap(/\\c\{.*?\}/, "")
                remap(/\\n\{\}/, "")
                remap(/\\3/, "[ssharp]")
                remap(/\\9/, "[ssharp]")
                remap(/\"a/, "[adiaeresis]")
                remap(/\"o/, "[odiaeresis]")
                remap(/\"u/, "[udiaeresis]")
            when 'fr' then
                remap(/\\ae/, "[adiaeresis]")
                remap(/\\oe/, "[odiaeresis]")
            when 'la' then
                # \lccode`'=`' somewhere else, todo
                remap(/\\c\{.*?\}/, "")
                remap(/\\a\s*/, "[aeligature]")
                remap(/\\o\s*/, "[oeligature]")
            else
        end

        if ! encoding.empty? then
            begin
                filename = `kpsewhich -progname=context enco-#{encoding}.tex`
                if data = IO.read(filename.chomp) then
                    report("preloading #{encoding} character mappings")
                    data.scan(/\\definecharacter\s*([a-zA-Z]+)\s*(\d+)\s*/o) do
                        name, number = $1, $2
                        remap(/\^\^#{sprintf("%02x",number)}/, "[#{name}]")
                    end
                end
            rescue
            end
        end

    end

end

class Commands

    include CommandBase

    public

    @@languagedata = Hash.new

    def patternfiles
        language = @commandline.argument('first')
        if (language == 'all') || language.empty? then
            languages = @@languagedata.keys.sort
        elsif @@languagedata.key?(language) then
            languages = [language]
        else
            languages = []
        end
        languages.each do |language|
            encoding = @@languagedata[language][0] || ''
            files    = @@languagedata[language][1] || []
            Language::generate(self,language,files,encoding)
        end
    end

    private

    # todo: filter the fallback list from context

    # The first entry in the array is the encoding which will be used
    # when interpreting th eraw patterns. The second entry is a list of
    # filesets (string|aray), each first match of a set is taken.

    @@languagedata['ba' ] = [ 'ec'      , ['bahyph.tex'] ]
    @@languagedata['ca' ] = [ 'ec'      , ['cahyph.tex'] ]
    @@languagedata['cy' ] = [ 'ec'      , ['cyhyph.tex'] ]
    @@languagedata['cz' ] = [ 'ec'      , ['czhyphen.tex','czhyphen.ex'] ]
    @@languagedata['de' ] = [ 'ec'      , ['dehyphn.tex'] ]
    @@languagedata['deo'] = [ 'ec'      , ['dehypht.tex'] ]
    @@languagedata['da' ] = [ 'ec'      , ['dkspecial.tex','dkcommon.tex'] ]
    # elhyph.tex
    @@languagedata['es' ] = [ 'ec'      , ['eshyph.tex'] ]
    @@languagedata['fi' ] = [ 'ec'      , ['ethyph.tex'] ]
    @@languagedata['fi' ] = [ 'ec'      , ['fihyph.tex'] ]
    @@languagedata['fr' ] = [ 'ec'      , ['frhyph.tex'] ]
    # ghyphen.readme ghyph31.readme grphyph
    @@languagedata['hr' ] = [ 'ec'      , ['hrhyph.tex'] ]
    @@languagedata['hu' ] = [ 'ec'      , ['huhyphn.tex'] ]
    @@languagedata['en' ] = [ 'default' , [['ushyphmax.tex','ushyph.tex','hyphen.tex']] ]
    @@languagedata['us' ] = [ 'default' , [['ushyphmax.tex','ushyph.tex','hyphen.tex']] ]
    # inhyph.tex
    @@languagedata['is' ] = [ 'ec'      , ['ishyph.tex'] ]
    @@languagedata['it' ] = [ 'ec'      , ['ithyph.tex'] ]
    @@languagedata['la' ] = [ 'ec'      , ['lahyph.tex'] ]
    # mnhyph
    @@languagedata['nl' ] = [ 'ec'      , ['nehyph96.tex'] ]
    @@languagedata['no' ] = [ 'ec'      , ['nohyph.tex'] ]
    # oldgrhyph.tex
    @@languagedata['pl' ] = [ 'ec'      , ['plhyph.tex'] ]
    @@languagedata['pt' ] = [ 'ec'      , ['pthyph.tex'] ]
    @@languagedata['ro' ] = [ 'ec'      , ['rohyph.tex'] ]
    @@languagedata['sl' ] = [ 'ec'      , ['sihyph.tex'] ]
    @@languagedata['sk' ] = [ 'ec'      , ['skhyphen.tex','skhyphen.ex'] ]
    # sorhyph.tex / upper sorbian
    # srhyphc.tex / cyrillic
    @@languagedata['sv' ] = [ 'ec'      , ['svhyph.tex'] ]
    @@languagedata['tr' ] = [ 'ec'      , ['tkhyph.tex'] ]
    @@languagedata['uk' ] = [ 'default' , [['ukhyphen.tex','ukhyph.tex']] ]

end

class Commands

    include CommandBase

    def dpxmapfiles

        force  = @commandline.option("force")

        texmfroot = @commandline.argument('first')
        texmfroot = '.' if texmfroot.empty?
        maproot   = "#{texmfroot.gsub(/\\/,'/')}/fonts/map/pdftex/context"

        if File.directory?(maproot) then
            files = Dir.glob("#{maproot}/*.map")
            if files.size > 0 then
                files.each do |pdffile|
                    next if File.basename(pdffile) == 'pdftex.map'
                    pdffile = File.expand_path(pdffile)
                    dpxfile = File.expand_path(pdffile.sub(/pdftex/i,'dvipdfm'))
                    unless pdffile == dpxfile then
                        begin
                            if data = File.read(pdffile) then
                                report("< #{File.basename(pdffile)} - pdf(e)tex")
                                n = 0
                                data = data.collect do |line|
                                    if line =~ /^[\%\#]+/mo then
                                        ''
                                    else
                                        encoding = if line =~ /([a-z0-9\-]+)\.enc/io        then $1 else ''  end
                                        fontfile = if line =~ /([a-z0-9\-]+)\.(pfb|ttf)/io  then $1 else nil end
                                        metrics  = if line =~ /^([a-z0-9\-]+)[\s\<]+/io     then $1 else nil end
                                        slant    = if line =~ /\"([\d\.]+)\s+SlantFont\"/io then "-s #{$1}" else '' end
                                        if metrics && encoding && fontfile then
                                            n += 1
                                            "#{metrics} #{encoding} #{fontfile} #{slant}"
                                        else
                                            ''
                                        end
                                    end
                                end
                                data.delete_if do |line|
                                    line.gsub(/\s+/,'').empty?
                                end
                                data.collect! do |line|
                                    # remove line with "name name" lines
                                    line.gsub(/^(\S+)\s+\1\s*$/) do
                                        $1
                                    end
                                end
                                begin
                                    if force then
                                        if n > 0 then
                                            File.makedirs(File.dirname(dpxfile))
                                            if f = File.open(dpxfile,'w') then
                                                report("> #{File.basename(dpxfile)} - dvipdfm(x) - #{n}")
                                                f.puts(data)
                                                f.close
                                            else
                                                report("? #{File.basename(dpxfile)} - dvipdfm(x)")
                                            end
                                        else
                                            report("- #{File.basename(dpxfile)} - dvipdfm(x)")
                                            begin File.delete(dpxname) ; rescue ; end
                                        end
                                    else
                                        report(". #{File.basename(dpxfile)} - dvipdfm(x) - #{n}")
                                    end
                                rescue
                                    report("error in saving dvipdfm file")
                                end
                            else
                                report("error in loading pdftex file")
                            end
                        rescue
                            report("error in processing pdftex file")
                        end
                    end
                end
                if force then
                    begin
                        report("regenerating database for #{texmfroot}")
                        system("mktexlsr #{texmfroot}")
                    rescue
                    end
                end
            else
                report("no mapfiles found in #{maproot}")
            end
        else
            report("provide proper texmfroot")
        end

    end

end

class Commands

    include CommandBase

    # usage   : ctxtools --listentities entities.xml
    # document: <!DOCTYPE something SYSTEM "entities.xml">

    def flushentities(handle,entities,doctype=nil) # 'stylesheet'
        tab = if doctype then "\t" else "" end
        handle.puts("<!DOCTYPE #{doctype} [") if doctype
        entities.keys.sort.each do |k|
            handle.puts("#{tab}<!ENTITY #{k} \"\&\##{entities[k]};\">")
        end
        handle.puts("]>") if doctype
    end

    def listentities

      # filename   = `texmfstart tmftools.rb --progname=context enco-uc.tex`.chomp
        filename   = `kpsewhich --progname=context enco-uc.tex`.chomp
        outputname = @commandline.argument('first')

        if filename and not filename.empty? and FileTest.file?(filename) then
            entities = Hash.new
            IO.readlines(filename).each do |line|
                if line =~ /\\definecharacter\s+([a-zA-Z]+)\s+\{\\uchar\{*(\d+)\}*\{(\d+)\}\}/o then
                    name, low, high = $1, $2.to_i, $3.to_i
                    entities[name] = low*256 + high
                end
            end
            if outputname and not outputname.empty? then
                if f = File.open(outputname,'w') then
                    flushentities(f,entities)
                    f.close
                else
                    flushentities($stdout,entities)
                end
            else
                flushentities($stdout,entities)
            end
        end

    end

end


logger      = Logger.new(banner.shift)
commandline = CommandLine.new

commandline.registeraction('touchcontextfile', 'update context version')
commandline.registeraction('contextversion', 'report context version')

commandline.registeraction('jeditinterface', 'generate jedit syntax files [--pipe]')
commandline.registeraction('bbeditinterface', 'generate bbedit syntax files [--pipe]')
commandline.registeraction('sciteinterface', 'generate scite syntax files [--pipe]')
commandline.registeraction('rawinterface', 'generate raw syntax files [--pipe]')

commandline.registeraction('translateinterface', 'generate interface files (xml) [nl de ..]')
commandline.registeraction('purgefiles', 'remove temporary files [--all --recurse] [basename]')

commandline.registeraction('documentation', 'generate documentation [--type=] [filename]')

commandline.registeraction('filterpages')   # no help, hidden temporary feature
commandline.registeraction('purgeallfiles') # no help, compatibility feature

commandline.registeraction('patternfiles', 'generate pattern files [--all --xml --utf8] [languagecode]')

commandline.registeraction('dpxmapfiles', 'convert pdftex mapfiles to dvipdfmx [--force] [texmfroot]')
commandline.registeraction('listentities', 'create doctype entity definition from enco-uc.tex')

commandline.registervalue('type','')

commandline.registerflag('recurse')
commandline.registerflag('force')
commandline.registerflag('pipe')
commandline.registerflag('all')
commandline.registerflag('xml')
commandline.registerflag('log')
commandline.registerflag('utf8')

# general

commandline.registeraction('help')
commandline.registeraction('version')

commandline.expand

Commands.new(commandline,logger,banner).send(commandline.action || 'help')

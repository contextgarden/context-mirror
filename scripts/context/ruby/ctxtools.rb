#!/usr/bin/env ruby

# program   : ctxtools
# copyright : PRAGMA Advanced Document Engineering
# version   : 1.2.0 - 2002/2005
# author    : Hans Hagen

# This script will harbor some handy manipulations on context
# related files.

# todo: move scite here

banner = ['CtxTools', 'version 1.2.0', '2004/2005', 'PRAGMA ADE/POD']

unless defined? ownpath
    ownpath = $0.sub(/[\\\/][a-z0-9\-]*?\.rb/i,'')
    $: << ownpath
end

require 'ftools'
require 'xmpl/switch'
require 'exa/logger'

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

    def purgefiles

        pattern = @commandline.arguments
        purgeall = @commandline.option("all")

        $dontaskprefixes.push(Dir.glob("mpx-*"))
        $dontaskprefixes.flatten!
        $dontaskprefixes.sort!

        if purgeall then
          forsuresuffixes.push(texnonesuffixes)
          texnonesuffixes = []
        end

        if ! pattern || pattern.empty? then
            globbed = "*.*"
            files = Dir.glob(globbed)
            report("purging files : #{globbed}")
        else
            pattern.each do |pat|
                globbed = "#{pat}-*.*"
                files = Dir.glob(globbed)
                globbed = "#{pat}.*"
                files.push(Dir.glob(globbed))
            end
            report("purging files : #{pattern.join(' ')}")
        end
        files.flatten!
        files.sort!

        $dontaskprefixes.each do |file|
            removecontextfile(file) if FileTest.file?(file)
        end
        $dontasksuffixes.each do |file|
            removecontextfile(file) if FileTest.file?(file)
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

        if $removedfiles || $keptfiles || $persistentfiles then
            report("removed files : #{$removedfiles}")
            report("kept files : #{$keptfiles}")
            report("persistent files : #{$persistentfiles}")
            report("reclaimed bytes : #{$reclaimedbytes}")
        end

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
        "mpgraph.mp", "mpgraph.mpd", "mpgraph.mpo", "mpgraph.mpy",
        "mprun.mp", "mprun.mpd", "mprun.mpo", "mprun.mpy",
        "xlscript.xsl"
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
        end
    end

end

logger      = EXA::ExaLogger.new(banner.shift)
commandline = CommandLine.new

commandline.registeraction('touchcontextfile', 'update context version')
commandline.registeraction('contextversion', 'report context version')

commandline.registeraction('jeditinterface', 'generate jedit syntax files [--pipe]')
commandline.registeraction('bbeditinterface', 'generate bbedit syntax files [--pipe]')
commandline.registeraction('sciteinterface', 'generate scite syntax files [--pipe]')
commandline.registeraction('rawinterface', 'generate raw syntax files [--pipe]')

commandline.registeraction('translateinterface', 'generate interface files (xml) [nl de ..]')
commandline.registeraction('purgefiles', 'remove temporary files [--all] [basename]')

commandline.registeraction('documentation', 'generate documentation file [--type=] [filename]')

commandline.registeraction('filterpages') # no help, hidden temporary feature

commandline.registeraction('help')
commandline.registeraction('version')

commandline.registervalue('type','')

# commandline.registerflag('recurse')
# commandline.registerflag('force')
commandline.registerflag('pipe')
commandline.registerflag('all')

commandline.expand

Commands.new(commandline,logger,banner).send(commandline.action || 'help')

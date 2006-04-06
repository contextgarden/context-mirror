banner = ['TeXExec', 'version 6.1.2', '1997-2006', 'PRAGMA ADE/POD']

unless defined? ownpath
    ownpath = $0.sub(/[\\\/][a-z0-9\-]*?\.rb/i,'')
    $: << ownpath
end

require 'base/switch'
require 'base/logger'
require 'base/variables'
require 'base/system'

require 'base/tex'
require 'base/texutil'

require 'ftools'     # needed ?

require 'base/kpse'  # needed ?
# require 'base/pdf'   # needed ?
require 'base/state' # needed ?
require 'base/file'  # needed ?

class Commands

    include CommandBase

    def make
        if job = TEX.new(logger) then
            prepare(job)
            # bonus, overloads language switch !
            job.setvariable('language','all') if @commandline.option('all')
            if @commandline.arguments.length > 0 then
                if @commandline.arguments.first == 'all' then
                    job.setvariable('texformats',job.defaulttexformats)
                    job.setvariable('mpsformats',job.defaultmpsformats)
                else
                    job.setvariable('texformats',@commandline.arguments)
                    job.setvariable('mpsformats',@commandline.arguments)
                end
            end
            job.makeformats
            job.inspect && Kpse.inspect if @commandline.option('verbose')
        end
    end

    def check
        if job = TEX.new(logger) then
            job.checkcontext
            job.inspect && Kpse.inspect  if @commandline.option('verbose')
        end
    end

    def main
        if @commandline.arguments.length>0 then
            process
        else
            help
        end
    end

    def process
        if job = TEX.new(logger) then
            job.setvariable('files',@commandline.arguments)
            prepare(job)
            job.processtex
            job.inspect && Kpse.inspect if @commandline.option('verbose')
        end
    end

    def mptex
        if job = TEX.new(logger) then
            job.setvariable('files',@commandline.arguments)
            prepare(job)
            job.processmptex
            job.inspect && Kpse.inspect  if @commandline.option('verbose')
        end
    end

    def mpxtex
        if job = TEX.new(logger) then
            job.setvariable('files',@commandline.arguments)
            prepare(job)
            job.processmpxtex
            job.inspect && Kpse.inspect  if @commandline.option('verbose')
        end
    end

    # hard coded goodies # to be redone as s-ctx-.. with vars passed as such

    def listing
        if job = TEX.new(logger) then
            prepare(job)
            job.cleanuptemprunfiles
            files = @commandline.arguments.sort
            if files.length > 0 then
                if f = File.open(job.tempfilename('tex'),'w') then
                    backspace = @commandline.checkedoption('backspace', '1.5cm')
                    topspace  = @commandline.checkedoption('topspace', '1.5cm')
                    pretty    = @commandline.option('pretty')
                    f << "% interface=english\n"
                    f << "\\setupbodyfont[11pt,tt]\n"
                    f << "\\setuplayout\n"
                    f << "  [topspace=#{topspace},backspace=#{backspace},\n"
                    f << "   header=0cm,footer=1.5cm,\n"
                    f << "   width=middle,height=middle]\n"
                    f << "\\setuptyping[lines=yes]\n"
                    f << "\\setuptyping[option=color]\n" if pretty
                    f << "\\starttext\n";
                    files.each do |filename|
                        report("list file: #{filename}")
                        cleanname = cleantexfilename(filename).downcase
                        f << "\\page\n"
                        f << "\\setupfootertexts[\\tttf #{cleanname}][\\tttf \\pagenumber]\n"
                        f << "\\typefile{#{filename}}\n"
                    end
                    f << "\\stoptext\n"
                    f.close
                    job.setvariable('interface','english')
                    job.setvariable('simplerun',true)
                    # job.setvariable('nooptionfile',true)
                    job.setvariable('files',[job.tempfilename])
                    job.processtex
                else
                    report('no files to list')
                end
            else
                report('no files to list')
            end
            job.cleanuptemprunfiles
        end
    end

    def figures
        # this one will be redone using rlxtools
        if job = TEX.new(logger) then
            prepare(job)
            job.cleanuptemprunfiles
            files = @commandline.arguments.sort
            if files.length > 0 then
                if f = File.open(job.tempfilename('tex'),'w') then
                    job.runtexutil(files,"--figures", true)
                    figures     = @commandline.checkedoption('method', 'a').downcase
                    paperoffset = @commandline.checkedoption('paperoffset', '0pt')
                    backspace   = @commandline.checkedoption('backspace', '1.5cm')
                    topspace    = @commandline.checkedoption('topspace', '1.5cm')
                    boxtype     = @commandline.checkedoption('boxtype','')
                    f << "% format=english\n";
                    f << "\\setuplayout\n";
                    f << "  [topspace=#{topspace},backspace=#{backspace},\n"
                    f << "   header=1.5cm,footer=0pt,\n";
                    f << "   width=middle,height=middle]\n";
                    if @commandline.option('fullscreen') then
                        f << "\\setupinteraction\n";
                        f << "  [state=start]\n";
                        f << "\\setupinteractionscreen\n";
                        f << "  [option=max]\n";
                    end
                    boxtype += "box" unless boxtype.empty? || (boxtype =~ /box$/io)
                    f << "\\starttext\n";
                    f << "\\showexternalfigures[alternative=#{figures},offset=#{paperoffset},size=#{boxtype}]\n";
                    f << "\\stoptext\n";
                    f.close
                    job.setvariable('interface','english')
                    job.setvariable('simplerun',true)
                    # job.setvariable('nooptionfile',true)
                    job.setvariable('files',[job.tempfilename])
                    job.processtex
                    File.silentdelete('texutil.tuf')
                else
                    report('no figures to show')
                end
            else
                report('no figures to show')
            end
            job.cleanuptemprunfiles
        end
    end

    def modules
        if job = TEX.new(logger) then
            prepare(job)
            job.cleanuptemprunfiles
            files = @commandline.arguments.sort
            msuffixes = ['tex','mp','pl','pm','rb']
            if files.length > 0 then
                files.each do |fname|
                    fnames = Array.new
                    if FileTest.file?(fname) then
                        fnames << fname
                    else
                        msuffixes.each do |fsuffix|
                            fnames << File.suffixed(fname,fsuffix)
                        end
                    end
                    fnames.each do |ffname|
                        if msuffixes.include?(File.splitname(ffname)[1]) && FileTest.file?(ffname) then
                            if mod = File.open(job.tempfilename('tex'),'w') then
                                # will become a call to ctxtools
                                job.runtexutil(ffname,"--documents", true)
                                if ted = File.silentopen(File.suffixed(ffname,'ted')) then
                                    firstline = ted.gets
                                    if firstline =~ /interface=/o then
                                        mod << firstline
                                    else
                                        mod << "% interface=en\n"
                                    end
                                    ted.close
                                else
                                    mod << "% interface=en\n"
                                end
                                mod << "\\usemodule[abr-01,mod-01]\n"
                                mod << "\\def\\ModuleNumber{1}\n"
                                mod << "\\starttext\n"
                                # todo: global file too
                                mod << "\\readlocfile{#{File.suffixed(ffname,'ted')}}{}{}\n"
                                mod << "\\stoptext\n"
                                mod.close
                                job.setvariable('interface','english') # redundant
                                job.setvariable('simplerun',true)
                                # job.setvariable('nooptionfile',true)
                                job.setvariable('files',[job.tempfilename])
                                job.processtex
                                ["dvi", "pdf","tuo"].each do |s|
                                    File.silentrename(job.tempfilename(s),File.suffixed(ffname,s));
                                end
                            end
                        end
                    end
                end
            else
                report('no modules to process')
            end
            job.cleanuptemprunfiles
        end
    end

    def arrangeoutput
        if job = TEX.new(logger) then
            prepare(job)
            job.cleanuptemprunfiles
            files = @commandline.arguments.sort
            if files.length > 0 then
                if f = File.open(job.tempfilename('tex'),'w') then
                    emptypages  = @commandline.checkedoption('addempty', '')
                    paperoffset = @commandline.checkedoption('paperoffset', '0cm')
                    textwidth   = @commandline.checkedoption('textwidth', '0cm')
                    backspace   = @commandline.checkedoption('backspace', '0cm')
                    topspace    = @commandline.checkedoption('topspace', '0cm')
                    f << "\\definepapersize\n"
                    f << "  [offset=#{paperoffset}]\n"
                    f << "\\setuplayout\n"
                    f << "  [backspace=#{backspace},\n"
                    f << "    topspace=#{topspace},\n"
                    f << "     marking=on,\n" if @commandline.option('marking')
                    f << "       width=middle,\n"
                    f << "      height=middle,\n"
                    f << "    location=middle,\n"
                    f << "      header=0pt,\n"
                    f << "      footer=0pt]\n"
                    unless @commandline.option('noduplex') then
                        f << "\\setuppagenumbering\n"
                        f << "  [alternative=doublesided]\n"
                    end
                    f << "\\starttext\n"
                    files.each do |filename|
                        report("arranging file #{filename}")
                        f << "\\insertpages\n"
                        f << "  [#{filename}]\n"
                        f << "  [#{emptypages}]\n" unless emptypages.empty?
                        f << "  [width=#{textwidth}]\n"
                    end
                    f << "\\stoptext\n"
                    f.close
                    job.setvariable('interface','english')
                    job.setvariable('simplerun',true)
                    # job.setvariable('nooptionfile',true)
                    job.setvariable('files',[job.tempfilename])
                    job.processtex
                else
                    report('no files to arrange')
                end
            else
                report('no files to arrange')
            end
            job.cleanuptemprunfiles
        end
    end

    def selectoutput
        if job = TEX.new(logger) then
            prepare(job)
            job.cleanuptemprunfiles
            files = @commandline.arguments.sort
            if files.length > 0 then
                if f = File.open(job.tempfilename('tex'),'w') then
                    selection   = @commandline.checkedoption('selection', '')
                    paperoffset = @commandline.checkedoption('paperoffset', '0cm')
                    textwidth   = @commandline.checkedoption('textwidth', '0cm')
                    backspace   = @commandline.checkedoption('backspace', '0cm')
                    topspace    = @commandline.checkedoption('topspace', '0cm')
                    paperformat = @commandline.checkedoption('paperformat', 'A4*A4').split(/[\*x]/o)
                    from, to = paperformat[0] || 'A4', paperformat[1] || paperformat[0] || 'A4'
                    if from == 'fit' or to == 'fit' then
                        f << "\\getfiguredimensions[#{files.first}]\n"
                        if from == 'fit' then
                            f << "\\expanded{\\definepapersize[from-fit][width=\\figurewidth,height=\\figureheight]}\n"
                            from = 'from-fit'
                        end
                        if to == 'fit' then
                            f << "\\expanded{\\definepapersize[to-fit][width=\\figurewidth,height=\\figureheight]}\n"
                            to = 'to-fit'
                        end
                    end
                    job.setvariable('paperformat','') # else overloaded later on
                    f << "\\setuppapersize[#{from}][#{to}]\n"
                    f << "\\definepapersize\n";
                    f << "  [offset=#{paperoffset}]\n";
                    f << "\\setuplayout\n";
                    f << "  [backspace=#{backspace},\n";
                    f << "    topspace=#{topspace},\n";
                    f << "     marking=on,\n" if @commandline.option('marking')
                    f << "       width=middle,\n";
                    f << "      height=middle,\n";
                    f << "    location=middle,\n";
                    f << "      header=0pt,\n";
                    f << "      footer=0pt]\n";
                    f << "\\setupexternalfigures\n";
                    f << "  [directory=]\n";
                    f << "\\starttext\n";
                    unless selection.empty? then
                        f << "\\filterpages\n"
                        f << "  [#{files.first}][#{selection}][width=#{textwidth}]\n"
                    end
                    f << "\\stoptext\n"
                    f.close
                    job.setvariable('interface','english')
                    job.setvariable('simplerun',true)
                    # job.setvariable('nooptionfile',true)
                    job.setvariable('files',[job.tempfilename])
                    job.processtex
                else
                    report('no files to selectt')
                end
            else
                report('no files to select')
            end
            job.cleanuptemprunfiles
        end
    end

    def copyoutput
        copyortrim(false,'copy')
    end

    def trimoutput
        copyortrim(true,'trim')
    end

    def copyortrim(trim=false,what='unknown')
        if job = TEX.new(logger) then
            prepare(job)
            job.cleanuptemprunfiles
            files = @commandline.arguments.sort
            if files.length > 0 then
                if f = File.open(job.tempfilename('tex'),'w') then
                    scale = @commandline.checkedoption('scale')
                    scale = (scale * 1000).to_i if scale < 10
                    paperoffset = @commandline.checkedoption('paperoffset', '0cm')
                    f << "\\starttext\n"
                    files.each do |filename|
                        result = @commandline.checkedoption('result','texexec')
                        if (filename !~ /^texexec/io) && (filename !~ /^#{result}/) then
                            report("copying file: #{filename}")
                            f <<  "\\getfiguredimensions\n"
                            f <<  "  [#{filename}]\n"
                            f <<  "  [page=1"
                            f <<  ",\n   size=trimbox" if trim
                            f <<  "]\n"
                            f <<  "\\definepapersize\n"
                            f <<  "  [copy]\n"
                            f <<  "  [width=\\naturalfigurewidth,\n"
                            f <<  "   height=\\naturalfigureheight]\n"
                            f <<  "\\setuppapersize\n"
                            f <<  "  [copy][copy]\n"
                            f <<  "\\setuplayout\n"
                            f <<  "  [page]\n"
                            f <<  "\\setupexternalfigures\n"
                            f <<  "  [directory=]\n"
                            f <<  "\\copypages\n"
                            f <<  "  [#[filename}]\n"
                            f <<  "  [scale=#{scale},\n"
                            f <<  "   marking=on,\n" if @commandline.option('markings')
                            f <<  "   size=trimbox,\n" if trim
                            f <<  "   offset=#{paperoffset}]\n"
                        end
                    end
                    f << "\\stoptext\n"
                    f.close
                    job.setvariable('interface','english')
                    job.setvariable('simplerun',true)
                    # job.setvariable('nooptionfile',true)
                    job.setvariable('files',[job.tempfilename])
                    job.processtex
                else
                    report("no files to #{what}")
                end
            else
                report("no files to #{what}")
            end
            job.cleanuptemprunfiles
        end
    end

    def combineoutput
        if job = TEX.new(logger) then
            prepare(job)
            job.cleanuptemprunfiles
            files = @commandline.arguments.sort
            if files.length > 0 then
                if f = File.open(job.tempfilename('tex'),'w') then
                    paperoffset = @commandline.checkedoption('paperoffset', '0cm')
                    combination = @commandline.checkedoption('combination','2*2').split(/[\*x]/o)
                    paperformat = @commandline.checkedoption('paperoffset', 'A4*A4').split(/[\*x]/o)
                    nx, ny = combination[0] || '2', combination[1] || combination[0] || '2'
                    from, to = paperformat[0] || 'A4', paperformat[1] || paperformat[0] || 'A4'
                    f << "\\setuppapersize[#{from}][#{to}]\n"
                    f << "\\setuplayout\n"
                    f << "  [topspace=#{paperoffset},\n"
                    f << "   backspace=#{paperoffset},\n"
                    f << "   header=0pt,\n"
                    f << "   footer=1cm,\n"
                    f << "   width=middle,\n"
                    f << "   height=middle]\n"
                    if @commandline.option('nobanner') then
                        f << "\\setuplayout\n"
                        f << "  [footer=0cm]\n"
                    end
                    f << "\\setupexternalfigures\n"
                    f << "  [directory=]\n"
                    f << "\\starttext\n"
                    files.each do |filename|
                        result = @commandline.checkedoption('result','texexec')
                        if (filename !~ /^texexec/io) && (filename !~ /^#{result}/) then
                            report("combination file: #{filename}")
                            cleanname = cleantexfilename(filename).downcase
                            f << "\\setupfootertexts\n"
                            f << "  [\\tttf #{cleanname}\\quad\\quad\\currentdate\\quad\\quad\\pagenumber]\n"
                            f << "\\combinepages[#{filename}][nx=#{nx},ny=#{ny}]\n"
                            f << "\\page\n"
                        end
                    end
                    f << "\\stoptext\n"
                    f.close
                    job.setvariable('interface','english')
                    job.setvariable('simplerun',true)
                    # job.setvariable('nooptionfile',true)
                    job.setvariable('files',[job.tempfilename])
                    job.processtex
                else
                    report('no files to list')
                end
            else
                report('no files to list')
            end
            job.cleanuptemprunfiles
        end
    end

    private

    def prepare(job)

        job.booleanvars.each do |k|
            job.setvariable(k,@commandline.option(k))
        end
        job.stringvars.each do |k|
            job.setvariable(k,@commandline.option(k))
        end
        job.standardvars.each do |k|
            job.setvariable(k,@commandline.option(k))
        end
        job.knownvars.each do |k|
            job.setvariable(k,@commandline.option(k)) unless @commandline.option(k).empty?
        end

        if (str = @commandline.option('engine')) && ! str.standard? && ! str.empty? then
            job.setvariable('texengine',str)
        elsif @commandline.oneof('pdfetex','pdftex','pdf') then
            job.setvariable('texengine','pdfetex')
        elsif @commandline.oneof('xetex','xtx') then
            job.setvariable('texengine','xetex')
        elsif @commandline.oneof('aleph') then
            job.setvariable('texengine','aleph')
        else
            job.setvariable('texengine','standard')
        end

        if (str = @commandline.option('backend')) && ! str.standard? && ! str.empty? then
            job.setvariable('backend',str)
        elsif @commandline.oneof('pdfetex','pdftex','pdf') then
            job.setvariable('backend','pdftex')
        elsif @commandline.oneof('dvipdfmx','dvipdfm','dpx','dpm') then
            job.setvariable('backend','dvipdfmx')
        elsif @commandline.oneof('xetex','xtx') then
            job.setvariable('backend','xetex')
        elsif @commandline.oneof('aleph') then
            job.setvariable('backend','dvipdfmx')
        elsif @commandline.oneof('dvips','ps') then
            job.setvariable('backend','dvips')
        else
            job.setvariable('backend','standard')
        end

        if (str = @commandline.option('engine')) && ! str.standard? && ! str.empty? then
            job.setvariable('mpsengine',@commandline.option('engine'))
        else
            job.setvariable('mpsengine','standard')
        end

    end

    def cleantexfilename(filename)
        filename.gsub(/([\$\_\#])/) do "\\$1" end.gsub(/([\~])/) do "\\string$1" end
    end

end

# we will make this pluggable, i.e. load plugins from base/tex that
# extend the class and may even add switches
#
# commandline.load_plugins('base/tex')
#
# maybe it's too slow so for a while keep the --pdf* in here

logger      = Logger.new(banner.shift)
commandline = CommandLine.new

commandline.registeraction('make',    'make formats')
commandline.registeraction('check',   'check versions')
commandline.registeraction('process', 'process file')
commandline.registeraction('mptex',   'process mp file')
commandline.registeraction('mpxtex',  'process mpx file')

commandline.registeraction('listing',    'list of file content')
commandline.registeraction('figures',    'generate overview of figures')
commandline.registeraction('modules',    'generate module documentation')
commandline.registeraction('pdfarrange', 'impose pages (booklets)')
commandline.registeraction('pdfselect',  'select pages from file(s)')
commandline.registeraction('pdfcopy',    'copy pages from file(s)')
commandline.registeraction('pdftrim',    'trim pages from file(s)')
commandline.registeraction('pdfcombine', 'combine multiple pages')

# compatibility switch

class Commands

    include CommandBase

    alias pdfarrange :arrangeoutput
    alias pdfselect  :selectoutput
    alias pdfcopy    :copyoutput
    alias pdftrim    :trimoutput
    alias pdfcombine :combineoutput

end

# so far for compatibility

@@extrastringvars = [
    'pages', 'background', 'backspace', 'topspace', 'boxtype', 'tempdir',
    'printformat', 'paperformat', 'method', 'scale', 'selection',
    'combination', 'paperoffset', 'textwidth', 'addempty', 'logfile',
    'startline', 'endline', 'startcolumn', 'endcolumn', 'scale'
]

@@extrabooleanvars = [
    'centerpage', 'noduplex', 'color', 'pretty',
    'fullscreen', 'screensaver', 'markings'
]

if job = TEX.new(logger) then

    job.setextrastringvars(@@extrastringvars)
    job.setextrabooleanvars(@@extrabooleanvars)

    job.booleanvars.each do |k|
        commandline.registerflag(k)
    end
    job.stringvars.each do |k|
        commandline.registervalue(k,'')
    end
    job.standardvars.each do |k|
        commandline.registervalue(k,'standard')
    end
    job.knownvars.each do |k|
        commandline.registervalue(k,'')
    end

end

# todo: register flags -> first one true

commandline.registerflag('pdf')
commandline.registerflag('pdftex')
commandline.registerflag('pdfetex')

commandline.registerflag('dvipdfmx')
commandline.registerflag('dvipdfm')
commandline.registerflag('dpx')
commandline.registerflag('dpm')

commandline.registerflag('dvips')
commandline.registerflag('ps')

commandline.registerflag('xetex')
commandline.registerflag('xtx')

commandline.registerflag('aleph')

commandline.registerflag('all')
commandline.registerflag('fast')

# generic

commandline.registeraction('help')
commandline.registeraction('version')

commandline.registerflag('verbose')

commandline.expand

Commands.new(commandline,logger,banner).send(commandline.action || 'main')

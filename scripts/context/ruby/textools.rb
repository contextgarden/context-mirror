#!/usr/bin/env ruby

# program   : textools
# copyright : PRAGMA Advanced Document Engineering
# version   : 2002-2005
# author    : Hans Hagen
#
# project   : ConTeXt / eXaMpLe
# concept   : Hans Hagen
# info      : j.hagen@xs4all.nl
# www       : www.pragma-ade.com

# This script will harbor some handy manipulations on tex
# related files.

banner = ['TeXTools', 'version 1.2.2', '2002/2005', 'PRAGMA ADE/POD']

unless defined? ownpath
    ownpath = $0.sub(/[\\\/][a-z0-9\-]*?\.rb/i,'')
    $: << ownpath
end

require 'base/switch'
require 'base/logger'

require 'ftools'

# Remark
#
# The fixtexmftrees feature does not realy belong in textools, but
# since it looks like no measures will be taken to make texlive (and
# tetex) downward compatible with respect to fonts installed by
# users, we provide this fixer. This option also moves script files
# to their new location (only for context) in the TDS. Beware: when
# locating  scripts, the --format switch in kpsewhich should now use
# 'texmfscripts' instead of  'other text files' (texmfstart is already
# aware of this). Files will only be moved when --force is given. Let
# me know if more fixes need to be made.

class Commands

    include CommandBase

    def hidemapnames
        report('hiding FontNames in map files')
        xidemapnames(true)
    end

    def videmapnames
        report('unhiding FontNames in map files')
        xidemapnames(false)
    end

    def removemapnames

        report('removing FontNames from map files')

        if files = findfiles('map') then
            report
            files.sort.each do |fn|
                gn = fn # + '.nonames'
                hn = fn + '.original'
                begin
                    if FileTest.file?(fn) && ! FileTest.file?(hn) then
                        if File.rename(fn,hn) then
                            if (fh = File.open(hn,'r')) && (gh = File.open(gn,'w')) then
                                report("processing #{fn}")
                                while str = fh.gets do
                                    str.sub!(/^([^\%]+?)(\s+)([^\"\<\s]*?)(\s)/) do
                                        $1 + $2 + " "*$3.length + $4
                                    end
                                    gh.puts(str)
                                end
                                fh.close
                                gh.close
                            else
                                report("no permissions to handle #{fn}")
                            end
                        else
                            report("unable to rename #{fn} to #{hn}")
                        end
                    else
                        report("not processing #{fn} due to presence of #{hn}")
                    end
                rescue
                    report("error in handling #{fn}")
                end
            end
        end

    end

    def restoremapnames

        report('restoring FontNames in map files')

        if files = findfiles('map') then
            report
            files.sort.each do |fn|
                hn = fn + '.original'
                begin
                    if FileTest.file?(hn) then
                        File.delete(fn) if FileTest.file?(fn)
                        report("#{fn} restored") if File.rename(hn,fn)
                    else
                        report("no original found for #{fn}")
                    end
                rescue
                    report("error in restoring #{fn}")
                end
            end
        end

    end

    def findfile

        report('locating file in texmf tree')

        # ! not in tree
        # ? fuzzy
        # . in tree
        # > in tree and used

        if filename = @commandline.argument('first') then
            if filename && ! filename.empty? then
                report
                used = kpsefile(filename) || pathfile(filename)
                if paths = texmfroots then
                    found, prefered = false, false
                    paths.each do |p|
                        if files = texmffiles(p,filename) then
                            found = true
                            files.each do |f|
                                # unreadable: report("#{if f == used then '>' else '.' end} #{f}")
                                if f == used then
                                    prefered = true
                                    report("> #{f}")
                                else
                                    report(". #{f}")
                                end
                            end
                        end
                    end
                    if prefered then
                        report("! #{used}") unless found
                    else
                        report("> #{used}")
                    end
                elsif used then
                    report("? #{used}")
                else
                    report('no file found')
                end
            else
                report('no file specified')
            end
        else
            report('no file specified')
        end

    end

    def unzipfiles

        report('g-unzipping files')

        if files = findfiles('gz') then
            report
            files.each do |f|
                begin
                    system("gunzip -d #{f}")
                rescue
                    report("unable to unzip file #{f}")
                else
                    report("file #{f} is unzipped")
                end
            end
        end

    end

    def fixafmfiles

        report('fixing afm files')

        if files = findfiles('afm') then
            report
            ok = false
            files.each do |filename|
                if filename =~ /\.afm$/io then
                    if f = File.open(filename) then
                        result = ''
                        done = false
                        while str = f.gets do
                            str.chomp!
                            str.strip!
                            if str.empty? then
                                # skip
                            elsif (str.length > 200) && (str =~ /^(comment|notice)\s(.*)\s*$/io) then
                                done = true
                                tag, words, len = $1, $2.split(' '), 0
                                result += tag
                                while words.size > 0 do
                                    str = words.shift
                                    len += str.length + 1
                                    result += ' ' + str
                                    if len > (70 - tag.length) then
                                        result += "\n"
                                        result += tag if words.size > 0
                                        len = 0
                                    end
                                end
                                result += "\n" if len>0
                            else
                                result += str + "\n"
                            end
                        end
                        f.close
                        if done then
                            ok = true
                            begin
                                if File.rename(filename,filename+'.original') then
                                    if FileTest.file?(filename) then
                                        report("something to fix in #{filename} but error in renaming (3)")
                                    elsif f = File.open(filename,'w') then
                                        f.puts(result)
                                        f.close
                                        report('file', filename, 'has been fixed')
                                    else
                                        report("something to fix in #{filename} but error in opening (4)")
                                        File.rename(filename+'.original',filename) # gamble
                                    end
                                else
                                    report("something to fix in #{filename} but error in renaming (2)")
                                end
                            rescue
                                report("something to fix in #{filename} but error in renaming (1)")
                            end
                        else
                            report("nothing to fix in #{filename}")
                        end
                    else
                        report("error in opening #{filename}")
                    end
                end
            end
            report('no files match the pattern') unless ok
        end

    end

    def mactodos

        report('fixing mac newlines')

        if files = findfiles('tex') then
            report
            files.each do |filename|
                begin
                    report("converting file #{filename}")
                    tmpfilename = filename + '.tmp'
                    if f = File.open(filename) then
                        if g = File.open(tmpfilename, 'w')
                            while str = f.gets do
                                g.puts(str.gsub(/\r/,"\n"))
                            end
                            if f.close && g.close && FileTest.file?(tmpfilename) then
                                File.delete(filename)
                                File.rename(tmpfilename,filename)
                            end
                        else
                            report("unable to open temporary file #{tmpfilename}")
                        end
                    else
                        report("unable to open #{filename}")
                    end
                rescue
                    report("problems with fixing #{filename}")
                end
            end
        end

    end

    def fixtexmftrees

        if paths = @commandline.argument('first') then
            paths = [paths] if ! paths.empty?
        end
        paths = texmfroots if paths.empty?

        if paths then

            moved = 0
            force = @commandline.option('force')

            report
            report("checking TDS 2003 => TDS 2004 : map files")
            # report

            # move [map,enc]  files from /texmf/[dvips,pdftex,dvipdfmx] -> /texmf/fonts/[*]

            ['map','enc'].each do |suffix|
                paths.each do |path|
                    ['dvips','pdftex','dvipdfmx'].each do |program|
                        report
                        report("checking #{suffix} files for #{program} on #{path}")
                        report
                        moved += movefiles("#{path}/#{program}","#{path}/fonts/#{suffix}/#{program}",suffix) do
                            # nothing
                        end
                    end
                end
            end

            report
            report("checking TDS 2003 => TDS 2004 : scripts")
            # report

            # move [rb,pl,py] files from /texmf/someplace -> /texmf/scripts/someplace

            ['rb','pl','py'].each do |suffix|
                paths.each do |path|
                    ['context'].each do |program|
                        report
                        report("checking #{suffix} files for #{program} on #{path}")
                        report
                        moved += movefiles("#{path}/#{program}","#{path}/scripts/#{program}",suffix) do |f|
                            f.gsub!(/\/(perl|ruby|python)tk\//o) do
                                "/#{$1}/"
                            end
                        end
                    end
                end
            end

            begin
                if moved>0 then
                    report
                    if force then
                        system('mktexlsr')
                        report
                        report("#{moved} files moved")
                    else
                        report("#{moved} files will be moved")
                    end
                else
                    report('no files need to be moved')
                end
            rescue
                report('you need to run mktexlsr')
            end

        end

    end

    def replace

        report('replace file')

        if newname = @commandline.argument('first') then
            if newname && ! newname.empty? then
                report
                report("replacing #{newname}")
                report
                oldname = kpsefile(File.basename(newname))
                force = @commandline.option('force')
                if oldname && ! oldname.empty? then
                    oldname = File.expand_path(oldname)
                    newname = File.expand_path(newname)
                    report("old: #{oldname}")
                    report("new: #{newname}")
                    report
                    if newname == oldname then
                        report('unable to replace itself')
                    elsif force then
                        begin
                            File.copy(newname,oldname)
                        rescue
                            report('error in replacing the old file')
                        end
                    else
                        report('the old file will be replaced (use --force)')
                    end
                else
                    report('nothing to replace')
                end
            else
                report('no file specified')
            end
        else
            report('no file specified')
        end

    end

    private # general

    def texmfroots
        begin
            paths = `kpsewhich -expand-path=\$TEXMF`.chomp
        rescue
        else
            return paths.split(/#{File::PATH_SEPARATOR}/) if paths && ! paths.empty?
        end
        return nil
    end

    def texmffiles(root, filename)
        begin
            files = Dir.glob("#{root}/**/#{filename}")
        rescue
        else
            return files if files && files.length>0
        end
        return nil
    end

    def pathfile(filename)
        used = nil
        begin
            if ! filename || filename.empty? then
                return nil
            else
                ENV['PATH'].split(File::PATH_SEPARATOR).each do |path|
                    if FileTest.file?(File.join(path,filename)) then
                        used = File.join(path,filename)
                        break
                    end
                end
            end
        rescue
            used = nil
        else
            used = nil if used && used.empty?
        end
        return used
    end

    def kpsefile(filename)
        used = nil
        begin
            if ! filename || filename.empty? then
                return nil
            else
                used = `kpsewhich #{filename}`.chomp
            end
            if used && used.empty? then
                used = `kpsewhich -progname=context #{filename}`.chomp
            end
            if used && used.empty? then
                used = `kpsewhich -format=texmfscripts #{filename}`.chomp
            end
            if used && used.empty? then
                used = `kpsewhich -progname=context -format=texmfscripts #{filename}`.chomp
            end
            if used && used.empty? then
                used = `kpsewhich -format="other text files" #{filename}`.chomp
            end
            if used && used.empty? then
                used = `kpsewhich -progname=context -format="other text files" #{filename}`.chomp
            end
        rescue
            used = nil
        else
            used = nil if used && used.empty?
        end
        return used
    end

    def downcasefilenames

        report('downcase filenames')

        force = @commandline.option('force')

        # if @commandline.option('recurse') then
            # files = Dir.glob('**/*')
        # else
            # files = Dir.glob('*')
        # end
        # if files && files.length>0 then

        if files = findfiles() then
            files.each do |oldname|
                if FileTest.file?(oldname) then
                    newname = oldname.downcase
                    if oldname != newname then
                        if force then
                            begin
                                File.rename(oldname,newname)
                            rescue
                                report("#{oldname} == #{oldname}\n")
                            else
                                report("#{oldname} => #{newname}\n")
                            end
                        else
                            report("(#{oldname} => #{newname})\n")
                        end
                    end
                end
            end
        end
    end

    def stripformfeeds

        report('strip formfeeds')

        force = @commandline.option('force')

        if files = findfiles() then
            files.each do |filename|
                if FileTest.file?(filename) then
                    begin
                        data = IO.readlines(filename).join('')
                    rescue
                    else
                        if data.gsub!(/\n*\f\n*/io,"\n\n") then
                            if force then
                                if f = open(filename,'w') then
                                    report("#{filename} is stripped\n")
                                    f.puts(data)
                                    f.close
                                else
                                    report("#{filename} cannot be stripped\n")
                                end
                            else
                                report("#{filename} will be stripped\n")
                            end
                        end
                    end
                end
            end
        end
    end

    public

    def showfont

        file = @commandline.argument('first')

        if file.empty? then
            report('provide filename')
        else
            file.sub!(/\.afm$/,'')
            begin
                report("analyzing afm file #{file}.afm")
                file = `kpsewhich #{file}.afm`.chomp
            rescue
                report('unable to run kpsewhich')
                return
            end

            names = Array.new

            if FileTest.file?(file) then
                File.new(file).each do |line|
                    if line.match(/^C\s*([\-\d]+)\s*\;.*?\s*N\s*(.+?)\s*\;/o) then
                        names.push($2)
                    end
                end
                ranges = names.size
                report("number of glyphs: #{ranges}")
                ranges = ranges/256 + 1
                report("number of subsets: #{ranges}")
                file = File.basename(file).sub(/\.afm$/,'')
                tex = File.open("textools.tex",'w')
                map = File.open("textools.map",'w')
                tex.puts("\\starttext\n")
                tex.puts("\\loadmapfile[textools.map]\n")
                for i in 1..ranges do
                    rfile = "#{file}-range-#{i}"
                    report("generating enc file #{rfile}.enc")
                    flushencoding("#{rfile}", (i-1)*256, i*256-1, names)
                    # catch console output
                    report("generating tfm file #{rfile}.tfm")
                    mapline = `afm2tfm #{file}.afm -T #{rfile}.enc #{rfile}.tfm`
                    # more robust replacement
                    mapline = "#{rfile} <#{rfile}.enc <#{file}.pfb"
                    # final entry in map file
                    mapline = "#{mapline} <#{file}.pfb"
                    map.puts("#{mapline}\n")
                    tex.puts("\\showfont[#{rfile}][unknown]\n")
                end
                tex.puts("\\stoptext\n")
                report("generating map file textools.map")
                report("generating tex file textools.tex")
                map.close
                tex.close
            else
                report("invalid file #{file}")
            end
        end

    end

    private

    def flushencoding (file, from, to, names)
        n = 0
        out = File.open("#{file}.enc",'w')
        out.puts("/#{file.gsub(/\-/,'')} [\n")
        for i in from..to do
            if names[i] then
                n += 1
                out.puts("/#{names[i]}\n")
            else
                out.puts("/.notdef\n")
            end
        end
        out.puts("] def\n")
        out.close
        return n
    end

    private # specific

    def movefiles(from_path,to_path,suffix,&block)
        obsolete = 'obsolete'
        force = @commandline.option('force')
        moved = 0
        if files = texmffiles(from_path, "*.#{suffix}") then
            files.each do |filename|
                newfilename = filename.sub(/^#{from_path}/, to_path)
                yield(newfilename) if block
                if FileTest.file?(newfilename) then
                    begin
                        File.rename(filename,filename+'.obsolete') if force
                    rescue
                        report("#{filename} cannot be made obsolete") if force
                    else
                        if force then
                            report("#{filename} is made obsolete")
                        else
                            report("#{filename} will become obsolete")
                        end
                    end
                else
                    begin
                        File.makedirs(File.dirname(newfilename)) if force
                    rescue
                    end
                    begin
                        File.copy(filename,newfilename) if force
                    rescue
                        report("#{filename} cannot be copied to #{newfilename}")
                    else
                        begin
                            File.delete(filename) if force
                        rescue
                            report("#{filename} cannot be deleted") if force
                        else
                            if force then
                                report("#{filename} is moved to #{newfilename}")
                                moved += 1
                            else
                                report("#{filename} will be moved to #{newfilename}")
                            end
                        end
                    end
                end
            end
        else
            report('no matches found')
        end
        return moved
    end

    def xidemapnames(hide)

        filter  = /^([^\%]+?)(\s+)([^\"\<\s]*?)(\s)/
        banner  = '% textools:nn '

        if files = findfiles('map') then
            report
            files.sort.each do |fn|
                if fn.has_suffix?('map') then
                    begin
                        lines = IO.read(fn)
                        report("processing #{fn}")
                        if f = File.open(fn,'w') then
                            skip = false
                            if hide then
                                lines.each do |str|
                                    if skip then
                                        skip = false
                                    elsif str =~ /#{banner}/ then
                                        skip = true
                                    elsif str =~ filter then
                                        f.puts(banner+str)
                                        str.sub!(filter) do
                                            $1 + $2 + " "*$3.length + $4
                                        end
                                    end
                                    f.puts(str)
                                end
                            else
                                lines.each do |str|
                                    if skip then
                                        skip = false
                                    elsif str.sub!(/#{banner}/, '') then
                                        f.puts(str)
                                        skip = true
                                    else
                                        f.puts(str)
                                    end
                                end
                            end
                            f.close
                        end
                    rescue
                        report("error in handling #{fn}")
                    end
                end
            end
        end

    end

    public

    def mergeupdate

        nocheck = @commandline.option('nocheck')
        force   = @commandline.option('force')
        root    = @commandline.argument('first')
        path    = @commandline.argument('second')

        if FileTest.directory?(root) then
            report("scanning #{root}")
            rootfiles = Dir.glob("#{root}/**/*")
        else
            report("provide sourse root")
            return
        end
        if rootfiles.size > 0 then
            report("#{rootfiles.size} files")
        else
            report("no files")
            return
        end

        if FileTest.directory?(path) then
            report("scanning #{path}")
            pathfiles = Dir.glob("#{path}/**/*")
        else
            report("provide destination root")
            return
        end
        if pathfiles.size > 0 then
            report("#{pathfiles.size} files")
        else
            report("no files")
            return
        end

        roothash = Hash.new
        pathhash = Hash.new

        rootfiles.each do |f|
            if File.file?(f) then
                fd, fb = File.dirname(f), File.basename(f)
                roothash[fb] = if roothash.key?(fb) then nil else fd end
            end
        end

        pathfiles.each do |f|
            if File.file?(f) then
                fd, fb = File.dirname(f), File.basename(f)
                pathhash[fb] = if pathhash.key?(fb) then nil else fd end
            end
        end

        pathhash.keys.each do |f|
            if pathhash[f] && roothash[f] then
                p = File.expand_path(File.join(pathhash[f],f))
                r = File.expand_path(File.join(roothash[f],f))
                if p != r then
                    if nocheck or File.mtime(p) < File.mtime(r) then
                        report("copying '#{r}' to '#{p}'")
                        begin
                            File.copy(r,p) if force
                        rescue
                            report("copying failed")
                        end
                    else
                        report("skipping '#{r}' to '#{p}'")
                    end
                end
            end
        end

    end

end

logger      = Logger.new(banner.shift)
commandline = CommandLine.new

commandline.registeraction('removemapnames'   , '[pattern]   [--recurse]')
commandline.registeraction('restoremapnames'  , '[pattern]   [--recurse]')
commandline.registeraction('hidemapnames'     , '[pattern]   [--recurse]')
commandline.registeraction('videmapnames'     , '[pattern]   [--recurse]')
commandline.registeraction('findfile'         , 'filename    [--recurse]')
commandline.registeraction('unzipfiles'       , '[pattern]   [--recurse]')
commandline.registeraction('fixafmfiles'      , '[pattern]   [--recurse]')
commandline.registeraction('mactodos'         , '[pattern]   [--recurse]')
commandline.registeraction('fixtexmftrees'    , '[texmfroot] [--force]')
commandline.registeraction('replace'          , 'filename    [--force]')
commandline.registeraction('mergeupdate'      , 'fromroot toroot [--force --nocheck]')
commandline.registeraction('downcasefilenames', '[--recurse] [--force]') # not yet documented
commandline.registeraction('stripformfeeds'   , '[--recurse] [--force]') # not yet documented
commandline.registeraction('showfont'         , 'filename')

commandline.registeraction('help')
commandline.registeraction('version')

commandline.registerflag('recurse')
commandline.registerflag('force')
commandline.registerflag('nocheck')

commandline.expand

Commands.new(commandline,logger,banner).send(commandline.action || 'help')

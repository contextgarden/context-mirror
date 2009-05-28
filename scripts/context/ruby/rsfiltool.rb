# program   : rsfiltool
# copyright : PRAGMA Publishing On Demand
# version   : 1.01 - 2002
# author    : Hans Hagen
#
# project   : eXaMpLe
# concept   : Hans Hagen
# info      : j.hagen@xs4all.nl
# www       : www.pragma-pod.com / www.pragma-ade.com

unless defined? ownpath
    ownpath = $0.sub(/[\\\/]\w*?\.rb/i,'')
    $: << ownpath
end

# --name=a,b,c.xml wordt names [a.xml, b.xml, c.xml]
# --path=x/y/z/a,b,c.xml wordt [x/y/z/a.xml, x/y/z/b.xml, x/y/z/c.xml]

# todo : split session stuff from xmpl/base into an xmpl/session module and "include xmpl/session" into base and here and ...

require 'fileutils'
# require 'ftools'
require 'xmpl/base'
require 'xmpl/switch'
require 'xmpl/request'

session = Example.new('rsfiltool', '1.01', 'PRAGMA POD')

filterprefix = 'rsfil-'

commandline = CommandLine.new

commandline.registerflag('submit')
commandline.registerflag('fetch')
commandline.registerflag('report')
#commandline.registerflag('split')
commandline.registerflag('stamp')
commandline.registerflag('silent')
commandline.registerflag('request')
commandline.registerflag('nobackup')

commandline.registervalue('filter')

commandline.registervalue('root')
commandline.registervalue('path')
commandline.registervalue('name')

commandline.expand

session.set('log.silent',true) if commandline.option('silent')

session.inherit(commandline)

session.identify

# session.exit unless session.loadenvironment

def prepare (session)

    # Normally the system provides the file, but a user can provide the rest; in
    # order to prevent problems with keying in names, we force lowercase names.

    session.set('option.file',session.get('argument.first')) if session.get('option.file').empty?

    root = session.get('option.root').downcase
    path = session.get('option.path').downcase
    name = session.get('option.name').downcase
    file = session.get('option.file').downcase

    session.error('provide file') if file.empty?
    session.error('provide root') if root.empty?

    filter = session.get('option.filter').downcase
    trash  = session.get('option.trash').downcase

    trash = '' unless FileTest.directory?(trash)

    if not filter.empty? then
        begin
            require filter
        rescue Exception
            begin
                require filterprefix + filter
            rescue Exception
                session.error('invalid filter')
            end
        end
        begin
            if RSFIL::valid?(file) then
                split = RSFIL::split(file,name)
                path = if split[0].downcase then split[0] else '' end
                file = if split[1].downcase then split[1] else '' end
                name = if split[2].downcase then split[2] else '' end
                session.report('split result',split.inspect)
                session.error('unable to split off path') if path.empty?
                session.error('unable to split off file') if file.empty?
                session.error('unable to split off name') if name.empty?
                session.set('option.path',path) if path
                session.set('option.file',file) if file
                session.set('option.name',name) if name
            else
                session.error('invalid filename', file)
                unless trash.empty? then
                    File.copy(file,trash + '/' + file)
                end
            end
        rescue
            session.error('unable to split',file,'with filter',filter)
        end
    end

    session.error('provide path') if path.empty?

    session.error('invalid root') unless test(?d,root)

    exit if session.error?

    session.set('fb.filename',file)

    path.gsub!(/\\/o, '/')
    path.gsub!(/\s/o, '')

    path = root + '/' + path

    # multiple paths

    if path =~ /^(.*)\/(.*?)$/o then
        prepath = $1
        postpath = $2
        paths = postpath.split(/\,/)
        paths.collect! do |p|
            prepath + '/' + p
        end
    else
        paths = Array.new
        paths.push(path)
    end

    paths.collect! do |p|
        p.gsub(/[^a-zA-Z0-9\s\-\_\/\.\:]/o, '-')
    end

    file.gsub!(/\\/o, '/')
    file.gsub!(/[^a-zA-Z0-9\s\-\_\/\.\:]/o, '-')

#    if session.get('option.split')
#        if file =~ /(.*)\.(.*?)$/o
#            path = path + '/' + $1
#        else
#            session.error('nothing to split in filename')
#        end
#    end

    paths.each do |p|
        begin
            session.report('creating path', p)
            File.makedirs(p)
        rescue
            session.error('unable to create path', p)
        end
    end

    name.gsub!(/\s+/,'')

    # can be a,b,c.exa.saved => a.exa.saved,b.exa.saved,c.exa.saved

    if name =~ /(.*?)\.(.*)$/
        name = $1
        suffix = $2
        names = name.split(/\,/)
        names.collect! do |n|
            n + '.' + suffix
        end
        name = names.join(',')
    else
        names = name.split(/\,/)
    end

    session.set('fb.path',path)
    session.set('fb.paths',paths)
    session.set('fb.name',name)
    session.set('fb.names',names)

end

def thefullname(path,file,name='')

    filename = file.gsub(/.*?\//, '')

    if name.empty?
        path + '/' + filename
    else
        unless name =~ /\..+$/o  # unless name.match(/\..+$/o)
            if filename =~ /(\..+)$/o  # if file.match(/(\..+)$/o)
                name = name + $1
            end
        end
        path + '/' + name
    end

end

def submitfile (session)

    filename = session.get('fb.filename')
    paths = session.get('fb.paths')
    names = session.get('fb.names')

    paths.each do |path|
        session.report('submitting path',path)
        names.each do |name|
            session.report('submitting file',filename,'to',name)
            submit(session,path,filename,name)
        end
    end

end

def submitlist (session)

    requestname = session.get('fb.filename')
    paths = session.get('fb.paths')

    if test(?e,requestname)
        session.report('loading request file', requestname)
        if request = ExaRequest.new(requestname)
            filelist = request.files
            if filelist && (filelist.size > 0)
                filelist.each do |filename|
                    paths.each do |path|
                        session.report('submitting file from list', filename)
                        submit(session,path,filename,request.naturalname(filename))
                    end
                end
            else
                session.warning('no filelist in', requestname)
            end
        else
            session.warning('unable to load', requestname)
        end
    else
        session.warning('no file', requestname)
    end

end

def submit (session, path, filename, newname)

    fullname = thefullname(path,newname)

    unless test(?e,filename)
        session.warning('no file to submit', filename)
        return
    end

    begin
        File.copy(fullname,fullname+'.old') if ! session.get('nobackup') && test(?e,fullname)
        if test(?e,filename)
            File.copy(filename,fullname)
            session.report('submit', filename, 'in', fullname)
            if session.get('option.stamp')
                f = open(fullname+'.tim','w')
                f.puts(Time.now.gmtime.strftime("%a %b %d %H:%M:%S %Y"))
                f.close
            end
        else
            session.error('unable to locate', filename)
        end
    rescue
        session.error('unable to move', filename, 'to', fullname)
    end

end

def fetch (session)

    filename = session.get('fb.filename')
    paths = session.get('fb.paths')
    name = session.get('fb.name')

    begin
        File.copy(filename,filename+'.old') if ! session.get('nobackup') && test(?e,filename)
        paths.each do |path|
            #  fullname = thefullname(path,request.naturalname(filename))
            # fullname = thefullname(path,filename)
            fullname = thefullname(path,name)
            if test(?e,fullname)
                File.copy(fullname,filename)
                session.report('fetch', filename, 'from', fullname)
                return
            else
                session.report('file',fullname, 'is not present')
            end
        end
    rescue
        session.error('unable to fetch file from path')
    end
    session.error('no file',filename, 'fetched') unless test(?e,filename)

end

def report (session)

    filename = session.get('fb.filename')
    paths = session.get('fb.paths')

    paths.each do |path|
        fullname = thefullname(path,request.naturalname(filename))
        if test(?e,fullname)
            begin
                session.report('file', fullname)
                session.report('size', test(?s,fullname))
                if test(?e,fullname+'.tim')
                    str = IO.readlines(fullname+'.tim')
                    # str = IO.read(fullname+'.tim')
                    session.report('time', str)
                end
            rescue
                session.error('unable to report about', fullname)
            end
        end
    end

end

if session.get('option.submit')
    prepare(session)
    if session.get('option.request')
        submitlist(session)
    else
        submitfile(session)
    end
elsif session.get('option.fetch')
    prepare(session)
    fetch(session)
elsif session.get('option.report')
    prepare(session)
    report(session)
else
    session.report('provide action')
end

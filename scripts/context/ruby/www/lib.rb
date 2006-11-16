#!/usr/bin/env ruby

# This is just a simple environment for remote processing of context
# files. It's not a framework, nor an example of how that should be done.
# Nowadays there are environments like Rails or Nitro. Maybe some day I'll
# give one of them a try.

# <META Http-Equiv="Cache-Control" Content="no-cache">
# <META Http-Equiv="Pragma" Content="no-cache">
# <META Http-Equiv="Expires" Content="0">

# we make limited use of cgi methods because we also need to handle webrick

# %var% as well as $(var) are supported

# paths need to be expanded before they enter apache, since .. is not
# handled by default

require 'base/variables'

require 'ftools'
require 'fileutils'
require 'tempfile'
require 'timeout'
require 'md5'
require 'digest/md5'
require 'cgi' # we also need escaping for webrick (could move it here)

# beware, namespaces have to match !

module XML

    def XML::element(tag,attributes=nil)
        if attributes.class == Hash then
            if block_given? then
                XML::element(tag,XML::attributes(attributes)) do yield end
            else
                XML::element(tag,XML::attributes(attributes))
            end
        else
            if block_given? then
                "<#{tag}#{if attributes && ! attributes.empty? then ' ' + attributes end}>#{yield}</#{tag}>"
            else
                "<#{tag}#{if attributes && ! attributes.empty? then ' ' + attributes end}/>"
            end
        end
    end

    def XML::attributes(hash)
        str = ''
        hash.each do |k,v|
            str << ' ' unless str.empty?
            if v =~ /\'/ then
                str << "#{k}=\"#{v}\""
            else
                str << "#{k}=\'#{v}\'"
            end
        end
        return str
    end

    def XML::create(version='1.0')
        "<?version='#{version}'?>#{yield || ''}"
    end

    def XML::line
        "\n"
    end

end

# str =
    # XML::create do
        # XML::element('test') do
            # XML::element('test') do
                # 'text a'
            # end +
            # XML::element('test',XML::attributes({'a'=>'b'})) do
                # XML::element('nested',XML::attributes({'a'=>'b'})) do
                    # 'text b-1'
                # end +
                # XML::element('nested',XML::attributes({'a'=>'b'})) do
                    # 'text b-2'
                # end
            # end +
            # XML::element('nested',{'a'=>'b'}) do
                # 'text c'
            # end
       # end
    # end

class ExtendedHash

    DEFAULT = 'default'

    @@re_default = /^(default|)$/i

    def default?(key)
        self[key] =~ @@re_default rescue true # unset, empty or 'default'
    end

    def default(key)
        self[key] = DEFAULT
    end

    def match?(key,value)
        value == '*' || value == self[key]
    end


end

class WWW

    @@session_prefix  = ''
    @@data_file       = 'example.cfg'
    @@session_max_age = 60*60
    @@watch_delay     = 30
    @@send_threshold  = 2*1024*1024
    @@admin_refresh   = 10
    @@namespace       = "http://www.pragma-ade.com/schemas/example.rng"

    @@re_bar   = /\s*\|\s*/
    @@re_lst   = /\s*\,\s*/
    @@re_var_a = /\%(.*?)\%/
    @@re_var_b = /\$\((.*?)\)/

    attr_reader :variables
    attr_writer :variables

    @@paths = [
        'configurations',
        'data',
        'distributions',
        'documents',
        'interfaces',
        'logs',
        'resources',
        'runners',
        'scripts',
        'templates',
        'work']

    @@re_true  = /^\s*(YES|ON|TRUE|1)\s*$/io
    @@re_false = /^\s*(NO|OFF|FALSE|0)\s*$/io

    def initialize(webrick_daemon=nil,webrick_request=nil,webrick_response=nil)
        @session_id, @session_file = '', ''
        @cgi, @cgi_cookie = nil, nil
        @webrick_daemon, @webrick_request, @webrick_response = webrick_daemon, webrick_request, webrick_response

        @interface = ExtendedHash.new
        @variables = ExtendedHash.new
        @session   = ExtendedHash.new

        @checked = false

        analyze_request()
        update_interface()

        @interface.set('template:message'  , 'exalogin-template.htm')
        @interface.set('template:status'   , 'exalogin-template.htm')
        @interface.set('template:login'    , 'exalogin.htm')
        @interface.set('process:timeout'   ,  @@session_max_age)
        @interface.set('process:threshold' ,  @@send_threshold)
        @interface.set('process:background', 'yes')  # this demands a watchdog being active
        @interface.set('process:indirect'  , 'no')  # indirect download, no direct feed
        @interface.set('process:autologin' , 'yes') # provide default interface when applicable
        @interface.set('process:exaurl'    , '')    # this one will be used as replacement in templates
        @interface.set('trace:run'         , 'no')
        @interface.set('trace:errors'      , 'no')
        @interface.set('process:os'        , platform)
        @interface.set('process:texos'     , 'texmf-' + platform)

        @interface.set('trace:run'         , 'yes') if (ENV['EXA_TRACE_RUN']    || '') =~ @@re_true
        @interface.set('trace:errors'      , 'yes') if (ENV['EXA_TRACE_ERRORS'] || '') =~ @@re_true

        yield self if block_given?
    end

    def set(key,value)
        @interface.set(key,value)
    end
    def get(key)
        @interface.get(key,value)
    end

    def platform
        case RUBY_PLATFORM
            when /(mswin|bccwin|mingw|cygwin)/i then 'mswin'
            when /(linux)/i                     then 'linux'
            when /(netbsd|unix)/i               then 'unix'
            when /(darwin|rhapsody|nextstep)/i  then 'macosx'
            else                                     'unix'
        end
    end

    def check_cgi
        # when mod_ruby is used, we need to close
        # the cgi session explicitly
        unless @webrick_request then
            unless @cgi then
                @cgi = CGI.new('html4')
                at_exit do
                    begin
                        @cgi.close
                    rescue
                    end
                end
            end
        end
    end

    def request_variable(key)
        begin
            if @webrick_request then
                [@webrick_request.query[key]].flatten.first.to_s
            else
                check_cgi
                [@cgi.params[key]].flatten.first.to_s
            end
        rescue
            ''
        end
    end

    def request_cookie(key)
        begin
            if @cgi then
                if str = @cgi.cookies[key] then
                    return str.first || ''
                end
            elsif @webrick_request then
                @webrick_request.cookies.flatten.each do |cookie|
                    if cookie.name == key then
                        return cookie.value unless cookie.value.empty?
                    end
                end
            end
        rescue
        end
        return ''
    end

    def analyze_request
        if @webrick_request then
            @interface.set('path:docroot', @webrick_daemon.config[:DocumentRoot] || './documents')
            @interface.set('process:uri', @webrick_request.request_uri.to_s)
            # @interface.set('process.url', [@webrick_request.host,@webrick_request.request_port].join(':'))
            @cgi = nil
            @webrick_request.query.each do |key, value|
                # todo: filename
                @variables.set(key, [value].flatten.first)
            end
        else
            @interface.set('path:docroot', ENV['DOCUMENT_ROOT'] || './documents')
            @interface.set('process:uri', ENV['REQUEST_URI'] || '')
            # @interface.set('process.url', [ENV['SERVER_NAME'],ENV['SERVER:PORT']].join(':'))
            ARGV[0] = '' # get rid of terminal mode
            check_cgi
            # quite fragile, due to changes between 1.6 and 1.8
            @cgi.params.keys.each do |p|
                if @cgi[p].respond_to?(:original_filename) then
                    @interface.set('log:method','post')
                    if @cgi[p].original_filename && ! @cgi[p].original_filename.empty? then
                        @variables.set(p, File.basename(@cgi[p].original_filename))
                    else
                        case @cgi.params[p].class
                            when StringIO.class then @variables.set(p, @cgi[p].read)
                            when Array.class    then @variables.set(p, @cgi[p].first.to_s)
                            when String.class   then @variables.set(p, @cgi[p])
                            when Tempfile.class then @variables.set(p, '[data blob]')
                        end
                    end
                else
                    @interface.set('log:method','get') unless @interface.get('log:method') == 'post'
                    @variables.set(p, [@cgi.params[p]].flatten.first.to_s)
                end
            end
        end
        @interface.set('path:root', File.dirname(@interface.get('path:docroot')))
    end

    # name in calling script takes precedence
    # one can set template:whatever as well
    # todo: in config

    def check_template_file(tag='',filename='exalogin-template.htm')
        @interface.set('file:template', filename) if @interface.get('file:template').empty?
        @interface.set('tag:template', tag)
        @interface.set('file:template', @interface.get('tag:template')) unless @interface.get('tag:template').empty?
    end

    def update_interface()
        root = @interface.get('path:docroot')
        @interface.set('path:docroot', File.expand_path("#{root}"))
        @@paths.each do |path|
            @interface.set("path:#{path}", File.expand_path("#{root}/../#{path}"))
        end
        @interface.set('file:template', @interface.get('tag:template')) unless @interface.get('tag:template').empty?
    end

    def indirect?(result)
        size = FileTest.size?(result) || 0
        @interface.true?('trace:errors') || @interface.true?('trace:run') || @interface.true?('process:indirect') ||
            ((! @interface.empty?('process:threshold')) && (size > @interface.get('process:threshold').to_i)) ||
            ((! @session.empty?('threshold'))           && (size > @session.get('threshold').to_i))
    end

end

# files

class WWW

    def sesname
        File.basename(@session_file)
    end
    def dirname
        File.basename(@session_file.sub(/ses$/,'dir'))
    end
    def lckname
        File.basename(@session_file.sub(/ses$/,'lck'))
    end

    def work_root(expand=true)
        p = if expand then File.expand_path(@interface.get('path:work')) else @interface.get('path:work') end
        if @interface.true?('process:background') then
            File.join(@interface.get('path:work'),'watch')
        else
            File.join(@interface.get('path:work'),'direct')
        end
    end

    def work_roots(expand=true)
        p = if expand then File.expand_path(@interface.get('path:work')) else @interface.get('path:work') end
        [File.join(@interface.get('path:work'),'watch'),File.join(@interface.get('path:work'),'direct')]
    end

    def cache_root(expand=true)
        p = if expand then File.expand_path(@interface.get('path:work')) else @interface.get('path:work') end
        File.join(@interface.get('path:work'),'cache')
    end

    def cleanup_path(dir)
        FileUtils::rm_r(pth) rescue false
    end

    def tmp_path(dir)
        @interface.set('path:templates', File.expand_path(@interface.get('path:templates'))) # to be sure; here ? ? ?
        pth = File.join(work_root,dir)
        File.makedirs(pth) rescue false
        pth
    end

    def locked?(lck)
        FileTest.file?(lck)
    end

end

# sessions

class WWW

    @@session_tags  = ['id','domain','project','username','password','gui','path','process','command','filename','action','status', 'starttime','endtime','runtime','task','option','threshold','url'].sort
    @@session_keep  = ['id','domain','project','username','password','process'].sort
    @@session_reset = @@session_tags - @@session_keep

    def new_session()
        if @variables.empty?('exa:session') then
            @session_id = new_session_id
        else
            @session_id = @variables.get('exa:session')
        end
        if @session_id == 'default' then # ???
            @session_id = new_session_id
        end
        @session_file = File.join(work_root,"#{@@session_prefix}#{@session_id}.ses")
        register_session
        return @session_id
    end

    def reset_session(all=false)
        (if all then @@session_tags else @@session_reset end).each do |k|
            @session.set(k)
        end
    end

    def valid_session
        @session_id = request_variable('id')
        if @session_id.empty? then
            begin
                if @cgi then
                    if @session_id = @cgi.cookies['session_id'] then
                        @session_id = @session_id.first || ''
                    else
                        @session_id = ''
                    end
                elsif @webrick_request then
                    @webrick_request.cookies.flatten.each do |cookie|
                        if cookie.name == 'session_id' then
                            unless cookie.value.empty? then
                                @session_id = cookie.value
                                # break
                            end
                        end
                    end
                else
                    @session_id = ''
                end
            rescue
                @interface.set('log:session',"[error in request #{$!}]")
                return false
            end
        end
        if @session_id.empty? then
            @interface.set('log:session','[no id, check work dir permissions]')
            return false
        else
            @interface.set('log:session',@session_id)
            load_session
            if ! @session.empty?('domain') && ! @session.empty?('project') && ! @session.empty?('username') then
                register_session
                return @session_id
            else
                return false
            end
        end
    end

    def touch_session(id=nil)
        begin
            t = Time.now
            File.utime(t,t,File.join(work_root,"#{@@session_prefix}#{id || @session_id}.ses")) rescue false
        rescue
            false
        end
    end

    def forced_session
        @session_id = new_session
        if @session_id.empty? then
            @interface.set('log:session','[no id, check work dir permissions]')
            return false
        else
            return check_session
        end
    end

    def client_session
        request, done = @variables.get('exa:request'), false
        request.sub!(/(^.*<exa:request[^>]*>.*?)\s*<exa:client>\s*(.*)\s*<\/exa:client>\s*(.*?<\/exa:request>.*$)/mio) do
            pre, client, post = $1, $2, $3
            client.scan(/<exa:(domain|project|username|password)>(.*?)<\/exa:\1>/mio) do
                @variables.set($1, $2)
            end
            done = true
            pre + post
        end
        if done then
            return forced_session
        else
            return nil
        end
    end

    def register_session
        if @cgi then
            @cgi_cookie = CGI::Cookie::new(
                'name'    => 'session_id',
                'value'   => @session_id,
                'expires' => Time.now + @interface.get('process:timeout').to_i
            )
            # @cgi_cookie = CGI::Cookie::new('session_id',@session_id)
        elsif @webrick_response then
            if cookie = WEBrick::Cookie.new('session_id', @session_id) then
                cookie.expires = Time.now + @interface.get('process:timeout').to_i
                cookie.max_age = @interface.get('process:timeout').to_i
                cookie.comment = 'exa identifier'
                @webrick_response.cookies.clear
                @webrick_response.cookies << cookie
            end
        end
    end

    def new_session_id # taken from cgi
        md5 = Digest::MD5::new
        now = Time::now
        md5.update(now.to_s)
        md5.update(String(now.usec))
        md5.update(String(rand(0)))
        md5.update(String($$))
        md5.update('foobar')
        @new_session = true
        md5.hexdigest[0,32] # was 16
    end

    @@hide_passwords = true
    HIDDEN = 'hidden'

    def same_passwords(password) # password in cfg file
        if @@hide_passwords && (@session.get('password') == HIDDEN) && (@session_id == @session.get('id')) then
            # this condition is only true when a same session id is found and
            # the password is checked once and set to HIDDEN
            same = true
        elsif password =~ /^MD5:/ then
            # so, one cannot send a known encrypted password since it will be
            # encrypted twice then
            same = (password == "MD5:" + MD5.new(@session.get('password')).hexdigest.upcase)
        else
            if (@session.default?('domain') && @session.default?('project') && @session.default?('username')) then
                @session.default('password') # is this safe enough?
            end
            same = (password == @session.get('password'))
        end
        if @@hide_passwords && same then
            @session.set('password', HIDDEN)
            save_session # next time this session is ok anyway
        end
        return same
    end

    @@session_line  = /^\s*(?![\#\%])(.*?)\s*\=\s*(.*?)\s*$/o
    @@session_begin = 'begin exa session'
    @@session_end   = 'end exa session'

    def loaded_session_data(filename)
        begin
            if data = IO.readlines(filename) then
                return data if (data.first =~ /^[\#\%]\s*#{@@session_begin}/o) && (data.last =~ /^[\#\%]\s*#{@@session_end}/o)
            end
        rescue
        end
        return nil
    end

    def load_session()
        begin
            @session_file = File.join(work_root,"#{@@session_prefix}#{@session_id}.ses")
            if data = loaded_session_data(@session_file) then
                data.each do |line|
                    if line =~ @@session_line then
                        @session.set($1, $2 || '')
                    end
                end
            else
                return false
            end
        rescue
            return false
        else
            return true
        end
    end

    def load_session_file(filename)
        begin
            if data = loaded_session_data(filename) then
                session = Hash.new
                data.each do |line|
                    if line =~ @@session_line then
                        session[$1] = $2 || ''
                    end
                end
            else
                Hash.new
            end
        rescue
            Hash.new
        else
            session
        end
    end

    def save_session
        begin
            unless @session_id.empty? then
                @session_file = File.join(work_root,"#{@@session_prefix}#{@session_id}.ses")
                @session_file = File.join(work_root,"#{@@session_prefix}#{@session_id}.ses")
                File.open(@session_file,'w') do |f|
                    f << "\# #{@@session_begin}\n"
                    @@session_tags.each do |tag|
                        if @session && @session.key?(tag) then
                            if ! @session.get(tag).empty? then # no one liner, fails
                                f << "#{tag}=#{@session.get(tag)}\n"
                            end
                        elsif @variables.key?(tag) && ! @variables.empty?(key) then
                            f << "#{tag}=#{@variables.get(tag)}\n"
                        end
                    end
                    @session.subset("ENV").keys.each do |tag|
                        f << "#{tag}=#{@session.get(tag)}\n"
                    end
                    f << "\# #{@@session_end}\n"
                end
            end
        rescue
            return false
        else
            return true
        end
    end

    def logged_in_session(force_default=false)
        if force_default || (@variables.default?('domain') && @variables.default?('project') && @variables.default?('username')) then
            id = default_session
        else
            id = check_session
        end
    end

    def default_session
        if @interface.true?('process:autologin') then
            @variables.default('domain')
            @variables.default('project')
            @variables.default('username')
            @variables.default('password')
            check_session
        else
            @session_id = nil
        end
    end

    def check_session
        @session.set('domain',   @variables.get('domain').downcase)
        @session.set('project',  @variables.get('project').downcase)
        @session.set('username', @variables.get('username').downcase)
        @session.set('password', @variables.get('password').downcase)
        new_session
        @session.set('id', @session_id)
        save_session
        return @session_id
    end

    def delete_session(id=nil)
        File.delete(work_root,"#{@@session_prefix}#{id || @session_id}.ses") rescue false
    end

    def cleanup_sessions(max_age=nil)
        begin
            now, age = Time.now, (max_age||@interface.get('process:timeout')).to_i
            Dir.glob("{#{work_root},#{cache_root}/#{@@session_prefix}*").each do |s|
                begin
                    if (now - File.mtime(s)) > age then
                        if FileTest.directory?(s) then
                            FileUtils::rm_r(s)
                        else
                            File.delete(s)
                        end
                    end
                rescue
                    # maybe purged in the meantime
                end
            end
        rescue
            # maybe another process is busy
        end
    end

end

# templates

class WWW

    def filled_template(title,text,showtime=false,refresh=0,refreshurl=nil)
        template = @interface.get("template:#{@interface.get('tag:template')}")
        template = @interface.get("template:status") if template.empty?
        fullname = File.join(@interface.get('path:templates'),template)
        @interface.set('log:templatename',template)
        @interface.set('log:templatefile',fullname)
        append_status(text)
        htmreply = ''
        if FileTest.file?(fullname) then
            begin
                htmreply = IO.read(fullname)
            rescue
                htmreply = ''
            end
        end
        if refresh>0 then
            if refreshurl then
                metadata = "<meta http-equiv='refresh' content='#{refresh};#{refreshurl}'>"
            else
                metadata = "<meta http-equiv='refresh' content='#{refresh}'>"
            end
        else
            metadata = ''
        end
        if ! htmreply || htmreply.empty? then
            # in head: <link rel='stylesheet' href='/exaresource/exastyle.css'>
            htmreply = <<-EOD
                <html>
                    #{metadata}
                    <head>
                        <title>#{title}</title>
                    </head>
                    <body>
                        <h2>#{title}</h2>
                        <h4>#{Time.now}</h4>
                        #{text}
                    </body>
                </html>
            EOD
        else
            if showtime then
                exa_template = "<h1>#{title}</h1>\n<h2>#{Time.now}</h2>\n#{text}\n"
            else
                exa_template = "<h1>#{title}</h1>#{text}\n"
            end
            htmreply = replace_template_placeholder(htmreply,exa_template,metadata)
        end
        htmreply
    end

    def message(title,str='',showtime=false,refresh=0,refreshurl=nil)
        if @cgi then
            @cgi.out("cookie"=>[@cgi_cookie]) do
                filled_template(title,str,showtime,refresh,refreshurl)
            end
        elsif @webrick_response then
            @webrick_response['content-type'] = 'text/html'
            @webrick_response.body = filled_template(title,str,showtime,refresh,refreshurl)
        else
            filled_template(title,str,showtime,refresh,refreshurl)
        end
    end

    def plaintext(str)
        if @cgi then
            @cgi.out('cookie'=>[@cgi_cookie],'content-type'=>'text/plain') do
                str
            end
        elsif @webrick_response then
            @webrick_response['content-type'] = 'text/plain'
            @webrick_response.body = str
        else
            str
        end
    end

    def exareply(status='',url='',size='',comment='')
        exaurl = @interface.get('process:exaurl')
        str  = "<?xml version='1.0'?>\n\n"
        str << "<exa:reply xmlns:exa='#{@@namespace}'>\n"
        str << "  <exa:session>#{@session_id}</exa:session>\n" unless @session_id.empty?
        str << "  <exa:status>#{status}</exa:status>\n"        unless (status || '').empty?
        str << "  <exa:url>#{exaurl}/#{url}</exa:url>\n"       unless (url    || '').empty?
        str << "  <exa:size>#{size}</exa:size>\n"              unless (size   || '').empty?
        str << "  <exa:comment>#{comment}</exa:comment>\n"     unless (comment|| '').empty?
        str << "</exa:reply>\n"
        return str
    end

    def append_status(str='')
        if @interface.true?('trace:errors') then
            if $! && $@ then
                str << "<br/><br/><br/><em>Error:</em><br/><pre>#{$!}</pre><pre>"
                str << $@.join("\n")
            end
            str << '<br/><br/><br/>'
            str << status_data
            str << '<em>Paths</em><br/>'
            str << '<pre>'
            @interface.subset('path:').each do |k,v|
                if FileTest.directory?(v) then
                    if FileTest.writable?(v) then
                        str << "#{v} exists and is writable\n"
                    else
                        str << "#{v} is not writable\n"
                    end
                else
                    str << "#{v} does not exist\n"
                end
            end
            str << '</pre>'
        end
        str
    end

    def simpleurl(url)
        if url then url.sub(/(:80|:443)$/,'') else '' end
    end

    def replace_exa_placeholders(data)
        data.gsub(/([\"\'])\@exa\_([a-zA-Z0-9\-\_]+)\1/) do
            quot, key, value = $1, $2, ''
            begin
                value = @variables.get(key)
            rescue
                value = ''
            end
            quot + value + quot
        end
    end

    def replace_url_placeholder(data)
        data.gsub!(/(http:\/\/|\/+)*\@exa\_main\_url/, @interface.get('process:exaurl'))
        replace_exa_placeholders(data)
    end

    def replace_template_placeholder(data,template='',metadata='')
        data.gsub!(/(http:\/\/|\/+)*\@exa\_main\_url/, @interface.get('process:exaurl'))
        data.gsub!(/\@exa\_template/, template)
        data.gsub!(/\@exa\_metadata/, metadata)
        replace_exa_placeholders(data)
    end

    def escaped(str)
        str
    end

end

# send files

class WWW

    def send_file(filename,parse=false) # this can take a lot of memory, look for alternative (fastcgi ?)
        begin
            if filename =~ /\.pdf$/ then
                mimetype, parse = 'application/pdf', false
            elsif filename =~ /\.(html|htm)$/ then
                mimetype, parse = 'text/html', true
            else
                mimetype, parse = 'text/plain', false
            end
            if FileTest.file?(filename) then
                if @webrick_response then
                    begin
                        @webrick_response['content-type'] = mimetype
                        @webrick_response['content-length'] = FileTest.size?(filename)
                        if parse then
                            File.open(filename, 'rb') do |f|
                                @webrick_response.body = replace_url_placeholder(f.read)
                            end
                        else
                            @webrick_response.body = File.open(filename, 'rb')
                        end
                    rescue
                    else
                        return
                    end
                elsif @cgi then
                    begin
                        # the following works ok, but stores the whole file in memory (see @cgi.out)
                        #
                        # File.open(filename, 'rb') do |f|
                            # @cgi.out('cookie'=>[@cgi_cookie],'connection'=>'close', 'length'=>File.size(filename), 'type'=>mimetype) do
                                # if parse then replace_url_placeholder(f.read) else f.read end
                            # end
                        # end
                        if parse then
                            File.open(filename, 'rb') do |f|
                                @cgi.out('cookie'=>[@cgi_cookie],'connection'=>'close', 'length'=>File.size(filename), 'type'=>mimetype) do
                                    replace_url_placeholder(f.read)
                                end
                            end
                        else
                            @cgi.print(@cgi.header('cookie'=>[@cgi_cookie],'connection'=>'close', 'length'=>File.size(filename), 'type'=>mimetype))
                            File.open(filename, 'rb') do |f|
                                while str = f.gets do
                                    @cgi.print(str)
                                end
                            end
                        end
                    rescue
                    else
                        return
                    end
                end
            end
        rescue
        end
        message('Error', "There is a problem with sending file #{File.basename(filename)}.")
    end

    def send_htmlfile(filename,parse=false)
        send_file(filename,parse)
    end
    def send_pdffile(filename) # this can take a lot of memory, look for alternative (fastcgi ?)
        send_file(filename,false)
    end

end

# tracing

class WWW

    def show_vars(a=@variables,title='')
        if a && a.length > 0 then
            if title.empty? then
                str = ''
            else
                str = "<em>#{title}</em>"
            end
            str << "<br/><pre>\n"
            a.keys.sort.each do |k|
                if k && a[k] && ! a[k].empty? then
                    if k == 'password' then
                        val = if a[k] == 'default' then 'default' else '******' end
                    else
                        # str << "#{k} => #{a[k].sub(/^\s+/moi,'').sub(/\s+$/moi,'')}\n"
                        val = a[k].to_s.strip
                        val.gsub!("&","&amp;")
                        val.gsub!("<","&lt;")
                        val.gsub!(">","&gt;")
                        val.gsub!("\n","\n    ")
                    end
                    str << "#{k} => #{val}\n"
                end
            end
            str << "</pre><br/>\n"
            return str
        else
            return ''
        end
    end

    def status_data
        show_vars(@session  , 'Session'    ) +
        show_vars(@variables, 'Variables'  ) +
        show_vars(@interface, 'Interface'  ) +
        show_vars(ENV       , 'Environment')
    end

    def report_status
        check_template_file('status')
        message('Status',status_data)
    end

end

# attachments

class WWW

    def extract_sent_files(dir)
        files = Array.new
        if @cgi then
            @cgi.params.keys.each do |tag|
                begin
                    if filename = @cgi[tag].original_filename then
                        files << extract_file_content(dir,filename,@cgi[tag]) unless filename.empty?
                    end
                rescue
                end
            end
        elsif @webrick_request then
            @webrick_request.query.keys.each do |tag|
                begin
                    if filename = @webrick_request.query[tag].filename then
                        files << extract_file_content(dir,filename,@webrick_request.query[tag]) unless filename.empty?
                    end
                rescue
                end
            end
        end
        @interface.set('log:attachments', files.compact.uniq.join('|'))
    end

    def extract_file_content(dir,filename,data)
        filename = File.join(dir,File.basename(filename))
        begin
            @interface.set('log:attachclass', data.class.inspect)
            if data.class == Tempfile then
                begin
                    File.copy(data.path,filename)
                rescue
                    begin
                        File.open(filename,'wb') do |f|
                            File.open(data.path,'rb') do |g|
                                while str = g.gets do
                                    f.write(str)
                                end
                            end
                        end
                    rescue
                        @interface.set('log:attachstate', "saving tempfile #{filename} failed (#{$!})")
                    else
                        @interface.set('log:attachstate', "tempfile #{filename} has been saved")
                    end
                else
                    @interface.set('log:attachstate', "#{data.path} copied to #{filename}")
                end
            elsif data.class == String then
                begin
                    File.open(filename,'wb') do |f|
                        f.write(data)
                    end
                rescue
                    @interface.set('log:attachstate', "saving string #{filename} failed (#{$!})")
                else
                    @interface.set('log:attachstate', "string #{filename} has been saved")
                end
            elsif data.class == StringIO then
                begin
                    File.open(filename,'wb') do |f|
                        f.write(data.read)
                    end
                rescue
                    @interface.set('log:attachstate', "saving stringio #{filename} failed (#{$!})")
                else
                    @interface.set('log:attachstate', "stringio #{filename} has been saved")
                end
            else
                @interface.set('log:attachstate', "unknown attachment class #{data.class.to_s}")
            end
        rescue
            begin File.delete(filename) ; rescue ; end
        else
            begin File.delete(filename) if FileTest.size(filename) == 0 ; rescue ; end
        end
        return File.basename(filename)
    end

end

# configuration

class WWW

    def interface_base_name(str)
        str.sub(/\.(pdf|htm|html)$/, '')
    end

    def located_interface_file(filename)
        ['configurations', 'runners', 'scripts'].each do |tag|
            datafile = File.join(@interface.get("path:#{tag}"),filename)
            if FileTest.file?(datafile+'.encrypted') then
                return datafile + '.encrypted'
            elsif FileTest.file?(datafile) then
                return datafile
            end
        end
        return nil
    end

    def load_interface_file(filename=@@data_file)
        reset_session() # no save yet
        if datafile = located_interface_file(filename) then
            nestedfiles = Array.new
            begin
                data = IO.read(datafile) || ''
                unless data.empty? then
                    loop do # we need to load them recursively
                        done = false
                        data.gsub!(/^include\s*:\s*(.*?)\s*$/) do
                            includedname, done = $1, true
                            if nestedname = located_interface_file(includedname) then
                                begin
                                    str = ("\n" + IO.read(nestedname) + "\n") || ''
                                rescue
                                    nestedfiles << File.basename('-'+includedname)
                                    ''
                                else
                                    nestedfiles << File.basename('+'+includedname)
                                    str
                                end
                            else
                                nestedfiles << File.basename('-'+includedname)
                                ''
                            end
                        end
                        break unless done
                    end
                end
                @interface.set('log:configurationfile', datafile + ' [' + nestedfiles.join(' ') + ']')
                return data
            rescue
            end
        end
        @interface.set('log:configurationfile', filename + ' [not loaded]')
        return nil
    end

    def fetch_session_interface_variables(data)
        data.scan(/^variable\s*:\s*(.*?)\s*\=\s*(.*?)\s*$/) do
            @interface.set($1, $2)
        end
        return true
    end

    def fetch_session_project_list(data)
        projectlist, permitted = Array.new, false
        data.scan(/^user\s*:\s*(.*?)\s*\,\s*(.*?)\s*\=\s*(.*?)\s*\,\s*(.*?)\s*$/) do
            domain, username, password, projects = $1, $2, $3, $4
            if @session.match?('domain',domain) && @session.match?('username',username) then
                if same_passwords(password) then
                    projectlist, permitted = @interface.resolved(projects).split(@@re_bar), true
                    break
                end
            end
        end
        if permitted then
            @interface.set('log:projectlist', '['+projectlist.join(' ')+']')
            if projectlist.length == 0 then
                return nil
            else
                return projectlist
            end
        else
            @interface.set('log:projectlist', '[no projects]')
            return nil
        end
    end

    def fetch_session_command(data)
        data.scan(/^process\s*:\s*(.*?)\s*\,\s*(.*?)\s*\=\s*(.*?)\s*$/) do
            domain, process, command = $1, $2, $3
            if @session.match?('domain',domain) && @session.match?('process',process) then
                @session.set('command', @interface.resolved(command))
            end
        end
        return @session.get('command')
    end

    def fetch_session_settings(data)
        data.scan(/^setting\s*:\s*(.*?)\s*\,\s*(.*?)\s*\,\s*(.*?)\s*\=\s*(.*?)\s*$/) do
            domain, process, variable, value = $1, $2, $3, $4
            if @session.match?('domain',domain) && @session.match?('process',process) then
                @interface.set(variable,value)
            end
        end
    end

    def get_command(action)
        # @session.set('action', action)
        # if @session.get('process') == 'none' then
            # @interface.set('log:child','yes')
            # @session.set('process', action)
        # end
        if data = load_interface_file() then
            fetch_session_interface_variables(data)
            if projectlist = fetch_session_project_list(data) then
                data.scan(/^project\s*:\s*(.*?)\s*\,\s*(.*?)\s*\=\s*(.*?)\s*,\s*(.*?)\s*,\s*(.*?)\s*$/) do
                    domain, project, gui, path, process = $1, $2, $3, $4, $5
                    if @session.match?('domain',domain) then
                        if @session.match?('project',project) then
                            if projectlist.include?(project) then
                                @session.set('process', @interface.resolved(process))
                                # break # no, else we end up in the parent (e.g. examplap instead of impose)
                            end
                        elsif ! action.empty? && project == action then
                            if projectlist.include?(action) then
                                @session.set('process', @interface.resolved(process))
                                # break # no, else we end up in the parent (e.g. examplap instead of impose)
                            end
                        end
                    end
                end
                fetch_session_command(data)
                fetch_session_settings(data)
            end
        end
        return ! @session.nothing?('command')
    end

    def get_file(filename)
        @session.set('filename', filename)
        if data = load_interface_file() then
            fetch_session_interface_variables(data)
            if projectlist = fetch_session_project_list(data) then
                data.scan(/^project\s*:\s*(.*?)\s*\,\s*(.*?)\s*\=\s*(.*?)\s*,\s*(.*?)\s*,\s*(.*?)\s*$/) do
                    domain, project, gui, path, process = $1, $2, $3, $4, $5
                    if @session.match?('domain',domain) then
                        guilist = @interface.resolved(gui).split(@@re_bar)
                        guilist.each do |g|
                            if /#{filename}$/ =~ g then
                                @session.set('gui',     File.expand_path(@interface.resolved(g)))
                                @session.set('path',    File.expand_path(@interface.resolved(path)))
                                @session.set('process', process)
                                break # take first matching interface
                            end
                        end
                    end
                end
            end
        end
        return ! (@session.nothing?('gui') && @session.nothing?('path') && @session.nothing?('process'))
    end

    def get_path(url='')
        if data = load_interface_file() then
            fetch_session_interface_variables(data)
            if projectlist = fetch_session_project_list(data) then
                data.scan(/^project\s*:\s*(.*?)\s*\,\s*(.*?)\s*\=\s*(.*?)\s*,\s*(.*?)\s*,\s*(.*?)\s*$/) do
                    domain, project, gui, path, process = $1, $2, $3, $4, $5
                    if @session.match?('domain',domain) && @session.match?('project',project) then
                        @session.set('url',     url)
                        @session.set('gui',     '')
                        @session.set('path',    File.expand_path(@interface.resolved(path)))
                        @session.set('process', '')
                    end
                end
            end
        end
        return ! @session.nothing?('path')
    end

    def get_gui()
        if data = load_interface_file() then
            fetch_session_interface_variables(data)
            if projectlist = fetch_session_project_list(data) then
                data.scan(/^project\s*:\s*(.*?)\s*\,\s*(.*?)\s*\=\s*(.*?)\s*,\s*(.*?)\s*,\s*(.*?)\s*$/) do
                    domain, project, gui, path, process = $1, $2, $3, $4, $5
                    if @session.match?('domain',domain) && @session.match?('project',project) && projectlist.include?(project) then
                        @session.set('gui',     File.expand_path(@interface.resolved(gui)))
                        @session.set('path',    File.expand_path(@interface.resolved(path)))
                        @session.set('process', process) unless process == 'none'
                        break # take first matching interface
                    end
                end
                data.scan(/^admin\s*:\s*(.*?)\s*\,\s*(.*?)\s*\=\s*(.*?)\s*\,\s*(.*?)\s*$/) do
                    domain, project, task, option = $1, $2, $3, $4
                    if @session.match?('domain',domain) && @session.match?('project',project) && projectlist.include?(project) then
                        @session.set('task', task)
                        @session.set('option', option)
                        break # take first matching task
                    end
                end
            end
        end
        return ! (@session.nothing?('gui') && @session.nothing?('path') && @session.nothing?('process'))
    end

end

class WWW

    def send_reply(logdata='')
        if @interface.true?('trace:run') then
            send_result(logdata)
        else
            dir, tmp = dirname, tmp_path(dirname)
            case @session.get('status')
                when 'running: finished' then
                    resultname, replyname = 'result.pdf', 'reply.exa'
                    replyfile = File.join(tmp,replyname)
                    if FileTest.file?(replyfile) then
                        begin
                            data = IO.read(replyfile)
                            resultname = if data =~ /<exa:output>(.*?)<\/exa:output>/ then $1 else resultname end
                        rescue
                            plaintext(exareply('error in reply'))
                            return
                        end
                    end
                    resultfile = File.join(tmp,resultname)
                    if FileTest.file?(resultfile) then
                        if indirect?(resultfile) then
                            begin
                                File.makedirs(File.join(cache_root,dir))
                                FileUtils::mv(resultfile,File.join(cache_root,dir,resultname))
                            rescue
                                plaintext(exareply('unable to access cache'))
                            else
                                plaintext(exareply('big file', "cache/#{dir}/#{resultname}", "#{File.size?(resultfile)}"))
                            end
                        else
                            send_file(resultfile)
                        end
                    else
                        plaintext(exareply('no result'))
                    end
                else # background, running, aborted
                    plaintext(exareply(@session.get('status')))
            end
        end
    end

    def send_url(fullname)
        dir, tmp = dirname, tmp_path(dirname)
        resultname, replyname = 'result.pdf', 'reply.exa'
        replyfile = File.join(tmp,replyname)
        resultfile = File.join(tmp,resultname)
        targetname = File.join(cache_root,dir,resultname)
        # make sure that there is no target left in case of an
        # error; needed in case of given session name
        if FileTest.directory?(File.join(cache_root,dir)) then
            File.delete(targetname) rescue false
        end
        # now try to locate the file
        if FileTest.file?(fullname) then
            if indirect?(fullname) then
                begin
                    # check if directory exists and (if so) delete left overs
                    File.makedirs(File.join(cache_root,dir))
                    File.delete(targetname) rescue false
                    File.symlink(fullname,targetname) rescue message('Status',$!)
                    unless FileTest.file?(targetname) then
                        FileUtils::cp(fullname,targetname) rescue false
                    end
                rescue
                    plaintext(exareply('unable to access cache'))
                else
                    plaintext(exareply('big file', "cache/#{dir}/#{resultname}", "#{File.size?(fullname)}"))
                end
            else
                send_file(fullname)
            end
        else
            message('Status', 'The file is not found')
        end
    end

    def send_result(logdata='')
        check_template_file('exalogin','exalogin-template.htm')
        dir, tmp = dirname, tmp_path(dirname)
        resultname, replyname, logname = 'result.pdf', 'reply.exa', 'log.htm'
        case @session.get('status')
            when 'running: background' then
                if st = @session.get('starttime') then # fuzzy
                    st = Time.now.to_i if st.empty?
                    if (Time.now.to_i - st.to_i) > @interface.get('process:timeout').to_i then
                        message('Status', 'Your request has been aborted (timeout)',true)
                    else
                        message('Status', 'Your request is queued',true,5,'exastatus')
                    end
                end
            when 'running: busy' then
                if st = @session.get('starttime') then # fuzzy
                    st = Time.now.to_i if st.empty?
                    if (Time.now.to_i - st.to_i) > @interface.get('process:timeout').to_i then
                        message('Status', 'Your request has been aborted (timeout)',true)
                    else
                        message('Status', 'Your request is being processed',true,5,'exastatus')
                    end
                end
            when 'running: aborted' then
                message('Status', 'Your request has been aborted (timeout)',true)
            when 'running: finished' then
                if @interface.true?('trace:run') then
                    logfile = File.join(tmp,logname)
                    begin
                        if f = File.open(logname,'w') then
                            if logdata.empty? then
                                begin
                                    logdata = IO.read('www-watch.out')
                                rescue
                                    logdata = 'no log data'
                                end
                            end
                            f << filled_template('Log',"<pre>#{CGI::escapeHTML(logdata)}</pre>")
                            f.close
                        end
                    rescue
                        message('Error', '')
                    end
                    if FileTest.file?(logfile) then
                        begin
                            File.makedirs(File.join(cache_root,dir))
                            FileUtils::mv(logfile,File.join(cache_root,dir,logname))
                        rescue
                            logdata = "<br/><br/>unable to access cache</a>"
                        else
                            logdata = "<br/><br/><a href='/cache/#{dir}/#{logname}'>#{logname}</a>"
                        end
                    else
                        logdata = ''
                    end
                else
                    logdata = ''
                end
                # todo: generate reply.exa if no reply
                replyfile = File.join(tmp,replyname)
                if FileTest.file?(replyfile) then
                    begin
                        data = IO.read(replyfile)
                        resultname = if data =~ /<exa:output>(.*?)<\/exa:output>/ then $1 else resultname end
                    rescue
                        message('Error','There is a problem in handling this request (invalid reply).')
                        return
                    end
                end
                resultfile = File.join(tmp,resultname)
                if FileTest.file?(resultfile) then
                    if indirect?(resultfile) then
                        begin
                            File.makedirs(File.join(cache_root,dir))
                            FileUtils::mv(resultfile,File.join(cache_root,dir,resultname))
                        rescue
                            str = "<br/><br/>unable to access cache</a>"
                        else
                            str = "<br/><br/><a href='/cache/#{dir}/#{resultname}'>#{resultname}</a>&nbsp;&nbsp;(#{File.size?(resultname)} bytes)"
                        end
                        message('Result', 'You can pick up the result here:' + str + logdata)
                    else
                        send_file(resultfile)
                    end
                else
                    message('Error', 'There is a problem in handling this request (no result file).' + logdata)
                end
        end
    end

end

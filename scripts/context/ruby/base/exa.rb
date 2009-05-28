# \setuplayout[width=3cm]
#
# tex.setup.setuplayout.width.[integer|real|dimension|string|key]
# tex.[mp]var.whatever.width.[integer|real|dimension|string|key]

require 'fileutils'
# require 'ftools'
require 'digest/md5'

# this can become a lua thing

# no .*? but 0-9a-z\:\. because other too slow (and greedy)

class Hash

    def subset(pattern)
        h = Hash.new
        r = /^#{pattern.gsub('.','\.')}/
        self.keys.each do |k|
            h[k] = self[k].dup if k =~ r
        end
        return h
    end

end

module ExaEncrypt

    def ExaEncrypt.encrypt_base(logger, oldfilename, newfilename)
        if FileTest.file?(oldfilename) then
            logger.report("checking #{oldfilename}") if logger
            if data = IO.read(oldfilename) then
                done = false
                # cfg file:
                #
                # banner : exa configuration file
                # user   : domain, name = password, projectlist
                #
                if data =~ /^\s*banner\s*\:\s*exa\s*configuration\s*file/ then
                    data.gsub!(/^(\s*user\s*\:\s*.+?\s*\,\s*.+?\s*\=\s*)(.+?)(\s*\,\s*.+\s*)$/) do
                        pre, password, post = $1, $2, $3
                        unless password =~ /MD5:/i then
                            done = true
                            password = "MD5:" + Digest::MD5.hexdigest(password).upcase
                        end
                        "#{pre}#{password}#{post}"
                    end
                else
                    data.gsub!(/<exa:password([^>]*?)>(.*?)<\/exa:password>/moi) do
                        attributes, password = $1, $2
                        unless password =~ /^([0-9A-F][0-9A-F])+$/ then
                            done = true
                            password = Digest::MD5.hexdigest(password).upcase
                            attributes = " encryption='md5'#{attributes}"
                        end
                        "<exa:password#{attributes}>#{password}</exa:password>"
                    end
                end
                begin
                    File.open(newfilename,'w') do |f|
                        f.puts(data)
                    end
                rescue
                    logger.report("#{newfilename} cannot be written") if logger
                else
                    logger.report("#{oldfilename} encrypted into #{newfilename}") if done and logger
                end
            end
        end
    end

end

module ExaModes

    @@modefile = 'examodes.tex'

    @@request = /(<exa:request.*?)(>.*?<\/exa:request>)/mo
    @@redone  = /<exa:request[^>]*?texified=([\'\"])yes\1.*?>/mo
    @@reload  = /<(exa:variable)([^>]+?label\=)([\"\'])([0-9A-Za-z\-\.\:]+?)(\3[^\/]*?)>(.*?)<(\/exa:variable)>/mo
    @@recalc  = /<(exa:variable)([^>]+?label\=)([\"\'])([0-9A-Za-z\-\.\:]+?)([\.\:]calcmath)(\3[^\/]*?)>(.*?)<(\/exa:variable)>/mo
    @@rename  = /<(exa:variable)([^>]+?label\=)([\"\'])([0-9A-Za-z\-\.\:]+?)(\3[^\/]*?)>(.*?)<(\/exa:variable)>/mo
    @@refile  = /<(exa:filename|exa:filelist)>(.*?)<(\/\1)>/mo

    def ExaModes.cleanup_request(logger,filename='request.exa',modefile=@@modefile)
        begin File.delete(filename+'.raw') ; rescue ; end
        begin File.delete(modefile)        ; rescue ; end
        if FileTest.file?(filename) then
            data, done = nil, false
            begin
                data = IO.read(filename)
            rescue
                data = nil
            end
            if data =~ @@request and data !~ @@redone then
                data.gsub!(@@rename) do
                    done = true
                    '<' + $1 + $2 + $3 + $4 + $5 + '>' +
                    texifiedstr($4,$6) +
                    '<' + $7 + '>'
                end
                data.gsub!(@@refile) do
                    done = true
                    '<' + $1 + '>' +
                    cleanpath($2) +
                    '<' + $3 + '>'
                end
                data.gsub!(@@recalc) do
                    done = true
                    '<' + $1 + $2 + $3 + $4 + ":raw" + $6 + '>' + $7 + '<' + $8 + '>' +
                    '<' + $1 + $2 + $3 + $4 + $6 + '>' +
                    calculatortexmath($7,false) +
                    '<' + $8 + '>'
                end
                if done then
                    data.gsub!(@@request) do
                        $1 + " texified='yes'" + $2
                    end
                    begin File.copy(filename, filename+'.raw') ; rescue ; end
                    begin
                        logger.report("rewriting #{filename}") if logger
                        File.open(filename,'w') do |f|
                            f.puts(data)
                        end
                    rescue
                        logger.report("#{filename} cannot be rewritten") if logger
                    end
                end
            else
                logger.report("#{filename} is already ok") if logger
            end
            @variables = Hash.new
            data.scan(@@reload) do
                @variables[$4] = $5
            end
            vars   = @variables.subset('data.tex.var')
            mpvars = @variables.subset('data.tex.mpvar')
            modes  = @variables.subset('data.tex.mode')
            setups = @variables.subset('data.tex.setup')
            if not (modes.empty? and setups.empty? and vars.empty? and mpvars.empty?) then
                begin
                    File.open(modefile,'w') do |mod|
                        logger.report("saving modes and setups in #{modefile}") if logger
                        if not modes.empty? then
                            for key in modes.keys do
                                k = key.dup
                                k.gsub!(/\./,'-')
                                mod.puts("\\enablemode[#{k}-#{modes[key]}]\n")
                                if modes[key] =~ /(on|yes|start)/o then # ! ! ! ! !
                                    mod.puts("\\enablemode[#{k}]\n")
                                end
                            end
                            mod.puts("\n\\readfile{cont-mod}{}{}\n")
                        end
                        if not setups.empty? then
                            for key in setups.keys
                                if key =~ /^(.+?)\.(.+?)\.(.+?)$/o then
                                    command, key, type, value = $1, $2, $3, setups[key]
                                    value = cleanedup(key,type,value)
                                    mod.puts("\\#{$1}[#{key}=#{value}]\n")
                                elsif key =~ /^(.+?)\.(.+?)$/o then
                                    command, type, value = $1, $2, setups[key]
                                    mod.puts("\\#{$1}[#{value}]\n")
                                end
                            end
                        end
                        savevaroptions(vars,  'setvariables',  mod)
                        savevaroptions(mpvars,'setMPvariables',mod)
                    end
                rescue
                    logger.report("#{modefile} cannot be saved") if logger
                end
            else
                logger.report("#{modefile} is not created") if logger
            end
        end
    end

    private

    def ExaModes.autoparenthesis(str)
        if str =~ /[\+\-]/o then '[1]' + str + '[1]' else str end
    end

    def ExaModes.cleanedup(key,type,value)
        if type == 'dimension' then
            unless value =~ /(cm|mm|in|bp|sp|pt|dd|em|ex)/o
                value + 'pt'
            else
                value
            end
        elsif type == 'calcmath' then
            '{' + calculatortexmath(value,true) + '}'
        elsif type =~ /^filename|filelist$/ or key =~ /^filename|filelist$/ then
            cleanpath(value)
        else
            value
        end
    end

    def ExaModes.cleanpath(str)
        (str ||'').gsub(/\\/o,'/')
    end

    def ExaModes.texifiedstr(key,val)
        case key
            when 'filename' then
                cleanpath(val)
            when 'filelist' then
                cleanpath(val)
            else
                val
        end
    end

    def ExaModes.savevaroptions(vars,setvariables,mod)
        if not vars.empty? then
            for key in vars.keys do
                # var.whatever.width.dimension.value
                if key =~ /^(.+?)\.(.+?)\.(.+?)$/o then
                    tag, key, type, value = $1, $2, $3, vars[key]
                    value = cleanedup(key,type,value)
                    mod.puts("\\#{setvariables}[#{tag}][#{key}=#{value}]\n")
                elsif key =~ /^(.+?)\.(.+?)$/o then
                    tag, key, value = $1, $2, vars[key]
                    mod.puts("\\#{setvariables}[#{tag}][#{key}=#{value}]\n")
                end
            end
        end
    end

    def ExaModes.calculatortexmath(str,tx=true)
        if tx then
            bdisp, edisp = "\\displaymath\{", "\}"
            binln, einln = "\\inlinemath\{" , "\}"
            egraf        = "\\endgraf"
        else
            bdisp, edisp = "<displaytexmath>", "</displaytexmath>"
            binln, einln = "<inlinetexmath>" , "</inlinetexmath>"
            egraf        = "<p/>"
        end
        str.gsub!(/\n\s*\n+/moi, "\\ENDGRAF ")
        str.gsub!(/(\[\[)\s*(.*?)\s*(\]\])/mos) do
            $1 + docalculatortexmath($2) + $3
        end
        str.gsub!(/(\\ENDGRAF)+\s*(\[\[)\s*(.*?)\s*(\]\])/moi) do
            $1 + bdisp + $3 + edisp
        end
        str.gsub!(/(\[\[)\s*(.*?)\s*(\]\])/o) do
            binln + $2 + einln
        end
        str.gsub!(/\\ENDGRAF/mos, egraf)
        str
    end

    def ExaModes.docalculatortexmath(str)
        str.gsub!(/\n/o) { ' ' }
        str.gsub!(/\s+/o) { ' ' }
        str.gsub!(/&gt;/o) { '>' }
        str.gsub!(/&lt;/o) { '<' }
        str.gsub!(/&.*?;/o) { }
        level = 0
        str.gsub!(/([\(\)])/o) do |chr|
            if    chr == '(' then
                level = level + 1
                chr = '[' + level.to_s + ']'
            elsif chr == ')' then
                chr = '[' + level.to_s + ']'
                level = level - 1
            end
            chr
        end
        # ...E...
        loop do
            break unless str.gsub!(/([\d\.]+)E([\-\+]{0,1}[\d\.]+)/o) do
                "\{\\SCINOT\{#{$1}\}\{#{$2}\}\}"
            end
        end
        # ^-..
        loop do
            break unless str.gsub!(/\^([\-\+]*\d+)/o) do
                "\^\{#{$1}\}"
            end
        end
        # ^(...)
        loop do
            break unless str.gsub!(/\^(\[\d+\])(.*?)\1/o) do
                "\^\{#{$2}\}"
            end
        end
        # 1/x^2
        loop do
            break unless str.gsub!(/([\d\w\.]+)\/([\d\w\.]+)\^([\d\w\.]+)/o) do
                "@\{#{$1}\}\{#{$2}\^\{#{$3}\}\}"
            end
        end
        # int(a,b,c)
        loop do
            break unless str.gsub!(/(int|sum|prod)(\[\d+\])(.*?),(.*?),(.*?)\2/o) do
                "\\#{$1.upcase}\^\{#{$4}\}\_\{#{$5}\}\{#{autoparenthesis($3)}\}"
            end
        end
        # int(a,b)
        loop do
            break unless str.gsub!(/(int|sum|prod)(\[\d+\])(.*?),(.*?)\2/o) do
                "\\#{$1.upcase}\_\{#{$4}\}\{#{autoparenthesis($3)}\}"
            end
        end
        # int(a)
        loop do
            break unless str.gsub!(/(int|sum|prod)(\[\d+\])(.*?)\2/o) do
                "\\#{$1.upcase}\{#{autoparenthesis($3)}\}"
            end
        end
        # sin(x) => {\sin(x)}
        loop do
            break unless str.gsub!(/(median|min|max|round|sqrt|sin|cos|tan|sinh|cosh|tanh|ln|log)\s*(\[\d+\])(.*?)\2/o) do
                "\{\\#{$1.upcase}\{#{$2}#{$3}#{$2}\}\}"
            end
        end
        # mean
        str.gsub!(/(mean)(\[\d+\])(.*?)\2/o) do
            "\{\\OVERLINE\{#{$3}\}\}"
        end
        # sin x  => {\sin(x)}
        # ...
        # (1+x)/(1+x) => \frac{1+x}{1+x}
        loop do
            break unless str.gsub!(/(\[\d+\])(.*?)\1\/(\[\d+\])(.*?)\3/o) do
                "@\{#{$2}\}\{#{$4}\}"
            end
        end
        # (1+x)/x => \frac{1+x}{x}
        loop do
            break unless str.gsub!(/(\[\d+\])(.*?)\1\/([a-zA-Z0-9]+)/o) do
                "@\{#{$2}\}\{#{$3}\}"
            end
        end
        # 1/(1+x) => \frac{1}{1+x}
        loop do
            break unless str.gsub!(/([a-zA-Z0-9]+)\/(\[\d+\])(.*?)\2/o) do
                "@\{#{$1}\}\{#{$3}\}"
            end
        end
        # 1/x => \frac{1}{x}
        loop do
            break unless str.gsub!(/([a-zA-Z0-9]+)\/([a-zA-Z0-9]+)/o) do
                "@\{#{$1}\}\{#{$2}\}"
            end
        end
        #
        str.gsub!(/\@/o) do
            "\\FRAC "
        end
        str.gsub!(/\*/o) do
            " "
        end
        str.gsub!(/\<\=/o) do
            "\\LE "
        end
        str.gsub!(/\>\=/o) do
            "\\GE "
        end
        str.gsub!(/\=/o) do
            "\\EQ "
        end
        str.gsub!(/\</o) do
            "\\LT "
        end
        str.gsub!(/\>/) do
            "\\GT "
        end
        str.gsub!(/(D)(\[\d+\])(.*?)\2/o) do
            "\{\\FRAC\{\\MBOX{d}\}\{\\MBOX{d}x\}\{#{$2}#{$3}#{$2}\}\}"
        end
        str.gsub!(/(exp)(\[\d+\])(.*?)\2/o) do
            "\{e^\{#{$3}\}\}"
        end
        str.gsub!(/(abs)(\[\d+\])(.*?)\2/o) do
            "\{\\left\|#{$3}\\right\|\}"
        end
        str.gsub!(/D([x|y])/o) do
            "\\FRAC\{\{\\rm d\}#{$1}\}\{\{\\rm d\}x\}"
        end
        str.gsub!(/D([f|g])(\[\d+\])(.*?)\2/o) do
            "\{\\rm #{$1}\}'#{$2}#{$3}#{$2}"
        end
        str.gsub!(/([f|g])(\[\d+\])(.*?)\2/o) do
            "\{\\rm #{$1}\}#{$2}#{$3}#{$2}"
        end
        str.gsub!(/(pi|inf)/io) do
            "\\#{$1} "
        end
        loop do
            break unless str.gsub!(/(\[\d+?\])(.*?)\1/o) do
                "\\left(#{$2}\\right)"
            end
        end
        str.gsub!(/\\([A-Z]+?)([\s\{\^\_\\])/io) do
            "\\#{$1.downcase}#{$2}"
        end
        str
    end

end

# ExaModes.cleanup_request()

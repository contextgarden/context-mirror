require 'base/kpsefast'

module KpseRunner

    @@kpse = nil

    def KpseRunner.kpsewhich(arg='')
        options, arguments = split_args(arg)
        unless @@kpse then
            if ENV['KPSEMETHOD'] && ENV['KPSEPORT'] then
                require 'base/kpseremote'
                @@kpse = KpseRemote.new
            else
                @@kpse = nil
            end
            if @@kpse && @@kpse.okay? then
                @@kpse.progname = options['progname'] || ''
                @@kpse.engine   = options['engine']   || ''
                @@kpse.format   = options['format']   || ''
            else
                require 'base/kpsefast'
                @@kpse = KpseFast.new
                @@kpse.load_cnf
                @@kpse.progname = options['progname'] || ''
                @@kpse.engine   = options['engine']   || ''
                @@kpse.format   = options['format']   || ''
                @@kpse.expand_variables
                @@kpse.load_lsr
            end
        else
            @@kpse.progname = options['progname'] || ''
            @@kpse.engine   = options['engine']   || ''
            @@kpse.format   = options['format']   || ''
            @@kpse.expand_variables
        end
        if    option = options['expand-braces'] and not option.empty? then
            @@kpse.expand_braces(option)
        elsif option = options['expand-path']   and not option.empty? then
            @@kpse.expand_path(option)
        elsif option = options['expand-var']    and not option.empty? then
            @@kpse.expand_var(option)
        elsif option = options['show-path']     and not option.empty? then
            @@kpse.show_path(option)
        elsif option = options['var-value']     and not option.empty? then
            @@kpse.expand_var(option)
        elsif arguments.size > 0 then
            files = Array.new
            arguments.each do |option|
                if file = @@kpse.find_file(option) and not file.empty? then
                    files << file
                end
            end
            files.join("\n")
        else
            ''
        end
    end

    def KpseRunner.kpsereset
        @@kpse = nil
    end

    private

    def KpseRunner.split_args(arg)
        vars, args = Hash.new, Array.new
        arg.gsub!(/([\"\'])(.*?)\1/o) do
            $2.gsub(' ','<space/>')
        end
        arg = arg.split(/\s+/o)
        arg.collect! do |a|
            a.gsub('<space/>',' ')
        end
        arg.each do |a|
            if a =~ /^(.*?)\=(.*?)$/o then
                k, v = $1, $2
                vars[k.sub(/^\-+/,'')] = v
            else
                args << a
            end
        end
        # puts vars.inspect
        # puts args.inspect
        return vars, args
    end

end

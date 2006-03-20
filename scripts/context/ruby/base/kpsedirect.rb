class KpseDirect

    attr_accessor :progname, :format, :engine

    def initialize
        @progname = ''
        @format = ''
        @engine = ''
    end

    def expand_path(str)
        `kpsewhich -expand-path=#{str}`.chomp
    end

    def expand_var(str)
        `kpsewhich -expand-var=#{str}`.chomp
    end

    def find_file(str)
        `kpsewhich #{_progname_} #{_format_} #{str}`.chomp
    end

    def _progname_
        if @progname.empty? then '' else "-progname=#{@progname}" end
    end
    def _format_
        if @format.empty?   then '' else "-format=\"#{@format}\"" end
    end

end

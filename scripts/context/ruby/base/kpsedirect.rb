class KpseDirect

    attr_accessor :progname, :format, :engine

    def initialize
        @progname, @format, @engine = '', '', ''
    end

    def expand_path(str)
        clean_name(`kpsewhich -expand-path=#{str}`.chomp)
    end

    def expand_var(str)
        clean_name(`kpsewhich -expand-var=#{str}`.chomp)
    end

    def find_file(str)
        clean_name(`kpsewhich #{_progname_} #{_format_} #{str}`.chomp)
    end

    def _progname_
        if @progname.empty? then '' else "-progname=#{@progname}" end
    end
    def _format_
        if @format.empty?   then '' else "-format=\"#{@format}\"" end
    end

    private

    def clean_name(str)
        str.gsub(/\\/,'/')
    end

end

require 'base/kpsefast'

case ENV['KPSEMETHOD']
    when /soap/o then require 'base/kpse/soap'
    when /drb/o  then require 'base/kpse/drb'
    else              require 'base/kpse/drb'
end

class KpseRemote

    @@port   = ENV['KPSEPORT']   || 7000
    @@method = ENV['KPSEMETHOD'] || 'drb'

    def KpseRemote::available?
        @@method && @@port
    end

    def KpseRemote::start_server(port=nil)
        kpse = KpseServer.new(port || @@port)
        kpse.start
    end

    def KpseRemote::start_client(port=nil) # keeps object in server
        kpseclient = KpseClient.new(port || @@port)
        kpseclient.start
        kpse = kpseclient.object
        tree = kpse.choose(KpseUtil::identify, KpseUtil::environment)
        [kpse, tree]
    end

    def KpseRemote::fetch(port=nil) # no need for defining methods but slower, send whole object
        kpseclient = KpseClient.new(port || @@port)
        kpseclient.start
        kpseclient.object.fetch(KpseUtil::identify, KpseUtil::environment) rescue nil
    end

    def initialize(port=nil)
        if KpseRemote::available? then
            begin
                @kpse, @tree = KpseRemote::start_client(port)
            rescue
                @kpse, @tree = nil, nil
            end
        else
            @kpse, @tree = nil, nil
        end
    end

    def progname=(value)
        @kpse.set(@tree,'progname',value)
    end
    def format=(value)
        @kpse.set(@tree,'format',value)
    end
    def engine=(value)
        @kpse.set(@tree,'engine',value)
    end

    def progname
        @kpse.get(@tree,'progname')
    end
    def format
        @kpse.get(@tree,'format')
    end
    def engine
        @kpse.get(@tree,'engine')
    end

    def load
        @kpse.load(KpseUtil::identify, KpseUtil::environment)
    end
    def okay?
        @kpse && @tree
    end
    def set(key,value)
        @kpse.set(@tree,key,value)
    end
    def load_cnf
        @kpse.load_cnf(@tree)
    end
    def load_lsr
        @kpse.load_lsr(@tree)
    end
    def expand_variables
        @kpse.expand_variables(@tree)
    end
    def expand_braces(str)
        clean_name(@kpse.expand_braces(@tree,str))
    end
    def expand_path(str)
        clean_name(@kpse.expand_path(@tree,str))
    end
    def expand_var(str)
        clean_name(@kpse.expand_var(@tree,str))
    end
    def show_path(str)
        clean_name(@kpse.show_path(@tree,str))
    end
    def var_value(str)
        clean_name(@kpse.var_value(@tree,str))
    end
    def find_file(filename)
        clean_name(@kpse.find_file(@tree,filename))
    end
    def find_files(filename,first=false)
        # dodo: each filename
        @kpse.find_files(@tree,filename,first)
    end

    private

    def clean_name(str)
        str.gsub(/\\/,'/')
    end

end

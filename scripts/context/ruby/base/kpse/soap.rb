require 'soap/rpc/standaloneServer'
require 'soap/rpc/driver'

require 'base/kpse/trees'

class KpseService < SOAP::RPC::StandaloneServer

    def on_init
        kpse = KpseTrees.new
        add_method(kpse, 'choose', 'files', 'environment')
        add_method(kpse, 'load', 'files', 'environment')
        add_method(kpse, 'expand_variables', 'tree')
        add_method(kpse, 'expand_braces', 'tree', 'str')
        add_method(kpse, 'expand_path', 'tree', 'str')
        add_method(kpse, 'expand_var', 'tree', 'str')
        add_method(kpse, 'show_path', 'tree', 'str')
        add_method(kpse, 'var_value', 'tree', 'str')
        add_method(kpse, 'find_file', 'tree', 'filename')
        add_method(kpse, 'find_files', 'tree', 'filename', 'first')
    end

end

class KpseServer

    @@url = 'http://kpse.thismachine.org/KpseService'

    attr_accessor :port

    def initialize(port=7000)
        @port = port
        @server = nil
    end

    def start
        puts "starting soap service at port #{@port}"
        @server = KpseService.new('KpseServer', @@url, '0.0.0.0', @port.to_i)
        trap(:INT) do
            @server.shutdown
        end
        status = @server.start
    end

    def stop
        @server.shutdown rescue false
    end

end

class KpseClient

    @@url = 'http://kpse.thismachine.org/KpseService'

    attr_accessor :port

    def initialize(port=7000)
        @port = port
        @kpse = nil
    end

    def start
        @kpse = SOAP::RPC::Driver.new("http://localhost:#{port}/", @@url)
        @kpse.add_method('choose','files', 'environment')
        @kpse.add_method('load','files', 'environment')
        @kpse.add_method('expand_variables', 'tree')
        @kpse.add_method('expand_braces', 'tree', 'str')
        @kpse.add_method('expand_path', 'tree', 'str')
        @kpse.add_method('expand_var', 'tree', 'str')
        @kpse.add_method('show_path', 'tree', 'str')
        @kpse.add_method('var_value', 'tree', 'str')
        @kpse.add_method('find_file', 'tree', 'filename')
        @kpse.add_method('find_files', 'tree', 'filename', 'first')
    end

    def object
        @kpse
    end

end

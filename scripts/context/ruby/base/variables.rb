# module    : base/variables
# copyright : PRAGMA Advanced Document Engineering
# version   : 2002-2005
# author    : Hans Hagen
#
# project   : ConTeXt / eXaMpLe
# concept   : Hans Hagen
# info      : j.hagen@xs4all.nl
# www       : www.pragma-ade.com

# ['base/tool','tool'].each do |r| begin require r ; rescue Exception ; else break ; end ; end

require 'base/tool'

module Variables

    def setvariable(key,value='')
        @variables[key] = value
    end

    def replacevariable(key,value='')
        @variables[key] = value if @variables.key?(key)
    end

    def getvariable(key,default='')
        if @variables.key?(key) then @variables[key] else default end
    end

    def checkedvariable(str,default='')
        if @variables.key?(key) then
            if @variables[key].empty? then default else @variables[key] end
        else
            default
        end
    end

    def report(*str)
        @logger.report(*str)
    end

    def debug(*str)
        @logger.debug(str)
    end

end

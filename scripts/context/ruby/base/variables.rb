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

class Hash

    def nothing?(id)
        ! self[id] || self[id].empty?
    end

    def subset(pattern)
        h = Hash.new
        p = pattern.gsub(/([\.\:\-])/) do "\\#{$1}" end
        r = /^#{p}/
        self.keys.each do |k|
            h[k] = self[k].dup if k =~ r
        end
        return h
    end

end

class ExtendedHash < Hash

    @@re_var_a = /\%(.*?)\%/
    @@re_var_b = /\$\((.*?)\)/

    def set(key,value='',resolve=true)
        if value then
            self[key] = if resolve then resolved(value.to_s) else value.to_s end
        else
            self[key] = ''
        end
    end

    def replace(key,value='')
        self[key] = value if self?(key)
    end

    def get(key,default='')
        if self.key?(key) then self[key] else default end
    end

    def true?(key)
        self[key] =~ /^(yes|on|true|enable|enabled|y|start)$/io rescue false
    end

    def resolved(str)
        begin
            str.to_s.gsub(@@re_var_a) do
                self[$1] || ''
            end.gsub(@@re_var_b) do
                self[$1] || ''
            end
        rescue
            str.to_s rescue ''
        end
    end

    def check(key,default='')
        if self.key?(key) then
            if self[key].empty? then self[key] = (default || '') end
        else
            self[key] = (default || '')
        end
    end

    def checked(key,default='')
        if self.key?(key) then
            if self[key].empty? then default else self[key] end
        else
            default
        end
    end

    def empty?(key)
        self[key].empty?
    end

    # def downcase(key)
        # self[key].downcase!
    # end

end

# the next one is obsolete so we need to replace things

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

    def truevariable(key)
        @variables[key] =~ /^(yes|on|true)$/io rescue false
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

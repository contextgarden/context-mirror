require 'digest/md5'

# todo: register omissions per file

class FileState

    def initialize
        @states = Hash.new
        @omiter = Hash.new
    end

    def reset
        @states.clear
        @omiter.clear
    end

    def register(filename,omit=nil)
        unless @states.key?(filename) then
            @states[filename] = Array.new
            @omiter[filename] = omit
        end
        @states[filename] << checksum(filename,@omiter[filename])
    end

    def update(filename=nil)
        [filename,@states.keys].flatten.compact.uniq.each do |fn|
            register(fn)
        end
    end

    def inspect(filename=nil)
        result = ''
        [filename,@states.keys].flatten.compact.uniq.sort.each do |fn|
            if @states.key?(fn) then
                result += "#{fn}: #{@states[fn].inspect}\n"
            end
        end
        result
    end

    def changed?(filename)
        if @states.key?(filename) then
            n = @states[filename].length
            if n>1 then
                changed = @states[filename][n-1] != @states[filename][n-2]
            else
                changed = true
            end
        else
            changed = true
        end
        return changed
    end

    def checksum(filename,omit=nil)
        sum = ''
        begin
            if FileTest.file?(filename) && (data = IO.read(filename)) then
                data.gsub!(/\n.*?(#{[omit].flatten.join('|')}).*?\n/) do "\n" end if omit
                sum = Digest::MD5.hexdigest(data).upcase
            end
        rescue
            sum = ''
        end
        return sum
    end

    def stable?
        @states.keys.each do |s|
            return false if changed?(s)
        end
        return true
    end

end

require 'ftools'

class File

    def File.suffixed(name,sufa,sufb=nil)
        if sufb then
            unsuffixed(name) + "-#{sufa}.#{sufb}"
        else
            unsuffixed(name) + ".#{sufa}"
        end
    end

    def File.unsuffixed(name)
        name.sub(/\.[^\.]*?$/o, '')
    end

    def File.suffix(name,default='')
        if name =~ /\.([^\.]*?)$/o then
            $1
        else
            default
        end
    end

    def File.splitname(name,suffix='')
        if name =~ /(.*)\.([^\.]*?)$/o then
            [$1, $2]
        else
            [name, suffix]
        end
    end

end

class File

    def File.silentopen(name,method='r')
        begin
            f = File.open(name,method)
        rescue
            return nil
        else
            return f
        end
    end

    def File.silentread(name)
        begin
            data = IO.read(name)
        rescue
            return nil
        else
            return data
        end
    end

    def File.atleast?(name,n=0)
        begin
            size = FileTest.size(name)
        rescue
            return false
        else
            return size > n
        end
    end

    def File.appended(name,str='')
        if FileTest.file?(name) then
            begin
                if f = File.open(name,'a') then
                    f << str
                    f.close
                    return true
                end
            rescue
            end
        end
        return false
    end

    def File.written(name,str='')
        begin
            if f = File.open(name,'w') then
                f << str
                f.close
                return true
            end
        rescue
        end
        return false
    end

    def File.silentdelete(filename)
        begin File.delete(filename) ; rescue ; end
    end

    def File.silentcopy(oldname,newname)
        return if File.expand_path(oldname) == File.expand_path(newname)
        begin File.copy(oldname,newname) ; rescue ; end
    end

    def File.silentrename(oldname,newname)
        # in case of troubles, we just copy the file; we
        # maybe working over multiple file systems or
        # apps may have mildly locked files (like gs does)
        return if File.expand_path(oldname) == File.expand_path(newname)
        begin File.delete(newname) ; rescue ; end
        begin
            File.rename(oldname,newname)
        rescue
            begin File.copy(oldname,newname) ; rescue ; end
        end
    end

end

class File

    # handles "c:\tmp\test.tex" as well as "/${TEMP}/test.tex")

    def File.unixfied(filename)
        begin
            str = filename.gsub(/\$\{*([a-z0-9\_]+)\}*/oi) do
                if ENV.key?($1) then ENV[$1] else $1 end
            end
            str.gsub(/[\/\\]+/o, '/')
        rescue
            filename
        end
    end

end


require 'monitor'
require 'base/kpsefast'

class KpseTrees < Monitor

    def initialize
        @trees = Hash.new
    end

    def pattern(filenames)
        filenames.join('|').gsub(/\\+/o,'/').downcase
    end

    def choose(filenames,environment)
        current = pattern(filenames)
        load(filenames,environment) unless @trees[current]
        puts "enabling tree #{current}"
        current
    end

    def fetch(filenames,environment) # will send whole object !
        current = pattern(filenames)
        load(filenames,environment) unless @trees[current]
        puts "fetching tree #{current}"
        @trees[current]
    end

    def load(filenames,environment)
        current = pattern(filenames)
        puts "loading tree #{current}"
        @trees[current] = KpseFast.new
        @trees[current].push_environment(environment)
        @trees[current].load_cnf(filenames)
        @trees[current].expand_variables
        @trees[current].load_lsr
    end

    def set(tree,key,value)
        case key
            when 'progname' then @trees[tree].progname = value
            when 'engine'   then @trees[tree].engine   = value
            when 'format'   then @trees[tree].format   = value
        end
    end
    def get(tree,key)
        case key
            when 'progname' then @trees[tree].progname
            when 'engine'   then @trees[tree].engine
            when 'format'   then @trees[tree].format
        end
    end

    def load_cnf(tree)
        @trees[tree].load_cnf
    end
    def load_lsr(tree)
        @trees[tree].load_lsr
    end
    def expand_variables(tree)
        @trees[tree].expand_variables
    end
    def expand_braces(tree,str)
        @trees[tree].expand_braces(str)
    end
    def expand_path(tree,str)
        @trees[tree].expand_path(str)
    end
    def expand_var(tree,str)
        @trees[tree].expand_var(str)
    end
    def show_path(tree,str)
        @trees[tree].show_path(str)
    end
    def var_value(tree,str)
        @trees[tree].var_value(str)
    end
    def find_file(tree,filename)
        @trees[tree].find_file(filename)
    end
    def find_files(tree,filename,first)
        @trees[tree].find_files(filename,first)
    end

end

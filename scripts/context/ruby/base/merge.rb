# module    : base/merge
# copyright : PRAGMA Advanced Document Engineering
# version   : 2006
# author    : Hans Hagen
#
# project   : ConTeXt / eXaMpLe
# concept   : Hans Hagen
# info      : j.hagen@xs4all.nl
# www       : www.pragma-ade.com

# --selfmerg ewill create stand alone script (--selfcleanup does the opposite)

# this module will package all the used modules in the file itself
# so that we can relocate the file at wish, usage:
#
# merge:
#
# unless SelfMerge::ok? && SelfMerge::merge then
#     puts("merging should happen on the path were the base inserts reside")
# end
#
# cleanup:
#
# unless SelfMerge::cleanup then
#     puts("merging should happen on the path were the base inserts reside")
# end

module SelfMerge

    @@kpsemergestart = "\# kpse_merge_start"
    @@kpsemergestop  = "\# kpse_merge_stop"
    @@kpsemergefile  = "\# kpse_merge_file: "
    @@kpsemergedone  = "\# kpse_merge_done: "

    @@filename = File.basename($0)
    @@ownpath  = File.expand_path(File.dirname($0))
    @@modroot  = '(base|graphics|rslb|www)' # needed in regex in order not to mess up SelfMerge
    @@modules  = $".collect do |file| File.expand_path(file) end

    @@modules.delete_if do |file|
        file !~ /^#{@@ownpath}\/#{@@modroot}.*$/i
    end

    def SelfMerge::ok?
        begin
            @@modules.each do |file|
                return false unless FileTest.file?(file)
            end
        rescue
            return false
        else
            return true
        end
    end

    def SelfMerge::merge
        begin
            if SelfMerge::ok? && rbfile = IO.read(@@filename) then
                begin
                    inserts = "#{@@kpsemergestart}\n\n"
                    @@modules.each do |file|
                        inserts << "#{@@kpsemergefile}'#{file}'\n\n"
                        inserts << IO.read(file).gsub(/^#.*?\n$/,'')
                        inserts << "\n\n"
                    end
                    inserts << "#{@@kpsemergestop}\n\n"
                    # no gsub! else we end up in SelfMerge
                    rbfile.sub!(/#{@@kpsemergestart}\s*#{@@kpsemergestop}/moi) do
                        inserts
                    end
                    rbfile.gsub!(/^(.*)(require [\"\'].*?#{@@modroot}.*)$/) do
                        pre, post = $1, $2
                        if pre =~ /#{@@kpsemergedone}/ then
                            "#{pre}#{post}"
                        else
                            "#{pre}#{@@kpsemergedone}#{post}"
                        end
                    end
                rescue
                    return false
                else
                    begin
                        File.open(@@filename,'w') do |f|
                            f << rbfile
                        end
                    rescue
                        return false
                    end
                end
            end
        rescue
            return false
        else
            return true
        end
    end

    def SelfMerge::cleanup
        begin
            if rbfile = IO.read(@@filename) then
                begin
                    rbfile.sub!(/#{@@kpsemergestart}(.*)#{@@kpsemergestop}\s*/moi) do
                        "#{@@kpsemergestart}\n\n#{@@kpsemergestop}\n\n"
                    end
                    rbfile.gsub!(/^(.*#{@@kpsemergedone}.*)$/) do
                        str = $1
                        if str =~ /require [\"\']/ then
                            str.gsub(/#{@@kpsemergedone}/, '')
                        else
                            str
                        end
                    end
                rescue
                    return false
                else
                    begin
                        File.open(@@filename,'w') do |f|
                            f << rbfile
                        end
                    rescue
                        return false
                    end
                end
            end
        rescue
            return false
        else
            return true
        end
    end

    def SelfMerge::replace
        if SelfMerge::ok? then
            SelfMerge::cleanup
            SelfMerge::merge
        end
    end

end

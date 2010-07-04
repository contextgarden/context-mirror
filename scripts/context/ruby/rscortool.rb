# program   : rscortool
# copyright : PRAGMA Publishing On Demand
# version   : 1.00 - 2002
# author    : Hans Hagen
#
# project   : eXaMpLe
# concept   : Hans Hagen
# info      : j.hagen@xs4all.nl
# www       : www.pragma-pod.com / www.pragma-ade.com

require 'rexml/document.rb'

class Array

    def downcase
        self.collect { |l| l.to_s.downcase }
    end

end

class SortedXML

    def initialize (filename)
        return nil if not filename or filename.empty? or not test(?e,filename)
        @data = REXML::Document.new(File.new(filename),
            {:ignore_whitespace_nodes => :all,
             :compress_whitespace     => :all})
    end

    def save (filename)
        # filename += '.xml' unless filename.match(/\..*?$/)
        filename += '.xml' unless filename =~ /\..*?$/
        if not filename.empty? and f = open(filename,'w')
            @data.write(f,0)
            f.close
        end
    end

    def sort
        keys = REXML::XPath.match(@data.root,"/contacts/contact/@label")
        return unless keys
        keys = keys.downcase
        records = @data.elements.to_a("/contacts/contact")
        @data.elements.delete_all("/contacts/contact")
        keys = keys.collect do |l| # prepare numbers
            l.gsub(/(\d+)/) do |d| sprintf('%05d', d) end
        end
        keys.sort.each do |s|
            @data.root.add_element(records[keys.index(s)])
        end
    end

end

def sortfile (filename)
    c = SortedXML.new(filename)
    c.sort
    c.save('test.xml')
end

exit if ARGV[0] == nil or ARGV[0].empty?

sortfile(ARGV[0])

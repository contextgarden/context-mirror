module PDFview

    @files = Hash.new

    def PDFview.open(*list)
        begin
            [*list].flatten.each do |file|
                filename = fullname(file)
                if FileTest.file?(filename) then
                    result = `pdfopen --file #{filename} 2>&1`
                    @files[filename] = true
                end
            end
        rescue
        end
    end

    def PDFview.close(*list)
        [*list].flatten.each do |file|
            filename = fullname(file)
            begin
                if @files.key?(filename) then
                    result = `pdfclose --file #{filename} 2>&1`
                else
                    closeall
                    return
                end
            rescue
            end
            @files.delete(filename)
        end
    end

    def PDFview.closeall
        begin
            result = `pdfclose --all 2>&1`
        rescue
        end
        @files.clear
    end

    def PDFview.fullname(name)
        name + if name =~ /\.pdf$/ then '' else '.pdf' end
    end

end

puts ('' || false)

# PDFview.open("t:/document/show-exa.pdf")
# PDFview.open("t:/document/show-gra.pdf")
# PDFview.close("t:/document/show-exa.pdf")
# PDFview.close("t:/document/show-gra.pdf")

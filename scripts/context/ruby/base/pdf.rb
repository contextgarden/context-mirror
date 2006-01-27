module PDFview

    @files      = Hash.new
    @opencalls  = Hash.new
    @closecalls = Hash.new
    @allcalls   = Hash.new

    @method     = 'default' # 'xpdf'

    @opencalls['default']  = "pdfopen --file"
    @opencalls['xpdf']     = "xpdfopen"

    @closecalls['default'] = "pdfclose --file"
    @closecalls['xpdf']    = nil

    @allcalls['default']   = "pdfclose --all"
    @allcalls['xpdf']      = nil

    def PDFview.setmethod(method)
        @method = method
    end

    def PDFview.open(*list)
        begin
            [*list].flatten.each do |file|
                filename = fullname(file)
                if FileTest.file?(filename) then
                    if @opencalls[@method] then
                        result = `#{@opencalls[@method]} #{filename} 2>&1`
                        @files[filename] = true
                    end
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
                    if @closecalls[@method] then
                        result = `#{@closecalls[@method]} #{filename} 2>&1`
                    end
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
            if @allcalls[@method] then
                result = `#{@allcalls[@method]} 2>&1`
            end
        rescue
        end
        @files.clear
    end

    def PDFview.fullname(name)
        name + if name =~ /\.pdf$/ then '' else '.pdf' end
    end

end

# PDFview.open("t:/document/show-exa.pdf")
# PDFview.open("t:/document/show-gra.pdf")
# PDFview.close("t:/document/show-exa.pdf")
# PDFview.close("t:/document/show-gra.pdf")

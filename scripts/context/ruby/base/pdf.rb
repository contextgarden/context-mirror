module PDFview

    @files      = Hash.new
    @opencalls  = Hash.new
    @closecalls = Hash.new
    @allcalls   = Hash.new

    # acrobat no longer is a valid default as (1) it keeps crashing with pdfopen due to a dual acrobat/reader install (a side effect
    # of the api changing every version, and (2) because there are all these anyoing popups with respect to signed, review, online
    # this and that stuff ... hardly useable as fast previewer, and (3) sumatra is faster and nicer and doesn't block (okay, we have to
    # get rid of this horrible yellow bg-coloring buts that is doable

    @method     = 'sumatra' # 'default' # 'xpdf'

    @opencalls['default']  = "pdfopen  --file" # "pdfopen --back --file"
    @opencalls['xpdf']     = "xpdfopen"
    @opencalls['sumatra']  = 'start "test" sumatrapdf.exe -reuse-instance -bg-color 0xCCCCCC'

    @closecalls['default'] = "pdfclose --file"
    @closecalls['xpdf']    = nil
    @closecalls['sumatra'] = nil

    @allcalls['default']   = "pdfclose --all"
    @allcalls['xpdf']      = nil
    @allcalls['sumatra']   = nil

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

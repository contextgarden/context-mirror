# module    : base/mp
# copyright : PRAGMA Advanced Document Engineering
# version   : 2005-2006
# author    : Hans Hagen
#
# project   : ConTeXt / eXaMpLe
# concept   : Hans Hagen
# info      : j.hagen@xs4all.nl
# www       : www.pragma-ade.com

module MPTools

    @@definitions, @@start, @@stop, @@before, @@after = Hash.new, Hash.new, Hash.new, Hash.new, Hash.new


    @@definitions['plain'] = <<EOT
\\gdef\\mpxshipout{\\shipout\\hbox\\bgroup
  \\setbox0=\\hbox\\bgroup}

\\gdef\\stopmpxshipout{\\egroup  \\dimen0=\\ht0 \\advance\\dimen0\\dp0
  \\dimen1=\\ht0 \\dimen2=\\dp0
  \\setbox0=\\hbox\\bgroup
    \\box0
    \\ifnum\\dimen0>0 \\vrule width1sp height\\dimen1 depth\\dimen2
    \\else \\vrule width1sp height1sp depth0sp\\relax
    \\fi\\egroup
  \\ht0=0pt \\dp0=0pt \\box0 \\egroup}
EOT

    @@start ['plain'] = ""
    @@before['plain'] = "\\mpxshipout"
    @@after ['plain'] = "\\stopmpxshipout"
    @@stop  ['plain'] = "\\end{document}"

    @@definitions['context'] = <<EOT
\\ifx\\startMPXpage\\undefined

  \\ifx\\loadallfontmapfiles\\undefined \\let\\loadallfontmapfiles\\relax \\fi

  \\gdef\\startMPXpage
    {\\shipout\\hbox
     \\bgroup
     \\setbox0=\\hbox
     \\bgroup}

  \\gdef\\stopMPXpage
    {\\egroup
     \\dimen0=\\ht0
     \\advance\\dimen0\\dp0
     \\dimen1=\\ht0
     \\dimen2=\\dp0
     \\setbox0=\\hbox\\bgroup
       \\box0
       \\ifnum\\dimen0>0
         \\vrule width 1sp height \\dimen1 depth \\dimen2
       \\else
         \\vrule width 1sp height 1sp depth 0sp \\relax
       \\fi
    \\egroup
    \\ht0=0pt
    \\dp0=0pt
    \\loadallfontmapfiles
    \\box0
    \\egroup}

\\fi

\\ifx\\starttext\\undefined

  \\let\\starttext\\relax
  \\def\\stoptext{\\end{document}}

\\fi
EOT

    @@start ['context'] = "\\starttext"
    @@before['context'] = "\\startMPXpage"
    @@after ['context'] = "\\stopMPXpage"
    @@stop  ['context'] = "\\stoptext"

    # todo: \usemodule[m-mpx ] and test fo defined

    def MPTools::mptotex(from,to=nil,method='plain')
        begin
            if from && data = IO.read(from) then
                f = if to then File.open(to,'w') else $stdout end
                f.puts("% file: #{from}")
                f.puts("")
                f.puts(@@definitions[method])
                unless @@start[method].empty? then
                    f.puts("")
                    f.puts(@@start[method])
                end
                data.gsub!(/([^\\])%.*?$/mo) do
                    $1
                end
                data.scan(/(verbatim|b)tex\s*(.*?)\s*etex/mo) do
                    tag, text = $1, $2
                    f.puts("")
                    if tag == 'b' then
                        f.puts(@@before[method])
                        f.puts("#{text}%")
                        f.puts(@@after [method])
                    else
                        f.puts("#{text}")
                    end
                    f.puts("")
                end
                f.puts("")
                f.puts(@@stop[method])
                f.close
            else
                return false
            end
        rescue
            File.delete(to) rescue false
            return false
        else
            return true
        end
    end

    @@splitMPlines = false

    def MPTools::splitmplines(str)
        if @@splitMPlines then
            btex, verbatimtex, strings, result = Array.new, Array.new, Array.new, str.dup
            # protect texts
            result.gsub!(/btex\s*(.*?)\s*etex/) do
                btex << $1
                "btex(#{btex.length-1})"
            end
            result.gsub!(/verbatimtex\s*(.*?)\s*etex/) do
                verbatimtex << $1
                "verbatimtex(#{verbatimtex.length-1})"
            end
            result.gsub!(/\"(.*?)\"/) do
                strings << $1
                "\"#{strings.length-1}\""
            end
            result.gsub!(/\;/) do
                ";\n"
            end
            result.gsub!(/(.{80,})(\-\-\-|\-\-|\.\.\.|\.\.)/) do
                "#{$1}#{$2}\n"
            end
            result.gsub!(/\n[\s\n]+/moi) do
                "\n"
            end
            result.gsub!(/btex\((\d+)\)/) do
                "btex #{btex[$1.to_i]} etex"
            end
            result.gsub!(/verbatimtex\((\d+)\)/) do
                "verbatimtex #{verbatimtex[$1.to_i]} etex"
            end
            result.gsub!(/\"(\d+)\"/) do
                "\"#{strings[$1.to_i]}\""
            end
            # return result # let's catch xetex bug
            return result.gsub(/\^\^(M|J)/o, "\n")
        else
            # return str # let's catch xetex bug
            return str.gsub(/\^\^(M|J)/o, "\n")
        end
    end

end

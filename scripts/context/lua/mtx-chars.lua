dofile(input.find_file(instance,"luat-log.lua"))

texmf.instance = instance -- we need to get rid of this / maybe current instance in global table

scripts       = scripts       or { }
scripts.chars = scripts.chars or { }

function scripts.chars.stixtomkiv(inname,outname)
    if inname == "" then
        logs.report("aquiring math data","invalid datafilename")
    end
    local f = io.open(inname)
    if not f then
        logs.report("aquiring math data","invalid datafile")
    else
        logs.report("aquiring math data","processing " .. inname)
        if not outname or outname == "" then
            outname = "char-mth.lua"
        end
        local classes = {
            N = "normal",
            A = "alphabetic",
            D = "diacritic",
            P = "punctuation",
            B = "binary",
            R = "relation",
            L = "large",
            O = "opening",
            C = "closing",
            F = "fence"
        }
        local format, concat = string.format, table.concat
        local valid, done = false, { }
        local g = io.open(outname,'w')
        g:write([[
-- filename : char-mth.lua
-- comment  : companion to char-mth.tex (in ConTeXt)
-- author   : Hans Hagen, PRAGMA-ADE, Hasselt NL
-- license  : see context related readme files
-- comment  : generated from data file downloaded from STIX website

if not versions   then versions   = { } end versions['char-mth'] = 1.001
if not characters then characters = { } end
        ]])
        g:write(format("\ncharacters.math = {\n"))
        for l in f:lines() do
            if not valid then
                valid = l:find("AMS/TeX name")
            end
            if valid then
                local unicode = l:sub(2,6)
                if unicode:sub(1,1) ~= " " and unicode ~= "" and not done[unicode] then
                    local mathclass, adobename, texname = l:sub(57,57) or "", l:sub(13,36) or "", l:sub(84,109) or ""
                    texname, adobename = texname:gsub("[\\ ]",""), adobename:gsub("[\\ ]","")
                    local t = { }
                    if mathclass ~= "" then t[#t+1] = format("mathclass='%s'", classes[mathclass] or "unknown") end
                    if adobename ~= "" then t[#t+1] = format("adobename='%s'", adobename                      ) end
                    if texname   ~= "" then t[#t+1] = format("texname='%s'"  , texname                        ) end
                    if #t > 0 then
                        g:write(format("\t[0x%s] = { %s },\n",unicode, concat(t,", ")))
                    end
                    done[unicode] = true
                end
            end
        end
        if not valid then
            g:write("\t-- The data file is corrupt, invalid or maybe the format has changed.\n")
            logs.report("aquiring math data","problems with data table")
        else
            logs.report("aquiring math data","table saved in " .. outname)
        end
        g:write("}\n")
        g:close()
        f:close()
    end
end

banner = banner .. " | character tools "

messages.help = [[
--stix                convert stix table to math table
]]

if environment.argument("stix") then
    local inname  = environment.files[1] or ""
    local outname = environment.files[2] or ""
    scripts.chars.stixtomkiv(inname,outname)
else
    input.help(banner,messages.help)
end

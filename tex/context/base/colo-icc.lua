if not modules then modules = { } end modules ['colo-ini'] = {
    version   = 1.000,
    comment   = "companion to colo-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local char, byte, gsub, match, format, strip = string.char, string.byte, string.gsub, string.match, string.format, string.strip
local readstring, readnumber = io.readstring, io.readnumber

local colors = attributes and attributes.colors or { } -- when used in mtxrun

local report_colors = logs.reporter("colors","icc")

local R, Cs, lpegmatch = lpeg.R, lpeg.Cs, lpeg.match

local invalid = R(char(0)..char(31))
local cleaned = invalid^0 * Cs((1-invalid)^0)

function colors.iccprofile(filename,verbose)
    local fullname = resolvers.findfile(filename,"icc") or ""
    if fullname == "" then
        local locate = resolvers.finders.byscheme -- not in mtxrun
        if locate then
            fullname = locate("loc",filename)
        end
    end
    if fullname == "" then
        return nil, false, format("profile '%s' cannot be found",filename)
    end
    local f = io.open(fullname,"rb")
    if not f then
        return nil, false, format("profile '%s'cannot be loaded",fullname)
    end
    local header =  {
        size               = readnumber(f,4),
        cmmtype            = readnumber(f,4),
        version            = readnumber(f,4),
        deviceclass        = strip(readstring(f,4)),
        colorspace         = strip(readstring(f,4)),
        connectionspace    = strip(readstring(f,4)),
        datetime           = {
            year    = readnumber(f,2),
            month   = readnumber(f,2),
            day     = readnumber(f,2),
            hour    = readnumber(f,2),
            minutes = readnumber(f,2),
            seconds = readnumber(f,2),
        },
        filesignature      = strip(readstring(f,4)),
        platformsignature  = strip(readstring(f,4)),
        options            = readnumber(f,4),
        devicemanufacturer = strip(readstring(f,4)),
        devicemodel        = strip(readstring(f,4)),
        deviceattributes   = readnumber(f,4),
        renderingintent    = readnumber(f,4),
        illuminantxyz      = {
            x = readnumber(f,4),
            y = readnumber(f,4),
            z = readnumber(f,4),
        },
        profilecreator     = readnumber(f,4),
        id                 = strip(readstring(f,16)),
    }
    local tags = { }
    for i=1,readnumber(f,128,4) do
        tags[readstring(f,4)] = {
            offset = readnumber(f,4),
            length = readnumber(f,4),
        }
    end
    local o = header.options
    header.options =
        o == 0 and "embedded"  or
        o == 1 and "dependent" or "unknown"
    local d = header.deviceattributes
    header.deviceattributes = {
        [number.hasbit(d,1) and "transparency" or "reflective"] = true,
        [number.hasbit(d,2) and "mate"         or "glossy"    ] = true,
        [number.hasbit(d,3) and "negative"     or "positive"  ] = true,
        [number.hasbit(d,4) and "bw"           or "color"     ] = true,
    }
    local r = header.renderingintent
    header.renderingintent =
        r == 0 and "perceptual" or
        r == 1 and "relative"   or
        r == 2 and "saturation" or
        r == 3 and "absolute"   or "unknown"
    for tag, spec in next, tags do
        if tag then
            local offset, length = spec.offset, spec.length
            local kind = readstring(f,offset,4)
            if kind == "text" or kind == "desc" then
                local str = readstring(f,length-4)
                tags[tag] = {
                    data    = str,
                    cleaned = lpegmatch(cleaned,str),
                }
            else
                if verbose then
                    report_colors("ignoring tag '%s' or type '%s' in profile '%s'",tag,kind,fullname)
                end
                tags[tag] = nil
            end
        end
    end
    f:close()
    local profile = {
        filename = filename,
        fullname = fullname,
        header   = header,
        tags     = tags,
    }
    return profile, true, format("profile '%s' loaded",fullname)
end

--~ local profile, error, message = colors.iccprofile("ussheetfedcoated.icc")
--~ print(error,message)
--~ table.print(profile)

if not modules then modules = { } end modules ['l-url'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local char, gmatch, gsub, format, byte = string.char, string.gmatch, string.gsub, string.format, string.byte
local concat = table.concat
local tonumber, type = tonumber, type
local lpegmatch, lpegP, lpegC, lpegR, lpegS, lpegCs, lpegCc = lpeg.match, lpeg.P, lpeg.C, lpeg.R, lpeg.S, lpeg.Cs, lpeg.Cc

-- from the spec (on the web):
--
--     foo://example.com:8042/over/there?name=ferret#nose
--     \_/   \______________/\_________/ \_________/ \__/
--      |           |            |            |        |
--   scheme     authority       path        query   fragment
--      |   _____________________|__
--     / \ /                        \
--     urn:example:animal:ferret:nose

url       = url or { }
local url = url

local function tochar(s)
    return char(tonumber(s,16))
end

local colon, qmark, hash, slash, percent, endofstring = lpegP(":"), lpegP("?"), lpegP("#"), lpegP("/"), lpegP("%"), lpegP(-1)

local hexdigit  = lpegR("09","AF","af")
local plus      = lpegP("+")
local nothing   = lpegCc("")
local escaped   = (plus / " ") + (percent * lpegC(hexdigit * hexdigit) / tochar)

-- we assume schemes with more than 1 character (in order to avoid problems with windows disks)

local scheme    =                 lpegCs((escaped+(1-colon-slash-qmark-hash))^2) * colon + nothing
local authority = slash * slash * lpegCs((escaped+(1-      slash-qmark-hash))^0)         + nothing
local path      = slash *         lpegCs((escaped+(1-            qmark-hash))^0)         + nothing
local query     = qmark         * lpegCs((escaped+(1-                  hash))^0)         + nothing
local fragment  = hash          * lpegCs((escaped+(1-           endofstring))^0)         + nothing

local parser = lpeg.Ct(scheme * authority * path * query * fragment)

lpeg.patterns.urlsplitter = parser

local escapes = { }

for i=0,255 do
    escapes[i] = format("%%%02X",i)
end

local escaper = lpeg.Cs((lpegR("09","AZ","az") + lpegS("-./_") + lpegP(1) / escapes)^0)

lpeg.patterns.urlescaper = escaper

-- todo: reconsider Ct as we can as well have five return values (saves a table)
-- so we can have two parsers, one with and one without

function url.split(str)
    return (type(str) == "string" and lpegmatch(parser,str)) or str
end

-- todo: cache them

function url.hashed(str)
    local s = url.split(str)
    local somescheme = s[1] ~= ""
    if not somescheme then
        return {
            scheme    = "file",
            authority = "",
            path      = str,
            query     = "",
            fragment  = "",
            original  = str,
            noscheme  = true,
        }
    else
        return {
            scheme    = s[1],
            authority = s[2],
            path      = s[3],
            query     = s[4],
            fragment  = s[5],
            original  = str,
            noscheme  = false,
        }
    end
end

function url.hasscheme(str)
    return url.split(str)[1] ~= ""
end

function url.addscheme(str,scheme)
    return (url.hasscheme(str) and str) or ((scheme or "file:///") .. str)
end

function url.construct(hash) -- dodo: we need to escape !
    local fullurl = { }
    local scheme, authority, path, query, fragment = hash.scheme, hash.authority, hash.path, hash.query, hash.fragment
    if scheme and scheme ~= "" then
        fullurl[#fullurl+1] = scheme .. "://"
    end
    if authority and authority ~= "" then
        fullurl[#fullurl+1] = authority
    end
    if path and path ~= "" then
        fullurl[#fullurl+1] = "/" .. path
    end
    if query and query ~= "" then
        fullurl[#fullurl+1] = "?".. query
    end
    if fragment and fragment ~= "" then
        fullurl[#fullurl+1] = "#".. fragment
    end
    return lpegmatch(escaper,concat(fullurl))
end

function url.filename(filename)
    local t = url.hashed(filename)
    return (t.scheme == "file" and (gsub(t.path,"^/([a-zA-Z])([:|])/)","%1:"))) or filename
end

function url.query(str)
    if type(str) == "string" then
        local t = { }
        for k, v in gmatch(str,"([^&=]*)=([^&=]*)") do
            t[k] = v
        end
        return t
    else
        return str
    end
end

--~ print(url.filename("file:///c:/oeps.txt"))
--~ print(url.filename("c:/oeps.txt"))
--~ print(url.filename("file:///oeps.txt"))
--~ print(url.filename("file:///etc/test.txt"))
--~ print(url.filename("/oeps.txt"))

--~ from the spec on the web (sort of):

--~ local function test(str)
--~     local t = url.hashed(str)
--~     t.constructed = url.construct(t)
--~     print(table.serialize(t))
--~ end

--~ test("sys:///./colo-rgb")

--~ test("/data/site/output/q2p-develop/resources/ecaboperception4_res/topicresources/58313733/figuur-cow.jpg")
--~ test("file:///M:/q2p/develop/output/q2p-develop/resources/ecaboperception4_res/topicresources/58313733")
--~ test("M:/q2p/develop/output/q2p-develop/resources/ecaboperception4_res/topicresources/58313733")
--~ test("file:///q2p/develop/output/q2p-develop/resources/ecaboperception4_res/topicresources/58313733")
--~ test("/q2p/develop/output/q2p-develop/resources/ecaboperception4_res/topicresources/58313733")

--~ test("file:///cow%20with%20spaces")
--~ test("file:///cow%20with%20spaces.pdf")
--~ test("cow%20with%20spaces.pdf")
--~ test("some%20file")
--~ test("/etc/passwords")
--~ test("http://www.myself.com/some%20words.html")
--~ test("file:///c:/oeps.txt")
--~ test("file:///c|/oeps.txt")
--~ test("file:///etc/oeps.txt")
--~ test("file://./etc/oeps.txt")
--~ test("file:////etc/oeps.txt")
--~ test("ftp://ftp.is.co.za/rfc/rfc1808.txt")
--~ test("http://www.ietf.org/rfc/rfc2396.txt")
--~ test("ldap://[2001:db8::7]/c=GB?objectClass?one#what")
--~ test("mailto:John.Doe@example.com")
--~ test("news:comp.infosystems.www.servers.unix")
--~ test("tel:+1-816-555-1212")
--~ test("telnet://192.0.2.16:80/")
--~ test("urn:oasis:names:specification:docbook:dtd:xml:4.1.2")
--~ test("http://www.pragma-ade.com/spaced%20name")

--~ test("zip:///oeps/oeps.zip#bla/bla.tex")
--~ test("zip:///oeps/oeps.zip?bla/bla.tex")

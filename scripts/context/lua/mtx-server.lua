if not modules then modules = { } end modules ['mtx-server'] = {
    version   = 1.001,
    comment   = "companion to mtxrun.lua",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

texmf.instance = instance -- we need to get rid of this / maybe current instance in global table

-- The starting point was stripped down webserver.lua by Samuel
-- Saint-Pettersen (as downloaded on 21-5-2008) which only served
-- html and was not configureable. In due time I will extend the
-- next code. Eventually we may move code to l-server.

scripts           = scripts           or { }
scripts.webserver = scripts.webserver or {}

local socket = require("socket")

local function message(str)
    return string.format("<h1>%s</h1>",str)
end

function scripts.webserver.run(configuration)
    local server = assert(socket.bind("*", tonumber(configuration.port or 8080)))
    while true do
        local client = server:accept()
        client:settimeout(configuration.timeout or 60)
        local request, e = client:receive()
        if e then
            client:send(message("404 Not Found"))
        else
            -- GET /showcase.pdf HTTP/1.1
            local filename = request:match("GET (.+) HTTP/.*$") -- todo: more clever
         -- filename = filename:gsub("%%(%d%d)",function(c) return string.char(tonumber(c,16)) end)
            filename = socket.url.unescape(filename)
            if filename == nil or filename == "" then
                filename = configuration.index or "index.html"
            end
            -- todo chunked
            local fullname = file.join(configuration.root,filename)
            local data = io.loaddata(fullname)
            if data and data ~= "" then
                local result
                client:send("HTTP/1.1 200 OK\r\n")
                client:send("Connection: close\r\n")
                if filename:find(".pdf$") then -- todo: special handler
                    client:send(string.format("Content-Length: %s\r\n",#data))
                    client:send("Content-Type: application/pdf\r\n")
                else
                    client:send("Content-Type: text/html\r\n")
                end
                client:send("\r\n")
                client:send(data)
                client:send("\r\n")
            else
                client:send(message("404 Not Found"))
            end
        end
        client:close()
    end
end


banner = banner .. " | webserver "

messages.help = [[
--start               start server
--port                port to listen to
--root                server root
--index               index file
]]

if environment.argument("start") then
    scripts.webserver.run {
        port  = environment.argument("port")  or "8080",
        root  = environment.argument("root")  or ".",           -- "e:/websites/www.pragma-ade.com",
        index = environment.argument("index") or "index.html",
    }
else
    input.help(banner,messages.help)
end

if not modules then modules = { } end modules ['mtx-server-ctx-startup'] = {
    version   = 1.001,
    comment   = "Overview Of Goodies",
    author    = "Hans Hagen",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

dofile(resolvers.findfile("trac-lmx.lua","tex"))

function doit(configuration,filename,hashed)

    local list = { }
    local root = file.dirname(resolvers.findfile("mtx-server.lua") or ".")
    if root == "" then root = "." end
    local pattern = root .. "/mtx-server-ctx-*.lua"
    local files = dir.glob(pattern)
    for i=1,#files do
        local filename = file.basename(files[i])
        local name = string.match(filename,"mtx%-server%-ctx%-(.-)%.lua$")
        if name and name ~= "startup" then
            list[#list+1] = string.format("<a href='%s' target='ctx-%s'>%s</a><br/><br/>",filename,name,name)
        end
    end

    local variables = {
        ['color-background-one']    = lmx.get('color-background-green'),
        ['color-background-two']    = lmx.get('color-background-blue'),
        ['title']                   = "Overview Of Goodies",
        ['color-background-one']    = lmx.get('color-background-green'),
        ['color-background-two']    = lmx.get('color-background-blue'),
        ['maintext']                = table.concat(list,"\n"),
    }

    return  { content = lmx.convert('context-base.lmx',false,variables) }

end

return doit, true

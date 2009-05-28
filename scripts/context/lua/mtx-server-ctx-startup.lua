if not modules then modules = { } end modules ['mtx-server-ctx-startup'] = {
    version   = 1.001,
    comment   = "Overview Of Goodies",
    author    = "Hans Hagen",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

dofile(resolvers.find_file("trac-lmx.lua","tex"))

function doit(configuration,filename,hashed)

    lmx.restore()

    lmx.variables['color-background-green']  = '#4F6F6F'
    lmx.variables['color-background-blue']   = '#6F6F8F'
    lmx.variables['color-background-yellow'] = '#8F8F6F'
    lmx.variables['color-background-purple'] = '#8F6F8F'

    lmx.variables['color-background-body']   = '#808080'
    lmx.variables['color-background-main']   = '#3F3F3F'
    lmx.variables['color-background-one']    = lmx.variables['color-background-green']
    lmx.variables['color-background-two']    = lmx.variables['color-background-blue']

    lmx.variables['title']                   = "Overview Of Goodies"

    lmx.set('title',                lmx.get('title'))
    lmx.set('color-background-one', lmx.get('color-background-green'))
    lmx.set('color-background-two', lmx.get('color-background-blue'))


    local list = { }
    local root = file.dirname(resolvers.find_file("mtx-server.lua") or ".")
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

    lmx.set('maintext',table.concat(list,"\n"))

    result = { content = lmx.convert('context-base.lmx') }

    return result

end

return doit, true

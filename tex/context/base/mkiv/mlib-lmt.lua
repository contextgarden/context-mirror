if not modules then modules = { } end modules ['mlib-lmt'] = {
    version   = 1.001,
    comment   = "companion to mlib-ctx.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files",
}

-- todo: check for possible inject usage

local type = type

local aux          = mp.aux
local mpdirect     = aux.direct
local mppath       = mp.path

local scan         = mp.scan
local scannumeric  = scan.numeric
local scanpath     = scan.path

local getparameter = metapost.getparameter

function mp.lmt_function_x(xmin,xmax,xstep,code,shape) -- experimental
    local code      = "return function(x) return " .. code .. " end"
    local action    = load(code)
    local points    = { }
    local nofpoints = 0
    if action then
         action = action()
    end
    if shape == "steps" then
        local halfx     = xstep / 2
        local lastx     = xmin
        local lasty     = action(xmin)
        for xi = xmin, xmax, xstep do
            local yi  = action(xi)
            local xx  = lastx + halfx
            nofpoints = nofpoints + 1 ; points[nofpoints] = { xx, lasty }
            nofpoints = nofpoints + 1 ; points[nofpoints] = { xx, yi }
            lastx     = xi
            lasty     = yi
        end
        if points[nofpoints][1] ~= xmax then
            local yi  = action(xmax)
            local xx  = lastx + halfx
            nofpoints = nofpoints + 1 ; points[nofpoints] = { xx, lasty }
            nofpoints = nofpoints + 1 ; points[nofpoints] = { xx, yi }
            lastx     = xi
            lasty     = yi
        end
    else
        for xi = xmin, xmax, xstep do
            nofpoints = nofpoints + 1 ; points[nofpoints] = { xi, action(xi) }
        end
        if points[nofpoints][1] ~= xmax then
            nofpoints = nofpoints + 1 ; points[nofpoints] = { xmax, action(xmax) }
        end
    end
    mppath(points,shape == "curve" and ".." or "--",false)
end

function mp.lmt_mesh_set()
    local mesh = getparameter { "mesh", "paths" }
    structures.references.currentset.mesh = mesh
end

function mp.lmt_mesh_update()
    local mesh = getparameter { "paths" } or getparameter { "mesh", "paths" }
    mesh[scannumeric()] = scanpath(true)
end

-- moved here

function mp.lmt_svg_include()
    local labelfile = metapost.getparameter { "labelfile" }
    if labelfile and labelfile ~= "" then
        local labels = table.load(labelfile) -- todo: same path as svg file
        if type(labels) == "table" then
            for i=1,#labels do
                metapost.remaptext(labels[i])
            end
        end
    end
    local fontname = metapost.getparameter { "fontname" }
    if fontname and fontname ~= "" then
        local unicode = metapost.getparameter { "unicode" }
        if unicode then
            mpdirect (
                metapost.svgglyphtomp(fontname,math.round(unicode))
            )
        end
        return
    end
    local colorfile = metapost.getparameter { "colormap" }
    local colormap  = false
    if colorfile and colorfile ~= "" then
        colormap = metapost.svgcolorremapper(colorfile)
    end
    local filename = metapost.getparameter { "filename" }
    if filename and filename ~= "" then
        mpdirect ( metapost.svgtomp {
            data     = io.loaddata(filename),
            remap    = true,
            colormap = colormap,
            id       = filename,
        } )
    else
        local buffer = metapost.getparameter { "buffer" }
        if buffer then
            mpdirect ( metapost.svgtomp {
                data     = buffers.getcontent(buffer),
             -- remap    = true,
                colormap = colormap,
                id       = buffer or "buffer",
            } )
        else
            local code = metapost.getparameter { "code" }
            if code then
                mpdirect ( metapost.svgtomp {
                    data     = code,
                    colormap = colormap,
                    id       = "code",
                } )
            end
        end
    end
end


function mp.lmt_do_remaptext()
    local parameters = metapost.scanparameters()
    if parameters and parameters.label then
        metapost.remaptext(parameters)
    end
end

do

    local dropins        = fonts.dropins
    local registerglyphs = dropins.registerglyphs
    local registerglyph  = dropins.registerglyph

    function mp.lmt_register_glyph()
        registerglyph(metapost.getparameterset("mpsglyph"))
    end

    function mp.lmt_register_glyphs()
        registerglyphs(metapost.getparameterset("mpsglyphs"))
    end

end

todecimal = xdecimal and xdecimal.new or tonumber -- bonus
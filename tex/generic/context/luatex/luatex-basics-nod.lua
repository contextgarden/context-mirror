if not modules then modules = { } end modules ['luatex-fonts-nod'] = {
    version   = 1.001,
    comment   = "companion to luatex-fonts.lua",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

if context then
    texio.write_nl("fatal error: this module is not for context")
    os.exit()
end

-- Don't depend on code here as it is only needed to complement the
-- font handler code.

-- Attributes:

if tex.attribute[0] ~= 0 then

    texio.write_nl("log","!")
    texio.write_nl("log","! Attribute 0 is reserved for ConTeXt's font feature management and has to be")
    texio.write_nl("log","! set to zero. Also, some attributes in the range 1-255 are used for special")
    texio.write_nl("log","! purposes so setting them at the TeX end might break the font handler.")
    texio.write_nl("log","!")

    tex.attribute[0] = 0 -- else no features

end

attributes            = attributes or { }
attributes.unsetvalue = -0x7FFFFFFF

local numbers, last = { }, 127

attributes.private = attributes.private or function(name)
    local number = numbers[name]
    if not number then
        if last < 255 then
            last = last + 1
        end
        number = last
        numbers[name] = number
    end
    return number
end

-- Nodes:

nodes              = { }
nodes.pool         = { }
nodes.handlers     = { }

local nodecodes    = { } for k,v in next, node.types   () do nodecodes[string.gsub(v,"_","")] = k end
local whatcodes    = { } for k,v in next, node.whatsits() do whatcodes[string.gsub(v,"_","")] = k end
local glyphcodes   = { [0] = "character", "glyph", "ligature", "ghost", "left", "right" }

nodes.nodecodes    = nodecodes
nodes.whatcodes    = whatcodes
nodes.whatsitcodes = whatcodes
nodes.glyphcodes   = glyphcodes

local free_node    = node.free
local remove_node  = node.remove
local new_node     = node.new
local traverse_id  = node.traverse_id

local math_code    = nodecodes.math

nodes.handlers.protectglyphs   = node.protect_glyphs
nodes.handlers.unprotectglyphs = node.unprotect_glyphs

function nodes.remove(head, current, free_too)
   local t = current
   head, current = remove_node(head,current)
   if t then
        if free_too then
            free_node(t)
            t = nil
        else
            t.next, t.prev = nil, nil
        end
   end
   return head, current, t
end

function nodes.delete(head,current)
    return nodes.remove(head,current,true)
end

function nodes.pool.kern(k)
    local n = new_node("kern",1)
    n.kern = k
    return n
end

-- experimental

local getfield = node.getfield or function(n,tag)       return n[tag]  end end
local setfield = node.setfield or function(n,tag,value) n[tag] = value end end

nodes.getfield = getfield
nodes.setfield = setfield

nodes.getattr  = getfield
nodes.setattr  = setfield

if node.getid      then nodes.getid      = node.getid      else function nodes.getid     (n) return getfield(n,"id")      end end
if node.getsubtype then nodes.getsubtype = node.getsubtype else function nodes.getsubtype(n) return getfield(n,"subtype") end end
if node.getnext    then nodes.getnext    = node.getnext    else function nodes.getnext   (n) return getfield(n,"next")    end end
if node.getprev    then nodes.getprev    = node.getprev    else function nodes.getprev   (n) return getfield(n,"prev")    end end
if node.getchar    then nodes.getchar    = node.getchar    else function nodes.getchar   (n) return getfield(n,"char")    end end
if node.getfont    then nodes.getfont    = node.getfont    else function nodes.getfont   (n) return getfield(n,"font")    end end
if node.getlist    then nodes.getlist    = node.getlist    else function nodes.getlist   (n) return getfield(n,"list")    end end

function nodes.tonut (n) return n end
function nodes.tonode(n) return n end

nodes.nuts = nodes -- we stay nodes

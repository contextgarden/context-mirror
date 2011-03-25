if not modules then modules = { } end modules ['scrn-fld'] = {
    version   = 1.001,
    comment   = "companion to scrn-fld.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- we should move some code from lpdf-fld to here

local fields        = { }
interactions.fields = fields

local codeinjections = backends.codeinjections
local nodeinjections = backends.nodeinjections

local function define(specification)
    codeinjections.definefield(specification)
end

local function defineset(name,set)
    codeinjections.definefield(name,set)
end

local function clone(specification)
    codeinjections.clonefield(specification)
end

local function insert(name,specification)
    return nodeinjections.typesetfield(name,specification)
end

fields.define    = define
fields.defineset = defineset
fields.clone     = clone
fields.insert    = insert

commands.definefield    = define
commands.definefieldset = defineset
commands.clonefield     = clone

function commands.insertfield(name,specification)
    tex.box["scrn_field_box_body"] = insert(name,specification)
end

-- (for the monent) only tex interface

function commands.getfieldcategory(name)
    local g = codeinjections.getfieldcategory(name)
    if g then
        context(g)
    end
end

function commands.getdefaultfieldvalue(name)
    local d = codeinjections.getdefaultfieldvalue(name)
    if d then
        context(d)
    end
end

function commands.setformsmethod(method)
    codeinjections.setformsmethod(method)
end

function commands.doiffieldcategoryelse(name)
    commands.testcase(codeinjections.validfieldcategory(name))
end

function commands.doiffieldsetelse(tag)
    commands.testcase(codeinjections.validfieldset(name))
end

function commands.doiffieldelse(name)
    commands.testcase(codeinjections.validfield(name))
end

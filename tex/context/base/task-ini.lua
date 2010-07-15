if not modules then modules = { } end modules ['task-ini'] = {
    version   = 1.001,
    comment   = "companion to task-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- this is a temporary solution, we need to isolate some modules and then
-- the load order can determine the trickery to be applied to node lists
--
-- we can disable more handlers and enable then when really used (*)

tasks.appendaction("processors", "normalizers", "fonts.collections.process")                 -- todo
tasks.appendaction("processors", "normalizers", "fonts.checkers.missing")                    -- disabled

tasks.appendaction("processors", "characters",  "chars.handle_mirroring")                    -- disabled
tasks.appendaction("processors", "characters",  "typesetting.cases.handler")                 -- disabled
tasks.appendaction("processors", "characters",  "typesetting.breakpoints.handler")           -- disabled
tasks.appendaction("processors", "characters",  "scripts.preprocess")

tasks.appendaction("processors", "words",       "kernel.hyphenation")                        -- always on
tasks.appendaction("processors", "words",       "languages.words.check")                     -- disabled

tasks.appendaction("processors", "fonts",       "parbuilders.solutions.splitters.split")     -- experimental
tasks.appendaction("processors", "fonts",       "nodes.process_characters")                  -- maybe todo
tasks.appendaction("processors", "fonts",       "nodes.inject_kerns")                        -- maybe todo
tasks.appendaction("processors", "fonts",       "nodes.protect_glyphs", nil, "nohead")       -- maybe todo
tasks.appendaction("processors", "fonts",       "kernel.ligaturing")                         -- always on
tasks.appendaction("processors", "fonts",       "kernel.kerning")                            -- always on
tasks.appendaction("processors", "fonts",       "nodes.stripping.process")                   -- disabled (might move)

tasks.appendaction("processors", "lists",       "typesetting.spacings.handler")              -- disabled
tasks.appendaction("processors", "lists",       "typesetting.kerns.handler")                 -- disabled
tasks.appendaction("processors", "lists",       "typesetting.digits.handler")                -- disabled (after otf handling)

tasks.appendaction("shipouts",   "normalizers", "nodes.cleanup_page")                        -- maybe todo
tasks.appendaction("shipouts",   "normalizers", "nodes.add_references")                      -- disabled
tasks.appendaction("shipouts",   "normalizers", "nodes.add_destinations")                    -- disabled
tasks.appendaction("shipouts",   "normalizers", "nodes.rules.process")                       -- disabled
tasks.appendaction("shipouts",   "normalizers", "nodes.shifts.process")                      -- disabled

tasks.appendaction("shipouts",   "finishers",   "shipouts.handle_color")                     -- disabled
tasks.appendaction("shipouts",   "finishers",   "shipouts.handle_transparency")              -- disabled
tasks.appendaction("shipouts",   "finishers",   "shipouts.handle_colorintent")               -- disabled
tasks.appendaction("shipouts",   "finishers",   "shipouts.handle_negative")                  -- disabled
tasks.appendaction("shipouts",   "finishers",   "shipouts.handle_effect")                    -- disabled
tasks.appendaction("shipouts",   "finishers",   "shipouts.handle_viewerlayer")               -- disabled

tasks.appendaction("math",       "normalizers", "noads.relocate_characters", nil, "nohead")  -- always on
tasks.appendaction("math",       "normalizers", "noads.resize_characters",   nil, "nohead")  -- always on
tasks.appendaction("math",       "normalizers", "noads.respace_characters",  nil, "nohead")  -- always on

tasks.appendaction("math",       "builders",    "noads.mlist_to_hlist")                      -- always on

-- quite experimental

tasks.appendaction("finalizers", "lists",       "nodes.repackage_graphicvadjust")            -- todo
tasks.appendaction("finalizers", "fonts",       "parbuilders.solutions.splitters.optimize")  -- experimental

-- rather new

tasks.appendaction("mvlbuilders", "normalizers", "nodes.migrate_outwards")
tasks.appendaction("mvlbuilders", "normalizers", "nodes.handle_page_spacing") -- last !

tasks.appendaction("vboxbuilders", "normalizers", "nodes.handle_vbox_spacing")

-- speedup: only kick in when used

tasks.disableaction("processors",  "fonts.checkers.missing")
tasks.disableaction("processors",  "chars.handle_breakpoints")
tasks.disableaction("processors",  "typesetting.cases.handler")
tasks.disableaction("processors",  "typesetting.digits.handler")
tasks.disableaction("processors",  "typesetting.breakpoints.handler")
tasks.disableaction("processors",  "chars.handle_mirroring")
tasks.disableaction("processors",  "languages.words.check")
tasks.disableaction("processors",  "typesetting.spacings.handler")
tasks.disableaction("processors",  "typesetting.kerns.handler")
tasks.disableaction("processors",  "nodes.stripping.process")

tasks.disableaction("shipouts",    "nodes.rules.process")
tasks.disableaction("shipouts",    "nodes.shifts.process")
tasks.disableaction("shipouts",    "shipouts.handle_color")
tasks.disableaction("shipouts",    "shipouts.handle_transparency")
tasks.disableaction("shipouts",    "shipouts.handle_colorintent")
tasks.disableaction("shipouts",    "shipouts.handle_effect")
tasks.disableaction("shipouts",    "shipouts.handle_negative")
tasks.disableaction("shipouts",    "shipouts.handle_viewerlayer")

tasks.disableaction("shipouts",    "nodes.add_references")
tasks.disableaction("shipouts",    "nodes.add_destinations")

tasks.disableaction("mvlbuilders", "nodes.migrate_outwards")

tasks.disableaction("processors",  "parbuilders.solutions.splitters.split")
tasks.disableaction("finalizers",  "parbuilders.solutions.splitters.optimize")

callbacks.freeze("find_.*_file", "find file using resolver")
callbacks.freeze("read_.*_file", "read file at once")
callbacks.freeze("open_.*_file", "open file for reading")

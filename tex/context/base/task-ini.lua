if not modules then modules = { } end modules ['task-ini'] = {
    version   = 1.001,
    comment   = "companion to task-ini.tex",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- this is a temporary solution, we need to isolate some modules and then
-- the load order can determine the trickery to be applied to node lists

tasks.appendaction("processors", "normalizers", "fonts.collections.process")
tasks.appendaction("processors", "normalizers", "fonts.checkers.missing")

tasks.appendaction("processors", "characters",  "chars.handle_mirroring")
tasks.appendaction("processors", "characters",  "chars.handle_casing")
tasks.appendaction("processors", "characters",  "chars.handle_breakpoints")
tasks.appendaction("processors", "characters",  "scripts.preprocess")

tasks.appendaction("processors", "words",       "kernel.hyphenation")
tasks.appendaction("processors", "words",       "languages.words.check")

tasks.appendaction("processors", "fonts",       "nodes.process_characters")
tasks.appendaction("processors", "fonts",       "nodes.inject_kerns")
tasks.appendaction("processors", "fonts",       "nodes.protect_glyphs", nil, "nohead")
tasks.appendaction("processors", "fonts",       "kernel.ligaturing")
tasks.appendaction("processors", "fonts",       "kernel.kerning")

tasks.appendaction("processors", "lists",       "lists.handle_spacing")
tasks.appendaction("processors", "lists",       "lists.handle_kerning")

tasks.appendaction("shipouts",   "normalizers", "nodes.cleanup_page")
tasks.appendaction("shipouts",   "normalizers", "nodes.add_references")
tasks.appendaction("shipouts",   "normalizers", "nodes.add_destinations")

tasks.appendaction("shipouts",   "finishers",   "shipouts.handle_color")
tasks.appendaction("shipouts",   "finishers",   "shipouts.handle_transparency")
tasks.appendaction("shipouts",   "finishers",   "shipouts.handle_overprint")
tasks.appendaction("shipouts",   "finishers",   "shipouts.handle_negative")
tasks.appendaction("shipouts",   "finishers",   "shipouts.handle_effect")
tasks.appendaction("shipouts",   "finishers",   "shipouts.handle_viewerlayer")

tasks.appendaction("math",       "normalizers", "noads.relocate_characters", nil, "nohead")
tasks.appendaction("math",       "normalizers", "noads.resize_characters", nil, "nohead")
tasks.appendaction("math",       "normalizers", "noads.respace_characters", nil, "nohead")

tasks.appendaction("math",       "builders",    "noads.mlist_to_hlist")

-- quite experimental

tasks.appendaction("finalizers", "lists",       "nodes.repackage_graphicvadjust")

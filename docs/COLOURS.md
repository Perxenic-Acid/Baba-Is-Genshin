# Colour filter backend (M9.5K)

User direction: color properties are stacked filters; frontend binding is deferred.
Installed primary source: Data/blocks.lua effectblock 7-45 and 74-137 lists the
fifteen named colours and palette coordinates in canonical order. The original
presentation cycles multiple palette colours; our future stacked-filter frontend
is an explicit user-requested adaptation, not a claim of that visual behavior.

All fifteen words parse and lower as ordinary rule properties, including NOT,
conditions, GROUP/MIMIC and scoped LEVEL under their existing scope limits. The
projection exposes entity.colour_filters, empty-cell colour_filters and
level_colour_filters, ordered records {name, palette={column,row}}. Distinct
active colors coexist; repeated declarations of one color produce one filter,
matching original Boolean color selection. Palette entries are semantic references,
not invented RGB values; final host palette/texture blend selection belongs to the
separate frontend workstream. No final RGB composition or renderer binding is
claimed as implemented by this backend change.

Filters are derived afresh on each projection, clear when rules retract, and are
not authoritative world/Undo facts. Tests cover all names/coordinates, ordering,
duplicates, denial/retraction, scoped LEVEL, MORE birth isolation and Undo. Full
regressions pass; native acceptance is not inferred. 3D is excluded by user request.

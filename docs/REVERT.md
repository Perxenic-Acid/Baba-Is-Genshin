# REVERT prerequisites (M9.6I)

## Primary references

Installed Data/syntax.lua addunit() initializes unit.originalname to concrete
UNITNAME. Data/convert.lua conversion() filters REVERT when the current concrete
name already equals originalname; doconvert() resolves that original name,
propagates it to every conversion product, and uses empty provenance for virtual
EMPTY conversion. Data/syntax.lua createall() also propagates the source origin.
Data/tools.lua copy() calls create(), whose addunit() initializes a fresh origin;
ordinary MORE copies therefore start at their own current concrete name, unlike
conversion products. HAS/MAKE births likewise start a fresh lineage.

## Intrinsic origin infrastructure implemented

`original_name` is optional intrinsic entity data. Its omission means the unit's
current concrete name (`archetype`, or `text_` plus the physical Text token name).
`RW_GetOriginalName(entity)` provides that effective name. Text names use this
engine's canonical token casing; the virtual EMPTY conversion origin is `@empty`.

Before a transform/retype changes concrete type, the original effective name is
saved and subsequently retained. Duplicate conversion products inherit it,
including TEXT/WRITE/BECOME/ALL paths. Original physical Text can therefore be
distinguished from objects converted into Text. Scoped LEVEL product groups keep
entrance provenance, including persistent boundary reloads and legacy records.
Newborn HAS/MORE/MAKE retain their own effective origin unless explicitly created
as conversion products. This adds no normal-start initialization pass.

Creation validates the field's shape. Retype cannot supply a different origin;
Preview and Commit apply the same preservation rule. Ordinary movement, facing,
status changes and whole-tree Undo preserve/restore intrinsic provenance. Tests
cover repeated and duplicate IS/TEXT/WRITE/BECOME conversion, physical Text,
HAS/MORE reset, invalid data, immutable retype, Preview/Commit/Undo, and execute
the installed conversion provenance assignment unchanged.

## Not yet implemented

REVERT remains pending in the official catalog. Public parsing/lowering,
conversion target selection and same-name suppression, EMPTY removal semantics,
scoped LEVEL reversion and interaction with competing/negative conversions still
need implementation and source-oracle tests. Origin tracking alone is not REVERT.
BACK remains a separate pending subsystem: it indexes historical per-unit changes
and conversion creation/removal pairs, rather than restoring original type.

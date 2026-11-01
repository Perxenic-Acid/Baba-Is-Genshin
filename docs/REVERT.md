# REVERT progress (M9.6K)

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

## Conversion implemented in M9.6J

Public REVERT is registered as the installed quality/property token. Ordinary
`A IS REVERT` lowers both its property declaration (for FEELING/MIMIC/GROUP and
negative declaration queries) and an indirect `@revert` conversion target.
Conditions, NOT and left-side expansions reuse the normal compiler/relations.
Physical Text and physical level blocks can revert; destination links remain
identity-bound through retyping. WRITE REVERT writes that literal Text token.

Installed conversion() inserts REVERT declarations before ordinary products;
convert() stops collecting after the first effective revert. We preserve that
priority and collapse effective duplicate REVERTs to one product. An unchanged
original name produces nothing and does not prevent other ordinary conversions.
IS identity protection and NOT REVERT suppress IS REVERT; a ban on the concrete
original noun is not a ban on the indirect REVERT target. Return to an original
Text uses identity-preserving retype; return to EMPTY deletes without HAS.
Virtual EMPTY IS REVERT produces no persistent units or allocator activity.
The normal conversion status initialization, terminal handling and Undo apply.

The installed BECOME editor entry has noun arguments (rules.lua defaults argtype
{0}); REVERT is type 2. Do not expand BECOME syntax to accept arbitrary properties.
The prepared conversion IR retains its existing verb handling, but the physical
BECOME REVERT sentence is not accepted by the parser. This differs from WRITE's
explicit user-requested syntax-word-literal extension.

Tests execute installed convert() unchanged for 96 combinations of original
name, duplicate REVERT/ordinary targets and condition applicability, comparing
selected products. Additional public-pipeline tests cover conditions/NOT/BROKEN,
identity protection, Text/EMPTY, GROUP/MIMIC/ALL, physical LEVEL links, RHS AND,
WRITE literals, source purity and Undo. The oracle covers product collection,
not the native MF_emptycreate/remove host implementation. Native success is not
inferred.

## Scoped entrance reversion (M9.6K)

Installed dolevelconversions() selects the first eligible REVERT, discards other
LEVEL products, removes the corresponding saved conversion record, then returns
to the upper level. It restores authored map data; it does not look up an
individual transformed unit's originalname. This backend follows that distinction.

Unconditional scoped REVERT is selected from the resolved LEVEL trait frame, so
NOT REVERT, identity protection and scoped BROKEN retain their existing gating.
It takes conversion precedence over other scoped targets and terminal outcomes.
`RW_RecordLevelOutcome(..., "revert")` resolves the entered product's tracked source,
removes its saved source conversion, retires the entire duplicate product group,
and reloads authored parent runtime plus other persistent conversions/results.
Retired IDs retain tombstones/allocator reservation. The child entry is rebound to
the surviving authored source, including entry through an allocated copy. Even
an unconverted entrance returns to its parent, matching the original save-removal
branch. Ordinary contact destruction/HAS is not involved.

One outer Commit and whole-tree Undo include the completed child turn, result,
parent reload, product retirements, entry identity and allocators. Tests cover
multiple products, non-Level authored entrance shapes/links, copy entry, sibling
persistence, runtime reset, tombstone reload, NOT/identity/BROKEN, conversion versus
terminal precedence and rejected missing provenance. The installed scoped selection
loop executes unchanged for 48 count/order/condition combinations; its native save
I/O and general 50-product terminal limit are outside this selection oracle.

## Remaining scope

Conditional scoped LEVEL evaluation retains its existing subsystem gap. Root
rooms without a parent entrance use the existing no_parent_level_block rejection;
runtime-only entrances lacking an authored origin reject missing_authored_level_origin
without changing progress. Arbitrary metadata must not invent missing history.
The dolevelconversions() >=50 ordinary-product TOO COMPLEX boundary is implemented
at level dispatch (M9.6L); an effective REVERT preempts such product lists.
Exact self-negated conversion/native host failure interactions and AUTO boundary
dispatch retain the documented shared engine limits. Native success is not inferred.

BACK remains a separate pending subsystem: it indexes historical per-unit changes
and conversion creation/removal pairs, rather than restoring original type.

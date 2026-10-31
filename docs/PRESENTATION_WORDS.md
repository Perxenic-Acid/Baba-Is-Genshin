# Presentation-only property backend (M9.6B)

Original primary reference: Data/effects.lua effects(), shorteffectblock(),
doeffect() and doshorteffect(). Core Data Lua search excludes Worlds/mods.
ANGRY/HAPPY/SAD/WONDER/BEST/PET are recurring particle declarations; PARTY invokes
short-effect confetti. BEST's glasses decoration is commented out in the original.
They add no ordinary collision, movement or victory behavior.

The seven public properties now use the normal compiler/projection registry.
AND stacking, NOT cancellation, conditional grants, MIMIC, GROUP and FEELING use
the same property semantics as other declarations; BROKEN disables their grants.
They remain independently queryable capabilities rather than aliases for color.

RW_GetPresentationEffectCatalog returns a deep-cloned description of the original
particle, count, chance/timing/palette and PET no-jitter/follow settings. PARTY's
short-effect trigger, velocity intervals and palette choices are distinct records.
Tests execute the original effects()/shorteffectblock() declarations with callbacks
and compare all seven catalog entries to their actual arguments.

No particle clock, camera-space placement, transient emitter, PARTY playback,
visibility filtering or native drawing is bound here. Those belong to the deferred
frontend. Original duplicate-declaration emission counts and scoped LEVEL/EMPTY
particle placement also remain frontend responsibilities. Querying capabilities
or the catalog consumes no simulation RNG and does not persist presentation facts
in the authored world or Undo. Official audit explicitly labels frontend deferral;
this is backend completion, not visual feature completion.

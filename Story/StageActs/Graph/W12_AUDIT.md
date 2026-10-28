# W12 story / runtime audit

57 passages; 103 authored links; 27 speech-bearing beats in the source. Three retain earlier forced-continuation overrides, explicitly listed below.

The original Twine remains unchanged. The cleaned working copy is the import source. The CSV beside this file contains every interactive beat with all requested audit fields.

## Saved graph disagreements repaired

The saved graph lacked the entrance off-script branch and the two follow-up passages. It also used older Mother passage IDs and a Mother choice label. Current Twine routes and Actor 1 IDs are restored. The saved graph was backed up before replacement. Editor positions were recovered by actual passage identity, not stale numeric manifest IDs.

## Narrative decisions still yours

- **A1_0_NoAgain** — Runtime continue_route=1 skips the Yes/other interaction; retained prior forced-start behavior, differs from Twine. Decide whether this beat is forced or interactive.
- **A1_3_Offscript** — Runtime continue_route=0 forces the scripted MC continuation despite an extra spoken branch in Twine. Decide whether player may interrupt.
- **A1_3_ThirdFailure** — Runtime continue_route=0 forces Watch the show; authored silence route remains in graph but is not listened for here.
- **A1_1_ACTOR 1'sQuestion** — No successful exact-answer branch is authored here. All ambitions enter WrongLine; this is the existing story, not an AI error.
- **A1_4_SecondCue** — Cue says Don't underestimate me ACTOR 1; next authored MC speech is I'll be fine. Older author note names a third cue. Needs your writing decision.
- **A2_0_DeclarationDay** — Older author note says tomorrow versus one month; current Act 1 already says one month. Note appears stale. Cue grammar NEITHER DO I. IT GET A LITTLE NERVOUS is meaning-sensitive; left unchanged.
- **A2_1_OffscriptAgain** — Authored third unrelated reply goes directly to Endgame, independently of global threshold 5. Preserved and flagged.
- **A2_2_HallCommentAppropriate** — All four choices mean agreement. No authored refusal or delay. No stays at a safe fallback; no invented agreement.
- **A2_2_HallCommentAwkward** — An unrelated reply leads to the same music-start outcome as agreement. Author note incorrectly says all four answers mean agree.
- **A2_2_SecondMisleading** — Authored third unrelated comment ends the story independently of global threshold 5.
- **A2_4_CallSomeone** — Dialogue/cue asks for Chief, but prose says cue does not specify who; choices allow any name. Preserved.
- **A2_6_ScriptChange** — Old note says all answers lead to Decline; current four links are distinct. Authored uncertainty is a real intent, not interpreter uncertainty.
- **A2_7_Agree** — After Yes, Actor 1 replies No? This is authored text, not a classification error.
- **A3_2_FirstQuestion** — Uncertainty and unrelated speech share one destination. No conditional prior-answer variants are authored as links.
- **A3_2_No** — Author notes propose prior-answer-dependent dialogue; current graph has one fixed response. Not implemented as invented branches.
- **A3_2_Yes** — Author notes propose prior-answer-dependent dialogue; current graph has one fixed response.
- **A3_2_Unclear** — Author notes propose prior-answer-dependent dialogue; current graph has one fixed response.
- **\ A1_4_Offscript** — Leading backslash ID; no incoming route in source. Preserved, not renamed or removed.
- **A1_0_Begin** — Unlabelled Without further ado / Let the show begin continuation made explicit Stage Manager speech. Standalone Bang remains narration; decide if it should be sound-only.

## Interaction overview

| Passage | Task | Authored intents | Production | Review |
|---|---|---|---|---|
| A1_0_Begin | Respond to the current scene. | yes = Yes.; no = No. | None explicitly typed | Unlabelled Without further ado / Let the show begin continuation made explicit Stage Manager speech. Standalone Bang remains narration; decide if it should be sound-only. |
| A1_0_No | Respond to the current scene. | yes = Yes.; no = Not yet. | None explicitly typed | No extra branch invented; unavailable visuals/audio remain production placeholders. |
| A1_0_NoAgain | Respond to the current scene. | yes = Yes | sound, stage | Runtime continue_route=1 skips the Yes/other interaction; retained prior forced-start behavior, differs from Twine. Decide whether this beat is forced or interactive. |
| A1_0_STH | Respond to the current scene. | no = No.; yes = Yes. | sound, stage | No extra branch invented; unavailable visuals/audio remain production placeholders. |
| A1_1_ACTOR 1'sQuestion | what would you say | ambition = Mention her dream. | stage | No successful exact-answer branch is authored here. All ambitions enter WrongLine; this is the existing story, not an AI error. |
| A1_1_Offtopic | Respond to the current scene. | other = Try another response. | None explicitly typed | No extra branch invented; unavailable visuals/audio remain production placeholders. |
| A1_1_Silence | Respond to the current scene. | other = Try to say something. | None explicitly typed | No extra branch invented; unavailable visuals/audio remain production placeholders. |
| A1_1_WrongLine | Respond to the current scene. | other = Try another response. | None explicitly typed | No extra branch invented; unavailable visuals/audio remain production placeholders. |
| A1_2_SecondFailure | Read the phone cue aloud. | cue = Read the cue card aloud. | phone | No extra branch invented; unavailable visuals/audio remain production placeholders. |
| A1_3_FirstCue | Read the phone cue aloud. | cue = Read the next line. | phone | No extra branch invented; unavailable visuals/audio remain production placeholders. |
| A1_3_Offscript | Respond to the current scene. |  | phone | Runtime continue_route=0 forces the scripted MC continuation despite an extra spoken branch in Twine. Decide whether player may interrupt. |
| A1_3_ThirdFailure | Respond to the current scene. |  | phone | Runtime continue_route=0 forces Watch the show; authored silence route remains in graph but is not listened for here. |
| A1_4_Offscript | Read the phone cue aloud. | cue = Read the next line. | phone, stage | No extra branch invented; unavailable visuals/audio remain production placeholders. |
| A1_4_SecondCue | Read the phone cue aloud. | cue = Read the line. | phone | Cue says Don't underestimate me ACTOR 1; next authored MC speech is I'll be fine. Older author note names a third cue. Needs your writing decision. |
| A2_0_DeclarationDay | Read the phone cue aloud. | choice_0 = Read the cue. | phone, stage | Older author note says tomorrow versus one month; current Act 1 already says one month. Note appears stale. Cue grammar NEITHER DO I. IT GET A LITTLE NERVOUS is meaning-sensitive; left unchanged. |
| A2_1_Entrance | Choose an entrance verbally. | choice_0 = Left.; choice_1 = Right. | phone | No extra branch invented; unavailable visuals/audio remain production placeholders. |
| A2_1_Offscript | Choose an entrance verbally. | choice_0 = Left.; choice_1 = Right. | phone | No extra branch invented; unavailable visuals/audio remain production placeholders. |
| A2_1_OffscriptAgain | Choose an entrance verbally. | choice_0 = Left.; choice_1 = Right. | phone | Authored third unrelated reply goes directly to Endgame, independently of global threshold 5. Preserved and flagged. |
| A2_2_Hall | Comment on the hall or the people gathered there. | choice_0 = Say something about the hall; choice_1 = Say something about the hall but out of context, weird comment | phone | No extra branch invented; unavailable visuals/audio remain production placeholders. |
| A2_2_HallCommentAppropriate | Respond to the current scene. | choice_0 = Yes.; choice_1 = Go ahead.; choice_2 = Let them begin.; choice_3 = Sure, why not? | phone | All four choices mean agreement. No authored refusal or delay. No stays at a safe fallback; no invented agreement. |
| A2_2_HallCommentAwkward | Respond to the current scene. | choice_0 = Yes.; choice_1 = Agree in a way that breaks the scene.; choice_3 = Sure, why not? | phone | An unrelated reply leads to the same music-start outcome as agreement. Author note incorrectly says all four answers mean agree. |
| A2_2_Misleading | Respond to the current scene. | choice_0 = Say something about the hall; choice_1 = Say something about the hall but out of context, weird comment | None explicitly typed | No extra branch invented; unavailable visuals/audio remain production placeholders. |
| A2_2_SecondMisleading | Respond to the current scene. | choice_0 = Say something about the hall; choice_1 = Say something about the hall but out of context, weird comment | None explicitly typed | Authored third unrelated comment ends the story independently of global threshold 5. |
| A2_4_CallSomeone | Respond to the current scene. | choice_0 = James! Could you bring the scroll?; choice_1 = Call out a name of your own.; choice_2 = CALL CHIEF | phone | Dialogue/cue asks for Chief, but prose says cue does not specify who; choices allow any name. Preserved. |
| A2_6_ScriptChange | Respond to the current scene. | choice_0 = No.; choice_1 = Yes.; choice_2 = I'm not sure anymore.; choice_3 = I've changed my mind. | phone | Old note says all answers lead to Decline; current four links are distinct. Authored uncertainty is a real intent, not interpreter uncertainty. |
| A3_2_FirstQuestion | Respond to the current scene. | choice_0 = Yes.; choice_1 = No.; choice_2 = I don't know. | None explicitly typed | Uncertainty and unrelated speech share one destination. No conditional prior-answer variants are authored as links. |
| A3_4_Conflict | Respond to the current scene. | choice_0 = Follow ACTOR 1 and continue the ceremony.; choice_1 = Respond to Actor 2.; choice_2 = Say something neither of them expected. | None explicitly typed | No extra branch invented; unavailable visuals/audio remain production placeholders. |

## Safe grammar boundary

Only a conservative list of obvious spelling/grammar changes was applied in the working copy. Speech personality, exaggerated spellings, plot, endings and route destinations remain. Ambiguous dialogue such as “the path you roles”, “What the ACTOR 1?”, and the ACTOR 1 address inside quoted lines is preserved for the author. Unmarked prose remains narration; decide later which descriptions should instead be stage events. Production notes embedded in the existing STAGE blocks stay hidden.

The existing Twine off-script widget still demonstrates older link-counter behavior. Godot ignores those legacy increments: only deliberate OFFSCRIPT changes its counter. Twine preview therefore is not a simulation of the current response policy.

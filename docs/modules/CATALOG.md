# v0ca. — Modules: the candidate list

Concept and rules: `OVERVIEW.md`. Order of the refactoring work: `PLAN.md`.
This file is the *what*: the modules we actually want, why each one is a module
rather than a setting, and what it needs before it can be built.

Nothing here is committed to a release. The list exists so that the Modules
screen has something real to show, and so that the seams we cut in `PLAN.md` are
cut in the right places.

## Where a module plugs in

Four hook points cover everything below. Only the last one exists today.

1. **Before recognition** — what gets recorded and with which hints. Audio
   source, dictionary terms handed to the model.
2. **After recognition, before insertion** — the post-processing chain the
   transcript is passed through. *Does not exist yet.* Several modules need it,
   so it is the first thing to build: a list of `(String) -> String` steps
   between `RecordingCoordinator.finish()` and the insertion. Rule from the
   mockup: the chain rewrites the **inserted** text, the history keeps the raw
   one.
3. **Around a provider call** — everything between "we have a question" and "we
   have an answer": what is stripped out, what context is added, which model is
   picked, how the image is packed.
4. **Alongside** — features that observe and display, touching nothing in the
   loop: stats, achievements, benchmarks.

## The list

### 1. Extended stats and achievements

More of what the app already counts: transcriptions, recording time, AI
requests, feature usage, activity streaks, personal bests, achievements.

**Mostly built already** — `StatsStore` keeps per-day words, characters,
seconds, hourly distribution and bests; `AchievementsStore` persists only the
flags that cannot be derived; the Stats tab and the shelf are in place. What is
left is coverage of the newer features and whatever the module switch should do
when it is off (hide the tab, keep the data). Local, hook 4.

### 2. Local RAG / knowledge base

A local store of the user's documents, notes and instructions. On an AI request
the app finds the relevant pieces locally and adds them to the context.

The largest item on the list by a wide margin: storage, chunking, an embedding
model, an index, its own UI, and a hook inside the question flow. `OVERVIEW.md`
argues it is a feature rather than a module; if it ships as a module, the switch
has to cover the indexing too, not just the retrieval. Local index, but it feeds
a network call. Hooks 3 and 4.

### 3. Privacy filter

Find and mask sensitive data — API keys, emails, phone numbers, passwords,
tokens — locally, before anything is sent to a provider.

The one module that must be **impossible to bypass** when it is on: it sits in
front of every provider call, including the ones added later. Worth designing as
a chokepoint in `ProviderClient` rather than a step someone can forget to call.
Open question: does the answer get the masked values substituted back, and what
happens when masking breaks the question's meaning. Local, hook 3.

### 4. Clean transcription

An extra processing pass over the finished transcript: repetitions, fillers,
slips and stray fragments out, punctuation improved — raw speech into clean text.

This is the mockup's auto-punctuation and speech-cleanup entries merged, and the main
customer for hook 2. Decide early whether it is rules or a model: rules are
instant and offline, a model is better and drags in a provider. The mockup
promises both offline and no slowdown, which points at rules first.
Hook 2.

### 5. Personal dictionary

Names, project names, professional terms and brands the recognition model gets
wrong — Playwright, KADR, Jira.

Already on the roadmap (`docs/PLAN.md`, stage 3) as hint terms for the model.
Two possible implementations, and they are not equivalent: terms fed to the
engine before recognition (hook 1, Whisper prompt tokens) or replacements
applied after it (hook 2). The first is better and not available on every
engine; the second always works. Probably both. Local.

### 6. Temporary session context / chats

Short-lived AI sessions where follow-up questions carry the previous messages,
so a discussion can continue without re-explaining.

Needs `AskSession` to hold a transcript of the exchange and a visible lifetime
for it — when does a session start, when does it end, does it survive the bubble
closing. Depends on Providers. Cost note: context grows with every turn, and the
user pays for it. Hook 3.

### 7. System audio transcription

Transcribe the computer's own output, not just the microphone: calls, Meet,
Zoom, YouTube, video, recordings.

Changes the audio source, so hook 1. On macOS 14+ this means Core Audio process
taps or ScreenCaptureKit audio, plus its own permission and its own visible
indicator — recording what the machine plays is a different promise from
recording what the user says, and the UI has to say so. Local.

### 8. Speaker recognition / diarization

Split the transcript by participant — Speaker 1, Speaker 2 — for system audio
and meetings.

Only makes sense together with 7. FluidAudio is the engine to check first: if it
ships diarization models, this is model plumbing; if not, it is a research
project. The history record and its UI would need to hold structured turns
rather than one string. Local, hooks 1–2.

### 9. Personal correction memory

Remember what the user keeps fixing — a mangled "play rite" into "Playwright" — and apply it
automatically afterwards.

The learned half of 5, and it should share storage with it: one list, some
entries typed by hand, some observed. Needs a source of corrections, which the
app does not currently have — nothing tracks what the user edits after
insertion. That signal has to be designed before the module can exist. Local,
hook 2.

### 10. AI model router

Pick the model per request: a screenshot goes to a vision model, a short text
question to a fast cheap one, a hard task to a strong one.

Today the model per mode is chosen by hand on the Providers tab; this replaces
that with rules. Depends on Providers, and needs the catalog to know which
models can see images — the app currently trusts the user to pick a vision model
for Screen mode. Hook 3.

### 11. Screenshot optimization

Downscale and recompress a screenshot before sending: resolution, file size,
without visible loss.

The smallest item here and pure win — fewer image tokens, faster upload. Sits
between `ScreenCapture` and `ProviderClient`. The only real question is the
floor: compress far enough and the model can no longer read the text on screen,
which is the whole point of the mode. Hook 3.

### 12. Screenshot of a selected area

A hotkey, a dragged selection, and a question about that part of the screen.

An addition to the Screen mode rather than a new one. Needs a selection overlay
window and a decision about ordering: does the question come while selecting or
after. Local capture, network answer. Hook 3.

### 13. Double-press long dictation

A third hotkey behaviour: double-press starts a long recording without holding
anything, pressing again ends it.

Touches the core loop, not the edges — the app already has toggle and
push-to-talk, and this is a third mode of the same control. By the rule in
`OVERVIEW.md` that makes it a **setting, not a module**: recording has no switch.
Listed here because it came in with the list, but it belongs in General.

### 14. App-aware transcription

Notice the frontmost application and adapt processing to it: technical terms and
English names in an IDE, plain conversational text in Telegram.

Not a processing step of its own but a **selector** over the others — it decides
which post-processing profile hook 2 runs. That makes it depend on 4, 5 and 9,
and it should be built after at least one of them exists. Local.

### 15. Transcription quality benchmark

Run one test recording through several installed models on this particular Mac,
show speed and result for each, recommend one.

Observes and reports, changes nothing — hook 4, no dependencies beyond the model
manager. Needs a bundled test clip with a known reference transcript, and an
honest error metric rather than a vibe. Local.

### 16. One more provider — Polza.ai

Add Polza.ai alongside OpenAI, Anthropic, xAI, Google Gemini and Alibaba Qwen.

A catalog entry, not a module: `ProviderCatalog.all` plus the endpoints and a key
placeholder. Listed here so it does not get lost. Check whether the API is
OpenAI-compatible — if it is, `ProviderClient` needs nothing new.

## What this changes about the earlier documents

`OVERVIEW.md` lists Achievements, Stats, Providers, AskFlow and ScreenCapture as
the modules. Those are the **architectural** split — packages under `modules/`.
This list is what a **user** sees on the Modules screen, and the two overlap only
in places. Both are real; they should not share one screen without saying which
kind a row is.

The dependency that matters most: items 4, 5, 9 and 14 all need the
post-processing chain from hook 2, and none of them can be built before it
exists. It is a small piece of work and it unblocks a third of this list.

Items 7 and 8 form their own cluster, and 2 is a project of its own — those three
are the expensive end of the list.

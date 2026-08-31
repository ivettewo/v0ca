# v0ca. — Meeting panel

A module: a floating panel that listens to a call, splits it into bubbles by
source, catches questions and answers them, and files the conversation in the
history when the call ends.

Design: the meeting-panel mockup (v2) in `design/`. Rules for modules:
`OVERVIEW.md`. This file is the decisions and the order of work.

The largest module on the list. Most of its machinery has been prototyped
before, in a private project of the author's; the approaches worth reusing are
described below in enough detail to rebuild them from scratch.

**It is a module, and the module rules apply in full.** Off on a fresh install,
like every other one — nothing about a listening panel should ever arrive
switched on. Switched off it registers no hotkeys, captures nothing, adds no tab
and no HUD mode; the conversations already recorded stay on disk and come back
with it. It will also be the first module to own a whole settings tab rather
than a row on someone else's.

## What the design specifies

**The panel.** Floating window at the right edge: 372pt wide, 16pt inset on
three sides, radius 26, shadow `0 16 40`. Not the HUD capsule — its own window.

**Bubbles, never names.** The other side is a dark `#1B1B1F` bubble with white
text, corners `20/20/20/8`, aligned left. You are a white bubble with a border,
corners mirrored, aligned right. Max width 284. The panel does not guess who is
speaking: the side comes from the audio source, and that is the whole reason it
can be honest about it.

**Seven states:** empty (before the call, with a start button), running, waiting
for the next line, question found, answer loading, settings, help.

**A question found in the other side's line** turns that bubble accent red with
two actions on it: `⌘↵` for an answer, `⌘C` to copy.

**The answer is a second window to the left** — 340×452, same radius and shadow,
scrolls inside, and carries chips with the source files it drew on.

**A Meetings tab** in Settings: history of calls with summaries and counts,
questions of the week with their answers and sources, a knowledge-base folder
with an index, conversation profiles (interview / meeting / custom) with
threshold, segmentation window and mic sensitivity, and the shortcuts.

**A fourth HUD mode, Meeting:** it doesn't insert text, it raises the panel and
keeps it up until the call ends.

## What is feasible, and what the design promises that the code can't yet

Everything in the panel is buildable. Two promises printed on the mockup do not
survive contact with an implementation, and both need a decision before code:

**1. "The panel finds questions by itself" versus "only the selected line goes
to the API".** Question detection cannot be a rule. That was tried, and the reason
is worth repeating: rhetorical questions, thinking aloud, questions the speaker
answers themselves, and indirect requests ("tell me about your experience with…")
that carry no question mark at all. What works is an LLM classifier over a window
of the last 8 lines, run continuously. That contradicts the privacy line on the panel:
a classifier means the conversation leaves the Mac all the time, not once per
question.

Three ways out, and this is a product decision, not a technical one:
- run the classifier and rewrite the promise honestly — the lines go to a
  classifier;
- keep the promise and use heuristics, accepting that indirect questions are
  missed;
- find a local model for classification — the only option that keeps both, and
  the only one whose cost we don't know yet.

**2. "Text only, nothing leaves the network" for the knowledge base.** The
working implementation indexes with OpenAI `text-embedding-3-small` over the network — the
whole folder goes to the provider at index time. Retrieval afterwards is local,
but the promise as written is false unless embeddings are computed on device.
Same fork: change the wording, or find a local embedding model.

## Approaches worth reusing

All of these were verified against a working implementation, not guessed.

- **System audio capture.** `SCStream` with `capturesAudio = true` and
  `excludesCurrentProcessAudio = true`, video squashed to 2×2 at one frame per
  second so nothing is paid for pixels. Conversion reads raw floats out of the
  block buffer and decimates 3:1 to 16 kHz by hand — `AVAudioConverter` throws on
  some formats, so this is worth copying rather than rediscovering.
- **The VAD.** RMS over each buffer; speech above a threshold accumulates; N
  silent buffers end the line; continuous speech is cut by length so the
  transcript keeps up; anything under half a second is dropped. The mockup's
  trigger threshold and segmentation window are these two numbers.
- **The panel window.** `.nonactivatingPanel` + `.borderless`, `canBecomeKey =
  true`, `canBecomeMain = false`: it takes keys without pulling focus out of
  Zoom. And `sharingType = .none`, which keeps the panel out of screen sharing —
  the participant must not see their own words transcribed back at them. Reported
  to be unreliable on macOS 15+, so it needs testing on a real call.
- **The index**, if we build the knowledge base: folder walk over `.md`/`.txt`,
  paragraphs joined to ~900 characters with 150 of overlap, embeddings in batches
  of 64, one JSON index, cosine search by brute force with a 0.2 floor and top-8.
  For a personal folder brute force is instant; no vector database.
- **Microphone through `AVCaptureSession`, not `AVAudioEngine`** — the reason
  that matters here: it creates no aggregate device and does not touch the
  output. During a call, an aggregate device is a way to break Zoom's
  own audio. Our `AudioRecorder` uses `AVAudioEngine` and will need checking.
- **Streaming answers.** `AsyncThrowingStream` over `URLSession.bytes` with
  `"stream": true`. Our `ProviderClient` waits for the whole answer, which is
  fine for a one-line "Ask" and not fine for a panel.

One dead end already paid for: click-through on the panel — the `hitTest`
approach in `NSHostingView` proved capricious and was abandoned.

## Order of work

Each step is usable on its own, and the panel is not built until the thing it
displays exists.

1. **Two streams.** Microphone and system audio side by side, with the
   permission and a visible indicator. No UI: verified by the log.
2. **Segmentation and rolling transcription.** VAD cuts lines, each goes to the
   engine, the result carries a timestamp and a side. Still no panel.
3. **The panel.** Window, bubbles, states, start and finish, and the
   conversation filed into the history. This is the point where it becomes a
   feature: a transcript of a call with the sides separated is useful on its own.
4. **Questions and answers.** Detection (see the fork above), `⌘↵` through the
   existing `ProviderClient`, the second window with the answer.
5. **The Meetings tab.** List, metrics, profiles, thresholds.
6. **The knowledge base with citations.** Last, and separable: the panel answers
   without sources until this exists.

## Hotkeys: decided

**The shortcuts printed on the mockup are placeholders.** ⌘⇧M, ⌘↵, ⌘C, ⌘⇧S were
drawn to show that actions exist, not to be registered. Taken literally they
break the machine: a global `⌘C` would swallow copy in every application on the
system, and that is not a trade — it is a bug with a keyboard shortcut.

The rule that keeps this safe: **exactly one global hotkey, everything else local
to the panel.**

- **Global — one.** Start and stop the meeting. Registered only while the module
  is on, and taken from a range that is normally free: `⌃⌥` combinations, not
  `⌘`-digits and not `⌘⇧` letters that applications claim.
- **Local — the rest.** Answer, copy, summary and hide only fire while the panel
  is key or the pointer is over it. Inside the panel `⌘C` is just copy, which is
  what it means everywhere else; outside it belongs to whatever the user is
  working in.

Local binding also settles the focus problem: the panel is `.nonactivatingPanel`
with `canBecomeKey = true`, so it can hold keys without pulling focus out of the
call.

Every shortcut stays editable in Settings, as the existing ones are, and the
defaults are checked against the app's own hotkeys before shipping.

**The existing `⌘1`–`⌘3` mode shortcuts stay as they are** — decided. They do
collide with browser tabs, but they are comfortable, they only fire while the bar
is on, and anyone can rebind them in Settings. That is a different situation from
a global `⌘C`, which would break a system-wide reflex the user never chose to
give up.

## Open questions

**Recording a conversation may require consent** where the user lives. The panel
being visible is part of the answer, but it can be minimized, so something has to
stay on screen that says a recording is running. This shapes the design, so it is
not a footnote.

**An hour of audio.** Recording is minutes today. Lines have to be transcribed as
they arrive and released; the audio is never written to disk (the design says so
too), and only text is kept.

**Two engines.** Whether WhisperKit or Parakeet through FluidAudio handles
short rolling segments better on this hardware is an open measurement, not an
opinion. The Transcription Quality Benchmark module from `CATALOG.md` would
answer it.

# Meeting panel — build log

The working document for building the meeting module. Decisions and design live
in `MEETING.md`; this file is the order of operations and the record of what was
actually done.

**How to use it.** Do one step at a time, in order. When a step is finished,
append an entry to the log at the bottom — what was written, what had to be
fixed, what turned out differently from the plan. The plan above is not edited
when reality disagrees with it: the log says so instead, and the plan gets a
short note pointing at the log entry.

A step is finished when its acceptance check passes, not when the code compiles.

## Status

| Step | What | State |
|---|---|---|
| 1 | Two audio streams | done |
| 2 | Segmentation and rolling transcription | done, thresholds not yet tuned on a real call |
| 3 | The panel | done, minus the header buttons and the summary |
| 4 | Questions and answers | done |
| 5 | The Meetings tab | done, minus what steps 4 and 6 would fill in |
| 6 | Knowledge base with citations | not started |

**Decided for step 4: the classifier.** Every line from the other side goes to
the chosen model, which returns one judgement. A rule about question marks was
rejected — it misses indirect requests and fires on rhetorical ones. The promise
on the panel was rewritten to say so rather than quietly broken.

Step 6 still waits on its own decision: whether the knowledge base may index
through a network embedding model.

---

## Step 1 — Two audio streams

Capture both sides of a call and prove they arrive. No UI beyond a recording
indicator, no transcription yet.

**What exists already.** `AudioRecorder` records the microphone through
`AVCaptureSession` at 16 kHz mono Float32 — the format the engine wants — and
does not create an aggregate device, which matters during a call. `ScreenCapture`
already asks for the Screen Recording permission, and that is the same permission
`SCStream` audio needs. So the microphone side needs no new capture code and the
system side needs no new permission prompt.

**Tasks.**

1. `Core/Capture/SystemAudioCapture.swift` — new. `SCStream` with
   `capturesAudio = true`, `excludesCurrentProcessAudio = true`, `sampleRate =
   48000`, `channelCount = 1`, video suppressed (`width/height = 2`,
   `minimumFrameInterval` one second) so nothing is spent on frames.
2. Sample conversion inside it: read raw floats out of the block buffer, average
   interleaved channels to mono, decimate to 16 kHz by index step. Do **not** use
   `AVAudioConverter` — it throws on some of the formats this delivers.
3. `Core/Capture/MeetingRecorder.swift` — new. Owns both sources, starts and
   stops them together, tags every chunk with a side (`.me` / `.them`) and a
   timestamp taken at chunk start.
4. Microphone: a second consumer of `AudioRecorder`'s samples. If that means a
   callback per buffer rather than one array at the end, add it — do not open a
   second capture session on the same device.
5. A visible indicator while capture runs. Recording a conversation is not the
   same promise as recording your own voice; nothing may capture silently.

**Acceptance.** With a call playing, the log shows chunks arriving from both
sides, with plausible RMS on each, and stopping the recorder stops both. No
audio is written to disk at any point.

**Pitfalls.** `SCShareableContent` needs a display even when only audio is
wanted. Permission may be granted but stale after an app restart — handle the
"granted, but the stream fails" path. AirPods switch to a mono profile when the
microphone is opened, which changes what the system-audio side sounds like.

---

## Step 2 — Segmentation and rolling transcription

Turn two sample streams into a list of lines while the call is still going.

**Tasks.**

1. A VAD in `MeetingRecorder` (or beside it): RMS per buffer, speech above a
   threshold accumulates, N consecutive silent buffers end a line, continuous
   speech is cut by a maximum length so the transcript keeps up, anything under
   half a second is dropped.
2. Both thresholds come from settings, not constants: the mockup draws them as
   "trigger threshold" and "segmentation window".
3. Each finished line goes to the engine on its own and comes back as
   `MeetingLine { id, side, startedAt, text }`.
4. A queue in front of the engine: lines arrive faster than they transcribe, and
   two transcriptions must not run at once. Order is preserved by `startedAt`,
   not by completion.
5. Long call hygiene: samples are released as soon as a line is transcribed.
   Nothing accumulates for an hour.

**Acceptance.** A five-minute call produces an ordered list of lines with the
right side on each, memory does not grow with call length, and the transcript
lags speech by seconds rather than minutes.

**Pitfalls.** Whisper on a two-second chunk hallucinates filler ("Продолжение
следует…") — decide whether to drop suspiciously short results. Which engine
handles short segments better is a measurement, not a preference.

---

## Step 3 — The panel

The window from the mockup, fed by step 2.

**Tasks.**

1. `Features/Meeting/MeetingPanelController.swift` — `NSPanel`, `.borderless` +
   `.nonactivatingPanel`, `isFloatingPanel`, `canBecomeKey = true`,
   `canBecomeMain = false`, `collectionBehavior` including `.canJoinAllSpaces`,
   `sharingType = .none` so the panel stays out of screen sharing.
2. Geometry from the mockup: 372pt wide, 16pt inset top/right/bottom, radius 26,
   shadow `0 16 40`.
3. `Features/Meeting/MeetingPanelView.swift` — bubbles: the other side dark with
   white text, corners `20/20/20/8`, leading; you white with a border, corners
   mirrored, trailing; max width 284; font 13.5/1.5. Auto-scroll to the newest
   line, and a lazy list so an hour of conversation stays smooth.
4. States: empty (before start), running, waiting for the next line.
5. Header: editable title, help, settings, minimize. Footer: copy, summarize,
   finish.
6. Storage: `MeetingStore` writing conversations next to the history —
   `{ id, title, startedAt, duration, lines }`. Audio is never saved.
7. The fourth HUD mode raises the panel instead of inserting text; one global
   hotkey starts and stops the meeting.

**Acceptance.** A call can be started from the bar, the panel fills with bubbles
in real time without stealing focus from the meeting app, it does not appear in
a shared screen, and "Завершить" leaves a conversation in the history.

**Pitfalls.** Do not attempt click-through: the `hitTest` approach in
`NSHostingView` is known to be capricious and was abandoned elsewhere. Panel
buttons must work without activating the app.

---

## Step 4 — Questions and answers

Blocked until the detection decision in `MEETING.md` is made.

**Tasks.**

1. Detection: a line from the other side is marked as a question. Whatever the
   mechanism, it must never fire on your own side, must not fire twice on the
   same question, and must not start a second answer while one is running.
2. Marked bubble: accent fill, with the two actions on it.
3. The answer window: 340×452, to the left of the panel, scrolls internally.
4. The request goes through the existing `ProviderClient`. Streaming would be
   worth adding here — waiting for a whole answer in silence reads as a hang.
5. The panel's local shortcuts, bound only while it is key or hovered.

**Acceptance.** A question asked out loud in a call gets marked, and one press
produces an answer in the second window without focus leaving the call.

---

## Step 5 — The Meetings tab

**Tasks.** Sidebar item behind the module; sub-tabs History and Settings; the
metrics row; conversation list with summary and counts; the week's questions;
conversation profiles with their thresholds; the shortcut list.

**Acceptance.** Past conversations are findable and readable, and every knob the
panel obeys is visible here.

---

## Step 6 — Knowledge base with citations

Blocked until the indexing decision in `MEETING.md` is made.

**Tasks.** Folder picking; index build over `.md`/`.txt` with paragraph chunks of
~900 characters and 150 of overlap; one JSON index; cosine search by brute force
with a floor and a top-K; source chips under the answer; re-index on demand with
progress and a staleness marker.

---

## Log

Newest entry at the top. One entry per finished step, or per attempt that taught
something. Say what changed, what broke, and what the plan got wrong.

### Steps 4–5 — questions, answers, and the tab

**Catching questions.** `QuestionCatcher` sends the last eight lines after every
line from the other side and asks for `{is_question, question, confidence}`.
Below the threshold it stays quiet; own lines are never classified; a question
already shown or answered never returns; a second classification never starts on
top of a first. This is the mind-wiki approach, checked against its wiring rather
than guessed: there is no heuristic prefilter there either, and the reason is
written down — indirect requests carry no question mark.

Cost of the decision, stated in the module page: the other side's lines leave the
Mac continuously while a call runs.

**Answering.** `MeetingAnswer` asks once per question, with six lines of context
— "and how long did that take?" means nothing alone. The answer gets a window of
its own, 340×452 to the left of the panel, which appears when there is something
in it and leaves when it is dismissed; no command opens or closes it.

`⌘↵` and `⌘C` are bound with SwiftUI's `keyboardShortcut` on the buttons
themselves, so they only fire while the panel holds the keys. That is the whole
answer to the "global ⌘C would break the machine" problem in `MEETING.md`.

**The tab.** Title with the section pill on the right, a metrics card, and the
conversation list with search — rebuilt once against the mockup after the first
attempt turned out to be a stats-tab layout in disguise. Settings: profile
presets, the two segmentation knobs, the confidence threshold, auto-answer, and
the panel's keys.

**One bug worth remembering:** picking a profile preset set both numbers, and the
sliders' change handler immediately flipped the profile to "custom" — the preset
un-selected itself. Fixed by making "custom" a consequence of *dragging*, not of
the value changing.

**Not built, and why:** the questions-of-the-week block, the task and question
counts on each conversation, and the summary line. All three need either step 6
or a summarizing pass that does not exist yet. Showing them empty would be
furniture pretending to be a feature.

### Steps 1–3 — capture, transcript, panel

**Capture.** `SystemAudioCapture` takes the other side through `SCStream`
(`capturesAudio`, `excludesCurrentProcessAudio`, video squeezed to 2×2 once a
second). Conversion to 16 kHz mono is done by hand off the block buffer, as
planned — `AVAudioConverter` is not to be trusted with these formats.
`MeetingRecorder` runs both sources and tags every chunk with a side and a time;
if the system side fails to start it stops the microphone too, because a
one-sided recording of the user is the opposite of the point.

The microphone needed no new capture code: `AudioRecorder` was already an
`AVCaptureSession` at 16 kHz mono. The plan said it might be on `AVAudioEngine`
and need replacing — that was wrong, and `MEETING.md` has been corrected.

**Transcript.** `SpeechSegmenter` cuts by loudness, one instance per side —
sharing one would splice two people into a single line. `MeetingTranscript`
transcribes one utterance at a time (two at once on one model is slower than two
in a row) and inserts each result by the time speech *started*, not by when
recognition finished, so a slow side can't land its words after later ones.
Whisper's silence-fillers ("Продолжение следует", "Thanks for watching") are
dropped by name — on two-second segments they show up often enough to matter.

**Panel.** `MeetingPanelController` + `MeetingPanelView`: 372pt at the right
edge, `.nonactivatingPanel`, `sharingType = .none`. Bubbles per the mockup, no
names. The conversation is filed into the history as a new `HistoryRecord.Kind`
— `.meeting` — with the title as its first line and no audio at all. The bar
gained a fourth mode, offered only while the module is on.

**Three things the plan got wrong, all caught in review:**

- I put the capture switch in the *menu bar* first. Wrong place — this is an app,
  and the control belongs in it. It now lives on the module page and in the panel.
- Picking the Meeting mode started recording immediately. It shouldn't: the panel
  opens empty, the title is set first, and recording starts from the panel. The
  mode's tint went from accent red to a calm slate for the same reason — the
  accent has to keep meaning "recording right now".
- A borderless `NSPanel` refuses to become key, so the title field could not be
  typed into, and its layer stayed opaque, so the rounded corners cut into black.
  Both fixed in the panel subclass.

**Not done from step 3:** the three header buttons (help, panel settings,
minimize) and the summary button. Both belong to features that don't exist yet —
settings for answering, and the summary itself.

**Still unverified:** the VAD thresholds. They are the numbers from a working
implementation elsewhere, not measured here. Whether lines break in the right
places on a real call, and how far the transcript lags speech, is the next thing
to check.

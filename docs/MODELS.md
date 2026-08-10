# v0ca. — Model Catalog

The catalog is stored as `ModelCatalog.json` in the bundle; each entry is a `ModelDescriptor` (`Core/Transcription/ModelDescriptor.swift`). All models run fully locally. Two engines:

- **WhisperKit** — the Whisper family in CoreML (the `argmaxinc/whisperkit-coreml` repository on Hugging Face), Neural Engine acceleration, 99 languages, translation to English, timestamps.
- **FluidAudio** — Parakeet TDT (CoreML, `FluidInference/*` on Hugging Face), very fast (~110× real time on an M4 Pro).

Exact sizes and the full list of variants should be cross-checked against the HF repositories during implementation — the lineup keeps growing, and the catalog should update without an app release (see "Catalog updates" below).

## Whisper (WhisperKit) — multilingual, 99 languages

| Model | ID | Size | Accuracy | Speed |
|---|---|---|---|---|
| Whisper Tiny | `openai_whisper-tiny` | ~75 MB | 4 | 10 |
| Whisper Base | `openai_whisper-base` | ~142 MB | 5 | 9 |
| Whisper Small | `openai_whisper-small` | ~466 MB | 7 | 7 |
| Whisper Small (216MB, quant.) | `openai_whisper-small_216MB` | ~216 MB | 6 | 8 |
| Whisper Medium | `openai_whisper-medium` | ~1.5 GB | 8 | 5 |
| Whisper Large v2 | `openai_whisper-large-v2` | ~2.9 GB | 9 | 3 |
| Whisper Large v2 (949MB, quant.) | `openai_whisper-large-v2_949MB` | ~949 MB | 9 | 4 |
| Whisper Large v2 Turbo | `openai_whisper-large-v2_turbo` | ~2.9 GB | 9 | 5 |
| Whisper Large v3 ★ | `openai_whisper-large-v3` | ~2.9 GB | 10 | 3 |
| Whisper Large v3 (947MB, quant.) | `openai_whisper-large-v3_947MB` | ~947 MB | 9 | 4 |
| Whisper Large v3 Turbo | `openai_whisper-large-v3-v20240930` | ~1.6 GB | 9 | 6 |
| Whisper Large v3 Turbo (626MB, quant.) | `openai_whisper-large-v3-v20240930_626MB` | ~626 MB | 9 | 7 |

## Whisper (WhisperKit) — English only

| Model | ID | Size | Accuracy | Speed |
|---|---|---|---|---|
| Whisper Tiny (EN) | `openai_whisper-tiny.en` | ~75 MB | 5 | 10 |
| Whisper Base (EN) | `openai_whisper-base.en` | ~142 MB | 6 | 9 |
| Whisper Small (EN) | `openai_whisper-small.en` | ~466 MB | 7 | 7 |
| Whisper Medium (EN) | `openai_whisper-medium.en` | ~1.5 GB | 8 | 5 |
| Distil Large v3 (EN) | `distil-whisper_distil-large-v3` | ~1.5 GB | 9 | 6 |
| Distil Large v3 (594MB, quant.) | `distil-whisper_distil-large-v3_594MB` | ~594 MB | 8 | 7 |
| Distil Large v3 Turbo | `distil-whisper_distil-large-v3_turbo` | ~1.5 GB | 9 | 7 |
| Distil Large v3 Turbo (600MB) | `distil-whisper_distil-large-v3_turbo_600MB` | ~600 MB | 8 | 8 |

## Parakeet (FluidAudio)

| Model | ID | Languages | Size | Accuracy | Speed |
|---|---|---|---|---|---|
| Parakeet TDT v2 | `parakeet-tdt-0.6b-v2-coreml` | English | ~600 MB | 8 | 10 |
| Parakeet TDT v3 ★ | `parakeet-tdt-0.6b-v3-coreml` | 25 European (incl. Russian) | ~600 MB | 8 | 10 |

★ — "Recommended" in the UI. Active by default after onboarding: **Whisper Small** (a balance) with a prompt to upgrade to Large v3 Turbo.

Total in the catalog at launch: **~22 models**; we grow to 30–40 with quantized variants from the HF repository (argmaxinc has 1–2 compressed versions for almost every model) and new releases (for example, future v3-turbo variants, Parakeet updates).

## Filters and search in the UI

- Search by name.
- The "All languages" filter: All / Multilingual (99) / English only / European (25).
- Tag chips: "Active", "Recommended", "English only", "Quantized".

## Download and storage

- Downloading from Hugging Face (WhisperKit and FluidAudio can do it themselves; progress — into the model card, like "62%" in the mockup).
- Path: `~/Library/Application Support/v0ca/models/<engine>/<id>/`.
- Deleting a model — from the card; the active one cannot be deleted without switching.

## In-memory lifecycle

- **The active model is loaded into memory immediately at app launch** (and when the active model is changed) — by the time the hotkey is first pressed it is already warm, with no warm-up delay before transcription.
- Unloading — only by the idle timer, the "Unload model" setting with options: **Never / after 5 minutes / 10 minutes / 15 minutes (default) / 30 minutes / 1 hour / 2 hours**.
- After unloading, the model is loaded back on the next hotkey press — the load runs in parallel with voice recording, so that by the time of "stop" it is ready (recording usually lasts longer than the warm-up).

## Catalog updates

`ModelCatalog.json` in the bundle is the baseline; if desired, we can later add remote catalog updates (a simple JSON on GitHub), so new models appear without a release. In v1 — the bundle only.

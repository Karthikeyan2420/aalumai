# Jarvis — on-device verification checklist

Everything below is **unverified until run on a physical device**. The
integration passes 111 unit/widget tests and a full debug build, but local
inference, voice, and the Android bridge only prove themselves on hardware.

Target device: Moto G96 5G (Android 15, 8 GB RAM, arm64-v8a).

## Install

```sh
flutter build apk --debug   # SHA pin is set; release build is the next gate
flutter install --debug
```

32-bit ABIs ship without the llama native libs by design; on an unsupported
device the model-load path must fail with a catchable error and the chat must
show a clear message rather than crash.

## 1. Model install (Model tab)

- [ ] Tap **Download model (~1.3 GB)** — progress advances, completes, status
      flips to "Model installed" (the download fails its SHA-256 integrity
      check if the file is corrupted). Wi-Fi recommended; the download is a
      single `dart:io HttpClient` stream into app-private storage.
- [ ] Kill and relaunch the app — model is still installed (prefs + file).
- [ ] Alternative: **Import a GGUF file** from storage; status also flips.
- [ ] **Delete model** → confirm dialog → status returns to "No model".
- [ ] `kExpectedSha256` in `lib/features/jarvis/data/model_manager.dart` is
      pinned to the LFS object id of ggml-org's `Qwen3-1.7B-Q4_K_M.gguf`; a
      successful on-device download proves the pin correct.

## 2. Load & chat (Chat tab)

- [ ] **Load model** — loading takes seconds on this device; status shows
      "Model loaded". Sending before load shows the "not loaded" error.
- [ ] Ask "what can you do?" — first reply may take 10–60 s on CPU; tokens
      should stream incrementally.
- [ ] Ask "add buy milk to my tasks" — reply must contain an `action` block,
      it executes (auto-approved class), and the task appears in Tasks.
- [ ] Ask "delete my task" with a matching task — a **confirmation sheet**
      appears; Decline must leave the task untouched and the chat must
      acknowledge; Accept must delete.
- [ ] Ask for something ambiguous (two same-named tasks) — Jarvis must ask
      which one, not guess.
- [ ] Stop button mid-generation — partial reply kept, app responsive.
- [ ] Threads/context dropdowns: reload after changing; 8 threads / 8192
      context should still respond (slower, more RAM).

## 3. Device bridge (Channel `aalumai/jarvis_actions`)

- [ ] "what's my battery?" — real percentage and charging state.
- [ ] "open WhatsApp" — launches the app; unknown package → honest failure.
- [ ] "open notification settings" — lands on this app's notification page.

## 4. Memories (Memories tab)

- [ ] After chat-learned facts, unconfirmed memories show a **Confirm**
      button; confirming makes them durable context.
- [ ] **Forget** asks then removes; Jarvis stops referencing it.
- [ ] Manual **Save a memory** FAB stores a confirmed fact.

## 5. Voice

- [ ] Hold the mic (appears only when a speech service exists) — partial
      words land in the input; release sends.
- [ ] Speaker toggle on — Jarvis's replies are read aloud; toggle off
      silences.
- [ ] Deny mic permission → no crash; mic simply unavailable.

## 6. Daily briefing (Model tab toggle)

- [ ] Toggle off → previously armed notification is cancelled (check
      notification drawer at 08:00 next morning).
- [ ] Toggle on → briefing at 08:00 with that morning's task/event counts
      and next alarm; quiet message on empty days.
- [ ] Works with the model deleted — the briefing is deterministic and never
      loads the model.

## 7. Soak

- [ ] 30 min chat with several tool calls — watch memory/RAM; no ANR.
- [ ] Reboot — briefing still armed (re-armed on app start), alarms/tasks
      unaffected.
- [ ] App-private storage: model lives under `<documents>/models/`; no writes
      outside app storage; uninstall removes everything.

## Known limitations (honest state)

- The first source URL was a nonexistent HF file (404 on device); the app now
  downloads ggml-org's Q4_K_M with the SHA-256 pin set.
- Notification text ships in English only; UI is translated, notification
  strings await translations.
- CPU-only inference (`gpuLayers: 0` — the plugin does not expose Vulkan
  yet); expect slow first tokens on big prompts.
- Ambiguity resolution depends on the model following the id-digit
  convention; the safety net is the confirmation sheet, never silent
  execution of sensitive actions.

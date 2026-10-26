# Deskflow Duo v0.2 film

84 seconds, 1920×1080, 30 fps. Six individually registered Remotion scenes; animation illustrates the workflow and is not a hardware recording. Narration uses Doubao realtime speech model 1.2.1.1, Taiwan-accent Xiaohe (`zh_female_xiaohe_jupiter_bigtts`). Voice WAVs are included for deterministic renders; no credentials or local gateway code are included.

```bash
npm ci
npm run dev -- --port=4190
npm run lint
npx remotion render src/index.ts DeskflowDuo out/deskflow-duo.mp4
```

`narration.json` contains the spoken script. `public/voice-0.wav` through `voice-5.wav` were generated via the provider's fixed-text `SayHello` interface, PCM mono 24 kHz, converted to WAV with FFmpeg. Synthesis credentials were injected into a local process from Keychain. To regenerate, use your own speech account and the [official API documentation](https://docs.volcengine.com/docs/6561/1594356); do not put credentials in source, CLI arguments, logs or `.env` files committed to Git.

Each segment begins at 0/14/28/42/56/70 seconds. The longest generated voice is under 12 seconds. The v0.2 narration and visuals focus on Mac mini + MacBook, separate Apple accounts, four keyboard/cursor combinations and five installation steps. Burned-in scene summaries and a separate Chinese VTT caption track accompany the film. There is no background music, so speech remains clear. Graphics and scripts are original; no desktop screenshots or personal data appear.

Source, narration and illustrations are MIT; Remotion itself has [separate licensing](https://www.remotion.dev/license). The video build does not contact speech services.

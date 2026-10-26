import { Series, useVideoConfig, Audio, staticFile } from "remotion";
import { Problem } from "./Problem";
import { Effect } from "./Effect";
import { Physical } from "./Physical";
import { Protocol } from "./Protocol";
import { Install } from "./Install";
import { Close } from "./Close";
export const MyComposition = () => {
  const { fps } = useVideoConfig();
  return (
    <Series>
      <Series.Sequence
        name="Problem"
        durationInFrames={13 * fps}
        premountFor={fps}
      >
        <Problem />
        <Audio src={staticFile("voice-0.wav")} />
      </Series.Sequence>
      <Series.Sequence
        name="Effect"
        durationInFrames={13 * fps}
        premountFor={fps}
      >
        <Effect />
        <Audio src={staticFile("voice-1.wav")} />
      </Series.Sequence>
      <Series.Sequence
        name="Physical"
        durationInFrames={13 * fps}
        premountFor={fps}
      >
        <Physical />
        <Audio src={staticFile("voice-2.wav")} />
      </Series.Sequence>
      <Series.Sequence
        name="Protocol"
        durationInFrames={13 * fps}
        premountFor={fps}
      >
        <Protocol />
        <Audio src={staticFile("voice-3.wav")} />
      </Series.Sequence>
      <Series.Sequence
        name="Install"
        durationInFrames={13 * fps}
        premountFor={fps}
      >
        <Install />
        <Audio src={staticFile("voice-4.wav")} />
      </Series.Sequence>
      <Series.Sequence
        name="Close"
        durationInFrames={13 * fps}
        premountFor={fps}
      >
        <Close />
        <Audio src={staticFile("voice-5.wav")} />
      </Series.Sequence>
    </Series>
  );
};

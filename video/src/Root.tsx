import { Composition, Folder } from "remotion";
import { MyComposition } from "./Composition";
import { Problem } from "./Problem";
import { Effect } from "./Effect";
import { Physical } from "./Physical";
import { Protocol } from "./Protocol";
import { Install } from "./Install";
import { Close } from "./Close";
export const RemotionRoot = () => (
  <>
    <Composition
      id="DeskflowDuo"
      component={MyComposition}
      durationInFrames={2340}
      fps={30}
      width={1920}
      height={1080}
    />
    <Folder name="Scenes">
      <Composition
        id="Problem"
        component={Problem}
        durationInFrames={390}
        fps={30}
        width={1920}
        height={1080}
      />
      <Composition
        id="Effect"
        component={Effect}
        durationInFrames={390}
        fps={30}
        width={1920}
        height={1080}
      />
      <Composition
        id="Physical"
        component={Physical}
        durationInFrames={390}
        fps={30}
        width={1920}
        height={1080}
      />
      <Composition
        id="Protocol"
        component={Protocol}
        durationInFrames={390}
        fps={30}
        width={1920}
        height={1080}
      />
      <Composition
        id="Install"
        component={Install}
        durationInFrames={390}
        fps={30}
        width={1920}
        height={1080}
      />
      <Composition
        id="Close"
        component={Close}
        durationInFrames={390}
        fps={30}
        width={1920}
        height={1080}
      />
    </Folder>
  </>
);

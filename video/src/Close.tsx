import { Frame } from "./Frame";
export const Close = () => (
  <Frame
    number="06"
    title={
      <>
        Mac mini × MacBook。<span style={{ color: "#bcd28e" }}>接着流动。</span>
      </>
    }
    subtitle="开源桌面配方：源码、脚本、AI Skill。你的账号，你的习惯。"
  >
    <div
      style={{
        position: "absolute",
        left: 130,
        top: 390,
        fontSize: 100,
        letterSpacing: -4,
        fontWeight: 600,
      }}
    >
      Deskflow Duo<span style={{ color: "#bcd28e" }}> ↗</span>
    </div>
    <div
      style={{
        position: "absolute",
        left: 140,
        top: 550,
        fontSize: 35,
        color: "#c4d5ac",
      }}
    >
      joymicro.ai/deskflow-duo
    </div>
    <div
      style={{
        position: "absolute",
        left: 140,
        top: 625,
        fontSize: 28,
        color: "#a0b391",
      }}
    >
      github.com/joymicro4/deskflow-duo
    </div>
    <div
      style={{
        position: "absolute",
        left: 140,
        top: 745,
        fontSize: 25,
        color: "#8fa47e",
      }}
    >
      v0.2 · 双 Mac 预览版 · MIT · by JoyMicro
    </div>
  </Frame>
);

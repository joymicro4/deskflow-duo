import { Frame } from "./Frame";
export const Close = () => (
  <Frame
    number="06"
    title={
      <>
        开源的，<span style={{ color: "#bcd28e" }}>自在桌面配方。</span>
      </>
    }
    subtitle="源码 · 安装脚本 · doctor · AI Skill。先在你的桌面试试看。"
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
        top: 555,
        fontSize: 30,
        color: "#b4c49b",
      }}
    >
      github.com/joymicro4/deskflow-duo
    </div>
    <div
      style={{
        position: "absolute",
        left: 140,
        top: 680,
        fontSize: 25,
        color: "#8fa47e",
      }}
    >
      MIT · 双 Mac 预览版 · by JoyMicro
    </div>
    <div
      style={{
        position: "absolute",
        left: 140,
        top: 750,
        fontSize: 24,
        color: "#8fa47e",
      }}
    >
      触控板读取已验证；完整接管链路仍需真机验证。
    </div>
  </Frame>
);

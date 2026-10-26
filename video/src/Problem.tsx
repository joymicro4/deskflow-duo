import { Frame } from "./Frame";
import { Desk } from "./Desk";
export const Problem = () => (
  <Frame
    number="01"
    title={
      <>
        两台 Mac。<span style={{ color: "#bcd28e" }}>一张桌面。</span>
      </>
    }
    subtitle="外接键鼠很顺手。换回 MacBook，谁来接管？"
  >
    <Desk />
    <div
      style={{
        position: "absolute",
        top: 815,
        left: 130,
        fontSize: 28,
        color: "#aabd99",
      }}
    >
      少一次切换，多一点专注。
    </div>
  </Frame>
);

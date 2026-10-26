import { Frame } from "./Frame";
import { Desk } from "./Desk";
export const Effect = () => (
  <Frame
    number="02"
    title={
      <>
        两套输入。
        <span style={{ color: "#bcd28e" }}>不用同一个 Apple ID。</span>
      </>
    }
    subtitle="外接键鼠控制两台，MacBook 自带键鼠也能控制 mini。"
  >
    <Desk right />
    <div
      style={{
        position: "absolute",
        top: 825,
        left: 130,
        fontSize: 28,
        color: "#aabd99",
      }}
    >
      你的账号，你的习惯，都可以保留。
    </div>
  </Frame>
);

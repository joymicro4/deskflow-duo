import { Frame } from "./Frame";
import { Desk } from "./Desk";
export const Effect = () => (
  <Frame
    number="02"
    title={
      <>
        换一只手，<span style={{ color: "#bcd28e" }}>继续心流。</span>
      </>
    }
    subtitle="鼠标或触控板请求换向；键盘默认不抢主控。"
  >
    <Desk right />
    <div
      style={{
        position: "absolute",
        top: 815,
        left: 130,
        fontSize: 28,
        color: "#aabd99",
      }}
    >
      外接鼠标 ⇄ 内建触控板
    </div>
  </Frame>
);

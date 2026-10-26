import { Frame } from "./Frame";
import { Desk } from "./Desk";
export const Problem = () => (
  <Frame
    number="01"
    title={
      <>
        新 Mac mini。<span style={{ color: "#bcd28e" }}>熟悉的 MacBook。</span>
      </>
    }
    subtitle="两台混着用，账号不同，也想共享键鼠。"
  >
    <Desk />
    <div
      style={{
        position: "absolute",
        top: 825,
        left: 130,
        fontSize: 28,
        color: "#aabd99",
      }}
    >
      一张桌面，不必先合并账号。
    </div>
  </Frame>
);

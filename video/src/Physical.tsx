import { Frame } from "./Frame";
export const Physical = () => (
  <Frame
    number="03"
    title={
      <>
        四种组合。<span style={{ color: "#bcd28e" }}>键盘跟随光标。</span>
      </>
    }
    subtitle="敲任一副键盘，文字都去光标所在的 Mac；键盘不抢控。"
  >
    <div
      style={{
        position: "absolute",
        left: 130,
        right: 130,
        top: 340,
        border: "1px solid #536d43",
        borderRadius: 18,
        overflow: "hidden",
      }}
    >
      <div
        style={{
          display: "grid",
          gridTemplateColumns: "1fr 1fr 1.3fr",
          padding: "22px 35px",
          background: "#2c402c",
          fontSize: 25,
          color: "#bfd4a6",
        }}
      >
        <span>指针主控</span>
        <span>光标在哪</span>
        <span>两副键盘输入到</span>
      </div>
      {[
        ["Mac mini", "Mac mini"],
        ["Mac mini", "MacBook"],
        ["MacBook", "Mac mini"],
        ["MacBook", "MacBook"],
      ].map(([controller, cursor], i) => (
        <div
          key={i}
          style={{
            display: "grid",
            gridTemplateColumns: "1fr 1fr 1.3fr",
            padding: "22px 35px",
            borderTop: "1px solid #42583a",
            background: i % 2 ? "#203425" : "#1b2d21",
            fontSize: 30,
          }}
        >
          <span>{controller}</span>
          <span>{cursor}</span>
          <span style={{ color: "#d1e7a9" }}>→ {cursor}</span>
        </div>
      ))}
    </div>
    <div
      style={{
        position: "absolute",
        top: 805,
        left: 130,
        fontSize: 23,
        color: "#95aa83",
      }}
    >
      参考双机环境已由用户实测确认；通用安装仍需逐机验收。
    </div>
  </Frame>
);

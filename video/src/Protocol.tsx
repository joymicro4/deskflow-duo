import { Frame } from "./Frame";
export const Protocol = () => (
  <Frame
    number="04"
    title={
      <>
        指针换向。<span style={{ color: "#bcd28e" }}>键盘加密跟随。</span>
      </>
    }
    subtitle="断线放行本机输入；⌃⌥⌘K 紧急关闭，并弹出通知。"
  >
    <div
      style={{
        position: "absolute",
        top: 395,
        left: 130,
        right: 130,
        display: "flex",
        gap: 25,
        alignItems: "center",
      }}
    >
      {["物理按键", "加密通道", "主控端路由", "光标所在 Mac"].map((s, i) => (
        <div
          key={s}
          style={{
            flex: 1,
            border: "1px solid #6b8055",
            borderRadius: 18,
            padding: "45px 18px",
            fontSize: 31,
            textAlign: "center",
            background: "#223526",
          }}
        >
          <span
            style={{
              display: "block",
              fontSize: 20,
              color: "#9ab87b",
              marginBottom: 25,
            }}
          >
            0{i + 1}
          </span>
          {s}
        </div>
      ))}
    </div>
    <div
      style={{
        position: "absolute",
        top: 695,
        left: 130,
        fontSize: 54,
        color: "#d1e7a9",
      }}
    >
      ⌃ ⌥ ⌘ K{" "}
      <span style={{ fontSize: 29, color: "#aabd99", marginLeft: 30 }}>
        紧急开关 · 不用连按 Esc
      </span>
    </div>
  </Frame>
);

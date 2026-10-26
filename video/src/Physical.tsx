import { Frame } from "./Frame";
export const Physical = () => (
  <Frame
    number="03"
    title={
      <>
        只认<span style={{ color: "#bcd28e" }}>物理指针。</span>
      </>
    }
    subtitle="被控端的本地键盘只输入本机。先动指针，再打字。"
  >
    <div
      style={{
        position: "absolute",
        left: 130,
        right: 130,
        top: 380,
        display: "flex",
        gap: 32,
      }}
    >
      {[
        ["01", "外接鼠标", "IOHIDManager"],
        ["02", "内建触控板", "MultitouchSupport *"],
        ["03", "远端注入", "不触发抢控"],
      ].map(([n, t, s]) => (
        <div
          key={n}
          style={{
            flex: 1,
            border: "1px solid #4c6344",
            background: "#203126",
            borderRadius: 20,
            padding: 40,
            height: 340,
          }}
        >
          <div style={{ color: "#acc486", fontSize: 24 }}>{n}</div>
          <h2 style={{ fontSize: 37, marginTop: 60, fontWeight: 500 }}>{t}</h2>
          <div style={{ fontSize: 24, color: "#9daf8e" }}>{s}</div>
        </div>
      ))}
    </div>
    <div
      style={{
        position: "absolute",
        top: 770,
        left: 130,
        fontSize: 22,
        color: "#8fa47e",
      }}
    >
      * 私有框架；系统更新与唤醒后需复测
    </div>
  </Frame>
);

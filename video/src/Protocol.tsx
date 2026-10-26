import React from "react";
import { Frame } from "./Frame";
export const Protocol = () => (
  <Frame
    number="04"
    title={
      <>
        传输有保护。<span style={{ color: "#bcd28e" }}>切换有节奏。</span>
      </>
    }
    subtitle="Deskflow 传输，Duo 协调；TLS 互信，三秒防抖。"
  >
    <div
      style={{
        position: "absolute",
        top: 410,
        left: 130,
        right: 130,
        display: "flex",
        gap: 25,
        alignItems: "center",
      }}
    >
      {["物理输入", "达到阈值", "请求接管", "连接收敛"].map((s, i) => (
        <React.Fragment key={s}>
          <div
            style={{
              border: "1px solid #6b8055",
              borderRadius: 18,
              padding: "42px 26px",
              fontSize: 33,
              flex: 1,
              textAlign: "center",
              background: "#223526",
            }}
          >
            {s}
          </div>
          {i < 3 && <span style={{ fontSize: 33, color: "#bcd28e" }}>→</span>}
        </React.Fragment>
      ))}
    </div>
    <div
      style={{
        position: "absolute",
        top: 690,
        left: 130,
        display: "flex",
        gap: 80,
        fontSize: 29,
        color: "#b3c79d",
      }}
    >
      <span>🔒 双向校验证书指纹</span>
      <span>3s 防抖</span>
      <span>手动接管兜底</span>
    </div>
  </Frame>
);

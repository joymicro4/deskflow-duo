import React from "react";
import { interpolate, useCurrentFrame, useVideoConfig } from "remotion";
export const Desk: React.FC<{ right?: boolean }> = ({ right = false }) => {
  const f = useCurrentFrame();
  const { fps } = useVideoConfig();
  const x = interpolate(
    f,
    [0, 3 * fps, 6 * fps],
    [right ? 1050 : 430, right ? 700 : 850, right ? 430 : 1050],
    { extrapolateRight: "clamp" },
  );
  return (
    <div
      style={{
        position: "absolute",
        left: 150,
        right: 150,
        top: 360,
        display: "flex",
        gap: 90,
        justifyContent: "center",
      }}
    >
      {[false, true].map((r) => (
        <div
          key={String(r)}
          style={{ width: 620, opacity: r === right ? 1 : 0.7 }}
        >
          <div
            style={{
              height: 310,
              border: `12px solid ${r === right ? "#a9c47d" : "#6e7d6f"}`,
              borderRadius: 22,
              background: "#15281f",
              padding: 34,
              boxShadow: r === right ? "0 0 80px #8ea95b25" : "none",
            }}
          >
            <div style={{ fontSize: 15, letterSpacing: 4, color: "#8fa27d" }}>
              ● ● ●
            </div>
            <div
              style={{
                fontSize: 37,
                color: r ? "#e2e8be" : "#b6d4a0",
                marginTop: 55,
                fontFamily: "monospace",
              }}
            >
              {r ? "Space to create." : "Keep your flow."}
            </div>
            <div style={{ fontSize: 19, color: "#6e917c", marginTop: 16 }}>
              {r ? "MacBook · 内建触控板" : "Mac · 外接鼠标"}
            </div>
          </div>
          <div
            style={{
              height: 13,
              borderRadius: "0 0 20px 20px",
              background: "#8d9b8d",
              width: "108%",
              marginLeft: "-4%",
            }}
          />
          <div
            style={{
              textAlign: "center",
              fontSize: 21,
              color: "#96a88b",
              marginTop: 25,
            }}
          >
            {r === right ? "● 主控端" : "被控端"} /{" "}
            {r ? "右侧 Mac" : "左侧 Mac"}
          </div>
        </div>
      ))}
      <div
        style={{
          position: "absolute",
          left: x,
          top: 170,
          fontSize: 50,
          color: "#e3f2ba",
          textShadow: "0 5px 10px #000",
        }}
      >
        ➤
      </div>
      <div
        style={{
          position: "absolute",
          left: 740,
          top: 120,
          color: "#bad48b",
          fontSize: 46,
        }}
      >
        {right ? "←" : "→"}
      </div>
    </div>
  );
};

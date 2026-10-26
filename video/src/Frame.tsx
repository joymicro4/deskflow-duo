import React from "react";
import {
  AbsoluteFill,
  interpolate,
  useCurrentFrame,
  useVideoConfig,
} from "remotion";
export const Frame: React.FC<{
  number: string;
  title: React.ReactNode;
  subtitle: string;
  children?: React.ReactNode;
}> = ({ number, title, subtitle, children }) => {
  const f = useCurrentFrame();
  const { fps } = useVideoConfig();
  return (
    <AbsoluteFill
      style={{
        background: "#13231b",
        color: "#eff1df",
        fontFamily: '"PingFang SC",-apple-system,sans-serif',
      }}
    >
      <AbsoluteFill
        style={{
          background:
            "radial-gradient(ellipse at 80% 60%,#354a2833,transparent 70%)",
        }}
      />
      <div
        style={{
          position: "absolute",
          top: 65,
          left: 100,
          right: 100,
          display: "flex",
          justifyContent: "space-between",
          fontSize: 23,
          color: "#b8c89d",
        }}
      >
        <span>
          ◧ Deskflow Duo{" "}
          <span style={{ fontSize: 16, color: "#71876d" }}> / JOYMICRO</span>
        </span>
        <span style={{ fontSize: 16, letterSpacing: 3 }}>
          {number} / THE DESK RECIPE
        </span>
      </div>
      <div
        style={{
          position: "absolute",
          left: 130,
          top: 145,
          fontSize: 76,
          fontWeight: 600,
          lineHeight: 1.25,
          letterSpacing: -2,
          opacity: interpolate(f, [0, 0.65 * fps], [0, 1], {
            extrapolateRight: "clamp",
          }),
          translate: `0 ${interpolate(f, [0, 0.65 * fps], [24, 0], { extrapolateRight: "clamp" })}px`,
        }}
      >
        {title}
      </div>
      {children}
      <div
        style={{
          position: "absolute",
          bottom: 75,
          left: 130,
          right: 130,
          textAlign: "center",
          fontSize: 32,
          lineHeight: 1.6,
          color: "#dce5cf",
          background: "#0b17138c",
          padding: "16px 24px",
          borderRadius: 12,
        }}
      >
        {subtitle}
      </div>
      <div
        style={{
          position: "absolute",
          bottom: 28,
          right: 100,
          fontSize: 13,
          color: "#71876d",
        }}
      >
        动画示意 · AI 配音 · 双机预览版 · 请逐机验收
      </div>
    </AbsoluteFill>
  );
};

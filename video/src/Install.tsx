import { Frame } from "./Frame";
export const Install = () => (
  <Frame
    number="05"
    title={
      <>
        把这张桌面，<span style={{ color: "#bcd28e" }}>变成你的。</span>
      </>
    }
    subtitle="安装依赖、编辑配置、互信指纹，再亲手开启系统授权。"
  >
    <div
      style={{
        position: "absolute",
        left: 130,
        top: 345,
        width: 1020,
        padding: 38,
        background: "#0b1911",
        border: "1px solid #526c42",
        borderRadius: 20,
        font: "26px/2 monospace",
        color: "#c6dfa3",
      }}
    >
      <div style={{ color: "#6c8661", fontSize: 17 }}>TERMINAL / EACH MAC</div>
      <div>./scripts/install.sh config/local.json mac-left</div>
      <div>python3 scripts/duo.py trust PEER_SHA256</div>
      <div>python3 scripts/duo.py permissions</div>
      <div>python3 scripts/duo.py start</div>
      <div>python3 scripts/duo.py doctor</div>
    </div>
    <div
      style={{
        position: "absolute",
        left: 1230,
        top: 450,
        fontSize: 30,
        lineHeight: 2,
        color: "#adc398",
      }}
    >
      01 配置左右布局
      <br />
      02 核对证书指纹
      <br />
      03 授权并测试
    </div>
  </Frame>
);

import { Frame } from "./Frame";
export const Install = () => (
  <Frame
    number="05"
    title={
      <>
        五步，<span style={{ color: "#bcd28e" }}>连接你的桌面。</span>
      </>
    }
    subtitle="装依赖 → install → 指纹与密钥配对 → 双权限 → 自检。"
  >
    <div
      style={{
        position: "absolute",
        left: 130,
        top: 350,
        width: 1000,
        padding: 38,
        background: "#0b1911",
        border: "1px solid #526c42",
        borderRadius: 20,
        font: "26px/2 monospace",
        color: "#c6dfa3",
      }}
    >
      <div style={{ color: "#6c8661", fontSize: 17 }}>TERMINAL / EACH MAC</div>
      <div>./scripts/install.sh config/local.json mini</div>
      <div>python3 scripts/duo.py trust PEER_CERT_SHA256</div>
      <div>python3 scripts/duo.py key-fingerprint</div>
      <div>python3 scripts/duo.py permissions</div>
      <div>python3 scripts/duo.py start</div>
      <div>python3 scripts/duo.py doctor</div>
    </div>
    <div
      style={{
        position: "absolute",
        left: 1200,
        top: 435,
        fontSize: 28,
        lineHeight: 2,
        color: "#adc398",
      }}
    >
      01 装 Deskflow 与依赖
      <br />
      02 两台各跑 install
      <br />
      03 TLS + 共享密钥配对
      <br />
      04 输入监控 + 辅助功能
      <br />
      05 启动与四组合验收
    </div>
  </Frame>
);

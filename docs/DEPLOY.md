# 静态部署草案

此目录所有资源采用相对 URL，可托管在 GitHub Pages 或任意子路径。不要改 DNS 或替换站点首页。

## 已核对的 JoyMicro 现有流程

JoyMicro `website` 仓库为 Next.js，`vercel.json` 指定 `npm run build:vercel`。现有 CI 在 main 检查通过后使用 `vercel deploy --prod`，从 GitHub Secrets 注入 Vercel 凭据；没有依赖 GitHub/Vercel 自动集成。不要在此仓库复制那些凭据。

## 获准发布后

1. 先检查 website 当前分支与未提交文件，创建独立 worktree/分支。
2. 将本目录的 `index.html`、`style.css`、`app.js` 与 `assets/` **新增**到 website 的 `public/deskflow-duo/`。目标已存在则先备份并审阅，不覆盖现有产品内容。
3. 本地验证 `/deskflow-duo/index.html`、相对资源和视频 Range 请求。为 `/deskflow-duo` 增加精确重定向到 `/deskflow-duo/index.html`（仅在现有 Next/Vercel 配置需要时），不得添加通配 rewrite。
4. 提交 PR，跑 website 既有 lint/test/build。检查 diff 仅涉及新增目录及必要的精确路径规则。
5. 得到明确“发布”后才合并进入现有部署 CI；线上检查该路径、原首页与其他路由。失败时回滚该提交，不改 DNS。
6. 发布本仓库与带视频资产的 GitHub Release；如启用 Pages，仅发布 docs/，不得暴露本机报告与配置。

发布前：本仓库保持 private，网页和 MP4 只在本地预览；不得把示意视频当作实际双机验收证据。

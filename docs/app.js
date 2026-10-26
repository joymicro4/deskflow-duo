const desk = { controller: "mini", cursor: "mini" };
const nameOf = (value) => (value === "mini" ? "Mac mini" : "MacBook");
const renderDesk = () => {
  for (const [id, node] of [
    ["left", "mini"],
    ["right", "macbook"],
  ]) {
    document
      .getElementById(id)
      .classList.toggle("active", desk.controller === node);
    document
      .getElementById(id)
      .classList.toggle("cursor-target", desk.cursor === node);
  }
  for (const [id, chosen] of [
    ["external", desk.controller === "mini"],
    ["builtin", desk.controller === "macbook"],
    ["cursor-mini", desk.cursor === "mini"],
    ["cursor-macbook", desk.cursor === "macbook"],
  ]) {
    document.getElementById(id).classList.toggle("selected", chosen);
    document.getElementById(id).setAttribute("aria-pressed", String(chosen));
  }
  document.querySelector("#arrow").textContent =
    desk.controller === "mini" ? "→" : "←";
  document.querySelector("#status").textContent =
    `${nameOf(desk.controller)} 主控，光标在 ${nameOf(desk.cursor)}`;
  document.querySelector("#type-target").textContent = nameOf(desk.cursor);
};
document.querySelector("#external").onclick = () => {
  desk.controller = desk.cursor = "mini";
  renderDesk();
};
document.querySelector("#builtin").onclick = () => {
  desk.controller = desk.cursor = "macbook";
  renderDesk();
};
document.querySelector("#cursor-mini").onclick = () => {
  desk.cursor = "mini";
  renderDesk();
};
document.querySelector("#cursor-macbook").onclick = () => {
  desk.cursor = "macbook";
  renderDesk();
};
document.querySelector("#theme").onclick = () => {
  const dark =
    document.body.classList.contains("dark") ||
    (!document.body.classList.contains("light") &&
      matchMedia("(prefers-color-scheme: dark)").matches);
  document.body.classList.toggle("dark", !dark);
  document.body.classList.toggle("light", dark);
};
renderDesk();

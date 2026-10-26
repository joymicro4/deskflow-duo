const select = (right) => {
  document.querySelector("#left").classList.toggle("active", !right);
  document.querySelector("#right").classList.toggle("active", right);
  for (const [id, chosen] of [
    ["builtin", right],
    ["external", !right],
  ]) {
    document.getElementById(id).classList.toggle("selected", chosen);
    document.getElementById(id).setAttribute("aria-pressed", String(chosen));
  }
  document.querySelector("#arrow").textContent = right ? "←" : "→";
  document.querySelector("#status").textContent = right
    ? "右侧主控 → 用内建键盘与触控板，操作两台 Mac"
    : "左侧主控 → 指针越过边缘，即可操作右侧 Mac";
};
document.querySelector("#external").onclick = () => select(false);
document.querySelector("#builtin").onclick = () => select(true);
document.querySelector("#theme").onclick = () => {
  const dark =
    document.body.classList.contains("dark") ||
    (!document.body.classList.contains("light") &&
      matchMedia("(prefers-color-scheme: dark)").matches);
  document.body.classList.toggle("dark", !dark);
  document.body.classList.toggle("light", dark);
};

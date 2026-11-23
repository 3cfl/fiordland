(() => {
  let secret = location.hash.slice(1);
  history.replaceState(null, "", location.pathname);
  const form = document.querySelector("form");
  const token = document.querySelector("#token");
  const button = document.querySelector("button");
  const status = document.querySelector("#status");
  const clear = () => { token.value = ""; secret = ""; };
  if (!/^[A-Za-z\d_-]{43}$/.test(secret)) { token.disabled = true; status.textContent = "Open the complete private link to continue."; return; }
  button.disabled = false;
  status.textContent = "The token is checked directly with Discord.";
  form.addEventListener("submit", async (event) => {
    event.preventDefault();
    if (button.disabled) return;
    button.disabled = true;
    token.disabled = true;
    status.textContent = "Checking..";
    try {
      const response = await fetch(location.pathname, { method: "POST", headers: { "Content-Type": "application/json", Authorization: `Bearer ${secret}` }, body: JSON.stringify({ token: token.value.trim() }), cache: "no-store", redirect: "error", signal: AbortSignal.timeout(55000) });
      const result = await response.json();
      status.textContent = result.message;
      if (response.ok || [404, 410].includes(response.status)) { clear(); form.remove(); return; }
    } catch { status.textContent = "Couldn't connect. Try again shortly."; }
    token.disabled = false;
    button.disabled = false;
  });
  addEventListener("pagehide", clear);
})();

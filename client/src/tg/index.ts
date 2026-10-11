// Telegram Mini App wrapper — no-ops outside Telegram so the game runs
// standalone in any browser.
let webApp: typeof import("@twa-dev/sdk").default | null = null;

export async function initTelegram() {
  try {
    const mod = await import("@twa-dev/sdk");
    webApp = mod.default;
    webApp.ready();
    webApp.expand();
    webApp.setHeaderColor("#1a1420");
  } catch {
    webApp = null; // standalone browser
  }
}

export function haptic(strength: "light" | "medium" | "heavy" = "medium") {
  webApp?.HapticFeedback?.impactOccurred(strength);
}

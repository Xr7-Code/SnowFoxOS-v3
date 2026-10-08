## Focus & Sanctuary (`snowfox den`)

`snowfox den` (*Den* = Fox Burrow) is the integrated, highly flexible focus and sovereignty tool of SnowFoxOS v3. It shields your system at both the network and application levels from the commercial attention economy, extreme stimuli, and predatory engagement algorithms — without trapping you, consuming background RAM, or compromising your autonomy.

> **Philosophy of the Fox Den:**  
> A den is the quiet, impenetrable sanctuary where a fox retreats from external noise, threats, and overload. Activating Den Mode transforms your workstation from a commercial ad-and-consumption engine back into a neutral, high-productivity instrument.

---

### Key Capabilities & Philosophy

- **Zero-Footprint Design:** No background daemons, no resident processes, and 0 MB RAM consumption when idle.
- **Total User Sovereignty:** No irreversible paternalism. Every filter can be activated, deactivated, or modified via CLI in milliseconds.
- **Decoupling Over Total Bans:** Destructive engagement traps (Shorts, Reels, endless feeds) are neutralized, while access to knowledge, open-source software, and educational material remains intact.
- **Conscious Interruption Over Silent Blocking:** Blocked requests can optionally be redirected to a local, reflective sanctuary page designed to break dopamine feedback loops.

---

### Commands

| Command | Action |
|---|---|
| `snowfox den [on\|off]` | Activate or immediately disable Den Mode |
| `snowfox den status` | Display current status, active redirects, and blocklists |
| `snowfox den add <domain>` | Add a domain to the global blocklist |
| `snowfox den rm <domain>` | Remove a domain from the blocklist |
| `snowfox den list` | View the full list of blocked domains |
| `snowfox den redirect [on\|off]` | Enable/disable local landing page redirection for blocked sites |

---

### Architecture & Multi-Tier Protection

The module operates across two synergistic layers that work regardless of your desktop setup:

```text
[ Request: Pornhub / TikTok / Shorts ]
               │
               ├──► Tier 1: Network / DNS Level (/etc/hosts) ──► Block / Redirect to Local Sanctuary HTML
               │
               └──► Tier 2: Browser & Path Level (uBlock / Extensions) ──► Granular Path Filtering (Shorts/Reels)
```

#### Tier 1: System & Network Level (Domain Blocker)
When you run `snowfox den on`, the CLI appends the predefined list from `/etc/snowfox/den-domains.list` directly to `/etc/hosts` (`0.0.0.0`) and flushes the `systemd-resolved` DNS cache.

* **Adult & Explicit Content:** `pornhub.com`, `xhamster.com`, `xnxx.com`, `onlyfans.com`, `redtube.com`, etc.
* **Hyper-Stimuli & Feed Platforms:** `tiktok.com`, `instagram.com`, `twitter.com`, `x.com`, `reddit.com`.

#### Tier 2: Browser Choice & Granular Path Filtering
The exact behavior on micro-paths depends on your **choice of browser**:
* **Zen Browser (Default):** Shipped pre-configured with custom uBlock Origin rules that neutralize path-specific traps like `youtube.com/shorts/*` or `instagram.com/reels/*` while keeping main educational platforms accessible.
* **Alternative Browsers (Firefox, LibreWolf, Chromium):** System-wide domain blocking (Tier 1) operates universally at the OS level. For path-level filtering, you can import the custom filter profile into your preferred extension manager.

---

### YouTube Strategy: Granular Filtering vs. De-centralized Frontends

YouTube presents a dual nature: an indispensable repository of documentation and educational material, yet engineered with shorts and recommendation engines designed to maximize session length. `snowfox den` provides two distinct strategies:

1. **Granular Filtering (Default):** YouTube remains accessible, but `/shorts/`, recommended video sidebars, and comment sections are hidden.
2. **Hard-Block & De-centralized Rerouting:** You can add `youtube.com` to `/etc/snowfox/den-domains.list` and reroute your media consumption to privacy-focused, algorithm-free alternatives:
   - **Alternative Frontends (Invidious / Piped):** Access YouTube content without tracking, shorts channels, algorithmic funneling, or ads.
   - **Federated Video Networks (PeerTube):** Open-source, decentralized video platforms entirely disconnected from commercial monetization models.

```bash
# Add YouTube completely to the network blocklist:
snowfox den add youtube.com
```

---

### The Sanctuary Landing Page (`/etc/snowfox/den-sanctuary.html`)

Instead of throwing a cold connection error or silently dropping traffic, `snowfox den` can optionally point blocked browser requests to a local, minimal HTML landing page.

This page acts as a cognitive circuit breaker, offering three levels of awareness and action:

#### 1. Economic Reality & Awareness
A clear-eyed breakdown of how modern attention markets operate:
* **The Tobacco & Sugar Parallel:** Just as traditional consumer industries suppressed research on addiction and health impacts for decades, modern platform algorithms exploit biological evolutionary vulnerabilities.
* **Profit Over Well-Being:** Internal industry leaks consistently confirm that tech platforms are fully aware of the psychological impact on youth, yet prioritize engagement metrics over user health.

#### 2. Physical Impulse Resets (Circuit Breakers)
When the brain craves an instant dopamine hit, intellectual reasoning is often insufficient. Physical intervention resets the nervous system:
* 🏋️ **15–20 Push-ups / Squats:** Triggers motor function and releases natural endorphins, snapping you out of passive scrolling trances.
* 💧 **Cold Water Splash:** Activates the mammalian dive reflex, immediately lowering heart rate and reducing sympathetic nervous system arousal.
* 🚶 **5-Minute Walk / Stretch:** Creates physical separation from the display.

#### 3. Reorientation Toward Creation Over Consumption
Actionable prompts directing attention back toward constructive local tools:
* Open terminal (`Super + Enter`) and continue working on your local repository or project.
* Read a book or listen to intentional, non-algorithmic audio.
* Launch `snowfox focus-stats` or open your local Markdown workspace.

---

### Transparency & Local Configuration Files

All rules and templates exist in plain text on your local machine under full user control:

* `/etc/snowfox/den-domains.list` — Plaintext domain blocklist.
* `/etc/snowfox/den-sanctuary.html` — Customizable local landing page template.
* `/etc/snowfox/ublock-rules.txt` — Importable path-filtering rules for web browsers.

/**
 * KinoAsh.Surface client entrypoint — `init(ctx, data)`.
 *
 * Proven shape (S2 spike, GO verdict): this is the spike's boot path moved
 * into a Kino.JS asset. The bundle imports `@a2ui/lit/v0_9` (registers
 * `<a2ui-surface>`), hands the renderer classes to the vendored,
 * dependency-free ash_a2ui hook via `configureAshA2ui`, then drives the
 * hook's mounted()/handleEvent contract with a LiveView-shaped host object
 * and feeds the encoded server->client messages passed from Elixir.
 *
 * `data` is either a bare server->client message list (static kino) or
 * `%{messages: [...], interactive: true}` (KinoAsh.Interactive). In live
 * mode the host additionally forwards hook pushes over `ctx.pushEvent`
 * (the server runs them through AshA2ui.ActionHandler) and refreshes the
 * surface from `a2ui:messages` broadcasts.
 */

import {MessageProcessor} from "@a2ui/web_core/v0_9";
import {basicCatalog} from "@a2ui/lit/v0_9";
import "./vendor/ash_a2ui_theme.css";
import "./card.css";
import {AshA2ui, configureAshA2ui} from "./vendor/ash_a2ui_hook.js";

function isLivePayload(data) {
  return (
    data !== null &&
    typeof data === "object" &&
    !Array.isArray(data) &&
    Array.isArray(data.messages)
  );
}

/**
 * Minimal LiveView-shaped host: the glue Phoenix normally provides. The
 * hook object itself is the prototype (exactly how LiveView resolves the
 * hook's own methods — renderSkeleton, dismissSkeleton, ...), the host
 * supplies `el`, `handleEvent`, and `pushEvent`.
 */
class HookHost {
  constructor(el, forwardPush) {
    this.el = el;
    this.events = {};
    this.pushed = [];
    this.handleEvent = (name, cb) => {
      this.events[name] = cb;
    };
    // Static kino: no server roundtrip, actions are recorded only. The
    // live kino passes forwardPush and every hook push rides ctx.pushEvent
    // to the Kino.JS.Live server.
    this.forwardPush = forwardPush || null;
    this.pushEvent = (name, payload) => {
      this.pushed.push({name, payload});
      if (this.forwardPush) this.forwardPush(name, payload);
    };
  }

  receive(messages) {
    const cb = this.events["a2ui:messages"];
    if (!cb) throw new Error("kino_ash: hook did not subscribe to a2ui:messages");
    cb({messages});
  }
}

Object.setPrototypeOf(HookHost.prototype, AshA2ui);

/** Recursively counts interactive controls across shadow boundaries. */
function countControls(root) {
  let count = 0;
  const walk = (node) => {
    if (!node) return;
    if (node.querySelectorAll) {
      count += node.querySelectorAll("button, input, select, textarea, table").length;
    }
    const scopes = [...(node.children || [])];
    if (node.shadowRoot) scopes.push(node.shadowRoot);
    for (const scope of scopes) walk(scope);
  };
  walk(root);
  return count;
}

/** Resolves once the surface element exists and the bootstrap skeleton is gone. */
async function waitHydrated(container) {
  for (let i = 0; i < 100; i++) {
    const surface = container.querySelector("a2ui-surface");
    const skeletonGone = !container.querySelector("[data-ash-a2ui-skeleton]");
    if (surface && skeletonGone) {
      if (surface.updateComplete && typeof surface.updateComplete.then === "function") {
        await surface.updateComplete;
      }
      return surface;
    }
    await new Promise((resolve) => setTimeout(resolve, 100));
  }
  return null;
}

export async function init(ctx, data) {
  const live = isLivePayload(data);
  const messages = live ? data.messages : data;

  await ctx.importCSS("main.css");
  // Notebook-flavored face for the card; degrades to system-ui offline.
  ctx.importCSS(
    "https://fonts.googleapis.com/css2?family=DM+Sans:wght@400;500;700&display=swap",
  );

  const card = document.createElement("div");
  card.className = "kino-ash-card";
  const host = document.createElement("div");
  host.className = "kino-ash-card__surface";
  card.appendChild(host);
  ctx.root.appendChild(card);

  configureAshA2ui({MessageProcessor, catalogs: [basicCatalog]});

  const hook = new HookHost(
    host,
    live ? (name, payload) => ctx.pushEvent(name, payload) : null,
  );

  // Live kino: follow-up messages from the server (ActionHandler results)
  // arrive as a2ui:messages broadcasts and patch the mounted surface.
  if (live) {
    ctx.handleEvent("a2ui:messages", (payload) => {
      const incoming =
        payload && Array.isArray(payload.messages) ? payload.messages : payload;
      if (Array.isArray(incoming) && incoming.length > 0) hook.receive(incoming);
    });
  }

  AshA2ui.mounted.call(hook);
  hook.receive(Array.isArray(messages) ? messages : []);

  const surface = await waitHydrated(host);

  // Hydration marker for headless verification (and console debugging).
  const result = {
    hydrated: Boolean(surface),
    controlsDeep: countControls(host),
    hasObjectObject: host.textContent.includes("[object Object]"),
    live,
    pushed: hook.pushed.length,
  };
  ctx.root.setAttribute("data-a2ui-hydrated", String(result.hydrated));
  window.__KINO_A2UI_RESULT__ = result;
}

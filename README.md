# kino_ash

Kino/Livebook widgets for the Ash ecosystem: render a real
[A2UI](https://a2ui.org) surface — table, forms, empty states — from an Ash
resource, using the `@a2ui/lit` web components and the same encoder
`ash_a2ui` uses in Phoenix LiveView apps.

```elixir
KinoAsh.render(MyApp.Support.Ticket)
```

## Status: demo slice (S2 + I1)

This is the verified demo slice, not the full package:

- **S2 bundle spike** — a standalone-HTML esbuild bundle proving
  `@a2ui/lit` 0.11 renders a real surface in a plain iframe from
  ash_a2ui's encoded messages (playwright-verified headless: controls in
  shadow DOM, zero `[object Object]`). Its boot path is exactly what the
  shipped kino asset runs.
- **I1 package skeleton** — the static `KinoAsh.Surface` kino plus the
  `KinoAsh.render/2` convenience, with the esbuild output committed under
  `lib/assets/a2ui_surface/build/` (kino convention).

## API

```elixir
# Ash-aware: resolves the surface via AshA2ui.Info.build_surface/2
KinoAsh.render(MyApp.Support.Ticket, actor: actor)

# Standalone UI module (AshA2ui.Standalone)
KinoAsh.render(MyApp.UI.TicketUI)

# Lower level: pre-encoded messages — the same server->client payload the
# ash_a2ui JS hook consumes (string or atom keys; at least one createSurface)
KinoAsh.Surface.new(messages)

# ... or a builder MFA the notebook supplies
KinoAsh.Surface.new({MyApp.UI, :build_surface, [actor: actor]})

# export: false skips the .livemd spec digest on save
KinoAsh.render(MyApp.Support.Ticket, export: false)
```

`export: true` (the default) persists a **spec digest** — surface id,
catalog id, protocol version, component count, message kinds — never
record data, because kino assets are served unauthenticated.

## Dependencies

`ash_a2ui` comes in as a git dependency pinned to the exact tree the
vendored hook and committed bundle were verified against. Bump the ref
deliberately — and re-vendor `assets/a2ui_surface/vendor/` from
ash_a2ui's `priv/js` when you do, so the server encoder and client hook
stay a matched pair.

## Rebuilding the JS bundle

```sh
cd assets/a2ui_surface
npm install
npm run build   # -> ../../lib/assets/a2ui_surface/build/{main.js,main.css}
```

The output is committed; consumers never need node.

## Headless verification

```sh
docker run --rm --network host -u $(id -u):$(id -g) -e HOME=/tmp \
  -e MIX_HOME=/m -v mixhome:/m -v hexcache:/tmp/.cache \
  -v ~/ast-forks/kino_ash:/w \
  -w /w elixir:1.18.4-otp-27 \
  bash -c 'set -o pipefail; MIX_ENV=test mix deps.get && MIX_ENV=test mix test'
```

`test/kino_ash_test.exs` exercises the full render path (resource ->
encoder -> kino struct -> digest) with a minimal ETS-backed fixture
resource; `test/kino_ash/surface_test.exs` pins the message-feeding
contract and export behavior.

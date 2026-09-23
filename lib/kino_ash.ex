defmodule KinoAsh do
  @moduledoc """
  Kino/Livebook widgets for the Ash ecosystem, rendering real
  [A2UI](https://a2ui.org) surfaces with the `@a2ui/lit` web components.

  ## Render an Ash resource as a surface

  The headline API wraps `AshA2ui.Info.build_surface/2`: pass a resource
  (or a standalone `AshA2ui.Standalone` UI module) and get a kino
  showing the resource's surface — table, forms, empty states — driven by
  the same encoded messages `ash_a2ui` pushes over LiveView in Phoenix
  apps:

      KinoAsh.render(MyApp.Promotions.Promotion)

  Options are forwarded to `AshA2ui.Info.build_surface/2` (`:actor`,
  `:tenant`, `:authorize?`, `:domain`, ...); `:export` controls whether
  the rendered output persists a spec digest when the notebook is saved
  (default `true` — identity and shape only, never record data).

  ## Interactive surfaces (actions round-trip)

  Pass `live: true` to get a `Kino.JS.Live` kino (`KinoAsh.Interactive`)
  whose server runs surface actions through `AshA2ui.ActionHandler` and
  broadcasts the re-encoded surface back — Create/Edit genuinely write
  through Ash inside the notebook:

      KinoAsh.render(MyApp.Support.Ticket, live: true, actor: current_user)

  Interactive kinos default `authorize?: false` (notebooks are a developer
  context; the static kino has no server at all) — pass `authorize?: true`
  to enforce policies on the read and every dispatched action. Exported
  live kinos are marked `interactive: true` under the distinct
  `a2ui_surface_live` info string.

  ## Feed pre-encoded messages

  Already have the encoded messages (e.g. from your own pipeline)? The
  lower-level kino accepts them directly, no Ash dependency needed at the
  call site:

      messages = AshA2ui.Info.build_surface(MyApp.UI.PatientUI, actor: actor)
      KinoAsh.Surface.new(messages)

  or defer encoding to a builder the notebook supplies:

      KinoAsh.Surface.new({MyApp.UI, :build_surface, [actor: actor]})

  The message contract: a non-empty list of maps with at least one
  `createSurface` message — exactly the server->client payload the
  `ash_a2ui` JS hook consumes (see `priv/js/ash_a2ui_hook.js` there).
  """

  @doc """
  Renders an Ash resource's A2UI surface as a kino.

  Accepts an Ash resource with an `a2ui` section, or a standalone UI
  module (`use AshA2ui.Standalone`). Keyword options are forwarded to
  `AshA2ui.Info.build_surface/2`, except:

    * `:export` (boolean, default `true`) — toggles .livemd persistence
      of the spec digest.
    * `:live` (boolean, default `false`) — return an interactive
      `Kino.JS.Live` kino (`KinoAsh.Interactive`) that runs surface
      actions server-side, instead of the static `Kino.JS` kino. See
      `KinoAsh.Interactive` for the actor contract (`:authorize?`
      defaults to `false` there).
  """
  @spec render(module() | Spark.Dsl.t(), keyword()) :: Kino.JS.t() | Kino.JS.Live.t()
  def render(resource_or_ui_module, opts \\ []) do
    {live_opts, rest} = Keyword.split(opts, [:live])
    {surface_opts, ash_opts} = Keyword.split(rest, [:export])

    if live_opts[:live] do
      KinoAsh.Interactive.new(
        resource_or_ui_module,
        Keyword.take(surface_opts, [:export]) ++ ash_opts
      )
    else
      resource_or_ui_module
      |> AshA2ui.Info.build_surface(ash_opts)
      |> KinoAsh.Surface.new(surface_opts)
    end
  end

  @doc """
  Convenience delegate to `KinoAsh.Surface.new/2` for pre-encoded
  messages.
  """
  defdelegate surface(spec, opts \\ []), to: KinoAsh.Surface, as: :new
end

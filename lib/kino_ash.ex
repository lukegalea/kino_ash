defmodule KinoAsh do
  @moduledoc """
  Kino/Livebook widgets for the Ash ecosystem, rendering real
  [A2UI](https://a2ui.org) surfaces with the `@a2ui/lit` web components.

  ## Render an Ash resource as a surface

  The headline API wraps `AshA2ui.Info.build_surface/2`: pass a resource
  (or a standalone `AshA2ui.Standalone` UI module) and get a static kino
  showing the resource's surface — table, forms, empty states — driven by
  the same encoded messages `ash_a2ui` pushes over LiveView in Phoenix
  apps:

      KinoAsh.render(MyApp.Promotions.Promotion)

  Options are forwarded to `AshA2ui.Info.build_surface/2` (`:actor`,
  `:tenant`, `:authorize?`, `:domain`, ...); `:export` controls whether
  the rendered output persists a spec digest when the notebook is saved
  (default `true` — identity and shape only, never record data).

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
  Renders an Ash resource's A2UI surface as a static kino.

  Accepts an Ash resource with an `a2ui` section, or a standalone UI
  module (`use AshA2ui.Standalone`). Keyword options are forwarded to
  `AshA2ui.Info.build_surface/2`, except `:export` (boolean, default
  `true`), which toggles .livemd persistence of the spec digest.
  """
  @spec render(module() | Spark.Dsl.t(), keyword()) :: Kino.JS.t()
  def render(resource_or_ui_module, opts \\ []) do
    {surface_opts, ash_opts} = Keyword.split(opts, [:export])

    resource_or_ui_module
    |> AshA2ui.Info.build_surface(ash_opts)
    |> KinoAsh.Surface.new(surface_opts)
  end

  @doc """
  Convenience delegate to `KinoAsh.Surface.new/2` for pre-encoded
  messages.
  """
  defdelegate surface(spec, opts \\ []), to: KinoAsh.Surface, as: :new
end

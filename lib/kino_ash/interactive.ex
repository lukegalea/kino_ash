defmodule KinoAsh.Interactive do
  @moduledoc """
  Interactive `Kino.JS.Live` kino: renders an A2UI surface *and* runs its
  actions server-side.

  `KinoAsh.Surface` (static) renders an encoded surface and stops there —
  its client records hook pushes for debugging only. This kino closes the
  loop with pure Elixir: the client forwards the vendored hook's
  `a2ui:action` envelope over `ctx.pushEvent`, the server runs it through
  `AshA2ui.ActionHandler.handle/3` (the exact handler Phoenix apps wire to
  the same event), and the follow-up `updateDataModel` messages broadcast
  back to every connected client as `a2ui:messages` — the same vendored
  hook consumes them and the mounted surface re-renders. Submits create
  and update real records; validation errors land on `/errors/<field>`,
  successes on `/ui/status` (plus typed `/ui/feedback` under experience
  v2).

  ## The actor contract

  Actions (and the initial `AshA2ui.Info.build_surface/2` read) run with
  the `:actor` and `:tenant` given to `new/2`. `:authorize?` defaults to
  **false**: notebooks are a developer context, and the static kino has no
  server-side opinion at all. Pass `authorize?: true` — with an `actor:`
  where your policies require one — to enforce policies on the surface
  read and on every action the surface dispatches. The rendered affordances
  still come from the encoder; the server is the authority regardless of
  what the client shows (spoofed or non-allowlisted actions are rejected
  with a `/ui/status` error before touching Ash).

  ## Export

  `export: true` (the default) persists a spec digest like the static
  kino, but under the distinct `a2ui_surface_live` info string with
  `"interactive" => true`, so a saved notebook distinguishes
  action-carrying outputs from read-only ones. Record data is still
  excluded — kino assets are served unauthenticated.

  ## Client boot

  The client is the same committed bundle as the static kino (one asset
  tree for both kinos): `init` receives `%{messages: [...], interactive:
  true}` instead of a bare message list, forwards hook pushes via
  `ctx.pushEvent`, and patches the surface from `a2ui:messages` events.
  The static path is byte-for-byte the old boot.
  """

  use Kino.JS, assets_path: "lib/assets/a2ui_surface/build"
  use Kino.JS.Live

  @export_info_string "a2ui_surface_live"

  @doc """
  Starts the interactive surface kino for an Ash resource with an `a2ui`
  section, or a standalone UI module (`use AshA2ui.Standalone`).

  ## Options

    * `:actor` — actor for the initial read and every dispatched action.
    * `:tenant` — tenant for the initial read and every dispatched action.
    * `:authorize?` — enforce Ash policies on the read and the actions.
      Defaults to `false` (see "The actor contract" in the moduledoc).
    * `:domain` — forwarded to `AshA2ui.Info.build_surface/2`.
    * `:export` — persist a spec digest to .livemd on save (default `true`),
      flagged `"interactive" => true` under the `a2ui_surface_live` info
      string.
  """
  @spec new(module() | Spark.Dsl.t(), keyword()) :: Kino.JS.Live.t()
  def new(resource_or_ui_module, opts \\ []) do
    opts = Keyword.validate!(opts, [:actor, :tenant, :authorize?, :domain, :export])
    {export_opts, ash_opts} = Keyword.split(opts, [:export])
    ash_opts = Keyword.put_new(ash_opts, :authorize?, false)

    messages = AshA2ui.Info.build_surface(resource_or_ui_module, ash_opts)

    export_kw =
      if Keyword.get(export_opts, :export, true) do
        [export: &export_spec/1]
      else
        []
      end

    Kino.JS.Live.new(__MODULE__, {resource_or_ui_module, messages, ash_opts}, export_kw)
  end

  @impl true
  def init({resource_or_ui_module, messages, ash_opts}, ctx) do
    {:ok,
     Kino.JS.Live.Context.assign(
       ctx,
       resource: resource_or_ui_module,
       messages: messages,
       ash_opts: ash_opts
     )}
  end

  @impl true
  def handle_connect(ctx) do
    {:ok, %{messages: ctx.assigns.messages, interactive: true}, ctx}
  end

  @impl true
  def handle_event("a2ui:action", action_message, ctx) do
    ctx.assigns.resource
    |> handle_action(action_message, ctx.assigns.ash_opts)
    |> broadcast_followups(ctx)

    {:noreply, ctx}
  end

  # The hook also pushes `a2ui:function_response` (client function-call
  # results) when it sets wantResponse; the basic catalog needs none of
  # them. Unknown events are ignored, never crash the kino.
  def handle_event(_event, _payload, ctx), do: {:noreply, ctx}

  @doc false
  @spec handle_action(module() | Spark.Dsl.t(), term(), keyword()) ::
          {:ok, [map()]} | {:error, [map()]}
  def handle_action(resource, action_message, ash_opts) do
    AshA2ui.ActionHandler.handle(resource, action_message, ash_opts)
  end

  # Both action outcomes broadcast: `{:ok, followups}` patches records and
  # status; `{:error, followups}` carries the /errors and /ui/status writes
  # the client renders. A non-list result (ActionHandler contract violation)
  # is swallowed rather than crashing the kino server.
  defp broadcast_followups({tag, followups}, ctx) when tag in [:ok, :error] and is_list(followups) do
    Kino.JS.Live.Context.broadcast_event(ctx, "a2ui:messages", followups)
  end

  defp broadcast_followups(_other, _ctx), do: :ok

  @doc false
  @spec export_spec(Kino.JS.Live.Context.t()) :: {String.t(), map()}
  def export_spec(ctx) do
    digest =
      ctx.assigns.messages
      |> KinoAsh.Surface.spec_digest()
      |> Map.put("interactive", true)

    {@export_info_string, digest}
  end
end

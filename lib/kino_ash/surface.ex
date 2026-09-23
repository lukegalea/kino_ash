defmodule KinoAsh.Surface do
  @moduledoc """
  Static `Kino.JS` kino hosting an A2UI surface.

  The kino renders a bordered notebook-flavored card (2px ink border, hard
  shadow, DM Sans fallback) around an `<a2ui-surface>` element driven by
  the vendored, dependency-free `ash_a2ui` hook (the same hook Phoenix
  apps mount under LiveView): the bundle registers the `@a2ui/lit`
  renderer, feeds the encoded server->client messages through a
  `MessageProcessor`, and hands the resulting `SurfaceModel` to the
  element.

  ## The message contract

  `new/2` accepts either:

    * pre-encoded messages — a non-empty list of maps with at least one
      `createSurface` message (string or atom keys; atom keys are
      normalized to strings, matching the JSON wire shape), or
    * a `{module, function, args}` builder MFA — called eagerly at
      creation; it must return such a list.

  In Phoenix, `ash_a2ui` pushes these messages as the `"a2ui:messages"`
  LiveView event. Here the notebook (or `KinoAsh.render/2`) supplies them
  directly, so the kino stays host-agnostic.

  ## Export

  With `export: true` (the default), saving the notebook persists a *spec
  digest* — surface id, catalog id, protocol version, component count,
  message kinds — as the output's `a2ui_surface` info string. Record data
  is deliberately excluded: kino assets are served unauthenticated.
  """

  use Kino.JS, assets_path: "lib/assets/a2ui_surface/build"

  @export_info_string "a2ui_surface"

  @type spec :: [map()] | {module(), atom(), [term()]}

  @doc """
  Creates the surface kino from pre-encoded messages or a builder MFA.

  ## Options

    * `:export` — persist a spec digest to .livemd on save (default
      `true`).
  """
  @spec new(spec(), keyword()) :: Kino.JS.t()
  def new(spec, opts \\ [])

  def new({module, function, args}, opts) when is_atom(module) and is_atom(function) and is_list(args) do
    new(resolve_builder(module, function, args), opts)
  end

  def new(messages, opts) when is_list(messages) and messages != [] do
    opts = Keyword.validate!(opts, export: true)
    messages = normalize_messages!(messages)

    export_kw =
      if opts[:export] do
        [export: &export_spec/1]
      else
        []
      end

    Kino.JS.new(__MODULE__, messages, export_kw)
  end

  def new([], _opts) do
    raise ArgumentError,
          "KinoAsh.Surface.new/2 received an empty message list — an A2UI surface " <>
            "needs at least one createSurface message (see AshA2ui.Info.build_surface/2)"
  end

  def new(other, _opts) do
    raise ArgumentError,
          "KinoAsh.Surface.new/2 expects pre-encoded messages (list of maps) or a " <>
            "{module, function, args} builder, got: #{inspect(other)}"
  end

  @doc """
  Summarises an encoded message list: identity and shape only — surface
  id, catalog id, protocol version, component count, message kinds.

  This is what `export: true` persists to .livemd. Record data (rows,
  form values, options) is deliberately excluded: kino assets are served
  unauthenticated, so nothing user-specific may ride along.
  """
  @spec spec_digest(term()) :: map()
  def spec_digest(messages) do
    messages = normalize_messages(messages)

    create = Enum.find(messages, &Map.has_key?(&1, "createSurface"))
    components = components_of(messages)

    %{
      "surfaceId" => (create && create["createSurface"]["surfaceId"]) || nil,
      "catalogId" => (create && create["createSurface"]["catalogId"]) || nil,
      "specVersion" => version_of(messages),
      "components" => components,
      "messages" => Enum.map(messages, &message_kind/1)
    }
  end

  @doc false
  @spec export_spec(term()) :: {String.t(), map()}
  def export_spec(messages), do: {@export_info_string, spec_digest(messages)}

  # --- spec resolution ------------------------------------------------

  defp resolve_builder(module, function, args) do
    apply(module, function, args)
  rescue
    error ->
      raise ArgumentError,
            "KinoAsh.Surface.new/2 builder {#{inspect(module)}, #{inspect(function)}, " <>
              "#{inspect(args)}} failed: #{Exception.format(:error, error)}"
  end

  # --- message normalization --------------------------------------------

  defp normalize_messages!(messages) do
    normalized = Enum.map(messages, &normalize_message!/1)

    unless Enum.any?(normalized, &Map.has_key?(&1, "createSurface")) do
      raise ArgumentError,
            "KinoAsh.Surface.new/2: no createSurface message in the payload — an A2UI " <>
              "surface bootstrap must carry one (kinds found: " <>
              "#{Enum.map_join(normalized, ", ", &message_kind/1)})"
    end

    normalized
  end

  defp normalize_message!(message) when is_map(message) do
    deep_stringify_keys(message)
  end

  defp normalize_message!(other) do
    raise ArgumentError,
          "KinoAsh.Surface.new/2: every message must be a map, got: #{inspect(other)}"
  end

  # Digest-time normalization is defensive and idempotent: already-string
  # keyed messages pass through untouched.
  defp normalize_messages(messages) when is_list(messages) do
    messages
    |> Enum.filter(&is_map/1)
    |> Enum.map(&deep_stringify_keys/1)
  end

  defp deep_stringify_keys(map) when is_map(map) do
    Map.new(map, fn
      {key, value} when is_atom(key) -> {Atom.to_string(key), deep_stringify_keys(value)}
      {key, value} when is_binary(key) -> {key, deep_stringify_keys(value)}

      {key, _value} ->
        raise ArgumentError,
              "KinoAsh.Surface.new/2: message keys must be atoms or strings, got: #{inspect(key)}"
    end)
  end

  defp deep_stringify_keys(list) when is_list(list), do: Enum.map(list, &deep_stringify_keys/1)
  defp deep_stringify_keys(other), do: other

  # --- digest helpers ---------------------------------------------------

  defp version_of([first | _]) do
    case first do
      %{"version" => version} -> version
      _ -> nil
    end
  end

  defp version_of([]), do: nil

  defp message_kind(message) when is_map(message) do
    message
    |> Map.keys()
    |> Enum.reject(&(&1 == "version"))
    |> List.first()
  end

  # v0.9.1 carries a separate updateComponents message with a component
  # list; v1.0 carries components inline on the createSurface payload.
  defp components_of(messages) do
    update =
      Enum.find(messages, fn message ->
        message_kind(message) == "updateComponents"
      end)

    cond do
      update != nil ->
        components = update["updateComponents"]["components"]
        length(List.wrap(components))

      create = Enum.find(messages, &Map.has_key?(&1, "createSurface")) ->
        components = create["createSurface"]["components"] || []
        length(List.wrap(components))

      true ->
        0
    end
  end
end

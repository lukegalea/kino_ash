defmodule KinoAsh.SurfaceTest do
  use ExUnit.Case, async: true

  alias KinoAsh.Surface

  @fixture Path.join(__DIR__, "../fixtures/messages.exs")

  setup do
    {:ok, messages: @fixture |> Code.eval_file() |> elem(0)}
  end

  describe "new/2 with pre-encoded messages" do
    test "returns a static Kino.JS kino for this module", %{messages: messages} do
      kino = Surface.new(messages)

      assert %Kino.JS{} = kino
      assert kino.module == Surface
      # export defaults on
      assert kino.export == true
    end

    test "normalizes atom-keyed messages to the string-keyed wire shape", %{messages: messages} do
      atom_keyed =
        Enum.map(messages, fn message ->
          Map.new(message, fn {key, value} -> {String.to_atom(key), value} end)
        end)

      kino = Surface.new(atom_keyed)
      assert %Kino.JS{} = kino

      # The stored data is the normalized list: the export callback (which
      # runs on stored data) must find the surface id.
      {"a2ui_surface", digest} = Surface.export_spec(atom_keyed)
      assert digest["surfaceId"] == "minimal_standalone"
      assert kino.module == Surface
    end

    test "export: false disables the .livemd export", %{messages: messages} do
      kino = Surface.new(messages, export: false)
      assert kino.export == false
    end

    test "raises on an empty message list" do
      assert_raise ArgumentError, ~r/empty message list/, fn ->
        Surface.new([])
      end
    end

    test "raises on a non-list spec" do
      assert_raise ArgumentError, ~r/pre-encoded messages/, fn ->
        Surface.new(%{"createSurface" => %{"surfaceId" => "x"}})
      end
    end

    test "raises on non-map entries", %{messages: messages} do
      assert_raise ArgumentError, ~r/every message must be a map/, fn ->
        Surface.new(messages ++ ["nope"])
      end
    end

    test "raises when no createSurface message is present" do
      assert_raise ArgumentError, ~r/no createSurface message/, fn ->
        Surface.new([%{"version" => "v0.9.1", "updateDataModel" => %{"path" => "/", "value" => %{}}}])
      end
    end

    test "raises on non-string/atom keys" do
      assert_raise ArgumentError, ~r/keys must be atoms or strings/, fn ->
        Surface.new([%{1 => "oops", "createSurface" => %{"surfaceId" => "x"}}])
      end
    end
  end

  describe "new/2 with a builder MFA" do
    test "resolves the messages eagerly", %{messages: messages} do
      kino = Surface.new({__MODULE__, :fixture_messages, []})

      assert %Kino.JS{} = kino
      assert kino.module == Surface
      # The resolved data is exactly the fixture list.
      assert {"a2ui_surface", digest} = Surface.export_spec(messages)
      assert digest["surfaceId"] == "minimal_standalone"
    end

    test "wraps builder failures in an ArgumentError" do
      assert_raise ArgumentError, ~r/builder .* failed/, fn ->
        Surface.new({__MODULE__, :boom, []})
      end
    end
  end

  describe "spec_digest/1" do
    test "summarises identity and shape", %{messages: messages} do
      digest = Surface.spec_digest(messages)

      assert %{
               "surfaceId" => "minimal_standalone",
               "catalogId" =>
                 "https://a2ui.org/specification/v0_9/catalogs/basic/catalog.json",
               "specVersion" => "v0.9.1",
               "messages" => ["createSurface", "updateComponents", "updateDataModel"]
             } = digest

      assert is_integer(digest["components"])
      assert digest["components"] > 0
    end

    test "carries no record data", %{messages: messages} do
      digest = Surface.spec_digest(messages)
      encoded = inspect(digest)

      refute encoded =~ "Ada Lovelace"
      refute encoded =~ "Grace Hopper"
      refute Map.has_key?(digest, "records")
    end

    test "counts v1.0-style inline components" do
      messages = [
        %{
          "version" => "v1.0",
          "createSurface" => %{
            "surfaceId" => "inline",
            "catalogId" => "https://a2ui.org/specification/v1_0/catalogs/basic/catalog.json",
            "components" => [%{"id" => "root", "component" => "Column"}],
            "dataModel" => %{}
          }
        }
      ]

      digest = Surface.spec_digest(messages)
      assert digest["components"] == 1
      assert digest["specVersion"] == "v1.0"
    end
  end

  describe "export_spec/1" do
    test "returns the a2ui_surface info string with the digest", %{messages: messages} do
      assert {"a2ui_surface", digest} = Surface.export_spec(messages)
      assert digest["surfaceId"] == "minimal_standalone"
    end
  end

  describe "assets" do
    test "the committed bundle is packaged into kino's priv dir" do
      assert %{archive_path: archive_path, js_path: "main.js"} = Surface.__assets_info__()
      assert File.exists?(archive_path)
    end
  end

  # --- builder helpers ------------------------------------------------

  def fixture_messages do
    Code.eval_file(Path.join(__DIR__, "../fixtures/messages.exs")) |> elem(0)
  end

  def boom, do: raise("builder exploded")
end

defmodule KinoAshTest do
  @moduledoc """
  Smoke test: the full render path headlessly — resource (or standalone UI
  module) -> AshA2ui.Info.build_surface -> KinoAsh.Surface kino — with no
  Livebook involved.
  """

  use ExUnit.Case, async: true

  alias KinoAsh.Test.Minimal
  alias KinoAsh.Test.MinimalUI

  setup do
    {:ok, _} = Ash.create(Minimal, %{name: "Ada Lovelace"}, authorize?: false)
    {:ok, _} = Ash.create(Minimal, %{name: "Grace Hopper"}, authorize?: false)
    :ok
  end

  describe "render/2" do
    test "renders a resource's surface as a static kino" do
      kino = KinoAsh.render(Minimal, authorize?: false)

      assert %Kino.JS{} = kino
      assert kino.module == KinoAsh.Surface
      assert kino.export == true
    end

    test "renders a standalone UI module's surface" do
      kino = KinoAsh.render(MinimalUI, authorize?: false)
      assert %Kino.JS{} = kino
    end

    test "export: false propagates to the kino" do
      kino = KinoAsh.render(Minimal, authorize?: false, export: false)
      assert kino.export == false
    end

    test "the resolved payload carries the seeded records" do
      messages = AshA2ui.Info.build_surface(MinimalUI, authorize?: false)

      assert length(messages) == 3
      assert [%{"version" => "v0.9.1"}, %{}, %{}] = messages

      [create_surface | _] = messages
      assert %{"createSurface" => %{"surfaceId" => "kino_ash_minimal_standalone"}} =
               create_surface

      data_model = List.last(messages)
      assert %{"updateDataModel" => %{"path" => "/", "value" => value}} = data_model

      names = Enum.map(value["records"], & &1["name"])
      assert "Ada Lovelace" in names
      assert "Grace Hopper" in names

      # The digest must still exclude every record value.
      refute inspect(KinoAsh.Surface.spec_digest(messages)) =~ "Ada Lovelace"
    end
  end

  describe "surface/2" do
    test "delegates to KinoAsh.Surface.new for pre-encoded messages" do
      messages = AshA2ui.Info.build_surface(MinimalUI, authorize?: false)
      kino = KinoAsh.surface(messages, export: false)

      assert %Kino.JS{} = kino
      assert kino.module == KinoAsh.Surface
      assert kino.export == false
    end
  end
end

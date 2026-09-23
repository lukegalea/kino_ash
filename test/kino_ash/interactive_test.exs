defmodule KinoAsh.InteractiveTest do
  @moduledoc """
  Pins the Kino.JS.Live contract: client action pushes run through
  AshA2ui.ActionHandler and broadcast back as `a2ui:messages` follow-ups;
  connects receive the initial surface; the export digest distinguishes
  action-carrying outputs; the authorize? default is false.
  """

  use ExUnit.Case, async: true

  import Kino.Test

  alias KinoAsh.Test.Guarded
  alias KinoAsh.Test.Minimal

  setup :configure_livebook_bridge

  @action_envelope %{
    "version" => "v0.9.1",
    "action" => %{
      "name" => "submit_form",
      "context" => %{"values" => %{"name" => "Linus Torvalds"}}
    }
  }

  describe "new/2" do
    test "starts a live kino" do
      kino = KinoAsh.Interactive.new(Minimal)
      assert %Kino.JS.Live{} = kino
      assert kino.module == KinoAsh.Interactive
    end

    test "connects receive the initial surface flagged interactive" do
      kino = KinoAsh.Interactive.new(Minimal)

      assert %{interactive: true, messages: messages} = Kino.Test.connect(kino)
      assert [%{"version" => "v0.9.1"}, _, _] = messages
      assert %{"createSurface" => %{}} = hd(messages)
    end

    test "export defaults to a digest under the live info string, flagged interactive" do
      kino = KinoAsh.Interactive.new(Minimal)
      assert kino.export == true

      assert {"a2ui_surface_live", digest} = Kino.Test.export(kino)
      assert digest["interactive"] == true
      assert digest["messages"] == ["createSurface", "updateComponents", "updateDataModel"]
    end

    test "export: false disables the digest" do
      kino = KinoAsh.Interactive.new(Minimal, export: false)
      assert kino.export == false
    end
  end

  describe "action round-trip" do
    test "a pushed submit_form create runs the Ash action and broadcasts follow-ups" do
      kino = KinoAsh.Interactive.new(Minimal)
      %{ref: ref} = kino
      Kino.Test.connect(kino)

      Kino.Test.push_event(kino, "a2ui:action", @action_envelope)

      assert_receive {:runtime_broadcast, "js_live", ^ref,
                      {:event, "a2ui:messages", followups, _meta}},
                     500

      assert is_list(followups) and followups != []
      assert Enum.all?(followups, &Map.has_key?(&1, "updateDataModel"))

      # The /records refresh comes from the kino server's own re-read (the
      # private ETS table is per-process, so it is the honest view).
      records_write =
        Enum.find_value(followups, fn
          %{"updateDataModel" => %{"path" => "/records", "value" => value}} -> value
          _other -> nil
        end)

      assert [%{"name" => "Linus Torvalds"}] = records_write
    end

    test "unknown actions broadcast the error path without touching Ash" do
      kino = KinoAsh.Interactive.new(Minimal)
      %{ref: ref} = kino
      Kino.Test.connect(kino)

      Kino.Test.push_event(kino, "a2ui:action", %{
        "action" => %{"name" => "delete_everything", "context" => %{}}
      })

      assert_receive {:runtime_broadcast, "js_live", ^ref,
                      {:event, "a2ui:messages", followups, _meta}},
                     500

      assert [%{"updateDataModel" => %{"path" => "/ui/status", "value" => status}}] = followups
      assert status =~ "Unknown action"

      assert Ash.read!(Minimal) == []
    end

    test "unrelated pushed events are ignored" do
      kino = KinoAsh.Interactive.new(Minimal)
      Kino.Test.connect(kino)

      Kino.Test.push_event(kino, "a2ui:function_response", %{"id" => "x"})

      refute_receive {:runtime_broadcast, "js_live", _, _}, 100
    end

    test "handle_action runs the resource's action with the given opts" do
      assert {:ok, followups} =
               KinoAsh.Interactive.handle_action(Minimal, @action_envelope, authorize?: false)

      assert Enum.any?(followups, fn
               %{"updateDataModel" => %{"path" => "/ui/status", "value" => value}} ->
                 value =~ "Created"

               _other ->
                 false
             end)

      assert [%{name: "Linus Torvalds"}] = Ash.read!(Minimal)
    end
  end

  describe "authorize? contract" do
    test "defaults to false: actions run without an actor even on guarded resources" do
      kino = KinoAsh.Interactive.new(Guarded)
      Kino.Test.connect(kino)

      Kino.Test.push_event(kino, "a2ui:action", @action_envelope)

      assert_receive {:runtime_broadcast, "js_live", _ref,
                      {:event, "a2ui:messages", followups, _meta}},
                     500

      assert Enum.any?(followups, fn
               %{"updateDataModel" => %{"path" => "/records", "value" => rows}} ->
                 Enum.any?(rows, &(&1["name"] == "Linus Torvalds"))

               _other ->
                 false
             end)
    end

    test "authorize?: true enforces policies and reports forbidden via /ui/status" do
      assert {:error, messages} =
               KinoAsh.Interactive.handle_action(Guarded, @action_envelope, authorize?: true)

      assert Enum.any?(messages, fn
               %{"updateDataModel" => %{"path" => "/ui/status", "value" => value}} ->
                 value =~ "not authorized"

               _other ->
                 false
             end)

      # ...and an actor satisfies the policy.
      actor = %{id: "actor-1"}

      assert {:ok, followups} =
               KinoAsh.Interactive.handle_action(Guarded, @action_envelope,
                 authorize?: true,
                 actor: actor
               )

      assert Enum.any?(followups, fn
               %{"updateDataModel" => %{"path" => "/records", "value" => rows}} ->
                 Enum.any?(rows, &(&1["name"] == "Linus Torvalds"))

               _other ->
                 false
             end)
    end
  end

  describe "KinoAsh.render/2 live option" do
    test "live: true returns the interactive kino" do
      kino = KinoAsh.render(Minimal, live: true)
      assert %Kino.JS.Live{} = kino
      assert kino.module == KinoAsh.Interactive
    end

    test "live: true forwards export and ash opts" do
      kino = KinoAsh.render(Minimal, live: true, export: false)
      assert kino.export == false
    end

    test "default (no live) stays the static kino" do
      kino = KinoAsh.render(Minimal, authorize?: false)
      assert %Kino.JS{} = kino
      assert kino.module == KinoAsh.Surface
    end
  end
end

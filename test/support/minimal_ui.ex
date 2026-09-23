defmodule KinoAsh.Test.MinimalUI do
  @moduledoc """
  Standalone UI module fixture: an `a2ui` block living outside the
  resource, pointed at `KinoAsh.Test.Minimal` via `for_resource`.
  """

  use AshA2ui.Standalone

  a2ui do
    for_resource KinoAsh.Test.Minimal
    surface_id "kino_ash_minimal_standalone"

    component :table do
      fields [:name]
      read_action :read
    end

    field :name do
      label "Name (standalone)"
    end
  end
end

defmodule KinoAsh.Test.Minimal do
  @moduledoc """
  Minimal fixture resource: a single `name` attribute and the smallest
  possible `a2ui` block (mirrors AshA2ui.Test.Minimal).
  """

  use Ash.Resource,
    domain: KinoAsh.Test.Domain,
    data_layer: Ash.DataLayer.Ets,
    extensions: [AshA2ui]

  ets do
    private? true
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :string, public?: true
  end

  actions do
    defaults [:read, :destroy, create: :*, update: :*]
  end

  a2ui do
    component :table do
      fields [:name]
    end
  end
end

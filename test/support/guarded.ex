defmodule KinoAsh.Test.Guarded do
  @moduledoc """
  Policy-guarded fixture: every action authorizes only with an actor
  present. This is the behavioral pin for the interactive kino's
  `authorize?` contract (default `false`, opt-in `true`).
  """

  use Ash.Resource,
    domain: KinoAsh.Test.Domain,
    data_layer: Ash.DataLayer.Ets,
    authorizers: [Ash.Policy.Authorizer],
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

  policies do
    policy always() do
      authorize_if actor_present()
    end
  end

  a2ui do
    component :table do
      fields [:name]
    end

    component :form do
      fields [:name]
      create_action :create
    end
  end
end

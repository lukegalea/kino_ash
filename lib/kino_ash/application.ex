defmodule KinoAsh.Application do
  @moduledoc """
  `kino_ash` application supervisor.

  Registers nothing yet: this slice ships the static `KinoAsh.Surface`
  kino only. Smart cells and other long-running widgets arrive in a later
  slice and will join this supervision tree.
  """
  use Application

  @impl true
  def start(_type, _args) do
    Supervisor.start_link([], strategy: :one_for_one, name: KinoAsh.Supervisor)
  end
end

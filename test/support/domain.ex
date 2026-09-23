defmodule KinoAsh.Test.Domain do
  @moduledoc """
  Test domain for the minimal fixture resource (mirrors ash_a2ui's own
  test fixture shape).
  """

  use Ash.Domain, validate_config_inclusion?: false

  resources do
    resource KinoAsh.Test.Minimal
    resource KinoAsh.Test.Guarded
  end
end

defmodule KinoAsh.MixProject do
  use Mix.Project

  @version "0.1.0"
  @description "Kino/Livebook widgets rendering Ash surfaces with the A2UI web components"

  def project do
    [
      app: :kino_ash,
      version: @version,
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
      deps: deps(),
      description: @description,
      package: package()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {KinoAsh.Application, []}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:kino, "~> 0.19"},
      # Demo-slice wiring: resolve surfaces directly through ash_a2ui's
      # encoder. Repo integration (or a hex release) replaces the path dep.
      {:ash_a2ui, path: "../ash_a2ui"}
    ]
  end

  defp package do
    [
      # lib/assets/*/build carries the committed esbuild bundle (kino
      # convention) — it must ship in the package.
      files: ~w(lib assets mix.exs README.md LICENSE),
      licenses: ["MIT"],
      links: %{}
    ]
  end
end

defmodule SeedyDotDot.MixProject do
  use Mix.Project

  def project do
    [
      app: :seedy_dot_dot,
      version: "0.1.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: [
        {:bandit, "~> 1.14"},
        {:plug, "~> 1.20"}
      ]
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {SeedyDotDot.Application, []}
    ]
  end
end

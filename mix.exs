defmodule SeedyDotDot.MixProject do
  use Mix.Project

  def project do
    [
      app: :seedy_dot_dot,
      version: "0.1.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: []
    ]
  end

  def application, do: []
end

defmodule Mix.Tasks.SeedyDotDot.Web do
  @moduledoc """
  Starts the single-user SeedyDotDot web demo on port 4000.
  """

  use Mix.Task

  @shortdoc "Starts the SeedyDotDot web demo"

  @impl true
  def run(_args) do
    Mix.Task.run("app.start")

    {:ok, _pid} =
      Supervisor.start_child(
        SeedyDotDot.Supervisor,
        {Bandit, plug: SeedyDotDot.Web.Router, scheme: :http, port: 4000}
      )

    Mix.shell().info("SeedyDotDot is listening at http://localhost:4000")
    Process.sleep(:infinity)
  end
end

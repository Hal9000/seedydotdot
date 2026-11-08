defmodule SeedyDotDot.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    Supervisor.start_link(
      [SeedyDotDot.GameServer],
      strategy: :one_for_one,
      name: SeedyDotDot.Supervisor
    )
  end
end

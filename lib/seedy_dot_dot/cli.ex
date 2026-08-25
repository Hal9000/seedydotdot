defmodule SeedyDotDot.CLI do
  @moduledoc """
  A terminal adapter for the game engine.
  """

  alias SeedyDotDot.{Game, World}

  @spec start(Path.t()) :: :ok | {:error, String.t()}
  def start(world_path \\ default_world_path()) do
    with {:ok, world} <- World.load(world_path) do
      game = Game.new(world)
      IO.puts(elem(Game.command(game, "look"), 1))
      play(game)
    end
  end

  defp play(game) do
    case IO.gets("\n> ") do
      nil ->
        :ok

      command ->
        case String.trim(command) |> String.downcase() do
          "quit" ->
            :ok

          "exit" ->
            :ok

          "q" ->
            :ok
          _ ->
            {new_game, output} = Game.command(game, command)
            IO.puts(output)
            play(new_game)
        end
    end
  end

  defp default_world_path do
    Path.expand("../../priv/dungeon.txt", __DIR__)
  end
end

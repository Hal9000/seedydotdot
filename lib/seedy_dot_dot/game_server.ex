defmodule SeedyDotDot.GameServer do
  @moduledoc """
  Holds one running game and its transcript for the web demo.
  """

  use GenServer

  alias SeedyDotDot.{Game, World}

  @type entry :: %{command: String.t(), output: String.t()}

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(options \\ []) do
    GenServer.start_link(__MODULE__, options, name: __MODULE__)
  end

  @spec command(String.t()) :: [entry()]
  def command(command), do: GenServer.call(__MODULE__, {:command, command})

  @spec transcript() :: [entry()]
  def transcript, do: GenServer.call(__MODULE__, :transcript)

  @spec restart() :: [entry()]
  def restart, do: command("restart")

  @impl true
  def init(_options) do
    case World.load(default_world_path()) do
      {:ok, world} ->
        game = Game.new(world)
        {:ok, %{game: game, transcript: [%{command: "look", output: output(game, "look")}]}}

      {:error, reason} ->
        {:stop, reason}
    end
  end

  @impl true
  def handle_call({:command, command}, _from, %{game: game, transcript: transcript} = state) do
    {new_game, game_output} = Game.command(game, command)
    new_transcript = transcript ++ [%{command: command, output: game_output}]
    {:reply, new_transcript, %{state | game: new_game, transcript: new_transcript}}
  end

  def handle_call(:transcript, _from, %{transcript: transcript} = state) do
    {:reply, transcript, state}
  end

  defp output(game, command), do: game |> Game.command(command) |> elem(1)
  defp default_world_path, do: Path.expand("../../priv/dungeon.txt", __DIR__)
end

defmodule SeedyDotDot.Game do
  @moduledoc """
  The mutable state and command interface for one game session.
  """

  alias SeedyDotDot.World

  defstruct [:world, :current_room]

  @type t :: %__MODULE__{world: World.t(), current_room: String.t()}

  @directions %{
    "north" => "north",
    "n" => "north",
    "south" => "south",
    "s" => "south",
    "east" => "east",
    "e" => "east",
    "west" => "west",
    "w" => "west"
  }

  @spec new(World.t()) :: t()
  def new(%World{} = world), do: %__MODULE__{world: world, current_room: world.start_room}

  @spec command(t(), String.t()) :: {t(), String.t()}
  def command(%__MODULE__{} = game, command) when is_binary(command) do
    case command |> String.trim() |> String.downcase() do
      "look" -> {game, describe_current_room(game)}
      direction when is_map_key(@directions, direction) -> move(game, @directions[direction])
      _ -> {game, "I don't understand that."}
    end
  end

  defp move(game, direction) do
    current_room = room(game)

    case Map.fetch(current_room.exits, direction) do
      {:ok, destination} ->
        moved_game = %{game | current_room: destination}
        {moved_game, describe_current_room(moved_game)}

      :error ->
        {game, "You can't go that way."}
    end
  end

  defp describe_current_room(game), do: room(game).description
  defp room(game), do: Map.fetch!(game.world.rooms, game.current_room)
end

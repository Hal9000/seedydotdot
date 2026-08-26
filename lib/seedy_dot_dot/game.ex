defmodule SeedyDotDot.Game do
  @moduledoc """
  The mutable state and command interface for one game session.
  """

  alias SeedyDotDot.{Text, World}

  defstruct [:world, :current_room, object_locations: %{}, facts: MapSet.new(), choose: nil]

  @type t :: %__MODULE__{
          world: World.t(),
          current_room: String.t(),
          object_locations: %{String.t() => String.t() | :inventory},
          facts: MapSet.t(String.t()),
          choose: ([String.t()] -> String.t())
        }

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
  def new(%World{} = world), do: new(world, [])

  @spec new(World.t(), keyword()) :: t()
  def new(%World{} = world, options) do
    object_locations = Map.new(world.objects, fn {id, object} -> {id, object.location} end)

    %__MODULE__{
      world: world,
      current_room: world.start_room,
      object_locations: object_locations,
      facts: world.facts,
      choose: Keyword.get(options, :choose, &choose_random/1)
    }
  end

  @spec true?(t(), String.t()) :: boolean()
  def true?(%__MODULE__{} = game, "carrying." <> object_id),
    do: game.object_locations[object_id] == :inventory

  def true?(%__MODULE__{} = game, "here." <> object_id),
    do: game.object_locations[object_id] == game.current_room

  def true?(%__MODULE__{} = game, fact), do: MapSet.member?(game.facts, fact)

  @spec command(t(), String.t()) :: {t(), String.t()}
  def command(%__MODULE__{} = game, command) when is_binary(command) do
    case command |> String.trim() |> String.downcase() do
      "look" -> {game, describe_current_room(game)}
      "inventory" -> {game, inventory(game)}
      "i" -> {game, inventory(game)}
      "take " <> noun -> take(game, noun)
      "get " <> noun -> take(game, noun)
      "drop " <> noun -> drop(game, noun)
      "examine " <> noun -> examine(game, noun)
      "look at " <> noun -> examine(game, noun)
      "x " <> noun -> examine(game, noun)
      direction when is_map_key(@directions, direction) -> move(game, @directions[direction])
      action -> run_action(game, action)
    end
  end

  defp move(game, direction) do
    current_room = room(game)

    case Map.fetch(current_room.exits, direction) do
      {:ok, %{destination: destination, condition: condition}} ->
        if is_nil(condition) or true?(game, condition) do
          moved_game = %{game | current_room: destination}
          {moved_game, describe_current_room(moved_game)}
        else
          {game, "You can't go that way."}
        end

      :error ->
        {game, "You can't go that way."}
    end
  end

  defp run_action(game, command) do
    case Map.fetch(game.world.actions, command) do
      {:ok, action} ->
        if Enum.all?(action.requirements, &true?(game, &1)) do
          apply_effects(game, action.effects)
        else
          {game, "That doesn't seem to work."}
        end

      :error ->
        {game, "I don't understand that."}
    end
  end

  defp apply_effects(game, effects) do
    {new_game, output} =
      Enum.reduce(effects, {game, []}, fn
        %{type: :say, text: text}, {game, output} ->
          {game, output ++ [render(game, text)]}

        %{type: :set, fact: fact}, {game, output} ->
          {%{game | facts: MapSet.put(game.facts, fact)}, output}

        %{type: :clear, fact: fact}, {game, output} ->
          {%{game | facts: MapSet.delete(game.facts, fact)}, output}
      end)

    {new_game, Enum.join(output, "\n")}
  end

  defp take(game, noun) do
    with {:ok, object_id, object} <- find_object(game, noun),
         :ok <- object_here(game, object_id),
         :ok <- portable(object) do
      {%{game | object_locations: Map.put(game.object_locations, object_id, :inventory)},
       "Taken."}
    else
      :not_found -> {game, "You don't see that here."}
      :not_here -> {game, "You don't see that here."}
      {:fixed, object} -> {game, "You can't take the #{object.name}."}
    end
  end

  defp drop(game, noun) do
    with {:ok, object_id, _object} <- find_object(game, noun),
         :ok <- carrying(game, object_id) do
      {%{game | object_locations: Map.put(game.object_locations, object_id, game.current_room)},
       "Dropped."}
    else
      :not_found -> {game, "You aren't carrying that."}
      :not_carrying -> {game, "You aren't carrying that."}
    end
  end

  defp examine(game, noun) do
    with {:ok, object_id, object} <- find_object(game, noun),
         :ok <- accessible(game, object_id) do
      {game, render(game, object.description)}
    else
      :not_found -> {game, "You don't see that here."}
      :not_accessible -> {game, "You don't see that here."}
    end
  end

  defp inventory(game) do
    case object_names_at(game, :inventory) do
      [] -> "You aren't carrying anything."
      names -> "You are carrying: #{Enum.join(names, ", ")}."
    end
  end

  defp describe_current_room(game) do
    description = render(game, room(game).description)

    case object_names_at(game, game.current_room) do
      [] -> description
      names -> "#{description}\n\nYou see here: #{Enum.join(names, ", ")}."
    end
  end

  defp find_object(game, noun) do
    normalized_noun = String.trim(noun)

    case Enum.find(game.world.objects, fn {id, object} ->
           id == normalized_noun or String.downcase(object.name) == normalized_noun
         end) do
      {id, object} -> {:ok, id, object}
      nil -> :not_found
    end
  end

  defp object_here(game, object_id) do
    if game.object_locations[object_id] == game.current_room, do: :ok, else: :not_here
  end

  defp carrying(game, object_id) do
    if game.object_locations[object_id] == :inventory, do: :ok, else: :not_carrying
  end

  defp accessible(game, object_id) do
    if game.object_locations[object_id] in [game.current_room, :inventory],
      do: :ok,
      else: :not_accessible
  end

  defp portable(%{portable: true}), do: :ok
  defp portable(object), do: {:fixed, object}

  defp object_names_at(game, location) do
    game.object_locations
    |> Enum.filter(fn {_id, object_location} -> object_location == location end)
    |> Enum.map(fn {id, _location} -> game.world.objects[id].name end)
    |> Enum.sort()
  end

  defp render(game, text), do: Text.render(text, game, game.choose)

  defp choose_random(alternatives),
    do: Enum.at(alternatives, :rand.uniform(length(alternatives)) - 1)

  defp room(game), do: Map.fetch!(game.world.rooms, game.current_room)
end

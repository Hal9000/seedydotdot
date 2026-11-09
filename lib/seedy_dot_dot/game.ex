defmodule SeedyDotDot.Game do
  @moduledoc """
  The mutable state and command interface for one game session.
  """

  alias SeedyDotDot.{Text, World}

  defstruct [
    :world,
    :current_room,
    object_locations: %{},
    facts: %{},
    fired_events: MapSet.new(),
    status: :playing,
    choose: nil
  ]

  @type t :: %__MODULE__{
          world: World.t(),
          current_room: String.t(),
          object_locations: %{String.t() => String.t() | :inventory},
          facts: %{String.t() => boolean()},
          fired_events: MapSet.t(String.t()),
          status: :playing | :won,
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
      fired_events: MapSet.new(),
      status: :playing,
      choose: Keyword.get(options, :choose, &choose_random/1)
    }
  end

  @spec true?(t(), String.t()) :: boolean()
  def true?(%__MODULE__{} = game, "carrying." <> object_id),
    do: game.object_locations[object_id] == :inventory

  def true?(%__MODULE__{} = game, "here." <> object_id),
    do: game.object_locations[object_id] == game.current_room

  def true?(%__MODULE__{} = game, fact), do: Map.get(game.facts, fact, false)

  @spec command(t(), String.t()) :: {t(), String.t()}
  def command(%__MODULE__{} = game, command) when is_binary(command) do
    normalized_command = command |> String.trim() |> String.downcase()

    case normalized_command do
      "restart" ->
        restart(game)

      _ when game.status != :playing ->
        {game, "The game is over. Type restart to play again."}

      "look" ->
        {game, describe_current_room(game)}

      "inventory" ->
        {game, inventory(game)}

      "i" ->
        {game, inventory(game)}

      "take " <> noun ->
        take(game, noun)

      "get " <> noun ->
        take(game, noun)

      "drop " <> noun ->
        drop(game, noun)

      "examine " <> noun ->
        examine(game, noun)

      "look at " <> noun ->
        examine(game, noun)

      "x " <> noun ->
        examine(game, noun)

      direction when is_map_key(@directions, direction) ->
        move(game, @directions[direction])

      action ->
        run_action(game, action)
    end
  end

  defp move(game, direction) do
    current_room = room(game)

    case Map.fetch(current_room.exits, direction) do
      {:ok, %{destination: destination, condition: condition}} ->
        if is_nil(condition) or true?(game, condition) do
          moved_game = %{game | current_room: destination}
          {event_game, event_output} = run_events(moved_game, {:enter, destination})
          {event_game, join_output(describe_current_room(event_game), event_output)}
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
        if requirements_met?(game, action.requirements) do
          apply_effects(game, action.effects)
        else
          {game, "That doesn't seem to work."}
        end

      :error ->
        {game, "I don't understand that."}
    end
  end

  defp run_events(game, trigger) do
    {game, output} =
      Enum.reduce(game.world.event_order, {game, []}, fn event_id, {game, output} ->
        event = Map.fetch!(game.world.events, event_id)

        if event.trigger == trigger and
             (not event.once or not MapSet.member?(game.fired_events, event_id)) and
             requirements_met?(game, event.requirements) do
          {event_game, event_output} = apply_effects(game, event.effects)

          event_game =
            if event.once,
              do: %{event_game | fired_events: MapSet.put(event_game.fired_events, event_id)},
              else: event_game

          {event_game, output ++ [event_output]}
        else
          {game, output}
        end
      end)

    {game, output |> Enum.reject(&(&1 == "")) |> Enum.join("\n")}
  end

  defp requirements_met?(game, requirements), do: Enum.all?(requirements, &true?(game, &1))

  defp apply_effects(game, effects) do
    {new_game, output} =
      Enum.reduce(effects, {game, []}, fn
        %{type: :say, text: text}, {game, output} ->
          {game, output ++ [render(game, text)]}

        %{type: :set, fact: fact}, {game, output} ->
          {%{game | facts: Map.put(game.facts, fact, true)}, output}

        %{type: :clear, fact: fact}, {game, output} ->
          {%{game | facts: Map.put(game.facts, fact, false)}, output}

        %{type: :bug, id: "box_of_bugs"}, _state ->
          raise "The Box of Bugs has escaped into the runtime."

        %{type: :win}, {game, output} ->
          {%{game | status: :won}, output}
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

  defp join_output(primary, ""), do: primary
  defp join_output(primary, extra), do: "#{primary}\n\n#{extra}"

  defp restart(game) do
    new_game = new(game.world, choose: game.choose)
    {new_game, "A new game begins.\n\n#{describe_current_room(new_game)}"}
  end

  defp room(game), do: Map.fetch!(game.world.rooms, game.current_room)
end

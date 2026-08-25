defmodule SeedyDotDot.World do
  @moduledoc """
  Immutable world definitions loaded from the SeedyDotDot DSL.
  """

  defstruct [:start_room, rooms: %{}, objects: %{}, facts: MapSet.new()]

  @type exit :: %{destination: String.t(), condition: String.t() | nil}

  @type room :: %{
          id: String.t(),
          description: String.t(),
          exits: %{String.t() => exit()}
        }

  @type object :: %{
          id: String.t(),
          name: String.t(),
          description: String.t(),
          location: String.t(),
          portable: boolean()
        }

  @type t :: %__MODULE__{
          start_room: String.t(),
          rooms: %{String.t() => room()},
          objects: %{String.t() => object()},
          facts: MapSet.t(String.t())
        }

  @directions ~w(north south east west)

  @spec parse(String.t()) :: {:ok, t()} | {:error, String.t()}
  def parse(text) when is_binary(text) do
    with {:ok, world} <- parse_lines(String.split(text, "\n")),
         :ok <- validate(world) do
      {:ok, world}
    end
  end

  @spec load(Path.t()) :: {:ok, t()} | {:error, String.t()}
  def load(filename) do
    with {:ok, text} <- File.read(filename) do
      parse(text)
    else
      {:error, reason} -> {:error, "could not load world: #{:file.format_error(reason)}"}
    end
  end

  @spec validate(t()) :: :ok | {:error, String.t()}
  def validate(%__MODULE__{start_room: nil}), do: {:error, "world has no start room"}

  def validate(%__MODULE__{start_room: start_room, rooms: rooms, objects: objects, facts: facts}) do
    cond do
      not Map.has_key?(rooms, start_room) ->
        {:error, "start room #{inspect(start_room)} does not exist"}

      true ->
        with :ok <- validate_exits(rooms, facts, objects) do
          validate_objects(objects, rooms)
        end
    end
  end

  defp parse_lines(lines), do: parse_lines(lines, %__MODULE__{})

  defp parse_lines([], %__MODULE__{} = world), do: {:ok, world}

  defp parse_lines([line | rest], world) do
    case String.trim(line) do
      "" ->
        parse_lines(rest, world)

      "start " <> room_id ->
        parse_start(room_id, rest, world)

      "room " <> room_id ->
        parse_room(room_id, rest, world)

      "object " <> object_id ->
        parse_object(object_id, rest, world)

      "fact " <> fact ->
        parse_fact(fact, rest, world)

      directive ->
        {:error, "unexpected directive: #{inspect(directive)}"}
    end
  end

  defp parse_start("", _rest, _world), do: {:error, "start requires a room ID"}

  defp parse_start(_room_id, _rest, %__MODULE__{start_room: start}) when not is_nil(start),
    do: {:error, "world has more than one start room"}

  defp parse_start(room_id, rest, world),
    do: parse_lines(rest, %{world | start_room: room_id})

  defp parse_fact("", _rest, _world), do: {:error, "fact requires a name"}

  defp parse_fact(fact, rest, %__MODULE__{facts: facts} = world) do
    if MapSet.member?(facts, fact) do
      {:error, "fact #{inspect(fact)} is defined more than once"}
    else
      parse_lines(rest, %{world | facts: MapSet.put(facts, fact)})
    end
  end

  defp parse_room("", _rest, _world), do: {:error, "room requires an ID"}

  defp parse_room(room_id, _rest, %__MODULE__{rooms: rooms}) when is_map_key(rooms, room_id),
    do: {:error, "room #{inspect(room_id)} is defined more than once"}

  defp parse_room(room_id, lines, world) do
    with {:ok, room, rest} <- parse_room_body(lines, %{id: room_id, prose: [], exits: %{}}) do
      room = Map.put(room, :description, room.prose |> Enum.reverse() |> Enum.join("\n"))
      parse_lines(rest, %{world | rooms: Map.put(world.rooms, room_id, Map.delete(room, :prose))})
    end
  end

  defp parse_room_body([], _room), do: {:error, "room is missing end"}
  defp parse_room_body(["end" | rest], room), do: {:ok, room, rest}

  defp parse_room_body([line | rest], room) do
    trimmed = String.trim(line)

    case String.split(trimmed, ~r/\s+/, parts: 2) do
      [direction, destination] when direction in @directions ->
        if Map.has_key?(room.exits, direction) do
          {:error, "room #{inspect(room.id)} defines #{direction} more than once"}
        else
          with {:ok, exit} <- parse_exit(destination) do
            parse_room_body(rest, %{room | exits: Map.put(room.exits, direction, exit)})
          end
        end

      _ ->
        parse_room_body(rest, %{room | prose: [String.trim_trailing(line) | room.prose]})
    end
  end

  defp parse_exit(destination) do
    case String.split(destination, " if ", parts: 2) do
      [room_id] ->
        {:ok, %{destination: room_id, condition: nil}}

      [room_id, condition] when room_id != "" and condition != "" ->
        {:ok, %{destination: room_id, condition: condition}}

      _ ->
        {:error, "exit has an invalid condition"}
    end
  end

  defp parse_object("", _rest, _world), do: {:error, "object requires an ID"}

  defp parse_object(object_id, _rest, %__MODULE__{objects: objects})
       when is_map_key(objects, object_id),
       do: {:error, "object #{inspect(object_id)} is defined more than once"}

  defp parse_object(object_id, _rest, %__MODULE__{rooms: rooms})
       when is_map_key(rooms, object_id),
       do: {:error, "object #{inspect(object_id)} conflicts with a room ID"}

  defp parse_object(object_id, lines, world) do
    object = %{id: object_id, name: nil, description: nil, location: nil, portable: nil}

    with {:ok, object, rest} <- parse_object_body(lines, object),
         :ok <- validate_object_fields(object) do
      parse_lines(rest, %{world | objects: Map.put(world.objects, object_id, object)})
    end
  end

  defp parse_object_body([], _object), do: {:error, "object is missing end"}
  defp parse_object_body(["end" | rest], object), do: {:ok, object, rest}

  defp parse_object_body([line | rest], object) do
    case String.trim(line) do
      "name " <> name when name != "" ->
        parse_object_body(rest, %{object | name: name})

      "description " <> description when description != "" ->
        parse_object_body(rest, %{object | description: description})

      "at " <> location when location != "" ->
        parse_object_body(rest, %{object | location: location})

      "portable" ->
        parse_object_body(rest, %{object | portable: true})

      "fixed" ->
        parse_object_body(rest, %{object | portable: false})

      directive ->
        {:error, "unexpected object directive: #{inspect(directive)}"}
    end
  end

  defp validate_object_fields(%{id: id, name: nil}),
    do: {:error, "object #{inspect(id)} has no name"}

  defp validate_object_fields(%{id: id, description: nil}),
    do: {:error, "object #{inspect(id)} has no description"}

  defp validate_object_fields(%{id: id, location: nil}),
    do: {:error, "object #{inspect(id)} has no starting location"}

  defp validate_object_fields(%{id: id, portable: nil}),
    do: {:error, "object #{inspect(id)} must be portable or fixed"}

  defp validate_object_fields(_object), do: :ok

  defp validate_exits(rooms, facts, objects) do
    Enum.reduce_while(rooms, :ok, fn {room_id, room}, :ok ->
      case Enum.find(room.exits, fn {_direction, exit} ->
             not Map.has_key?(rooms, exit.destination) or
               not valid_condition?(exit.condition, facts, objects)
           end) do
        nil ->
          {:cont, :ok}

        {direction, %{destination: destination}} when not is_map_key(rooms, destination) ->
          {:halt,
           {:error,
            "room #{inspect(room_id)} has #{direction} exit to missing room #{inspect(destination)}"}}

        {direction, %{condition: condition}} ->
          {:halt,
           {:error,
            "room #{inspect(room_id)} has #{direction} exit with unknown fact #{inspect(condition)}"}}
      end
    end)
  end

  defp valid_condition?(nil, _facts, _objects), do: true

  defp valid_condition?("carrying." <> object_id, _facts, objects),
    do: Map.has_key?(objects, object_id)

  defp valid_condition?("here." <> object_id, _facts, objects),
    do: Map.has_key?(objects, object_id)

  defp valid_condition?(fact, facts, _objects), do: MapSet.member?(facts, fact)

  defp validate_objects(objects, rooms) do
    Enum.reduce_while(objects, :ok, fn {object_id, object}, :ok ->
      if Map.has_key?(rooms, object.location) do
        {:cont, :ok}
      else
        {:halt,
         {:error,
          "object #{inspect(object_id)} starts in missing room #{inspect(object.location)}"}}
      end
    end)
  end
end

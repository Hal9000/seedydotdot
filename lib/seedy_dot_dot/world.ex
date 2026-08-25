defmodule SeedyDotDot.World do
  @moduledoc """
  Immutable world definitions loaded from the SeedyDotDot DSL.
  """

  defstruct [:start_room, rooms: %{}]

  @type room :: %{id: String.t(), description: String.t(), exits: %{String.t() => String.t()}}
  @type t :: %__MODULE__{start_room: String.t(), rooms: %{String.t() => room()}}

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

  def validate(%__MODULE__{start_room: start_room, rooms: rooms}) do
    cond do
      not Map.has_key?(rooms, start_room) ->
        {:error, "start room #{inspect(start_room)} does not exist"}

      true ->
        validate_exits(rooms)
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

      directive ->
        {:error, "unexpected directive: #{inspect(directive)}"}
    end
  end

  defp parse_start("", _rest, _world), do: {:error, "start requires a room ID"}
  defp parse_start(_room_id, _rest, %__MODULE__{start_room: start}) when not is_nil(start),
    do: {:error, "world has more than one start room"}

  defp parse_start(room_id, rest, world),
    do: parse_lines(rest, %{world | start_room: room_id})

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
          parse_room_body(rest, %{room | exits: Map.put(room.exits, direction, destination)})
        end

      _ ->
        parse_room_body(rest, %{room | prose: [String.trim_trailing(line) | room.prose]})
    end
  end

  defp validate_exits(rooms) do
    Enum.reduce_while(rooms, :ok, fn {room_id, room}, :ok ->
      case Enum.find(room.exits, fn {_direction, destination} ->
             not Map.has_key?(rooms, destination)
           end) do
        nil ->
          {:cont, :ok}

        {direction, destination} ->
          {:halt,
           {:error,
            "room #{inspect(room_id)} has #{direction} exit to missing room #{inspect(destination)}"}}
      end
    end)
  end
end

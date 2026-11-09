defmodule SeedyDotDot.World do
  @moduledoc """
  Immutable world definitions loaded from the SeedyDotDot DSL.
  """

  defstruct [
    :start_room,
    rooms: %{},
    objects: %{},
    facts: %{},
    actions: %{},
    events: %{},
    event_order: []
  ]

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

  @type action :: %{
          command: String.t(),
          requirements: [String.t()],
          effects: [effect()]
        }

  @type effect ::
          %{type: :say, text: String.t()}
          | %{type: :set | :clear, fact: String.t()}
          | %{type: :bug, id: String.t()}
          | %{type: :win}

  @type event :: %{
          id: String.t(),
          trigger: {:enter, String.t()},
          once: boolean(),
          requirements: [String.t()],
          effects: [effect()]
        }

  @type t :: %__MODULE__{
          start_room: String.t(),
          rooms: %{String.t() => room()},
          objects: %{String.t() => object()},
          facts: %{String.t() => boolean()},
          actions: %{String.t() => action()},
          events: %{String.t() => event()},
          event_order: [String.t()]
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

  def validate(%__MODULE__{
        start_room: start_room,
        rooms: rooms,
        objects: objects,
        facts: facts,
        actions: actions,
        events: events
      }) do
    cond do
      not Map.has_key?(rooms, start_room) ->
        {:error, "start room #{inspect(start_room)} does not exist"}

      true ->
        with :ok <- validate_exits(rooms, facts, objects),
             :ok <- validate_objects(objects, rooms) do
          with :ok <- validate_actions(actions, facts, objects) do
            validate_events(events, rooms, facts, objects)
          end
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

      "action " <> command ->
        parse_action(command, rest, world)

      "event " <> event_id ->
        parse_event(event_id, rest, world)

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

  defp parse_fact(definition, rest, %__MODULE__{facts: facts} = world) do
    with {:ok, fact, value} <- parse_fact_definition(definition) do
      if Map.has_key?(facts, fact) do
        {:error, "fact #{inspect(fact)} is defined more than once"}
      else
        parse_lines(rest, %{world | facts: Map.put(facts, fact, value)})
      end
    end
  end

  defp parse_fact_definition(definition) do
    case String.split(definition, ~r/\s+/, parts: 2) do
      [fact] when fact != "" -> {:ok, fact, true}
      [fact, "true"] when fact != "" -> {:ok, fact, true}
      [fact, "false"] when fact != "" -> {:ok, fact, false}
      _ -> {:error, "fact requires an optional true or false initial value"}
    end
  end

  defp parse_action("", _rest, _world), do: {:error, "action requires a command"}

  defp parse_action(command, _rest, %__MODULE__{actions: actions})
       when is_map_key(actions, command),
       do: {:error, "action #{inspect(command)} is defined more than once"}

  defp parse_action(command, lines, world) do
    action = %{command: command, requirements: [], effects: []}

    with {:ok, action, rest} <- parse_action_body(lines, action) do
      parse_lines(rest, %{world | actions: Map.put(world.actions, command, action)})
    end
  end

  defp parse_action_body([], _action), do: {:error, "action is missing end"}
  defp parse_action_body(["end" | rest], action), do: {:ok, action, rest}

  defp parse_action_body([line | rest], action) do
    case String.trim(line) do
      "require " <> fact when fact != "" ->
        parse_action_body(rest, %{action | requirements: action.requirements ++ [fact]})

      "say " <> text when text != "" ->
        parse_action_body(rest, %{action | effects: action.effects ++ [%{type: :say, text: text}]})

      "set " <> fact when fact != "" ->
        parse_action_body(rest, %{action | effects: action.effects ++ [%{type: :set, fact: fact}]})

      "clear " <> fact when fact != "" ->
        parse_action_body(rest, %{
          action
          | effects: action.effects ++ [%{type: :clear, fact: fact}]
        })

      "win" ->
        parse_action_body(rest, %{action | effects: action.effects ++ [%{type: :win}]})

      "bug " <> id when id != "" ->
        parse_action_body(rest, %{action | effects: action.effects ++ [%{type: :bug, id: id}]})

      directive ->
        {:error, "unexpected action directive: #{inspect(directive)}"}
    end
  end

  defp parse_event("", _rest, _world), do: {:error, "event requires an ID"}

  defp parse_event(event_id, _rest, %__MODULE__{events: events})
       when is_map_key(events, event_id),
       do: {:error, "event #{inspect(event_id)} is defined more than once"}

  defp parse_event(event_id, lines, world) do
    event = %{id: event_id, trigger: nil, once: false, requirements: [], effects: []}

    with {:ok, event, rest} <- parse_event_body(lines, event),
         :ok <- validate_event_fields(event) do
      parse_lines(rest, %{
        world
        | events: Map.put(world.events, event_id, event),
          event_order: world.event_order ++ [event_id]
      })
    end
  end

  defp parse_event_body([], _event), do: {:error, "event is missing end"}
  defp parse_event_body(["end" | rest], event), do: {:ok, event, rest}

  defp parse_event_body([line | rest], event) do
    case String.trim(line) do
      "on enter " <> room_id when room_id != "" ->
        parse_event_body(rest, %{event | trigger: {:enter, room_id}})

      "once" ->
        parse_event_body(rest, %{event | once: true})

      "require " <> fact when fact != "" ->
        parse_event_body(rest, %{event | requirements: event.requirements ++ [fact]})

      "say " <> text when text != "" ->
        parse_event_body(rest, %{event | effects: event.effects ++ [%{type: :say, text: text}]})

      "set " <> fact when fact != "" ->
        parse_event_body(rest, %{event | effects: event.effects ++ [%{type: :set, fact: fact}]})

      "clear " <> fact when fact != "" ->
        parse_event_body(rest, %{event | effects: event.effects ++ [%{type: :clear, fact: fact}]})

      "win" ->
        parse_event_body(rest, %{event | effects: event.effects ++ [%{type: :win}]})

      directive ->
        {:error, "unexpected event directive: #{inspect(directive)}"}
    end
  end

  defp validate_event_fields(%{id: id, trigger: nil}),
    do: {:error, "event #{inspect(id)} has no trigger"}

  defp validate_event_fields(_event), do: :ok

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

  defp valid_condition?(fact, facts, _objects), do: Map.has_key?(facts, fact)

  defp validate_actions(actions, facts, objects) do
    Enum.reduce_while(actions, :ok, fn {command, action}, :ok ->
      case Enum.find(action.requirements, &(not valid_condition?(&1, facts, objects))) do
        nil ->
          case validate_action_effects(command, action.effects, facts) do
            :ok -> {:cont, :ok}
            error -> {:halt, error}
          end

        fact ->
          {:halt, {:error, "action #{inspect(command)} has unknown requirement #{inspect(fact)}"}}
      end
    end)
  end

  defp validate_action_effects(command, effects, facts) do
    case Enum.find(effects, fn
           %{type: type, fact: fact} when type in [:set, :clear] ->
             not Map.has_key?(facts, fact)

           _ ->
             false
         end) do
      nil ->
        :ok

      %{fact: fact} ->
        {:error, "action #{inspect(command)} modifies unknown stored fact #{inspect(fact)}"}
    end
  end

  defp validate_events(events, rooms, facts, objects) do
    Enum.reduce_while(events, :ok, fn {event_id, event}, :ok ->
      case event.trigger do
        {:enter, room_id} when not is_map_key(rooms, room_id) ->
          {:halt, {:error, "event #{inspect(event_id)} enters missing room #{inspect(room_id)}"}}

        {:enter, _room_id} ->
          case Enum.find(event.requirements, &(not valid_condition?(&1, facts, objects))) do
            nil ->
              case validate_action_effects(event_id, event.effects, facts) do
                :ok -> {:cont, :ok}
                error -> {:halt, error}
              end

            fact ->
              {:halt,
               {:error, "event #{inspect(event_id)} has unknown requirement #{inspect(fact)}"}}
          end
      end
    end)
  end

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

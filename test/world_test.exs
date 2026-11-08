defmodule SeedyDotDot.WorldTest do
  use ExUnit.Case, async: true

  alias SeedyDotDot.World

  test "parses a small world with prose and exits" do
    world = """
    start lobby
    fact door.open
    fact escape.open false
    room lobby
      Welcome to the lobby.
      north corridor if door.open
    end
    room corridor
      The corridor is dim.
      south lobby
    end
    object key
      name brass key
      description A small brass key.
      at lobby
      portable
    end
    action unlock corridor
      require carrying.key
      say The key turns.
      clear door.open
    end
    event corridor_greeting
      on enter corridor
      once
      say The corridor coughs politely.
    end
    """

    assert {:ok, parsed} = World.parse(world)
    assert parsed.start_room == "lobby"
    assert parsed.rooms["lobby"].description == "  Welcome to the lobby."

    assert parsed.rooms["lobby"].exits == %{
             "north" => %{destination: "corridor", condition: "door.open"}
           }

    assert parsed.facts == %{"door.open" => true, "escape.open" => false}

    assert parsed.actions["unlock corridor"] == %{
             command: "unlock corridor",
             requirements: ["carrying.key"],
             effects: [%{type: :say, text: "The key turns."}, %{type: :clear, fact: "door.open"}]
           }

    assert parsed.events["corridor_greeting"].trigger == {:enter, "corridor"}
    assert parsed.events["corridor_greeting"].once
    assert parsed.event_order == ["corridor_greeting"]

    assert parsed.objects["key"] == %{
             id: "key",
             name: "brass key",
             description: "A small brass key.",
             location: "lobby",
             portable: true
           }
  end

  test "rejects an exit to a missing room" do
    world = """
    start lobby
    room lobby
      north nowhere
    end
    """

    assert {:error, ~s(room "lobby" has north exit to missing room "nowhere")} =
             World.parse(world)
  end

  test "rejects duplicate room IDs" do
    world = """
    start lobby
    room lobby
    end
    room lobby
    end
    """

    assert {:error, ~s(room "lobby" is defined more than once)} = World.parse(world)
  end

  test "rejects an object whose starting room does not exist" do
    world = """
    start lobby
    room lobby
    end
    object ruby
      name ruby
      description A red gemstone.
      at nowhere
      portable
    end
    """

    assert {:error, ~s(object "ruby" starts in missing room "nowhere")} = World.parse(world)
  end

  test "rejects a conditional exit that references an unknown fact" do
    world = """
    start lobby
    room lobby
      north corridor if door.open
    end
    room corridor
    end
    """

    assert {:error, ~s(room "lobby" has north exit with unknown fact "door.open")} =
             World.parse(world)
  end

  @tag :demo_validation
  test "rejects an action that modifies an unknown stored fact" do
    world = """
    start lobby
    room lobby
    end
    action break something
      clear machine.active
    end
    """

    assert {:error, ~s(action "break something" modifies unknown stored fact "machine.active")} =
             World.parse(world)
  end

  test "rejects an event that enters a missing room" do
    world = """
    start lobby
    room lobby
    end
    event arrival
      on enter nowhere
    end
    """

    assert {:error, ~s(event "arrival" enters missing room "nowhere")} = World.parse(world)
  end
end

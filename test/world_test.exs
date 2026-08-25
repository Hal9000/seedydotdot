defmodule SeedyDotDot.WorldTest do
  use ExUnit.Case, async: true

  alias SeedyDotDot.World

  test "parses a small world with prose and exits" do
    world = """
    start lobby
    room lobby
      Welcome to the lobby.
      north corridor
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
    """

    assert {:ok, parsed} = World.parse(world)
    assert parsed.start_room == "lobby"
    assert parsed.rooms["lobby"].description == "  Welcome to the lobby."
    assert parsed.rooms["lobby"].exits == %{"north" => "corridor"}

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
end

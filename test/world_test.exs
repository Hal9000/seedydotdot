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
    """

    assert {:ok, parsed} = World.parse(world)
    assert parsed.start_room == "lobby"
    assert parsed.rooms["lobby"].description == "  Welcome to the lobby."
    assert parsed.rooms["lobby"].exits == %{"north" => "corridor"}
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
end

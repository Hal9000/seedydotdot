defmodule SeedyDotDot.GameTest do
  use ExUnit.Case, async: true

  alias SeedyDotDot.{Game, World}

  setup do
    {:ok, world} =
      World.parse("""
      start lobby
      room lobby
        The lobby.
        north corridor
      end
      room corridor
        The corridor.
        south lobby
      end
      """)

    %{game: Game.new(world)}
  end

  test "look describes the current room", %{game: game} do
    assert {^game, "  The lobby."} = Game.command(game, "look")
  end

  test "movement changes rooms and describes the destination", %{game: game} do
    assert {moved_game, "  The corridor."} = Game.command(game, "n")
    assert moved_game.current_room == "corridor"

    assert {returned_game, "  The lobby."} = Game.command(moved_game, "south")
    assert returned_game.current_room == "lobby"
  end

  test "blocked movement retains the current room", %{game: game} do
    assert {^game, "You can't go that way."} = Game.command(game, "east")
  end

  test "unknown commands retain the current room", %{game: game} do
    assert {^game, "I don't understand that."} = Game.command(game, "take ruby")
  end
end

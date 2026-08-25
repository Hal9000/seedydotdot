defmodule SeedyDotDot.GameTest do
  use ExUnit.Case, async: true

  alias SeedyDotDot.{Game, World}

  setup do
    {:ok, world} =
      World.parse("""
      start lobby
      fact machine.active
      room lobby
        The lobby.
        north corridor
      end
      room corridor
        The corridor.
        south lobby
        north vault if carrying.key
      end
      room vault
        The vault.
        south corridor
      end
      object key
        name brass key
        description A small brass key.
        at lobby
        portable
      end
      object statue
        name statue
        description A remarkably stationary statue.
        at lobby
        fixed
      end
      """)

    %{game: Game.new(world)}
  end

  test "look describes the current room and its objects", %{game: game} do
    assert {^game, "  The lobby.\n\nYou see here: brass key, statue."} =
             Game.command(game, "look")
  end

  test "movement changes rooms and describes the destination", %{game: game} do
    assert {moved_game, "  The corridor."} = Game.command(game, "n")
    assert moved_game.current_room == "corridor"

    assert {returned_game, "  The lobby.\n\nYou see here: brass key, statue."} =
             Game.command(moved_game, "south")

    assert returned_game.current_room == "lobby"
  end

  test "blocked movement retains the current room", %{game: game} do
    assert {^game, "You can't go that way."} = Game.command(game, "east")
  end

  test "unknown commands retain the current room", %{game: game} do
    assert {^game, "I don't understand that."} = Game.command(game, "dance")
  end

  test "taking and dropping an object updates inventory and room contents", %{game: game} do
    assert {taken_game, "Taken."} = Game.command(game, "get brass key")
    assert taken_game.object_locations["key"] == :inventory
    assert {^taken_game, "You are carrying: brass key."} = Game.command(taken_game, "i")

    assert {dropped_game, "Dropped."} = Game.command(taken_game, "drop key")
    assert dropped_game.object_locations["key"] == "lobby"

    assert {^dropped_game, "You aren't carrying anything."} =
             Game.command(dropped_game, "inventory")
  end

  test "objects can be examined while here or carried", %{game: game} do
    assert {^game, "A small brass key."} = Game.command(game, "x key")
    assert {taken_game, "Taken."} = Game.command(game, "take key")
    assert {^taken_game, "A small brass key."} = Game.command(taken_game, "look at brass key")
  end

  test "fixed and absent objects cannot be taken", %{game: game} do
    assert {^game, "You can't take the statue."} = Game.command(game, "take statue")
    assert {moved_game, "  The corridor."} = Game.command(game, "north")
    assert {^moved_game, "You don't see that here."} = Game.command(moved_game, "take key")
  end

  test "fact queries support stored and derived facts", %{game: game} do
    assert Game.true?(game, "machine.active")
    refute Game.true?(game, "machine.broken")
    refute Game.true?(game, "carrying.key")
    assert Game.true?(game, "here.key")

    assert {taken_game, "Taken."} = Game.command(game, "take key")
    assert Game.true?(taken_game, "carrying.key")
    refute Game.true?(taken_game, "here.key")
  end

  test "a conditional exit requires its fact", %{game: game} do
    assert {corridor_game, "  The corridor."} = Game.command(game, "north")
    assert {^corridor_game, "You can't go that way."} = Game.command(corridor_game, "north")

    assert {carrying_game, "Taken."} = Game.command(game, "take key")
    assert {with_key_game, "  The corridor."} = Game.command(carrying_game, "north")
    assert {vault_game, "  The vault."} = Game.command(with_key_game, "north")
    assert vault_game.current_room == "vault"
  end
end

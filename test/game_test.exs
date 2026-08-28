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
      action use key
        require carrying.key
        say The machine stops.
        clear machine.active
        say A tiny supervisor sighs.
      end
      action reset machine
        set machine.active
        say The machine starts.
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

  test "data-defined actions check requirements before ordered effects", %{game: game} do
    assert {^game, "That doesn't seem to work."} = Game.command(game, "use key")
    assert Game.true?(game, "machine.active")

    assert {carrying_game, "Taken."} = Game.command(game, "take key")

    assert {stopped_game, "The machine stops.\nA tiny supervisor sighs."} =
             Game.command(carrying_game, "use key")

    refute Game.true?(stopped_game, "machine.active")

    assert {reset_game, "The machine starts."} = Game.command(stopped_game, "reset machine")
    assert Game.true?(reset_game, "machine.active")
  end

  test "enter events fire once after their requirements are met" do
    {:ok, world} =
      World.parse("""
      start lobby
      room lobby
        north hall
      end
      room hall
        The hall.
        south lobby
      end
      object key
        name key
        description A key.
        at lobby
        portable
      end
      event hall_greeting
        on enter hall
        once
        require carrying.key
        say The hall coughs politely.
      end
      """)

    game = Game.new(world)

    assert {hall_game, "  The hall."} = Game.command(game, "north")
    refute MapSet.member?(hall_game.fired_events, "hall_greeting")

    assert {lobby_game, "\n\nYou see here: key."} = Game.command(hall_game, "south")
    assert {carrying_game, "Taken."} = Game.command(lobby_game, "take key")

    assert {greeted_game, "  The hall.\n\nThe hall coughs politely."} =
             Game.command(carrying_game, "north")

    assert MapSet.member?(greeted_game.fired_events, "hall_greeting")

    assert {returned_game, ""} = Game.command(greeted_game, "south")
    assert {again_game, "  The hall."} = Game.command(returned_game, "north")
    assert MapSet.member?(again_game.fired_events, "hall_greeting")
  end
end

defmodule SeedyDotDot.DungeonTest do
  use ExUnit.Case, async: true

  alias SeedyDotDot.{Game, World}

  test "the canonical dungeon is completable" do
    {:ok, world} = World.load(Path.expand("../priv/dungeon.txt", __DIR__))
    game = Game.new(world, choose: &List.last/1)

    assert {game, "  You are in a poorly illuminated corridor." <> _} =
             Game.command(game, "north")

    assert {game, "  Everything here is a little too polished." <> _} = Game.command(game, "east")
    assert {game, "Taken."} = Game.command(game, "take ruby")

    assert {game, "  You stand before THE SEGVAULT." <> output} = Game.command(game, "north")
    assert output =~ "A distant pager chirps."

    assert {game, "The ruby fits the socket. Somewhere, a machine sounds less dormant."} =
             Game.command(game, "use ruby on console")

    assert {game, "  Cold night air arrives" <> _} = Game.command(game, "north")

    assert {won_game,
            "You push through the fire door and escape before anyone can explain the Segvault."} =
             Game.command(game, "leave through fire door")

    assert won_game.status == :won

    assert {^won_game, "The game is over. Type restart to play again."} =
             Game.command(won_game, "look")
  end

  test "the Box of Bugs remains contained" do
    {:ok, world} = World.load(Path.expand("../priv/dungeon.txt", __DIR__))
    game = Game.new(world)

    assert {^game, "The label promises this is completely safe."} =
             Game.command(game, "open box of bugs")
  end

  test "the Closet of Runtime Exceptions remains closed" do
    {:ok, world} = World.load(Path.expand("../priv/dungeon.txt", __DIR__))
    game = Game.new(world)

    assert {^game, "The closet remains quiet."} =
             Game.command(game, "open closet of runtime exceptions")
  end

  test "the Big Red Do Not Press Button remains unpressed" do
    {:ok, world} = World.load(Path.expand("../priv/dungeon.txt", __DIR__))
    game = Game.new(world)

    assert {^game, "The button remains unpressed."} =
             Game.command(game, "press big red do not press button")
  end

  test "the Pedestal of Object Permanence releases the ruby" do
    game = game_in_ruby_room()
    assert {carrying_game, "Taken."} = Game.command(game, "take ruby")
    assert {^carrying_game, output} = Game.command(carrying_game, "look")

    refute output =~ "rests on a pedestal"
  end

  test "the Stale Console changes after the ruby is used" do
    game = game_in_ruby_room()
    assert {game, "Taken."} = Game.command(game, "take ruby")
    assert {game, "  You stand before THE SEGVAULT." <> _} = Game.command(game, "north")

    assert {game, "The ruby fits the socket. Somewhere, a machine sounds less dormant."} =
             Game.command(game, "use ruby on console")

    assert {^game, output} = Game.command(game, "look")
    assert output =~ "The console now glows with a ruby-red certainty."
  end

  defp game_in_ruby_room do
    {:ok, world} = World.load(Path.expand("../priv/dungeon.txt", __DIR__))
    game = Game.new(world, choose: &List.last/1)

    assert {game, "  You are in a poorly illuminated corridor." <> _} =
             Game.command(game, "north")

    assert {game, "  Everything here is a little too polished." <> _} = Game.command(game, "east")
    game
  end
end

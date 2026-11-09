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

  @tag :tidex_demo
  test "the Box of Bugs remains contained" do
    {:ok, world} = World.load(Path.expand("../priv/dungeon.txt", __DIR__))
    game = Game.new(world)

    assert {^game, "The label promises this is completely safe."} =
             Game.command(game, "open box of bugs")
  end
end

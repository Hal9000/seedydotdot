defmodule SeedyDotDot.TextTest do
  use ExUnit.Case, async: true

  alias SeedyDotDot.{Game, World}

  test "renders independent alternatives with an injected chooser" do
    game =
      game_with("""
      start room
      room room
        A {quiet|loud} and {old|new} room.
      end
      """)

    assert {^game, "  A loud and new room."} = Game.command(game, "look")
  end

  test "renders conditional branches from stored facts" do
    game =
      game_with("""
      start room
      fact machine.active
      room room
        {?machine.active:The machine is active.|The machine is quiet.}
      end
      action silence machine
        clear machine.active
      end
      """)

    assert {^game, "  The machine is active."} = Game.command(game, "look")
    assert {silent_game, ""} = Game.command(game, "silence machine")
    assert {^silent_game, "  The machine is quiet."} = Game.command(silent_game, "look")
  end

  test "renders dynamic action output after effects are applied" do
    game =
      game_with("""
      start room
      fact machine.active
      room room
        A room.
      end
      action silence machine
        clear machine.active
        say {?machine.active:The machine is still active.|The machine is now quiet.}
      end
      """)

    assert {_silent_game, "The machine is now quiet."} = Game.command(game, "silence machine")
  end

  defp game_with(world_text) do
    {:ok, world} = World.parse(world_text)
    Game.new(world, choose: &List.last/1)
  end
end

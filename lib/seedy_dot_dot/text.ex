defmodule SeedyDotDot.Text do
  @moduledoc """
  Renders the small dynamic-text syntax used by world data.
  """

  alias SeedyDotDot.Game

  @conditional ~r/\{\?([^:{}|]+):([^{}|]*)\|([^{}]*)\}/
  @alternatives ~r/\{([^{}?][^{}]*)\}/

  @spec render(String.t(), Game.t(), ([String.t()] -> String.t())) :: String.t()
  def render(text, game, choose) do
    text
    |> render_conditions(game)
    |> render_alternatives(choose)
  end

  defp render_conditions(text, game) do
    Regex.replace(@conditional, text, fn _match, fact, when_true, when_false ->
      if Game.true?(game, fact), do: when_true, else: when_false
    end)
  end

  defp render_alternatives(text, choose) do
    Regex.replace(@alternatives, text, fn _match, alternatives ->
      alternatives
      |> String.split("|")
      |> choose.()
    end)
  end
end

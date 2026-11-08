defmodule SeedyDotDot.Web.RouterTest do
  use ExUnit.Case, async: false

  import Plug.Conn
  import Plug.Test

  alias SeedyDotDot.{GameServer, Web.Router}

  setup do
    GameServer.restart()
    :ok
  end

  test "shows the transcript and accepts a command" do
    response = conn(:get, "/") |> Router.call([])

    assert response.status == 200
    assert response.resp_body =~ "SeedyDotDot"
    assert response.resp_body =~ "neglected lobby"

    response =
      conn(:post, "/command", "command=north")
      |> put_req_header("content-type", "application/x-www-form-urlencoded")
      |> Router.call([])

    assert response.status == 303
    assert get_resp_header(response, "location") == ["/"]

    response = conn(:get, "/") |> Router.call([])
    assert response.resp_body =~ "&gt; north"
    assert response.resp_body =~ "poorly illuminated corridor"
  end
end

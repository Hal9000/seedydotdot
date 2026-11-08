defmodule SeedyDotDot.Web.Router do
  @moduledoc false

  use Plug.Router

  alias SeedyDotDot.GameServer

  plug(Plug.Parsers, parsers: [:urlencoded])
  plug(:match)
  plug(:dispatch)

  get "/" do
    conn
    |> put_resp_content_type("text/html")
    |> send_resp(200, page(GameServer.transcript()))
  end

  post "/command" do
    command = Map.get(conn.params, "command", "")
    GameServer.command(command)

    conn
    |> put_resp_header("location", "/")
    |> send_resp(303, "")
  end

  match _ do
    send_resp(conn, 404, "Not found")
  end

  defp page(transcript) do
    """
    <!doctype html>
    <html lang="en">
      <head>
        <meta charset="utf-8">
        <title>SeedyDotDot</title>
        <style>
          body { background: #111; color: #ddd; font: 16px/1.4 monospace; margin: 2rem auto; max-width: 52rem; }
          h1 { color: #e87538; }
          article { border-left: 2px solid #555; margin: 1rem 0; padding-left: 1rem; }
          .command { color: #7cc576; }
          pre { font: inherit; margin: .25rem 0; white-space: pre-wrap; }
          form { display: flex; gap: .5rem; margin-top: 2rem; }
          input { background: #222; border: 1px solid #777; color: #fff; flex: 1; font: inherit; padding: .5rem; }
          button { background: #e87538; border: 0; color: #111; font: inherit; padding: .5rem 1rem; }
        </style>
      </head>
      <body>
        <h1>SeedyDotDot</h1>
        <main>#{render_transcript(transcript)}</main>
        <form method="post" action="/command">
          <input autofocus name="command" aria-label="Command" autocomplete="off">
          <button type="submit">Send</button>
        </form>
      </body>
    </html>
    """
  end

  defp render_transcript(entries) do
    entries
    |> Enum.map(fn %{command: command, output: output} ->
      """
      <article>
        <pre class="command">&gt; #{escape(command)}</pre>
        <pre>#{escape(output)}</pre>
      </article>
      """
    end)
    |> Enum.join("\n")
  end

  defp escape(text), do: text |> Plug.HTML.html_escape() |> IO.iodata_to_binary()
end

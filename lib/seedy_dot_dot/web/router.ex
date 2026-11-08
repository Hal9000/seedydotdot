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
    entry = GameServer.command(command) |> List.last()

    if accepts_plain_text?(conn) do
      conn
      |> put_resp_content_type("text/plain")
      |> send_resp(200, entry.output)
    else
      conn
      |> put_resp_header("location", "/")
      |> send_resp(303, "")
    end
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
          body { background: #111; color: #d8d5ca; font: 16px/1.4 ui-monospace, SFMono-Regular, Menlo, Consolas, monospace; margin: 2rem auto; max-width: 52rem; }
          h1 { color: #e87538; font-size: 1.25rem; font-weight: 500; }
          .terminal { background: #171717; border: 1px solid #4c4b46; border-radius: .5rem; box-shadow: 0 .75rem 2.5rem #0008; display: flex; flex-direction: column; height: 32rem; padding: 1rem; }
          main { flex: 1; min-height: 0; overflow-y: auto; padding-right: .5rem; scroll-behavior: smooth; }
          article { margin: 0 0 1rem; }
          .command, .prompt { color: #82bd88; }
          pre { font: inherit; margin: .25rem 0; white-space: pre-wrap; }
          form { align-items: center; display: flex; gap: .65rem; margin-top: 1rem; }
          input { background: transparent; border: 0; color: #d8d5ca; flex: 1; font: inherit; min-width: 0; outline: 0; padding: .25rem 0; }
          input:disabled { color: #838178; }
          .sr-only { height: 1px; margin: -1px; overflow: hidden; position: absolute; width: 1px; clip: rect(0, 0, 0, 0); }
        </style>
      </head>
      <body>
        <h1>SeedyDotDot</h1>
        <section class="terminal">
          <main id="transcript" aria-live="polite">#{render_transcript(transcript)}</main>
          <form id="command-form" method="post" action="/command">
            <label class="sr-only" for="command">Command</label>
            <span class="prompt" aria-hidden="true">&gt;</span>
            <input autofocus id="command" name="command" autocomplete="off">
          </form>
        </section>
        <script>
          (() => {
            const form = document.getElementById("command-form");
            const input = document.getElementById("command");
            const transcript = document.getElementById("transcript");
            const charsPerSecond = 50;

            const scrollToBottom = () => { transcript.scrollTop = transcript.scrollHeight; };

            const appendEntry = (command, output) => {
              const entry = document.createElement("article");
              const commandLine = document.createElement("pre");
              const outputLine = document.createElement("pre");

              commandLine.className = "command";
              commandLine.textContent = `> ${command}`;
              entry.append(commandLine, outputLine);
              transcript.append(entry);
              scrollToBottom();

              if (!output || window.matchMedia("(prefers-reduced-motion: reduce)").matches) {
                outputLine.textContent = output;
                scrollToBottom();
                return Promise.resolve();
              }

              return new Promise((resolve) => {
                let index = 0;
                const interval = window.setInterval(() => {
                  outputLine.textContent += output.charAt(index);
                  index += 1;
                  scrollToBottom();

                  if (index === output.length) {
                    window.clearInterval(interval);
                    resolve();
                  }
                }, 1000 / charsPerSecond);
              });
            };

            form.addEventListener("submit", async (event) => {
              event.preventDefault();
              const command = input.value;
              if (!command) return;

              input.value = "";
              input.disabled = true;

              try {
                const response = await fetch(form.action, {
                  method: "POST",
                  headers: {
                    "Accept": "text/plain",
                    "Content-Type": "application/x-www-form-urlencoded"
                  },
                  body: new URLSearchParams({ command })
                });

                const output = response.ok ? await response.text() : "The terminal stops responding.";
                await appendEntry(command, output);
              } catch (_) {
                await appendEntry(command, "The terminal stops responding.");
              } finally {
                input.disabled = false;
                input.focus();
              }
            });

            scrollToBottom();
          })();
        </script>
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

  defp accepts_plain_text?(conn) do
    conn
    |> get_req_header("accept")
    |> Enum.any?(&String.contains?(&1, "text/plain"))
  end

  defp escape(text), do: text |> Plug.HTML.html_escape() |> IO.iodata_to_binary()
end

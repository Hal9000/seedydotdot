# SeedyDotDot

A small, data-driven Elixir text adventure. It requires Elixir 1.18 or later.

## Run the CLI

With Elixir installed, start the terminal game from the repository root:

```sh
mix run -e 'SeedyDotDot.CLI.start()'
```

Use `look`, `north`/`n`, `south`/`s`, `east`/`e`, and `west`/`w`.
Use `quit`, `exit`, or `q` to leave the CLI.

Run the test suite with:

```sh
mix test
```

## Run the web demo

Start the single-user web demo:

```sh
mix seedy_dot_dot.web
```

Open `http://localhost:4000`. The page shows the transcript and provides one
command field. Enter `restart` to begin again after winning.
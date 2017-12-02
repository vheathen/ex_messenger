use Mix.Config

# Configure mix test.watch
config :mix_test_watch,
  tasks: [
    "test",
    "credo",
  ]
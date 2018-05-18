use Mix.Config

# Do not start Manager on tests, we need it here because of the mix_test_watch
config :ex_messenger, :children, []

# Configure mix test.watch
config :mix_test_watch,
  tasks: [
    "test",
    "credo",
  ]
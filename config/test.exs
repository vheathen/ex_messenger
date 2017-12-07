use Mix.Config

# We need to test requests without real external service usage
config :tesla, adapter: :mock

# Logger: we don't need debug
config :logger, level: :info
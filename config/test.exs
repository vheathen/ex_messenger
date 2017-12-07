use Mix.Config

config :ex_smsbliss, ecto_repos: [ExSmsBliss.Storage.Postgresql.Repo]

# Configures Ecto to use UTC datetime as timestamps
config :ex_smsbliss, ExSmsBliss.Storage.Postgresql.Repo,
    migration_timestamps: [type: :utc_datetime]

config :ex_smsbliss, :adapter, 
  repo: ExSmsBliss.Storage.Postgresql.Repo

# Configure your database
config :ex_smsbliss, ExSmsBliss.Storage.Postgresql.Repo,
  adapter: Ecto.Adapters.Postgres,
  username: "postgres",
#  password: "postgres",
  database: "ex_smsbliss_test",
  hostname: "localhost",
  pool_size: 10,
  # Ensure async testing is possible:
  pool: Ecto.Adapters.SQL.Sandbox

# We need to test requests without real external service usage
config :tesla, adapter: :mock

# Logger: we don't need debug
config :logger, level: :info
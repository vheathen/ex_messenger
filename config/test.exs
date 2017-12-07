use Mix.Config

config :ex_smsbliss, ecto_repos: [ExSmsBliss.Storage.Postgrsql.Repo]

# Configures generators to use uuid as id
config :ex_smsbliss, :generators,
    binary_id: true

# Configures Ecto to use UTC datetime as timestamps
config :ex_smsbliss, ExSmsBliss.Storage.Postgrsql.Repo,
    migration_timestamps: [type: :utc_datetime]

config :ex_smsbliss, repo: ExSmsBliss.Storage.Postgrsql.Repo

# Configure your database
config :ex_smsbliss, ExSmsBliss.Storage.Postgrsql.Repo,
  adapter: Ecto.Adapters.Postgres,
  username: "postgres",
#  password: "postgres",
  database: "ex_smsbliss_test",
  hostname: "localhost",
  pool_size: 10

# We need to test requests without real external service usage
config :tesla, adapter: :mock
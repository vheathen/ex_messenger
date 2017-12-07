
Faker.start
ExUnit.start()

{:ok, _pid} = ExSmsBliss.Storage.Postgresql.Repo.start_link()
Ecto.Adapters.SQL.Sandbox.mode(ExSmsBliss.Storage.Postgresql.Repo, :manual)

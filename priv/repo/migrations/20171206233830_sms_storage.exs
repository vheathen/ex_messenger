defmodule ExSmsBliss.Storage.Postgrsql.Repo.Migrations.SmsStorage do
  use Ecto.Migration

  def up do
    execute ~S(CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA public;)

    create table(:ex_smsbliss_messages, primary_key: false) do
      add :id, :binary_id, primary_key: true, default: fragment("uuid_generate_v1mc()")  # yes, it's v1mc() to have better index
      add :phone, :text
      add :text, :text
      add :sender, :text
      add :schedule_at, :utc_datetime
      add :status, :text, null: false, default: "queued"
      add :smsc_id, :text
      
      timestamps()
    end

    create unique_index(:ex_smsbliss_messages, [:smsc_id])
    create index(:ex_smsbliss_messages, [:status])
  end

  def down do
    
  end
end

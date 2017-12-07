defmodule ExSmsBliss.Storage.Message do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  alias ExSmsBliss.Storage.Message

  @primary_key {:id, :binary_id, read_after_writes: true}
  @foreign_key_type :binary_id
  @timestamps_opts [type: :utc_datetime, usec: true]

  schema "ex_smsbliss_messages" do
    field :phone, :string
    field :text, :string
    field :sender, :string
    field :schedule_at, :utc_datetime
    field :status, :string
    field :smsc_id, :string
    
    timestamps()
  end

  def changeset(%Message{} = message, attrs \\ %{}) do
    message
    |> cast(attrs, [:phone, :text, :sender, :schedule_at, :status, :smsc_id])
    |> validate_required([:phone, :text])
    |> unique_constraint(:smsc_id)
  end
end
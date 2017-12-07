defmodule ExSmsBlissTest.Manager do
  @moduledoc false
  # use GenStage

  import Ecto.Query
  alias ExSmsBliss.Config
  alias ExSmsBliss.Storage.Message

  @statuses [:queued, :working, :accepted]

  @doc """
  Returns queue: a message list # TODO: with a given status and higher
  """
  def get_queue do
    Message
    |> order_by([asc: :updated_at])
    |> get_repo().all()
  end

  def queue(%{} = message) do
    %Message{} 
    |> Message.changeset(message) 
    |> get_repo().insert(returning: [:status])
  end

  # TODO: Make it possible to queue message lists
  # def queue(messages) when is_list(messages) do    
  #   # messages
  #   # |>  Enum.with_index
  #   # |>  Enum.reduce(Ecto.Multi.new, fn {message, i}, multi ->
  #   #       Ecto.Multi.insert(multi, i, Message.changeset(%Message{}, message), returning: [:status])
  #   #     end)
  #   # |> get_repo().transaction()
  # end

  defp get_repo do
    :ex_smsbliss
    |> Config.get(:adapter)
    |> Keyword.get(:repo)
  end
end
defmodule ExSmsBliss.ApiTestHelper do

  @option_keys [:amount, :sender, :client_id, :schedule_at]
  
  def gen_message(opts \\ %{}) do
    message = %{
                  phone: Faker.Phone.EnGb.landline_number |> String.replace("+44", "79"),
                  text: Faker.Lorem.Shakespeare.Ru.hamlet
                }

    @option_keys
    |> Enum.reduce(message, &(put_field(&2, &1, Map.get(opts, &1))))
  end

  def gen_messages(context) do
    amount = Map.get(context, :amount, 10)

    1..amount
    |> Enum.map(fn _ -> gen_message(context) end)
  end

  def gen_message_status(opts \\ %{}) do
    main = %{smsc_id: :rand.uniform(9999999) + 10000000}

    client_id = if Map.get(opts, :client_id), do: Faker.Code.iban, else: nil
    main = if client_id, do: Map.put(main, :client_id, client_id), else: main

    main
  end

  def gen_message_statuses(context) do
    amount = Map.get(context, :amount, 10)
    
    1..amount
    |> Enum.map(fn _ -> gen_message_status(context) end)    
  end

  def schedule_in(ms) do
    DateTime.utc_now 
    |> DateTime.to_unix(:milliseconds) 
    |> Kernel.+(ms) 
    |> DateTime.from_unix!(:milliseconds)
  end

  defp put_field(map, key = :sender, value) do
    case value do
      nil -> map
      true -> Map.put(map, key, Faker.Company.suffix)
      value -> Map.put(map, key, value)
    end
  end

  defp put_field(map, key = :client_id, value) do
    case value do
      nil -> map
      _ -> Map.put(map, key, Ecto.UUID.generate())
    end
  end

  defp put_field(map, key = :schedule_at, value) do
    case value do
      nil -> map
      true -> Map.put(map, key, schedule_in(100))
      _ -> Map.put(map, key, value)
    end
  end

  defp put_field(map, _, _), do: map
  
end
defmodule ExSmsBliss.MessagesTestHelper do
  
  def message(opts \\ []) do
    main = %{
              phone: Faker.Phone.EnGb.landline_number |> String.replace("+44", "79"),
              text: Faker.Lorem.Shakespeare.Ru.hamlet              
            }
    
    sender = 
      case Keyword.get(opts, :sender) do
        true -> Faker.Company.suffix
        val -> val
      end
    
    main = if sender, do: Map.put(main, :sender, sender), else: main

    client_id = if Keyword.get(opts, :client_id), do: Faker.String.base64, else: nil

    main = if client_id, do: Map.put(main, "clientId", client_id), else: main

    main
  end

  def messages(num, opts \\ []) do
    1..num
    |> Enum.map(fn _ -> message(opts) end)
  end

end
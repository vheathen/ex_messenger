defmodule ExMessenger.Mixfile do
  use Mix.Project

  def project do
    [
      app: :ex_messenger,
      version: "0.1.0",
      elixir: "~> 1.5",
      elixirc_paths: elixirc_paths(Mix.env),
      start_permanent: Mix.env == :prod,
      deps: deps(),
      aliases: aliases(),

      name: "ExMessenger",
      source_url: "https://github.com/vheathen/ex_messenger",
      description: "SmsBliss (https://smsbliss.ru/) unofficial API client",
      package: [
             name: :ex_messenger,
             files: ["lib", "mix.exs", "README*", "LICENSE*"],
             maintainers: ["Vladimir Drobyshevskiy"],
             licenses: ["MIT"],
             links: %{ "GitHub" => "https://github.com/vheathen/ex_messenger" },
           ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {ExMessenger.Application, []}
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:prod), do: ["lib"]
  defp elixirc_paths(_),     do: ["lib", "test/support"]
  
  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [

      {:tesla, "~> 0.10.0"}, # , github: "teamon/tesla"},
      {:poison, ">= 1.0.0"},

      {:uuid, "~> 1.1"},

      {:ex2ms, "~> 1.0"},

      {:faker, "~> 0.9", only: [:test, :dev]},
      {:credo, "~> 0.8", only: [:dev, :test], runtime: false},
      {:mix_test_watch, "~> 0.6", only: :dev, runtime: false},
    ]
  end

  defp aliases do
    [
      test: "test --no-start"
    ]
  end
end

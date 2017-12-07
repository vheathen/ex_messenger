defmodule ExSmsBliss.Mixfile do
  use Mix.Project

  def project do
    [
      app: :ex_smsbliss,
      version: "0.1.0",
      elixir: "~> 1.5",
      elixirc_paths: elixirc_paths(Mix.env),
      start_permanent: Mix.env == :prod,
      deps: deps(),
      aliases: aliases(),

      name: "ExSmsBliss",
      source_url: "https://github.com/vheathen/ex_smsbliss",
      description: "SmsBliss (https://smsbliss.ru/) unofficial API client",
      package: [
             name: :ex_smsbliss,
             files: ["lib", "mix.exs", "README*", "LICENSE*"],
             maintainers: ["Vladimir Drobyshevskiy"],
             licenses: ["MIT"],
             links: %{ "GitHub" => "https://github.com/vheathen/ex_smsbliss" },
           ]

    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger, :ecto, :postgrex],
      mod: {ExSmsBliss.Application, []}
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_),     do: ["lib"]

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"},

      {:gen_stage, "~> 0.12"},
      {:ecto, "~> 2.2"},
      {:postgrex, ">= 0.0.0"},

      {:tesla, "~> 0.9.0"},
      {:poison, ">= 1.0.0"},

      {:faker, "~> 0.9", only: [:test, :dev]},
      {:credo, "~> 0.8", only: [:dev, :test], runtime: false},
      {:mix_test_watch, path: "/home/vlad/ProjectsLocal/mix-test.watch", only: :dev, runtime: false}, #"~> 0.5", only: :dev, runtime: false},
    ]
  end

  defp aliases do
    [
      # Ensures database is reset before tests are run
      "test": ["ecto.create --quiet", "ecto.migrate", "test"]
    ]
  end
end

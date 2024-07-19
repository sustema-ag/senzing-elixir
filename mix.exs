defmodule Senzing.MixProject do
  use Mix.Project

  @version "0.0.0-dev"

  def project do
    [
      app: :senzing,
      version: @version,
      elixir: "~> 1.17",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      docs: &docs/0,
      source_url: "https://github.com/sustema-ag/senzing-elixir",
      description: "Elixir NIF for Senzing Entity Matching",
      package: package(),
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test,
        "coveralls.github": :test,
        "coveralls.multiple": :test
      ]
    ]
  end

  defp elixirc_paths(env)
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_env), do: ["lib"]

  def application do
    [
      extra_applications: [:logger],
      mod: application_mod(Mix.env())
    ]
  end

  defp application_mod(env)
  defp application_mod(:test), do: {Senzing.Application, []}
  defp application_mod(_env), do: {Senzing.Application, mod: Senzing.G2.Engine}

  defp package do
    [
      maintainers: ["Jonatan Männchen"],
      files: [
        "lib/**/*.ex",
        "LICENSE*",
        "mix.exs",
        "README*"
      ],
      licenses: ["MIT"],
      links: %{"Github" => "https://github.com/sustema-ag/senzing-elixir"}
    ]
  end

  defp docs do
    [
      source_ref: "v#{@version}",
      main: "Senzing",
      logo: "assets/logo-short.svg",
      assets: %{"assets" => "assets"},
      groups_for_docs: [
        # Config
        "Functions: Configuration Object Management": &(&1[:type] == :configuration_object_management),
        "Functions: Datasource Management": &(&1[:type] == :datasource_management),
        # Engine
        "Functions: Initialization": &(&1[:type] == :initialization),
        "Functions: Add Records": &(&1[:type] == :add_records),
        "Functions: Replace Records": &(&1[:type] == :replace_records),
        "Functions: Reevaluating": &(&1[:type] == :reevaluating),
        "Functions: Redo Processing": &(&1[:type] == :redo_processing),
        "Functions: Deleting Records": &(&1[:type] == :deleting_records),
        "Functions: Getting Entities and Records": &(&1[:type] == :getting_entities_and_records),
        "Functions: Searching for Entities": &(&1[:type] == :searching_for_entities),
        "Functions: Finding Paths": &(&1[:type] == :finding_paths),
        "Functions: Finding Networks": &(&1[:type] == :finding_networks),
        "Functions: Why": &(&1[:type] == :why),
        "Functions: How": &(&1[:type] == :how),
        "Functions: Reporting": &(&1[:type] == :reporting),
        "Functions: Cleanup": &(&1[:type] == :cleanup),
        "Functions: Statistics": &(&1[:type] == :statistics)
      ]
    ]
  end

  defp deps do
    [
      {:credo, "~> 1.7", only: :dev, runtime: false},
      {:dialyxir, "~> 1.4", only: :dev, runtime: false},
      {:doctest_formatter, "~> 0.3.0", only: :dev, runtime: false},
      {:excoveralls, "~> 0.18", only: :test},
      {:ex_doc, "~> 0.34.0", only: :dev, runtime: false},
      {:gen_stage, "~> 1.2", optional: true},
      {:makeup_json, "~> 0.1", only: :dev, runtime: false},
      {:styler, "~> 0.11.9", runtime: false, only: :dev},
      {:zigler, "~> 0.11.1"}
    ]
  end
end

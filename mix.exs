defmodule Woody.MixProject do
  use Mix.Project

  def project do
    [
      app: :woody_ex,
      version: "0.1.0",
      elixir: "~> 1.13",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      dialyzer: [
        plt_add_apps: [:mix]
      ]
    ]
    |> Keyword.merge(overrides(Mix.env()))
  end

  defp overrides(:test) do
    [
      elixirc_paths: ["lib", "test"],
      thrift: [
        files: ["test/test.thrift"],
        output_path: "test/generated"
      ],
      woody: [
        output_path: "test/generated"
      ]
    ]
  end

  defp overrides(_) do
    []
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:woody, git: "https://github.com/valitydev/woody_erlang.git", branch: "ft/codec-concept"},
      # {:woody, path: "deps/woody"},
      {:thrift, git: "https://github.com/pinterest/elixir-thrift", branch: "master"},
      {:dialyxir, "~> 1.2", only: [:dev], runtime: false},
      {:credo, "~> 1.6", only: [:dev, :test], runtime: false}
    ]
  end
end

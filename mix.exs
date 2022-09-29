defmodule Woody.MixProject do
  use Mix.Project

  def project do
    [
      app: :woody_ex,
      version: "0.1.0",
      elixir: "~> 1.13",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
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
      {:woody, git: "https://github.com/valitydev/woody_erlang.git", branch: "master"},
      {:rec_struct, "~> 0.3.0", only: :test}
    ]
  end
end

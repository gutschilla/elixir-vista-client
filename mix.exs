defmodule VistaClient.MixProject do
  use Mix.Project

  def project do
    [
      app: :vista_client,
      version: "0.1.2",
      elixir: "~> 1.8",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package(),
      description: description(),
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [
        :logger,
        :inets,
        :hackney,
      ]
    ]
  end

  def description do
    """
    A client to read cinema program data from VistaConnect.
    """
  end

  defp package do
    [
      files: ["lib", "mix.exs", "README.md", "LICENSE", "test"],
      maintainers: ["Martin Dobberstein (Gutsch)"],
      licenses: ["MIT"],
      links: %{
        "GitHub" => "https://github.com/gutschilla/elixir-vista-client"
      }
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:jason, "~> 1.1.2"},
      {:hackney, "~> 1.15"},
      {:tesla, "~> 1.2.1"},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false}
    ]
  end
end

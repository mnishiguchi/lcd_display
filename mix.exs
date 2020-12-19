defmodule LcdDisplay.MixProject do
  use Mix.Project

  @version "0.0.4"
  @source_url "https://github.com/mnishiguchi/lcd_display"

  def project do
    [
      app: :lcd_display,
      version: @version,
      elixir: "~> 1.11",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      name: "LcdDisplay",
      description: "Control an Liquid-crystal display (LCD) like Hitachi HD44780",
      deps: deps(),
      docs: docs(),
      package: package()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    []
  end

  # ensure test/support is compiled
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:circuits_gpio, "~> 0.4"},
      {:circuits_i2c, "~> 0.1"},
      {:mox, "~> 1.0.0", only: :test},
      {:mix_test_watch, "~> 1.0", only: :dev, runtime: false},
      {:ex_doc, "~> 0.14", only: :dev, runtime: false}
    ]
  end

  defp docs do
    [
      main: "LcdDisplay",
      source_ref: "v#{@version}",
      source_url: @source_url
    ]
  end

  defp package do
    %{
      licenses: ["MIT"],
      maintainers: ["Masatoshi Nishiguchi"],
      links: %{"GitHub" => @source_url}
    }
  end
end

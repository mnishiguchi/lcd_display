defmodule LcdDisplay.MixProject do
  @moduledoc false

  use Mix.Project

  @version "0.2.0"
  @source_url "https://github.com/mnishiguchi/lcd_display"

  def project do
    [
      app: :lcd_display,
      version: @version,
      elixir: "~> 1.11",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      build_embedded: Mix.env() == :prod,
      description: "Use character liquid crystal display (LCD) in Elixir",
      deps: deps(),
      docs: docs(),
      package: package()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # ensure test/support is compiled
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:circuits_gpio, "~> 2.0 or ~> 1.0"},
      {:circuits_i2c, "~> 2.0 or ~> 1.0"},
      {:circuits_spi, "~> 2.0 or ~> 1.0"},
      {:mox, "~> 1.0.0", only: :test},
      {:mix_test_watch, "~> 1.0", only: :dev, runtime: false},
      {:ex_doc, "~> 0.14", only: :dev, runtime: false},
      {:credo, "~> 1.4", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.0", only: [:dev, :test], runtime: false}
    ]
  end

  defp docs do
    [
      extras: ["README.md"],
      main: "readme",
      source_ref: "v#{@version}",
      source_url: @source_url
    ]
  end

  defp package do
    %{
      files: [
        "lib",
        "mix.exs",
        "README.md",
        "LICENSE*"
      ],
      licenses: ["MIT"],
      links: %{
        "GitHub" => @source_url,
        "HD44780 data sheet" => "https://cdn-shop.adafruit.com/datasheets/HD44780.pdf",
        "PCF8574 data sheet" => "https://www.nxp.com/docs/en/data-sheet/PCF8574_PCF8574A.pdf",
        "MCP23008 data sheet" =>
          "https://ww1.microchip.com/downloads/en/DeviceDoc/MCP23008-MCP23S08-Data-Sheet-20001919F.pdf",
        "MCP23017 data sheet" => "https://ww1.microchip.com/downloads/en/devicedoc/20001952c.pdf",
        "SN74HC595 data sheet" => "https://www.ti.com/lit/ds/scls041i/scls041i.pdf"
      }
    }
  end
end

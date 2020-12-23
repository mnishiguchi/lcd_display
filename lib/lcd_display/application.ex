defmodule LcdDisplay.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: LcdDisplay.Supervisor]

    children = [
      {LcdDisplay.ProcessRegistry, nil},
      {LcdDisplay.DisplaySupervisor, nil}
    ]

    {:ok, _pid} = Supervisor.start_link(children, opts)
  end

  def target() do
    Application.get_env(:lcd_display, :target)
  end
end

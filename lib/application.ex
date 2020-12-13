defmodule LcdDisplay.Application do
  @moduledoc false

  use Application

  require Logger

  def start(_type, _args) do
    Logger.debug("#{__MODULE__} starting")

    children = []
    opts = [strategy: :one_for_one, name: LcdDisplay.Supervisor]
    Supervisor.start_link(children, opts)
  end

  def stop(_state) do
    Logger.debug("#{__MODULE__} stopping")
  end
end

defmodule LcdDisplay.TouchDriver do
  @moduledoc false

  defmacro __using__(opts) do
    driver_impl = Keyword.fetch!(opts, :driver_impl)

    quote do
      alias LcdDisplay.TouchDriver.GenericServer

      def start_link(opts \\ []) do
        GenericServer.start_link(Keyword.put(opts, :driver_impl, unquote(driver_impl)))
      end
    end
  end
end

defmodule LcdDisplay.TouchDriver.TouchContract do
  @moduledoc false

  @callback init(opts :: keyword()) :: {:ok, state :: term()} | {:stop, reason :: term()}

  @callback handle_info(message :: term(), state :: term()) ::
              {:noreply, state :: term()} | {:stop, reason :: term(), state :: term()}

  @optional_callbacks handle_info: 2
end

defmodule LcdDisplay.TouchDriver.GenericServer do
  @moduledoc false

  use GenServer
  require Logger

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: opts[:name])
  end

  @impl GenServer
  def init(opts) do
    driver_impl = Keyword.fetch!(opts, :driver_impl)
    impl_opts = Keyword.drop(opts, [:driver_impl, :name])

    try do
      case driver_impl.init(impl_opts) do
        {:ok, impl_state} ->
          Logger.info("[TouchDriver] #{inspect(driver_impl)} initialized successfully")

          {:ok, %{driver_impl: driver_impl, impl_state: impl_state}}

        {:stop, reason} ->
          Logger.error(fn ->
            """
            [TouchDriver] #{inspect(driver_impl)} failed to initialize
              reason: #{inspect(reason)}
              opts: #{inspect(impl_opts, pretty: true, limit: :infinity)}
            """
          end)

          {:stop, reason}
      end
    rescue
      exception ->
        Logger.error(fn ->
          """
          [TouchDriver] #{inspect(driver_impl)} failed to initialize
            exception: #{inspect(exception)}
            opts: #{inspect(impl_opts, pretty: true, limit: :infinity)}
          """
        end)

        {:stop, exception}
    end
  end

  @impl GenServer
  def handle_info(msg, %{driver_impl: impl, impl_state: impl_state} = state) do
    if function_exported?(impl, :handle_info, 2) do
      case impl.handle_info(msg, impl_state) do
        {:noreply, new_state} ->
          {:noreply, %{state | impl_state: new_state}}

        {:stop, reason, new_state} ->
          {:stop, reason, %{state | impl_state: new_state}}
      end
    else
      {:noreply, state}
    end
  end
end

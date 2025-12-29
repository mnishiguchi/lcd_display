defmodule LcdDisplay.DisplayDriver do
  @moduledoc """
  Shared display driver helpers used by graphic LCD panel modules.
  """

  defmacro __using__(opts) do
    driver_impl = Keyword.fetch!(opts, :driver_impl)

    quote do
      alias LcdDisplay.DisplayDriver.GenericServer

      def start_link(opts \\ []) do
        GenericServer.start_link(Keyword.put(opts, :driver_impl, unquote(driver_impl)))
      end

      defdelegate reset(pid), to: GenericServer
      defdelegate size(pid), to: GenericServer
      defdelegate pixel_format(pid), to: GenericServer
      defdelegate set_pixel_format(pid, fmt), to: GenericServer
      defdelegate set_power(pid, status), to: GenericServer
      defdelegate set_mode(pid, mode), to: GenericServer
      defdelegate set_frame_rate(pid, fps), to: GenericServer
      defdelegate write_frame_565(pid, img), to: GenericServer
      defdelegate write_frame_666(pid, img), to: GenericServer
      defdelegate write_frame(pid, img, src), to: GenericServer
      defdelegate write_command(pid, cmd, opts), to: GenericServer
      defdelegate write_data(pid, data), to: GenericServer
      defdelegate transfer(pid, bytes, is_data), to: GenericServer
    end
  end
end

defmodule LcdDisplay.DisplayDriver.DisplayContract do
  @moduledoc false

  @callback init(Keyword.t()) :: {:ok, term()} | {:stop, term()}
  @callback terminate(reason :: term(), struct()) :: any()

  @callback reset(struct()) :: struct()
  @callback size(struct()) :: %{width: non_neg_integer(), height: non_neg_integer()}
  @callback pixel_format(struct()) :: atom()
  @callback set_pixel_format(struct(), atom()) :: struct()
  @callback set_power(struct(), :on | :off) :: struct()
  @callback set_mode(struct(), atom()) :: struct()
  @callback set_frame_rate(struct(), non_neg_integer()) :: struct()
  @callback write_frame_565(struct(), iodata()) :: struct()
  @callback write_frame_666(struct(), iodata()) :: struct()
  @callback write_frame(struct(), binary() | list(), atom()) :: struct()
  @callback write_command(struct(), integer(), keyword()) :: struct()
  @callback write_data(struct(), iodata() | integer()) :: struct()
  @callback transfer(struct(), iodata() | integer() | binary(), boolean()) :: struct()
end

defmodule LcdDisplay.DisplayDriver.GenericServer do
  @moduledoc """
  Internal server module used by `LcdDisplay.DisplayDriver`.
  """

  use GenServer
  require Logger

  def start_link(opts) do
    driver_impl = Keyword.fetch!(opts, :driver_impl)
    name = Keyword.get(opts, :name)

    GenServer.start_link(__MODULE__, {driver_impl, opts}, name: name)
  end

  @impl true
  def init({driver_impl, opts}) do
    Process.flag(:trap_exit, true)

    impl_opts = Keyword.delete(opts, :driver_impl)

    try do
      case driver_impl.init(impl_opts) do
        {:ok, display_state} ->
          Logger.info("[DisplayDriver] #{inspect(driver_impl)} initialized successfully")

          {:ok, %{driver_impl: driver_impl, display_state: display_state}}

        {:stop, reason} ->
          Logger.error(fn ->
            """
            [DisplayDriver] #{inspect(driver_impl)} failed to initialize
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
          [DisplayDriver] #{inspect(driver_impl)} failed to initialize
            exception: #{inspect(exception)}
            opts: #{inspect(impl_opts, pretty: true, limit: :infinity)}
          """
        end)

        {:stop, exception}
    end
  end

  @impl true
  def terminate(reason, %{driver_impl: driver_impl, display_state: display_state}) do
    driver_impl.terminate(reason, display_state)
  end

  ## Public API

  def reset(pid), do: GenServer.call(pid, :reset)
  def size(pid), do: GenServer.call(pid, :size)
  def pixel_format(pid), do: GenServer.call(pid, :pixel_format)
  def set_pixel_format(pid, value), do: GenServer.call(pid, {:set_pixel_format, value})
  def set_power(pid, status), do: GenServer.call(pid, {:set_power, status})
  def set_mode(pid, mode), do: GenServer.call(pid, {:set_mode, mode})
  def set_frame_rate(pid, frame_rate), do: GenServer.call(pid, {:set_frame_rate, frame_rate})
  def write_frame_565(pid, data), do: GenServer.call(pid, {:write_frame_565, data})
  def write_frame_666(pid, data), do: GenServer.call(pid, {:write_frame_666, data})
  def write_frame(pid, data, color), do: GenServer.call(pid, {:write_frame, data, color})
  def write_command(pid, cmd, opts \\ []), do: GenServer.call(pid, {:write_command, cmd, opts})
  def write_data(_pid, []), do: :ok
  def write_data(pid, data), do: GenServer.call(pid, {:write_data, data})

  def transfer(pid, bytes, is_data)
      when (is_integer(bytes) or is_list(bytes) or is_binary(bytes)) and is_boolean(is_data) do
    GenServer.call(pid, {:transfer, bytes, is_data})
  end

  ## GenServer callbacks delegating to the driver_impl

  @impl true
  def handle_call(:reset, _from, state) do
    %{driver_impl: driver_impl, display_state: display_state} = state
    new_display = driver_impl.reset(display_state)

    {:reply, :ok, %{state | display_state: new_display}}
  end

  @impl true
  def handle_call(:size, _from, state) do
    %{driver_impl: driver_impl, display_state: display_state} = state
    new_display = driver_impl.size(display_state)

    {:reply, new_display, state}
  end

  @impl true
  def handle_call(:pixel_format, _from, state) do
    %{driver_impl: driver_impl, display_state: display_state} = state
    new_display = driver_impl.pixel_format(display_state)

    {:reply, new_display, state}
  end

  @impl true
  def handle_call({:set_pixel_format, pixel_format}, _from, state) do
    %{driver_impl: driver_impl, display_state: display_state} = state
    new_display = driver_impl.set_pixel_format(display_state, pixel_format)

    {:reply, :ok, %{state | display_state: new_display}}
  end

  @impl true
  def handle_call({:set_power, status}, _from, state) do
    %{driver_impl: driver_impl, display_state: display_state} = state
    new_display = driver_impl.set_power(display_state, status)

    {:reply, :ok, %{state | display_state: new_display}}
  end

  @impl true
  def handle_call({:set_mode, mode}, _from, state) do
    %{driver_impl: driver_impl, display_state: display_state} = state
    new_display = driver_impl.set_mode(display_state, mode)

    {:reply, :ok, %{state | display_state: new_display}}
  end

  @impl true
  def handle_call({:set_frame_rate, frame_rate}, _from, state) do
    %{driver_impl: driver_impl, display_state: display_state} = state
    new_display = driver_impl.set_frame_rate(display_state, frame_rate)

    {:reply, :ok, %{state | display_state: new_display}}
  end

  @impl true
  def handle_call({:write_frame_565, data}, _from, state) do
    %{driver_impl: driver_impl, display_state: display_state} = state
    new_display = driver_impl.write_frame_565(display_state, data)

    {:reply, :ok, %{state | display_state: new_display}}
  end

  @impl true
  def handle_call({:write_frame_666, data}, _from, state) do
    %{driver_impl: driver_impl, display_state: display_state} = state
    new_display = driver_impl.write_frame_666(display_state, data)

    {:reply, :ok, %{state | display_state: new_display}}
  end

  @impl true
  def handle_call({:write_frame, data, color}, _from, state) do
    %{driver_impl: driver_impl, display_state: display_state} = state
    new_display = driver_impl.write_frame(display_state, data, color)

    {:reply, :ok, %{state | display_state: new_display}}
  end

  @impl true
  def handle_call({:write_command, cmd, opts}, _from, state) do
    %{driver_impl: driver_impl, display_state: display_state} = state
    new_display = driver_impl.write_command(display_state, cmd, opts)

    {:reply, :ok, %{state | display_state: new_display}}
  end

  @impl true
  def handle_call({:write_data, data}, _from, state) do
    %{driver_impl: driver_impl, display_state: display_state} = state
    new_display = driver_impl.write_data(display_state, data)

    {:reply, :ok, %{state | display_state: new_display}}
  end

  @impl true
  def handle_call({:transfer, bytes, is_data}, _from, state) do
    %{driver_impl: driver_impl, display_state: display_state} = state
    new_display = driver_impl.transfer(display_state, bytes, is_data)

    {:reply, :ok, %{state | display_state: new_display}}
  end
end

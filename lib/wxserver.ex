defmodule WxServer do
  use GenServer, restart: :transient
  require Logger

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  @impl GenServer
  def init(args) do
    {:wx_ref, _, _, pid} = AstarWx.start_link(args)
    ref = Process.monitor(pid)
    {:ok, {ref, pid}}
  end

  @impl GenServer
  def handle_info({:DOWN, _, _, _, _}, _state) do
    Logger.info("handling DOWN")
    System.stop(0)
    {:stop, :ignore, nil}
  end
end

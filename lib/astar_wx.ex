defmodule AstarWx do
  require Logger

  @behaviour :wx_object
  @title "A-star Wx Demo"
  @width 640
  @height 480
  @size {@width, @height}

  def start_link(args) do
    :wx_object.start_link(__MODULE__, args, name: __MODULE__)
  end

  @impl true
  def init(_args) do
    Logger.info("starting")

    fps = Application.get_env(:astarwx, :fps, 30)
    slice = trunc(1_000 / fps)

    # Setup window
    wx = :wx.new([{:debug, :verbose}, {:silent_start, false}])

    frame_id = System.unique_integer([:positive, :monotonic])
    frame = :wxFrame.new(wx, frame_id, @title, size: @size)
    :wxFrame.connect(frame, :size)
    :wxFrame.connect(frame, :close_window)

    panel = :wxPanel.new(frame, [])
    # https://www.erlang.org/doc/man/wxmouseevent#type-wxMouseEventType
    :wxPanel.connect(panel, :paint, [:callback])
    :wxPanel.connect(panel, :left_up)
    :wxFrame.connect(panel, :motion)
    :wxPanel.connect(panel, :enter_window)
    :wxPanel.connect(panel, :leave_window)

    :wxFrame.show(frame)

    # This is what we draw on.
    blitmap = :wxBitmap.new(@width, @height)
    memory_dc = :wxMemoryDC.new(blitmap)

    Logger.info("starting timer #{slice}ms")
    timer_ref = Process.send_after(self(), :tick, slice)

    state = %{
      wx_frame: frame,
      wx_panel: panel,
      wx_memory_dc: memory_dc,

      updated_at: nil,

      timer_ref: timer_ref,
      slice: slice,
    }
    {frame, state}
  end

  ##
  ## Wx Async Events
  ##

  @impl true
  def handle_event({:wx, _, _, _, {:wxSize, :size, size, _}} = event, state) do
    Logger.info("received size event: #{inspect(event)}")
    :wxPanel.setSize(state.wx_panel, size)
    {:noreply, state}
  end

  @impl true
  def handle_event({:wx, _, _, _, {:wxClose, :close_window}} = event, state) do
    Logger.info("received close event: #{inspect(event)}")
    {:stop, :normal, state}
  end

  @impl true
  def handle_event({:wx, _id, _wx_ref, _something,
                    {:wxMouse, :enter_window,
                     _x, _y,
                     _left_down, _middle_down, _right_down,
                     _control_down, _shift_down, _alt_down, _meta_down,
                     _wheel_rotation, _wheel_delta, _lines_per_action}} = _event, state) do
    {:noreply, state}
  end

  @impl true
  def handle_event({:wx, _id, _wx_ref, _something,
                    {:wxMouse, :leave_window,
                     _x, _y,
                     _left_down, _middle_down, _right_down,
                     _control_down, _shift_down, _alt_down, _meta_down,
                     _wheel_rotation, _wheel_delta, _lines_per_action}} = _event, state) do
    {:noreply, state}
  end

  @impl true
  def handle_event({:wx, _id, _wx_ref, _something,
                    {:wxMouse, :motion, _x, _y,
                     _left_down, _middle_down, _right_down,
                     _control_down, _shift_down, _alt_down, _meta_down,
                     _wheel_rotation, _wheel_delta, _lines_per_action}} = event, state) do
    Logger.debug("mouse event #{inspect event, pretty: true}")
    {:noreply, state}
  end

  @impl true
  def handle_event({:wx, _id, _wx_ref, _something,
                    {:wxMouse, :left_up,
                     x, y,
                     left_down, _middle_down, _right_down,
                     _control_down, _shift_down, _alt_down, _meta_down,
                     _wheel_rotation, _wheel_delta, _lines_per_action}} = _event,
    state
  ) do
    Logger.info("click #{inspect {x, y}} #{left_down}")
    {:noreply, state}
  end

  @impl true
  def handle_event({:wx, _, _, _, _} = event, state) do
    Logger.info("unhandled wx event #{inspect event, pretty: true}")
    {:noreply, state}
  end

  ##
  ## Wx Sync Events
  ##

  @impl true
  def handle_sync_event({:wx, _, _, _, {:wxPaint, :paint}} = event, _, state) do
    Logger.debug("paint event #{inspect event, pretty: true}")

    dc = state.wx_memory_dc

    # Draw
    paint_dc = :wxPaintDC.new(state.wx_panel)
    :wxDC.blit(paint_dc, {0, 0}, @size, dc, {0, 0})

    # Cleanup :-/
    :wxPaintDC.destroy(paint_dc)

    :ok
  end

  @impl true
  def handle_sync_event(event, _, _state) do
    Logger.info("received sync event: #{inspect event, pretty: true}")
    :ok
  end

  ##
  ## Ticks
  ##

  @impl true
  def handle_info(:tick, state) do
    start_ms = System.convert_time_unit(System.monotonic_time, :native, :millisecond)
    Logger.debug("Tick at #{start_ms}ms #{inspect state, pretty: true}")

    new_state = update(state)
    render(new_state)

    end_ms = System.convert_time_unit(System.monotonic_time, :native, :millisecond)
    elapsed = trunc(end_ms - start_ms)
    pause = max(0, state[:slice] - elapsed)
    Logger.debug("Elapsed #{elapsed}ms, pausing #{pause}ms")

    timer_ref = Process.send_after(self(), :tick, pause)
    {:noreply, %{new_state | timer_ref: timer_ref}}
  end

  @impl true
  def handle_info({:EXIT, _pid, reason}, _state) do
    Logger.info("A child process died: #{reason}")
  end

  @impl true
  def handle_info(msg, state) do
    Logger.error("received unexpected message: #{inspect(msg)}")
    {:noreply, state}
  end

  @impl true
  def terminate(reason, state) do
    Logger.info("Terminating, #{inspect reason}")
    stop(state)
    exit(reason)
  end

  ##
  ## Gfx Loop
  ##

  def update(state) do
    state
  end

  def render(state) do
    Logger.debug("render")
    :wxPanel.refresh(state.wx_panel, eraseBackground: false)
  end

  def stop(_state) do
    Logger.info("stopping")
  end
end

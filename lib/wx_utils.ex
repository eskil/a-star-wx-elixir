defmodule WxUtils do
  @moduledoc """
  Utility functions for Wx operations.
  """

  @doc"""
  Draw a crosshair at the given `{x, y}` and with the given `color`

  Returns `:ok`

  ## Parameters
  * `dc`, a `wxDC` context to draw in
  * `pos`, a `{x, y}` coordinate to center the crosshair at
  * `color` a `{r, g, b}` colour value

  ## Options

  * `:width`, width of the pen. 1 is thin given the context, 2 is close to the
    pixel size.
  * `:size`, the length of each crosshair.
  """
  def wx_crosshair(dc, pos, color, options \\ []) do
    {x, y} = pos
    width = Keyword.get(options, :width, 1)
    size = Keyword.get(options, :size, 2)
    pen = :wxPen.new(color, [{:width,  width}, {:style, Wx.wxSOLID}])

    :wxDC.setPen(dc, pen)
    :ok = :wxDC.drawLine(dc, {x, y-size}, {x, y+size})
    :ok = :wxDC.drawLine(dc, {x-size, y}, {x+size, y})
    :wxPen.destroy(pen)
    :ok
  end

  def wx_cls(dc, color) do
    brush = :wxBrush.new(color, [{:style, Wx.wxSOLID}])
    :ok = :wxDC.setBackground(dc, brush)
    :ok = :wxDC.clear(dc)
    :wxBrush.destroy(brush)
  end

  def wx_cls(dc) do
    wx_cls(dc, {0, 0, 0})
  end
end

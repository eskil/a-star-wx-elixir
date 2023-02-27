defmodule Vector do
  @moduledoc """
  Various utility methods for Pacex. Quick and simple vector implementation.
  """

  defstruct [
    x: 0,
    y: 0,
  ]

  @type t :: %Vector{
    x: float(),
    y: float(),
  }

  def new(%{x: x, y: y}) do
    %Vector{x: x, y: y}
  end

  def new({x, y}) do
    %Vector{x: x, y: y}
  end

  def new(%Vector{}=a) do
    %Vector{x: a.x, y: a.y}
  end

  def new(x, y) do
    %Vector{x: x, y: y}
  end

  def len(%Vector{} = v) do
    :math.sqrt(v.x * v.x + v.y * v.y)
  end

  def len({x, y}) do
    :math.sqrt(x * x + y * y)
  end

  def add(%Vector{} = a, %Vector{} = b) do
    new(a.x + b.x, a.y + b.y)
  end

  def add({ax, ay}, {bx, by}) do
    new(ax + bx, ay + by)
  end

  def sub(%Vector{} = a, %Vector{} = b) do
    new(a.x - b.x, a.y - b.y)
  end

  def sub({ax, ay}, {bx, by}) do
    new(ax - bx, ay - by)
  end

  def distance(%Vector{} = a, %Vector{} = b) do
    len(sub(b, a))
  end

  def distance({_ax, _ay}=a, {_bx, _by}=b) do
    len(sub(b, a))
  end

  def normalise(%Vector{} = v) do
    l = len(v)
    new(v.x / l, v.y / l)
  end

  def normalise({x, y}=v) do
    l = len(v)
    new(x / l, y / l)
  end

  def dot(%Vector{} = a, %Vector{} = b) do
    a.x * b.x + a.y * b.y
  end

  def dot({ax, ay}, {bx, by}) do
    ax * bx + ay * by
  end

  def shorten(%Vector{}=a, sz) do
    s = 1 - sz/len(a)
    new(a.x * s, a.y * s)
  end

  def shorten({x, y}=v, sz) do
    s = 1 - sz/len(v)
    new(x * s, y * s)
  end

  def mag(%Vector{} = v) do
    :math.sqrt(:math.pow(v.x, 2) + :math.pow(v.y, 2))
  end

  def angle(%Vector{x: 0.0, y: y}) when y < 0 do
    - :math.pi / 2
  end

  def angle(%Vector{x: 0.0}) do
    :math.pi / 2
  end

  def angle(%Vector{x: 0, y: y}) when y < 0 do
    - :math.pi / 2
  end

  def angle(%Vector{x: 0}) do
    :math.pi / 2
  end

  def angle(%Vector{} = v) do
    :math.atan(-v.y / -v.x)
  end

  @doc"""
  Calls trunc on x & y to make the vector work with wx.
  """
  def truncate(%Vector{}=v) do
    new({trunc(v.x), trunc(v.y)})
  end

  @doc """
  This is a graph oriented degree, ie. left is 0, up is 90 etc.

  ## Examples
      iex> alias Vector, as: Vector
      Vector
      iex> Vector.degrees_a(Vector.new(1, 1))
      45.0
      iex> Vector.degrees_a(Vector.new(0, 1))
      90.0
      iex> Vector.degrees_a(Vector.new(1, 0))
      -0.0
      iex> Vector.degrees_a(Vector.new(-1, 1))
      135.0
      iex> Vector.degrees_a(Vector.new(-1, 0))
      180.0
      iex> Vector.degrees_a(Vector.new(-1, -1))
      225.0
      iex> Vector.degrees_a(Vector.new(0, -1))
      270.0
      iex> Vector.degrees_a(Vector.new(1, -1))
      315.0
  """
  def degrees_a(%Vector{} = v) do
    a = angle(v) * (180 / :math.pi)
    a = if v.x < 0 do
      180 + a
    else
      if v.y < 0 do
        360 + a
      else
        a
      end
    end
    a
  end

  @doc """
  This is a screen oriented degree. Degrees are in North=up (0) South=down (180) degrees.
  Vectors are in x,y screen coordinate, so 1,1 = 135D down to right

  ## Examples
      iex> Vector.degrees(Vector.new(0, -1))
      0
      iex> Vector.degrees(Vector.new(1, -1))
      45
      iex> Vector.degrees(Vector.new(1, 0))
      90
      iex> Vector.degrees(Vector.new(1, 1))
      135
      iex> Vector.degrees(Vector.new(0, 1))
      180
      iex> Vector.degrees(Vector.new(-1, 1))
      225
      iex> Vector.degrees(Vector.new(-1, 0))
      270
      iex> Vector.degrees(Vector.new(-1, -1))
      315
  """
  def degrees(%Vector{} = v) do
    # Y is our "north" and it's pointing "right" to rotate.
    y = new(0, -1)
    d = dot(v, y)
    cos_a = d / (mag(v) * mag(y))
    d = :math.acos(cos_a) * (180 / :math.pi)
    if v.x < 0 do
      360 - d
    else
      d
    end
    |> trunc
  end
end

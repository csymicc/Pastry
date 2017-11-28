defmodule Project3Test do
  use ExUnit.Case
  doctest NIOper

  test "greets the world" do
    leafSet = {["30C8D7DFFF64D2657ED03EEC790D3627", "C9622B007444A88EE3E27FB14FDA479E", "B804288617393EC6EEE568687C548A58", "B823171A9C40A0F6F7FC3914C1376261", "30C8D7DFFF64D2657ED03EEC790D3627", "C9622B007444A88EE3E27FB14FDA479E", "B804288617393EC6EEE568687C548A58", "B823171A9C40A0F6F7FC3914C1376261"], ["56A2BCFE9A53B744D98037323B5C79CF", "5CA3364B9A9322EB3216D931BB4DB5C3", "6E4CAFC1C9CA29000C23A9A46D007233", "964A7426C6F7010BE14BEE3AD211DCA7", "6E4CAFC1C9CA29000C23A9A46D007233", "964A7426C6F7010BE14BEE3AD211DCA7", "6E4CAFC1C9CA29000C23A9A46D007233", "5E987FBE07C453132DCD81BAD6338238"]}
    from = "2F6FB39BD6227D719588C71AF57E108D"
    nodeId = "325B71CD559E50E917176BA60D700EE5"
    nextId = "2435F7591A2BF95EED10A900A1520225"
    { a, b } = leafSet
    list = 
    a ++ b    
    |> Enum.filter(&(&1 != nodeId))
    |> Enum.group_by(fn nId -> NIOper.compare(nodeId, nId) > 0 end)
    
    smaller = (if Map.has_key?(list, :false), do: list.false, else: [])
    |> Enum.map(&({ &1, NIOper.distance(nodeId, &1) }))
    |> Enum.sort(fn { _, d1 }, { _, d2 } -> d1 > d2 end) 
    |> Enum.map(fn { nId, _ } -> nId end)
    dlens = if length(smaller) > div(16, 2), do: length(smaller) - div(16, 2), else: 0
    smaller = Enum.drop(smaller, dlens)
    IO.puts inspect smaller
    IO.puts NIOper.distance(from, nodeId)
    IO.puts NIOper.distance(from, nextId)

  end


end

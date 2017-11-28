defmodule NIOper do

    @factor  round(:math.pow(2, 128))

    def inRange(nodeId, leafSet) do
        { smaller, larger } = leafSet
        if length(smaller) == 0 || length(larger) == 0 do
            :false
        else
            val1 = String.to_integer(nodeId, 16)
            val2 = val1 + @factor
            min = Enum.at(smaller, 0) |> String.to_integer(16)
            max = Enum.at(larger, 0) |> String.to_integer(16)
            max = if min > max, do: max + @factor, else: max
            cond do
                min == max -> :true
                min <= val1 && val1 <= max -> :true
                min <= val2 && val2 <= max -> :true
                :true -> :false
            end
        end
    end

    def compare(nodeId1, nodeId2) do
        start = String.to_integer(nodeId1, 16)
        last = start + div(@factor, 2)
        val1 = String.to_integer(nodeId2, 16)
        val2 = val1 + @factor
        if (start < val1 && val1 < last) || (start < val2 && val2 < last), 
        do: 1, else: -1
    end

    def distance(nodeId1, nodeId2) do
        val1 = String.to_integer(nodeId1, 16)
        val2 = String.to_integer(nodeId2, 16)
        val3 = min(val1, val2) + @factor - max(val1, val2)
        min(abs(val1 - val2), val3)
    end

    def find_closet( _ , closet, []), do: closet
    def find_closet(nodeId, closet, numSet) do
        [ head | tail ] = numSet
        if distance(head, nodeId) < distance(closet, nodeId) do
            find_closet(nodeId, head, tail)
        else 
            find_closet(nodeId, closet, tail)
        end
    end

    def shl(nodeId1, nodeId2), do: get_shl(String.codepoints(nodeId1), String.codepoints(nodeId2), 0)
    def get_shl( [], _ , clens), do: clens
    def get_shl( _ , [], clens), do: clens
    def get_shl(nodeId1, nodeId2, clens) do
        [ head1 | tail1 ] = nodeId1
        [ head2 | tail2 ] = nodeId2
        if head1 == head2 do
            get_shl(tail1, tail2, clens + 1)
        else 
            clens
        end
    end

end
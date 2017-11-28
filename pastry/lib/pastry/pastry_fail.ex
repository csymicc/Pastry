defmodule Pastry.Fail do
    def check_leaf_fail(nodeId, leafSet, nodeState) do
        { _ , routingTable, neighborSet, nameMap } = Agent.get(nodeState, &(&1))
        { smaller, larger } = leafSet
        salive = Enum.filter(smaller, fn nodeId -> 
            Map.get(nameMap, nodeId) |> Process.whereis != :nil 
        end)
        if length(salive) != length(smaller) do
            min = Map.get(nameMap, Enum.at(salive, 0)) |> Process.whereis
            GenServer.cast(min, { :leafSet_fail, :from, nodeId })
        end
        lalive = Enum.filter(larger, fn nodeId -> 
            Map.get(nameMap, nodeId) |> Process.whereis != :nil 
        end)
        if length(lalive) != length(larger) do
            max = Map.get(nameMap, Enum.at(lalive, 0)) |> Process.whereis
            GenServer.cast(max, { :leafSet_fail, :from, nodeId })
        end
        if length(smaller) + length(larger) != length(salive) + length(lalive) do
            Agent.update(nodeState, fn _ -> { leafSet, routingTable, neighborSet, nameMap } end)
        end
        { salive, lalive }
    end

    def check_routingTable_fail(nextId, position, nodeId, l, routingTable, nameMap, nodeState) do
        row = Enum.at(routingTable, l)
        if nextId != :nil && Map.get(nameMap, nextId) |> Process.whereis == :nil do
            
            dead = Enum.filter(row, fn { _ , nId } -> 
                Map.get(nameMap, nId)
                |> Process.whereis
                == :nil
            end)
            live = Enum.filter(row, fn { _ , nId } -> 
                Map.get(nameMap, nId)
                |> Process.whereis
                != :nil
            end) |> Enum.into(Map.new())

            c = String.at(nextId, l)
            forward = Enum.reduce(0..31, :nil, fn (row_num, firstNode) -> 
                if row_num < l || firstNode != :nil do
                    firstNode
                else
                    Enum.at(routingTable, row_num)
                    |> Enum.map(fn { key , value } -> 
                        { key, Map.get(nameMap, value) |> Process.whereis }
                    end)
                    |> Enum.filter(fn { key, value } -> 
                        value != :nil && key != c
                    end)
                    |> Enum.map(fn { _ , value } -> value end)
                    |> Enum.at(0)
                end
            end)

            if forward != :nil do
                Enum.map(dead, fn { char, _ } -> 
                    GenServer.cast(forward, { :routingTable_fail, position, nodeId, char, l })
                end)
            end
            routingTable = Pastry.Update.update_routingTable(routingTable, live, l)
            { leafSet , _ , neighborSet, _ } = Agent.get(nodeState, &(&1))
            nameMap = Pastry.Update.update_nameMap(position, nodeId, leafSet, routingTable, neighborSet, nameMap)
            Agent.update(nodeState, fn _ -> { leafSet, routingTable, neighborSet, nameMap } end)
            :nil
        else
            nextId
        end
    end

    def check_neighbours_fail(position, nodeId, nodeState) do
        :timer.sleep(5000)
        { leafSet , routingTable , neighborSet, nameMap } = Agent.get(nodeState, &(&1))
        aliveNode = 
        Enum.map(neighborSet, &(Map.get(nameMap, &1)))
        |> Enum.map(&(Process.whereis(&1)))
        |> Enum.filter(&(&1 != :nil))
        if length(aliveNode) != length(neighborSet) do
            Enum.map(aliveNode, &(GenServer.cast(&1, { :neighbor_fail, position, nodeId })))
            Agent.update(nodeState, fn _ -> { leafSet, routingTable, neighborSet, nameMap } end)
        end
        check_neighbours_fail(position, nodeId, nodeState)
    end

end
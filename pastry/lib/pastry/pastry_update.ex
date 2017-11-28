defmodule Pastry.Update do

    @lvalue 16
    @mvalue 16

    def update_leafSet(ls, leafSet, nodeId, fromId) do
        { s1, l1 } = leafSet
        { s2, l2 } = ls
        list = s1 ++ l1 ++ s2 ++ l2 ++ [ fromId ] 
        |> Enum.uniq
        |> Enum.filter(&(&1 != nodeId))
        |> Enum.group_by(fn nId -> NIOper.compare(nodeId, nId) > 0 end)

        smaller = (if Map.has_key?(list, :false), do: list.false, else: [])
        |> Enum.map(&({ &1, NIOper.distance(nodeId, &1) }))
        |> Enum.sort(fn { _, d1 }, { _, d2 } -> d1 > d2 end) 
        |> Enum.map(fn { nId, _ } -> nId end)
        dlens = if length(smaller) > div(@lvalue, 2), do: length(smaller) - div(@lvalue, 2), else: 0
        smaller = Enum.drop(smaller, dlens)

        larger = (if Map.has_key?(list, :true), do: list.true, else: [])
        |> Enum.map(&({ &1, NIOper.distance(nodeId, &1) }))
        |> Enum.sort(fn { _, d1 }, { _, d2 } -> d1 > d2 end) 
        |> Enum.map(fn { nId, _ } -> nId end)
        dlens = if length(larger) > div(@lvalue, 2), do: length(larger) - div(@lvalue, 2), else: 0
        larger = Enum.drop(larger, dlens)
        { smaller, larger }
    end

    def update_routingTable(nodeId, fromId, routingTable, rt, frow, erow, nameMap) do
        l = NIOper.shl(nodeId, fromId)
        Enum.reduce(0..31, [], fn (row_num, newtable) -> 
            if row_num < frow || row_num > erow do
                newtable ++ [ Enum.at(routingTable, row_num) ]
            else
                row1 = Enum.at(routingTable, row_num) |> Map.values
                row2 = Enum.at(rt, row_num) |> Map.values
                row2 = if row_num == l, do: row2 ++ [ fromId ], else: row2
                map = row1 ++ row2 |> Enum.filter(fn nId -> NIOper.shl(nId, nodeId) == row_num end)
                |> Enum.group_by(fn nId -> String.at(nId, row_num) end)
                |> Enum.map(fn { c, list } -> 
                    if length(list) == 2 do
                        [ pos1, pos2 ] = Enum.map(list, &(Map.get(nameMap, &1)))
                        cpos = Map.get(nameMap, nodeId)      
                        if NetNode.distance(pos1, cpos) > NetNode.distance(pos2, cpos) do
                            { c, Enum.at(list, 1) }
                        else { c, Enum.at(list, 0) }
                        end
                    else
                        { c, Enum.at(list, 0) }
                    end
                end)
                |> Enum.into(Map.new())
                newtable ++ [ map ]
            end
        end)
    end
    
    def update_routingTable(routingTable, row, l) do
        Enum.reduce(0..31, [], fn (row_num, newtable) -> 
            if row_num != l do
                newtable ++ [ Enum.at(routingTable, row_num) ]
            else
                newtable ++ [ row ]
            end
        end)
    end
    
    def update_neighborSet(position, neighborSet, ns, nameMap) do
        new_neighborSet = neighborSet ++ ns 
        |> Enum.uniq
        |> Enum.map(&({ &1, NetNode.distance(position, Map.get(nameMap, &1)) }))
        |> Enum.sort(fn { _, d1 }, { _, d2 } -> d1 > d2 end)
        |> Enum.map(fn { nId, _ } -> nId end)
        dlens = if length(new_neighborSet) > @mvalue, do: length(new_neighborSet) - @mvalue, else: 0
        Enum.drop(new_neighborSet, dlens)
    end

    def update_nameMap(position, nodeId, leafSet, routingTable, neighborSet, nameMap) do
        { smaller, larger } = leafSet
        smaller ++ larger ++ neighborSet ++ 
        Enum.reduce(routingTable, [], fn(map, list) -> list ++ Map.values(map) end)
        |> Enum.uniq
        |> Enum.map(&({ &1, Map.get(nameMap, &1) })) |> Enum.into(Map.new())
        |> Map.put(nodeId, position)
    end

end
defmodule Pastry do
    use GenServer

    def init(position) do
        leafSet = { [], [] }
        routingTable = Enum.reduce(1..32, [], fn(_, rt) -> rt ++ [%{}] end)
        neighborSet = []
        nodeId = Base.encode16(:crypto.hash(:md5, Atom.to_string(position)))
        nameMap = %{ nodeId => position }
        
        nodeState = Atom.to_string(position) 
        |> String.replace("Pastry_", "State_") 
        |> String.to_atom

        Agent.start(fn -> { leafSet, routingTable, neighborSet, nameMap } end, name: nodeState)

        { :ok, { position, nodeId, nodeState } }
    end

    def handle_call(neighbour, _, state) do
        { position, nodeId, nodeState } = state
        GenServer.cast(neighbour, { :join, position, nodeId, 1 })
        init_State(position, nodeId, nodeState)

        table = Agent.get(nodeState, &(&1))
        { leafSet, routingTable, neighborSet, nameMap } = table
        { smaller, larger } = leafSet

        smaller ++ larger ++ neighborSet ++ 
        Enum.reduce(routingTable, [], fn(map, list) -> list ++ Map.values(map) end)
        |> Enum.uniq
        |> Enum.map(&(Map.get(nameMap, &1)))
        |> Enum.each(&(GenServer.cast(&1, { :join_finish, position, nodeId, table } )))

        spawn(Pastry.Fail, :check_neighbours_fail, [ position, nodeId, nodeState ])

        { :reply, :init_finish, state }
    end

    def init_State(position, nodeId, nodeState) do
        receive do
            { :join, state, fromId, hops, table } ->
                { ls , rt, ns, nm } = table
                { leafSet, routingTable, neighborSet, nameMap } = Agent.get(nodeState, &(&1))
                nameMap = Map.merge(nameMap, nm)
                leafSet = 
                if state == :finish do
                    Pastry.Update.update_leafSet(ls, leafSet, nodeId, fromId)
                else leafSet end
                #IO.puts "from  " <> fromId
                routingTable = Pastry.Update.update_routingTable(nodeId, fromId, routingTable, rt, hops - 1, hops - 1, nameMap)
                
                neighborSet = 
                if hops == 1 do 
                    Pastry.Update.update_neighborSet(position, neighborSet, ns ++ [ fromId ], nameMap) 
                else neighborSet end
               
                nameMap = Pastry.Update.update_nameMap(position, nodeId, leafSet, routingTable, neighborSet, nameMap)
                Agent.update(nodeState, fn _ -> { leafSet, routingTable, neighborSet, nameMap } end)
                
                if state == :unfinish do 
                    init_State(position, nodeId, nodeState)
                #else IO.puts Atom.to_string(position) <> " initalization completes"
                end
            
        end
    end

    def handle_cast(msg, state) do
        { position, nodeId, nodeState } = state
        case msg do
            { :join, from, fromId, hops } -> 
                handle_join(from, fromId, nodeId, position, hops, nodeState)
            { :join_finish, _, fromId, fromtable } -> 
                handle_update(fromId, position, nodeId, fromtable, nodeState)
            { :request, key, msg } -> 
                handle_request(position, :node, nodeId, key, nodeId, msg, 0, nodeState) 
            { :request, from, fromId, key, msg, hops } ->
                handle_request(position, from, fromId, key, nodeId, msg, hops, nodeState)
            { :leafSet_fail, from, fromId} ->
                handle_fail(:leafSet, position, nodeId, nodeState, { from, fromId })
            { :routingTable_fail, from, fromId, c, l } ->
                handle_fail(:routingTable, position, nodeId, nodeState, { from, fromId, c, l })
            { :neighbor_fail, from, fromId } ->
                handle_fail(:neighbor, position, nodeId, nodeState, { from, fromId })
            { :lf_response, from, fromId, ls, nm } ->
                handle_fail_response(:leafSet, position, nodeId, nodeState, { from, fromId, ls, nm })
            { :rtf_response, from, fromId, info } ->
                handle_fail_response(:routingTable, position, nodeId, nodeState, { from, fromId, info })
            { :nf_response, from, fromId, ns, nm } ->
                handle_fail_response(:neighbor, position, nodeId, nodeState, { from, fromId, ns, nm })
        end
        { :noreply, state }
    end

    #receive node fail message
    def handle_fail(:leafSet, position, nodeId, nodeState, info) do
        { from , _ } = info
        { leafSet , _ , _ , nameMap } = Agent.get(nodeState, &(&1))
        GenServer.cast(from, { :lf_response, position, nodeId, leafSet, nameMap })
    end
    def handle_fail(:routingTable, position, nodeId, nodeState, info) do
        { from , _ , c, l } = info
        { _ , routingTable , _ , nameMap } = Agent.get(nodeState, &(&1))
        row = Enum.at(routingTable, l)
        entry = Map.get(row, c)
        if entry != :nil && Map.get(nameMap, entry) |> Process.whereis != :nil do
            GenServer.cast(from, { :rtf_response, position, nodeId, { c, l, entry, Map.get(nameMap, entry) } })
        else
            GenServer.cast(from, { :rtf_response, position, nodeId, :nil })
        end
    end
    def handle_fail(:neighbor, position, nodeId, nodeState, info) do
        { from , _ } = info
        { _ , _ , neighborSet, nameMap } = Agent.get(nodeState, &(&1))
        GenServer.cast(from, { :nf_response, position, nodeId, neighborSet, nameMap })
    end

    #receive response to node fail message
    def handle_fail_response(:leafSet, position, nodeId , nodeState, msg_info) do
        { _ , fromId , ls, nm } = msg_info
        { leafSet, routingTable, neighborSet, nameMap } = Agent.get(nodeState, &(&1))
        nameMap = Map.merge(nm, nameMap)
        leafSet = Pastry.Update.update_leafSet(ls, leafSet, nodeId, fromId)
        Pastry.Update.update_nameMap(position, nodeId, leafSet, routingTable, neighborSet, nameMap)
        Agent.update(nodeState, fn _ -> { leafSet, routingTable, neighborSet, nameMap } end)
    end
    def handle_fail_response(:routingTable, _ , _ , nodeState, msg_info) do
        { _ , _ , info } = msg_info
        { leafSet, routingTable, neighborSet, nameMap } = Agent.get(nodeState, &(&1))
        { routingTable, nameMap } = case info do
            { c, l, entry, epos } ->
                row = Enum.at(routingTable, l)
                |> Map.delete(c)
                |> Map.put(c, entry)
                { Pastry.Update.update_routingTable(routingTable, row, l),
                Map.put(nameMap, entry, epos) }
            :nil -> { routingTable, nameMap }
        end
        Agent.update(nodeState, fn _ -> { leafSet, routingTable, neighborSet, nameMap } end)
    end
    def handle_fail_response(:neighbor, position, nodeId , nodeState, msg_info) do
        { from , fromId , ns, nm } = msg_info
        { leafSet, routingTable, neighborSet, nameMap } = Agent.get(nodeState, &(&1))
        nameMap = Map.merge(nm, nameMap) |> Map.put(fromId, from)
        neighborSet = Pastry.Update.update_neighborSet(position, neighborSet, ns ++ [ fromId ], nameMap)
        Pastry.Update.update_nameMap(position, nodeId, leafSet, routingTable, neighborSet, nameMap)
        Agent.update(nodeState, fn _ -> { leafSet, routingTable, neighborSet, nameMap } end)
    end

    #handle message come from a new node
    def handle_join(from, fromId, nodeId, position, hops, nodeState) do
        #IO.puts Atom.to_string(position) <> "   " <> Atom.to_string(from)
        table = Agent.get(nodeState, &(&1))
        { leafSet, routingTable, _ , nameMap } = table 
        nextId = routing_msg(position, fromId, nodeId, leafSet, routingTable, nameMap, nodeState)
        #IO.puts from
        #IO.puts fromId
        #IO.puts nodeId
        #IO.puts nextId
        #IO.puts hops
        #IO.puts "-----------"
        if nextId == nodeId do
            send(from, { :join, :finish, nodeId, hops, table })
        else 
            send(from, { :join, :unfinish, nodeId, hops, table })
            GenServer.cast(Map.get(nameMap, nextId), { :join, from, fromId, hops + 1 })
        end
    end

    #receive message is a node table and update self table according to it
    def handle_update(fromId, position, nodeId, fromtable, nodeState) do
        { ls , rt, ns, nm } = fromtable
        { leafSet, routingTable, neighborSet, nameMap } = Agent.get(nodeState, &(&1))
        nameMap = Map.merge(nameMap, nm)
        leafSet = Pastry.Update.update_leafSet(ls, leafSet, nodeId, fromId)
        routingTable = Pastry.Update.update_routingTable(nodeId, fromId, routingTable, rt, 0, NIOper.shl(fromId, nodeId), nameMap)
        neighborSet = Pastry.Update.update_neighborSet(position, neighborSet, ns ++ [ fromId ], nameMap)
        nameMap = Pastry.Update.update_nameMap(position, nodeId, leafSet, routingTable, neighborSet, nameMap) 
        Agent.update(nodeState, fn _ -> { leafSet, routingTable, neighborSet, nameMap } end)
    end

    def handle_request(position, from, fromId, key, nodeId, msg, hops, nodeState) do
        #IO.puts Atom.to_string(position) <> "   " <> fromId
        #IO.puts hops
        { leafSet, routingTable, _ , nameMap } = Agent.get(nodeState, &(&1))
        nextId = routing_msg(position, key, nodeId, leafSet, routingTable, nameMap, nodeState)
        if nextId == nodeId do
            Map.get(nameMap, nodeId)
            |> Atom.to_string 
            |> String.replace("Pastry_", "Node_") 
            |> String.to_atom
            |> GenServer.cast({ from, key, hops, msg })
        else
            GenServer.cast(Map.get(nameMap, nextId), { :request, from, fromId, key, msg, hops + 1 })
        end
    end

    #routing algorithm
    def routing_msg(position, key, nodeId, leafSet, routingTable, nameMap, nodeState) do
        leafSet = Pastry.Fail.check_leaf_fail(nodeId, leafSet, nodeState)
        if NIOper.inRange(key, leafSet) do
            { smaller, larger } = leafSet
            NIOper.find_closet(key, nodeId, smaller ++ larger)
        else
            l = NIOper.shl(key, nodeId)
            nextId = Enum.at(routingTable, l) 
            |> Map.get(String.at(key, l))
            |> Pastry.Fail.check_routingTable_fail(position, nodeId, l, routingTable, nameMap, nodeState)
            case nextId do
                :nil -> route_to_nearest(key, nodeId, l, nameMap)
                nextId -> nextId
            end
        end
    end

    def route_to_nearest(key, nodeId, l, nameMap) do
        nameMap = Enum.filter(nameMap, fn { _ , value } -> 
            Process.whereis(value) != :nil
        end) |> Enum.into(Map.new())
        [ head | tail ] = Map.keys(nameMap)
        nextId = NIOper.find_closet(key, head, tail)
        if NIOper.shl(nextId, key) < l 
        || NIOper.distance(nextId, key) >= NIOper.distance(nodeId, key) do 
            nodeId
        else nextId
        end
    end

    #def terminate( _, state) do
        #{ position, nodeId, _ } = state
        #IO.puts Atom.to_string(position) <> " terminates " <> nodeId
    #end

end
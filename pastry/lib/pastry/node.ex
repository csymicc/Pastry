defmodule NetNode do
    use GenServer

    @reuslt :result
    @interval 1000

    def init(position) do
        { :ok, 
        Atom.to_string(position) 
        |> String.replace("Node_", "Pastry_") 
        |> String.to_atom }
    end

    def handle_call({ :init, [] }, _, position) do
        { :ok, pid } = GenServer.start_link(Pastry, position, name: position)
        { :reply, pid, { position, pid } }
    end
    def handle_call({ :init, nodelist }, _, position) do
        neighbour = find_nearest_neigh(position, nodelist)
        { :ok, pid } = GenServer.start_link(Pastry, position, name: position)
        GenServer.call(pid, neighbour, 100000)
        { :reply, pid, { position, pid } }
    end

    def handle_cast({ :start, parentId, numRequest, numNodes }, state) do
        { position, pid } = state
        spawn(NetNode, :sending, [ pid, parentId, position, numRequest, numRequest * numNodes * 10 ] )
        { :noreply, state }
    end

    def handle_cast({ _ , _ , hops, _ }, state) do
        #{ request, requestNo } = msg
        { node, _ } = state
        Agent.update(:result, fn list -> list ++ [ hops ] end)
        #IO.puts "#{inspect node} receives a request from #{inspect from}. hops is #{hops}. RequestNo is #{requestNo}"
        { :noreply, state }
    end

    def sending( _ , parentId, position, 0, _ ), do: send(parentId, { :finish, position })
    def sending(pid, parentId, position, times, num) do
        key = Base.encode16(:crypto.hash(:md5, Integer.to_string(:rand.uniform(num))))
        GenServer.cast(pid, { :request, key, { "pastry", times } })
        #IO.puts "round #{times}"
        :timer.sleep(@interval)
        sending(pid, parentId, position, times - 1, num)
    end

    def find_nearest_neigh(pos, nodelist) do
        [ head | tail ] = nodelist
        Enum.reduce(tail, head, fn (npos, head) -> 
            if distance(pos, npos) < distance(pos, head) do npos
            else head end
        end)
    end

    def distance(p1, p2) do
        pos1 = Atom.to_string(p1) |> String.replace("Pastry_", "") 
        |> String.split("_") |> Enum.map(&(String.to_integer(&1)))
        pos2 = Atom.to_string(p2) |> String.replace("Pastry_", "") 
        |> String.split("_") |> Enum.map(&(String.to_integer(&1)))
        dx = Enum.at(pos1, 0) - Enum.at(pos2, 0)
        dy = Enum.at(pos1, 1) - Enum.at(pos2, 1)
        dx * dx + dy * dy
    end

    #def terminate( _, state) do
        #{ node, _ } = state
        #IO.puts Atom.to_string(node) <> " terminates"
    #end

end
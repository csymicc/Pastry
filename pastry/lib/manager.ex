defmodule Manager do

    def main(numNodes, numRequests) do
        nodelist = Enum.to_list(0..numNodes * 10) 
        |> Enum.shuffle 
        |> Enum.take(2 * numNodes)
        |> Enum.map(&(Integer.to_string(&1)))
        |> Enum.chunk_every(2)
        |> Enum.map(fn [x, y] -> "Node_" <> x <> "_" <> y |> String.to_atom end)
        |> Enum.map(&({ &1, GenServer.start_link(NetNode, &1, name: &1) }))
        |> Enum.reduce([], fn ({ pos, { :ok, pid } }, list) -> 
            pos = changeName(pos, "Node_", "Pastry_")
            IO.puts Integer.to_string(length(list)) <> "init #{pos} #{inspect pid}"
            GenServer.call(pid, { :init, list }, 100000)
            :timer.sleep(200)
            list ++ [ pos ]
        end)
        |> Enum.map(&(changeName(&1, "Pastry_", "Node_")))
        Agent.start(fn -> [] end, name: :result)
        Enum.map(nodelist, fn nodeName -> 
            GenServer.cast(nodeName, { :start, self(), numRequests, numNodes })
        end)
        wait(numNodes, numNodes * numRequests)
    end

    def changeName(element, name1, name2) do
        Atom.to_string(element) 
        |> String.replace(name1, name2) 
        |> String.to_atom
    end

    def wait(0, total), do: show_result(total)
    def wait(numNodes, total) do
        receive do
            { :finish, _ } ->  :ok #IO.puts "#{pos} has finished" 
        end
        wait(numNodes - 1, total)
    end

    def show_result(total) do
        IO.puts "wait for finish"
        :timer.sleep(20000)
        result = Agent.get(:result, &(&1))
        |> Enum.group_by(&(&1))
        |> Enum.map(fn { key, value } -> { key, length(value) } end)
        IO.puts inspect result
        sum = Enum.reduce(result, 0, fn ({ key, value }, sum) -> sum + key * value end)
        IO.puts sum / total
    end

end
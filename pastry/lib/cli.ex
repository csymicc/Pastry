defmodule Project3.CLI do
    
    def main(args) do
        numNodes = Enum.at(args, 0) |> String.to_integer
        numRequests = Enum.at(args, 1) |> String.to_integer
        if length(args) == 3 do
            ManagerFail.main(numNodes, numRequests)
        else
            Manager.main(numNodes, numRequests)
        end
    end

end
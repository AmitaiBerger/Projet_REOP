using Pkg
Pkg.activate(joinpath(@__DIR__, ".."))

using KIRO2025
using Printf

function main()
    if length(ARGS) < 2
        println("Usage: julia scripts/evaluate_solution.jl <instance_path> <solution_path> [vehicle_path]")
        println("Example: julia scripts/evaluate_solution.jl data-projet/instances/instance_01.csv data-projet/solutions/solution_01.csv")
        return
    end

    instance_path = ARGS[1]
    solution_path = ARGS[2]
    
    if length(ARGS) >= 3
        vehicle_path = ARGS[3]
    else
        # Default assumption: vehicles.csv is in the same folder as the instance
        vehicle_path = joinpath(dirname(instance_path), "vehicles.csv")
        if !isfile(vehicle_path)
             # Fallback to v3-ponts location if not found
             vehicle_path = joinpath(@__DIR__, "..", "data", "v3-ponts", "instances", "vehicles.csv")
        end
    end

    println("Instance: $instance_path")
    println("Solution: $solution_path")
    println("Vehicles: $vehicle_path")

    if !isfile(instance_path)
        println("Error: Instance file not found at $instance_path")
        return
    end
    if !isfile(solution_path)
        println("Error: Solution file not found at $solution_path")
        return
    end
    if !isfile(vehicle_path)
        println("Error: Vehicle file not found at $vehicle_path")
        return
    end

    instance = read_instance(instance_path, vehicle_path)
    solution = read_solution(solution_path)

    println("-"^40)
    println("Evaluation Results")
    println("-"^40)

    # Check feasibility
    # Note: is_feasible prints warnings for violations
    feasible = is_feasible(solution, instance)
    
    if feasible
        println("Status: FEASIBLE ✅")
    else
        println("Status: INFEASIBLE ❌")
    end

    # Compute costs
    c = cost(solution, instance)
    rc = rental_cost(solution, instance)
    fc = fuel_cost(solution, instance)
    radc = radius_cost(solution, instance)

    @printf("Total Cost:  %.2f\n", c)
    @printf("  Rental:    %.2f\n", rc)
    @printf("  Fuel:      %.2f\n", fc)
    @printf("  Radius:    %.2f\n", radc)
    println("-"^40)
end

main()

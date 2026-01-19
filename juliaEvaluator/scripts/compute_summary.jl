using Pkg
Pkg.activate(".")
using KIRO2025

function compute_summary()
    # Read instances and solutions
    instance_dir = "data-projet/instances"
    solution_dir = "data-projet/solutions"
    vehicle_file = joinpath(instance_dir, "vehicles.csv")

    total_cost = 0.0

    for i in 1:10
        println("\nInstance $(i):")
        instance_file = joinpath(instance_dir, "instance_$(lpad(i, 2, '0')).csv")
        instance = read_instance(instance_file, vehicle_file)

        solution = read_solution(
            joinpath(solution_dir, "solution_$(lpad(i, 2, '0')).csv")
        )

        # Check feasibility before computing costs
        solution_feasible = is_feasible(solution, instance)
        solution_cost = cost(solution,instance)
        
        println("  Bad: $(round(solution_cost, digits=2)) [Feasible: $(solution_feasible)]")

        total_cost += solution_cost
    end

    println("\n" * "="^60)
    println("SUMMARY ACROSS ALL 10 INSTANCES:")
    println("="^60)
    println("Total Cost:        $(round(total_cost, digits=2))")
end

compute_summary()

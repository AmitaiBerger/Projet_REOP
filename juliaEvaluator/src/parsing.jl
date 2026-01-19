function read_instance(instance_file::String, vehicle_file::String)
    # Read vehicles
    @assert isfile(vehicle_file) "vehicles.csv not found at $vehicle_file"
    df_vehicles = CSV.read(vehicle_file, DataFrame)
    vehicles = map(eachrow(df_vehicles)) do row
        # Extract fourier coefficients
        fourier_cos = [
            row.fourier_cos_0, row.fourier_cos_1, row.fourier_cos_2, row.fourier_cos_3
        ]
        fourier_sin = [
            row.fourier_sin_0, row.fourier_sin_1, row.fourier_sin_2, row.fourier_sin_3
        ]

        return Vehicle(
            row.family,
            row.max_capacity,
            row.rental_cost,
            row.fuel_cost,
            row.radius_cost,
            row.speed,
            row.parking_time,
            fourier_cos,
            fourier_sin,
        )
    end

    # Read instance
    @assert isfile(instance_file) "Instance file not found at $instance_file"
    df = CSV.read(instance_file, DataFrame)

    # Find depot (id=0)
    depot_row = df[df.id .== 0, :]
    @assert nrow(depot_row) == 1 "Expected exactly one depot (id=0)"
    @assert depot_row.latitude[1] == DEPOT.latitude "Depot latitude does not match the expected value"
    @assert depot_row.longitude[1] == DEPOT.longitude "Depot longitude does not match the expected value"
    depot = Order(
        0,
        depot_row.longitude[1],
        depot_row.latitude[1],
        0.0,
        0,
        0,
        depot_row.delivery_duration[1],
    )

    # Read orders (all rows except depot)
    order_rows = df[df.id .!= 0, :]
    orders = [
        Order(
            row.id,
            row.longitude,
            row.latitude,
            row.order_weight,
            row.window_start,
            row.window_end,
            row.delivery_duration,
        ) for row in eachrow(order_rows)
    ]

    # Build distance matrix (placeholder - needs actual computation or loading)
    n = length(orders)
    euclidean_distances = zeros(n + 1, n + 1)
    manhattan_distances = zeros(n + 1, n + 1)
    for i in 1:(n + 1)
        for j in 1:(n + 1)
            if i == j
                euclidean_distances[i, j] = 0
                manhattan_distances[i, j] = 0
            else
                o1 = i == 1 ? depot : orders[i - 1]
                o2 = j == 1 ? depot : orders[j - 1]
                euclidean_distances[i, j] = euclidean_distance(o1, o2)
                manhattan_distances[i, j] = manhattan_distance(o1, o2)
            end
        end
    end
    return Instance(vehicles, depot, orders, euclidean_distances, manhattan_distances)
end

function write_solution(solution::Solution, filepath::String)
    # Find maximum number of orders in any route
    N = maximum([length(route.order_ids) for route in solution.routes]; init=0)
    @assert N > 0 "Solution has no routes to write."

    open(filepath, "w") do io
        # Write header
        print(io, "family")
        for i in 1:N
            print(io, ",order_$i")
        end
        println(io)

        # Write routes
        for route in solution.routes
            print(io, route.family)
            for i in 1:N
                if i <= length(route.order_ids)
                    print(io, ",", route.order_ids[i])
                else
                    print(io, ",")
                end
            end
            println(io)
        end
    end
end

function read_solution(filepath::String)
    df = CSV.read(filepath, DataFrame)
    routes = Vector{Route}()

    for row in eachrow(df)
        # Handle both "family" (new spec) and "vehicle_id"/"family_id" (old files)
        if hasproperty(df, :family)
            family = row.family
        elseif hasproperty(df, :family_id)
            family = row.family_id
        elseif hasproperty(df, :vehicle_id)
            family = row.vehicle_id
        else
            error("Solution CSV must have 'family', 'family_id', or 'vehicle_id' column")
        end

        # Collect order IDs from order_* columns in the correct order
        order_ids = Int[]
        # Find all order columns and sort them by number
        order_cols = filter(col -> startswith(string(col), "order_"), names(df))
        order_nums = [(col, parse(Int, string(col)[7:end])) for col in order_cols]
        sort!(order_nums; by=x -> x[2])

        for (col, _) in order_nums
            val = row[col]
            if !ismissing(val)
                push!(order_ids, Int(val))
            end
        end

        push!(routes, Route(family, order_ids))
    end

    return Solution(routes)
end

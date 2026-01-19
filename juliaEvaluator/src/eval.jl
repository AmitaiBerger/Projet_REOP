function compute_travel_time(
    location_1_index, location_2_index, vehicle_index, t, instance::Instance
)
    δ = instance.manhattan_distances[location_1_index + 1, location_2_index + 1]
    v = instance.vehicles[vehicle_index]
    τ = δ / v.speed
    γ = sum(
        v.fourier_cos[n + 1] * cos(n * ω * t) + v.fourier_sin[n + 1] * sin(n * ω * t) for
        n in 0:3
    )
    return τ * γ
end

function is_feasible(solution::Solution, instance::Instance)
    nb_visits = zeros(Int, length(instance.orders))

    for route in solution.routes
        (; family, order_ids) = route
        time = 0.0
        current_order_id = instance.depot.id # = 0
        for id in order_ids
            nb_visits[id] += 1
            travel_time = compute_travel_time(
                current_order_id, id, family, time, instance
            )
            time += travel_time
            order = instance.orders[id]
            if time < order.window_start
                time = order.window_start
            end
            tolerance = 1e-5  # Small tolerance to avoid numerical issues
            if time > order.window_end + tolerance
                @warn "Route is infeasible due to time window violation at order $id (arrival time: $time, window end: $(order.window_end), travel time: $travel_time)"
                return false
            end
            time += order.delivery_duration
            current_order_id = id
        end

        total_weight = sum(instance.orders[cust_id].weight for cust_id in order_ids)
        vehicle = instance.vehicles[family]
        if total_weight > vehicle.max_capacity
            @warn "Route is infeasible due to capacity violation (total weight: $total_weight, max capacity: $(vehicle.max_capacity))"
            return false
        end
    end

    if any(nb_visits .!= 1)
        @warn "Solution is infeasible because some orders are either not visited or visited more than once"
        return false
    end

    return true
end

function rental_cost(solution::Solution, instance::Instance)
    total_rental_cost = 0.0
    for route in solution.routes
        vehicle = instance.vehicles[route.family]
        total_rental_cost += vehicle.rental_cost
    end
    return total_rental_cost
end

function fuel_cost(solution::Solution, instance::Instance)
    total_fuel_cost = 0
    for route in solution.routes
        vehicle = instance.vehicles[route.family]
        route_distance = 0
        previous_order_id = instance.depot.id # = 0
        for id in route.order_ids
            route_distance += instance.manhattan_distances[previous_order_id + 1, id + 1]
            previous_order_id = id
        end
        route_distance += instance.manhattan_distances[
            previous_order_id + 1, instance.depot.id + 1
        ]
        total_fuel_cost += route_distance * vehicle.fuel_cost
    end
    return total_fuel_cost
end

function radius_cost(solution::Solution, instance::Instance)
    total_radius_cost = 0
    for route in solution.routes
        vehicle = instance.vehicles[route.family]
        route_diameter = 0
        for id in route.order_ids
            for id2 in route.order_ids
                if id == id2
                    continue
                end
                route_diameter = max(
                    route_diameter, instance.euclidean_distances[id + 1, id2 + 1]
                )
            end
        end
        total_radius_cost += route_diameter * vehicle.radius_cost / 2
    end
    return total_radius_cost
end

function cost(solution::Solution, instance::Instance)
    return rental_cost(solution, instance) +
           fuel_cost(solution, instance) +
           radius_cost(solution, instance)
end

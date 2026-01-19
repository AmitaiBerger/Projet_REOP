using Pkg
Pkg.activate(".")
using KIRO2025
using Plots: Plots
using PlotlyJS: PlotlyJS
using PyCall

# Initialize Python folium library for maps with OpenStreetMap tiles
const folium = PyCall.pyimport_conda("folium", "folium")

# Helper function to create hover text with delivery details
function create_hover_text(order_id::Int, instance::Instance)
    order = instance.orders[order_id]
    return "Order $order_id<br>" *
           "Weight: $(round(order.weight, digits=1)) kg<br>" *
           "Window: $(round(order.window_start/3600, digits=1))-$(round(order.window_end/3600, digits=1))h<br>" *
           "Duration: $(round(order.delivery_duration/60, digits=1)) min"
end

"""
    visualize_routes_on_map(solution::Solution, instance::Instance, title::String)

Create an interactive map with REAL OpenStreetMap tiles showing Paris streets.
Uses Python's folium library to generate HTML with zoom, pan, and street-level details.
"""
function visualize_routes_on_map(solution::Solution, instance::Instance, title::String)
    # Get depot coordinates
    depot = instance.depot
    depot_lat = depot.latitude
    depot_lon = depot.longitude

    # Calculate center of all locations for map centering
    all_lats = [depot_lat]
    all_lons = [depot_lon]

    for route in solution.routes
        for order_id in route.order_ids
            order = instance.orders[order_id]
            push!(all_lats, order.latitude)
            push!(all_lons, order.longitude)
        end
    end

    center_lat = sum(all_lats) / length(all_lats)
    center_lon = sum(all_lons) / length(all_lons)

    # Create folium map centered on Paris with OpenStreetMap tiles
    m = folium.Map(;
        location=[center_lat, center_lon],
        zoom_start=12,
        tiles="OpenStreetMap",  # Real street map!
        control_scale=true,
    )

    # Add depot marker (red star)
    folium.Marker(
        [depot_lat, depot_lon];
        popup="<b>DEPOT</b><br>Starting point",
        tooltip="Depot",
        icon=folium.Icon(; color="red", icon="star", prefix="fa"),
    ).add_to(
        m
    )

    # Define route colors
    route_colors = [
        "blue",
        "green",
        "purple",
        "orange",
        "darkred",
        "lightred",
        "beige",
        "darkblue",
        "darkgreen",
        "cadetblue",
    ]

    # Plot each route
    for (route_idx, route) in enumerate(solution.routes)
        if isempty(route.order_ids)
            continue
        end

        color = route_colors[(route_idx - 1) % length(route_colors) + 1]

        # Collect coordinates for this route
        route_coords = [[depot_lat, depot_lon]]

        for order_id in route.order_ids
            order = instance.orders[order_id]
            push!(route_coords, [order.latitude, order.longitude])

            # Add marker for each order
            popup_text =
                "<b>Order $order_id</b><br>" *
                "Route $route_idx (Vehicle $(route.family))<br>" *
                "Weight: $(round(order.weight, digits=1)) kg<br>" *
                "Window: $(round(order.window_start/3600, digits=1))h - $(round(order.window_end/3600, digits=1))h<br>" *
                "Service: $(round(order.delivery_duration/60, digits=1)) min"

            folium.CircleMarker(
                [order.latitude, order.longitude];
                radius=6,
                popup=popup_text,
                tooltip="Order $order_id",
                color=color,
                fill=true,
                fillColor=color,
                fillOpacity=0.7,
            ).add_to(
                m
            )
        end

        # Return to depot
        push!(route_coords, [depot_lat, depot_lon])

        # Draw route line on map
        folium.PolyLine(
            route_coords;
            color=color,
            weight=3,
            opacity=0.7,
            popup="Route $route_idx (Vehicle $(route.family))",
        ).add_to(
            m
        )
    end

    # Add title as text overlay
    title_html = """
    <div style="position: fixed; 
                top: 10px; 
                left: 50px; 
                width: auto;
                height: auto;
                background-color: white;
                border: 2px solid grey;
                border-radius: 5px;
                padding: 10px;
                font-size: 14px;
                font-weight: bold;
                z-index: 9999;">
        $title
    </div>
    """
    m.get_root().html.add_child(folium.Element(title_html))

    # Add layer control for toggling routes
    folium.LayerControl().add_to(m)

    return m
end

# Helper function to create hover text with delivery details (simplified version for static plots)
function create_hover_text(order_id::Int, instance::Instance)
    order = instance.orders[order_id]
    return "Order $order_id<br>" *
           "Weight: $(round(order.weight, digits=1)) kg<br>" *
           "Window: $(round(order.window_start/3600, digits=1))-$(round(order.window_end/3600, digits=1))h<br>" *
           "Duration: $(round(order.delivery_duration/60, digits=1)) min"
end

"""
    visualize_routes_interactive(solution::Solution, instance::Instance, title::String)

Create an INTERACTIVE map visualization with zoom/pan capabilities using Plots.plotlyjs backend.
"""
function visualize_routes_interactive(solution::Solution, instance::Instance, title::String)
    # Switch to plotlyjs backend for interactivity
    Plots.plotlyjs()

    # Get depot coordinates
    depot = instance.depot
    depot_lat = depot.latitude
    depot_lon = depot.longitude

    # Create plot
    p = Plots.plot(;
        xlabel="Longitude",
        ylabel="Latitude",
        title=title,
        legend=:outertopright,
        size=(1200, 900),
    )

    # Plot depot
    Plots.scatter!(
        p,
        [depot_lon],
        [depot_lat];
        marker=:star,
        markersize=15,
        color=:red,
        label="Depot",
        markerstrokewidth=2,
    )

    # Get colors for different routes
    n_routes = length(solution.routes)
    colors = Plots.palette(:tab10, n_routes)

    # Plot each route
    for (route_idx, route) in enumerate(solution.routes)
        if isempty(route.order_ids)
            continue
        end

        # Get route coordinates
        lats = Float64[]
        lons = Float64[]

        # Start from depot
        push!(lats, depot_lat)
        push!(lons, depot_lon)

        # Add order locations
        for order_id in route.order_ids
            order = instance.orders[order_id]
            push!(lats, order.latitude)
            push!(lons, order.longitude)
        end

        # Return to depot
        push!(lats, depot_lat)
        push!(lons, depot_lon)

        # Plot route line
        Plots.plot!(
            p,
            lons,
            lats;
            linewidth=2,
            color=colors[route_idx],
            alpha=0.6,
            label="Route $(route_idx) (Vehicle $(route.family))",
        )

        # Plot order points
        Plots.scatter!(
            p,
            lons[2:(end - 1)],
            lats[2:(end - 1)];
            marker=:circle,
            markersize=6,
            color=colors[route_idx],
            label="",
            markerstrokewidth=0,
        )
    end

    # Switch back to GR backend for other plots
    Plots.gr()

    return p
end

"""
    visualize_routes(solution::Solution, instance::Instance, title::String)

Create a map visualization of routes based on GPS coordinates (static version).
"""
function visualize_routes(solution::Solution, instance::Instance, title::String)
    # Get depot coordinates
    depot = instance.depot
    depot_lat = depot.latitude
    depot_lon = depot.longitude

    # Create plot
    p = Plots.Plots.plot(;
        xlabel="Longitude",
        ylabel="Latitude",
        title=title,
        legend=:outertopright,
        size=(1000, 800),
        dpi=150,
    )

    # Plot depot
    Plots.Plots.scatter!(
        p,
        [depot_lon],
        [depot_lat];
        marker=:star,
        markersize=15,
        color=:red,
        label="Depot",
        markerstrokewidth=2,
    )

    # Get colors for different routes
    n_routes = length(solution.routes)
    colors = Plots.Plots.palette(:tab10, n_routes)

    # Plot each route
    for (route_idx, route) in enumerate(solution.routes)
        if isempty(route.order_ids)
            continue
        end

        # Get route coordinates
        lats = Float64[]
        lons = Float64[]

        # Start from depot
        push!(lats, depot_lat)
        push!(lons, depot_lon)

        # Add order locations
        for order_id in route.order_ids
            order = instance.orders[order_id]  # order_id is 1-indexed into orders array
            push!(lats, order.latitude)
            push!(lons, order.longitude)
        end

        # Return to depot
        push!(lats, depot_lat)
        push!(lons, depot_lon)

        # Plot route line
        Plots.Plots.plot!(
            p,
            lons,
            lats;
            linewidth=2,
            color=colors[route_idx],
            alpha=0.6,
            label="Route $(route_idx) (Vehicle $(route.family))",
        )

        # Plot order points
        Plots.Plots.scatter!(
            p,
            lons[2:(end - 1)],
            lats[2:(end - 1)];
            marker=:circle,
            markersize=6,
            color=colors[route_idx],
            label="",
            markerstrokewidth=0,
        )
    end

    return p
end

"""
    visualize_time_windows(solution::Solution, instance::Instance, title::String)

Create a Gantt chart showing delivery times vs time windows.
"""
function visualize_time_windows(solution::Solution, instance::Instance, title::String)
    # Calculate arrival times for all deliveries
    deliveries = []

    for (route_idx, route) in enumerate(solution.routes)
        if isempty(route.order_ids)
            continue
        end

        vehicle = instance.vehicles[route.family]
        current_time = 0.0
        current_order_id = instance.depot.id  # = 0

        for order_id in route.order_ids
            order = instance.orders[order_id]

            # Calculate travel time using the correct function signature
            travel_time = KIRO2025.compute_travel_time(
                current_order_id, order_id, route.family, current_time, instance
            )

            arrival_time = current_time + travel_time

            # Apply waiting time if arrival is before time window
            service_start_time = arrival_time
            waiting_time = 0.0
            if arrival_time < order.window_start
                service_start_time = order.window_start
                waiting_time = order.window_start - arrival_time
            end

            departure_time = service_start_time + order.delivery_duration

            push!(
                deliveries,
                (
                    route_idx=route_idx,
                    order_id=order_id,
                    arrival=arrival_time,
                    service_start=service_start_time,
                    waiting=waiting_time,
                    departure=departure_time,
                    tw_start=order.window_start,
                    tw_end=order.window_end,
                    vehicle_id=route.family,
                ),
            )

            current_time = departure_time
            current_order_id = order_id
        end
    end

    # Sort by arrival time
    sort!(deliveries; by=x -> x.arrival)

    # Create Gantt chart
    p = Plots.plot(;
        xlabel="Time (seconds)",
        ylabel="Delivery #",
        title=title,
        legend=:outerright,
        size=(1200, 600),
        dpi=150,
    )

    colors = Plots.palette(:tab10, length(solution.routes))

    for (i, del) in enumerate(deliveries)
        # Plot time window as a gray bar
        Plots.plot!(
            p,
            [del.tw_start, del.tw_end],
            [i, i];
            linewidth=8,
            color=:lightgray,
            alpha=0.5,
            label=i == 1 ? "Time Window" : "",
        )

        # Plot arrival time
        Plots.scatter!(
            p,
            [del.arrival],
            [i];
            marker=:circle,
            markersize=6,
            color=colors[del.route_idx],
            label=i == 1 ? "Arrival" : "",
            markerstrokewidth=0,
        )

        # Plot waiting time (if any) in orange/yellow
        if del.waiting > 0
            Plots.plot!(
                p,
                [del.arrival, del.service_start],
                [i, i];
                linewidth=3,
                color=:orange,
                alpha=0.7,
                linestyle=:dash,
                label=i == 1 ? "Waiting" : "",
            )
        end

        # Plot service start time marker
        if del.waiting > 0
            Plots.scatter!(
                p,
                [del.service_start],
                [i];
                marker=:diamond,
                markersize=5,
                color=colors[del.route_idx],
                label=i == 1 ? "Service Start" : "",
                markerstrokewidth=0,
            )
        end

        # Plot delivery/service duration
        Plots.plot!(
            p,
            [del.service_start, del.departure],
            [i, i];
            linewidth=3,
            color=colors[del.route_idx],
            label=i == 1 ? "Service" : "",
        )
    end

    return p
end

"""
    visualize_truck_loads(solution::Solution, instance::Instance, title::String)

Create a visualization showing truck capacity utilization over time.
"""
function visualize_truck_loads(solution::Solution, instance::Instance, title::String)
    p = Plots.plot(;
        xlabel="Delivery Sequence",
        ylabel="Load (kg)",
        title=title,
        legend=:outertopright,
        size=(1000, 600),
        dpi=150,
    )

    colors = Plots.palette(:tab10, length(solution.routes))

    for (route_idx, route) in enumerate(solution.routes)
        if isempty(route.order_ids)
            continue
        end

        vehicle = instance.vehicles[route.family]
        loads = Float64[]
        positions = Int[]

        current_load = 0.0

        for (pos, order_id) in enumerate(route.order_ids)
            order = instance.orders[order_id]
            current_load += order.weight
            push!(loads, current_load)
            push!(positions, pos)
        end

        # Plot load over sequence
        Plots.plot!(
            p,
            positions,
            loads;
            linewidth=2,
            marker=:circle,
            markersize=5,
            color=colors[route_idx],
            label="Route $(route_idx) (Vehicle $(route.family))",
            markerstrokewidth=0,
        )

        # Plot capacity line
        Plots.plot!(
            p,
            [0, length(route.order_ids) + 1],
            [vehicle.max_capacity, vehicle.max_capacity];
            linestyle=:dash,
            linewidth=1,
            color=colors[route_idx],
            alpha=0.5,
            label="",
        )
    end

    return p
end

"""
    visualize_time_windows_per_vehicle(solution::Solution, instance::Instance, title::String)

Create separate Gantt charts for each vehicle showing delivery times vs time windows.
One subplot per vehicle for better readability.
"""
function visualize_time_windows_per_vehicle(
    solution::Solution, instance::Instance, title::String
)
    # Calculate arrival times for all deliveries organized by route
    route_deliveries = Dict{Int,Vector}()

    for (route_idx, route) in enumerate(solution.routes)
        if isempty(route.order_ids)
            continue
        end

        deliveries = []
        vehicle = instance.vehicles[route.family]
        current_time = 0.0
        current_order_id = instance.depot.id  # = 0

        for order_id in route.order_ids
            order = instance.orders[order_id]

            # Calculate travel time
            travel_time = KIRO2025.compute_travel_time(
                current_order_id, order_id, route.family, current_time, instance
            )

            arrival_time = current_time + travel_time

            # Apply waiting time if arrival is before time window
            service_start_time = arrival_time
            waiting_time = 0.0
            if arrival_time < order.window_start
                service_start_time = order.window_start
                waiting_time = order.window_start - arrival_time
            end

            departure_time = service_start_time + order.delivery_duration

            push!(
                deliveries,
                (
                    order_id=order_id,
                    arrival=arrival_time,
                    service_start=service_start_time,
                    waiting=waiting_time,
                    departure=departure_time,
                    tw_start=order.window_start,
                    tw_end=order.window_end,
                ),
            )

            current_time = departure_time
            current_order_id = order_id
        end

        route_deliveries[route_idx] = deliveries
    end

    # Create subplots - one per vehicle
    n_routes = length(route_deliveries)
    plots = []

    for (route_idx, deliveries) in sort(collect(route_deliveries); by=x -> x[1])
        route = solution.routes[route_idx]
        vehicle_id = route.family

        p = Plots.plot(;
            xlabel="Time (seconds)",
            ylabel="Delivery #",
            title="Vehicle $vehicle_id (Route $route_idx) - $(length(deliveries)) deliveries",
            legend=:outerright,
            size=(1000, 200 + length(deliveries) * 20),
            dpi=150,
        )

        for (i, del) in enumerate(deliveries)
            # Plot time window as a gray bar
            Plots.plot!(
                p,
                [del.tw_start, del.tw_end],
                [i, i];
                linewidth=8,
                color=:lightgray,
                alpha=0.5,
                label=i == 1 ? "Time Window" : "",
            )

            # Plot arrival time
            Plots.scatter!(
                p,
                [del.arrival],
                [i];
                marker=:circle,
                markersize=6,
                color=:blue,
                label=i == 1 ? "Arrival" : "",
                markerstrokewidth=0,
            )

            # Plot waiting time (if any)
            if del.waiting > 0
                Plots.plot!(
                    p,
                    [del.arrival, del.service_start],
                    [i, i];
                    linewidth=3,
                    color=:orange,
                    alpha=0.7,
                    linestyle=:dash,
                    label=i == 1 ? "Waiting" : "",
                )
            end

            # Plot service start time marker
            if del.waiting > 0
                Plots.scatter!(
                    p,
                    [del.service_start],
                    [i];
                    marker=:diamond,
                    markersize=5,
                    color=:green,
                    label=i == 1 ? "Service Start" : "",
                    markerstrokewidth=0,
                )
            end

            # Plot delivery/service duration
            Plots.plot!(
                p,
                [del.service_start, del.departure],
                [i, i];
                linewidth=3,
                color=:darkblue,
                label=i == 1 ? "Service" : "",
            )
        end

        push!(plots, p)
    end

    # Combine all subplots vertically
    return Plots.plot(plots...; layout=(n_routes, 1), size=(1000, 300 * n_routes))
end

"""
    visualize_truck_loads_per_vehicle(solution::Solution, instance::Instance, title::String)

Create separate load progression charts for each vehicle.
One subplot per vehicle for better capacity tracking.
"""
function visualize_truck_loads_per_vehicle(
    solution::Solution, instance::Instance, title::String
)
    plots = []
    n_routes = length([r for r in solution.routes if !isempty(r.order_ids)])

    for (route_idx, route) in enumerate(solution.routes)
        if isempty(route.order_ids)
            continue
        end

        vehicle = instance.vehicles[route.family]
        loads = Float64[0.0]  # Start from 0
        positions = Int[0]     # Start from depot

        current_load = 0.0

        for (pos, order_id) in enumerate(route.order_ids)
            order = instance.orders[order_id]
            current_load += order.weight
            push!(loads, current_load)
            push!(positions, pos)
        end

        # Create subplot for this vehicle
        p = Plots.plot(;
            xlabel="Delivery Sequence",
            ylabel="Load (kg)",
            title="Vehicle $(route.family) (Route $route_idx) - Max: $(vehicle.max_capacity) kg",
            legend=:bottomright,
            size=(1000, 300),
            dpi=150,
        )

        # Plot load progression
        Plots.plot!(
            p,
            positions,
            loads;
            linewidth=2,
            marker=:circle,
            markersize=6,
            color=:blue,
            label="Current Load",
            markerstrokewidth=0,
            fill=(0, 0.1, :blue),
        )

        # Plot capacity line
        Plots.plot!(
            p,
            [0, length(route.order_ids)],
            [vehicle.max_capacity, vehicle.max_capacity];
            linestyle=:dash,
            linewidth=2,
            color=:red,
            label="Max Capacity",
        )

        # Add capacity percentage text
        max_load = maximum(loads)
        pct = round(max_load / vehicle.max_capacity * 100; digits=1)
        Plots.annotate!(
            p,
            length(route.order_ids) / 2,
            vehicle.max_capacity * 0.9,
            Plots.text("Peak: $(round(max_load, digits=1)) kg ($(pct)%)", 10, :center),
        )

        push!(plots, p)
    end

    # Combine all subplots vertically
    return Plots.plot(plots...; layout=(n_routes, 1), size=(1000, 300 * n_routes))
end

"""
    visualize_solution(instance_num::Int, solution_name::String; use_interactive=false, per_vehicle=true, use_real_map=true)

Create all visualizations for a given instance and solution.
- use_interactive: If true, create interactive PlotlyJS maps with zoom
- per_vehicle: If true, create separate subplots per vehicle for time windows and loads
- use_real_map: If true, create interactive map with real OpenStreetMap tiles (Paris streets)
"""
function visualize_solution(
    instance_num::Int,
    solution_name::String;
    use_interactive=false,
    per_vehicle=true,
    use_real_map=true,
)
    # Load instance and solution
    instance_dir = "data/v3-ponts/instances"
    solution_dir = "data/v3-ponts/solutions"
    vehicle_file = joinpath(instance_dir, "vehicles.csv")

    instance_file = joinpath(instance_dir, "instance_$(lpad(instance_num, 2, '0')).csv")
    solution_file = joinpath(
        solution_dir, "$(solution_name)_solution_$(lpad(instance_num, 2, '0')).csv"
    )

    println("Loading instance $(instance_num)...")
    instance = read_instance(instance_file, vehicle_file)
    solution = read_solution(solution_file)

    # Check feasibility and compute cost
    feasible = is_feasible(solution, instance)
    solution_cost = cost(solution, instance)

    println("Solution: $(solution_name)")
    println("  Feasible: $(feasible)")
    println("  Cost: $(round(solution_cost, digits=2))")
    println("  Routes: $(length(solution.routes))")

    # Create visualizations
    title_prefix = "Instance $(instance_num) - $(uppercase(solution_name))"

    # Create route map (with real OpenStreetMap, interactive PlotlyJS, or static)
    if use_real_map
        println("\nCreating route map with real Paris streets (OpenStreetMap)...")
        p1 = visualize_routes_on_map(solution, instance, "$(title_prefix) - Route Map")
    elseif use_interactive
        println("\nCreating route map (interactive)...")
        p1 = visualize_routes_interactive(solution, instance, "$(title_prefix) - Route Map")
    else
        println("\nCreating route map...")
        p1 = visualize_routes(solution, instance, "$(title_prefix) - Route Map")
    end

    # Create time window chart (per-vehicle or combined)
    println("Creating time window chart$(per_vehicle ? " (per vehicle)" : "")...")
    if per_vehicle
        p2 = visualize_time_windows_per_vehicle(
            solution, instance, "$(title_prefix) - Delivery Times"
        )
    else
        p2 = visualize_time_windows(solution, instance, "$(title_prefix) - Delivery Times")
    end

    # Create truck load chart (per-vehicle or combined)
    println("Creating truck load chart$(per_vehicle ? " (per vehicle)" : "")...")
    if per_vehicle
        p3 = visualize_truck_loads_per_vehicle(
            solution, instance, "$(title_prefix) - Truck Loads"
        )
    else
        p3 = visualize_truck_loads(solution, instance, "$(title_prefix) - Truck Loads")
    end

    # Save plots
    output_dir = "visualizations"
    mkpath(output_dir)

    suffix = per_vehicle ? "_pervehicle" : ""

    if use_real_map
        # Save folium map as HTML
        map_file = joinpath(
            output_dir,
            "instance_$(lpad(instance_num, 2, '0'))_$(solution_name)_routes_map.html",
        )
        p1.save(map_file)
        println("Real map saved to: $map_file")
    elseif use_interactive
        # Save interactive plot as HTML
        Plots.savefig(
            p1,
            joinpath(
                output_dir,
                "instance_$(lpad(instance_num, 2, '0'))_$(solution_name)_routes_interactive.html",
            ),
        )
    else
        Plots.savefig(
            p1,
            joinpath(
                output_dir,
                "instance_$(lpad(instance_num, 2, '0'))_$(solution_name)_routes$(suffix).png",
            ),
        )
    end

    Plots.savefig(
        p2,
        joinpath(
            output_dir,
            "instance_$(lpad(instance_num, 2, '0'))_$(solution_name)_timewindows$(suffix).png",
        ),
    )
    Plots.savefig(
        p3,
        joinpath(
            output_dir,
            "instance_$(lpad(instance_num, 2, '0'))_$(solution_name)_loads$(suffix).png",
        ),
    )

    println("Visualizations saved to $(output_dir)/")

    return p1, p2, p3
end

"""
    compare_solutions(instance_num::Int, solution_names::Vector{String})

Create side-by-side comparison of multiple solutions for the same instance.
"""
function compare_solutions(instance_num::Int, solution_names::Vector{String})
    # Load instance
    instance_dir = "data/v3-ponts/instances"
    solution_dir = "data/v3-ponts/solutions"
    vehicle_file = joinpath(instance_dir, "vehicles.csv")

    instance_file = joinpath(instance_dir, "instance_$(lpad(instance_num, 2, '0')).csv")
    instance = read_instance(instance_file, vehicle_file)

    # Create comparison plots
    plots_list = []

    for solution_name in solution_names
        solution_file = joinpath(
            solution_dir, "$(solution_name)_solution_$(lpad(instance_num, 2, '0')).csv"
        )
        solution = read_solution(solution_file)

        feasible = is_feasible(solution, instance)
        solution_cost = cost(solution, instance)

        title = "$(uppercase(solution_name))\nCost: $(round(solution_cost, digits=2))"
        if !feasible
            title *= "\n⚠ INFEASIBLE"
        end

        p = visualize_routes(solution, instance, title)
        push!(plots_list, p)
    end

    # Combine plots
    n_plots = length(plots_list)
    layout = (1, n_plots)
    p_combined = Plots.plot(
        plots_list...; layout=layout, size=(400 * n_plots, 400), dpi=150
    )

    # Save comparison
    output_dir = "visualizations"
    mkpath(output_dir)
    Plots.savefig(
        p_combined,
        joinpath(output_dir, "instance_$(lpad(instance_num, 2, '0'))_comparison.png"),
    )

    println("Comparison saved to $(output_dir)/")

    return p_combined
end

# Example usage:
println("="^60)
println("KIRO 2025 - Solution Visualization")
println("="^60)
println()
println("Available functions:")
println(
    "  visualize_solution(instance_num, solution_name; use_interactive=false, per_vehicle=true, use_real_map=true)",
)
println("    - Create all visualizations for a specific solution")
println("    - use_interactive: Enable interactive zoom on route maps (saves HTML)")
println("    - per_vehicle: Create separate plots per vehicle for time windows and loads")
println("    - use_real_map: Use real OpenStreetMap tiles showing Paris streets (HTML)")
println("    - Example: visualize_solution(1, \"lns\", use_real_map=true)")
println()
println("  compare_solutions(instance_num, [\"greedy\", \"local_search\", \"lns\"])")
println("    - Compare multiple solutions side-by-side")
println("    - Example: compare_solutions(2, [\"greedy\", \"local_search\", \"lns\"])")
println()
println("Visualizing Instance 10 with LNS solution...")
println("Creating map with REAL Paris streets from OpenStreetMap!")
println()

# Visualize instance 10 with LNS solution with REAL map background
visualize_solution(10, "lns"; use_interactive=false, per_vehicle=true, use_real_map=true)

println("\n" * "="^60)
println("Creating comparison plot for Instance 10...")
println("="^60)

# Compare greedy, local search, and LNS for instance 10
compare_solutions(10, ["greedy", "local_search", "lns"])

println("\nDone! Check the 'visualizations/' directory for output files.")
println("  - *_pervehicle.png: Separate charts per vehicle")
println("  - *_routes_map.html: Interactive map with REAL Paris streets (open in browser!)")
println()
println("🗺️  The route map now shows:")
println("  ✓ Real Paris streets from OpenStreetMap")
println("  ✓ Zoom and pan to explore delivery locations")
println("  ✓ Click on markers for delivery details")
println("  ✓ Street names and landmarks visible")

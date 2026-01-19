struct Vehicle
    family::Int
    max_capacity::Int
    rental_cost::Int
    fuel_cost::Float64
    radius_cost::Float64
    speed::Float64
    parking_time::Int
    fourier_cos::Vector{Float64}
    fourier_sin::Vector{Float64}
end

struct Order
    id::Int
    longitude::Float64
    latitude::Float64
    weight::Float64
    window_start::Int
    window_end::Int
    delivery_duration::Int
end

function euclidean_distance(o1::Order, o2::Order)
    Δ_longitude = o1.longitude - o2.longitude
    Δ_latitude = o1.latitude - o2.latitude
    Δ_y = ρ * deg2rad(Δ_latitude)
    Δ_x = ρ * cos(deg2rad(DEPOT.latitude)) * deg2rad(Δ_longitude)
    return sqrt(Δ_x^2 + Δ_y^2)
end

function manhattan_distance(o1::Order, o2::Order)
    Δ_longitude = o1.longitude - o2.longitude
    Δ_latitude = o1.latitude - o2.latitude
    Δ_y = ρ * deg2rad(Δ_latitude)
    Δ_x = ρ * cos(deg2rad(DEPOT.latitude)) * deg2rad(Δ_longitude)
    return abs(Δ_x) + abs(Δ_y)
end

struct Instance
    vehicles::Vector{Vehicle}
    depot::Order
    orders::Vector{Order}
    euclidean_distances::Matrix{Float64}
    manhattan_distances::Matrix{Float64}
end

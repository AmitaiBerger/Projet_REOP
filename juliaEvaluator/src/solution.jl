struct Route
    family::Int
    order_ids::Vector{Int}
end

struct Solution
    routes::Vector{Route}
end

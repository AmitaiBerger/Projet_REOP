"""
    bad_heuristic(instance::Instance) -> Solution

One vehicle per order, of type maximum capacity.
"""
function bad_heuristic(instance::Instance)
    best_vehicle = argmax(v -> v.max_capacity, instance.vehicles).family
    routes = [Route(best_vehicle, [order.id]) for order in instance.orders]
    return Solution(routes)
end

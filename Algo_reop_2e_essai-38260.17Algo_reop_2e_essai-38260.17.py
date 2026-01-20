import csv
import math
import random
from copy import deepcopy

# =========================
# CONSTANTS
# =========================

R_EARTH = 6.371e6
DAY = 86400
OMEGA = 2 * math.pi / DAY

N_RESTARTS = 5   # cheap and effective

# =========================
# DATA READING
# =========================

def read_vehicles(file_path):
    vehicles = []
    with open(file_path, newline='') as f:
        reader = csv.DictReader(f)
        for row in reader:
            vehicles.append({
                'family': int(row['family']),
                'capacity': float(row['max_capacity']),
                'rental_cost': float(row['rental_cost']),
                'fuel_cost': float(row['fuel_cost']),
                'radius_cost': float(row['radius_cost']),
                'speed': float(row['speed']),
                'parking_time': float(row['parking_time']),
                'alpha': [float(row[f'fourier_cos_{i}']) for i in range(4)],
                'beta': [float(row[f'fourier_sin_{i}']) for i in range(4)]
            })
    return vehicles


def read_instance(file_path):
    orders = []
    depot = None
    with open(file_path, newline='') as f:
        reader = csv.DictReader(f)
        for row in reader:
            if row['order_weight'] == '':
                depot = {
                    'id': int(row['id']),
                    'coord': (float(row['latitude']), float(row['longitude']))
                }
            else:
                orders.append({
                    'id': int(row['id']),
                    'coord': (float(row['latitude']), float(row['longitude'])),
                    'weight': float(row['order_weight']),
                    'tmin': float(row['window_start']),
                    'tmax': float(row['window_end']),
                    'service': float(row['delivery_duration'])
                })
    return depot, orders

# =========================
# GEOGRAPHY
# =========================

def geo_to_meters(coord, phi0):
    lat, lon = coord
    x = R_EARTH * math.cos(math.radians(phi0)) * math.radians(lon)
    y = R_EARTH * math.radians(lat)
    return (x, y)


def manhattan(a, b):
    return abs(a[0] - b[0]) + abs(a[1] - b[1])


def euclidean(a, b):
    return math.sqrt((a[0] - b[0])**2 + (a[1] - b[1])**2)

# =========================
# TRAVEL TIME
# =========================

def gamma(vehicle, t):
    g = 0
    for n in range(4):
        g += (vehicle['alpha'][n] * math.cos(n * OMEGA * t)
              + vehicle['beta'][n] * math.sin(n * OMEGA * t))
    return max(g, 0.1)


def travel_time(vehicle, i, j, t):
    d = manhattan(i['coord'], j['coord'])
    tau_ref = d / vehicle['speed'] + vehicle['parking_time'] / 2
    return tau_ref * gamma(vehicle, t)

# =========================
# FEASIBILITY
# =========================

def feasible_route(route, vehicle, depot):
    t = 0
    prev = depot
    for o in route:
        t += travel_time(vehicle, prev, o, t)
        t = max(t, o['tmin'])
        if t > o['tmax']:
            return False
        t += o['service']
        prev = o
    return True

# =========================
# COSTS
# =========================

def route_cost(route, vehicle, depot):
    cost = vehicle['rental_cost']

    dist = manhattan(depot['coord'], route[0]['coord'])
    for i in range(len(route) - 1):
        dist += manhattan(route[i]['coord'], route[i+1]['coord'])
    dist += manhattan(route[-1]['coord'], depot['coord'])

    cost += dist * vehicle['fuel_cost']

    max_r2 = 0
    for i in range(len(route)):
        for j in range(i+1, len(route)):
            r2 = euclidean(route[i]['coord'], route[j]['coord'])**2
            max_r2 = max(max_r2, r2)

    cost += max_r2 * vehicle['radius_cost']
    return cost


def best_vehicle(route, vehicles, depot):
    best_v = None
    best_c = float("inf")
    load = sum(o['weight'] for o in route)

    for v in vehicles:
        if load <= v['capacity'] and feasible_route(route, v, depot):
            c = route_cost(route, v, depot)
            if c < best_c:
                best_c = c
                best_v = v

    return best_v, best_c

# =========================
# GREEDY CONSTRUCTION (Δ-cost)
# =========================

def build_routes(orders, vehicles, depot):
    remaining = orders[:]
    routes = []

    # Priority by urgency, with small randomness
    remaining.sort(key=lambda o: (o['tmax'], random.random()))

    while remaining:
        # Start route with most urgent order
        route = [remaining.pop(0)]
        v_cur, c_cur = best_vehicle(route, vehicles, depot)

        improved = True
        while improved:
            improved = False
            best_delta = float("inf")
            best_o = None
            best_pos = None
            best_v = None
            best_c = None

            for o in remaining:
                # Try insertion at every position
                for pos in range(len(route) + 1):
                    test_route = route[:pos] + [o] + route[pos:]
                    v, c = best_vehicle(test_route, vehicles, depot)
                    if v is not None:
                        delta = c - c_cur
                        if delta < best_delta:
                            best_delta = delta
                            best_o = o
                            best_pos = pos
                            best_v = v
                            best_c = c

            if best_o is not None:
                route.insert(best_pos, best_o)
                remaining.remove(best_o)
                v_cur = best_v
                c_cur = best_c
                improved = True

        routes.append({'orders': route, 'vehicle': v_cur})

    return routes


# =========================
# SOLUTION COST
# =========================

def solution_cost(routes, depot):
    return sum(route_cost(r['orders'], r['vehicle'], depot) for r in routes)

# =========================
# MULTI-START WRAPPER
# =========================

def solve_instance(orders, vehicles, depot):
    best_routes = None
    best_cost = float("inf")

    for _ in range(N_RESTARTS):
        random.shuffle(orders)
        routes = build_routes(orders, vehicles, depot)
        cost = solution_cost(routes, depot)

        if cost < best_cost:
            best_cost = cost
            best_routes = deepcopy(routes)

    return best_routes

# =========================
# EXPORT CSV
# =========================

def save_routes(routes, filename):
    N = max(len(r['orders']) for r in routes)
    header = ['family'] + [f'order_{i+1}' for i in range(N)]

    with open(filename, 'w', newline='') as f:
        writer = csv.writer(f)
        writer.writerow(header)
        for r in routes:
            row = [r['vehicle']['family']] + [o['id'] for o in r['orders']]
            row += [''] * (N - len(r['orders']))
            writer.writerow(row)

# =========================
# MAIN
# =========================

def creer_solution(solution_file, instance_file, vehicles):
    depot, orders = read_instance(instance_file)

    phi0 = depot['coord'][0]
    depot['coord'] = geo_to_meters(depot['coord'], phi0)
    for o in orders:
        o['coord'] = geo_to_meters(o['coord'], phi0)

    routes = solve_instance(orders, vehicles, depot)
    save_routes(routes, solution_file)


if __name__ == "__main__":
    Instance_File = "//home/ghislain-de-villeroche/Downloads/ProjetREOP2025-2026/juliaEvaluator/data-projet/instances/"
    Route_File = "//home/ghislain-de-villeroche/Downloads/ProjetREOP2025-2026/juliaEvaluator/data-projet/solutions/"

    vehicles = read_vehicles(Instance_File + "vehicles.csv")

    for i in range(1, 11):
        creer_solution(
            Route_File + f"solution_{i:02d}.csv",
            Instance_File + f"instance_{i:02d}.csv",
            vehicles
        )

    print("✔ Solutions generated")


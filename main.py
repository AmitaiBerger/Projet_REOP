import csv
import math
from copy import deepcopy
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent

# =========================
# CONSTANTES
# =========================

R_EARTH = 6.371e6
DAY = 86400
OMEGA = 2 * math.pi / DAY

# =========================
# LECTURE DES DONNÉES
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
# GÉOGRAPHIE
# =========================

def geo_to_meters(coord, phi0):
    lat, lon = coord
    x = R_EARTH * math.cos(math.radians(phi0)) * math.radians(lon)
    y = R_EARTH * math.radians(lat)
    return (x, y)

def manhattan(a, b):
    return abs(a[0]-b[0]) + abs(a[1]-b[1])

def euclidean(a, b):
    return math.sqrt((a[0]-b[0])**2 + (a[1]-b[1])**2)

# =========================
# TEMPS DE TRAJET
# =========================

def gamma(vehicle, t):
    g = 0
    for n in range(4):
        g += vehicle['alpha'][n]*math.cos(n*OMEGA*t) + vehicle['beta'][n]*math.sin(n*OMEGA*t)
    return max(g, 0.1)

def travel_time(vehicle, i, j, t):
    d = manhattan(i['coord'], j['coord'])
    tau_ref = d / vehicle['speed'] + vehicle['parking_time'] / 2
    return tau_ref * gamma(vehicle, t)

# =========================
# FAISABILITÉ TEMPORELLE
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
# COÛT D'UNE ROUTE
# =========================

def route_cost(route, vehicle, depot):
    if not route:
        return 0  # Route vide = coût 0
    cost = vehicle['rental_cost']
    dist = manhattan(depot['coord'], route[0]['coord'])
    for i in range(len(route)-1):
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

# =========================
# MEILLEUR VEHICULE POUR UNE ROUTE
# =========================

def best_vehicle(route, vehicles, depot):
    if not route:
        return None, float("inf")
    best = None
    best_cost = float("inf")
    load = sum(o['weight'] for o in route)
    for v in vehicles:
        if load <= v['capacity'] and feasible_route(route, v, depot):
            c = route_cost(route, v, depot)
            if c < best_cost:
                best_cost = c
                best = v
    return best, best_cost

# =========================
# CONSTRUCTION GLOUTONNE
# =========================

def build_routes(orders, vehicles, depot):
    remaining = orders[:]
    routes = []
    remaining.sort(key=lambda o: o['tmax'])
    while remaining:
        route = [remaining.pop(0)]
        improved = True
        while improved:
            improved = False
            best_cost = float("inf")
            best_o = None
            for o in remaining:
                test = route + [o]
                v, c = best_vehicle(test, vehicles, depot)
                if v is not None and c < best_cost:
                    best_cost = c
                    best_o = o
            if best_o:
                route.append(best_o)
                remaining.remove(best_o)
                improved = True
        v, _ = best_vehicle(route, vehicles, depot)
        routes.append({'orders': route, 'vehicle': v})
    return routes

# =========================
# 2-OPT INTRA-ROUTE
# =========================

def two_opt_route(route, vehicles, depot):
    best_route = route[:]
    best_v, best_cost = best_vehicle(best_route, vehicles, depot)
    improved = True
    while improved:
        improved = False
        n = len(best_route)
        for i in range(n-1):
            for j in range(i+2, n):
                new_route = best_route[:i] + best_route[i:j][::-1] + best_route[j:]
                v, c = best_vehicle(new_route, vehicles, depot)
                if v and c < best_cost:
                    best_route = new_route
                    best_cost = c
                    improved = True
                    break
            if improved:
                break
    return best_route

def improve_routes_2opt(routes, vehicles, depot):
    for r in routes:
        r['orders'] = two_opt_route(r['orders'], vehicles, depot)
        r['vehicle'], _ = best_vehicle(r['orders'], vehicles, depot)

# =========================
# RELOCATE LIGHT
# =========================

def relocate_light(routes, vehicles, depot):
    improved = True
    while improved:
        improved = False
        for i in range(len(routes)):
            for j in range(len(routes)):
                if i == j:
                    continue
                r1 = routes[i]
                r2 = routes[j]
                for k in range(len(r1['orders'])):
                    order = r1['orders'][k]
                    new_r1 = r1['orders'][:k] + r1['orders'][k+1:]
                    if not new_r1:
                        continue  # On ne teste pas route vide
                    # Tester seulement 3 positions les plus proches géographiquement
                    positions = [0, len(r2['orders'])//2, len(r2['orders'])]
                    for pos in positions:
                        new_r2 = r2['orders'][:pos] + [order] + r2['orders'][pos:]
                        v1, c1 = best_vehicle(new_r1, vehicles, depot)
                        v2, c2 = best_vehicle(new_r2, vehicles, depot)
                        if v1 and v2:
                            old_cost = route_cost(r1['orders'], r1['vehicle'], depot) + \
                                       route_cost(r2['orders'], r2['vehicle'], depot)
                            new_cost = c1 + c2
                            if new_cost < old_cost:
                                routes[i] = {'orders': new_r1, 'vehicle': v1}
                                routes[j] = {'orders': new_r2, 'vehicle': v2}
                                improved = True
                                break
                    if improved:
                        break
                if improved:
                    break
            if improved:
                break

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

def creer_solution(solution_file_name, instance_file_name):
    depot, orders = read_instance(instance_file_name)
    phi0 = depot['coord'][0]
    depot['coord'] = geo_to_meters(depot['coord'], phi0)
    for o in orders:
        o['coord'] = geo_to_meters(o['coord'], phi0)
    routes = build_routes(orders, vehicles, depot)
    improve_routes_2opt(routes, vehicles, depot)
    relocate_light(routes, vehicles, depot)
    save_routes(routes, solution_file_name)

# =========================
# RUN
# =========================

if __name__ == "__main__":
    vehicles = read_vehicles(BASE_DIR / "juliaEvaluator" / "data-projet" / "instances" / "vehicles.csv")
    for i in range(1, 11):
        inst = BASE_DIR / "juliaEvaluator" / "data-projet" / "instances" / f"instance_{i:02d}.csv"
        sol = f"solution_{i:02d}.csv"
        creer_solution(sol, inst)
    print("✔ Solutions générées avec 2-opt + relocate light")

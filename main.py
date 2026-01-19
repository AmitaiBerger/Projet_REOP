import csv
import math
from copy import deepcopy

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
        g += (vehicle['alpha'][n] * math.cos(n * OMEGA * t)
              + vehicle['beta'][n] * math.sin(n * OMEGA * t))
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
        t = t + travel_time(vehicle, prev, o, t)
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


def best_vehicle(route, vehicles, depot):
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
            best_gain = float("inf")
            best_o = None

            for o in remaining:
                test = route + [o]
                v, c = best_vehicle(test, vehicles, depot)
                if v is not None and c < best_gain:
                    best_gain = c
                    best_o = o

            if best_o:
                route.append(best_o)
                remaining.remove(best_o)
                improved = True

        v, _ = best_vehicle(route, vehicles, depot)
        routes.append({'orders': route, 'vehicle': v})

    return routes


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

def creer_solution(solution_file_name,instance_file_name):
    depot, orders = read_instance(instance_file_name)
    phi0 = depot['coord'][0]
    depot['coord'] = geo_to_meters(depot['coord'], phi0)
    for o in orders:
        o['coord'] = geo_to_meters(o['coord'], phi0)

    routes = build_routes(orders, vehicles, depot)
    save_routes(routes, solution_file_name)

if __name__ == "__main__":
    vehicles = read_vehicles("juliaEvaluator/data-projet/instances/vehicles.csv")
    creer_solution("solution_01.csv",r"C:\Users\amita\OneDrive\Bureau\REOP\Projet_REOP\juliaEvaluator\data-projet\instances\instance_01.csv")

    creer_solution("solution_02.csv",r"C:\Users\amita\OneDrive\Bureau\REOP\Projet_REOP\juliaEvaluator\data-projet\instances\instance_02.csv")
    creer_solution("solution_03.csv",r"C:\Users\amita\OneDrive\Bureau\REOP\Projet_REOP\juliaEvaluator\data-projet\instances\instance_03.csv")
    creer_solution("solution_04.csv",r"C:\Users\amita\OneDrive\Bureau\REOP\Projet_REOP\juliaEvaluator\data-projet\instances\instance_04.csv")
    creer_solution("solution_05.csv",r"C:\Users\amita\OneDrive\Bureau\REOP\Projet_REOP\juliaEvaluator\data-projet\instances\instance_05.csv")
    creer_solution("solution_06.csv",r"C:\Users\amita\OneDrive\Bureau\REOP\Projet_REOP\juliaEvaluator\data-projet\instances\instance_06.csv")
    creer_solution("solution_07.csv",r"C:\Users\amita\OneDrive\Bureau\REOP\Projet_REOP\juliaEvaluator\data-projet\instances\instance_07.csv")
    creer_solution("solution_08.csv",r"C:\Users\amita\OneDrive\Bureau\REOP\Projet_REOP\juliaEvaluator\data-projet\instances\instance_08.csv")
    creer_solution("solution_09.csv",r"C:\Users\amita\OneDrive\Bureau\REOP\Projet_REOP\juliaEvaluator\data-projet\instances\instance_09.csv")
    creer_solution("solution_10.csv",r"C:\Users\amita\OneDrive\Bureau\REOP\Projet_REOP\juliaEvaluator\data-projet\instances\instance_10.csv")

    print("✔ Solutions générées")

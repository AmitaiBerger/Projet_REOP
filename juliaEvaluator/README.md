# REOP 2025-2026 -- Projet-- Califrais Delivery Optimization Challenge

Vehicle Routing Problem with Time Windows (VRPTW) solver for the KIRO 2025 competition, in collaboration with **Califrais**, the official digital and logistics operator of the Rungis International Market.

## Competition Overview

### Industrial Context

[Califrais](https://www.califrais.fr/) operates the digital marketplace [RungisMarket](https://rungismarket.com/) for the Rungis International Market, one of the world's largest wholesale food markets located in the Paris suburbs. The platform enables Paris restaurants and businesses to order fresh products (fruits, vegetables, meat, fish, etc.) from a unified marketplace, with Califrais handling:

- **Order consolidation** from multiple suppliers
- **Warehouse storage** at Rungis Market
- **Last-mile delivery** to Paris customers with a truck fleet

### Challenge Objective

**Optimize delivery truck routes** to minimize operational costs while satisfying all constraints. This is a real-world problem solved daily by Califrais using operations research methods.

**Key Constraints:**
- Customers order until midnight for next-day delivery
- Warehouse loading starts immediately
- First trucks depart early morning (5-6 AM)
- **Algorithm runtime**: ≤ 10 minutes for largest instances

**Evaluation:** Teams submit solutions for all problem instances to the KIRO platform. The team with the lowest total cost across all instances wins.

## Problem Description

### Vehicle Fleet
- **Unlimited rental fleet** with multiple vehicle families (F types)
- Each family has distinct characteristics:
  - Maximum capacity (kg)
  - Daily rental cost (€)
  - Fuel cost per meter (€/m)
  - Radius penalty cost (€/m²) - encourages clustered deliveries
  - Speed (m/s) and parking time (s)
  - Time-dependent travel coefficients (Fourier series)

### Customers & Orders
- **Depot (i=0)**: Califrais warehouse at Rungis Market
- **Customers (i ∈ I)**: Delivery locations in Paris region
  - GPS coordinates (latitude, longitude in degrees)
  - Order weight (kg)
  - Delivery time window [t_min, t_max] (seconds from midnight)
  - Service duration (seconds)

### Time-Dependent Travel Times
Travel times vary by vehicle type and time of day (rush hour modeling):

```
τ_f(i,j|t) = τ_f(i,j) · γ_f(t)
```

- **Reference time**: Based on Manhattan distance and vehicle speed
- **Time factor**: Fourier series (period = 24h) capturing traffic patterns
- **FIFO property**: Departing later means arriving later (guaranteed)

### Cost Components

**Total cost = Σ (Rental + Fuel + Radius penalty)**

1. **Rental cost**: Daily vehicle hire (fixed per route)
2. **Fuel cost**: Based on Manhattan distance traveled
3. **Radius penalty**: Squared Euclidean radius of delivery cluster
   - Encourages geographically compact routes
   - Reduces driving time in congested Paris streets

### Constraints

1. **Coverage**: Each customer served exactly once
2. **Capacity**: Total weight ≤ vehicle capacity
3. **Time windows**: Arrivals within [t_min, t_max] (waiting allowed)
4. **Sequencing**: Proper arrival/departure timing with travel times

## Features

- **Time-dependent travel times** using Fourier series
- **Multiple vehicle types** with different capacities and costs
- **Time window constraints** for deliveries
- **FIFO property** enforcement
- **Real map visualization** with OpenStreetMap tiles of Paris

### Route Maps with Real Paris Streets
Interactive HTML maps showing routes overlaid on **real OpenStreetMap tiles**:
- Actual Paris street names and geography
- Zoom from city-wide to street-level detail
- Click markers for delivery details
- Color-coded routes by vehicle

### Per-Vehicle Analysis Charts
- **Time windows**: Separate Gantt chart per vehicle showing:
  - Waiting times (orange dashed)
  - Service times (dark blue)
  - Time window constraints (gray bars)
- **Truck loads**: Individual capacity tracking per vehicle
  - Current load progression
  - Peak utilization percentage

## Usage

### Run full optimization (all 10 instances) 
```bash
julia --project=. scripts/main.jl
```
Runs a bad heuristic on all instances. **You should build a better heuristic**

### Compute performance summary
```bash
julia --project=. scripts/compute_summary.jl
```
Shows feasibility status and cost improvements for all solutions. **This is the script that will be used to evaluate your solutions**. Please test that it works with your solutions.

### Create visualizations
```bash
julia --project=. scripts/visualization.jl
```
This requires to install some python packages (not needed, but can help you figure out what happens with your algorithms)
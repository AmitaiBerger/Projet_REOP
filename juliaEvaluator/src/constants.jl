const T = 24 * 60
const ω = 2 * π / T
const a0x = round(6700 / 60; digits=2)
const a0y = round(9700 / 60; digits=2)
const b0 = round(500 / 60; digits=2)
const a1x = round(6200 / 60; digits=2)
const a1y = round(9050 / 60; digits=2)
const b1 = round(400 / 60; digits=2)
const α₀ = [1.18, -0.16, -0.02, 0.03]
const α₁ = [1.22, -0.19, -0.03, 0.03]
const β₀ = [0.0, -0.12, 0.0, 0.06]
const β₁ = [0.0, -0.14, -0.01, 0.06]
const DEPOT = (; longitude=2.34842, latitude=48.764246)
const PARIS_CENTER = (; longitude=2.3522, latitude=48.8566)
const DEPARTURE_TIME = 5 * 60
const ρ = 6.371e6  # Earth radius

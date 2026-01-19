function Δ_latitude_to_meters(Δ_latitude)
    return ρ * 2π / 360 * Δ_latitude
end

function Δ_longitude_to_meters(Δ_longitude)
    φ₀ = KIRO2025.DEPOT.latitude
    return ρ * cos(deg2rad(φ₀)) * 2π / 360 * Δ_longitude
end

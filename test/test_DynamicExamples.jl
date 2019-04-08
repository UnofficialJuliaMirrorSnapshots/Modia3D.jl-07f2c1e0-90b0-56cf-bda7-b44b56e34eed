module TestDynamicExamples

import Modia3D
using  Modia3D.Test
import Modia3D.ModiaMath


# Test Modia3D - Dynamic Examples

# examples/dynamics
dynamicsPath = joinpath(Modia3D.path, "examples", "dynamics")


include(joinpath(dynamicsPath, "Simulate_Pendulum.jl"))
import .Simulate_Pendulum

include(joinpath(dynamicsPath, "Simulate_DoublePendulum.jl"))
import .Simulate_DoublePendulum


@testset "Modia3D: Simulate_Pendulum.jl" begin
   pendulum = Modia3D.SimulationModel( Simulate_Pendulum.Pendulum(Lx=1.6, m=0.5) )
   result = ModiaMath.simulate!(pendulum, stopTime=5.0, tolerance=1e-8, log=false)
   phi = result.series["rev.phi"]
   w   = result.series["rev.w"]

   @test isapprox(phi[end], -2.61422; atol=1e-5 )
   @test isapprox(w[end]  , -3.51319; atol=1e-5 )
end


@testset "Modia3D: Simulate_DoublePendulum.jl" begin
   doublePendulum = Modia3D.SimulationModel( Simulate_DoublePendulum.DoublePendulum(Lx=1.0, m=1.0) )
   result = ModiaMath.simulate!(doublePendulum, stopTime=5.0, tolerance=1e-8, log=false)
   phi1 = result.series["rev1.phi"]
   phi2 = result.series["rev2.phi"]
   w1   = result.series["rev1.w"]
   w2   = result.series["rev2.w"]

   @test isapprox(phi1[end], -0.211087; atol=1e-3 )
   @test isapprox(phi2[end],  0.458381; atol=1e-3 )
   @test isapprox(w1[end]  ,  1.51728 ; atol=1e-2 )
   @test isapprox(w2[end]  , -0.928819; atol=1e-2 )
end

end

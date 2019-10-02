module tests_SolidFileMesh

using Modia3D
using Modia3D.StaticArrays
import Modia3D.ModiaMath

vmat1 = Modia3D.Material(color="LightBlue" , transparency=0.5)    # material of SolidFileMesh
vmat2 = deepcopy(vmat1)                                           # material of convex decomposition of SolidFileMesh
vmat2.transparency = 0.7

cmat = "Steel"

filenamePascal = joinpath(Modia3D.path, "objects", "pascal", "pascal.obj")
filenameCrank = joinpath(Modia3D.path, "objects", "engine", "crank", "crank.obj")
filenameRod = joinpath(Modia3D.path, "objects", "engine", "rod", "rod.obj")
filenameBunny = joinpath(Modia3D.path, "objects", "bunny", "bunny.obj")

@assembly ThreeDFiles begin
  world = Modia3D.Object3D(visualizeFrame=true)
  solidFileMeshCrank = Modia3D.SolidFileMesh(filenameCrank,1.0)
  #fileMesh1 = Modia3D.Object3D(world, Modia3D.Solid(solidFileMeshCrank, "Aluminium", vmat1; contactMaterial = cmat); r=[0.0,0.0,0.0], fixed=false)

  #boxMoving     = Modia3D.Object3D(world, Modia3D.Solid(Modia3D.SolidBox(0.3,0.3,0.3) , "Aluminium", vmat1; contactMaterial = cmat); r=[0.0, 0.0, 0.0], R=ModiaMath.rot2(-pi/3), fixed=false) # ,R=ModiaMath.rot2(-pi/3),

  sphereMoving     = Modia3D.Object3D(world, Modia3D.Solid(Modia3D.SolidSphere(0.5) , "Aluminium", vmat1; contactMaterial = cmat); r=[0.0, 0.0, 0.0],  fixed=false) # R=ModiaMath.rot2(-pi/2),

  #fileMesh2 = Modia3D.Object3D(world, Modia3D.SolidWithConvexDecomposition(solidFileMeshCrank, "Aluminium", vmat1, vmat2; contactMaterial = cmat); r=[3.0,0.0,0.0], fixed=false)

  #bunny = Modia3D.Object3D(world, Modia3D.SolidWithConvexDecomposition(Modia3D.SolidFileMesh(filenameBunny,0.1), "Aluminium", vmat1, vmat2; contactMaterial = cmat); r=[-3.0, 0.0, -1.0], fixed=true)

  box     = Modia3D.Object3D(world, Modia3D.Solid(Modia3D.SolidBox(1.0,4.0,20.0) , "Aluminium", vmat1; contactMaterial = cmat); r=[-3.0, 0.0, -2.0], fixed=true) # R=ModiaMath.rot2(-pi/3),
end


gravField = Modia3D.UniformGravityField(g=9.81, n=[-1,0,0])
threeD = ThreeDFiles(sceneOptions=Modia3D.SceneOptions(gravityField=gravField,visualizeFrames=true, defaultFrameLength=0.7,nz_max = 100, enableContactDetection=true, visualizeContactPoints=true))


# Modia3D.visualizeAssembly!( threeD )


model = Modia3D.SimulationModel( threeD )
result = ModiaMath.simulate!(model; stopTime=4.0, tolerance=1e-6,interval=0.001, log=false)


println("... success of tests_SolidFileMesh.jl!")

end

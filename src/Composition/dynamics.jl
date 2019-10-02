# License for this file: MIT (expat)
# Copyright 2017-2018, DLR Institute of System Dynamics and Control
#
# This file is part of module
#   Modia3D.Composition (Modia3D/Composition/_module.jl)
#



"""
    get_Object3DsWithoutParent!(assembly,frames) - Returns all frames within assembly, that do not have a parent frame

The function traverses assembly and stores all frames without a parent frame in vector frames.
"""
function get_Object3DsWithoutParent!(assembly::Modia3D.AbstractAssembly, frames::AbstractVector)::NOTHING
    assemblyType = typeof(assembly)

    for i = 1:fieldcount(assemblyType)
          field     = getfield(assembly, fieldname(assemblyType,i))
          fieldType = typeof(field)
          if fieldType == Object3D
             if hasNoParent(field)
                push!(frames,field)
             end
          elseif fieldType <: Modia3D.AbstractAssembly
             get_Object3DsWithoutParent!(field, frames)
          end
    end
    return nothing
end


"""
    world = get_WorldObject3D(assembly) - Returns the assembly world frame

The function traverses assembly and collects all frames that do not have a parent frame.
If exactly one such frame is present, it is returned.
Otherwise, an error is triggered
"""
function get_WorldObject3D(assembly::Modia3D.AbstractAssembly)::Object3D
   frames = Object3D[]
   get_Object3DsWithoutParent!(assembly, frames)
   if length(frames) == 1
      return frames[1]
   elseif length(frames) < 1
      error("\nError message from Modia3D.SimulationModel!(..):\n",
            typeof(assembly), " has no reference frame.")
   else
      frameNames = String[]
      for frame in frames
         push!(frameNames, ModiaMath.fullName(frame))
      end
      error("\nError message from Modia3D.SimulationModel!(..):\n",
            typeof(assembly), " has the following frames that do not have a parent frame:\n",
            frameNames, "\n",
            "This is not allowed (exactly one frame must not have a parent frame).")
   end
end


"""
    simModel = SimulationModel(assembly::Modia3D.AbstractAssembly;
                               analysis::ModiaMath.AnalysisType=ModiaMath.DynamicAnalysis,
                               startTime = 0.0, stopTime  = 1.0, tolerance = 1e-4,
                               interval  = (stopTime-startTime)/500.0,
                               maxStepSize = NaN, maxNumberOfSteps=missing)

Generate a `simulationModel` from an `assembly` generated with macro [`Modia3D.@assembly`](@ref)
and the type of `analysis` to be carried out on the `assembly`.
Additionally, default `startTime`, `stopTime`, `tolerance`, `interval`,
`maxStepSize`, `maxNumberOfSteps`, for the simulation
engine are defined. These values should be adapted so that assembly-specific, meaningful
defaults are provided.
"""
struct SimulationModel <: ModiaMath.AbstractSimulationModel
   modelName::String
   simulationState::ModiaMath.SimulationState
   assembly::Modia3D.AbstractAssembly
   var::ModiaMath.ModelVariables
   analysis::ModiaMath.AnalysisType

   function SimulationModel(assembly::Modia3D.AbstractAssembly;
                            analysis::ModiaMath.AnalysisType=ModiaMath.DynamicAnalysis,
                            startTime = 0.0,
                            stopTime  = 1.0,
                            tolerance = 1e-4,
                            interval  = (stopTime-startTime)/500.0,
                            maxStepSize=NaN,
                            maxNumberOfSteps=missing,
                            hev = 1e-8,
                            scaleConstraintsAtEvents::Bool = true)
      modelName = Modia3D.trailingPartOfName( string( typeof(assembly) ) )
      world = get_WorldObject3D(assembly)
      assembly._internal.referenceObject3D = world
      # println("\n... world reference frame: ", ModiaMath.fullName(world))

      # Determine Variables in assembly
      var = ModiaMath.ModelVariables(assembly, analysis=analysis)
      #ModiaMath.print_ModelVariables(var)

      # Set initial values for x
      x = zeros(var.nx)
      x_fixed   = fill(false,var.nx)
      x_nominal = fill(1.0  ,var.nx)
      ModiaMath.copy_start_to_x!(var, x, x_fixed, x_nominal)
      # println("... x0 = ", x)

      # Last nfc equations are the constraint equations
      is_constraint = fill(false, var.nx)
      for i = (var.nx-var.nfc+1):var.nx
         is_constraint[i] = true
      end

      # Construct Scene(..) object
      so = assembly._internal.sceneOptions
      sceneOptions::SceneOptions = typeof(so) == NOTHING ? SceneOptions() : so
      scene = Scene(sceneOptions)
      scene.analysis = analysis
      assembly._internal.scene = scene
      if !scene.options.enableContactDetection
          scene.collide = false
      end

      # Build tree for optimized structure or standard structure
      # collision handling is only available for optimized structure
      nz = 0
      if scene.options.useOptimizedStructure
         build_superObjs!(scene, world)
         if !scene.options.enableContactDetection
             scene.collide = false
         end

         if scene.collide
            initializeContactDetection!(world, scene)
            if scene.collide
                nz = scene.options.contactDetection.contactPairs.nz
                append!(scene.allVisuElements, world.contactVisuObj1)
                append!(scene.allVisuElements, world.contactVisuObj2)
                append!(scene.allVisuElements, world.supportVisuObj1A)
                append!(scene.allVisuElements, world.supportVisuObj1B)
                append!(scene.allVisuElements, world.supportVisuObj1C)
                append!(scene.allVisuElements, world.supportVisuObj2A)
                append!(scene.allVisuElements, world.supportVisuObj2B)
                append!(scene.allVisuElements, world.supportVisuObj2C)
            end
         end
         initializeMassComputation!(scene)
      else
         build_tree!(scene, world)
         if scene.options.enableContactDetection
            error("Collision handling is only possible with the optimized structure. Please set useOptimizedStructure = true in Modia3D.SceneOptions.")
         end
      end

      # Initialize connections between signals and frames, joints, ...
      build_SignalObject3DConnections!(assembly)
      scene.initAnalysis = true

      # Generate simulationState
      simulationState = ModiaMath.SimulationState(modelName, getModelResidues!, x, ModiaMath.Variables.getVariableName;
                                x_fixed   = x_fixed,
                                x_nominal = x_nominal,
                                is_constraint = is_constraint,
                                nz = nz,
                                defaultStartTime = startTime,
                                defaultStopTime  = stopTime,
                                defaultTolerance = tolerance,
                                defaultInterval  = interval,
                                defaultMaxStepSize = maxStepSize,
                                defaultMaxNumberOfSteps = maxNumberOfSteps,
                                getResultNames   = Composition.getResultNames,
                                getResult        = ModiaMath.Variables.getResult,
                                storeResult!     = ModiaMath.Variables.storeVariables!,
                                hev = hev,
                                scaleConstraintsAtEvents = scaleConstraintsAtEvents)

#=
      scene = assembly._internal.scene
      if useOptimizedStructure
          println("\n... SimulationModel: treeAccVelo begin")
          tree = scene.treeAccVelo
      else
          println("\n... SimulationModel: tree begin")
          tree = scene.tree
      end

      for obj in tree
         if hasParent(obj)
            println(ModiaMath.instanceName(obj), " (parent = ", ModiaMath.instanceName(obj.parent), ")")
            println("    r_rel = ", obj.r_rel, ", R_rel = ", obj.R_rel)
         else
            println(ModiaMath.instanceName(obj), " (no parent)")
         end
         if hasJoint(obj)
            println("    joint type = ", typeof(obj.joint))
         end
         if objectHasMass(obj)
            println("    m = ", obj.massProperties.m, " rCM = ", obj.massProperties.rCM, " I = ", obj.massProperties.I)
         end
      end
      println("...  end\n\n")

      println("... allVisuElements:")
      for obj in scene.allVisuElements
          println(ModiaMath.instanceName(obj))
      end
      println("... end allVisuElements")
=#
      new(modelName, simulationState,assembly,var,analysis)
   end
end

ModiaMath.print_ModelVariables(model::SimulationModel) = ModiaMath.print_ModelVariables(model.var)
print_ModelVariables(          model::SimulationModel) = ModiaMath.print_ModelVariables(model.var)

getResultNames(model::SimulationModel) = model.var.result_names


function initializeFlowVariables(scene::Scene)
  flowVarInput   = scene.flowVarInput
  flowVarOutput  = scene.flowVarOutput
  @assert(length(flowVarInput) == length(flowVarOutput))
  for i=eachindex(flowVarInput)
    flowVarInput[i].value  = 0.0
    flowVarOutput[i].value = 0.0
  end
end


function setFlowVariables(scene::Scene)
  flowVarInput   = scene.flowVarInput
  flowVarOutput  = scene.flowVarOutput
  @assert(length(flowVarInput) == length(flowVarOutput))
  for i=eachindex(flowVarInput)
    flowVarInput[i].value  += flowVarOutput[i].value
  end
end

function setPotentialVariables(scene::Scene)
  potentialVarInput   = scene.potentialVarInput
  potentialVarOutput  = scene.potentialVarOutput
  @assert(length(potentialVarInput) == length(potentialVarOutput))
  for i=eachindex(potentialVarInput)
    potentialVarInput[i].value = potentialVarOutput[i].value
  end
end

function computationForcesAndTorques(scene::Scene, sim::ModiaMath.SimulationState)
    for forceTorque in scene.uniqueForceTorques
        computeTorque(forceTorque, sim)
    end
end

function computationSignals(scene::Scene, sim::ModiaMath.SimulationState)
    for signal in scene.uniqueSignals
        computeSignal(signal, sim)
    end
end

# Return a table of actual variable and residue values from nonlinear solver in case of error
function ModiaMath.getVariableAndResidueValues(m::SimulationModel)
   var = m.var
   v_table = ModiaMath.get_variableValueTable(var)
   r_table = ModiaMath.get_residueValueTable(var, m.simulationState.derxev)
   return (v_table, r_table)
end


const str_DUMMY = "dummyDistance(nothing,nothing)"


function getModelResidues!(m::SimulationModel, time::Float64, _x::Vector{Float64}, _derx::Vector{Float64}, _r::Vector{Float64}, _w::Vector{Float64})
   # println("... time = ", time, ", x = ", _x, ", derx = ", _derx)
   sim              = m.simulationState
   world            = m.assembly._internal.referenceObject3D
   scene            = m.assembly._internal.scene
   if scene.options.useOptimizedStructure
      tree          = scene.treeAccVelo
   else
      tree          = scene.tree
   end
   cutJoints        = scene.cutJoints
   var              = m.var
   analysis         = m.analysis

   # Handle initialization and termination of model
   if ModiaMath.isInitial(sim)
      # println("... isInitial = true")
      if scene.collide
         initializeContactDetection!(world, scene)
         append!(scene.allVisuElements, world.contactVisuObj1)
         append!(scene.allVisuElements, world.contactVisuObj2)

         append!(scene.allVisuElements, world.supportVisuObj1A)
         append!(scene.allVisuElements, world.supportVisuObj1B)
         append!(scene.allVisuElements, world.supportVisuObj1C)
         append!(scene.allVisuElements, world.supportVisuObj2A)
         append!(scene.allVisuElements, world.supportVisuObj2B)
         append!(scene.allVisuElements, world.supportVisuObj2C)
      end
      if scene.visualize
         initializeVisualization(Modia3D.renderer[1], scene.allVisuElements)
      end
   end

   if ModiaMath.isTerminal(sim)
      # println("... isTerminal = true")
      if scene.visualize
         # println("... visualization closing")
         closeVisualization(Modia3D.renderer[1])
      end
      if scene.collide
         closeContactDetection!(m.assembly)
      end
      return
   end

   # Check input arguments
   @assert(length(_x)    == var.nx)
   @assert(length(_derx) == var.nx)
   @assert(length(_r)    == var.nx)
   @assert(length(_w)    == 0)

   storeResults = ModiaMath.isStoreResult(sim) && (scene.visualize || var.nwr > 0 || var.nwc > 0 )

   # Initialize residues _r with zero
   for i in eachindex(_r)
      _r[i] = 0.0
   end

   # Copy x and derx to variables
   ModiaMath.copy_x_and_derx_to_variables!(time, _x, _derx, var)

   # Compute signals
   initializeFlowVariables(scene)
   computationSignals(scene, sim)
   setPotentialVariables(scene)
   setFlowVariables(scene)

   # Initialize force/torque of world-frame
   world.dynamics.f = ModiaMath.ZeroVector3D
   world.dynamics.t = ModiaMath.ZeroVector3D

   # Compute positions, velocities, accelerations in a forward recursion

   open("log.txt", "a") do file

   #println("\n... Forward recursion")
   for obj in tree
      # Compute kinematics
      computeKinematics!(obj.joint, obj, analysis, time)

      if typeof(obj.visualizationFrame) != NOTHING
         obj.visualizationFrame.r_abs = obj.r_abs
         obj.visualizationFrame.R_abs = obj.R_abs
      end


      # Compute forces and torques
      initializeFlowVariables(scene)
      setPotentialVariables(scene)
      computationForcesAndTorques(scene,sim)
      setFlowVariables(scene)

      # Initialize forces and torques
      dynamics::Object3Ddynamics = obj.dynamics

      if analysis != ModiaMath.KinematicAnalysis
         hasMassProperties = false
         if scene.options.useOptimizedStructure
            if objectHasMass(obj)
               massProperties    = obj.massProperties
               hasMassProperties = true
            end
         else
            if dataHasMass(obj)
               massProperties    = obj.data.massProperties
               hasMassProperties = true
            end
         end

         if hasMassProperties
            # Compute inertia forces / torques
            mass = massProperties.m
            rCM  = massProperties.rCM
            I    = massProperties.I
            w    = dynamics.w
            #println("w = ",w)
            grav = gravityAcceleration(scene.options.gravityField, obj.r_abs)
            # println("grav = ", grav)
            if rCM === ModiaMath.ZeroVector3D
               dynamics.f = -mass*( obj.R_abs*(dynamics.a0  - grav) )
               dynamics.t = -(I*dynamics.z + cross(w, I*w))
               # println("(dynamics.a0  - grav) = ", (dynamics.a0  - grav) )
               #println("dynamics.t = ", dynamics.t)
               #println(" ")
            else
               dynamics.f = -mass*( obj.R_abs*(dynamics.a0 - grav) +
                                  cross(dynamics.z, rCM) + cross(w, cross(w, rCM)))
               dynamics.t = -(I*dynamics.z + cross(w, I*w)) + cross(rCM, dynamics.f)
            end

         else
            dynamics.f = ModiaMath.ZeroVector3D
            dynamics.t = ModiaMath.ZeroVector3D
         end
      end
      #println("    ", ModiaMath.instanceName(obj), ": f = ", dynamics.f, ", t = ", dynamics.t)

      #if ModiaMath.isInitial(sim)
      #   println(ModiaMath.instanceName(obj), ": f = ", dynamics.f, ", t = ", dynamics.t)
      #end
   end # for


   # Compute contact forces/torques
   if scene.collide
      ch = scene.options.contactDetection
      chpairs = ch.contactPairs

      # Compute signed distances of all contact shapes during zero-crossing computation
      setComputationFlag(ch)
      if ModiaMath.isEvent(sim)    # with Event
         selectContactPairsWithEvent!(sim, ch, world) #sim#
      elseif ModiaMath.isZeroCrossing(sim) # no Event
         selectContactPairsNoEvent!(sim, ch, world) #sim
      else
         getDistances!(ch, world)
      end

      # Handle zero crossing event
      simh = sim.eventHandler
      for (pairID, pair) in ch.contactDict
        obj1 = pair.obj1
        obj2 = pair.obj2
        rContact      = (pair.contactPoint1 + pair.contactPoint2)/2.0
        contactNormal = pair.contactNormal

        #simh = sim.eventHandler
        #println( "time = ", sim.time, ": ", ModiaMath.instanceName(obj1), " ", ModiaMath.instanceName(obj2),
        #         " i = ", i, ", initial = ", simh.initial, ", event = ", simh.event, " change = ", chpairs.changeDirection[i] )
        if ModiaMath.isEvent(sim)
            # Include contact pair material into collision pair
            if haskey(ch.lastContactDict, pairID)
                # use material (reference) from previous event
                pair.contactPairMaterial = ch.lastContactDict[pairID].contactPairMaterial    # improve later (should avoid to inquire pairID twice)
            else
                # determine contact pair material
                pair.contactPairMaterial = contactStart(obj1, obj2, rContact, contactNormal,
                                                         scene.options.elasticContactReductionFactor)
                simh.restart = max(simh.restart, ModiaMath.Restart)
                simh.newEventIteration = false
                if ModiaMath.isLogEvents(simh.logger)
                    name1 = ModiaMath.instanceName(obj1)
                    name2 = ModiaMath.instanceName(obj2)
                    n     = contactNormal
                    println("        distance(", name1, ",", name2, ") = ", pair.distanceWithHysteresis, " became < 0")
                    Printf.@printf("            contact normal = [%.3g,%.3g,%.3g], contact position = [%.3g,%.3g,%.3g], c_res=%.3g, d_res=%.3g\n",
                                   n[1],n[2],n[3],rContact[1],rContact[2],rContact[3], pair.contactPairMaterial.c_res, pair.contactPairMaterial.d_res)
                end
            end
        end

        # println("length(ch.dictCommunicate) ", length(ch.dictCommunicate) )
        (f1,f2,t1,t2) = responseCalculation(pair.contactPairMaterial, obj1, obj2, rContact, contactNormal,
                                             pair.distanceWithHysteresis, time, file)

        # Transform forces/torques in local part frames
        obj1.dynamics.f += obj1.R_abs*f1
        obj1.dynamics.t += obj1.R_abs*t1
        obj2.dynamics.f += obj2.R_abs*f2
        obj2.dynamics.t += obj2.R_abs*t2
#=
               if time > 0.785 && time < 0.787  && String(ModiaMath.instanceName(obj1)) != "table.box1"
                  println("obj1= \"", ModiaMath.instanceName(obj1), "\" obj2 = ", ModiaMath.instanceName(obj2), " f = ", obj1.dynamics.f, " t = ", obj1.dynamics.t, " rContact = ", rContact, " ctNormal[i] ", ModiaMath.Vector3D(chpairs.contactNormal[i]) ," time = ", time)
               end
=#
      end

      if ModiaMath.isEvent(sim)
            # Should be possible to make this more efficient
            for (pairID, pair) in ch.lastContactDict
                if !haskey(ch.contactDict, pairID)
                    contactEnd(pair.contactPairMaterial, pair.obj1, pair.obj2)
                    simh.restart = max(simh.restart, ModiaMath.Restart)
                    simh.newEventIteration = false
                    if !ModiaMath.isLogEvents(simh.logger)
                        break
                    end
                    name1 = ModiaMath.instanceName(pair.obj1)
                    name2 = ModiaMath.instanceName(pair.obj2)
                    println("        distance(", name1, ",", name2, ")  became > 0")
                end
            end

            # Save contactDict in lastContactDict
            empty!(ch.lastContactDict)
            for (pairID, pair) in ch.contactDict
                push!(ch.lastContactDict, pairID => pair)
            end
      end
   end


   # For all cut-joints, set forces/torques at the frames and compute cut-joint residues
   for joint in cutJoints
      computePositionResidues!(joint, time)
      if analysis == ModiaMath.DynamicAnalysis
         computeVelocityResidues!(joint, time)
      end
      if analysis != ModiaMath.KinematicAnalysis
         computeCutForcesAndToques!(joint, time)
      end
   end

   #println("\n... Backward recursion")

   # Compute forces/torques and residues in a backward recursion
   if analysis != ModiaMath.KinematicAnalysis
      for i = length(tree):-1:1
         obj = tree[i]
         computeForceTorqueAndResidue!(obj.joint, obj, analysis, time)
      end

      #if ModiaMath.isInitial(sim)
      #   for i = length(tree):-1:1
      #      obj = tree[i]
      #      println(ModiaMath.instanceName(obj), ": f = ", obj.dynamics.f, ", t = ", obj.dynamics.t)
      #   end
      #end
   end

   # Visualize at a communication point

   if scene.visualize && storeResults
      # Compute positions of frames that are only used for visualization
      if scene.options.useOptimizedStructure
          for obj in scene.treeVisu
              parent = obj.parent
              obj.r_abs = obj.r_rel ≡ ModiaMath.ZeroVector3D ? parent.r_abs : parent.r_abs + parent.R_abs'*obj.r_rel
              obj.R_abs = obj.R_rel ≡ ModiaMath.NullRotation ? parent.R_abs : obj.R_rel*parent.R_abs
              if typeof(obj.visualizationFrame) != NOTHING
                 obj.visualizationFrame.r_abs = obj.r_abs
                 obj.visualizationFrame.R_abs = obj.R_abs
              end
          end
      end
      visualize!(Modia3D.renderer[1], time)
   end

   # Copy variables to residues
   ModiaMath.copy_variables_to_residue!(var, _x, _derx, _r)

   #println("... x = ", _x, ", derx = ", _derx, ", residue = ", _r)

end   # from open
   return nothing
end

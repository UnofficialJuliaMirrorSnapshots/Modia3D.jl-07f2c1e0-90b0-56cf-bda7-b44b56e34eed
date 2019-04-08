# License for this file: MIT (expat)
# Copyright 2017-2018, DLR Institute of System Dynamics and Control
#
# This file is part of module
#   Modia3D.Composition (Modia3D/Composition/_module.jl)
#


mutable struct SignalToFlangeAngle <: Modia3D.AbstractSignalAdaptor
    _internal::ModiaMath.ComponentInternal
    signal::Modia3D.AbstractSignal
    flange::Flange
    function SignalToFlangeAngle(phi::Union{ModiaMath.RealScalar,NOTHING}=nothing)
        if typeof(phi) != NOTHING
            flange = Flange(;phiCausality=ModiaMath.Output)
            signal = phi._internal.within
            flange.phi = phi
            new(ModiaMath.ComponentInternal(), signal, flange)
        else
            error("from Modia3D.SignalToFlangeAngle: There is no signal to convert.")
        end
    end
end

mutable struct SignalToFlangeTorque <: Modia3D.AbstractSignalAdaptor
    _internal::ModiaMath.ComponentInternal
    signal::Modia3D.AbstractSignal
    flange::Flange
    function SignalToFlangeTorque(tau::Union{ModiaMath.RealScalar,NOTHING}=nothing)
        if typeof(tau) != NOTHING
            flange = Flange(;tauCausality=ModiaMath.Output, tauFlow=true)
            signal = tau._internal.within
            tau.flow   = true
            flange.tau = tau
            new(ModiaMath.ComponentInternal(), signal, flange)
        else
            error("from Modia3D.SignalToFlangeTorque: There is no signal to convert.")
        end
    end
end


mutable struct AdaptorForceElementToFlange <: Modia3D.AbstractForceAdaptor
    _internal::ModiaMath.ComponentInternal
    forceElement::Modia3D.AbstractForceTorque
    flange::Flange
    function AdaptorForceElementToFlange(;phi::Union{ModiaMath.RealScalar,NOTHING}=nothing,
                                          w::Union{ModiaMath.RealScalar,NOTHING}=nothing,
                                          a::Union{ModiaMath.RealScalar,NOTHING}=nothing,
                                          tau::Union{ModiaMath.RealScalar,NOTHING}=nothing)
        flange = Flange()
        forceElement  = nothing
        forceElement1 = nothing
        forceElement2 = nothing
        forceElement3 = nothing
        forceElement4 = nothing
        if typeof(phi) != NOTHING
            flange.phi = phi
            forceElement1 = phi._internal.within
            forceElement  = forceElement1
        end
        if typeof(w) != NOTHING
            flange.w = w
            forceElement2 = w._internal.within
            ((typeof(forceElement)==NOTHING) ? (forceElement=forceElement2) : ( (typeof(forceElement)!=typeof(forceElement2)) ? (error("from Modia3D.AdaptorForceElementToFlange: all arguments should be of the same @forceElement.")) : () ) )
        end
        if typeof(a) != NOTHING
            flange.a = a
            forceElement3 = a._internal.within
            ((typeof(forceElement)==NOTHING) ? (forceElement=forceElement3) : ( (typeof(forceElement)!=typeof(forceElement3)) ? (error("from Modia3D.AdaptorForceElementToFlange: all arguments should be of the same @forceElement.")) : () ) )
        end
        if typeof(tau) != NOTHING
            tau.flow   = true
            flange.tau = tau
            forceElement4 = tau._internal.within
            ((typeof(forceElement)==NOTHING) ? (forceElement=forceElement4) : ( (typeof(forceElement)!=typeof(forceElement4)) ? (error("from Modia3D.AdaptorForceElementToFlange: all arguments should be of the same @forceElement.")) : () ) )
        end
        if typeof(forceElement) != NOTHING
            new(ModiaMath.ComponentInternal(),forceElement,flange)
        else
            error("from Modia3D.SignalToFlangeTorque: There is no forceElement to convert.")
        end
    end
end


#=
mutable struct TransDyn
  filter_T::Float64
  signal::AbstractSignal
  flange::Flange
  function TransDyn(signal::AbstractSignal, filter_T = 50)
     new(signal, Flange()
  end
end
=#

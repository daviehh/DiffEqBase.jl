module DiffEqBaseEnzymeExt

using DiffEqBase
import DiffEqBase: value
isdefined(Base, :get_extension) ? (import Enzyme) : (import ..Enzyme)

using ChainRulesCore
using EnzymeCore

function EnzymeCore.EnzymeRules.augmented_primal(config::EnzymeCore.EnzymeRules.ConfigWidth{1}, func::Const{typeof(DiffEqBase.solve_up)}, ::Type{Duplicated{RT}}, prob, sensealg::Union{Const{Nothing}, Const{<:AbstractSensitivityAlgorithm}}, u0, p, args...; kwargs...) where RT
    @inline function copy_or_reuse(val, idx)
        if EnzymeCore.EnzymeRules.overwritten(config)[idx] && ismutable(val)
            return deepcopy(val)
        else
            return val
        end
    end

    @inline function arg_copy(i)
        copy_or_reuse(args[i].val, i+5)
    end
 
    res = DiffEqBase._solve_adjoint(copy_or_reuse(prob.val, 2), copy_or_reuse(sensealg.val, 3), copy_or_reuse(u0.val, 4), copy_or_reuse(p.val, 5), SciMLBase.ChainRulesOriginator(), ntuple(arg_copy, Val(length(args)))...;
        kwargs...)

    dres = deepcopy(res[1])::RT
    for v in dres.u
        v.= 0
    end
    tup = (dres, res[2])
    return EnzymeCore.EnzymeRules.AugmentedReturn{RT, RT, Any}(res[1], dres, tup::Any)
end

function EnzymeCore.EnzymeRules.reverse(config::EnzymeCore.EnzymeRules.ConfigWidth{1}, func::Const{typeof(DiffEqBase.solve_up)}, ::Type{<:Duplicated{RT}}, tape, prob, sensealg, u0, p, args...; kwargs...) where RT
	dres, clos = tape
    dres = dres::RT
	dargs = clos(dres)
    for (darg, ptr) in zip(dargs, (func, prob, sensealg, u0, p, args...))
        if ptr isa EnzymeCore.Const
            continue
        end
        if darg == ChainRulesCore.NoTangent()
            continue
        end
        ptr.dval .+= darg
    end
    for v in dres.u
        v.= 0
    end
    return ntuple(_ -> nothing, Val(length(args)+4))
end

end

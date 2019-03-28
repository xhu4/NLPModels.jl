#aSee JuliaSmoothOptimizers/NLPModels.jl/issues/113
__precompile__()

module NLPModels

using LinearAlgebra, LinearOperators, Printf, SparseArrays, FastClosures

export AbstractNLPModelMeta, NLPModelMeta, AbstractNLPModel, Counters
export reset!, sum_counters,
       obj, grad, grad!, objgrad, objgrad!, objcons, objcons!,
       cons, cons!, jth_con, jth_congrad, jth_congrad!, jth_sparse_congrad,
       jac_structure, jac_coord!, jac_coord,
       jac, jprod, jprod!, jtprod, jtprod!, jac_op, jac_op!,
       jth_hprod, jth_hprod!, ghjvprod, ghjvprod!,
       hess_structure!, hess_structure, hess_coord!, hess_coord, hess, hprod, hprod!, hess_op, hess_op!,
       push!,
       varscale, lagscale, conscale,
       NotImplementedError

# import methods we override
import Base.push!
import LinearOperators.reset!

include("nlp_utils.jl")
include("nlp_types.jl")
include("NLSModels.jl")

mutable struct NotImplementedError <: Exception
  name :: Union{Symbol,Function,String}
end

Base.showerror(io::IO, e::NotImplementedError) = print(io, e.name, " not implemented")

# simple default API for retrieving counters
for counter in fieldnames(Counters)
  @eval begin
    """`$($counter)(nlp)`

    Get the number of `$(split("$($counter)", "_")[2])` evaluations.
    """
    $counter(nlp :: AbstractNLPModel) = nlp.counters.$counter
    export $counter
  end
end

"""`increment!(nlp, s)`

Increment counter `s` of problem `nlp`.
"""
function increment!(nlp :: AbstractNLPModel, s :: Symbol)
  setfield!(nlp.counters, s, getfield(nlp.counters, s) + 1)
end

"""`sum_counters(counters)`

Sum all counters of `counters`.
"""
sum_counters(c :: Counters) = sum(getfield(c, x) for x in fieldnames(Counters))

"""`sum_counters(nlp)`

Sum all counters of problem `nlp`.
"""
sum_counters(nlp :: AbstractNLPModel) = sum_counters(nlp.counters)

"""`reset!(counters)`

Reset evaluation counters
"""
function reset!(counters :: Counters)
  for f in fieldnames(Counters)
    setfield!(counters, f, 0)
  end
  return counters
end

"""`reset!(nlp)

Reset evaluation count in `nlp`
"""
function reset!(nlp :: AbstractNLPModel)
  reset!(nlp.counters)
  return nlp
end

# Methods to be overridden in other packages.
"""`f = obj(nlp, x)`

Evaluate \$f(x)\$, the objective function of `nlp` at `x`.
"""
obj(::AbstractNLPModel, ::AbstractVector) =
  throw(NotImplementedError("obj"))

"""`g = grad(nlp, x)`

Evaluate \$\\nabla f(x)\$, the gradient of the objective function at `x`.
"""
function grad(nlp::AbstractNLPModel, x::AbstractVector)
  g = similar(x)
  return grad!(nlp, x, g)
end

"""`g = grad!(nlp, x, g)`

Evaluate \$\\nabla f(x)\$, the gradient of the objective function at `x` in place.
"""
grad!(::AbstractNLPModel, ::AbstractVector, ::AbstractVector) =
  throw(NotImplementedError("grad!"))

"""`c = cons(nlp, x)`

Evaluate \$c(x)\$, the constraints at `x`.
"""
function cons(nlp::AbstractNLPModel, x::AbstractVector)
  c = similar(x, nlp.meta.ncon)
  return cons!(nlp, x, c)
end

"""`c = cons!(nlp, x, c)`

Evaluate \$c(x)\$, the constraints at `x` in place.
"""
cons!(::AbstractNLPModel, ::AbstractVector, ::AbstractVector) =
  throw(NotImplementedError("cons!"))

jth_con(::AbstractNLPModel, ::AbstractVector, ::Integer) =
  throw(NotImplementedError("jth_con"))
jth_congrad(::AbstractNLPModel, ::AbstractVector, ::Integer) =
  throw(NotImplementedError("jth_congrad"))
jth_congrad!(::AbstractNLPModel, ::AbstractVector, ::Integer, ::AbstractVector) =
  throw(NotImplementedError("jth_congrad!"))
jth_sparse_congrad(::AbstractNLPModel, ::AbstractVector, ::Integer) =
  throw(NotImplementedError("jth_sparse_congrad"))

"""`f, c = objcons(nlp, x)`

Evaluate \$f(x)\$ and \$c(x)\$ at `x`.
"""
function objcons(nlp, x)
  f = obj(nlp, x)
  c = nlp.meta.ncon > 0 ? cons(nlp, x) : Float64[]
  return f, c
end

"""`f = objcons!(nlp, x, c)`

Evaluate \$f(x)\$ and \$c(x)\$ at `x`. `c` is overwritten with the value of \$c(x)\$.
"""
function objcons!(nlp, x, c)
  f = obj(nlp, x)
  nlp.meta.ncon > 0 && cons!(nlp, x, c)
  return f, c
end

"""`f, g = objgrad(nlp, x)`

Evaluate \$f(x)\$ and \$\\nabla f(x)\$ at `x`.
"""
function objgrad(nlp, x)
  f = obj(nlp, x)
  g = grad(nlp, x)
  return f, g
end

"""`f, g = objgrad!(nlp, x, g)`

Evaluate \$f(x)\$ and \$\\nabla f(x)\$ at `x`. `g` is overwritten with the
value of \$\\nabla f(x)\$.
"""
function objgrad!(nlp, x, g)
  f = obj(nlp, x)
  grad!(nlp, x, g)
  return f, g
end

"""`(rows,cols) = jac_structure(nlp)`

Returns the structure of the constraint's Jacobian in sparse coordinate format.
"""
jac_structure(:: AbstractNLPModel) = throw(NotImplementedError("jac_structure"))

"""`(rows,cols,vals) = jac_coord!(nlp, x, rows, cols, vals)`

Evaluate \$\\nabla c(x)\$, the constraint's Jacobian at `x` in sparse coordinate format,
rewriting `vals`. `rows` and `cols` are not rewritten.
"""
jac_coord!(:: AbstractNLPModel, :: AbstractVector) = throw(NotImplementedError("jac_coord!"))

"""`(rows,cols,vals) = jac_coord(nlp, x)`

Evaluate \$\\nabla c(x)\$, the constraint's Jacobian at `x` in sparse coordinate format.
"""
jac_coord(:: AbstractNLPModel, :: AbstractVector) = throw(NotImplementedError("jac_coord"))

"""`Jx = jac(nlp, x)`

Evaluate \$\\nabla c(x)\$, the constraint's Jacobian at `x` as a sparse matrix.
"""
jac(::AbstractNLPModel, ::AbstractVector) = throw(NotImplementedError("jac"))

"""`Jv = jprod(nlp, x, v)`

Evaluate \$\\nabla c(x)v\$, the Jacobian-vector product at `x`.
"""
function jprod(nlp::AbstractNLPModel, x::AbstractVector, v::AbstractVector)
  Jv = similar(v, nlp.meta.ncon)
  return jprod!(nlp, x, v, Jv)
end

"""`Jv = jprod!(nlp, x, v, Jv)`

Evaluate \$\\nabla c(x)v\$, the Jacobian-vector product at `x` in place.
"""
jprod!(::AbstractNLPModel, ::AbstractVector, ::AbstractVector, ::AbstractVector) =
  throw(NotImplementedError("jprod!"))

"""`Jtv = jtprod(nlp, x, v, Jtv)`

Evaluate \$\\nabla c(x)^Tv\$, the transposed-Jacobian-vector product at `x`.
"""
function jtprod(nlp::AbstractNLPModel, x::AbstractVector, v::AbstractVector)
  Jtv = similar(x)
  return jtprod!(nlp, x, v, Jtv)
end

"""`Jtv = jtprod!(nlp, x, v, Jtv)`

Evaluate \$\\nabla c(x)^Tv\$, the transposed-Jacobian-vector product at `x` in place.
"""
jtprod!(::AbstractNLPModel, ::AbstractVector, ::AbstractVector, ::AbstractVector) =
  throw(NotImplementedError("jtprod!"))

"""`J = jac_op(nlp, x)`

Return the Jacobian at `x` as a linear operator.
The resulting object may be used as if it were a matrix, e.g., `J * v` or
`J' * v`.
"""
function jac_op(nlp :: AbstractNLPModel, x :: AbstractVector)
  prod = @closure v -> jprod(nlp, x, v)
  ctprod = @closure v -> jtprod(nlp, x, v)
  F1 = typeof(prod)
  F3 = typeof(ctprod)
  return LinearOperator{Float64,F1,F3,F3}(nlp.meta.ncon, nlp.meta.nvar,
                                          false, false, prod, ctprod, ctprod)
end

"""`J = jac_op!(nlp, x, Jv, Jtv)`

Return the Jacobian at `x` as a linear operator.
The resulting object may be used as if it were a matrix, e.g., `J * v` or
`J' * v`. The values `Jv` and `Jtv` are used as preallocated storage for the
operations.
"""
function jac_op!(nlp :: AbstractNLPModel, x :: AbstractVector,
                 Jv :: AbstractVector, Jtv :: AbstractVector)
  prod = @closure v -> jprod!(nlp, x, v, Jv)
  ctprod = @closure v -> jtprod!(nlp, x, v, Jtv)
  F1 = typeof(prod)
  F3 = typeof(ctprod)
  return LinearOperator{Float64,F1,F3,F3}(nlp.meta.ncon, nlp.meta.nvar,
                                          false, false, prod, ctprod, ctprod)
end

jth_hprod(::AbstractNLPModel, ::AbstractVector, ::AbstractVector, ::Integer) =
  throw(NotImplementedError("jth_hprod"))
jth_hprod!(::AbstractNLPModel, ::AbstractVector, ::AbstractVector, ::Integer, ::AbstractVector) =
  throw(NotImplementedError("jth_hprod!"))
ghjvprod(::AbstractNLPModel, ::AbstractVector, ::AbstractVector, ::AbstractVector) =
  throw(NotImplementedError("ghjvprod"))
ghjvprod!(::AbstractNLPModel, ::AbstractVector, ::AbstractVector, ::AbstractVector, ::AbstractVector) =
  throw(NotImplementedError("ghjvprod!"))

"""`(rows,cols) = hess_structure(nlp)`

Returns the structure of the Lagrangian Hessian in sparse coordinate format.
"""
function hess_structure(nlp :: AbstractNLPModel)
  rows = Vector{Int}(undef, nlp.meta.nnzh)
  cols = Vector{Int}(undef, nlp.meta.nnzh)
  hess_structure!(nlp, rows, cols)
end

"""`hess_structure!(nlp, rows, cols)`

Returns the structure of the Lagrangian Hessian in sparse coordinate format in place.
"""
hess_structure!(:: AbstractNLPModel, ::AbstractVector{<: Integer}, ::AbstractVector{<: Integer}) = throw(NotImplementedError("hess_structure!"))

"""`(rows,cols,vals) = hess_coord!(nlp, x, rows, cols, vals; obj_weight=1.0, y=zeros)`

Evaluate the Lagrangian Hessian at `(x,y)` in sparse coordinate format,
with objective function scaled by `obj_weight`, i.e.,

\\\\[ \\nabla^2L(x,y) = \\sigma * \\nabla^2 f(x) + \\sum_{i=1}^m y_i\\nabla^2 c_i(x), \\\\]

with σ = obj_weight, rewriting `vals`. `rows` and `cols` are not rewritten.
Only the lower triangle is returned.
"""
hess_coord!(:: AbstractNLPModel, :: AbstractVector, ::AbstractVector{<: Integer}, ::AbstractVector{<: Integer}, ::AbstractVector; kwargs...) = throw(NotImplementedError("hess_coord!"))

"""`(rows,cols,vals) = hess_coord(nlp, x; obj_weight=1.0, y=zeros)`

Evaluate the Lagrangian Hessian at `(x,y)` in sparse coordinate format,
with objective function scaled by `obj_weight`, i.e.,

\\\\[ \\nabla^2L(x,y) = \\sigma * \\nabla^2 f(x) + \\sum_{i=1}^m y_i\\nabla^2 c_i(x), \\\\]

with σ = obj_weight.
Only the lower triangle is returned.
"""
hess_coord(nlp::AbstractNLPModel, x::AbstractVector; y::AbstractVector=Float64[], obj_weight::Real=1.0) = throw(NotImplementedError("hess_coord"))

"""`Hx = hess(nlp, x; obj_weight=1.0, y=zeros)`

Evaluate the Lagrangian Hessian at `(x,y)` as a sparse matrix,
with objective function scaled by `obj_weight`, i.e.,

\\\\[ \\nabla^2L(x,y) = \\sigma * \\nabla^2 f(x) + \\sum_{i=1}^m y_i\\nabla^2 c_i(x), \\\\]

with σ = obj_weight.
Only the lower triangle is returned.
"""
hess(::AbstractNLPModel, ::AbstractVector; kwargs...) =
  throw(NotImplementedError("hess"))

"""`Hv = hprod(nlp, x, v; obj_weight=1.0, y=zeros)`

Evaluate the product of the Lagrangian Hessian at `(x,y)` with the vector `v`,
with objective function scaled by `obj_weight`, i.e.,

\\\\[ \\nabla^2L(x,y) = \\sigma * \\nabla^2 f(x) + \\sum_{i=1}^m y_i\\nabla^2 c_i(x), \\\\]

with σ = obj_weight.
"""
function hprod(nlp::AbstractNLPModel, x::AbstractVector, v::AbstractVector; obj_weight::Real = one(eltype(x)), y::AbstractVector=similar(x, 0))
  Hv = similar(x)
  return hprod!(nlp, x, v, Hv, obj_weight=obj_weight, y=y)
end

"""`Hv = hprod!(nlp, x, v, Hv; obj_weight=1.0, y=zeros)`

Evaluate the product of the Lagrangian Hessian at `(x,y)` with the vector `v` in
place, with objective function scaled by `obj_weight`, i.e.,

\\\\[ \\nabla^2L(x,y) = \\sigma * \\nabla^2 f(x) + \\sum_{i=1}^m y_i\\nabla^2 c_i(x), \\\\]

with σ = obj_weight.
"""
hprod!(::AbstractNLPModel, ::AbstractVector, ::AbstractVector, ::AbstractVector; kwargs...) =
  throw(NotImplementedError("hprod!"))

"""`H = hess_op(nlp, x; obj_weight=1.0, y=zeros)`

Return the Lagrangian Hessian at `(x,y)` with objective function scaled by
`obj_weight` as a linear operator. The resulting object may be used as if it were a
matrix, e.g., `H * v`. The linear operator H represents

\\\\[ \\nabla^2L(x,y) = \\sigma * \\nabla^2 f(x) + \\sum_{i=1}^m y_i\\nabla^2 c_i(x), \\\\]

with σ = obj_weight.
"""
function hess_op(nlp :: AbstractNLPModel, x :: AbstractVector;
                 obj_weight :: Float64=1.0, y :: AbstractVector=zeros(nlp.meta.ncon))
  prod = @closure v -> hprod(nlp, x, v; obj_weight=obj_weight, y=y)
  F = typeof(prod)
  return LinearOperator{Float64,F,F,F}(nlp.meta.nvar, nlp.meta.nvar,
                                       true, true, prod, prod, prod)
end

"""`H = hess_op!(nlp, x, Hv; obj_weight=1.0, y=zeros)`

Return the Lagrangian Hessian at `(x,y)` with objective function scaled by
`obj_weight` as a linear operator, and storing the result on `Hv`. The resulting
object may be used as if it were a matrix, e.g., `w = H * v`. The vector `Hv` is
used as preallocated storage for the operation.  The linear operator H
represents

\\\\[ \\nabla^2L(x,y) = \\sigma * \\nabla^2 f(x) + \\sum_{i=1}^m y_i\\nabla^2 c_i(x), \\\\]

with σ = obj_weight.
"""
function hess_op!(nlp :: AbstractNLPModel, x :: AbstractVector, Hv :: AbstractVector;
                 obj_weight :: Float64=1.0, y :: AbstractVector=zeros(nlp.meta.ncon))
  prod = @closure v -> hprod!(nlp, x, v, Hv; obj_weight=obj_weight, y=y)
  F = typeof(prod)
  return LinearOperator{Float64,F,F,F}(nlp.meta.nvar, nlp.meta.nvar,
                                       true, true, prod, prod, prod)
end

push!(nlp :: AbstractNLPModel, args...; kwargs...) =
  throw(NotImplementedError("push!"))
varscale(::AbstractNLPModel, ::AbstractVector) =
  throw(NotImplementedError("varscale"))
lagscale(::AbstractNLPModel, ::Float64) =
  throw(NotImplementedError("lagscale"))
conscale(::AbstractNLPModel, ::AbstractVector) =
  throw(NotImplementedError("conscale"))

include("autodiff_model.jl")
include("slack_model.jl")
include("qn_model.jl")
include("feasibility_form_nls.jl")

include("dercheck.jl")

end # module

# Tutorial

NLPModels.jl was created for two purposes:

 - Allow users to access problem databases in an unified way.
 Mainly, this means
 [CUTEst.jl](https://github.com/JuliaSmoothOptimizers/CUTEst.jl),
 but it also gives access to [AMPL
 problems](https://github.com/JuliaSmoothOptimizers/AmplNLReader.jl),
 as well as JuMP defined problems (e.g. as in
 [OptimizationProblems.jl](https://github.com/JuliaSmoothOptimizers/OptimizationProblems.jl)).
 - Allows users to create their own problems in the same way.
 This means that an optimization method designed for NLPModels is
 interchangeable between models.
 See, for instance,
 [Optimize.jl](https://github.com/JuliaSmoothOptimizers/Optimize.jl).

The main interfaces for user defined problems are

- [ADNLPModel](models/#adnlpmodel), which defines a model very easily, using automatic
  differentiation.
- [SimpleNLPModel](models/#simplenlpmodel), which allows users to handle all functions himself,
  giving

## ADNLPModel Tutorial

ADNLPModel is very simple to use and is very useful for classrooms, for
instance.
It only needs the objective function $f$ and a starting point $x^0$ to be
well-defined.
For constrained problems, you'll also need the constraints function $c$, and
the constraints vectors $c_L$ and $c_U$, such that $c_L \leq c(x) \leq c_U$.
Equality constraints are identified by $c_{L_i} = c_{U_i}$.

Let's define the famous Rosenbrock function
\begin{align*}
f(x) = (x_1 - 1)^2 + 100(x_2 - x_1^2)^2,
\end{align*}
with starting point $x^0 = (-1.2,1.0)$.

```@example adnlp
using NLPModels

f(x) = (x[1] - 1.0)^2 + 100*(x[2] - x[1]^2)^2
x0 = [-1.2; 1.0]
nlp = ADNLPModel(f, x0)
```

This is enough to define the model.
Let's get the objective function value at $x^0$, using only `nlp`.

```@example adnlp
fx = obj(nlp, nlp.meta.x0)
println("fx = $fx")
```

Done.
Let's try the gradient and Hessian.

```@example adnlp
gx = grad(nlp, nlp.meta.x0)
Hx = hess(nlp, nlp.meta.x0)
println("gx = $gx")
println("Hx = $Hx")
```

Notice how only the lower triangle of the Hessian is stored.
Also notice that it is *dense*. This is a current limitation of this model. It
doesn't return sparse matrices, so use it with care.

Let's do something a little more complex here, defining a function to try to
solve this problem through gradient method with Armijo search.
Namely, the method

1. Given $x^0$, $\varepsilon > 0$, and $\eta \in (0,1)$. Set $k = 0$;
2. Compute $d^k = -\nabla f(x^k)$;
3. Compute $\alpha_k$ such that
$ f(x^k + \alpha_kd^k) < f(x^k) + \alpha_k\eta \nabla f(x^k)^Td^k $
4. Define $x^{k+1} = x^k + \alpha_kx^k$
5. Update $k = k + 1$
6. If $\Vert \nabla f(x^k) \Vert < \varepsilon$ STOP with $x^* = x^k$,
otherwise go to step 2.

```@example adnlp
function gradient(nlp; itmax=100000, eta=1e-2, eps=1e-6, sigma=0.9)
  x = nlp.meta.x0
  fx = obj(nlp, x)
  gx = grad(nlp, x)
  gtg = dot(gx, gx)
  ef = 0
  iter = 0
  while gtg > eps^2
    t = 1.0
    while obj(nlp, x - t*gx) > fx - eta*t*gtg
      t *= sigma
    end
    x = x - t*gx
    fx = obj(nlp, x)
    gx = grad(nlp, x)
    gtg = dot(gx, gx)
    iter += 1
    if iter >= itmax
      ef = 1
      break
    end
  end
  return x, fx, sqrt(gtg), ef, iter
end

x, fx, ngx, ef, iter = gradient(nlp)
println("x = $x")
println("fx = $fx")
println("ngx = $ngx")
println("ef = $ef")
println("iter = $iter")
```

Maybe this code is too complicated? If you're in a class you just want to show a
Newton step.

```@example adnlp
g(x) = grad(nlp, x)
H(x) = hess(nlp, x) + triu(hess(nlp, x)', 1)
x = nlp.meta.x0
d = -H(x)\g(x)
```

or a few

```@example adnlp
for i = 1:5
  x = x - H(x)\g(x)
  println("x = $x")
end
```

Also, notice how we can reuse the method.

```@example adnlp
f(x) = (x[1] + x[2] - 4)^2 + (x[1]*x[2] - 1)^2
x0 = [2.0; 1.0]
nlp = ADNLPModel(f, x0)

x, fx, ngx, ef, iter = gradient(nlp)
```

Even using a different model.

```@example adnlp
using OptimizationProblems

nlp = JuMPNLPModel(woods())
x, fx, ngx, ef, iter = gradient(nlp)
println("fx = $fx")
println("ngx = $ngx")
println("ef = $ef")
println("iter = $iter")
```

For constrained minimization, you need the constraints vector and bounds too.
Bounds on the variables can be passed through a new vector.

```@example adnlp
f(x) = (x[1] - 1.0)^2 + 100*(x[2] - x[1]^2)^2
x0 = [-1.2; 1.0]
lvar = [-Inf; 0.1]
uvar = [0.5; 0.5]
c(x) = [x[1] + x[2] - 2; x[1]^2 + x[2]^2]
lcon = [0.0; -Inf]
ucon = [Inf; 1.0]
nlp = ADNLPModel(f, x0, c=c, lvar=lvar, uvar=uvar, lcon=lcon, ucon=ucon)

println("cx = $(cons(nlp, nlp.meta.x0))")
println("Jx = $(jac(nlp, nlp.meta.x0))")
```

## SimpleNLPModel Tutorial

SimpleNLPModel allows you to pass every single function of the model.
On the other hand, it doesn't handle anything else. Calling an undefined
function will throw a `NotImplementedError`.
Only the objective function is mandaroty (if don't need it, pass `x->0`,
to quickly solve it).

```@example slp
using NLPModels

f(x) = (x[1] - 1.0)^2 + 4*(x[2] - 1.0)^2
x0 = zeros(2)
nlp = SimpleNLPModel(f, x0)

fx = obj(nlp, nlp.meta.x0)
println("fx = $fx")

# grad(nlp, nlp.meta.x0) # This is undefined
```

```@example slp
g(x) = [2*(x[1] - 1.0); 8*(x[2] - 1.0)]
nlp = SimpleNLPModel(f, x0, g=g)

grad(nlp, nlp.meta.x0)
```

"But what's to stop me from defining `g` however I want?"
Nothing. So you have to be careful on how you're defining it.
You should probably check your derivatives.
If the function is simply defined, you can try using automatic differentiation.
Alternatively, you can use the [derivative checker](dercheck).

```@example slp
gradient_check(nlp)
```

```@example slp
g(x) = [2*(x[1] - 1.0); 8*x[2] - 1.0] # Find the error
nlp = SimpleNLPModel(f, x0, g=g)
gradient_check(nlp)
```

For constrained problems, we still need the constraints function, `lcon` and `ucon`.
Also, let's pass the Jacobian-vector product.

```@example slp
c(x) = [x[1]^2 + x[2]^2; x[1]*x[2] - 1]
lcon = [1.0; 0.0]
ucon = [4.0; 0.0]
Jacprod(x, v) = [2*x[1]*v[1] + 2*x[2]*v[2]; x[2]*v[1] + x[1]*v[2]]
nlp = SimpleNLPModel(f, x0, c=c, lcon=lcon, ucon=ucon, g=g, Jp=Jacprod)
jprod(nlp, ones(2), ones(2))
```

Furthermore, NLPModels also works with inplace operations.
Since some models do not take full advantage of this (like ADNLPModel),
an user might want to define his own functions that do.

```@example slp
f(x) = (x[1] - 1.0)^2 + 4*(x[2] - 1.0)^2
x0 = zeros(2)
g!(x, gx) = begin
  gx[1] = 2*(x[1] - 1.0)
  gx[2] = 8*(x[2] = 1.0)
  return gx
end
nlp = SimpleNLPModel(f, x0, g! =g!) # Watchout, g!=g! is interpreted as g != g!
gx = zeros(2)
grad!(nlp, nlp.meta.x0, gx)
```
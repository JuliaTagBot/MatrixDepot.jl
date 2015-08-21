# Test matrices for regularization methods from Hansen's
# Regularization toolbox

# compute a oscillating matrix from a given signular value spectrum
# using the idea proposed by Per Christian Hansen, "Test matrices for
# regularization methods. 
function oscillate{T}(Σ::Vector{T})
    n = length(Σ)
    dv = rand(T, 1, n)[:] + eps(T)
    ev = rand(T, 1, n-1)[:] + eps(T)
    B = Bidiagonal(dv, ev, true)
    U, S, V = svd(B)
    return U*diagm(Σ)*U'
end
        

#  mode = 1: geometrically distributed singular values.
#  mode = 2: arithmetrically distributed singular values.
#  κ = sqrt(1/eps(T)) is the condition number of the matrix.
function oscillate{T}(::Type{T}, n::Int, mode::Int)
    κ = sqrt(1/eps(T))
    if mode == 1
        factor = κ^(-1/(n-1))
        Σ = factor.^[0:n-1;]
    elseif mode == 2
        Σ = ones(T, n) - T[0:n-1;]/(n-1)*(1 - 1/κ)
    else
        error("invalid mode value.")
    end
    return oscillate(Σ)
end
oscillate{T}(::Type{T}, n::Int) = oscillate(T, n, 2)


immutable RegProb{T}
    A::Matrix{T}  # matrix of interest
    b::Vector{T}  # right-hand side
    x::Vector{T}  # the solution to Ax = b
end

function show(io::IO, p::RegProb)
    println(io, "Test problems for Regularization Methods")
    println(io, "A:\n", p.A)
    println(io, "b:\n", p.b)
    println(io, "x:\n", p.x)
end

# The following test problems are derived from Per Christian Hansen's
# Regularization tools for MATLAB. 
# http://www.imm.dtu.dk/~pcha/Regutools/
#
# Copyright (c) 2015, Per Christian Hansen
# All rights reserved.
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are
# met:
#     * Redistributions of source code must retain the above copyright
#       notice, this list of conditions and the following disclaimer.
#     * Redistributions in binary form must reproduce the above copyright
#       notice, this list of conditions and the following disclaimer in
#       the documentation and/or other materials provided with the distribution
#     * Neither the name of the DTU Compute nor the names
#       of its contributors may be used to endorse or promote products derived
#       from this software without specific prior written permission.
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
# LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.


#
# Computation of the Second Derivative 
# 
function deriv2{T}(::Type{T}, n::Int)
    h = one(T)/n; sqh = sqrt(h); h32 = h*sqh; h2 = h^2; sqhi = 1/sqh
    t = 2/3; A = zeros(T, n, n)

    # compute A
    for i = 1:n
        A[i,i] = h2*((i^2 - i + 0.25)*h - (i - t))
        for j = 1:i-1
            A[i,j] = h2*(j - 0.5)*((i - 0.5)*h - 1)
        end
    end
    A = A + tril(A, -1)'

    # compute b
    b = zeros(T, n)
    [b[i] = h32*(i - 0.5)*((i^2 + (i-1)^2)*h2/2 - 1)/6 for i = 1:n]

    # compute x
    x = zeros(T, n)
    [x[i] = h32*(i - 0.5) for i = 1:n]
    
    return RegProb(A, b, x)
end

#
# One-Dimensional Image Restoration Model
# 
function shaw{T}(::Type{T}, n::Int)
    mod(n, 2) == 0 || error("The dimension of the matrix must be even.")
    h = pi/n; A = zeros(T, n, n)
    
    # compute A
    co = cos(-pi/2 + T[.5:n-.5;]*h)
    psi = pi*sin(-pi/2 + T[.5:n-.5;]*h)
    for i = 1:div(n,2)
        for j = i:n-i
            ss = psi[i] +psi[j]
            A[i,j] = ((co[i] + co[j])*sin(ss)/ss)^2
            A[n-j+1, n-i+1] = A[i,j]
        end
        A[i, n-i+1] = (2*co[i])^2
    end
    A = A + triu(A, 1)'; A = A*h
    
    # compute x and b
    a1 = 2; c1 = 6; t1 = .8
    a2 = 1; c2 = 2; t2 = -.5
    x = a1*exp(-c1*(-pi/2 + T[.5:n-.5;]*h - t1).^2) + 
        a2*exp(-c2*(-pi/2 + T[.5:n-.5;]*h - t2).^2)
    b = A*x

    return RegProb(A, b, x)
end

#
# A Problem with a Discontinuous Solution
#
function wing{T}(::Type{T}, n::Int, t1::Real, t2::Real)
    t1 < t2 || error("t1 must be smaller than t2")
    A = zeros(T, n, n); h = 1/n
    
    # compute A
    sti = (T[1:n;]-0.5)*h
    [A[i,:] = h*sti.*exp(-sti[i] * sti.^2) for i = 1:n]

    # compute b
    b = sqrt(h)*0.5*(exp(-sti*t1^2) - exp(-sti*t2^2))./sti

    # compute x
    indices = [findfirst(t1 .< sti, true): findlast(t2 .> sti, true);]
    x = zeros(T,n); x[indices] = sqrt(h)*ones(length(indices))

    return RegProb(A, b, x)
end
wing{T}(::Type{T}, n::Int) = wing(T, n, 1/3, 2/3)

#
# Severely Ill-posed Problem Suggested by Fox & Goodwin
#
function foxgood{T}(::Type{T}, n::Int)
    h = 1/n; t = h*(T[1:n;] - one(T)/2)

    A = h*sqrt((t.^2)*ones(T,n)' + ones(T, n) * (t.^2)')
    x = t
    b = zeros(T, n)
    [b[i] = ((one(T) + t[i]^2)^1.5 - t[i]^3)/3 for i in 1:n]

    return RegProb(A, b, x)
end

#
# Inverse Heat Equation
#
function heat{T}(::Type{T}, n::Int, κ::Real)
    mod(n, 2) == 0 || error("The dimension of the matrix must be even.")
    h = one(T)/n; t = T[h/2:h:1;]
    c = h/(2*κ*T(sqrt(pi)))
    d = one(T)/(4*κ^2)

    # compute the matrix A
    m = length(t); k = zeros(T, m)
    [k[i] = c*t[i]^(-1.5)*exp(-d/t[i]) for i in 1:m]
    r = zeros(T, m); r[1] = k[1]
    A = toeplitz(k, r)

    # compute the vectors x and b
    x = zeros(T, n)
    for i = 1:div(n,2) # 
        ti = i*20/n
        if ti < 2
            x[i] = 0.75*ti^2/4
        elseif ti < 3
            x[i] = 0.75 + (ti - 2)*(3 - ti)
        else
            x[i] = 0.75*exp(-(ti - 3)*2)
        end
    end
    x[div(n,2)+1:n] = zeros(T, div(n, 2))
    b = A*x
    return RegProb(A, b, x)
end
heat{T}(::Type{T}, n::Int) = heat(T, n, 1)

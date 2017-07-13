# This file is a part of Julia. License is MIT: https://julialang.org/license

mutable struct Set{T} <: AbstractSet{T}
    dict::Dict{T,Void}

    Set{T}() where {T} = new(Dict{T,Void}())
    Set{T}(itr) where {T} = union!(new(Dict{T,Void}()), itr)
end
Set() = Set{Any}()

"""
    Set([itr])

Construct a [`Set`](@ref) of the values generated by the given iterable object, or an
empty set. Should be used instead of [`IntSet`](@ref) for sparse integer sets, or
for sets of arbitrary objects.
"""
Set(itr) = Set{eltype(itr)}(itr)
function Set(g::Generator)
    T = _default_eltype(typeof(g))
    (_isleaftype(T) || T === Union{}) || return grow_to!(Set{T}(), g)
    return Set{T}(g)
end

eltype(::Type{Set{T}}) where {T} = T
similar(s::Set{T}) where {T} = Set{T}()
similar(s::Set, T::Type) = Set{T}()

function show(io::IO, s::Set)
    print(io, "Set")
    if isempty(s)
        print(io, "{", eltype(s), "}()")
        return
    end
    print(io, "(")
    show_vector(io, s, "[", "]")
    print(io, ")")
end

isempty(s::Set) = isempty(s.dict)
length(s::Set)  = length(s.dict)
in(x, s::Set) = haskey(s.dict, x)
push!(s::Set, x) = (s.dict[x] = nothing; s)
pop!(s::Set, x) = (pop!(s.dict, x); x)
pop!(s::Set, x, deflt) = x in s ? pop!(s, x) : deflt

function pop!(s::Set)
    isempty(s) && throw(ArgumentError("set must be non-empty"))
    idx = start(s.dict)
    val = s.dict.keys[idx]
    _delete!(s.dict, idx)
    val
end

delete!(s::Set, x) = (delete!(s.dict, x); s)

copy(s::Set) = union!(similar(s), s)

sizehint!(s::Set, newsz) = (sizehint!(s.dict, newsz); s)
empty!(s::Set) = (empty!(s.dict); s)
rehash!(s::Set) = (rehash!(s.dict); s)

start(s::Set)       = start(s.dict)
done(s::Set, state) = done(s.dict, state)
# NOTE: manually optimized to take advantage of Dict representation
next(s::Set, i)     = (s.dict.keys[i], skip_deleted(s.dict, i+1))

"""
    union(s1,s2...)
    ∪(s1,s2...)

Construct the union of two or more sets. Maintains order with arrays.

# Examples
```jldoctest
julia> union([1, 2], [3, 4])
4-element Array{Int64,1}:
 1
 2
 3
 4

julia> union([1, 2], [2, 4])
3-element Array{Int64,1}:
 1
 2
 4

julia> union([4, 2], [1, 2])
3-element Array{Int64,1}:
 4
 2
 1
```
"""
function union end

union(s::Set) = copy(s)
function union(s::Set, sets...)
    u = Set{join_eltype(s, sets...)}()
    union!(u, s)
    for t in sets
        union!(u, t)
    end
    return u
end
const ∪ = union

"""
    union!(s, iterable)

Union each element of `iterable` into set `s` in-place.

# Examples
```jldoctest
julia> a = Set([1, 3, 4, 5]);

julia> union!(a, 1:2:8);

julia> a
Set([7, 4, 3, 5, 1])
```
"""
function union!(s::Set{T}, xs) where T
    haslength(xs) && sizehint!(s, length(xs))
    for x=xs
        push!(s, x)
        length(s) == max_values(T) && break
    end
    s
end

join_eltype() = Bottom
join_eltype(v1, vs...) = typejoin(eltype(v1), join_eltype(vs...))

"""
    intersect(s1,s2...)
    ∩(s1,s2)

Construct the intersection of two or more sets.
Maintains order and multiplicity of the first argument for arrays and ranges.

# Examples
```jldoctest
julia> intersect([1, 2, 3], [3, 4, 5])
1-element Array{Int64,1}:
 3

julia> intersect([1, 4, 4, 5, 6], [4, 6, 6, 7, 8])
3-element Array{Int64,1}:
 4
 4
 6
```
"""
function intersect end

intersect(s::Set) = copy(s)
function intersect(s::Set, sets...)
    i = similar(s)
    for x in s
        inall = true
        for t in sets
            if !in(x, t)
                inall = false
                break
            end
        end
        inall && push!(i, x)
    end
    return i
end
const ∩ = intersect

function setdiff(a::Set, b)
    d = similar(a)
    for x in a
        if !(x in b)
            push!(d, x)
        end
    end
    d
end

"""
    setdiff!(s, iterable)

Remove each element of `iterable` from set `s` in-place.

# Examples
```jldoctest
julia> a = Set([1, 3, 4, 5]);

julia> setdiff!(a, 1:2:6);

julia> a
Set([4])
```
"""
setdiff!(s::Set, xs) = (for x=xs; delete!(s, x); end; s)

==(l::Set, r::Set) = (length(l) == length(r)) && (l <= r)
<( l::Set, r::Set) = (length(l) < length(r)) && (l <= r)
<=(l::Set, r::Set) = issubset(l, r)

"""
    issubset(a, b)
    ⊆(a,b) -> Bool
    ⊈(a,b) -> Bool
    ⊊(a,b) -> Bool

Determine whether every element of `a` is also in `b`, using [`in`](@ref).

# Examples
```jldoctest
julia> issubset([1, 2], [1, 2, 3])
true

julia> issubset([1, 2, 3], [1, 2])
false
```
"""
function issubset(l, r)
    for elt in l
        if !in(elt, r)
            return false
        end
    end
    return true
end
const ⊆ = issubset
⊊(l::Set, r::Set) = <(l, r)
⊈(l::Set, r::Set) = !⊆(l, r)
⊇(l, r) = issubset(r, l)
⊉(l::Set, r::Set) = !⊇(l, r)
⊋(l::Set, r::Set) = <(r, l)

"""
    unique(itr)

Return an array containing only the unique elements of collection `itr`,
as determined by [`isequal`](@ref), in the order that the first of each
set of equivalent elements originally appears. The element type of the
input is preserved.

# Examples
```jldoctest
julia> unique([1, 2, 6, 2])
3-element Array{Int64,1}:
 1
 2
 6

julia> unique(Real[1, 1.0, 2])
2-element Array{Real,1}:
 1
 2
```
"""
function unique(itr)
    T = _default_eltype(typeof(itr))
    out = Vector{T}()
    seen = Set{T}()
    i = start(itr)
    if done(itr, i)
        return out
    end
    x, i = next(itr, i)
    if !_isleaftype(T) && iteratoreltype(itr) == EltypeUnknown()
        S = typeof(x)
        return _unique_from(itr, S[x], Set{S}((x,)), i)
    end
    push!(seen, x)
    push!(out, x)
    return unique_from(itr, out, seen, i)
end

_unique_from(itr, out, seen, i) = unique_from(itr, out, seen, i)
@inline function unique_from(itr, out::Vector{T}, seen, i) where T
    while !done(itr, i)
        x, i = next(itr, i)
        S = typeof(x)
        if !(S === T || S <: T)
            R = typejoin(S, T)
            seenR = convert(Set{R}, seen)
            outR = convert(Vector{R}, out)
            if !in(x, seenR)
                push!(seenR, x)
                push!(outR, x)
            end
            return _unique_from(itr, outR, seenR, i)
        end
        if !in(x, seen)
            push!(seen, x)
            push!(out, x)
        end
    end
    return out
end

"""
    unique(f, itr)

Returns an array containing one value from `itr` for each unique value produced by `f`
applied to elements of `itr`.

# Examples
```jldoctest
julia> unique(x -> x^2, [1, -1, 3, -3, 4])
3-element Array{Int64,1}:
 1
 3
 4
```
"""
function unique(f::Callable, C)
    out = Vector{eltype(C)}()
    seen = Set()
    for x in C
        y = f(x)
        if !in(y, seen)
            push!(seen, y)
            push!(out, x)
        end
    end
    out
end

# If A is not grouped, then we will need to keep track of all of the elements that we have
# seen so far.
function _unique!(A::AbstractVector)
    seen = Set{eltype(A)}()
    idxs = eachindex(A)
    i = state = start(idxs)
    for x in A
        if x ∉ seen
            push!(seen, x)
            i, state = next(idxs, state)
            A[i] = x
        end
    end
    resize!(A, i - first(idxs) + 1)
end

# If A is grouped, so that each unique element is in a contiguous group, then we only
# need to keep track of one element at a time. We replace the elements of A with the
# unique elements that we see in the order that we see them. Once we have iterated
# through A, we resize A based on the number of unique elements that we see.
function _groupedunique!(A::AbstractVector)
    isempty(A) && return A
    idxs = eachindex(A)
    y = first(A)
    state = start(idxs)
    i, state = next(idxs, state)
    for x in A
        if !isequal(x, y)
            i, state = next(idxs, state)
            y = A[i] = x
        end
    end
    resize!(A, i - first(idxs) + 1)
end

"""
    unique!(A::AbstractVector)

Remove duplicate items as determined by [`isequal`](@ref), then return the modified `A`.
`unique!` will return the elements of `A` in the order that they occur. If you do not care
about the order of the returned data, then calling `(sort!(A); unique!(A))` will be much
more efficient as long as the elements of `A` can be sorted.

# Examples
```jldoctest
julia> unique!([1, 1, 1])
1-element Array{Int64,1}:
 1

julia> A = [7, 3, 2, 3, 7, 5];

julia> unique!(A)
4-element Array{Int64,1}:
 7
 3
 2
 5

julia> B = [7, 6, 42, 6, 7, 42];

julia> sort!(B);  # unique! is able to process sorted data much more efficiently.

julia> unique!(B)
3-element Array{Int64,1}:
  6
  7
 42
```
"""
function unique!(A::Union{AbstractVector{<:Real}, AbstractVector{<:AbstractString},
                          AbstractVector{<:Symbol}})
    if isempty(A)
        return A
    elseif issorted(A) || issorted(A, rev=true)
        return _groupedunique!(A)
    else
        return _unique!(A)
    end
end
# issorted fails for some element types, so the method above has to be restricted to
# elements with isless/< defined.
function unique!(A)
    if isempty(A)
        return A
    else
        return _unique!(A)
    end
end

"""
    allunique(itr) -> Bool

Return `true` if all values from `itr` are distinct when compared with [`isequal`](@ref).

# Examples
```jldoctest
julia> a = [1; 2; 3]
3-element Array{Int64,1}:
 1
 2
 3

julia> allunique([a, a])
false
```
"""
function allunique(C)
    seen = Set{eltype(C)}()
    for x in C
        if in(x, seen)
            return false
        else
            push!(seen, x)
        end
    end
    true
end

allunique(::Set) = true

allunique(r::AbstractRange{T}) where {T} = (step(r) != zero(T)) || (length(r) <= 1)

function filter(f, s::Set)
    u = similar(s)
    for x in s
        if f(x)
            push!(u, x)
        end
    end
    return u
end
function filter!(f, s::Set)
    for x in s
        if !f(x)
            delete!(s, x)
        end
    end
    return s
end

const hashs_seed = UInt === UInt64 ? 0x852ada37cfe8e0ce : 0xcfe8e0ce
function hash(s::Set, h::UInt)
    h = hash(hashs_seed, h)
    for x in s
        h ⊻= hash(x)
    end
    return h
end

convert(::Type{Set{T}}, s::Set{T}) where {T} = s
convert(::Type{Set{T}}, x::Set) where {T} = Set{T}(x)

# replace!

askey(k, ::Associative) = k.first
askey(k, ::AbstractSet) = k

function _replace!(prednew::Callable, A::Union{Associative,AbstractSet}, count::Int)
    count < 0 && throw(DomainError(count, "`count` must not be negative"))
    count == 0 && return A
    repl = Pair{eltype(A),eltype(A)}[]
    c = 0
    for x in A
        y = prednew(x)
        if !isnull(y)
            push!(repl, x => unsafe_get(y))
            c += 1
            c == count && break
        end
    end
    for oldnew in repl
        pop!(A, askey(first(oldnew), A))
        push!(A, last(oldnew))
    end
    A
end

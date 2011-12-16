## subarrays ##

type SubArray{T,N,A<:AbstractArray,I<:(RangeIndex...,)} <: AbstractArray{T,N}
    parent::A
    indexes::I
    dims::Dims
    strides::Array{Long,1}
    first_index::Long

    #linear indexing constructor
    if N == 1 && length(I) == 1 && A <: Array
        function SubArray(p::A, i::(Long,))
            new(p, i, (length(i[1]),), [1], i[1])
        end
        function SubArray(p::A, i::(Range1{Long},))
            new(p, i, (length(i[1]),), [1], i[1].start)
        end
        function SubArray(p::A, i::(Range{Long},))
            new(p, i, (length(i[1]),), [i[1].step], i[1].start)
        end
    else
        function SubArray(p::A, i::I)
            newdims = Array(Long, 0)
            newstrides = Array(Long, 0)
            newfirst = 1
            pstrides = strides(p)
            for j = 1:length(i)
                if isa(i[j], Long)
                    newfirst += (i[j]-1)*pstrides[j]
                else
                    push(newdims, length(i[j]))
                    #may want to return error if i[j].step <= 0
                    push(newstrides, isa(i[j],Range1) ? pstrides[j] :
                         pstrides[j] * i[j].step)
                    newfirst += (i[j].start-1)*pstrides[j]
                end
            end
            new(p, i, tuple(newdims...), newstrides, newfirst)
        end
    end
end

#linear indexing sub (may want to rename as slice)
function sub{T,N}(A::Array{T,N}, i::(RangeIndex,))
    SubArray{T,1,typeof(A),typeof(i)}(A, i)
end

function sub{T,N}(A::AbstractArray{T,N}, i::NTuple{N,RangeIndex})
    i = map(j -> isa(j, Long) ? (j:j) : j, i)
    SubArray{T,N,typeof(A),typeof(i)}(A, i)
end
sub(A::AbstractArray, i::RangeIndex...) =
    sub(A, i)
function sub(A::SubArray, i::RangeIndex...)
    j = 1
    newindexes = Array(RangeIndex,length(A.indexes))
    for k = 1:length(A.indexes)
        if isa(A.indexes[k], Long)
            newindexes[k] = A.indexes[k]
        else
            newindexes[k] = A.indexes[k][isa(i[j],Long) ? (i[j]:i[j]) : i[j]]
            j += 1
        end
    end
    sub(A.parent, tuple(newindexes...))
end

function slice{T,N}(A::AbstractArray{T,N}, i::NTuple{N,RangeIndex})
    n = 0
    for j = i; if !isa(j, Long); n += 1; end; end
    SubArray{T,n,typeof(A),typeof(i)}(A, i)
end

slice(A::AbstractArray, i::RangeIndex...) = slice(A, i)

function slice(A::SubArray, i::RangeIndex...)
    j = 1
    newindexes = Array(RangeIndex,length(A.indexes))
    for k = 1:length(A.indexes)
        if isa(A.indexes[k], Long)
            newindexes[k] = A.indexes[k]
        else
            newindexes[k] = A.indexes[k][i[j]]
            j += 1
        end
    end
    slice(A.parent, tuple(newindexes...))
end

### rename the old slice function ###
##squeeze all dimensions of length 1
#slice{T,N}(a::AbstractArray{T,N}) = sub(a, map(i-> i == 1 ? 1 : (1:i), size(a)))
#slice{T,N}(s::SubArray{T,N}) =
#    sub(s.parent, map(i->!isa(i, Long) && length(i)==1 ?i[1] : i, s.indexes))
#
##slice dimensions listed, error if any have length > 1
##silently ignores dimensions that are greater than N
#function slice{T,N}(a::AbstractArray{T,N}, sdims::Integer...)
#    newdims = ()
#    for i = 1:N
#        next = 1:size(a, i)
#        for j = sdims
#            if i == j
#                if size(a, i) != 1
#                    error("slice: dimension ", i, " has length greater than 1")
#                end
#                next = 1
#                break
#            end
#        end
#        newdims = tuple(newdims..., next)
#    end
#    sub(a, newdims)
#end
#function slice{T,N}(s::SubArray{T,N}, sdims::Integer...)
#    newdims = ()
#    for i = 1:length(s.indexes)
#        next = s.indexes[i]
#        for j = sdims
#            if i == j
#                if length(next) != 1
#                    error("slice: dimension ", i," has length greater than 1")
#                end
#                next = isa(next, Long) ? next : next.start
#                break
#            end
#        end
#        newdims = tuple(newdims..., next)
#    end
#    sub(s.parent, newdims)
#end
### end commented code ###

size(s::SubArray) = s.dims
ndims{T,N}(s::SubArray{T,N}) = N

copy(s::SubArray) = copy_to(similar(s.parent, size(s)), s)
similar(s::SubArray, T, dims::Dims) = similar(s.parent, T, dims)

ref{T}(s::SubArray{T,0,AbstractArray{T,0}}) = s.parent[]
ref{T}(s::SubArray{T,0}) = s.parent[s.first_index]

ref{T}(s::SubArray{T,1}, i::Integer) = s.parent[s.first_index + (i-1)*s.strides[1]]
ref{T}(s::SubArray{T,2}, i::Integer, j::Integer) =
    s.parent[s.first_index + (i-1)*s.strides[1] + (j-1)*s.strides[2]]

ref(s::SubArray, i::Integer) = s[ind2sub(size(s), i)...]

function ref{T}(s::SubArray{T,2}, ind::Integer)
    ld = size(s,1)
    i = rem(ind-1,ld)+1
    j = div(ind-1,ld)+1
    s.parent[s.first_index + (i-1)*s.strides[1] + (j-1)*s.strides[2]]
end

function ref(s::SubArray, is::Integer...)
    index = s.first_index
    for i = 1:length(is)
        index += (is[i]-1)*s.strides[i]
    end
    s.parent[index]
end

ref{T}(s::SubArray{T,1}, I::Range1{Long}) =
    ref(s.parent, (s.first_index+(I.start-1)*s.strides[1]):s.strides[1]:(s.first_index+(I.stop-1)*s.strides[1]))

ref{T}(s::SubArray{T,1}, I::Range{Long}) =
    ref(s.parent, (s.first_index+(I.start-1)*s.strides[1]):(s.strides[1]*I.step):(s.first_index+(I.stop-1)*s.strides[1]))

function ref{T,S<:Integer}(s::SubArray{T,1}, I::AbstractVector{S})
    t = Array(Long, length(I))
    for i = 1:length(I)
        t[i] = s.first_index + (I[i]-1)*s.strides[1]
    end
    ref(s.parent, t)
end

function ref(s::SubArray, I::Indices...)
    j = 1 #the jth dimension in subarray
    n = ndims(s.parent)
    newindexes = Array(Indices, n)
    for i = 1:n
        t = s.indexes[i]
        #TODO: don't generate the dense vector indexes if they can be ranges
        newindexes[i] = isa(t, Long) ? t : t[I[j]]
        j += 1
    end

    reshape(ref(s.parent, newindexes...), map(length, I))
end

assign(s::SubArray, v::AbstractArray, i::Integer) =
    invoke(assign, (SubArray, Any, Integer), s, v, i)

assign(s::SubArray, v, i::Integer) = assign(s, v, ind2sub(size(s), i)...)

assign{T}(s::SubArray{T,2}, v::AbstractArray, ind::Integer) =
    invoke(assign, (SubArray{T,2}, Any, Integer), a, v, ind)

function assign{T}(s::SubArray{T,2}, v, ind::Integer)
    ld = size(s,1)
    i = rem(ind-1,ld)+1
    j = div(ind-1,ld)+1
    s.parent[s.first_index + (i-1)*s.strides[1] + (j-1)*s.strides[2]] = v
    return s
end

assign(s::SubArray, v::AbstractArray, i::Integer, is::Integer...) =
    invoke(assign, (SubArray, Any, Integer...), s, v, tuple(i,is...))

assign(s::SubArray, v::AbstractArray, is::Integer...) =
    invoke(assign, (SubArray, Any, Integer...), s, v, is)

function assign(s::SubArray, v, is::Integer...)
    index = s.first_index
    for i = 1:length(is)
        index += (is[i]-1)*s.strides[i]
    end
    s.parent[index] = v
    return s
end

assign{T}(s::SubArray{T,0,AbstractArray{T,0}}, v::AbstractArray) =
    (s.parent[]=v; s)

assign{T}(s::SubArray{T,0,AbstractArray{T,0}},v) = (s.parent[]=v; s)

assign{T}(s::SubArray{T,0}, v::AbstractArray) =
    (s.parent[s.first_index]=v; s)

assign{T}(s::SubArray{T,0}, v) = (s.parent[s.first_index]=v; s)


assign{T}(s::SubArray{T,1}, v::AbstractArray, i::Integer) =
    (s.parent[s.first_index + (i-1)*s.strides[1]] = v; s)

assign{T}(s::SubArray{T,1}, v, i::Integer) =
    (s.parent[s.first_index + (i-1)*s.strides[1]] = v; s)

assign{T}(s::SubArray{T,2}, v::AbstractArray, i::Integer, j::Integer) =
    (s.parent[s.first_index +(i-1)*s.strides[1]+(j-1)*s.strides[2]] = v; s)

assign{T}(s::SubArray{T,2}, v, i::Integer, j::Integer) =
    (s.parent[s.first_index +(i-1)*s.strides[1]+(j-1)*s.strides[2]] = v; s)

assign{T}(s::SubArray{T,1}, v::AbstractArray, I::Range1{Long}) =
    assign(s.parent, v, (s.first_index+(I.start-1)*s.strides[1]):s.strides[1]:(s.first_index+(I.stop-1)*s.strides[1]))

assign{T}(s::SubArray{T,1}, v, I::Range1{Long}) =
    assign(s.parent, v, (s.first_index+(I.start-1)*s.strides[1]):s.strides[1]:(s.first_index+(I.stop-1)*s.strides[1]))

assign{T}(s::SubArray{T,1}, v::AbstractArray, I::Range{Long}) =
    assign(s.parent, v, (s.first_index+(I.start-1)*s.strides[1]):(s.strides[1]*I.step):(s.first_index+(I.stop-1)*s.strides[1]))

assign{T}(s::SubArray{T,1}, v, I::Range{Long}) =
    assign(s.parent, v, (s.first_index+(I.start-1)*s.strides[1]):(s.strides[1]*I.step):(s.first_index+(I.stop-1)*s.strides[1]))

function assign{T,S<:Integer}(s::SubArray{T,1}, v::AbstractArray, I::AbstractVector{S})
    t = Array(Long, length(I))
    for i = 1:length(I)
        t[i] = s.first_index + (I[i]-1)*s.strides[1]
    end
    assign(s.parent, v, t)
end

function assign{T,S<:Integer}(s::SubArray{T,1}, v, I::AbstractVector{S})
    t = Array(Long, length(I))
    for i = 1:length(I)
        t[i] = s.first_index + (I[i]-1)*s.strides[1]
    end
    assign(s.parent, v, t)
end

function assign(s::SubArray, v::AbstractArray, I::Indices...)
    j = 1 #the jth dimension in subarray
    n = ndims(s.parent)
    newindexes = cell(n)
    for i = 1:n
        t = s.indexes[i]
        #TODO: don't generate the dense vector indexes if they can be ranges
        newindexes[i] = isa(t, Long) ? t : t[I[j]]
        j += 1
    end

    assign(s.parent, reshape(v, map(length, I)), newindexes...)
end

function assign(s::SubArray, v, I::Indices...)
    j = 1 #the jth dimension in subarray
    n = ndims(s.parent)
    newindexes = cell(n)
    for i = 1:n
        t = s.indexes[i]
        #TODO: don't generate the dense vector indexes if they can be ranges
        newindexes[i] = isa(t, Long) ? t : t[I[j]]
        j += 1
    end

    assign(s.parent, v, newindexes...)
end

strides(s::SubArray) = tuple(s.strides...)

stride(s::SubArray, i::Integer) = s.strides[i]

convert{T}(::Type{Ptr}, x::SubArray{T}) =
    pointer(x.parent) + (x.first_index-1)*sizeof(T)

pointer(s::SubArray, i::Long) = pointer(s, ind2sub(size(s), i))

function pointer{T}(s::SubArray{T}, is::(Long...))
    index = s.first_index
    for n = 1:length(is)
        index += (is[n]-1)*s.strides[n]
    end
    return pointer(s.parent, index)
end

summary{T,N}(s::SubArray{T,N}) =
    strcat(dims2string(size(s)), " SubArray of ", summary(s.parent))

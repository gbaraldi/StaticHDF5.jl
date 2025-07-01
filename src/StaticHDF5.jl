module StaticHDF5

export open_file, create_file, close_file
export write_object, read_object
export open_group, create_group, close_group, list_objects
export get_dataset_info, is_dataset, is_group
export READ_ONLY, READ_WRITE, CREATE  # Export the constants

include("api/api.jl")
using .API

# Constants for file access modes
const READ_ONLY = API.H5F_ACC_RDONLY
const READ_WRITE = API.H5F_ACC_RDWR
const CREATE = API.H5F_ACC_TRUNC

abstract type HDF5Object end

"""
    HDF5File

A handle to an HDF5 file.
"""
struct HDF5File <: HDF5Object
    file_id::API.hid_t
end

"""
    HDF5Group

A handle to an HDF5 group.
"""
struct HDF5Group <: HDF5Object
    group_id::API.hid_t
end

get_hid(obj::HDF5File) = obj.file_id
get_hid(obj::HDF5Group) = obj.group_id

"""
    open_file(filename::String, mode::Integer=READ_ONLY) -> HDF5File

Open an HDF5 file with the specified access mode.
Returns a file identifier that should be closed with `close_file`.

# Arguments
- `filename`: Path to the HDF5 file
- `mode`: File access mode (READ_ONLY, READ_WRITE)

# Example
```julia
file = open_file("data.h5")
# ... operations on file ...
close_file(file)
```
"""
function open_file(filename::String, mode::Integer = READ_ONLY)
    file_id = API.h5f_open(filename, mode, API.H5P_DEFAULT)
    return HDF5File(file_id)
end

"""
    create_file(filename::String, mode::Integer=CREATE) -> HDF5File

Create a new HDF5 file.
Returns a file identifier that should be closed with `close_file`.

# Arguments
- `filename`: Path to the HDF5 file to create
- `mode`: File creation mode (default: CREATE which truncates existing files)

# Example
```julia
file = create_file("new_data.h5")
# ... operations on file ...
close_file(file)
```
"""
function create_file(filename::String, mode::Integer = CREATE)
    file_id = API.h5f_create(filename, mode, API.H5P_DEFAULT, API.H5P_DEFAULT)
    return HDF5File(file_id)
end

"""
    close_file(file::HDF5File)

Close an HDF5 file.

# Arguments
- `file`: File identifier returned by `open_file` or `create_file`
"""
function close_file(file::HDF5File)
    API.h5f_close(get_hid(file))
    return nothing
end

"""
    create_group(object::HDF5Object, group_name::String) -> HDF5Group

Create a new group in the HDF5 file.
Returns a group identifier that should be closed with `close_group`.

# Arguments
- `object`: HDF5 object (file, group)
- `group_name`: Name of the group to create

# Example
```julia
file = create_file("data.h5")
group = create_group(file, "measurements")
# ... operations on group ...
close_group(group)
close_file(file)
```
"""
function create_group(file::HDF5Object, group_name::String)
    group_id = API.h5g_create(get_hid(file), group_name, API.H5P_DEFAULT, API.H5P_DEFAULT, API.H5P_DEFAULT)
    return HDF5Group(group_id)
end

"""
    open_group(file::HDF5Object, group_name::String) -> HDF5Group

Open an existing group in the HDF5 file.
Returns a group identifier that should be closed with `close_group`.

# Arguments
- `object`: HDF5 object (file, group)
- `group_name`: Name of the group to open

# Example
```julia
group = open_group(file, "measurements")
# ... operations on group ...
close_group(group)
```
"""
function open_group(file::HDF5Object, group_name::String)
    group_id = API.h5g_open(get_hid(file), group_name, API.H5P_DEFAULT)
    return HDF5Group(group_id)
end

"""
    close_group(group::HDF5Group)

Close an HDF5 group.

# Arguments
- `group`: Group identifier returned by `create_group`
"""
function close_group(group::HDF5Group)
    API.h5g_close(get_hid(group))
    return nothing
end

"""
    write_object(object::HDF5Object, dataset_name::String, data::AbstractArray)

Write an array to an HDF5 object.

This converts to a regular Array before writing.
# Arguments
- `object`: HDF5 object (file, group, or dataset)
- `dataset_name`: Name of the dataset to create
- `data`: Array to write

# Example
```julia
file = create_file("data.h5")
write_object(file, "matrix", rand(10, 10))
close_file(file)
```
"""
function write_object(object::HDF5Object, dataset_name::String, data::AbstractArray)
    # Convert to regular Array if it's not already one
    return write_object(object, dataset_name, Array(data)::Array)
end

# Method for string arrays (without @nospecialize for better type stability)
function write_object(object::HDF5Object, dataset_name::String, data::Array{String})
    rank = length(size(data))
    dims = _convert(Vector{Int}, size(data))

    reverse!(dims)  # HDF5 uses C ordering (last dimension varies fastest)
    dataspace_id = API.h5s_create_simple(rank, dims, C_NULL)
    datatype_id = _get_h5_datatype(String)

    # Create dataset
    dataset_id = API.h5d_create(
        get_hid(object),
        dataset_name,
        datatype_id,
        dataspace_id,
        API.H5P_DEFAULT,
        API.H5P_DEFAULT,
        API.H5P_DEFAULT
    )

    try
        # For string arrays, we need to create an array of string pointers
        str_ptrs = [pointer(s) for s in data]
        API.h5d_write(dataset_id, datatype_id, API.H5S_ALL, API.H5S_ALL, API.H5P_DEFAULT, str_ptrs)
    finally
        # Clean up
        API.h5t_close(datatype_id)
        API.h5s_close(dataspace_id)
        API.h5d_close(dataset_id)
    end

    return nothing
end

# Method for non-string arrays
function write_object(object::HDF5Object, dataset_name::String, @nospecialize(data::Array))
    rank = length(size(data))
    dims = _convert(Vector{Int}, size(data))

    reverse!(dims)  # HDF5 uses C ordering (last dimension varies fastest)
    dataspace_id = API.h5s_create_simple(rank, dims, C_NULL)
    datatype_id = _get_h5_datatype(eltype(data)::Type)

    # Create dataset
    dataset_id = API.h5d_create(
        get_hid(object),
        dataset_name,
        datatype_id,
        dataspace_id,
        API.H5P_DEFAULT,
        API.H5P_DEFAULT,
        API.H5P_DEFAULT
    )

    try
        # Write data normally for non-string types
        API.h5d_write(dataset_id, datatype_id, API.H5S_ALL, API.H5S_ALL, API.H5P_DEFAULT, data)
    finally
        # Clean up
        API.h5t_close(datatype_id)
        API.h5s_close(dataspace_id)
        API.h5d_close(dataset_id)
    end

    return nothing
end

"""
    write_object(object::HDF5Object, dataset_name::String, data::String)

Write a scalar string to an HDF5 object.

# Arguments
- `object`: HDF5 object (file, group, or dataset)
- `dataset_name`: Name of the dataset to create
- `data`: String to write

# Example
```julia
file = create_file("data.h5")
write_object(file, "message", "Hello, World!")
close_file(file)
```
"""
function write_object(object::HDF5Object, dataset_name::String, data::String)
    # Create scalar dataspace
    dataspace_id = API.h5s_create(API.H5S_SCALAR)
    datatype_id = _get_h5_datatype(String)

    dataset_id = API.h5d_create(
        get_hid(object),
        dataset_name,
        datatype_id,
        dataspace_id,
        API.H5P_DEFAULT,
        API.H5P_DEFAULT,
        API.H5P_DEFAULT
    )

    try
        # For variable-length strings, we need to pass a pointer to the string pointer
        str_ptr = [pointer(data)]
        API.h5d_write(dataset_id, datatype_id, API.H5S_ALL, API.H5S_ALL, API.H5P_DEFAULT, str_ptr)
    finally
        API.h5d_close(dataset_id)
        API.h5t_close(datatype_id)
        API.h5s_close(dataspace_id)
    end
    return nothing
end

"""
    write_object(object::HDF5Object, dataset_name::String, data::Number)

Write a scalar number to an HDF5 object.

# Arguments
- `object`: HDF5 object (file, group, or dataset)
- `dataset_name`: Name of the dataset to create
- `data`: Number to write

# Example
```julia
file = create_file("data.h5")
write_object(file, "value", 42)
write_object(file, "pi", 3.14159)
close_file(file)
```
"""
function write_object(object::HDF5Object, dataset_name::String, data::Number)
    # Create scalar dataspace
    dataspace_id = API.h5s_create(API.H5S_SCALAR)
    datatype_id = _get_h5_datatype(typeof(data))

    dataset_id = API.h5d_create(
        get_hid(object),
        dataset_name,
        datatype_id,
        dataspace_id,
        API.H5P_DEFAULT,
        API.H5P_DEFAULT,
        API.H5P_DEFAULT
    )

    try
        data_array = [data]
        API.h5d_write(dataset_id, datatype_id, API.H5S_ALL, API.H5S_ALL, API.H5P_DEFAULT, data_array)
    finally
        API.h5d_close(dataset_id)
        API.h5t_close(datatype_id)
        API.h5s_close(dataspace_id)
    end
    return nothing
end

"""
    get_dataset_info(object::HDF5Object, dataset_name::String)

Get information about a dataset stored in an HDF5 file.

# Arguments
- `object`: HDF5 object (file, group)
- `dataset_name`: Name of the dataset to get information about

# Returns
Named tuple with fields: `type`, `dims`, `is_scalar`

# Example
```julia
file_id = open_file("data.h5")
info = get_dataset_info(file_id, "matrix")
println("Type: ", info.type)
println("Dimensions: ", info.dims)
close_file(file_id)
```
"""
function get_dataset_info(object::HDF5Object, dataset_name::String)
    # Check if the path exists and what type it is
    if is_group(object, dataset_name)
        throw(ArgumentError("'$dataset_name' is a group, not a dataset. Use group operations instead."))
    elseif !is_dataset(object, dataset_name)
        throw(ArgumentError("'$dataset_name' does not exist or is not a dataset."))
    end

    dataset_id = API.h5d_open(get_hid(object), dataset_name, API.H5P_DEFAULT)
    dataspace_id = API.h5d_get_space(dataset_id)

    rank = API.h5s_get_simple_extent_ndims(dataspace_id)
    dims_out = Vector{API.hsize_t}(undef, rank)
    API.h5s_get_simple_extent_dims(dataspace_id, dims_out, C_NULL)

    # Convert dimensions to Julia ordering (first dimension varies fastest)
    dims = Tuple(reverse(dims_out))

    # Check if it's a scalar
    is_scalar = API.h5s_get_simple_extent_type(dataspace_id) == API.H5S_SCALAR

    datatype_id = API.h5d_get_type(dataset_id)
    julia_type = _get_julia_type(datatype_id)

    # Clean up
    API.h5t_close(datatype_id)
    API.h5s_close(dataspace_id)
    API.h5d_close(dataset_id)

    return (type = julia_type, dims = dims, is_scalar = is_scalar)
end

"""
    read_object(object::HDF5Object, dataset_name::String, ::Type{Array{T,N}}) where {T,N}

Read an array from an HDF5 file with a specified array type.
This version ensures type stability by pre-specifying both the element type and dimensionality.

# Arguments
- `object`: HDF5 object (file, group)
- `dataset_name`: Name of the dataset to read
- `Array{T,N}`: The array type to read (e.g., Vector{Float64}, Matrix{Int}, Array{Float32,3}, etc.)

# Example
```julia
file_id = open_file("data.h5")
data = read_object(file_id, "vector", Array{Float64,1})  # For 1D arrays
data = read_object(file_id, "matrix", Array{Int,2})      # For 2D arrays
data = read_object(file_id, "tensor", Array{Float32,3})  # For 3D arrays
close_file(file_id)
```

# Notes
Throws an error if the actual dimensions don't match the expected dimensionality.
"""
function read_object(object::HDF5Object, dataset_name::String, ::Type{Array{T, N}}) where {T, N}
    dataset_id = API.h5d_open(get_hid(object), dataset_name, API.H5P_DEFAULT)
    dataspace_id = API.h5d_get_space(dataset_id)

    rank = API.h5s_get_simple_extent_ndims(dataspace_id)
    dims = Vector{API.hsize_t}(undef, rank)
    API.h5s_get_simple_extent_dims(dataspace_id, dims, C_NULL)
    if length(dims) != N
        throw(ArgumentError("Dimension mismatch: expected $N-dimensional array, got $(length(dims))-dimensional array"))
    end
    data = Array{T}(undef, reverse(ntuple(i -> dims[i], N)))

    # Get stored datatype for type checking
    stored_datatype_id = API.h5d_get_type(dataset_id)
    # Get the Julia type corresponding to the stored type
    stored_julia_type = _get_julia_type(stored_datatype_id)

    if !(stored_julia_type === T)
        API.h5t_close(stored_datatype_id)
        API.h5s_close(dataspace_id)
        API.h5d_close(dataset_id)
        # Add the actual types when type printing doesn't get complained in JET
        throw(ArgumentError("Type mismatch: requested type is not the stored type "))
    end

    # Read data with special handling for string arrays
    if T === String
        # For string arrays, we need to handle variable-length strings
        if API.h5t_is_variable_str(stored_datatype_id)
            # Variable-length strings
            str_ptrs = Vector{Ptr{Cchar}}(undef, length(data))
            fill!(str_ptrs, C_NULL)
            API.h5d_read(dataset_id, stored_datatype_id, API.H5S_ALL, API.H5S_ALL, API.H5P_DEFAULT, str_ptrs)

            # Convert pointers to strings
            for i in eachindex(data)
                data[i] = str_ptrs[i] == C_NULL ? "" : unsafe_string(str_ptrs[i])
            end

            # Clean up variable-length data
            API.h5d_vlen_reclaim(stored_datatype_id, dataspace_id, API.H5P_DEFAULT, str_ptrs)
        else
            # Fixed-length strings
            str_size = API.h5t_get_size(stored_datatype_id)
            buf = Vector{UInt8}(undef, str_size * length(data))
            API.h5d_read(dataset_id, stored_datatype_id, API.H5S_ALL, API.H5S_ALL, API.H5P_DEFAULT, buf)

            # Convert buffer to strings
            for i in eachindex(data)
                start_idx = (i - 1) * str_size + 1
                end_idx = i * str_size
                str_bytes = buf[start_idx:end_idx]
                nulpos = findfirst(==(0x00), str_bytes)
                data[i] = nulpos !== nothing ? String(str_bytes[1:(nulpos - 1)]) : String(str_bytes)
            end
        end
    else
        # Normal read for non-string types
        API.h5d_read(dataset_id, stored_datatype_id, API.H5S_ALL, API.H5S_ALL, API.H5P_DEFAULT, data)
    end

    # Clean up
    API.h5t_close(stored_datatype_id)
    API.h5s_close(dataspace_id)
    API.h5d_close(dataset_id)

    return data
end

"""
    read_object(object::HDF5Object, dataset_name::String)

Read an object from an HDF5 file, automatically inferring the type.
This infers the array dimensions from the file so it's not type stable

# Arguments
- `object`: HDF5 object (file, group, or dataset)
- `dataset_name`: Name of the dataset to read

# Example
```julia
file_id = open_file("data.h5")
data = read_object(file_id, "vector")  # For 1D arrays
close_file(file_id)
```
"""
function read_object(object::HDF5Object, dataset_name::String)
    info = get_dataset_info(object, dataset_name)
    if info.is_scalar || length(info.dims) == 0
        # It's a scalar
        return read_object(object, dataset_name, info.type)
    else
        # It's an array
        return read_object(object, dataset_name, Array{info.type, length(info.dims)})
    end
end

"""
    read_object(object::HDF5Object, dataset_name::String, ::Type{T}) where T

Read a scalar object from an HDF5 file with a specified type for type stability.

# Arguments
- `object`: HDF5 object (file, group) to read from
- `dataset_name`: Name of the dataset to read
- `T`: The scalar type to read (e.g., String, Int, Float64, etc.)

# Example
```julia
file = open_file("data.h5")
text = read_object(file, "text", String)
scalar = read_object(file, "scalar", Int)
close_file(file)
```
"""
function read_object(object::HDF5Object, dataset_name::String, ::Type{T}) where {T}
    # For scalar types that are not arrays
    if !(T <: AbstractArray)
        dataset_id = API.h5d_open(get_hid(object), dataset_name, API.H5P_DEFAULT)
        dataspace_id = API.h5d_get_space(dataset_id)

        # Check if it's actually a scalar
        if API.h5s_get_simple_extent_type(dataspace_id) != API.H5S_SCALAR
            API.h5s_close(dataspace_id)
            API.h5d_close(dataset_id)
            throw(ArgumentError("Expected scalar dataset, but found array"))
        end

        # Get stored datatype for type checking
        stored_datatype_id = API.h5d_get_type(dataset_id)
        stored_julia_type = _get_julia_type(stored_datatype_id)

        if !(stored_julia_type === T)
            API.h5t_close(stored_datatype_id)
            API.h5s_close(dataspace_id)
            API.h5d_close(dataset_id)
            throw(ArgumentError("Type mismatch: requested type is not the stored type"))
        end

        # Read scalar data
        if T === String
            # Special handling for strings
            if API.h5t_is_variable_str(stored_datatype_id)
                buf = Vector{Ptr{Cchar}}(undef, 1)
                buf[1] = C_NULL
                API.h5d_read(dataset_id, stored_datatype_id, API.H5S_ALL, API.H5S_ALL, API.H5P_DEFAULT, pointer(buf))
                str_ptr = buf[1]
                result = str_ptr == C_NULL ? "" : unsafe_string(str_ptr)
                API.h5d_vlen_reclaim(stored_datatype_id, dataspace_id, API.H5P_DEFAULT, pointer(buf))
            else
                str_size = API.h5t_get_size(stored_datatype_id)
                buf = Vector{UInt8}(undef, str_size)
                API.h5d_read(dataset_id, stored_datatype_id, API.H5S_ALL, API.H5S_ALL, API.H5P_DEFAULT, pointer(buf))
                nulpos = findfirst(==(0x00), buf)
                result = nulpos !== nothing ? String(copy(buf[1:(nulpos - 1)])) : String(copy(buf))
            end
        else
            # For numeric scalars
            data_array = Vector{T}(undef, 1)
            API.h5d_read(dataset_id, stored_datatype_id, API.H5S_ALL, API.H5S_ALL, API.H5P_DEFAULT, data_array)
            result = data_array[1]
        end

        # Clean up
        API.h5t_close(stored_datatype_id)
        API.h5s_close(dataspace_id)
        API.h5d_close(dataset_id)

        return result
    else
        # For array types, delegate to the array method
        return read_object(object, dataset_name, T)
    end
end

"""
    list_objects(object::HDF5Object, path::String="/") -> Vector{String}

List all objects in a file or group.

# Arguments
- `object`: HDF5 object (file, group, or dataset)
- `path`: Path to the group (default: root group)

# Example
```julia
file_id = open_file("data.h5")
objects = list_objects(file_id)
close_file(file_id)
```
"""
function list_objects(object::HDF5Object, path::String = "/")
    should_close = false
    if isa(object, HDF5File)
        # Open the group
        group_id = API.h5g_open(get_hid(object), path, API.H5P_DEFAULT)
        should_close = true
    elseif isa(object, HDF5Group)
        # Open the group
        group_id = if path == "/" # Just use the group id if we're at the root
            get_hid(object)
        else
            API.h5g_open(get_hid(object), path, API.H5P_DEFAULT)
            should_close = true
        end
    else
        error("Unsupported object type: $(typeof(object))")
    end

    # Get the number of objects in the group
    info = Ref{API.H5G_info_t}()
    API.h5g_get_info(group_id, info)
    n_objs = info[].nlinks

    objects = String[]

    # If there are no objects, return empty array
    if n_objs == 0
        API.h5g_close(group_id)
        return objects
    end

    # Iterate through objects
    for i in 0:(n_objs - 1)
        # Get object name
        len = API.h5l_get_name_by_idx(group_id, ".", API.H5_INDEX_NAME, API.H5_ITER_NATIVE, i, C_NULL, 0, API.H5P_DEFAULT)
        buf = Vector{UInt8}(undef, len + 1)
        API.h5l_get_name_by_idx(group_id, ".", API.H5_INDEX_NAME, API.H5_ITER_NATIVE, i, buf, len + 1, API.H5P_DEFAULT)
        name = unsafe_string(pointer(buf))

        # Get object info
        obj_id = API.h5o_open(group_id, name, API.H5P_DEFAULT)
        obj_type = API.h5i_get_type(obj_id)

        push!(objects, name)

        API.h5o_close(obj_id)
    end

    if should_close
        API.h5g_close(group_id)
    end

    return objects
end
"""
    keys(object::HDF5Object) -> Vector{String}

List all objects in a file or group.

# Arguments
- `object`: HDF5 object (file, group)
# Example
```julia
file_id = open_file("data.h5")
objects = keys(file_id)
close_file(file_id)
```
"""
Base.keys(object::HDF5Object) = list_objects(object)

# Type-stable conversion for NTuple -> Vector
function _convert(::Type{Vector{T}}, @nospecialize(tup::NTuple{N, U} where {N})) where {T, U}
    N = length(tup)
    v = Vector{T}(undef, N)
    for i in 1:N
        if T === U
            v[i] = tup[i]
        else
            v[i] = Base.convert(T, tup[i])
        end
    end
    return v
end

# Helper function to get HDF5 datatype from Julia type
function _get_h5_datatype(@nospecialize(T::Type))
    if T === Float64
        return API.h5t_copy(API.H5T_NATIVE_DOUBLE)
    elseif T === Float32
        return API.h5t_copy(API.H5T_NATIVE_FLOAT)
    elseif T === Int64
        return API.h5t_copy(API.H5T_NATIVE_INT64)
    elseif T === Int32
        return API.h5t_copy(API.H5T_NATIVE_INT32)
    elseif T === Int16
        return API.h5t_copy(API.H5T_NATIVE_INT16)
    elseif T === Int8
        return API.h5t_copy(API.H5T_NATIVE_INT8)
    elseif T === UInt64
        return API.h5t_copy(API.H5T_NATIVE_UINT64)
    elseif T === UInt32
        return API.h5t_copy(API.H5T_NATIVE_UINT32)
    elseif T === UInt16
        return API.h5t_copy(API.H5T_NATIVE_UINT16)
    elseif T === UInt8
        return API.h5t_copy(API.H5T_NATIVE_UINT8)
    elseif T === Bool
        # Encode Bool as bitfield (UInt8-based) with precision 1
        bool_type = API.h5t_copy(API.H5T_NATIVE_B8)
        API.h5t_set_precision(bool_type, 1)
        return bool_type
    elseif T === String
        # Create variable-length string type
        str_type = API.h5t_copy(API.H5T_C_S1)
        API.h5t_set_size(str_type, API.H5T_VARIABLE)
        API.h5t_set_cset(str_type, API.H5T_CSET_UTF8)
        return str_type
    elseif T === ComplexF64
        complex_type = API.h5t_create(API.H5T_COMPOUND, 16)
        API.h5t_insert(complex_type, "r", 0, API.h5t_copy(API.H5T_NATIVE_DOUBLE))
        API.h5t_insert(complex_type, "i", 8, API.h5t_copy(API.H5T_NATIVE_DOUBLE))
        return complex_type
    elseif T === ComplexF32
        complex_type = API.h5t_create(API.H5T_COMPOUND, 8)
        API.h5t_insert(complex_type, "r", 0, API.h5t_copy(API.H5T_NATIVE_FLOAT))
        API.h5t_insert(complex_type, "i", 4, API.h5t_copy(API.H5T_NATIVE_FLOAT))
        return complex_type
    else
        @assert false "unsupported datatype"
    end
end

function _get_julia_type(datatype_id::API.hid_t)
    class = API.h5t_get_class(datatype_id)

    if class == API.H5T_INTEGER
        # Get sign
        is_signed = API.h5t_get_sign(datatype_id) == API.H5T_SGN_2

        # Get size
        size = API.h5t_get_size(datatype_id)

        # Special case for Bool
        # Map to Julia integer types
        if is_signed
            if size == 1
                return Int8
            elseif size == 2
                return Int16
            elseif size == 4
                return Int32
            elseif size == 8
                return Int64
            else
                error("Unsupported signed integer size: $size")
            end
        else
            if size == 1
                return UInt8
            elseif size == 2
                return UInt16
            elseif size == 4
                return UInt32
            elseif size == 8
                return UInt64
            else
                error("Unsupported unsigned integer size: $size")
            end
        end
    elseif class == API.H5T_FLOAT
        size = API.h5t_get_size(datatype_id)
        if size == 2
            return Float16
        elseif size == 4
            return Float32
        elseif size == 8
            return Float64
        end
    elseif class == API.H5T_STRING
        return String
    elseif class == API.H5T_BITFIELD
        size = API.h5t_get_size(datatype_id)
        if size == 1
            if API.h5t_get_precision(datatype_id) == 1
                return Bool
            end
            return UInt8
        elseif size == 2
            return UInt16
        elseif size == 4
            return UInt32
        elseif size == 8
            return UInt64
        else
            error("Unsupported bitfield size: $size")
        end
    elseif class == API.H5T_COMPOUND
        nmembers = API.h5t_get_nmembers(datatype_id)
        if nmembers == 2
            # Get member names
            name1_ptr = API.h5t_get_member_name(datatype_id, 0)
            name2_ptr = API.h5t_get_member_name(datatype_id, 1)
            name1 = name1_ptr isa String ? name1_ptr : unsafe_string(name1_ptr)
            name2 = name2_ptr isa String ? name2_ptr : unsafe_string(name2_ptr)


            if (name1 == "r" && name2 == "i")
                # Get the base type from the first member
                member_type = API.h5t_get_member_type(datatype_id, 0)
                member_class = API.h5t_get_class(member_type)
                member_size = API.h5t_get_size(member_type)

                API.h5t_close(member_type)

                if member_class == API.H5T_FLOAT
                    if member_size == 4
                        return ComplexF32
                    elseif member_size == 8
                        return ComplexF64
                    end
                end
            end
        end
        error("Unsupported compound datatype")
    end

    # Default to Float64 if we can't determine the type
    error("Unsupported HDF5 datatype class: $class")
end

"""
    is_dataset(object::HDF5Object, path::String) -> Bool

Check if a path in the HDF5 file refers to a dataset.

# Arguments
- `object`: HDF5 object (file, group)
- `path`: Path to check

# Example
```julia
file = open_file("data.h5")
if is_dataset(file, "my_array")
    data = read_object(file, "my_array")
end
close_file(file)
```
"""
function is_dataset(object::HDF5Object, path::String)
    try
        obj_id = API.h5o_open(get_hid(object), path, API.H5P_DEFAULT)
        obj_type = API.h5i_get_type(obj_id)
        API.h5o_close(obj_id)
        return obj_type == API.H5I_DATASET
    catch
        return false
    end
end

"""
    is_group(object::HDF5Object, path::String) -> Bool

Check if a path in the HDF5 file refers to a group.

# Arguments
- `object`: HDF5 object (file, group)
- `path`: Path to check

# Example
```julia
file = open_file("data.h5")
if is_group(file, "measurements")
    group = open_group(file, "measurements")
    # ... work with group ...
    close_group(group)
end
close_file(file)
```
"""
function is_group(object::HDF5Object, path::String)
    try
        obj_id = API.h5o_open(get_hid(object), path, API.H5P_DEFAULT)
        obj_type = API.h5i_get_type(obj_id)
        API.h5o_close(obj_id)
        return obj_type == API.H5I_GROUP
    catch
        return false
    end
end

end # module StaticHDF5

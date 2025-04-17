module StaticHDF5

export open_file, create_file, close_file
export write_array, read_array
export open_group, create_group, close_group, list_objects
export get_array_info
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
function open_file(filename::String, mode::Integer=READ_ONLY)
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
function create_file(filename::String, mode::Integer=CREATE)
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
    write_array(object::HDF5Object, dataset_name::String, data::AbstractArray{T}) where T

Write an array to an HDF5 object.

This converts to a regular Array before writing.
# Arguments
- `object`: HDF5 object (file, group, or dataset)
- `dataset_name`: Name of the dataset to create
- `data`: Array to write

# Example
```julia
file = create_file("data.h5")
write_array(file, "matrix", rand(10, 10))
close_file(file)
```
"""
function write_array(object::HDF5Object, dataset_name::String, data::AbstractArray)
    # Convert to regular Array if it's not already one
    return write_array(object, dataset_name, Array(data)::Array)
end

function write_array(object::HDF5Object, dataset_name::String, @nospecialize(data::Array))
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

    # Write data
    API.h5d_write(
        dataset_id,
        datatype_id,
        API.H5S_ALL,
        API.H5S_ALL,
        API.H5P_DEFAULT,
        data
    )

    # Clean up
    API.h5t_close(datatype_id)
    API.h5s_close(dataspace_id)
    API.h5d_close(dataset_id)

    return nothing
end

"""
    get_array_info(object::HDF5Object, dataset_name::String) -> (Type, Tuple)

Get information about an array stored in an HDF5 file.
Returns a tuple containing the element type and dimensions of the array.

# Arguments
- `object`: HDF5 object (file, group)
- `dataset_name`: Name of the dataset to get information about

# Example
```julia
file_id = open_file("data.h5")
elem_type, dims = get_array_info(file_id, "matrix")
close_file(file_id)
```
"""
function get_array_info(object::HDF5Object, dataset_name::String)
    dataset_id = API.h5d_open(get_hid(object), dataset_name, API.H5P_DEFAULT)
    dataspace_id = API.h5d_get_space(dataset_id)

    rank = API.h5s_get_simple_extent_ndims(dataspace_id)
    dims_out = Vector{API.hsize_t}(undef, rank)
    API.h5s_get_simple_extent_dims(dataspace_id, dims_out, C_NULL)

    # Convert dimensions to Julia ordering (first dimension varies fastest)
    dims = Tuple(reverse(dims_out))

    datatype_id = API.h5d_get_type(dataset_id)
    julia_type = _get_julia_type(datatype_id)

    # Clean up
    API.h5t_close(datatype_id)
    API.h5s_close(dataspace_id)
    API.h5d_close(dataset_id)

    return julia_type, dims
end

"""
    read_array(object::HDF5Object, dataset_name::String, ::Type{Array{T,N}}) where {T,N}

Read an array from an HDF5 file with a specified array type.
This version ensures type stability by pre-specifying both the element type and dimensionality.

# Arguments
- `object`: HDF5 object (file, group)
- `dataset_name`: Name of the dataset to read
- `Array{T,N}`: The array type to read (e.g., Vector{Float64}, Matrix{Int}, Array{Float32,3}, etc.)

# Example
```julia
file_id = open_file("data.h5")
data = read_array(file_id, "vector", Array{Float64,1})  # For 1D arrays
data = read_array(file_id, "matrix", Array{Int,2})      # For 2D arrays
data = read_array(file_id, "tensor", Array{Float32,3})  # For 3D arrays
close_file(file_id)
```

# Notes
Throws an error if the actual dimensions don't match the expected dimensionality.
"""
function read_array(object::HDF5Object, dataset_name::String, ::Type{Array{T,N}}) where {T,N}
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
        throw(ArgumentError("Type mismatch: requested type $T is not the stored type $stored_julia_type"))
    end

    # Read data
    API.h5d_read(
        dataset_id,
        stored_datatype_id,
        API.H5S_ALL,
        API.H5S_ALL,
        API.H5P_DEFAULT,
        data
    )

    # Clean up
    API.h5t_close(stored_datatype_id)
    API.h5s_close(dataspace_id)
    API.h5d_close(dataset_id)

    return data
end

"""
    read_array(object::HDF5Object, dataset_name::String) where {T,N}

Read an array from an HDF5 file with a specified array type.
This infers the array dimensions from the file so it's not type stable

# Arguments
- `object`: HDF5 object (file, group, or dataset)
- `dataset_name`: Name of the dataset to read

# Example
```julia
file_id = open_file("data.h5")
data = read_array(file_id, "vector")  # For 1D arrays
close_file(file_id)
```
"""
function read_array(object::HDF5Object, dataset_name::String)
    elem_type, dims = get_array_info(object, dataset_name)
    return read_array(object, dataset_name, Array{elem_type, length(dims)})
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
function list_objects(object::HDF5Object, path::String="/")
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
    for i in 0:(n_objs-1)
        # Get object name
        len = API.h5l_get_name_by_idx(group_id, ".", API.H5_INDEX_NAME, API.H5_ITER_NATIVE, i, C_NULL, 0, API.H5P_DEFAULT)
        buf = Vector{UInt8}(undef, len+1)
        API.h5l_get_name_by_idx(group_id, ".", API.H5_INDEX_NAME, API.H5_ITER_NATIVE, i, buf, len+1, API.H5P_DEFAULT)
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
function _convert(::Type{Vector{T}}, @nospecialize(tup::NTuple{N,U} where N)) where {T,U}
    N = length(tup)
    v = Vector{T}(undef, N)
    for i = 1:N
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
    else @assert false "unsupported datatype" end
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
    # elseif class == API.H5T_STRING
    #     return String # This is not how Strings work
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
    end

    # Default to Float64 if we can't determine the type
    error("Unsupported HDF5 datatype class: $class")
end



end # module StaticHDF5

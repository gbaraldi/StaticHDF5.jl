module SimpleHDF5

export open_file, create_file, close_file
export write_array, read_array
export create_group, list_datasets
export get_array_info
export READ_ONLY, READ_WRITE, CREATE  # Export the constants

include("api/api.jl")
using .API

# Constants for file access modes
const READ_ONLY = API.H5F_ACC_RDONLY
const READ_WRITE = API.H5F_ACC_RDWR
const CREATE = API.H5F_ACC_TRUNC


"""
    open_file(filename::String, mode::Integer=READ_ONLY) -> hid_t

Open an HDF5 file with the specified access mode.
Returns a file identifier that should be closed with `close_file`.

# Arguments
- `filename`: Path to the HDF5 file
- `mode`: File access mode (READ_ONLY, READ_WRITE)

# Example
```julia
file_id = open_file("data.h5")
# ... operations on file ...
close_file(file_id)
```
"""
function open_file(filename::String, mode::Integer=READ_ONLY)
    file_id = API.h5f_open(filename, mode, API.H5P_DEFAULT)
    return file_id
end

"""
    create_file(filename::String, mode::Integer=CREATE) -> hid_t

Create a new HDF5 file.
Returns a file identifier that should be closed with `close_file`.

# Arguments
- `filename`: Path to the HDF5 file to create
- `mode`: File creation mode (default: CREATE which truncates existing files)

# Example
```julia
file_id = create_file("new_data.h5")
# ... operations on file ...
close_file(file_id)
```
"""
function create_file(filename::String, mode::Integer=CREATE)
    file_id = API.h5f_create(filename, mode, API.H5P_DEFAULT, API.H5P_DEFAULT)
    return file_id
end

"""
    close_file(file_id::hid_t)

Close an HDF5 file.

# Arguments
- `file_id`: File identifier returned by `open_file` or `create_file`
"""
function close_file(file_id)
    API.h5f_close(file_id)
    return nothing
end

"""
    create_group(file_id::hid_t, group_name::String) -> hid_t

Create a new group in the HDF5 file.
Returns a group identifier that should be closed with `API.h5g_close`.

# Arguments
- `file_id`: File identifier
- `group_name`: Name of the group to create

# Example
```julia
file_id = create_file("data.h5")
group_id = create_group(file_id, "measurements")
# ... operations on group ...
API.h5g_close(group_id)
close_file(file_id)
```
"""
function create_group(file_id, group_name::String)
    group_id = API.h5g_create(file_id, group_name, API.H5P_DEFAULT, API.H5P_DEFAULT, API.H5P_DEFAULT)
    return group_id
end

"""
    write_array(file_id::hid_t, dataset_name::String, data::AbstractArray{T}) where T

Write an array to an HDF5 file.

# Arguments
- `file_id`: File identifier
- `dataset_name`: Name of the dataset to create
- `data`: Array to write

# Example
```julia
file_id = create_file("data.h5")
write_array(file_id, "matrix", rand(10, 10))
close_file(file_id)
```
"""
function write_array(file_id, dataset_name::String, data::AbstractArray{T}) where T
    # Convert to regular Array if it's not already one
    array_data = Array(data)

    # Get dimensions of the array
    dims = size(array_data)
    rank = length(dims)

    # Create dataspace
    dims_hsize_t = [reverse(dims)]  # HDF5 uses C ordering (last dimension varies fastest)
    dataspace_id = API.h5s_create_simple(rank, dims_hsize_t, C_NULL)

    # Create datatype
    datatype_id = _get_h5_datatype(T)

    # Create dataset
    dataset_id = API.h5d_create(
        file_id,
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
        array_data
    )

    # Clean up
    API.h5t_close(datatype_id)
    API.h5s_close(dataspace_id)
    API.h5d_close(dataset_id)

    return nothing
end

"""
    get_array_info(file_id::hid_t, dataset_name::String) -> (Type, Tuple)

Get information about an array stored in an HDF5 file.
Returns a tuple containing the element type and dimensions of the array.

# Arguments
- `file_id`: File identifier
- `dataset_name`: Name of the dataset to get information about

# Example
```julia
file_id = open_file("data.h5")
elem_type, dims = get_array_info(file_id, "matrix")
close_file(file_id)
```
"""
function get_array_info(file_id, dataset_name::String)
    # Open the dataset
    dataset_id = API.h5d_open(file_id, dataset_name, API.H5P_DEFAULT)

    # Get dataspace
    dataspace_id = API.h5d_get_space(dataset_id)

    # Get dimensions
    rank = API.h5s_get_simple_extent_ndims(dataspace_id)
    dims_out = Vector{API.hsize_t}(undef, rank)
    API.h5s_get_simple_extent_dims(dataspace_id, dims_out, C_NULL)

    # Convert dimensions to Julia ordering (first dimension varies fastest)
    dims = Tuple(reverse(dims_out))

    # Get datatype
    datatype_id = API.h5d_get_type(dataset_id)

    # Determine Julia type from HDF5 type
    julia_type = _get_julia_type(datatype_id)

    # Clean up
    API.h5t_close(datatype_id)
    API.h5s_close(dataspace_id)
    API.h5d_close(dataset_id)

    return julia_type, dims
end

"""
    read_array(file_id::hid_t, dataset_name::String, ::Type{Array{T,N}}) where {T,N}

Read an array from an HDF5 file with a specified array type.
This version ensures type stability by pre-specifying both the element type and dimensionality.

# Arguments
- `file_id`: File identifier
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
function read_array(file_id, dataset_name::String, ::Type{Array{T,N}}) where {T,N}
    # Get array info to check dimensions
    elem_type, dims = get_array_info(file_id, dataset_name)
    
    # Check if dimensionality matches
    if length(dims) != N
        throw(API.H5Error("Dimension mismatch: expected $N-dimensional array, got $(length(dims))-dimensional array"))
    end
    
    # Open the dataset
    dataset_id = API.h5d_open(file_id, dataset_name, API.H5P_DEFAULT)

    # Get dataspace
    dataspace_id = API.h5d_get_space(dataset_id)


    # Create array to hold data
    ntuple(i -> dims[i], N)
    data = Array{T}(undef, ntuple(i -> dims[i], N))

    # Get datatype for requested type
    datatype_id = _get_h5_datatype(T)

    # Get stored datatype for type checking
    stored_datatype_id = API.h5d_get_type(dataset_id)
    stored_class = API.h5t_get_class(stored_datatype_id)
    requested_class = API.h5t_get_class(datatype_id)

    # Get the Julia type corresponding to the stored type
    stored_julia_type = _get_julia_type(stored_datatype_id)

    # Check if types are compatible
    if !_are_types_compatible(stored_class, requested_class, stored_julia_type, T)
        API.h5t_close(datatype_id)
        API.h5t_close(stored_datatype_id)
        API.h5s_close(dataspace_id)
        API.h5d_close(dataset_id)
        throw(API.H5Error("Type mismatch: requested type $T is not compatible with stored type $stored_julia_type"))
    end

    # Read data
    API.h5d_read(
        dataset_id,
        datatype_id,
        API.H5S_ALL,
        API.H5S_ALL,
        API.H5P_DEFAULT,
        data
    )

    # Clean up
    API.h5t_close(datatype_id)
    API.h5t_close(stored_datatype_id)
    API.h5s_close(dataspace_id)
    API.h5d_close(dataset_id)

    return data
end

"""
    read_array(file_id::hid_t, dataset_name::String, ::Type{Vector{T}}) where T

Read a 1D array from an HDF5 file.
This is a convenience method for `read_array(file_id, dataset_name, Array{T,1})`.
"""
# function read_array(file_id, dataset_name::String, ::Type{Vector{T}}) where T
#     return read_array(file_id, dataset_name, Array{T,1})
# end

# """
#     read_array(file_id::hid_t, dataset_name::String, ::Type{Matrix{T}}) where T

# Read a 2D array from an HDF5 file.
# This is a convenience method for `read_array(file_id, dataset_name, Array{T,2})`.
# """
# function read_array(file_id, dataset_name::String, ::Type{Matrix{T}}) where T
#     return read_array(file_id, dataset_name, Array{T,2})
# end

"""
    read_array(file_id::hid_t, dataset_name::String, ::Type{T}) where T

Read an array from an HDF5 file with a specified element type.
This version infers the dimensions from the file.

# Arguments
- `file_id`: File identifier
- `dataset_name`: Name of the dataset to read
- `T`: Element type of the array

# Example
```julia
file_id = open_file("data.h5")
data = read_array(file_id, "dataset", Float64)  # Infers dimensions from file
close_file(file_id)
```

# Notes
This method is not type stable with respect to the array dimensions,
as they are only known at runtime. For type-stable code, use the parametric
array type version: `read_array(file_id, dataset_name, Array{T,N})`.
"""
function read_array(file_id, dataset_name::String, ::Type{T}) where T
    # Get array info to determine dimensions
    elem_type, dims = get_array_info(file_id, dataset_name)
    
    # Open the dataset
    dataset_id = API.h5d_open(file_id, dataset_name, API.H5P_DEFAULT)

    # Get dataspace
    dataspace_id = API.h5d_get_space(dataset_id)

    # Create array to hold data
    data = Array{T}(undef, dims...)

    # Get datatype for requested type
    datatype_id = _get_h5_datatype(T)

    # Get stored datatype for type checking
    stored_datatype_id = API.h5d_get_type(dataset_id)
    stored_class = API.h5t_get_class(stored_datatype_id)
    requested_class = API.h5t_get_class(datatype_id)

    # Get the Julia type corresponding to the stored type
    stored_julia_type = _get_julia_type(stored_datatype_id)

    # Check if types are compatible
    if !_are_types_compatible(stored_class, requested_class, stored_julia_type, T)
        API.h5t_close(datatype_id)
        API.h5t_close(stored_datatype_id)
        API.h5s_close(dataspace_id)
        API.h5d_close(dataset_id)
        throw(API.H5Error("Type mismatch: requested type $T is not compatible with stored type $stored_julia_type"))
    end

    # Read data
    API.h5d_read(
        dataset_id,
        datatype_id,
        API.H5S_ALL,
        API.H5S_ALL,
        API.H5P_DEFAULT,
        data
    )

    # Clean up
    API.h5t_close(datatype_id)
    API.h5t_close(stored_datatype_id)
    API.h5s_close(dataspace_id)
    API.h5d_close(dataset_id)

    return data
end

"""
    read_array(file_id::hid_t, dataset_name::String, ::Type{T}, dims::Tuple) where T

Read an array from an HDF5 file with specified dimensions.
This version ensures type stability by pre-specifying the dimensions.

# Arguments
- `file_id`: File identifier
- `dataset_name`: Name of the dataset to read
- `T`: Element type of the array
- `dims`: Expected dimensions of the array

# Example
```julia
file_id = open_file("data.h5")
data = read_array(file_id, "matrix", Float64, (10, 10))
close_file(file_id)
```

# Notes
Throws an error if the actual dimensions don't match the expected dimensions.
This method is deprecated in favor of the parametric type version:
`read_array(file_id, dataset_name, Array{T,N})`.
"""
function read_array(file_id, dataset_name::String, ::Type{T}, dims::Tuple) where T
    # Open the dataset
    dataset_id = API.h5d_open(file_id, dataset_name, API.H5P_DEFAULT)

    # Get dataspace
    dataspace_id = API.h5d_get_space(dataset_id)

    # Get actual dimensions
    rank = API.h5s_get_simple_extent_ndims(dataspace_id)
    dims_out = Vector{API.hsize_t}(undef, rank)
    API.h5s_get_simple_extent_dims(dataspace_id, dims_out, C_NULL)

    # Convert dimensions to Julia ordering (first dimension varies fastest)
    actual_dims = Tuple(reverse(dims_out))

    # Check if dimensions match
    if actual_dims != dims
        API.h5s_close(dataspace_id)
        API.h5d_close(dataset_id)
        throw(API.H5Error("Dimension mismatch: expected $dims, got $actual_dims"))
    end

    # Create array to hold data
    data = Array{T}(undef, dims)

    # Get datatype for requested type
    datatype_id = _get_h5_datatype(T)

    # Get stored datatype for type checking
    stored_datatype_id = API.h5d_get_type(dataset_id)
    stored_class = API.h5t_get_class(stored_datatype_id)
    requested_class = API.h5t_get_class(datatype_id)

    # Get the Julia type corresponding to the stored type
    stored_julia_type = _get_julia_type(stored_datatype_id)

    # Check if types are compatible
    if !_are_types_compatible(stored_class, requested_class, stored_julia_type, T)
        API.h5t_close(datatype_id)
        API.h5t_close(stored_datatype_id)
        API.h5s_close(dataspace_id)
        API.h5d_close(dataset_id)
        throw(API.H5Error("Type mismatch: requested type $T is not compatible with stored type $stored_julia_type"))
    end

    # Read data
    API.h5d_read(
        dataset_id,
        datatype_id,
        API.H5S_ALL,
        API.H5S_ALL,
        API.H5P_DEFAULT,
        data
    )

    # Clean up
    API.h5t_close(datatype_id)
    API.h5t_close(stored_datatype_id)
    API.h5s_close(dataspace_id)
    API.h5d_close(dataset_id)

    return data
end

"""
    list_datasets(file_id::hid_t, path::String="/") -> Vector{String}

List all datasets in a file or group.

# Arguments
- `file_id`: File identifier
- `path`: Path to the group (default: root group)

# Example
```julia
file_id = open_file("data.h5")
datasets = list_datasets(file_id)
close_file(file_id)
```
"""
function list_datasets(file_id, path::String="/")
    # Open the group
    group_id = if path == "/"
        API.h5g_open(file_id, "/", API.H5P_DEFAULT)
    else
        API.h5g_open(file_id, path, API.H5P_DEFAULT)
    end

    # Get the number of objects in the group
    info = Ref{API.H5G_info_t}()
    API.h5g_get_info(group_id, info)
    n_objs = info[].nlinks

    datasets = String[]

    # If there are no objects, return empty array
    if n_objs == 0
        API.h5g_close(group_id)
        return datasets
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

        # If it's a dataset, add to the list
        if obj_type == API.H5I_DATASET
            push!(datasets, name)
        end

        API.h5o_close(obj_id)
    end

    API.h5g_close(group_id)

    return datasets
end

# Helper function to get HDF5 datatype from Julia type
function _get_h5_datatype(::Type{Float64})
    return API.h5t_copy(API.H5T_NATIVE_DOUBLE)
end

function _get_h5_datatype(::Type{Float32})
    return API.h5t_copy(API.H5T_NATIVE_FLOAT)
end

function _get_h5_datatype(::Type{Int64})
    return API.h5t_copy(API.H5T_NATIVE_INT64)
end

function _get_h5_datatype(::Type{Int32})
    return API.h5t_copy(API.H5T_NATIVE_INT32)
end

function _get_h5_datatype(::Type{Int16})
    return API.h5t_copy(API.H5T_NATIVE_INT16)
end

function _get_h5_datatype(::Type{Int8})
    return API.h5t_copy(API.H5T_NATIVE_INT8)
end

function _get_h5_datatype(::Type{UInt64})
    return API.h5t_copy(API.H5T_NATIVE_UINT64)
end

function _get_h5_datatype(::Type{UInt32})
    return API.h5t_copy(API.H5T_NATIVE_UINT32)
end

function _get_h5_datatype(::Type{UInt16})
    return API.h5t_copy(API.H5T_NATIVE_UINT16)
end

function _get_h5_datatype(::Type{UInt8})
    return API.h5t_copy(API.H5T_NATIVE_UINT8)
end

function _get_h5_datatype(::Type{Bool})
    # Create a proper boolean datatype using H5T_NATIVE_B8
    bool_id = API.h5t_copy(API.H5T_NATIVE_B8)
    return bool_id
end

# Helper function to get Julia type from HDF5 datatype
function _get_julia_type(datatype_id)
    class = API.h5t_get_class(datatype_id)

    if class == API.H5T_INTEGER
        # Get sign
        is_signed = API.h5t_get_sign(datatype_id) == API.H5T_SGN_2

        # Get size
        size = API.h5t_get_size(datatype_id)

        # Special case for Bool
        if size == 1 && !is_signed
            # Check if this is a Bool type
            native_type_id = API.h5t_get_native_type(datatype_id, API.H5T_DIR_ASCEND)
            if API.h5t_equal(native_type_id, API.H5T_NATIVE_B8) > 0
                API.h5t_close(native_type_id)
                return Bool
            end
            API.h5t_close(native_type_id)
        end

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
                return Int64  # Default for unusual sizes
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
                return UInt64  # Default for unusual sizes
            end
        end
    elseif class == API.H5T_FLOAT
        size = API.h5t_get_size(datatype_id)

        if size == 4
            return Float32
        elseif size == 8
            return Float64
        end
    elseif class == API.H5T_STRING
        return String
    elseif class == API.H5T_BITFIELD
        # HDF5 bitfield class is used for booleans
        return Bool
    end

    # Default to Float64 if we can't determine the type
    return Float64
end

# Helper function to check if types are compatible for conversion
function _are_types_compatible(stored_class, requested_class, stored_julia_type, requested_julia_type)
    # Same class is always compatible
    if stored_class == requested_class
        return true
    end

    # Integer and float can be converted between each other
    if (stored_class == API.H5T_INTEGER && requested_class == API.H5T_FLOAT) ||
       (stored_class == API.H5T_FLOAT && requested_class == API.H5T_INTEGER)
        return true
    end

    # Special case for Bool arrays
    if stored_julia_type == Bool
        # Allow reading Bool as Bool
        if requested_julia_type == Bool
            return true
        end

        # Allow reading Bool as UInt8 (for compatibility with tests)
        if requested_julia_type == UInt8
            return true
        end

        # Disallow reading Bool as other integer types
        if requested_julia_type <: Integer
            return false
        end
    end

    # Disallow reading integers as Bool
    if stored_class == API.H5T_INTEGER && requested_class == API.H5T_BITFIELD
        return false
    end

    return false
end

end # module SimpleHDF5

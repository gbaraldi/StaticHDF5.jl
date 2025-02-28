# SimpleHDF5

A simple, lightweight Julia interface to HDF5 files focused on array operations.
It's main goal is to support juliac

## Features

- Simple API for reading and writing arrays to HDF5 files
- Support for various data types (Float64, Float32, Int64, Int32, Int16, Int8, UInt64, UInt32, UInt16, UInt8, Bool)
- Group operations for organizing data
- Type-stable operations for optimal performance
- Minimal dependencies (only requires HDF5_jll)

## Installation

```julia
using Pkg
Pkg.add("SimpleHDF5")
```

## Basic Usage

```julia
using SimpleHDF5

# Create a file and write some arrays
file_id = create_file("example.h5")
write_array(file_id, "integers", [1, 2, 3, 4, 5])
write_array(file_id, "matrix", reshape(1:12, 3, 4))
close_file(file_id)

# Read arrays back
file_id = open_file("example.h5")
integers = read_array(file_id, "integers", Int64)
matrix = read_array(file_id, "matrix", Int64)
close_file(file_id)
```

## Working with Groups

```julia
# Create a file with groups
file_id = create_file("grouped_example.h5")

# Create a group and write data to it
group_id = create_group(file_id, "measurements")
write_array(group_id, "temperatures", [22.1, 22.3, 22.0, 21.8])

# Create a subgroup
subgroup_id = create_group(group_id, "day1")
write_array(subgroup_id, "morning", [20.1, 20.5, 21.0])

# Close groups and file
SimpleHDF5.API.h5g_close(subgroup_id)
SimpleHDF5.API.h5g_close(group_id)
close_file(file_id)
```

## Type-Stable Reading

For optimal performance, you should use the type-stable version of `read_array`. SimpleHDF5 provides several type-stable options:

1. **Using parametric array types** (recommended):
   ```julia
   # For 1D arrays (vectors)
   vector = read_array(file_id, "vector", Vector{Float64})

   # For 2D arrays (matrices)
   matrix = read_array(file_id, "matrix", Matrix{Int})

   # For N-dimensional arrays
   tensor = read_array(file_id, "tensor", Array{Float32, 3})
   ```

2. **Using get_array_info + parametric array types**:
   ```julia
   elem_type, dims = get_array_info(file_id, "matrix")
   # Use the information to choose the right parametric type
   matrix = read_array(file_id, "matrix", Array{elem_type, length(dims)})
   ```

The standard version of `read_array` without a parametric type is not type stable because the dimensions are only known at runtime:

```julia
# Not type stable (dimensions only known at runtime)
data = read_array(file_id, "dataset", Float64)
```

For best performance, especially in performance-critical applications, always use one of the parametric type versions.

### Recommended Type-Stable Workflow

```julia
file_id = open_file("example.h5")

# Option 1: Using get_array_info to determine type and dimensionality
elem_type, dims = get_array_info(file_id, "matrix")
# Then use the appropriate parametric type
if length(dims) == 1
    data = read_array(file_id, "matrix", Vector{elem_type})
elseif length(dims) == 2
    data = read_array(file_id, "matrix", Matrix{elem_type})
else
    data = read_array(file_id, "matrix", Array{elem_type, length(dims)})
end

# Option 2: Using parametric array types directly (simpler if you know the type and dimensionality)
matrix = read_array(file_id, "matrix", Matrix{Float64})

close_file(file_id)
```

### Type Stability Note

Type stability is important for optimal performance in Julia. When a function is type-stable, Julia can generate more efficient machine code, resulting in faster execution.

The following versions of `read_array` are available:

```julia
# Not type stable (dimensions only known at runtime)
read_array(file_id, "dataset", Float64)

# Type stable (array type with dimensionality specified at compile time)
read_array(file_id, "dataset", Vector{Float64})  # For 1D arrays
read_array(file_id, "dataset", Matrix{Float64})  # For 2D arrays
read_array(file_id, "dataset", Array{Float64, 3})  # For 3D arrays
```

## Testing

SimpleHDF5 includes a comprehensive test suite that verifies functionality and performance:

- Basic functionality tests
- Type-specific tests (integers, booleans, etc.)
- Type stability tests using JET.jl
- Performance benchmarks (requires BenchmarkTools.jl)

To run the tests:

```julia
using Pkg
Pkg.test("SimpleHDF5")
```

### Type Stability Testing

SimpleHDF5 uses [JET.jl](https://github.com/aviatesk/JET.jl) for type stability analysis. JET performs static analysis to detect potential type instabilities and other issues in the code.

Note that JET.@test_opt only analyzes code for type stability but doesn't actually run it. The test suite includes both JET analysis and actual execution tests to ensure both type stability and correct functionality.

## License

MIT
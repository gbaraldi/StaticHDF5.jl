<!-- [![Build Status](https://github.com/gbaraldi/SimpleHDF5.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/gbaraldi/SimpleHDF5.jl/actions/workflows/CI.yml?query=branch%3Amain) -->
[![](https://img.shields.io/badge/docs-dev-blue.svg)](https://gbaraldi.github.io/SimpleHDF5.jl/dev/)

# SimpleHDF5

A simple, lightweight Julia interface to HDF5 files focused on array operations.
It's main goal is to support juliac

## Features

- Simple API for reading and writing arrays to HDF5 files
- Support for various data types (Float64, Float32, Int64, Int32, Int16, Int8, UInt64, UInt32, UInt16, UInt8, Bool)
- Group operations for organizing data
- Type-stable operations for --trim

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

For --trim use SimpleHDF5 has a way to pass in the expected return type, this makes it type stable

1. **Using parametric array types** (recommended):
   ```julia
   # For 1D arrays (vectors)
   vector = read_array(file_id, "vector", Vector{Float64})

   # For 2D arrays (matrices)
   matrix = read_array(file_id, "matrix", Matrix{Int})

   # For N-dimensional arrays
   tensor = read_array(file_id, "tensor", Array{Float32, 3})
   ```

The standard version of `read_array` without the return type is not stable because it's not possible to know what kind of array is in the file

<!-- [![Build Status](https://github.com/gbaraldi/StaticHDF5.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/gbaraldi/StaticHDF5.jl/actions/workflows/CI.yml?query=branch%3Amain) -->
[![](https://img.shields.io/badge/docs-dev-blue.svg)](https://gbaraldi.github.io/StaticHDF5.jl/dev/)

# StaticHDF5

A simple, lightweight Julia interface to HDF5 files focused on array operations.
It's main goal is to support reading HDF5 files while respecting the --trim restrictions

## Features

- Simple API for reading and writing arrays to HDF5 files
- Support for various data types (Float64, Float32, Int64, Int32, Int16, Int8, UInt64, UInt32, UInt16, UInt8, Bool)
- Group operations for organizing data
- Type-stable operations for --trim

## Installation

```julia
using Pkg
Pkg.add("StaticHDF5")
```

## Basic Usage

```julia
using StaticHDF5

# Create a file and write some arrays
file = create_file("example.h5")
write_array(file, "integers", [1, 2, 3, 4, 5])
write_array(file, "matrix", reshape(1:12, 3, 4))
close_file(file)

# Read arrays back
file = open_file("example.h5")
integers = read_array(file, "integers")
matrix = read_array(file, "matrix")
close_file(file)
```

## Working with Groups

```julia
# Create a file with groups
file = create_file("grouped_example.h5")

# Create a group and write data to it
group = create_group(file, "measurements")
write_array(group, "temperatures", [22.1, 22.3, 22.0, 21.8])

# Create a subgroup
subgroup = create_group(group, "day1")
write_array(subgroup, "morning", [20.1, 20.5, 21.0])

# Close groups and file
close_group(subgroup)
close_group(group)
close_file(file)

# Read from groups
file = open_file("grouped_example.h5")
group = open_group(file, "measurements")
temperatures = read_array(group, "temperatures", Vector{Float64})
subgroup = open_group(group, "day1")
morning = read_array(subgroup, "morning", Vector{Float64})
close_group(subgroup)
close_group(group)
close_file(file)
```

## Type-Stable Reading

For trimming, StaticHDF5 requires specifying the expected return type:

1. **Using parametric array types** (recommended):
   ```julia
   # For 1D arrays (vectors)
   vector = read_array(file_id, "vector", Vector{Float64})

   # For 2D arrays (matrices)
   matrix = read_array(file_id, "matrix", Matrix{Int})

   # For N-dimensional arrays
   tensor = read_array(file_id, "tensor", Array{Float32, 3})
   ```

The standard version of `read_array` without the return type is not type-stable because it's not possible to know what kind of array is in the file.

## File Access Modes

StaticHDF5 provides three file access modes:

- `READ_ONLY`: Open an existing file for reading only
- `READ_WRITE`: Open an existing file for reading and writing
- `CREATE`: Create a new file (truncates if it exists)

```julia
# Open a file for reading only
file = open_file("data.h5", READ_ONLY)

# Open a file for reading and writing
file = open_file("data.h5", READ_WRITE)

# Create a new file
file = create_file("new_data.h5", CREATE)
```

## Differences from HDF5.jl

Firstly we would like to thank the HDF5.jl developers for making such a featureful and powerful package. The goal for StaticHDF5.jl is not to replace it, but to have an interface that is compatible with trimming. This means cutting down on some of the features and also forcing the user to be explicit about the type they expect to load out of the hdf5 file.
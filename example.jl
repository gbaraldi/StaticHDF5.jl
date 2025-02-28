#!/usr/bin/env julia

# Add the src directory to the load path
push!(LOAD_PATH, joinpath(@__DIR__, "src"))
using SimpleHDF5
using BenchmarkTools  # For performance comparison

# Example 1: Basic writing and reading
println("Example 1: Basic writing and reading")
println("------------------------------------")

# Create a file and write some arrays
file_id = create_file("example.h5")  # Using default CREATE mode
write_array(file_id, "integers", [1, 2, 3, 4, 5])
write_array(file_id, "floats", [1.1, 2.2, 3.3, 4.4, 5.5])
write_array(file_id, "matrix", reshape(1:12, 3, 4))  # Using AbstractArray
close_file(file_id)

println("Written arrays to example.h5")

# Read the arrays back
file_id = open_file("example.h5")  # Using default READ_ONLY mode

# Note: This basic reading approach works but is not type-stable
# For performance-critical code, use the approach in Example 4 instead
integers = read_array(file_id, "integers", Int64)
floats = read_array(file_id, "floats", Float64)
matrix = read_array(file_id, "matrix", Int64)
close_file(file_id)

println("Read arrays from example.h5:")
println("integers: ", integers)
println("floats: ", floats)
println("matrix: ", matrix)
println()

# Example 2: Working with groups
println("Example 2: Working with groups")
println("-----------------------------")

# Create a file with groups
file_id = create_file("grouped_example.h5")

# Create a group and write data to it
group_id = create_group(file_id, "measurements")
write_array(group_id, "temperatures", [22.1, 22.3, 22.0, 21.8])

# Create a subgroup and write data to it
subgroup_id = create_group(group_id, "day1")
write_array(subgroup_id, "morning", [20.1, 20.5, 21.0])
write_array(subgroup_id, "evening", [19.8, 19.5, 19.2])

# Close groups and file
SimpleHDF5.API.h5g_close(subgroup_id)
SimpleHDF5.API.h5g_close(group_id)
close_file(file_id)

println("Written grouped data to grouped_example.h5")

# Read the grouped data
file_id = open_file("grouped_example.h5", READ_ONLY)  # Explicitly using READ_ONLY mode

# Read from the main group
group_id = SimpleHDF5.API.h5g_open(file_id, "measurements", SimpleHDF5.API.H5P_DEFAULT)
temperatures = read_array(group_id, "temperatures", Float64)

# Read from the subgroup
subgroup_id = SimpleHDF5.API.h5g_open(group_id, "day1", SimpleHDF5.API.H5P_DEFAULT)
morning = read_array(subgroup_id, "morning", Float64)
evening = read_array(subgroup_id, "evening", Float64)

# Close everything
SimpleHDF5.API.h5g_close(subgroup_id)
SimpleHDF5.API.h5g_close(group_id)
close_file(file_id)

println("Read grouped data from grouped_example.h5:")
println("temperatures: ", temperatures)
println("morning: ", morning)
println("evening: ", evening)
println()

# Example 3: Listing datasets
println("Example 3: Listing datasets")
println("--------------------------")

file_id = open_file("example.h5")
datasets = list_datasets(file_id)
println("Datasets in example.h5: ", datasets)
close_file(file_id)

file_id = open_file("grouped_example.h5")
datasets = list_datasets(file_id)
println("Datasets in root of grouped_example.h5: ", datasets)

group_id = SimpleHDF5.API.h5g_open(file_id, "measurements", SimpleHDF5.API.H5P_DEFAULT)
datasets = list_datasets(file_id, "measurements")
println("Datasets in measurements group: ", datasets)

datasets = list_datasets(file_id, "measurements/day1")
println("Datasets in measurements/day1 group: ", datasets)

SimpleHDF5.API.h5g_close(group_id)
close_file(file_id)
println()

# Example 4: Type-stable reading approaches
println("Example 4: Type-stable reading approaches")
println("---------------------------------------")

# Create a file with different types of arrays
file_id = create_file("types_example.h5")
write_array(file_id, "integers", [1, 2, 3])
write_array(file_id, "floats", [1.1, 2.2, 3.3])
write_array(file_id, "booleans", [true, false, true])
write_array(file_id, "matrix", reshape(1:12, 3, 4))
close_file(file_id)

# Read using different type-stable approaches
file_id = open_file("types_example.h5")

println("Approach 1: Using get_array_info + parametric array types")
println("-----------------------------------------------------------")

# Step 1: Get info about each dataset (this is type-stable)
int_type, int_dims = get_array_info(file_id, "integers")
float_type, float_dims = get_array_info(file_id, "floats")
bool_type, bool_dims = get_array_info(file_id, "booleans")
matrix_type, matrix_dims = get_array_info(file_id, "matrix")

println("Dataset info:")
println("  integers: type=$(int_type), dims=$(int_dims)")
println("  floats: type=$(float_type), dims=$(float_dims)")
println("  booleans: type=$(bool_type), dims=$(bool_dims)")
println("  matrix: type=$(matrix_type), dims=$(matrix_dims)")

# Step 2: Read with parametric array types for type stability
# This approach allows Julia to optimize the code better
integers = read_array(file_id, "integers", Array{Int,1})
floats = read_array(file_id, "floats", Array{Float64,1})
booleans = read_array(file_id, "booleans", Array{Bool,1})
matrix = read_array(file_id, "matrix", Array{Int,2})

println("Read data with type stability (using parametric array types):")
println("  integers: ", integers)
println("  floats: ", floats)
println("  booleans: ", booleans)
println("  matrix: ", matrix)
println()

println("Approach 2: Using convenience parametric types (simpler)")
println("-----------------------------------------------")

# Read directly with convenience parametric array types
# This is more concise and still type-stable
integers2 = read_array(file_id, "integers", Vector{Int})
floats2 = read_array(file_id, "floats", Vector{Float64})
booleans2 = read_array(file_id, "booleans", Vector{Bool})
matrix2 = read_array(file_id, "matrix", Matrix{Int})

println("Read data with type stability (using convenience parametric types):")
println("  integers: ", integers2)
println("  floats: ", floats2)
println("  booleans: ", booleans2)
println("  matrix: ", matrix2)

close_file(file_id)
println()

# Example 5: Different array types
println("Example 5: Different array types")
println("------------------------------")

# Create a file with different array types
file_id = create_file("array_types.h5")

# Regular Array
regular_array = [1, 2, 3, 4, 5]
write_array(file_id, "regular", regular_array)

# Reshaped Range
reshaped_range = reshape(1:12, 3, 4)
write_array(file_id, "reshaped", reshaped_range)

# View of an array
original = rand(10, 10)
array_view = @view original[1:5, 1:5]
write_array(file_id, "view", array_view)

close_file(file_id)

# Read back the arrays
file_id = open_file("array_types.h5")

# For best performance, use the type-stable approach with parametric types:
read_regular = read_array(file_id, "regular", Vector{Int})
read_reshaped = read_array(file_id, "reshaped", Matrix{Int})
read_view = read_array(file_id, "view", Matrix{Float64})

close_file(file_id)

println("Different array types:")
println("  Regular array: ", read_regular)
println("  Reshaped range: ", read_reshaped)
println("  Array view: ", read_view)
println()

# Example 6: Performance comparison - Type stability matters!
println("Example 6: Performance comparison")
println("--------------------------------")

# Create a test file with a large array
file_id = create_file("performance_test.h5")
large_array = rand(100, 100)  # 10,000 element array
write_array(file_id, "large_array", large_array)
close_file(file_id)

file_id = open_file("performance_test.h5")

# Get array info once
elem_type, dims = get_array_info(file_id, "large_array")

# Benchmark non-type-stable version (dimensions unknown at compile time)
println("Non-type-stable version (without dimensions):")
@btime read_array($file_id, "large_array", Float64)

# Benchmark type-stable version with parametric type
println("Type-stable version (with parametric type):")
@btime read_array($file_id, "large_array", Matrix{Float64})

close_file(file_id)
println()

println("All examples completed successfully!") 
#!/usr/bin/env julia

using HDF5
using BenchmarkTools
include("SimpleHDF5.jl")
using .SimpleHDF5

# Create test data
const SMALL_ARRAY = rand(100, 100)
const MEDIUM_ARRAY = rand(1000, 1000)
const LARGE_ARRAY = rand(2000, 2000)

function benchmark_write()
    println("Benchmarking write operations")
    println("-----------------------------")
    
    # Benchmark SimpleHDF5 write
    println("\nSimpleHDF5 - Small array (100x100):")
    @btime begin
        file_id = create_file("simple_small.h5")
        write_array(file_id, "data", $SMALL_ARRAY)
        close_file(file_id)
    end
    
    println("\nSimpleHDF5 - Medium array (1000x1000):")
    @btime begin
        file_id = create_file("simple_medium.h5")
        write_array(file_id, "data", $MEDIUM_ARRAY)
        close_file(file_id)
    end
    
    println("\nSimpleHDF5 - Large array (2000x2000):")
    @btime begin
        file_id = create_file("simple_large.h5")
        write_array(file_id, "data", $LARGE_ARRAY)
        close_file(file_id)
    end
    
    # Benchmark HDF5.jl write
    println("\nHDF5.jl - Small array (100x100):")
    @btime begin
        h5open("hdf5_small.h5", "w") do file
            file["data"] = $SMALL_ARRAY
        end
    end
    
    println("\nHDF5.jl - Medium array (1000x1000):")
    @btime begin
        h5open("hdf5_medium.h5", "w") do file
            file["data"] = $MEDIUM_ARRAY
        end
    end
    
    println("\nHDF5.jl - Large array (2000x2000):")
    @btime begin
        h5open("hdf5_large.h5", "w") do file
            file["data"] = $LARGE_ARRAY
        end
    end
end

function benchmark_read()
    println("\nBenchmarking read operations")
    println("----------------------------")
    
    # Create files for reading
    file_id = create_file("simple_read.h5")
    write_array(file_id, "data", MEDIUM_ARRAY)
    close_file(file_id)
    
    h5open("hdf5_read.h5", "w") do file
        file["data"] = MEDIUM_ARRAY
    end
    
    # Benchmark SimpleHDF5 read
    println("\nSimpleHDF5 - Medium array (1000x1000):")
    @btime begin
        file_id = open_file("simple_read.h5")
        data = read_array(file_id, "data", Float64)
        close_file(file_id)
    end
    
    # Benchmark HDF5.jl read
    println("\nHDF5.jl - Medium array (1000x1000):")
    @btime begin
        h5open("hdf5_read.h5", "r") do file
            data = read(file["data"])
        end
    end
end

function benchmark_group_operations()
    println("\nBenchmarking group operations")
    println("-----------------------------")
    
    # Benchmark SimpleHDF5 group operations
    println("\nSimpleHDF5 - Creating and writing to groups:")
    @btime begin
        file_id = create_file("simple_groups.h5")
        group_id = create_group(file_id, "group1")
        write_array(group_id, "data1", $SMALL_ARRAY)
        subgroup_id = create_group(group_id, "subgroup")
        write_array(subgroup_id, "data2", $SMALL_ARRAY)
        API.h5g_close(subgroup_id)
        API.h5g_close(group_id)
        close_file(file_id)
    end
    
    # Benchmark HDF5.jl group operations
    println("\nHDF5.jl - Creating and writing to groups:")
    @btime begin
        h5open("hdf5_groups.h5", "w") do file
            g1 = create_group(file, "group1")
            g1["data1"] = $SMALL_ARRAY
            g2 = create_group(g1, "subgroup")
            g2["data2"] = $SMALL_ARRAY
        end
    end
end

function run_benchmarks()
    println("Running benchmarks comparing SimpleHDF5 vs HDF5.jl")
    println("==================================================")
    
    benchmark_write()
    benchmark_read()
    benchmark_group_operations()
    
    println("\nBenchmarks completed!")
end

run_benchmarks() 
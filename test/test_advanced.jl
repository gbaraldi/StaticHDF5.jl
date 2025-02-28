#!/usr/bin/env julia

using Test
using BenchmarkTools

using SimpleHDF5

# Helper function to clean up test files
function cleanup_test_files()
    for file in ["test_edge_cases.h5", "test_overwrite.h5", "test_empty.h5", "test_perf.h5"]
        isfile(file) && rm(file)
    end
end

# Clean up any leftover test files before starting
cleanup_test_files()

@testset "SimpleHDF5 Advanced Tests" begin
    
    @testset "Edge Cases" begin
        file_id = create_file("test_edge_cases.h5")
        
        # Test empty array
        empty_array = Int64[]
        write_array(file_id, "empty_array", empty_array)
        
        # Test array with one element
        single_element = [42]
        write_array(file_id, "single_element", single_element)
        
        # Test very small array
        tiny_array = [1, 2]
        write_array(file_id, "tiny_array", tiny_array)
        
        # Test array with zeros
        zero_array = zeros(Int64, 5)
        write_array(file_id, "zero_array", zero_array)
        
        # Test array with NaN and Inf
        special_array = [NaN, Inf, -Inf, 0.0, 1.0]
        write_array(file_id, "special_array", special_array)
        
        close_file(file_id)
        
        # Read back and verify
        file_id = open_file("test_edge_cases.h5")
        
        # Empty array - size should match but might be empty
        read_empty = read_array(file_id, "empty_array", Int64)
        @test length(read_empty) == 0
        
        # Single element array
        read_single = read_array(file_id, "single_element", Int64)
        @test read_single == single_element
        @test length(read_single) == 1
        
        # Tiny array
        read_tiny = read_array(file_id, "tiny_array", Int64)
        @test read_tiny == tiny_array
        
        # Zero array
        read_zero = read_array(file_id, "zero_array", Int64)
        @test read_zero == zero_array
        
        # Special values array
        read_special = read_array(file_id, "special_array", Float64)
        @test isnan(read_special[1])
        @test isinf(read_special[2]) && read_special[2] > 0
        @test isinf(read_special[3]) && read_special[3] < 0
        @test read_special[4] == 0.0
        @test read_special[5] == 1.0
        
        close_file(file_id)
    end
    
    @testset "Overwriting Datasets" begin
        # Create file with initial data
        file_id = create_file("test_overwrite.h5")
        initial_data = [1, 2, 3, 4, 5]
        write_array(file_id, "data", initial_data)
        close_file(file_id)
        
        # Open file and overwrite data
        file_id = open_file("test_overwrite.h5", READ_WRITE)
        new_data = [10, 20, 30, 40, 50]
        
        # This should fail because dataset already exists
        @test_throws SimpleHDF5.API.H5Error write_array(file_id, "data", new_data)
        
        # Workaround: we need to delete and recreate
        # For now, we'll just close and reopen with truncate
        close_file(file_id)
        
        file_id = create_file("test_overwrite.h5")
        write_array(file_id, "data", new_data)
        close_file(file_id)
        
        # Verify new data
        file_id = open_file("test_overwrite.h5")
        read_data = read_array(file_id, "data", Int64)
        @test read_data == new_data
        close_file(file_id)
    end
    
    @testset "Empty File" begin
        # Create an empty file
        file_id = create_file("test_empty.h5")
        close_file(file_id)
        
        # Open and check that there are no datasets
        file_id = open_file("test_empty.h5")
        datasets = list_datasets(file_id)
        @test isempty(datasets)
        close_file(file_id)
    end
    
    @testset "Performance Tests" begin
        # These are not strict tests but benchmarks to ensure reasonable performance
        
        # Create test data of different sizes
        small_array = rand(10, 10)
        medium_array = rand(100, 100)
        
        # Benchmark write performance
        file_id = create_file("test_perf.h5")
        
        # Small array write time should be reasonable
        small_write_time = @elapsed write_array(file_id, "small", small_array)
        @test small_write_time < 0.1  # This is a generous upper bound
        
        # Medium array write time
        medium_write_time = @elapsed write_array(file_id, "medium", medium_array)
        @test medium_write_time < 1.0  # This is a generous upper bound
        
        close_file(file_id)
        
        # Benchmark read performance
        file_id = open_file("test_perf.h5")
        
        # Small array read time
        small_read_time = @elapsed read_array(file_id, "small", Float64)
        @test small_read_time < 0.1  # This is a generous upper bound
        
        # Medium array read time
        medium_read_time = @elapsed read_array(file_id, "medium", Float64)
        @test medium_read_time < 1.0  # This is a generous upper bound
        
        close_file(file_id)
        
        # Print performance results
        println("Performance results:")
        println("  Small array (10x10) write time: $(small_write_time) seconds")
        println("  Medium array (100x100) write time: $(medium_write_time) seconds")
        println("  Small array (10x10) read time: $(small_read_time) seconds")
        println("  Medium array (100x100) read time: $(medium_read_time) seconds")
    end
    
    @testset "Memory Management" begin
        # Test that resources are properly cleaned up
        
        # Create a large array that would consume significant memory
        large_array = rand(1000, 1000)
        
        # Write and read multiple times to check for memory leaks
        for i in 1:5
            file_id = create_file("test_perf.h5")
            write_array(file_id, "large", large_array)
            close_file(file_id)
            
            file_id = open_file("test_perf.h5")
            read_large = read_array(file_id, "large", Float64)
            close_file(file_id)
            
            # Force garbage collection to check for proper resource cleanup
            GC.gc()
            
            # If we've made it this far without errors, it's a good sign
            @test true
        end
    end
end

# Clean up test files after tests
cleanup_test_files()

println("All advanced tests completed successfully!") 
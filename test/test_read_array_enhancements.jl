#!/usr/bin/env julia

using Test
using SimpleHDF5

# Helper function to clean up test files
function cleanup_test_files()
    isfile("test_read_enhancements.h5") && rm("test_read_enhancements.h5")
end

# Clean up any leftover test files before starting
cleanup_test_files()

@testset "SimpleHDF5 Read Array Enhancements Tests" begin
    
    @testset "get_array_info Function" begin
        # Create test data of different types and dimensions
        int32_1d = Int32[1, 2, 3, 4, 5]
        float64_2d = reshape(1.0:12.0, 3, 4)
        bool_3d = reshape(repeat([true, false], 12), 2, 3, 4)
        
        # Write arrays
        file_id = create_file("test_read_enhancements.h5")
        write_array(file_id, "int32_1d", int32_1d)
        write_array(file_id, "float64_2d", float64_2d)
        write_array(file_id, "bool_3d", bool_3d)
        close_file(file_id)
        
        # Test get_array_info
        file_id = open_file("test_read_enhancements.h5")
        
        # Check int32_1d
        elem_type, dims = get_array_info(file_id, "int32_1d")
        @test elem_type == Int32
        @test dims == (5,)
        
        # Check float64_2d
        elem_type, dims = get_array_info(file_id, "float64_2d")
        @test elem_type == Float64
        @test dims == (3, 4)
        
        # Check bool_3d
        elem_type, dims = get_array_info(file_id, "bool_3d")
        @test elem_type == Bool
        @test dims == (2, 3, 4)
        
        close_file(file_id)
    end
    
    @testset "Dimension-Specified read_array" begin
        # Create test data
        test_array_2d = reshape(1:12, 3, 4)
        
        # Write array
        file_id = create_file("test_read_enhancements.h5")
        write_array(file_id, "array_2d", test_array_2d)
        close_file(file_id)
        
        # Read array with correct dimensions
        file_id = open_file("test_read_enhancements.h5")
        read_array_2d = read_array(file_id, "array_2d", Int64, (3, 4))
        @test read_array_2d == test_array_2d
        
        # Test with incorrect dimensions
        @test_throws SimpleHDF5.API.H5Error read_array(file_id, "array_2d", Int64, (4, 3))
        @test_throws SimpleHDF5.API.H5Error read_array(file_id, "array_2d", Int64, (3, 3))
        @test_throws SimpleHDF5.API.H5Error read_array(file_id, "array_2d", Int64, (12,))
        
        close_file(file_id)
    end
    
    @testset "Type Compatibility Checking" begin
        # Create test data
        int_array = [1, 2, 3]
        float_array = [1.1, 2.2, 3.3]
        bool_array = [true, false, true]
        
        # Write arrays
        file_id = create_file("test_read_enhancements.h5")
        write_array(file_id, "int_array", int_array)
        write_array(file_id, "float_array", float_array)
        write_array(file_id, "bool_array", bool_array)
        close_file(file_id)
        
        # Read arrays with compatible types
        file_id = open_file("test_read_enhancements.h5")
        
        # Integer can be read as float
        float_from_int = read_array(file_id, "int_array", Float64)
        @test float_from_int ≈ [1.0, 2.0, 3.0]
        
        # Float can be read as integer (with potential loss of precision)
        int_from_float = read_array(file_id, "float_array", Int64)
        @test int_from_float == [1, 2, 3]
        
        # Test incompatible types
        @test_throws SimpleHDF5.API.H5Error read_array(file_id, "bool_array", Int64, (3,))
        @test_throws SimpleHDF5.API.H5Error read_array(file_id, "int_array", Bool, (3,))
        
        close_file(file_id)
    end
    
    @testset "Type Stability" begin
        # Create test data
        test_array = rand(Float64, 10, 10)
        
        # Write array
        file_id = create_file("test_read_enhancements.h5")
        write_array(file_id, "test_array", test_array)
        close_file(file_id)
        
        # Open file and test type stability
        file_id = open_file("test_read_enhancements.h5")
        
        # Test with dimensions specified (should be type stable)
        @inferred read_array(file_id, "test_array", Float64, (10, 10))
        
        # Test regular reading (not using @inferred as it won't pass)
        result = read_array(file_id, "test_array", Float64)
        @test result ≈ test_array
        
        close_file(file_id)
    end
    
    @testset "Workflow Example" begin
        # Create test data
        test_array = rand(Float64, 5, 5)
        
        # Write array
        file_id = create_file("test_read_enhancements.h5")
        write_array(file_id, "test_array", test_array)
        close_file(file_id)
        
        # Typical workflow: first get info, then read with exact type and dimensions
        file_id = open_file("test_read_enhancements.h5")
        
        # Step 1: Get information about the array
        elem_type, dims = get_array_info(file_id, "test_array")
        
        # Step 2: Read the array with the exact type and dimensions
        result = read_array(file_id, "test_array", elem_type, dims)
        
        # Verify result
        @test result ≈ test_array
        @test typeof(result) == Array{Float64, 2}
        @test size(result) == (5, 5)
        
        close_file(file_id)
    end
end

# Clean up test files after tests
cleanup_test_files()

println("All read array enhancement tests completed successfully!") 
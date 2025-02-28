#!/usr/bin/env julia

# Add the src directory to the load path
push!(LOAD_PATH, joinpath(dirname(@__DIR__), "src"))
using Test
using SimpleHDF5

# Define a dummy macro that does nothing if JET is not available
macro test_opt(expr)
    esc(expr)
end
using JET

# Cleanup any leftover test files before starting
function cleanup_test_files()
    for file in ["test_type_stability_file.h5", "test_type_stability_write.h5", 
                 "test_type_stability_read.h5", "test_type_stability_complex.h5",
                 "test_type_stability_parametric.h5"]
        isfile(file) && rm(file)
    end
end

# Clean up before starting tests
cleanup_test_files()

@testset "SimpleHDF5 Type Stability Tests" begin
    @testset "File Operations Type Stability" begin
        # Test file creation
        file_id = SimpleHDF5.create_file("test_type_stability_file.h5")
        @test file_id isa Int
        SimpleHDF5.close_file(file_id)
        
        # Test file opening
        file_id = SimpleHDF5.open_file("test_type_stability_file.h5", SimpleHDF5.READ_ONLY)
        @test file_id isa Int
        SimpleHDF5.close_file(file_id)
        
        # Test group creation
        file_id = SimpleHDF5.create_file("test_type_stability_file.h5")
        group_id = SimpleHDF5.create_group(file_id, "group1")
        @test group_id isa Int
        SimpleHDF5.API.h5g_close(group_id)
        SimpleHDF5.close_file(file_id)
    end
    
    @testset "Write Operations Type Stability" begin
        # Create a new file for write tests
        file_id = SimpleHDF5.create_file("test_type_stability_write.h5")
        
        # Test writing different types of arrays
        int_array = [1, 2, 3, 4]
        float_array = [1.1, 2.2, 3.3, 4.4]
        bool_array = [true, false, true, false]
        
        JET.@test_opt SimpleHDF5.write_array(file_id, "int_array", int_array)
        JET.@test_opt SimpleHDF5.write_array(file_id, "float_array", float_array)
        JET.@test_opt SimpleHDF5.write_array(file_id, "bool_array", bool_array)
        
        # Actually write the arrays for subsequent tests
        SimpleHDF5.write_array(file_id, "int_array", int_array)
        SimpleHDF5.write_array(file_id, "float_array", float_array)
        SimpleHDF5.write_array(file_id, "bool_array", bool_array)
        
        # Verify the arrays were written correctly
        @test "int_array" in SimpleHDF5.list_datasets(file_id)
        @test "float_array" in SimpleHDF5.list_datasets(file_id)
        @test "bool_array" in SimpleHDF5.list_datasets(file_id)
        
        # Test writing arrays to groups
        group_id = SimpleHDF5.create_group(file_id, "group1")
        JET.@test_opt SimpleHDF5.write_array(group_id, "group_int_array", int_array)
        SimpleHDF5.write_array(group_id, "group_int_array", int_array)
        SimpleHDF5.API.h5g_close(group_id)
        
        # Test listing datasets
        JET.@test_opt SimpleHDF5.list_datasets(file_id)
        
        # Close the file
        SimpleHDF5.close_file(file_id)
    end
    
    @testset "Read Operations Type Stability" begin
        # Create a new file for read tests with test data
        file_id = SimpleHDF5.create_file("test_type_stability_read.h5")
        
        # Write test data
        int_array = [1, 2, 3, 4]
        float_array = [1.1, 2.2, 3.3, 4.4]
        bool_array = [true, false, true, false]
        
        SimpleHDF5.write_array(file_id, "int_array", int_array)
        SimpleHDF5.write_array(file_id, "float_array", float_array)
        SimpleHDF5.write_array(file_id, "bool_array", bool_array)
        
        # Close and reopen the file for reading
        SimpleHDF5.close_file(file_id)
        file_id = SimpleHDF5.open_file("test_type_stability_read.h5", SimpleHDF5.READ_ONLY)
        
        # Test getting array info (this is type stable)
        JET.@test_opt SimpleHDF5.get_array_info(file_id, "int_array")
        
        # Get dimensions for type-stable reading
        int_type, int_dims = SimpleHDF5.get_array_info(file_id, "int_array")
        float_type, float_dims = SimpleHDF5.get_array_info(file_id, "float_array")
        bool_type, bool_dims = SimpleHDF5.get_array_info(file_id, "bool_array")
        
        # Test reading arrays with parametric types using JET (this is type stable)
        JET.@test_opt SimpleHDF5.read_array(file_id, "int_array", Array{Int,1})
        JET.@test_opt SimpleHDF5.read_array(file_id, "float_array", Array{Float64,1})
        JET.@test_opt SimpleHDF5.read_array(file_id, "bool_array", Array{Bool,1})
        
        # Verify the arrays were read correctly
        @test SimpleHDF5.read_array(file_id, "int_array", Array{Int,1}) == int_array
        @test SimpleHDF5.read_array(file_id, "float_array", Array{Float64,1}) == float_array
        @test SimpleHDF5.read_array(file_id, "bool_array", Array{Bool,1}) == bool_array
        
        # Test convenience methods for Vector and Matrix
        @test SimpleHDF5.read_array(file_id, "int_array", Vector{Int}) == int_array
        @test SimpleHDF5.read_array(file_id, "float_array", Vector{Float64}) == float_array
        @test SimpleHDF5.read_array(file_id, "bool_array", Vector{Bool}) == bool_array
        
        # Note: Reading without dimensions is not type stable, so we don't test it with JET
        # But we verify it works functionally
        @test SimpleHDF5.read_array(file_id, "int_array", Int) == int_array
        @test SimpleHDF5.read_array(file_id, "float_array", Float64) == float_array
        @test SimpleHDF5.read_array(file_id, "bool_array", Bool) == bool_array
        
        # Close the file
        SimpleHDF5.close_file(file_id)
    end
    
    @testset "Complex Array Type Stability" begin
        # Create a new file for complex array tests
        file_id = SimpleHDF5.create_file("test_type_stability_complex.h5")
        
        # Create and write a 2D array
        array_2d = [i + j for i in 1:3, j in 1:4]
        SimpleHDF5.write_array(file_id, "array_2d", array_2d)
        
        # Create and write a 3D array
        array_3d = [i + j + k for i in 1:2, j in 1:3, k in 1:4]
        SimpleHDF5.write_array(file_id, "array_3d", array_3d)
        
        # Close and reopen the file for reading
        SimpleHDF5.close_file(file_id)
        file_id = SimpleHDF5.open_file("test_type_stability_complex.h5", SimpleHDF5.READ_ONLY)
        
        # Test reading arrays with parametric types using JET (this is type stable)
        JET.@test_opt SimpleHDF5.read_array(file_id, "array_2d", Array{Int,2})
        JET.@test_opt SimpleHDF5.read_array(file_id, "array_3d", Array{Int,3})
        
        # Verify the arrays were read correctly
        @test SimpleHDF5.read_array(file_id, "array_2d", Array{Int,2}) == array_2d
        @test SimpleHDF5.read_array(file_id, "array_3d", Array{Int,3}) == array_3d
        
        # Test convenience methods for Matrix
        @test SimpleHDF5.read_array(file_id, "array_2d", Matrix{Int}) == array_2d
        
        # Note: Reading without dimensions is not type stable, so we don't test it with JET
        # But we verify it works functionally
        @test SimpleHDF5.read_array(file_id, "array_2d", Int) == array_2d
        @test SimpleHDF5.read_array(file_id, "array_3d", Int) == array_3d
        
        # Close the file
        SimpleHDF5.close_file(file_id)
    end
    
    @testset "Parametric Type Array Reading" begin
        # Create a new file for parametric type tests
        file_id = SimpleHDF5.create_file("test_type_stability_parametric.h5")
        
        # Write test data
        vector_data = [1, 2, 3, 4, 5]
        matrix_data = [i + j for i in 1:3, j in 1:4]
        tensor_data = [i + j + k for i in 1:2, j in 1:3, k in 1:4]
        
        SimpleHDF5.write_array(file_id, "vector", vector_data)
        SimpleHDF5.write_array(file_id, "matrix", matrix_data)
        SimpleHDF5.write_array(file_id, "tensor", tensor_data)
        
        # Close and reopen the file for reading
        SimpleHDF5.close_file(file_id)
        file_id = SimpleHDF5.open_file("test_type_stability_parametric.h5", SimpleHDF5.READ_ONLY)
        
        # Test reading with parametric types using JET (these should be type stable)
        JET.@test_opt SimpleHDF5.read_array(file_id, "vector", Vector{Int})
        JET.@test_opt SimpleHDF5.read_array(file_id, "matrix", Matrix{Int})
        JET.@test_opt SimpleHDF5.read_array(file_id, "tensor", Array{Int, 3})
        
        # Verify the arrays were read correctly
        @test SimpleHDF5.read_array(file_id, "vector", Vector{Int}) == vector_data
        @test SimpleHDF5.read_array(file_id, "matrix", Matrix{Int}) == matrix_data
        @test SimpleHDF5.read_array(file_id, "tensor", Array{Int, 3}) == tensor_data
        
        # Test error cases
        # Trying to read a vector as a matrix should throw an error
        @test_throws SimpleHDF5.API.H5Error SimpleHDF5.read_array(file_id, "vector", Matrix{Int})
        
        # Close the file
        SimpleHDF5.close_file(file_id)
    end
    
    @testset "Type Stability Workflow" begin
        # This testset demonstrates the recommended workflow for type-stable operations
        
        # Create a file with test data
        file_id = SimpleHDF5.create_file("test_type_stability_file.h5")
        test_array = rand(Int, 3, 4, 5)
        SimpleHDF5.write_array(file_id, "test_array", test_array)
        SimpleHDF5.close_file(file_id)
        
        # Recommended type-stable workflow:
        file_id = SimpleHDF5.open_file("test_type_stability_file.h5")
        
        # 1. Get array info (type stable)
        # Note: JET.@test_opt only analyzes code for type stability but doesn't run it
        JET.@test_opt SimpleHDF5.get_array_info(file_id, "test_array")
        elem_type, dims = SimpleHDF5.get_array_info(file_id, "test_array")
        
        # 2. Read with parametric array type (type stable)
        JET.@test_opt SimpleHDF5.read_array(file_id, "test_array", Array{Int, 3})
        result = SimpleHDF5.read_array(file_id, "test_array", Array{Int, 3})
        
        # Verify results
        @test result == test_array
        @test size(result) == size(test_array)
        
        SimpleHDF5.close_file(file_id)
    end
end

# Final cleanup
cleanup_test_files()

println("All type stability tests completed successfully!") 
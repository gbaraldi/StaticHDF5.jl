#!/usr/bin/env julia

using Test
using SimpleHDF5

# Helper function to clean up test files
function cleanup_test_files()
    isfile("test_bool.h5") && rm("test_bool.h5")
end

# Clean up any leftover test files before starting
cleanup_test_files()

@testset "SimpleHDF5 Bool Type Handling Tests" begin
    
    @testset "Basic Bool Array Operations" begin
        # Create test file
        file_id = SimpleHDF5.create_file("test_bool.h5")
        
        # Create and write Bool arrays
        bool_1d = Bool[true, false, true, false, true]
        bool_2d = Bool[true false true; false true false]
        
        SimpleHDF5.write_array(file_id, "/bool_1d", bool_1d)
        SimpleHDF5.write_array(file_id, "/bool_2d", bool_2d)
        
        # Read arrays back
        read_bool_1d = SimpleHDF5.read_array(file_id, "/bool_1d", Bool)
        read_bool_2d = SimpleHDF5.read_array(file_id, "/bool_2d", Bool)
        
        # Close file
        SimpleHDF5.close_file(file_id)
        
        # Check array equality
        @test read_bool_1d == bool_1d
        @test read_bool_2d == bool_2d
        @test size(read_bool_1d) == size(bool_1d)
        @test size(read_bool_2d) == size(bool_2d)
    end
    
    # Clean up between tests
    cleanup_test_files()
    
    @testset "Bool Type Detection" begin
        # Create test data
        bool_array = [true, false, true]
        
        # Write array
        file_id = create_file("test_bool.h5")
        write_array(file_id, "bool_array", bool_array)
        close_file(file_id)
        
        # Test type detection
        file_id = open_file("test_bool.h5")
        elem_type, dims = get_array_info(file_id, "bool_array")
        close_file(file_id)
        
        # Verify detected type
        @test elem_type == Bool
        @test dims == (3,)
    end
    
    # Clean up between tests
    cleanup_test_files()
    
    @testset "Bool-Integer Conversion" begin
        # Create test data
        bool_array = [true, false, true]
        int_array = [1, 0, 1]
        
        # Write arrays
        file_id = create_file("test_bool.h5")
        write_array(file_id, "bool_array", bool_array)
        write_array(file_id, "int_array", int_array)
        close_file(file_id)
        
        # Read with type conversion
        file_id = open_file("test_bool.h5")
        
        # Read bool as integers - this is now disallowed
        @test_throws SimpleHDF5.API.H5Error read_array(file_id, "bool_array", Int8)
        
        # Read integers as bool - this is now disallowed
        @test_throws SimpleHDF5.API.H5Error read_array(file_id, "int_array", Bool)
        
        close_file(file_id)
    end
    
    # Clean up between tests
    cleanup_test_files()
    
    @testset "Large Bool Arrays" begin
        # Create test file
        file_id = SimpleHDF5.create_file("test_bool.h5")
        
        # Create and write large Bool array
        large_bool = rand(Bool, 100, 100)
        
        SimpleHDF5.write_array(file_id, "/large_bool", large_bool)
        
        # Read array back
        read_large_bool = SimpleHDF5.read_array(file_id, "/large_bool", Bool)
        
        # Close file
        SimpleHDF5.close_file(file_id)
        
        # Check array equality
        @test read_large_bool == large_bool
        @test size(read_large_bool) == size(large_bool)
    end
    
    # Clean up between tests
    cleanup_test_files()
    
    @testset "Type-Stable Bool Reading" begin
        # Create test file
        file_id = SimpleHDF5.create_file("test_bool.h5")
        
        # Create and write Bool array
        bool_array = Bool[true false true; false true false]
        
        SimpleHDF5.write_array(file_id, "/bool_array", bool_array)
        
        # Read array back with type stability
        read_bool_array = SimpleHDF5.read_array(file_id, "/bool_array", Bool)
        
        # Close file
        SimpleHDF5.close_file(file_id)
        
        # Check array equality and type stability
        @test read_bool_array == bool_array
        @test size(read_bool_array) == size(bool_array)
        @test typeof(read_bool_array) == typeof(bool_array)
    end
end

# Clean up test files after tests
cleanup_test_files()

println("All Bool handling tests completed successfully!") 
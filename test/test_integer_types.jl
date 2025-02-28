#!/usr/bin/env julia

using Test
using SimpleHDF5

# Helper function to clean up test files
function cleanup_test_files()
    isfile("test_integer_types.h5") && rm("test_integer_types.h5")
end

# Clean up any leftover test files before starting
cleanup_test_files()

@testset "SimpleHDF5 Integer Types Tests" begin
    
    @testset "Basic Integer Type Tests" begin
        # Create test data for each integer type
        int8_array = Int8[-128, 0, 127]
        int16_array = Int16[-32768, 0, 32767]
        uint8_array = UInt8[0, 128, 255]
        uint16_array = UInt16[0, 32768, 65535]
        
        # Write arrays
        file_id = create_file("test_integer_types.h5")
        write_array(file_id, "int8", int8_array)
        write_array(file_id, "int16", int16_array)
        write_array(file_id, "uint8", uint8_array)
        write_array(file_id, "uint16", uint16_array)
        close_file(file_id)
        
        # Read arrays
        file_id = open_file("test_integer_types.h5")
        read_int8 = read_array(file_id, "int8", Int8)
        read_int16 = read_array(file_id, "int16", Int16)
        read_uint8 = read_array(file_id, "uint8", UInt8)
        read_uint16 = read_array(file_id, "uint16", UInt16)
        close_file(file_id)
        
        # Test array equality
        @test read_int8 == int8_array
        @test read_int16 == int16_array
        @test read_uint8 == uint8_array
        @test read_uint16 == uint16_array
    end
    
    @testset "Edge Cases" begin
        # Test min and max values for each type
        int8_min_max = Int8[typemin(Int8), typemax(Int8)]
        int16_min_max = Int16[typemin(Int16), typemax(Int16)]
        uint8_min_max = UInt8[typemin(UInt8), typemax(UInt8)]
        uint16_min_max = UInt16[typemin(UInt16), typemax(UInt16)]
        
        # Write arrays
        file_id = create_file("test_integer_types.h5")
        write_array(file_id, "int8_min_max", int8_min_max)
        write_array(file_id, "int16_min_max", int16_min_max)
        write_array(file_id, "uint8_min_max", uint8_min_max)
        write_array(file_id, "uint16_min_max", uint16_min_max)
        close_file(file_id)
        
        # Read arrays
        file_id = open_file("test_integer_types.h5")
        read_int8_min_max = read_array(file_id, "int8_min_max", Int8)
        read_int16_min_max = read_array(file_id, "int16_min_max", Int16)
        read_uint8_min_max = read_array(file_id, "uint8_min_max", UInt8)
        read_uint16_min_max = read_array(file_id, "uint16_min_max", UInt16)
        close_file(file_id)
        
        # Test array equality
        @test read_int8_min_max == int8_min_max
        @test read_int16_min_max == int16_min_max
        @test read_uint8_min_max == uint8_min_max
        @test read_uint16_min_max == uint16_min_max
    end
    
    @testset "Multidimensional Arrays" begin
        # Create 2D arrays of different integer types
        int8_2d = reshape(Int8.(1:16), 4, 4)
        int16_2d = reshape(Int16.(1:16), 4, 4)
        uint8_2d = reshape(UInt8.(1:16), 4, 4)
        uint16_2d = reshape(UInt16.(1:16), 4, 4)
        
        # Write arrays
        file_id = create_file("test_integer_types.h5")
        write_array(file_id, "int8_2d", int8_2d)
        write_array(file_id, "int16_2d", int16_2d)
        write_array(file_id, "uint8_2d", uint8_2d)
        write_array(file_id, "uint16_2d", uint16_2d)
        close_file(file_id)
        
        # Read arrays
        file_id = open_file("test_integer_types.h5")
        read_int8_2d = read_array(file_id, "int8_2d", Int8)
        read_int16_2d = read_array(file_id, "int16_2d", Int16)
        read_uint8_2d = read_array(file_id, "uint8_2d", UInt8)
        read_uint16_2d = read_array(file_id, "uint16_2d", UInt16)
        close_file(file_id)
        
        # Test array equality
        @test read_int8_2d == int8_2d
        @test read_int16_2d == int16_2d
        @test read_uint8_2d == uint8_2d
        @test read_uint16_2d == uint16_2d
        
        # Test dimensions
        @test size(read_int8_2d) == size(int8_2d)
        @test size(read_int16_2d) == size(int16_2d)
        @test size(read_uint8_2d) == size(uint8_2d)
        @test size(read_uint16_2d) == size(uint16_2d)
    end
    
    @testset "Type Conversion" begin
        # Test writing as one type and reading as another
        # This tests the HDF5 type conversion capabilities
        
        # Create test data
        int8_array = Int8[1, 2, 3]
        
        # Write as Int8
        file_id = create_file("test_integer_types.h5")
        write_array(file_id, "int8_to_convert", int8_array)
        close_file(file_id)
        
        # Read as different types
        file_id = open_file("test_integer_types.h5")
        
        # These should work with automatic conversion
        read_as_int16 = read_array(file_id, "int8_to_convert", Int16)
        read_as_int32 = read_array(file_id, "int8_to_convert", Int32)
        read_as_int64 = read_array(file_id, "int8_to_convert", Int64)
        read_as_float32 = read_array(file_id, "int8_to_convert", Float32)
        read_as_float64 = read_array(file_id, "int8_to_convert", Float64)
        
        close_file(file_id)
        
        # Test conversions
        @test all(read_as_int16 .== Int16[1, 2, 3])
        @test all(read_as_int32 .== Int32[1, 2, 3])
        @test all(read_as_int64 .== Int64[1, 2, 3])
        @test all(read_as_float32 .== Float32[1, 2, 3])
        @test all(read_as_float64 .== Float64[1, 2, 3])
    end
    
    @testset "Large Arrays" begin
        # Test with larger arrays of the new integer types
        int8_large = rand(Int8, 100, 100)
        int16_large = rand(Int16, 100, 100)
        uint8_large = rand(UInt8, 100, 100)
        uint16_large = rand(UInt16, 100, 100)
        
        # Write arrays
        file_id = create_file("test_integer_types.h5")
        write_array(file_id, "int8_large", int8_large)
        write_array(file_id, "int16_large", int16_large)
        write_array(file_id, "uint8_large", uint8_large)
        write_array(file_id, "uint16_large", uint16_large)
        close_file(file_id)
        
        # Read arrays
        file_id = open_file("test_integer_types.h5")
        read_int8_large = read_array(file_id, "int8_large", Int8)
        read_int16_large = read_array(file_id, "int16_large", Int16)
        read_uint8_large = read_array(file_id, "uint8_large", UInt8)
        read_uint16_large = read_array(file_id, "uint16_large", UInt16)
        close_file(file_id)
        
        # Test array equality
        @test read_int8_large == int8_large
        @test read_int16_large == int16_large
        @test read_uint8_large == uint8_large
        @test read_uint16_large == uint16_large
    end
end

# Clean up test files after tests
cleanup_test_files()

println("All integer type tests completed successfully!") 
#!/usr/bin/env julia

using Test

# Add the parent directory to the load path and include the StaticHDF5 module
using StaticHDF5

# Helper function to clean up test files

@testset "StaticHDF5 Tests" begin

    @testset "File Operations" begin
        # Test file creation
        tmpdir = mktempdir()
        file_id = create_file(joinpath(tmpdir, "test_file.h5"))
        @test file_id > 0
        @test isfile(joinpath(tmpdir, "test_file.h5"))
        close_file(file_id)

        # Test file opening (read-only)
        file_id = open_file(joinpath(tmpdir, "test_file.h5"))
        @test file_id > 0
        close_file(file_id)

        # Test file opening (read-write)
        file_id = open_file(joinpath(tmpdir, "test_file.h5"), READ_WRITE)
        @test file_id > 0
        close_file(file_id)

        # Test error handling for non-existent file
        @test_throws StaticHDF5.API.H5Error open_file("nonexistent_file.h5")
    end

    @testset "Basic Array Operations" begin
        # Create test data
        test_array_1d = [1, 2, 3, 4, 5]
        test_array_2d = reshape(1:12, 3, 4)  # This is now handled by AbstractArray support
        test_array_3d = reshape(1:24, 2, 3, 4)  # This is now handled by AbstractArray support

        tmpdir = mktempdir()
        file_id = create_file(joinpath(tmpdir, "test_file.h5"))
        write_array(file_id, "array_1d", test_array_1d)
        write_array(file_id, "array_2d", test_array_2d)
        write_array(file_id, "array_3d", test_array_3d)
        close_file(file_id)

        # Read arrays
        file_id = open_file(joinpath(tmpdir, "test_file.h5"))
        read_array_1d = read_array(file_id, "array_1d")
        read_array_2d = read_array(file_id, "array_2d")
        read_array_3d = read_array(file_id, "array_3d")
        close_file(file_id)

        # Test array equality
        @test read_array_1d == test_array_1d
        @test read_array_2d == Array(test_array_2d)  # Convert to Array for comparison
        @test read_array_3d == Array(test_array_3d)  # Convert to Array for comparison

        # Test array dimensions
        @test size(read_array_1d) == size(test_array_1d)
        @test size(read_array_2d) == size(test_array_2d)
        @test size(read_array_3d) == size(test_array_3d)
    end

    @testset "Group Operations" begin
        # Create file with groups
        tmpdir = mktempdir()
        file_id = create_file(joinpath(tmpdir, "test_file.h5"))

        # Create groups
        group_id = create_group(file_id, "group1")
        @test group_id > 0

        # Write to group
        test_array = [1.1, 2.2, 3.3]
        write_array(group_id, "data", test_array)

        # Create nested group
        subgroup_id = create_group(group_id, "subgroup")
        @test subgroup_id > 0

        # Write to subgroup
        test_subarray = [4.4, 5.5, 6.6]
        write_array(subgroup_id, "subdata", test_subarray)

        # Close groups and file
        close_group(subgroup_id)
        close_group(group_id)
        close_file(file_id)

        # Read from groups
        file_id = open_file(joinpath(tmpdir, "test_file.h5"))

        # Read from main group
        group_id = StaticHDF5.API.h5g_open(file_id, "group1", StaticHDF5.API.H5P_DEFAULT)
        read_array_group = read_array(group_id, "data")
        @test read_array_group ≈ test_array

        # Read from subgroup
        subgroup_id = StaticHDF5.API.h5g_open(group_id, "subgroup", StaticHDF5.API.H5P_DEFAULT)
        read_array_subgroup = read_array(subgroup_id, "subdata")
        @test read_array_subgroup ≈ test_subarray

        # Close everything
        close_group(subgroup_id)
        close_group(group_id)
        close_file(file_id)
    end

    @testset "List Datasets" begin
        # Create file with multiple datasets
        tmpdir = mktempdir()
        file_id = create_file(joinpath(tmpdir, "test_file.h5"))
        write_array(file_id, "data1", [1, 2, 3])
        write_array(file_id, "data2", [4, 5, 6])

        # Create group with datasets
        group_id = create_group(file_id, "group")
        write_array(group_id, "groupdata1", [7, 8, 9])
        write_array(group_id, "groupdata2", [10, 11, 12])
        close_group(group_id)

        # List datasets in root
        datasets_root = list_datasets(file_id)
        @test length(datasets_root) == 2
        @test "data1" in datasets_root
        @test "data2" in datasets_root

        # List datasets in group
        datasets_group = list_datasets(file_id, "group")
        @test length(datasets_group) == 2
        @test "groupdata1" in datasets_group
        @test "groupdata2" in datasets_group

        close_file(file_id)
    end

    @testset "Data Types" begin
        # Test different data types
        tmpdir = mktempdir()
        file_id = create_file(joinpath(tmpdir, "test_file.h5"))

        float64_array = [1.1, 2.2, 3.3]
        write_array(file_id, "float64", float64_array)

        float32_array = Float32[1.1, 2.2, 3.3]
        write_array(file_id, "float32", float32_array)

        int64_array = Int64[1, 2, 3]
        write_array(file_id, "int64", int64_array)

        int32_array = Int32[1, 2, 3]
        write_array(file_id, "int32", int32_array)

        int16_array = Int16[1, 2, 3]
        write_array(file_id, "int16", int16_array)

        int8_array = Int8[1, 2, 3]
        write_array(file_id, "int8", int8_array)

        uint64_array = UInt64[1, 2, 3]
        write_array(file_id, "uint64", uint64_array)

        uint32_array = UInt32[1, 2, 3]
        write_array(file_id, "uint32", uint32_array)

        uint16_array = UInt16[1, 2, 3]
        write_array(file_id, "uint16", uint16_array)

        uint8_array = UInt8[1, 2, 3]
        write_array(file_id, "uint8", uint8_array)

        bool_array = [true, false, true]
        write_array(file_id, "bool", bool_array)

        close_file(file_id)

        # Read back and verify
        file_id = open_file(joinpath(tmpdir, "test_file.h5"))

        @test read_array(file_id, "float64") ≈ float64_array
        @test read_array(file_id, "float32") ≈ float32_array
        @test read_array(file_id, "int64") == int64_array
        @test read_array(file_id, "int32") == int32_array
        @test read_array(file_id, "int16") == int16_array
        @test read_array(file_id, "int8") == int8_array
        @test read_array(file_id, "uint64") == uint64_array
        @test read_array(file_id, "uint32") == uint32_array
        @test read_array(file_id, "uint16") == uint16_array
        @test read_array(file_id, "uint8") == uint8_array
        @test read_array(file_id, "bool") == bool_array

        close_file(file_id)
    end

    @testset "Large Arrays" begin
        # Test with a larger array
        large_array = rand(100, 100)
        tmpdir = mktempdir()
        file_id = create_file(joinpath(tmpdir, "test_file.h5"))
        write_array(file_id, "large_array", large_array)
        close_file(file_id)

        file_id = open_file(joinpath(tmpdir, "test_file.h5"))
        read_large_array = read_array(file_id, "large_array")
        close_file(file_id)

        @test size(read_large_array) == size(large_array)
        @test read_large_array ≈ large_array
    end
    @testset "Error Handling" begin
        # Create a file for testing errors
        tmpdir = mktempdir()
        file_id = create_file(joinpath(tmpdir, "test_file.h5"))
        write_array(file_id, "data", [1, 2, 3])
        close_file(file_id)

        # Test reading non-existent dataset
        file_id = open_file(joinpath(tmpdir, "test_file.h5"))
        @test_throws StaticHDF5.API.H5Error read_array(file_id, "nonexistent")
        close_file(file_id)

        # This might not fail in all cases due to type conversion, but worth testing
        file_id = open_file(joinpath(tmpdir, "test_file.h5"))
        read_array(file_id, "data")
        close_file(file_id)
    end
    @testset "Performance Tests" begin
        # These are not strict tests but benchmarks to ensure reasonable performance
        small_array = rand(10, 10)
        medium_array = rand(100, 100)

        tmpdir = mktempdir()
        file_id = create_file(joinpath(tmpdir, "test_file.h5"))
        small_write_time = @elapsed write_array(file_id, "small", small_array)
        medium_write_time = @elapsed write_array(file_id, "medium", medium_array)

        close_file(file_id)

        file_id = open_file(joinpath(tmpdir, "test_file.h5"))

        small_read_time = @elapsed read_array(file_id, "small")
        medium_read_time = @elapsed read_array(file_id, "medium")

        close_file(file_id)
        # Print performance results
        println("Performance results:")
        println("  Small array (10x10) write time: $(small_write_time) seconds")
        println("  Medium array (100x100) write time: $(medium_write_time) seconds")
        println("  Small array (10x10) read time: $(small_read_time) seconds")
        println("  Medium array (100x100) read time: $(medium_read_time) seconds")
    end

end

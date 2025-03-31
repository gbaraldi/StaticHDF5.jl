#!/usr/bin/env julia

using Test
using StaticHDF5
using HDF5

@testset "HDF5.jl Integration Tests" begin

    @testset "StaticHDF5 -> HDF5.jl" begin
        # Create a file with StaticHDF5
        tmpdir = mktempdir()
        test_file = joinpath(tmpdir, "simple_to_hdf5jl.h5")

        # Create test data
        test_array_1d = [1, 2, 3, 4, 5]
        test_array_2d = reshape([1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12], 3, 4)
        test_array_3d = reshape(collect(1:24), 2, 3, 4)
        test_array_bool = [true, false, true, false, true]

        # Write data using StaticHDF5
        file_id = create_file(test_file)
        write_array(file_id, "array_1d", test_array_1d)
        write_array(file_id, "array_2d", test_array_2d)
        write_array(file_id, "array_3d", test_array_3d)
        write_array(file_id, "array_bool", test_array_bool)

        # Create a group and write data to it
        group_id = StaticHDF5.create_group(file_id, "group1")
        write_array(group_id, "nested_array", test_array_2d)
        close_group(group_id)

        close_file(file_id)

        # Now read the file with HDF5.jl
        h5open(test_file, "r") do file
            # Test reading arrays
            @test read(file["array_1d"]) == test_array_1d
            @test read(file["array_2d"]) == test_array_2d
            @test read(file["array_3d"]) == test_array_3d
            @test read(file["array_bool"]) == test_array_bool

            # Test reading from group
            @test read(file["group1/nested_array"]) == test_array_2d

            # Test attributes and metadata
            @test ndims(file["array_1d"]) == 1
            @test ndims(file["array_2d"]) == 2
            @test ndims(file["array_3d"]) == 3

            @test size(file["array_1d"]) == (5,)
            @test size(file["array_2d"]) == (3, 4)
            @test size(file["array_3d"]) == (2, 3, 4)

            @test eltype(file["array_1d"]) == Int
        end
    end

    @testset "HDF5.jl -> StaticHDF5" begin
        # Create a file with HDF5.jl
        tmpdir = mktempdir()
        test_file = joinpath(tmpdir, "hdf5jl_to_simple.h5")

        # Create test data with concrete arrays (not ranges)
        test_array_1d = Float32[1.1, 2.2, 3.3, 4.4, 5.5]
        test_array_2d = Float64[1.0 2.0 3.0 4.0; 5.0 6.0 7.0 8.0; 9.0 10.0 11.0 12.0]
        test_array_3d = reshape(Int8.(collect(1:24)), 2, 3, 4)
        test_array_bool = [true, false, true, false, true]

        # Write data using HDF5.jl
        h5open(test_file, "w") do file
            file["float_array_1d"] = test_array_1d
            file["float_array_2d"] = test_array_2d
            file["int_array_3d"] = test_array_3d
            file["bool_array"] = test_array_bool
            # Avoid conflict with StaticHDF5.create_group
            g = HDF5.create_group(file, "group1")
            g["nested_array"] = test_array_2d
        end

        # Now read the file with StaticHDF5
        file_id = open_file(test_file)

        # Test reading arrays
        read_array_1d = read_array(file_id, "float_array_1d")
        read_array_2d = read_array(file_id, "float_array_2d")
        read_array_3d = read_array(file_id, "int_array_3d")
        # Bool is not compatible with HDF5.jl
        # read_array_bool = read_array(file_id, "bool_array")

        @test read_array_1d == test_array_1d
        @test read_array_2d == test_array_2d
        @test read_array_3d == test_array_3d
        # Bool is not compatible with HDF5.jl
        # @test read_array_bool == test_array_bool
        # Test reading from group
        nested_array = read_array(file_id, "group1/nested_array")
        @test nested_array == test_array_2d

        # Test array info - get_array_info returns (type, dims) tuple
        info_1d = get_array_info(file_id, "float_array_1d")
        info_2d = get_array_info(file_id, "float_array_2d")
        info_3d = get_array_info(file_id, "int_array_3d")

        # Check types (first element of tuple)
        @test info_1d[1] == Float32
        @test info_2d[1] == Float64
        @test info_3d[1] == Int8

        # Check dimensions (second element of tuple)
        @test info_1d[2] == (5,)
        @test info_2d[2] == (3, 4)
        @test info_3d[2] == (2, 3, 4)

        close_file(file_id)
    end
end

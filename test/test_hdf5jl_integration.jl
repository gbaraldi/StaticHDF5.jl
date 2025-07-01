#!/usr/bin/env julia

using Test
using StaticHDF5
using HDF5

@testset "HDF5.jl Integration Tests" begin

    @testset "StaticHDF5 -> HDF5.jl" begin
        tmpdir = mktempdir()
        test_file = joinpath(tmpdir, "simple_to_hdf5jl.h5")

        test_array_1d = [1, 2, 3, 4, 5]
        test_array_2d = reshape([1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12], 3, 4)
        test_array_3d = reshape(collect(1:24), 2, 3, 4)
        test_array_bool = [true, false, true, false, true]
        test_string = "This is a test string"
        test_string_array = ["Alice", "Bob", "Charlie", "David"]
        test_complex = [1.0 + 2.0im, 3.0 + 4.0im, 5.0 + 6.0im]

        file = create_file(test_file)
        write_object(file, "array_1d", test_array_1d)
        write_object(file, "array_2d", test_array_2d)
        write_object(file, "array_3d", test_array_3d)
        write_object(file, "array_bool", test_array_bool)
        write_object(file, "complex_array", test_complex)
        write_object(file, "single_string", [test_string])  # Write as single-element array
        write_object(file, "string_array", test_string_array)

        group = StaticHDF5.create_group(file, "group1")
        write_object(group, "nested_array", test_array_2d)
        write_object(group, "nested_string", [test_string])  # Write as single-element array
        write_object(group, "nested_string_array", test_string_array)
        close_group(group)

        close_file(file)

        # Now read the file with HDF5.jl
        h5open(test_file, "r") do file
            @test read(file["array_1d"]) == test_array_1d
            @test read(file["array_2d"]) == test_array_2d
            @test read(file["array_3d"]) == test_array_3d
            @test read(file["array_bool"]) == test_array_bool
            @test read(file["complex_array"]) ≈ test_complex

            @test read(file["single_string"])[1] == test_string  # Read first element
            @test read(file["string_array"]) == test_string_array

            @test read(file["group1/nested_array"]) == test_array_2d
            @test read(file["group1/nested_string"])[1] == test_string  # Read first element
            @test read(file["group1/nested_string_array"]) == test_string_array

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
        tmpdir = mktempdir()
        test_file = joinpath(tmpdir, "hdf5jl_to_simple.h5")

        # Create test data with concrete arrays (not ranges)
        test_array_1d = Float32[1.1, 2.2, 3.3, 4.4, 5.5]
        test_array_2d = Float64[1.0 2.0 3.0 4.0; 5.0 6.0 7.0 8.0; 9.0 10.0 11.0 12.0]
        test_array_3d = reshape(Int8.(collect(1:24)), 2, 3, 4)
        test_array_bool = [true, false, true, false, true]
        test_string = "This is a test string from HDF5.jl"
        test_string_array = ["Eve", "Frank", "Grace", "Henry"]
        test_complex = [1.0 + 2.0im, 3.0 + 4.0im, 5.0 + 6.0im]

        h5open(test_file, "w") do file
            file["float_array_1d"] = test_array_1d
            file["float_array_2d"] = test_array_2d
            file["int_array_3d"] = test_array_3d
            file["bool_array"] = test_array_bool
            file["single_string"] = [test_string]  # Write as single-element array
            file["string_array"] = test_string_array
            file["complex_array"] = test_complex
            # Avoid conflict with StaticHDF5.create_group
            g = HDF5.create_group(file, "group1")
            g["nested_array"] = test_array_2d
            g["nested_string"] = [test_string]  # Write as single-element array
            g["nested_string_array"] = test_string_array
        end

        file = open_file(test_file)

        read_array_1d = read_object(file, "float_array_1d")
        read_array_2d = read_object(file, "float_array_2d")
        read_array_3d = read_object(file, "int_array_3d")
        read_complex = read_object(file, "complex_array")
        # Bool is not compatible with HDF5.jl
        # read_array_bool = read_object(file, "bool_array")

        @test read_array_1d == test_array_1d
        @test read_array_2d == test_array_2d
        @test read_array_3d == test_array_3d
        @test read_complex ≈ test_complex
        @test eltype(read_complex) == Complex{Float64}
        # Bool is not compatible with HDF5.jl
        # @test read_array_bool == test_array_bool

        read_string = read_object(file, "single_string")[1]  # Read first element
        read_string_array = read_object(file, "string_array")
        @test read_string == test_string
        @test read_string_array == test_string_array

        nested_array = read_object(file, "group1/nested_array")
        nested_string = read_object(file, "group1/nested_string")[1]  # Read first element
        nested_string_array = read_object(file, "group1/nested_string_array")
        @test nested_array == test_array_2d
        @test nested_string == test_string
        @test nested_string_array == test_string_array

        info_1d = get_dataset_info(file, "float_array_1d")
        info_2d = get_dataset_info(file, "float_array_2d")
        info_3d = get_dataset_info(file, "int_array_3d")

        @test info_1d.type == Float32
        @test info_2d.type == Float64
        @test info_3d.type == Int8

        @test info_1d.dims == (5,)
        @test info_2d.dims == (3, 4)
        @test info_3d.dims == (2, 3, 4)

        @test length(info_1d.dims) == 1
        @test length(info_2d.dims) == 2
        @test length(info_3d.dims) == 3

        @test prod(info_1d.dims) == 5
        @test prod(info_2d.dims) == 12
        @test prod(info_3d.dims) == 24

        @test !info_1d.is_scalar
        @test !info_2d.is_scalar
        @test !info_3d.is_scalar

        close_file(file)
    end

    @testset "Scalar Bidirectional Compatibility" begin
        tmpdir = mktempdir()
        filename = joinpath(tmpdir, "scalar_test.h5")

        # Test scalar values
        scalar_string = "hello world"
        scalar_float64 = 3.14159
        scalar_float32 = Float32(2.71828)
        scalar_int64 = Int64(42)
        scalar_int32 = Int32(123)
        scalar_int16 = Int16(456)
        scalar_int8 = Int8(78)
        scalar_uint64 = UInt64(999)
        scalar_uint32 = UInt32(888)
        scalar_uint16 = UInt16(777)
        scalar_uint8 = UInt8(66)
        scalar_bool = true
        scalar_complex64 = 1.0 + 2.0im
        scalar_complex32 = ComplexF32(3.0 + 4.0im)

        # Write scalars with StaticHDF5, read with HDF5.jl
        file = StaticHDF5.create_file(filename)
        StaticHDF5.write_object(file, "scalar_string", scalar_string)
        StaticHDF5.write_object(file, "scalar_float64", scalar_float64)
        StaticHDF5.write_object(file, "scalar_float32", scalar_float32)
        StaticHDF5.write_object(file, "scalar_int64", scalar_int64)
        StaticHDF5.write_object(file, "scalar_int32", scalar_int32)
        StaticHDF5.write_object(file, "scalar_int16", scalar_int16)
        StaticHDF5.write_object(file, "scalar_int8", scalar_int8)
        StaticHDF5.write_object(file, "scalar_uint64", scalar_uint64)
        StaticHDF5.write_object(file, "scalar_uint32", scalar_uint32)
        StaticHDF5.write_object(file, "scalar_uint16", scalar_uint16)
        StaticHDF5.write_object(file, "scalar_uint8", scalar_uint8)
        StaticHDF5.write_object(file, "scalar_bool", scalar_bool)
        StaticHDF5.write_object(file, "scalar_complex64", scalar_complex64)
        StaticHDF5.write_object(file, "scalar_complex32", scalar_complex32)
        StaticHDF5.close_file(file)

        # Read with HDF5.jl and verify
        HDF5.h5open(filename, "r") do h5file
            @test read(h5file, "scalar_string") == scalar_string
            @test read(h5file, "scalar_float64") == scalar_float64
            @test read(h5file, "scalar_float32") == scalar_float32
            @test read(h5file, "scalar_int64") == scalar_int64
            @test read(h5file, "scalar_int32") == scalar_int32
            @test read(h5file, "scalar_int16") == scalar_int16
            @test read(h5file, "scalar_int8") == scalar_int8
            @test read(h5file, "scalar_uint64") == scalar_uint64
            @test read(h5file, "scalar_uint32") == scalar_uint32
            @test read(h5file, "scalar_uint16") == scalar_uint16
            @test read(h5file, "scalar_uint8") == scalar_uint8
            @test read(h5file, "scalar_bool") == scalar_bool
            @test read(h5file, "scalar_complex64") == scalar_complex64
            @test read(h5file, "scalar_complex32") == scalar_complex32
        end

        # Write scalars with HDF5.jl, read with StaticHDF5
        HDF5.h5open(filename, "w") do h5file
            write(h5file, "hdf5_string", scalar_string)
            write(h5file, "hdf5_float64", scalar_float64)
            write(h5file, "hdf5_float32", scalar_float32)
            write(h5file, "hdf5_int64", scalar_int64)
            write(h5file, "hdf5_int32", scalar_int32)
            write(h5file, "hdf5_int16", scalar_int16)
            write(h5file, "hdf5_int8", scalar_int8)
            write(h5file, "hdf5_uint64", scalar_uint64)
            write(h5file, "hdf5_uint32", scalar_uint32)
            write(h5file, "hdf5_uint16", scalar_uint16)
            write(h5file, "hdf5_uint8", scalar_uint8)
            write(h5file, "hdf5_bool", scalar_bool)
            write(h5file, "hdf5_complex64", scalar_complex64)
            write(h5file, "hdf5_complex32", scalar_complex32)
        end

        # Read with StaticHDF5 and verify
        file = StaticHDF5.open_file(filename)
        @test StaticHDF5.read_object(file, "hdf5_string") == scalar_string
        @test StaticHDF5.read_object(file, "hdf5_float64") == scalar_float64
        @test StaticHDF5.read_object(file, "hdf5_float32") == scalar_float32
        @test StaticHDF5.read_object(file, "hdf5_int64") == scalar_int64
        @test StaticHDF5.read_object(file, "hdf5_int32") == scalar_int32
        @test StaticHDF5.read_object(file, "hdf5_int16") == scalar_int16
        @test StaticHDF5.read_object(file, "hdf5_int8") == scalar_int8
        @test StaticHDF5.read_object(file, "hdf5_uint64") == scalar_uint64
        @test StaticHDF5.read_object(file, "hdf5_uint32") == scalar_uint32
        @test StaticHDF5.read_object(file, "hdf5_uint16") == scalar_uint16
        @test StaticHDF5.read_object(file, "hdf5_uint8") == scalar_uint8
        @test StaticHDF5.read_object(file, "hdf5_bool") == scalar_bool
        @test StaticHDF5.read_object(file, "hdf5_complex64") == scalar_complex64
        @test StaticHDF5.read_object(file, "hdf5_complex32") == scalar_complex32
        StaticHDF5.close_file(file)
    end
end

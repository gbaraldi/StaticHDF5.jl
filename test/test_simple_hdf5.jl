#!/usr/bin/env julia

using Test
using StaticHDF5

@testset "StaticHDF5 Core Tests" begin

    @testset "File Operations" begin
        tmpdir = mktempdir()
        file = create_file(joinpath(tmpdir, "test_file.h5"))
        @test isfile(joinpath(tmpdir, "test_file.h5"))
        close_file(file)

        file = open_file(joinpath(tmpdir, "test_file.h5"))
        close_file(file)

        file = open_file(joinpath(tmpdir, "test_file.h5"), READ_WRITE)
        close_file(file)

        @test_throws StaticHDF5.API.H5Error open_file("nonexistent_file.h5")
    end

    @testset "Basic Array Operations" begin
        test_array_1d = [1, 2, 3, 4, 5]
        test_array_2d = reshape(1:12, 3, 4)
        test_array_3d = reshape(1:24, 2, 3, 4)

        tmpdir = mktempdir()
        file = create_file(joinpath(tmpdir, "test_file.h5"))
        write_object(file, "array_1d", test_array_1d)
        write_object(file, "array_2d", test_array_2d)
        write_object(file, "array_3d", test_array_3d)
        close_file(file)

        file = open_file(joinpath(tmpdir, "test_file.h5"))
        read_array_1d = read_object(file, "array_1d")
        read_array_2d = read_object(file, "array_2d")
        read_array_3d = read_object(file, "array_3d")
        close_file(file)

        @test read_array_1d == test_array_1d
        @test read_array_2d == Array(test_array_2d)
        @test read_array_3d == Array(test_array_3d)

        @test size(read_array_1d) == size(test_array_1d)
        @test size(read_array_2d) == size(test_array_2d)
        @test size(read_array_3d) == size(test_array_3d)
    end

    @testset "Group Operations" begin
        tmpdir = mktempdir()
        file = create_file(joinpath(tmpdir, "test_file.h5"))

        group = create_group(file, "group1")
        test_array = [1.1, 2.2, 3.3]
        write_object(group, "data", test_array)

        subgroup = create_group(group, "subgroup")
        test_subarray = [4.4, 5.5, 6.6]
        write_object(subgroup, "subdata", test_subarray)

        close_group(subgroup)
        close_group(group)
        close_file(file)

        file = open_file(joinpath(tmpdir, "test_file.h5"))
        group = open_group(file, "group1")
        read_array_group = read_object(group, "data")
        @test read_array_group ≈ test_array

        subgroup = open_group(group, "subgroup")
        read_array_subgroup = read_object(subgroup, "subdata")
        @test read_array_subgroup ≈ test_subarray

        close_group(subgroup)
        close_group(group)
        close_file(file)
    end

    @testset "List Objects" begin
        tmpdir = mktempdir()
        file = create_file(joinpath(tmpdir, "test_file.h5"))
        write_object(file, "data1", [1, 2, 3])
        write_object(file, "data2", [4, 5, 6])

        group = create_group(file, "group")
        write_object(group, "groupdata1", [7, 8, 9])
        write_object(group, "groupdata2", [10, 11, 12])

        objects_root = keys(file)
        @test length(objects_root) == 3
        @test "data1" in objects_root
        @test "data2" in objects_root

        objects_group = keys(group)
        @test length(objects_group) == 2
        @test "groupdata1" in objects_group
        @test "groupdata2" in objects_group

        close_group(group)
        close_file(file)
    end

    @testset "Data Types" begin
        tmpdir = mktempdir()
        file = create_file(joinpath(tmpdir, "test_file.h5"))

        # Test core numeric types
        float64_array = [1.1, 2.2, 3.3]
        float32_array = Float32[1.1, 2.2, 3.3]
        int64_array = Int64[1, 2, 3]
        int32_array = Int32[1, 2, 3]
        uint64_array = UInt64[1, 2, 3]
        bool_array = [true, false, true]
        string_array = ["hello", "world", "test"]
        write_object(file, "float64", float64_array)
        write_object(file, "float32", float32_array)
        write_object(file, "int64", int64_array)
        write_object(file, "int32", int32_array)
        write_object(file, "uint64", uint64_array)
        write_object(file, "bool", bool_array)
        write_object(file, "string", string_array)

        close_file(file)

        file = open_file(joinpath(tmpdir, "test_file.h5"))

        @test read_object(file, "float64") ≈ float64_array
        @test read_object(file, "float32") ≈ float32_array
        @test read_object(file, "int64") == int64_array
        @test read_object(file, "int32") == int32_array
        @test read_object(file, "uint64") == uint64_array
        @test read_object(file, "bool") == bool_array
        @test read_object(file, "string") == string_array

        close_file(file)
    end

    @testset "Scalar Data Types" begin
        tmpdir = mktempdir()
        file = create_file(joinpath(tmpdir, "test_file.h5"))

        # Test all supported scalar types
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

        # Write all scalars
        write_object(file, "scalar_string", scalar_string)
        write_object(file, "scalar_float64", scalar_float64)
        write_object(file, "scalar_float32", scalar_float32)
        write_object(file, "scalar_int64", scalar_int64)
        write_object(file, "scalar_int32", scalar_int32)
        write_object(file, "scalar_int16", scalar_int16)
        write_object(file, "scalar_int8", scalar_int8)
        write_object(file, "scalar_uint64", scalar_uint64)
        write_object(file, "scalar_uint32", scalar_uint32)
        write_object(file, "scalar_uint16", scalar_uint16)
        write_object(file, "scalar_uint8", scalar_uint8)
        write_object(file, "scalar_bool", scalar_bool)
        write_object(file, "scalar_complex64", scalar_complex64)
        write_object(file, "scalar_complex32", scalar_complex32)

        close_file(file)

        # Read back and verify
        file = open_file(joinpath(tmpdir, "test_file.h5"))

        @test read_object(file, "scalar_string") == scalar_string
        @test read_object(file, "scalar_float64") == scalar_float64
        @test read_object(file, "scalar_float32") == scalar_float32
        @test read_object(file, "scalar_int64") == scalar_int64
        @test read_object(file, "scalar_int32") == scalar_int32
        @test read_object(file, "scalar_int16") == scalar_int16
        @test read_object(file, "scalar_int8") == scalar_int8
        @test read_object(file, "scalar_uint64") == scalar_uint64
        @test read_object(file, "scalar_uint32") == scalar_uint32
        @test read_object(file, "scalar_uint16") == scalar_uint16
        @test read_object(file, "scalar_uint8") == scalar_uint8
        @test read_object(file, "scalar_bool") == scalar_bool
        @test read_object(file, "scalar_complex64") == scalar_complex64
        @test read_object(file, "scalar_complex32") == scalar_complex32

        # Test type-stable reading with explicit types
        @test read_object(file, "scalar_string", String) == scalar_string
        @test read_object(file, "scalar_float64", Float64) == scalar_float64
        @test read_object(file, "scalar_float32", Float32) == scalar_float32
        @test read_object(file, "scalar_int64", Int64) == scalar_int64
        @test read_object(file, "scalar_int32", Int32) == scalar_int32
        @test read_object(file, "scalar_int16", Int16) == scalar_int16
        @test read_object(file, "scalar_int8", Int8) == scalar_int8
        @test read_object(file, "scalar_uint64", UInt64) == scalar_uint64
        @test read_object(file, "scalar_uint32", UInt32) == scalar_uint32
        @test read_object(file, "scalar_uint16", UInt16) == scalar_uint16
        @test read_object(file, "scalar_uint8", UInt8) == scalar_uint8
        @test read_object(file, "scalar_bool", Bool) == scalar_bool
        @test read_object(file, "scalar_complex64", ComplexF64) == scalar_complex64
        @test read_object(file, "scalar_complex32", ComplexF32) == scalar_complex32

        close_file(file)
    end

    @testset "Scalar Data Types" begin
        tmpdir = mktempdir()
        file = create_file(joinpath(tmpdir, "test_file.h5"))

        # Test all supported scalar types
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

        # Write scalars
        write_object(file, "scalar_string", scalar_string)
        write_object(file, "scalar_float64", scalar_float64)
        write_object(file, "scalar_float32", scalar_float32)
        write_object(file, "scalar_int64", scalar_int64)
        write_object(file, "scalar_int32", scalar_int32)
        write_object(file, "scalar_int16", scalar_int16)
        write_object(file, "scalar_int8", scalar_int8)
        write_object(file, "scalar_uint64", scalar_uint64)
        write_object(file, "scalar_uint32", scalar_uint32)
        write_object(file, "scalar_uint16", scalar_uint16)
        write_object(file, "scalar_uint8", scalar_uint8)
        write_object(file, "scalar_bool", scalar_bool)
        write_object(file, "scalar_complex64", scalar_complex64)
        write_object(file, "scalar_complex32", scalar_complex32)

        close_file(file)

        # Read scalars back and verify
        file = open_file(joinpath(tmpdir, "test_file.h5"))

        @test read_object(file, "scalar_string") == scalar_string
        @test read_object(file, "scalar_float64") == scalar_float64
        @test read_object(file, "scalar_float32") == scalar_float32
        @test read_object(file, "scalar_int64") == scalar_int64
        @test read_object(file, "scalar_int32") == scalar_int32
        @test read_object(file, "scalar_int16") == scalar_int16
        @test read_object(file, "scalar_int8") == scalar_int8
        @test read_object(file, "scalar_uint64") == scalar_uint64
        @test read_object(file, "scalar_uint32") == scalar_uint32
        @test read_object(file, "scalar_uint16") == scalar_uint16
        @test read_object(file, "scalar_uint8") == scalar_uint8
        @test read_object(file, "scalar_bool") == scalar_bool
        @test read_object(file, "scalar_complex64") == scalar_complex64
        @test read_object(file, "scalar_complex32") == scalar_complex32

        # Test type-stable reading
        @test read_object(file, "scalar_string", String) == scalar_string
        @test read_object(file, "scalar_float64", Float64) == scalar_float64
        @test read_object(file, "scalar_float32", Float32) == scalar_float32
        @test read_object(file, "scalar_int64", Int64) == scalar_int64
        @test read_object(file, "scalar_int32", Int32) == scalar_int32
        @test read_object(file, "scalar_int16", Int16) == scalar_int16
        @test read_object(file, "scalar_int8", Int8) == scalar_int8
        @test read_object(file, "scalar_uint64", UInt64) == scalar_uint64
        @test read_object(file, "scalar_uint32", UInt32) == scalar_uint32
        @test read_object(file, "scalar_uint16", UInt16) == scalar_uint16
        @test read_object(file, "scalar_uint8", UInt8) == scalar_uint8
        @test read_object(file, "scalar_bool", Bool) == scalar_bool
        @test read_object(file, "scalar_complex64", ComplexF64) == scalar_complex64
        @test read_object(file, "scalar_complex32", ComplexF32) == scalar_complex32

        close_file(file)
    end

    @testset "Error Handling" begin
        tmpdir = mktempdir()
        file = create_file(joinpath(tmpdir, "test_file.h5"))
        write_object(file, "data", [1, 2, 3])
        close_file(file)

        file = open_file(joinpath(tmpdir, "test_file.h5"))
        # Now gives a more user-friendly ArgumentError instead of H5Error
        @test_throws ArgumentError("'nonexistent' does not exist or is not a dataset.") read_object(file, "nonexistent")
        close_file(file)
    end
end


using Test
using StaticHDF5
using JET

@testset "StaticHDF5 Type Stability Tests" begin
    @testset "File Operations Type Stability" begin
        tmpdir = mktempdir()
        file = create_file(joinpath(tmpdir, "test_file.h5"))
        # Test file creation
        JET.@test_opt create_file(joinpath(tmpdir, "test_file.h5"))
        # Test file opening
        JET.@test_opt open_file("test_type_stability_file.h5", StaticHDF5.READ_ONLY)
        # Test group creation
        JET.@test_opt create_group(file, "group1")
        group = create_group(file, "group1")


        JET.@test_opt close_group(group)
        JET.@test_opt close_file(file)
        close_group(group)
        close_file(file)
    end

    @testset "Write Operations Type Stability" begin
        tmpdir = mktempdir()
        file = create_file(joinpath(tmpdir, "test_file.h5"))

        # Test writing different types of arrays
        int_array = [1, 2, 3, 4]
        float_array = [1.1, 2.2, 3.3, 4.4]
        bool_array = [true, false, true, false]
        string_array = ["hello", "world", "test"]
        complex_array = [1.0+2.0im, 3.0+4.0im, 5.0+6.0im]

        JET.@test_opt write_object(file, "int_array", int_array)
        JET.@test_opt write_object(file, "float_array", float_array)
        JET.@test_opt write_object(file, "bool_array", bool_array)
        JET.@test_opt write_object(file, "string_array", string_array)
        JET.@test_opt write_object(file, "complex_array", complex_array)

        # write_object should be optimized even with an unknown array type
        JET.test_opt(write_object, (typeof(file), String, Array))

        # Actually write the arrays for subsequent tests
        write_object(file, "int_array", int_array)
        write_object(file, "float_array", float_array)
        write_object(file, "bool_array", bool_array)
        write_object(file, "string_array", string_array)
        write_object(file, "complex_array", complex_array)

        # Verify the arrays were written correctly
        @test "int_array" in keys(file)
        @test "float_array" in keys(file)
        @test "bool_array" in keys(file)
        @test "string_array" in keys(file)
        @test "complex_array" in keys(file)

        # Test writing arrays to groups
        group = create_group(file, "group1")
        JET.@test_opt write_object(group, "group_int_array", int_array)
        write_object(group, "group_int_array", int_array)
        close_group(group)

        # Test listing objects
        JET.@test_opt keys(file)

        # Close the file
        close_file(file)
    end

    @testset "Read Operations Type Stability" begin
        tmpdir = mktempdir()
        file = create_file(joinpath(tmpdir, "test_file.h5"))

        # Write test data
        int_array = [1, 2, 3, 4]
        float_array = [1.1, 2.2, 3.3, 4.4]
        bool_array = [true, false, true, false]
        string_array = ["hello", "world", "test"]
        complex_array = [1.0+2.0im, 3.0+4.0im, 5.0+6.0im]

        StaticHDF5.write_object(file, "int_array", int_array)
        StaticHDF5.write_object(file, "float_array", float_array)
        StaticHDF5.write_object(file, "bool_array", bool_array)
        StaticHDF5.write_object(file, "string_array", string_array)
        StaticHDF5.write_object(file, "complex_array", complex_array)

        StaticHDF5.close_file(file)
        file = StaticHDF5.open_file(joinpath(tmpdir, "test_file.h5"), StaticHDF5.READ_ONLY)

        JET.@test_opt StaticHDF5.get_dataset_info(file, "int_array")

        JET.@test_opt StaticHDF5.read_object(file, "int_array", Array{Int,1})
        JET.@test_opt StaticHDF5.read_object(file, "float_array", Array{Float64,1})
        JET.@test_opt StaticHDF5.read_object(file, "bool_array", Array{Bool,1})
        JET.@test_opt StaticHDF5.read_object(file, "string_array", Array{String,1})
        JET.@test_opt StaticHDF5.read_object(file, "complex_array", Array{ComplexF64,1})

        # Verify the arrays were read correctly
        @test StaticHDF5.read_object(file, "int_array", Array{Int,1}) == int_array
        @test StaticHDF5.read_object(file, "float_array", Array{Float64,1}) == float_array
        @test StaticHDF5.read_object(file, "bool_array", Array{Bool,1}) == bool_array
        @test StaticHDF5.read_object(file, "string_array", Array{String,1}) == string_array
        @test StaticHDF5.read_object(file, "complex_array", Array{ComplexF64,1}) == complex_array

        @test StaticHDF5.read_object(file, "int_array", Vector{Int}) == int_array
        @test StaticHDF5.read_object(file, "float_array", Vector{Float64}) == float_array
        @test StaticHDF5.read_object(file, "bool_array", Vector{Bool}) == bool_array
        @test StaticHDF5.read_object(file, "string_array", Vector{String}) == string_array
        @test StaticHDF5.read_object(file, "complex_array", Vector{ComplexF64}) == complex_array


        StaticHDF5.close_file(file)
    end

    @testset "Complex Array Type Stability" begin
        tmpdir = mktempdir()
        file = create_file(joinpath(tmpdir, "test_file.h5"))

        array_2d = [i + j for i in 1:3, j in 1:4]
        StaticHDF5.write_object(file, "array_2d", array_2d)

        array_3d = [i + j + k for i in 1:2, j in 1:3, k in 1:4]
        StaticHDF5.write_object(file, "array_3d", array_3d)

        StaticHDF5.close_file(file)
        file = StaticHDF5.open_file(joinpath(tmpdir, "test_file.h5"), StaticHDF5.READ_ONLY)

        JET.@test_opt StaticHDF5.read_object(file, "array_2d", Array{Int,2})
        JET.@test_opt StaticHDF5.read_object(file, "array_3d", Array{Int,3})

        # Verify the arrays were read correctly
        @test StaticHDF5.read_object(file, "array_2d", Array{Int,2}) == array_2d
        @test StaticHDF5.read_object(file, "array_3d", Array{Int,3}) == array_3d

        # Close the file
        StaticHDF5.close_file(file)
    end

    @testset "Parametric Type Array Reading" begin
        # Create a new file for parametric type tests
        file = StaticHDF5.create_file("test_type_stability_parametric.h5")

        # Write test data
        vector_data = [1, 2, 3, 4, 5]
        matrix_data = [i + j for i in 1:3, j in 1:4]
        tensor_data = [i + j + k for i in 1:2, j in 1:3, k in 1:4]

        StaticHDF5.write_object(file, "vector", vector_data)
        StaticHDF5.write_object(file, "matrix", matrix_data)
        StaticHDF5.write_object(file, "tensor", tensor_data)

        # Close and reopen the file for reading
        StaticHDF5.close_file(file)
        file = StaticHDF5.open_file("test_type_stability_parametric.h5", StaticHDF5.READ_ONLY)

        # Test reading with parametric types using JET (these should be type stable)
        JET.@test_opt StaticHDF5.read_object(file, "vector", Vector{Int})
        JET.@test_opt StaticHDF5.read_object(file, "matrix", Matrix{Int})
        JET.@test_opt StaticHDF5.read_object(file, "tensor", Array{Int, 3})

        # Verify the arrays were read correctly
        @test StaticHDF5.read_object(file, "vector", Vector{Int}) == vector_data
        @test StaticHDF5.read_object(file, "matrix", Matrix{Int}) == matrix_data
        @test StaticHDF5.read_object(file, "tensor", Array{Int, 3}) == tensor_data

        # Test error cases
        # Trying to read a vector as a matrix should throw an error
        @test_throws ArgumentError StaticHDF5.read_object(file, "vector", Matrix{Int})

        # Close the file
        StaticHDF5.close_file(file)
    end

    @testset "String and Complex Number Type Stability" begin
        tmpdir = mktempdir()
        file = create_file(joinpath(tmpdir, "test_file.h5"))

        # Test scalar values of all supported types
        scalar_string = "hello world"
        scalar_complex = 1.0 + 2.0im
        scalar_complex32 = ComplexF32(3.0 + 4.0im)
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

        # Test writing scalars
        JET.@test_opt write_object(file, "scalar_string", scalar_string)
        JET.@test_opt write_object(file, "scalar_complex", scalar_complex)
        JET.@test_opt write_object(file, "scalar_complex32", scalar_complex32)
        JET.@test_opt write_object(file, "scalar_float64", scalar_float64)
        JET.@test_opt write_object(file, "scalar_float32", scalar_float32)
        JET.@test_opt write_object(file, "scalar_int64", scalar_int64)
        JET.@test_opt write_object(file, "scalar_int32", scalar_int32)
        JET.@test_opt write_object(file, "scalar_int16", scalar_int16)
        JET.@test_opt write_object(file, "scalar_int8", scalar_int8)
        JET.@test_opt write_object(file, "scalar_uint64", scalar_uint64)
        JET.@test_opt write_object(file, "scalar_uint32", scalar_uint32)
        JET.@test_opt write_object(file, "scalar_uint16", scalar_uint16)
        JET.@test_opt write_object(file, "scalar_uint8", scalar_uint8)
        JET.@test_opt write_object(file, "scalar_bool", scalar_bool)

        # Actually write the scalars
        write_object(file, "scalar_string", scalar_string)
        write_object(file, "scalar_complex", scalar_complex)
        write_object(file, "scalar_complex32", scalar_complex32)
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

        # Test multidimensional string and complex arrays
        string_matrix = ["a" "b"; "c" "d"]
        complex_matrix = [1.0+1.0im 2.0+2.0im; 3.0+3.0im 4.0+4.0im]
        complex32_array = ComplexF32[1.0+1.0im, 2.0+2.0im, 3.0+3.0im]

        JET.@test_opt write_object(file, "string_matrix", string_matrix)
        JET.@test_opt write_object(file, "complex_matrix", complex_matrix)
        JET.@test_opt write_object(file, "complex32_array", complex32_array)

        write_object(file, "string_matrix", string_matrix)
        write_object(file, "complex_matrix", complex_matrix)
        write_object(file, "complex32_array", complex32_array)

        close_file(file)
        file = open_file(joinpath(tmpdir, "test_file.h5"), READ_ONLY)

        # Test reading scalars with type stability
        JET.@test_opt read_object(file, "scalar_string", String)
        JET.@test_opt read_object(file, "scalar_complex", ComplexF64)
        JET.@test_opt read_object(file, "scalar_complex32", ComplexF32)
        JET.@test_opt read_object(file, "scalar_float64", Float64)
        JET.@test_opt read_object(file, "scalar_float32", Float32)
        JET.@test_opt read_object(file, "scalar_int64", Int64)
        JET.@test_opt read_object(file, "scalar_int32", Int32)
        JET.@test_opt read_object(file, "scalar_int16", Int16)
        JET.@test_opt read_object(file, "scalar_int8", Int8)
        JET.@test_opt read_object(file, "scalar_uint64", UInt64)
        JET.@test_opt read_object(file, "scalar_uint32", UInt32)
        JET.@test_opt read_object(file, "scalar_uint16", UInt16)
        JET.@test_opt read_object(file, "scalar_uint8", UInt8)
        JET.@test_opt read_object(file, "scalar_bool", Bool)

        # Test reading arrays with type stability
        JET.@test_opt read_object(file, "string_matrix", Matrix{String})
        JET.@test_opt read_object(file, "complex_matrix", Matrix{ComplexF64})
        JET.@test_opt read_object(file, "complex32_array", Vector{ComplexF32})

        # Verify correctness
        @test read_object(file, "scalar_string", String) == scalar_string
        @test read_object(file, "scalar_complex", ComplexF64) == scalar_complex
        @test read_object(file, "scalar_complex32", ComplexF32) == scalar_complex32
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
        @test read_object(file, "string_matrix", Matrix{String}) == string_matrix
        @test read_object(file, "complex_matrix", Matrix{ComplexF64}) == complex_matrix
        @test read_object(file, "complex32_array", Vector{ComplexF32}) == complex32_array

        close_file(file)
    end
end

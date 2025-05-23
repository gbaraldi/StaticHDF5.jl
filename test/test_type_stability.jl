
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

        JET.@test_opt write_array(file, "int_array", int_array)
        JET.@test_opt write_array(file, "float_array", float_array)
        JET.@test_opt write_array(file, "bool_array", bool_array)

        # write_array should be optimized even with an unknown array type
        JET.test_opt(write_array, (typeof(file), String, Array))

        # Actually write the arrays for subsequent tests
        write_array(file, "int_array", int_array)
        write_array(file, "float_array", float_array)
        write_array(file, "bool_array", bool_array)

        # Verify the arrays were written correctly
        @test "int_array" in keys(file)
        @test "float_array" in keys(file)
        @test "bool_array" in keys(file)

        # Test writing arrays to groups
        group = create_group(file, "group1")
        JET.@test_opt write_array(group, "group_int_array", int_array)
        write_array(group, "group_int_array", int_array)
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

        StaticHDF5.write_array(file, "int_array", int_array)
        StaticHDF5.write_array(file, "float_array", float_array)
        StaticHDF5.write_array(file, "bool_array", bool_array)

        StaticHDF5.close_file(file)
        file = StaticHDF5.open_file(joinpath(tmpdir, "test_file.h5"), StaticHDF5.READ_ONLY)

        JET.@test_opt StaticHDF5.get_array_info(file, "int_array")

        JET.@test_opt StaticHDF5.read_array(file, "int_array", Array{Int,1})
        JET.@test_opt StaticHDF5.read_array(file, "float_array", Array{Float64,1})
        JET.@test_opt StaticHDF5.read_array(file, "bool_array", Array{Bool,1})

        # Verify the arrays were read correctly
        @test StaticHDF5.read_array(file, "int_array", Array{Int,1}) == int_array
        @test StaticHDF5.read_array(file, "float_array", Array{Float64,1}) == float_array
        @test StaticHDF5.read_array(file, "bool_array", Array{Bool,1}) == bool_array

        @test StaticHDF5.read_array(file, "int_array", Vector{Int}) == int_array
        @test StaticHDF5.read_array(file, "float_array", Vector{Float64}) == float_array
        @test StaticHDF5.read_array(file, "bool_array", Vector{Bool}) == bool_array


        StaticHDF5.close_file(file)
    end

    @testset "Complex Array Type Stability" begin
        tmpdir = mktempdir()
        file = create_file(joinpath(tmpdir, "test_file.h5"))

        array_2d = [i + j for i in 1:3, j in 1:4]
        StaticHDF5.write_array(file, "array_2d", array_2d)

        array_3d = [i + j + k for i in 1:2, j in 1:3, k in 1:4]
        StaticHDF5.write_array(file, "array_3d", array_3d)

        StaticHDF5.close_file(file)
        file = StaticHDF5.open_file(joinpath(tmpdir, "test_file.h5"), StaticHDF5.READ_ONLY)

        JET.@test_opt StaticHDF5.read_array(file, "array_2d", Array{Int,2})
        JET.@test_opt StaticHDF5.read_array(file, "array_3d", Array{Int,3})

        # Verify the arrays were read correctly
        @test StaticHDF5.read_array(file, "array_2d", Array{Int,2}) == array_2d
        @test StaticHDF5.read_array(file, "array_3d", Array{Int,3}) == array_3d

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

        StaticHDF5.write_array(file, "vector", vector_data)
        StaticHDF5.write_array(file, "matrix", matrix_data)
        StaticHDF5.write_array(file, "tensor", tensor_data)

        # Close and reopen the file for reading
        StaticHDF5.close_file(file)
        file = StaticHDF5.open_file("test_type_stability_parametric.h5", StaticHDF5.READ_ONLY)

        # Test reading with parametric types using JET (these should be type stable)
        JET.@test_opt StaticHDF5.read_array(file, "vector", Vector{Int})
        JET.@test_opt StaticHDF5.read_array(file, "matrix", Matrix{Int})
        JET.@test_opt StaticHDF5.read_array(file, "tensor", Array{Int, 3})

        # Verify the arrays were read correctly
        @test StaticHDF5.read_array(file, "vector", Vector{Int}) == vector_data
        @test StaticHDF5.read_array(file, "matrix", Matrix{Int}) == matrix_data
        @test StaticHDF5.read_array(file, "tensor", Array{Int, 3}) == tensor_data

        # Test error cases
        # Trying to read a vector as a matrix should throw an error
        @test_throws ArgumentError StaticHDF5.read_array(file, "vector", Matrix{Int})

        # Close the file
        StaticHDF5.close_file(file)
    end
end

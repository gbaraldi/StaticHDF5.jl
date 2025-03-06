
using Test
using SimpleHDF5
using JET

@testset "SimpleHDF5 Type Stability Tests" begin
    @testset "File Operations Type Stability" begin
        tmpdir = mktempdir()
        file_id = create_file(joinpath(tmpdir, "test_file.h5"))
        # Test file creation
        JET.@test_opt create_file(joinpath(tmpdir, "test_file.h5"))
        # Test file opening
        JET.@test_opt open_file("test_type_stability_file.h5", SimpleHDF5.READ_ONLY)
        # Test group creation
        JET.@test_opt create_group(file_id, "group1")
        group_id = create_group(file_id, "group1")


        JET.@test_opt close_group(group_id)
        JET.@test_opt close_file(file_id)
        close_group(group_id)
        close_file(file_id)
    end

    @testset "Write Operations Type Stability" begin
        tmpdir = mktempdir()
        file_id = create_file(joinpath(tmpdir, "test_file.h5"))

        # Test writing different types of arrays
        int_array = [1, 2, 3, 4]
        float_array = [1.1, 2.2, 3.3, 4.4]
        bool_array = [true, false, true, false]

        JET.@test_opt write_array(file_id, "int_array", int_array)
        JET.@test_opt write_array(file_id, "float_array", float_array)
        JET.@test_opt write_array(file_id, "bool_array", bool_array)

        # Actually write the arrays for subsequent tests
        write_array(file_id, "int_array", int_array)
        write_array(file_id, "float_array", float_array)
        write_array(file_id, "bool_array", bool_array)

        # Verify the arrays were written correctly
        @test "int_array" in list_datasets(file_id)
        @test "float_array" in list_datasets(file_id)
        @test "bool_array" in list_datasets(file_id)

        # Test writing arrays to groups
        group_id = create_group(file_id, "group1")
        JET.@test_opt write_array(group_id, "group_int_array", int_array)
        write_array(group_id, "group_int_array", int_array)
        close_group(group_id)

        # Test listing datasets
        JET.@test_opt list_datasets(file_id)

        # Close the file
        close_file(file_id)
    end

    @testset "Read Operations Type Stability" begin
        tmpdir = mktempdir()
        file_id = create_file(joinpath(tmpdir, "test_file.h5"))

        # Write test data
        int_array = [1, 2, 3, 4]
        float_array = [1.1, 2.2, 3.3, 4.4]
        bool_array = [true, false, true, false]

        SimpleHDF5.write_array(file_id, "int_array", int_array)
        SimpleHDF5.write_array(file_id, "float_array", float_array)
        SimpleHDF5.write_array(file_id, "bool_array", bool_array)

        SimpleHDF5.close_file(file_id)
        file_id = SimpleHDF5.open_file(joinpath(tmpdir, "test_file.h5"), SimpleHDF5.READ_ONLY)

        JET.@test_opt SimpleHDF5.get_array_info(file_id, "int_array")

        JET.@test_opt SimpleHDF5.read_array(file_id, "int_array", Array{Int,1})
        JET.@test_opt SimpleHDF5.read_array(file_id, "float_array", Array{Float64,1})
        JET.@test_opt SimpleHDF5.read_array(file_id, "bool_array", Array{Bool,1})

        # Verify the arrays were read correctly
        @test SimpleHDF5.read_array(file_id, "int_array", Array{Int,1}) == int_array
        @test SimpleHDF5.read_array(file_id, "float_array", Array{Float64,1}) == float_array
        @test SimpleHDF5.read_array(file_id, "bool_array", Array{Bool,1}) == bool_array

        @test SimpleHDF5.read_array(file_id, "int_array", Vector{Int}) == int_array
        @test SimpleHDF5.read_array(file_id, "float_array", Vector{Float64}) == float_array
        @test SimpleHDF5.read_array(file_id, "bool_array", Vector{Bool}) == bool_array


        SimpleHDF5.close_file(file_id)
    end

    @testset "Complex Array Type Stability" begin
        tmpdir = mktempdir()
        file_id = create_file(joinpath(tmpdir, "test_file.h5"))

        array_2d = [i + j for i in 1:3, j in 1:4]
        SimpleHDF5.write_array(file_id, "array_2d", array_2d)

        array_3d = [i + j + k for i in 1:2, j in 1:3, k in 1:4]
        SimpleHDF5.write_array(file_id, "array_3d", array_3d)

        SimpleHDF5.close_file(file_id)
        file_id = SimpleHDF5.open_file(joinpath(tmpdir, "test_file.h5"), SimpleHDF5.READ_ONLY)

        JET.@test_opt SimpleHDF5.read_array(file_id, "array_2d", Array{Int,2})
        JET.@test_opt SimpleHDF5.read_array(file_id, "array_3d", Array{Int,3})

        # Verify the arrays were read correctly
        @test SimpleHDF5.read_array(file_id, "array_2d", Array{Int,2}) == array_2d
        @test SimpleHDF5.read_array(file_id, "array_3d", Array{Int,3}) == array_3d

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
        @test_throws ArgumentError SimpleHDF5.read_array(file_id, "vector", Matrix{Int})

        # Close the file
        SimpleHDF5.close_file(file_id)
    end
end

#!/usr/bin/env julia

using Test

using StaticHDF5


@testset "StaticHDF5 Edge Cases" begin

    @testset "Empty and Special Arrays" begin
        tmpdir = mktempdir()
        file = create_file(joinpath(tmpdir, "test_edge_cases.h5"))

        empty_array = Int[]
        write_object(file, "empty", empty_array)

        single_element = [42]
        write_object(file, "single", single_element)

        zero_array = [0, 0, 0]
        write_object(file, "zeros", zero_array)

        special_floats = [NaN, Inf, -Inf, 0.0, -0.0]
        write_object(file, "special", special_floats)

        close_file(file)

        file = open_file(joinpath(tmpdir, "test_edge_cases.h5"))

        @test read_object(file, "empty") == empty_array
        @test read_object(file, "single") == single_element
        @test read_object(file, "zeros") == zero_array

        read_special = read_object(file, "special")
        @test isnan(read_special[1])
        @test isinf(read_special[2]) && read_special[2] > 0
        @test isinf(read_special[3]) && read_special[3] < 0
        @test read_special[4] == 0.0
        @test read_special[5] == -0.0

        close_file(file)
    end

    @testset "Unicode Strings" begin
        tmpdir = mktempdir()
        file = create_file(joinpath(tmpdir, "test_unicode.h5"))

        unicode_strings = ["Hello 世界", "🚀 Julia", "Ñoño", "Café"]
        write_object(file, "unicode", unicode_strings)

        close_file(file)

        file = open_file(joinpath(tmpdir, "test_unicode.h5"))
        read_unicode = read_object(file, "unicode")
        @test read_unicode == unicode_strings
        close_file(file)
    end

    @testset "Dataset Overwrite Behavior" begin
        tmpdir = mktempdir()
        test_file = joinpath(tmpdir, "overwrite_test.h5")

        # Create file with initial data
        file = create_file(test_file)
        write_object(file, "data", [1, 2, 3])
        close_file(file)

        # Reopen file and add new data (not overwriting existing)
        file = open_file(test_file, READ_WRITE)
        write_object(file, "new_data", [8, 9])
        close_file(file)

        # Verify both datasets exist
        file = open_file(test_file)
        @test read_object(file, "data") == [1, 2, 3]
        @test read_object(file, "new_data") == [8, 9]
        close_file(file)
    end

    @testset "Empty File Operations" begin
        tmpdir = mktempdir()
        test_file = joinpath(tmpdir, "empty_test.h5")

        file = create_file(test_file)
        close_file(file)

        file = open_file(test_file)
        objects = keys(file)
        @test length(objects) == 0
        close_file(file)
    end

    @testset "Dataset Creation Conflicts" begin
        tmpdir = mktempdir()
        file = create_file(joinpath(tmpdir, "test_file.h5"))
        initial_data = [1, 2, 3, 4, 5]
        write_object(file, "data", initial_data)
        close_file(file)

        file = open_file(joinpath(tmpdir, "test_file.h5"), READ_WRITE)
        new_data = [10, 20, 30, 40, 50]

        # This should fail because dataset already exists
        @test_throws StaticHDF5.API.H5Error write_object(file, "data", new_data)

        close_file(file)
    end

    @testset "get_dataset_info Error Handling" begin
        tmpdir = mktempdir()
        file = create_file(joinpath(tmpdir, "test_file.h5"))
        write_object(file, "data", [1, 2, 3])
        write_object(file, "scalar", 42)

        # Create a group for testing
        group = create_group(file, "test_group")
        write_object(group, "nested_data", [4, 5, 6])
        close_group(group)

        close_file(file)

        file = open_file(joinpath(tmpdir, "test_file.h5"))

        # Test get_dataset_info on group (should give helpful error)
        @test_throws ArgumentError("'test_group' is a group, not a dataset. Use group operations instead.") get_dataset_info(file, "test_group")

        # Test get_dataset_info on non-existent path
        @test_throws ArgumentError("'nonexistent' does not exist or is not a dataset.") get_dataset_info(file, "nonexistent")

        # Test get_dataset_info on valid array dataset (should work)
        info = get_dataset_info(file, "data")
        @test info.type == Int64
        @test info.dims == (3,)
        @test !info.is_scalar

        # Test get_dataset_info on scalar dataset (should work)
        scalar_info = get_dataset_info(file, "scalar")
        @test scalar_info.type == Int64
        @test scalar_info.dims == ()
        @test scalar_info.is_scalar

        # Test get_dataset_info on nested dataset (should work)
        nested_info = get_dataset_info(file, "test_group/nested_data")
        @test nested_info.type == Int64
        @test nested_info.dims == (3,)
        @test !nested_info.is_scalar

        close_file(file)
    end
end

#!/usr/bin/env julia

using Test

using SimpleHDF5


@testset "SimpleHDF5 Advanced Tests" begin

    @testset "Edge Cases" begin
        tmpdir = mktempdir()
        file_id = create_file(joinpath(tmpdir, "test_file.h5"))

        # Test empty array
        empty_array = Int64[]
        write_array(file_id, "empty_array", empty_array)

        # Test array with one element
        single_element = [42]
        write_array(file_id, "single_element", single_element)

        # Test very small array
        tiny_array = [1, 2]
        write_array(file_id, "tiny_array", tiny_array)

        # Test array with zeros
        zero_array = zeros(Int64, 5)
        write_array(file_id, "zero_array", zero_array)

        # Test array with NaN and Inf
        special_array = [NaN, Inf, -Inf, 0.0, 1.0]
        write_array(file_id, "special_array", special_array)

        close_file(file_id)

        # Read back and verify
        file_id = open_file(joinpath(tmpdir, "test_file.h5"))

        # Empty array
        read_empty = read_array(file_id, "empty_array")
        @test length(read_empty) == 0

        # Single element array
        read_single = read_array(file_id, "single_element")
        @test read_single == single_element
        @test length(read_single) == 1

        # Tiny array
        read_tiny = read_array(file_id, "tiny_array")
        @test read_tiny == tiny_array

        # Zero array
        read_zero = read_array(file_id, "zero_array")
        @test read_zero == zero_array

        # Special values array
        read_special = read_array(file_id, "special_array")
        @test isnan(read_special[1])
        @test isinf(read_special[2]) && read_special[2] > 0
        @test isinf(read_special[3]) && read_special[3] < 0
        @test read_special[4] == 0.0
        @test read_special[5] == 1.0

        close_file(file_id)
    end

    @testset "Overwriting Datasets" begin
        # Create file with initial data
        tmpdir = mktempdir()
        file_id = create_file(joinpath(tmpdir, "test_file.h5"))
        initial_data = [1, 2, 3, 4, 5]
        write_array(file_id, "data", initial_data)
        close_file(file_id)

        # Open file and overwrite data
        file_id = open_file(joinpath(tmpdir, "test_file.h5"), READ_WRITE)
        new_data = [10, 20, 30, 40, 50]

        # This should fail because dataset already exists
        @test_throws SimpleHDF5.API.H5Error write_array(file_id, "data", new_data)

        # Workaround: we need to delete and recreate
        # For now, we'll just close and reopen with truncate
        close_file(file_id)
    end

    @testset "Empty File" begin
        # Create an empty file
        tmpdir = mktempdir()
        file_id = create_file(joinpath(tmpdir, "test_file.h5"))
        close_file(file_id)

        # Open and check that there are no datasets
        file_id = open_file(joinpath(tmpdir, "test_file.h5"))
        datasets = list_datasets(file_id)
        @test isempty(datasets)
        close_file(file_id)
    end

end


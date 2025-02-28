#!/usr/bin/env julia

# SimpleHDF5 Test Runner
# This script runs all tests for the SimpleHDF5 module

using Test
using SimpleHDF5
# Check if BenchmarkTools is available
global has_benchmark_tools = true
try
    using BenchmarkTools
catch
    global has_benchmark_tools = false
    @warn "BenchmarkTools not found, skipping performance tests"
end

using JET

# Check if SimpleHDF5 module exists

# Function to clean up test files before running tests
function cleanup_test_files()
    for file in ["test.h5", "test_group.h5", "test_integer.h5", "test_bool.h5", 
                 "test_type_stability_file.h5", "test_type_stability_write.h5", 
                 "test_type_stability_read.h5", "test_type_stability_complex.h5"]
        isfile(file) && rm(file)
    end
end

# Function to run a test file in a separate process
function run_test_file(test_file)
    println("Running $test_file...")
    
    # Clean up before running tests
    cleanup_test_files()
    
    # Run the test file
    cmd = `$(Base.julia_cmd()) $test_file`
    result = run(cmd)
    
    # Check if the test passed
    if result.exitcode == 0
        println("✅ $test_file: All tests passed")
        return true
    else
        println("❌ $test_file: Some tests failed")
        return false
    end
end

# Initialize all_passed
all_passed = true

# Run basic tests
all_passed &= run_test_file("test_simple_hdf5.jl")

# Run integer types tests
all_passed &= run_test_file("test_integer_types.jl")

# Run read array enhancements tests
all_passed &= run_test_file("test_read_array_enhancements.jl")

# Run bool handling tests
all_passed &= run_test_file("test_bool_handling.jl")

# Run type stability tests
all_passed &= run_test_file("test_type_stability.jl")

# Run advanced tests if BenchmarkTools is available
if has_benchmark_tools
    all_passed &= run_test_file("test_advanced.jl")
else
    println("Skipping advanced tests (BenchmarkTools not available)")
end

# Final cleanup
cleanup_test_files()

# Print summary
if all_passed
    println("\n✅ All tests completed successfully!")
    exit(0)
else
    println("\n❌ Some tests failed!")
    exit(1)
end
println("====================") 
using Test
using SimpleHDF5

include("test_simple_hdf5.jl")
include("test_edge_cases.jl")
if VERSION >= v"1.11" && VERSION < v"1.12"
    include("test_type_stability.jl")
end
include("test_hdf5jl_integration.jl")

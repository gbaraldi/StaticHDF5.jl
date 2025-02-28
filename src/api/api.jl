module API

using Libdl: dlopen, dlclose, dlpath, dlsym, RTLD_LAZY, RTLD_NODELETE
using Base: StringVector
using Preferences: @load_preference, delete_preferences!, set_preferences!

using HDF5_jll

include("lock.jl")
include("types.jl")
include("error.jl")
include("functions.jl") # core API ccall wrappers
include("helpers.jl")

function __init__()
    # Ensure this is reinitialized on using
    libhdf5handle[] = dlopen(libhdf5)

    # Disable file locking as that can cause problems with mmap'ing.
    # File locking is disabled in HDF5.init!(::FileAccessPropertyList)
    # or here if h5p_set_file_locking is not available
    @static if !has_h5p_set_file_locking() && !haskey(ENV, "HDF5_USE_FILE_LOCKING")
        ENV["HDF5_USE_FILE_LOCKING"] = "FALSE"
    end

    # use our own error handling machinery (i.e. turn off automatic error printing)
    h5e_set_auto(API.H5E_DEFAULT, C_NULL, C_NULL)
end

end # module API

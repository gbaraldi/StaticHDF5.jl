# Code from HDF5.jl

# The MIT License (MIT)
# Copyright (c) 2012-2021: Timothy E. Holy, Simon Kornblith, and contributors: https://github.com/JuliaIO/HDF5.jl/contributors

# Permission is hereby granted, free of charge, to any person obtaining a copy of this software
# and associated documentation files (the "Software"), to deal in the Software without
# restriction, including without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the
# Software is furnished to do so, subject to the following conditions:

# The above copyright notice and this permission notice shall be included in all copies or
# substantial portions of the Software.

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING
# BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,
# DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.


const liblock = ReentrantLock()

# Try to acquire the lock (test-test-set) and close if successful
# Otherwise, defer finalization
# https://github.com/JuliaIO/HDF5.jl/issues/1048
function try_close_finalizer(x)
    if !islocked(liblock) && trylock(liblock) do
            close(x)
            true
        end
    else
        finalizer(try_close_finalizer, x)
    end
    return nothing
end

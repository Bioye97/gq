Testing
=======

Set ``GQ_BUILD_TESTS`` to ``ON`` in ``cmake/ConfigUser.cmake``, then configure,
build, and run the integration suite from a separate build directory:

.. code-block:: bash

   mkdir build
   cd build
   cmake ..
   cmake --build .
   ctest --output-on-failure

The suite covers the merge modules, ``topobath``, ``elygtl``, the SSH modules,
NetCDF metadata, and remote-input handling. Remote-input tests may require
network access when the relevant GMT data are not already cached.

Documentation checks
--------------------

Sphinx runs with warnings treated as errors for HTML, man, and LaTeX builds.
This identifies broken internal references, invalid reStructuredText, missing
figures, and stale generated usage. External URL checking is intentionally
separate because a fully local build should not require network access.

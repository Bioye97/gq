Documentation Workflow
======================

Source layout
-------------

Handwritten Sphinx sources live in ``doc/rst/source``. Each example remains
owned by ``doc/examples/<module>/<example>`` and contains its README, shell
script, and rendered figure. The documentation generator converts that
README and copies lightweight presentation assets into the build tree. Shell
scripts are offered as downloads on the generated pages instead of being
displayed inline.

Build targets
-------------

Enable ``GQ_BUILD_DOCS`` in ``cmake/ConfigUser.cmake``, configure GQ, and run
the following commands from the build directory:

.. code-block:: bash

   cmake --build . --target docs
   cmake --build . --target docs_html
   cmake --build . --target docs_man
   cmake --build . --target docs_latex
   cmake --build . --target docs_pdf

``docs_usage`` refreshes the eight module usage files by invoking the compiled
plugin with ``-?``. ``docs_examples`` refreshes the generated gallery. The
HTML, man, and LaTeX targets depend on both, so they update generated content
automatically. The combined ``docs`` target builds HTML and man pages only.
The large PDF manual is opt-in through ``docs_pdf``, which first refreshes the
LaTeX sources and then runs ``latexmk``.

The examples are not rerun during a documentation build. This keeps local
builds predictable and avoids downloading or loading large model files.

Version selector
----------------

The HTML sidebar includes a documentation-version selector. Local builds use
the project version, currently ``1.0.0``. A publishing workflow can supply all
available versions and identify the version being built with two environment
variables:

.. code-block:: bash

   export GQ_DOC_CURRENT_VERSION=1.0.0
   export GQ_DOC_VERSIONS='[["development", "https://example.org/gq/"], ["1.0.0", "https://example.org/gq/1.0.0/"]]'

``GQ_DOC_VERSIONS`` is a JSON list of display-label and documentation-root URL
pairs. Each published version should be built with the same list and copied to
the corresponding URL directory. The final URLs can be added when the GQ
repository and documentation host are chosen.

Adding an example
-----------------

Add a directory under the appropriate module, including at least
``README.md`` and one shell script. Committed PNG and PDF outputs are included
automatically. Reconfigure CMake or rebuild after its glob check detects the
new directory.

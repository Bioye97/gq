Input and Output Formats
========================

Text tables
-----------

``merge1d`` and ``ssh1d`` accept ordinary text tables, in addition to NetCDF 
series. The first column is the coordinate and subsequent columns are fields. 
A participating set of tables must have the same number of field columns and 
strictly increasing coordinates after input scaling. Scaling does not reorder 
table rows. ``merge1d`` cannot use both text and NetCDF sources in a single 
run.

NetCDF variables
----------------

GQ reads single and multiparameter NetCDF files. Compatible fields share
coordinate dimensions. Though the names of equivalent fields may differ
between source files. Coordinate variables are identified through standard
axis metadata and conventional x, y, and z names.

``merge2d`` NetCDF inputs can be ordinary grids or selected layers from
three-dimensional cubes. Three-dimensional model variables may store
their dimensions in any order when the coordinate relationship is
unambiguous. However, GQ output cubes use a ``(z,y,x)`` order.

When SSH application changes a model lattice through ``-R``, ``-I``, or
``-T``, scalar ancillary variables in the NetCDF file are unchanged.
Unselected variables that depend on a changed coordinate are omitted 
because they no longer match the output lattice.

Output variables
----------------

The merge modules may append a shared variable named ``weight`` or write only
that variable. Its ``long_name`` is ``merging weight``, its units are ``1``,
and its range is from zero to one.

The SSH modules use fractional perturbations. In application mode, selected
model values are multiplied by ``1 + epsilon``. A taper requested for output
is also called ``weight``, with ``long_name`` set to
``heterogeneity taper weight``.

GQ writes missing output values as NaN. See :doc:`missing-values`.

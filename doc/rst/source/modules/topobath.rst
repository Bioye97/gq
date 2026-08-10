topobath
========

``topobath`` adds, removes, or replaces topography and/or
bathymetry in a three-dimensional multiparameter NetCDF cube. It can shift an
entire model column, construct a one-dimensional or linear land extension,
remove a water column, or rebuild water columns above a newly created seafloor.

Synopsis
--------

.. code-block:: bash

   gmt topobath model.nc [new_surface.nc] -Goutput.nc -Ooperation [-Mmethod] [options]

Coordinates
-----------

Source scaling is applied before classification, sampling, or any surface
operation. The transformed model z axis must increase strictly from the top
of the model to its bottom. Thus, elevations above sea level are negative and
depths below sea level are positive. Old and new surface grids must use the
same units and signs. Use the model ``+z`` modifier and the surface ``+v`` or
``+z`` modifier to establish this convention when necessary. Scaling changes
coordinate values without reordering model layers.

``-T<zmin>/<zmax>/<dz>`` defines the working output axis, where ``zmin`` is
the top, ``zmax`` is the bottom, and ``zmin < zmax``. Without ``-T``, the
module derives increasing bounds at the smallest transformed input spacing.
``-Z`` is applied after every topography operation. Its ``+x``, ``+y``, and
``+z`` modifiers scale final coordinates, while ``+X``, ``+Y``, and ``+Z``
set their unit metadata. The ``+v`` and ``+V`` lists independently scale and
name the units of selected output fields in model-selector order. Scaling is
performed in place without reordering coordinates, model layers, fields, or
ancillary variables. A negative axis scale therefore writes a decreasing
coordinate. For example,
``-Z+x0.001+Xkm+y0.001+Ykm+z-1000+Zm+v0.001,0.001+Vkm/s,km/s``
can convert horizontal coordinates from metres to kilometres, restore a
positive-up vertical coordinate in metres, and convert two velocity fields
from metres per second to kilometres per second.

Operations and scopes
---------------------

Every run explicitly selects an operation with ``-O``:

* ``-Oa`` adds a requested surface to a model that normally begins at sea
  level. Nonzero old surfaces are accepted with a warning.
* ``-Or`` removes the selected existing surface. Land is flattened to zero.
  Targeted seafloors move to zero and their water columns are removed.
* ``-Ox`` replaces the selected old surface with the supplied new surface.

Append ``+t`` to operate only on dry-land topography or ``+b`` to operate
only on wet-region bathymetry. With no modifier, both classes are selected. A
column outside the selected scope is unchanged. The wet/dry classification,
rather than the sign of a surface value, controls this selection, so dry land
below sea level is valid (as is the case in Death Valley or the Dead Sea). 
If interpolated relief lies above sea level in a cell classified as wet, the 
requested seafloor is clamped to sea level with a warning. This accommodates 
small coastline differences between a categorical mask and a continuous relief 
grid without changing the authoritative class.

Adding and replacing require one construction method:

* ``-Mp`` shifts the complete column to the new surface.
* ``-Me`` maps the old dry-land surface to zero and extends its value
  vertically to the new elevation.
* ``-Ml`` maps the old dry-land surface to zero and linearly grades its value
  to the field-specific surface minimum supplied with ``-L``.

Wet columns always shift the solid model to the requested seafloor and fill
the newly created water column with values set with ``-W``. Dry columns whose 
requested surface is below sea level also shift as complete columns. ``-M`` is 
therefore required by add(a) and replace(x) operations, but is not used by 
remove(r).

Wet/dry classification and inference
------------------------------------

``-Cg`` gives GMT shoreline classification priority and is the default.
``-Cm`` lets model evidence override that prior where the model resolves a
class. ``-Cl`` and ``-Cw`` classify the complete domain as land or wet,
respectively. For geographic models, ``-D`` selects the GSHHG resolution and
``-A`` controls which hierarchy levels are wet or dry. Selected oceans, lakes,
and ponds are wet; land and islands in lakes are dry. A user ``-K`` grid with
wet = 0 and land = 1 is authoritative and replaces both GMT and model
classification.

Supplying the old surface with ``-E`` is strongly recommended. Without it,
``topobath`` finds the shallowest valid boundary among all selected fields.
Different field boundaries produce a warning, and the shallowest boundary is
used. In wet columns, field-specific ``-W`` values and tolerances identify the
water column and seafloor. Model classification can only recognize wet
regions when those signatures are available.

A parameter missing exactly at a surface identified by another field remains
missing. Values are not pulled upward merely to hide that disagreement.
Consequently, ``-E`` is particularly important when a legitimate surface
parameter may be NaN, because a surface inferred from that parameter alone
could mistake the missing value for air. ``-Q`` writes the inferredold surface 
and, with ``+c``, classification codes 0 (unresolved), 1 (land), and 2 (wet).

Air and water
-------------

``-F<field>/<air>`` sets a field-specific air value. Unspecified air values
are NaN. The air value applies strictly above the identified free surface; a
NaN exactly on that surface remains NaN.

``-W<field>/<water>[+t<tolerance>]`` serves two roles: it recognizes old
water during surface inference and supplies values for newly created water.
It is required for every selected field when a wet surface must be inferred,
or when add/replace creates or rebuilds a water column. It is not required
merely because wet cells exist when ``-E`` supplies the old surface and the
operation either removes their water or leaves the wet columns unchanged.

Sampling and missing values
---------------------------

``-H`` optionally fills strictly internal holes in each native x-y model
layer. Nearest-neighbor, linear Delaunay, local weighted-average, spline, and
minimum-curvature methods are available. Boundary-connected missing regions
and original valid nodes remain unchanged, and ``+m<maxgap>`` can restrict
filling by the x and y spans of each hole. Without ``-H``, native horizontal
holes remain missing.

``-R`` must lie within the transformed model domain. ``-I`` and common
``-n`` resample the selected fields, inferred surface, and relief onto the
horizontal output lattice. This resampling is distinct from ``-H`` and does
not deliberately fill data holes. ``-T`` defines the output vertical
lattice. ``-S`` selects the GMT vertical interpolant: Akima (``a``), cubic
(``c``), step-up (``e``), linear (``l``), nearest (``n``), or smoothing spline
(``s<p>``) with non-negative fit parameter ``p``. Linear is the default. Its
``+g`` modifier bridges internal missing layers, with an optional maximum gap.
Exterior missing regions and air are not extrapolated. Packed values and
declared missing sentinels are decoded on input, and output missing values are
set to NaN.

The coordinate modifiers of ``-Z`` also transform the optional ``-Q`` grids:
``+x`` and ``+y`` scale their coordinates, and ``+z`` scales the inferred old
surface. Classification codes cannot be scaled. Field ``+v`` and ``+V``
modifiers apply only to the selected three-dimensional model fields.

The complete order is input scaling, optional native-layer ``-H`` filling,
``-n`` horizontal resampling, wet/dry classification, old-surface selection
or inference, the requested operation, ``-S`` vertical interpolation, and
final ``-Z`` output scaling. Note that a sufficiently large pull-up operation
(i.e., upward column shift) can move the model base outside the source cube. 
Such newly exposed base values are set to NaN, and the module reports a warning.

Field selectors limit the processed 3-D variables. Without one, every numeric
3-D variable sharing the first compatible x/y/z dimensions is selected.
Compatible global, coordinate, scalar, and horizontal ancillary metadata are
unchanged. Coordinate-dependent ancillary variables are omitted when ``-R`` or
``-I`` changes the horizontal lattice.

Usage
-----

.. gq-usage:: topobath

Examples
--------

See :doc:`../examples/topobath/index`.

See also
--------

:doc:`elygtl`, :doc:`merge3d`, :doc:`../reference/missing-values`

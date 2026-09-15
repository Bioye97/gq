merge3d
=======

``merge3d`` tiles or smoothly merges three-dimensional multiparameter NetCDF cubes. 
Horizontal support polygons (i.e., clip files) are extruded/extended through a 
selectable  vertical interval, with independent x, y, and z windows and taper ratios.

Synopsis
--------

.. code-block:: bash

   gmt merge3d <cubes|mergefile> -Rregion -Iincrement -Tzmin/zmax/dz \
       -Goutput.nc [options]

Behavior
--------

Output fields use ``(z,y,x)`` dimensions and geometry defined by ``-R``,
``-I``, and ``-T``. Every input axis must be strictly increasing after its
source transform. Input coordinate scaling does not reorder coordinates or cube
data. A decreasing source axis can use a negative input scale to make it
increase. Mergefile z supports and ``-T`` use this transformed system. Output
``-Z`` transforms only the completed output and may scale both coordinates and
model fields without reordering them.

Direct cube lists tile values in availability order and retain the first
available value by default. A mergefile enables primary and secondary pairing
and contains records of the form::

   primary [secondary] [polygon] [zlo/zhi] [xwindow/ywindow/zwindow] \
       [rx1/rx2/ry1/ry2/rz1/rz2]

Each non-comment record contains up to six whitespace-separated fields:

``primary``
   Required NetCDF source providing the primary field or fields.

``secondary``
   Optional source paired with the primary. Pairing applies only within the
   primary horizontal and vertical support and does not extend the primary
   availability beyond its domain. Use ``-`` for an unpaired fallback tile.

``polygon``
   Optional xy polygon defining the horizontal support. The complete primary
   horizontal domain is used when it is omitted.

``zlo/zhi``
   Optional vertical support in transformed source coordinates. The complete
   transformed primary z range is the default.

``xwindow/ywindow/zwindow``
   BLEND window functions. One name applies to all axes. When two names are
   supplied, x also applies to z. Three names set x, y, and z. The default is
   ``cosine/cosine/cosine``.

``rx1/rx2/ry1/ry2/rz1/rz2``
   Dimensionless taper ratios in ``[0, 0.5)``. One value applies everywhere,
   three apply symmetrically to x, y, and z, and six control every side
   independently. ``rx1/rx2`` apply at west/east (low/high x), ``ry1/ry2``
   at south/north (low/high y), and ``rz1/rz2`` at ``zlo/zhi``. Every ratio
   defaults to 0.2.

   Each ratio sets the fraction of the corresponding support extent used by
   the transition at one boundary. For example, for vertical support
   ``0/40``, ``rz1/rz2 = 0/0.2`` disables the ``zlo`` taper and uses
   approximately the final 8 coordinate units for the ``zhi`` taper. Within
   each transition, the selected window controls how the primary
   merging-weight factor changes between its boundary value and 1. The paired
   secondary receives the complementary weight. The x, y, and z factors are
   multiplied. Larger ratios give broader transitions and a smaller
   full-primary interior. 0 disables the taper on that side. The ``boxcar``
   window ignores taper ratios and has unit weight throughout the support.

   For the polygonal horizontal support, BLEND evaluates x and y tapers along
   local polygon cross-sections and adapts the transition width where a
   cross-section is too narrow for the nominal support-wide taper. The z
   taper uses the complete ``zlo/zhi`` support interval.

Use ``-`` to skip an optional field when supplying a later field. Trailing
optional fields may be omitted. Add a secondary as a later unpaired record
when it should provide fallback values outside a paired primary domain. For
example::

   primary.nc?vp,vs secondary.nc?p,s support.txt 0/40 cosine/cosine/cosine 0.2/0.2/0
   secondary.nc?p,s - - - -

The polygon is extruded through its vertical support. Polygon validation and
conversion with ``-ME`` or ``-MB`` follow ``merge2d``.

NetCDF dimensions may appear in any order when x, y, and z coordinates can be
identified from CF metadata or conventional names. All selected fields in one
source must share those dimensions. Select fields with
``file.nc?field1,field2,...``. If ``?`` is omitted, the first eligible 3-D data
variable is used. ``-F`` names output fields and does not select input fields.
Source selectors map positionally to ``-F``, so ``model1.nc?vp,vs,den`` and
``model2.nc?p,s,d`` can both map to ``vp,vs,rho`` with ``-Fvp,vs,rho``.
Without ``-F``, output retains the first primary's source field names and
every source must use those same names.

Input modifiers follow the field list. ``+x``, ``+y``, and ``+z`` scale source
coordinates. ``+v`` supplies one broadcast field scale or one scale per
selected field. Uppercase counterparts set target-unit metadata. ``+n``
declares an additional missing-value sentinel. Use
``file.nc?<field1,field2,...>+<modifiers>`` for named fields or
``file.nc?+<modifiers>`` for the default field. For example,
``model.nc?vp,vs+x0.001+Xkm+y0.001+Ykm+z-1/1000+Zkm+v0.001,0.001+Vkm/s,km/s``
scales x and y in m to km, converts a source z axis of
``4000 ... -16000 m`` to ``-4 ... 16 km`` without changing cube order, and
scales both selected fields in m/s to km/s. Input transforms occur before
interpolation, support polygon tests, and merging. Afterward,
``-Z+z-1000+Zm`` restores ``4000 ... -16000 m`` without changing the output
field or weight order.

Output ``-Z`` applies after merging. Its field scales and units follow ``-F``
order when supplied and selector order otherwise. It scales coordinates and
fields in place and does not reorder coordinates, fields, or weight. A
negative axis scale therefore produces a decreasing output axis. For example,
with ``-Fvp,vs``,
``-Z+x0.001+Xkm+y0.001+Ykm+z-0.001+Zkm+v0.001,0.001+Vkm/s,km/s`` converts x
and y in m to km, converts negative-down z in m to positive-down km, and
converts both velocity fields in m/s to km/s without reordering the cube.

Aggregate weighting with ``-A``, paired gap filling with ``-P``, and the
shared ``weight`` output follow the lower-dimensional merge modules. Only
overlapping primaries must share the same secondary when using ``-A``. 
Non-overlapping primaries may use different secondaries.

The ``-H`` option fills strictly internal horizontal holes in every native
x-y layer before vertical interpolation, resampling, and merging. It matches
``merge2d``: nearest neighbor (``n``), linear Delaunay (``l``), local weighted
average (``a``), spline (``s``), and minimum curvature (``m``) are available,
with linear Delaunay as the default. The ``+m<maxgap>`` modifier limits filling
to holes whose x and y spans do not exceed the specified number of grid nodes.
Original finite nodes and boundary-connected gaps are preserved. Input cubes
used with ``-H`` must have regularly spaced x and y coordinates.

The ``-S`` option selects vertical interpolation: Akima (``a``), cubic
(``c``), step-up (``e``), linear (``l``), nearest (``n``), or smoothing
spline (``s<p>``) with non-negative fit parameter ``p``. Linear (``l``) is
the default. Vertical interpolation remains within contiguous non-missing
runs by default. Appending ``+g`` bridges internal missing layers, optionally
subject to a maximum z-coordinate distance. It does extrapolate beyond the
available vertical range and does not bridge horizontal gaps.

After vertical interpolation, GMT ``-n`` controls horizontal resampling of
each output z layer: nearest neighbor (``-nn``), bilinear (``-nl``), bicubic
(``-nc``), or B-spline (``-nb``). Bicubic is the default. Regular horizontal
grids use GMT's two-dimensional interpolation and the selected ``-n``
modifiers. Cubes with irregular x or y coordinates use separable x-then-y
GMT splines. In this fallback, ``-nb`` and ``-nc`` both use cubic
interpolation.

The options do not conflict. Processing follows input scaling, ``-H`` filling
of internal holes in native x-y layers, ``-S`` vertical interpolation to an
output z layer, ``-n`` horizontal resampling to the ``-R``/``-I`` grid, and
then merging. Without ``-H``, ``-n`` resamples available values but does not
deliberately fill internal horizontal holes. For example, ``-Hl -Sl+g -nl`` 
fills native x-y holes with linear Delaunay interpolation, bridges internal 
z gaps linearly, and resamples each output layer horizontally with bilinear 
interpolation.

Declared missing values, IEEE NaNs, selector ``+n`` sentinels, and ``-di`` are
set to NaN. ``-W`` adds the shared variable ``weight`` with
``long_name="merging weight"`` and units ``1``. ``-W+o`` writes only the
coordinates and weight. The implementation holds one input field at a time
and writes completed output layers incrementally rather than retaining multiple 
data cubes in memory.

Usage
-----

Merging-weight output follows the paired supports in mergefile order. The
first support containing a node supplies its primary weight; outside that
support, later supports, including broader parents, remain visible. A zero
on the selected support boundary is retained. With ``-A``, positive weights
are summed and capped at 1 only where primaries overlap and share the selected
secondary. Elsewhere, the regular primary weight is retained. An unpaired
background has weight 0 in merging mode.

This produces one ordered weight field from the supports in the mergefile,
without plotting overlays. It describes the primary tapers, not final
per-source contribution fractions or field-specific missing-value replacements.
The same selection applies to ``-W`` and ``-W+o``.

.. gq-usage:: merge3d

Examples
--------

See :doc:`../examples/merge3d/index`.

See also
--------

:doc:`merge2d`, :doc:`topobath`, :doc:`../reference/scaling-units`

merge1d
=======

``merge1d`` tiles or smoothly merges one-dimensional multiparameter data 
series. Inputs may be text tables or one-dimensional NetCDF series, but not 
both at the same time.

Synopsis
--------

.. code-block:: bash

   gmt merge1d <mergefile|input1 input2 ...> -Tmin/max/inc [-Goutput] [options]

Behavior
--------

The output axis is defined by ``-Tmin/max/inc``. Text tables use the first
column as the coordinate and every remaining column as a data field. All
participating tables must contain the same number of fields/columns. NetCDF 
variables selected together must share one coordinate dimension.

Direct file lists tile data in availability order. The default ``-Cf``
retains the first available value. ``-Cl``, ``-Co``, and ``-Cu`` select the
lowest, last, or highest value. The ``+n`` and ``+p`` modifiers restrict
replacement by sign.

Weighted merging uses records of the form::

   primary [secondary] [west/east] [window] [r1/r2]

Each non-comment record contains up to five whitespace-separated fields:

``primary``
   Required source providing the primary values for the record.

``secondary``
   Optional source paired with the primary for merging. Use ``-`` for an
   unpaired fallback tile. Pairing is valid only within the primary coordinate
   domain.

``west/east``
   Support interval for a paired primary. It must lie within the primary
   coordinate domain. The default is the entire primary domain.

``window``
   BLEND window function applied within the support. The default is
   ``cosine``.

``r1/r2``
   Dimensionless beginning and ending taper ratios relative to the support
   length. ``r1`` applies at west (low coordinate) and ``r2`` at east (high
   coordinate). Each ratio must be in ``[0, 0.5)``. One ratio applies
   symmetrically, and the default is ``0.2/0.2``.

   A ratio sets the fraction of the support length used by the transition at
   that boundary. For example, on support ``20/80``, ``0/0.2`` disables the
   west taper and uses approximately the final 12 coordinate units for the
   east taper. Within a taper, the selected window controls how the primary
   merging weight changes between its boundary value and 1. The paired
   secondary receives the complementary weight. Larger ratios give broader
   transitions and a smaller full-primary interior. A ratio of 0 disables the
   taper on that side. The ``boxcar`` window ignores taper ratios and has unit
   weight throughout the support.

Use ``-`` to skip an optional field when supplying a later field. Trailing
optional fields may be omitted. Blank lines and text following ``#`` are
ignored. For example::

   primary.nc secondary.nc 20/80 cosine 0.25/0.25
   secondary.nc - - - -

Add the secondary as a later unpaired record when it should provide fallback
values outside the paired primary domain. ``-A`` normalizes positive weights
where primary supports that share the same secondary source overlap.

The ``-S`` option selects interpolation onto ``-T``: Akima (``a``), cubic
(``c``), step-up (``e``), linear (``l``), nearest (``n``), or smoothing
spline (``s<p>``) with non-negative fit parameter ``p``. Linear (``l``) is
the default. Interpolation operates independently within contiguous finite
runs by default. Append ``+g`` to bridge internal gaps, optionally with a
maximum bracketing coordinate distance. Values are not extrapolated before
the first or after the last available sample. ``-P`` may subsequently fill
any remaining primary gaps from the paired secondary. Without ``-P``,
those primary gaps remain missing.

Select NetCDF fields by appending ``?`` and a comma-separated list to each
filename, for example ``model.nc?vp,vs,rho``. Selected variables must share
one coordinate dimension. If ``?`` is omitted, ``merge1d`` uses the first
eligible one-dimensional data variable. Selector modifiers follow the field
list. Use ``model.nc?<field1,field2,...>+<modifiers>`` for named fields or
``model.nc?+<modifiers>`` to transform the default variable without naming it.
For example,
``model.nc?vp,vs+x0.001+Xkm+v0.001,0.001+Vkm/s,km/s`` selects ``vp`` and
``vs``, scales the input axis in metres to kilometres, and scales both fields
in m/s to km/s.

The selector modifiers ``+x`` and ``+v`` scale the input coordinate and
fields, while ``+X`` and ``+V`` set their target-unit metadata. One ``+v`` or
``+V`` value applies to every selected field. Otherwise, values follow
selector order. These input transforms are applied before interpolation and
merging. Input ``+x`` scaling does not reorder coordinates or samples, and the
transformed input axis must be strictly increasing. A decreasing source axis
can therefore use a negative ``+x`` scale to make it increase. Output ``-Z+x``
can restore the axis convention after merging without reordering the
data. The ``+n`` modifier declares an additional missing-value sentinel.

The ``-F`` option names output NetCDF variables. It does not select source
variables. Selected fields map positionally to ``-F``, so
``model1.nc?vp,vs,den`` and ``model2.nc?p,s,d`` can both map to output fields
``vp,vs,rho`` with ``-Fvp,vs,rho``. One explicitly selected variable retains
its source name when ``-F`` is absent. An unselected single variable is named
``z``. The ``-Z`` modifiers transform the final coordinate and fields after
merging, in ``-F`` order when supplied and model selector order otherwise. ``-Z``
scales output coordinates and fields in place and does not reorder coordinates,
fields, or weights. A negative ``-Z+x`` scale therefore produces a decreasing
output axis. For example, with ``-Fvp,vs``,
``-Z+x-0.001+Xkm+v0.001,0.001+Vkm/s,km/s`` converts a positive-down axis from
m to a negative-down axis in km and converts both velocity fields in m/s to
km/s without changing sample order. Declared missing values, IEEE NaNs,
selector ``+n`` sentinels, and
text ``-di`` values are set to NaN.

Text output goes to standard output unless ``-G`` is supplied. A ``.nc``
suffix requests NetCDF output. ``-W`` adds the shared ``weight`` field, with
``long_name="merging weight"`` and units ``1``. ``-W+o`` writes only the
coordinate and weight. All selected fields use this same merging weight.

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

.. gq-usage:: merge1d

Examples
--------

See :doc:`../examples/merge1d/index`.

See also
--------

:doc:`merge2d`, :doc:`merge3d`, :doc:`../reference/supports-windows`,
:doc:`../reference/missing-values`

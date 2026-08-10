ssh3d
=====

``ssh3d`` generates or applies three-dimensional fractional perturbation
fields with isotropic or axis-aligned anisotropic correlation lengths to 
selected model fields in multiparameter three-dimensional NetCDF cubes. 
The perturbation field can be tapered using similar functionality as in 
``merge3d``.

Synopsis
--------

.. code-block:: bash

   gmt ssh3d [-A model.nc] -Rregion -Iincrement -Tzmin/zmax/dz \
       -Dstddev [statistics] -Goutput.nc

Behavior
--------

The spectral models and normalization follow ``ssh2d``. One correlation length
is isotropic; three lengths define axis-aligned x/y/z anisotropy. Shared
statistics apply to every selected field, while field-specific ``-D``, ``-C``,
and ``-U`` values override them. Fields share a realization unless ``-Q+i`` is
selected, and spectral padding reduces periodic edge effects.

Without ``-A``, ``-R``, ``-I``, and ``-T`` define a regular NetCDF cube. In
application mode geometry is inherited unless those options request a subset
or new lattice. Source ``+x``, ``+y``, ``+z``, and ``+v`` transforms occur
first. They never reorder data. Transformed coordinates must be regular and
increasing. A negative input scale can therefore convert a descending axis to
the required increasing working convention while preserving layer order.

``-H`` fills enclosed horizontal NaN holes independently on each z layer.
``-R`` and ``-I`` then resample horizontally with the common ``-n`` method.
``-T`` resamples vertically with ``-S``. ``-S+g`` also bridges internal
vertical gaps, optionally subject to a maximum gap in transformed z units.
After preprocessing, each valid selected value becomes ``m * (1 + epsilon)``.
``-Z`` performs final axis and field scaling without reordering, so a negative
output z scale can restore the original convention. When the lattice changes,
scalar ancillary variables are retained and incompatible coordinate-dependent
variables are omitted. Unresolved or missing values remain NaN.

``-P`` defines an xy polygon extruded/extended through the model's vertical axis, 
while ``-L`` restricts its vertical interval. A non-monotone polygon may be 
converted with ``-EE`` or ``-EB``. ``-W`` accepts independent x/y/z window 
functions and one, three, or six taper ratios for symmetric or side-specific 
control. All fields share the same tapering parameters, which is applied after 
statistical  normalization and may be written as the ``weight`` variable with
``long_name="heterogeneity taper weight"`` and units ``1``.

Usage
-----

.. gq-usage:: ssh3d

Examples
--------

See :doc:`../examples/ssh3d/index`.

See also
--------

:doc:`ssh1d`, :doc:`ssh2d`, :doc:`../reference/statistical-models`

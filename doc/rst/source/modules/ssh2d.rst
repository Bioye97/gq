ssh2d
=====

``ssh2d`` generates or applies two-dimensional fractional perturbation
fields with isotropic or axis-aligned anisotropic correlation lengths to 
selected model fields in multiparameter two-dimensional NetCDF grids. 
The perturbation field can be tapered using similar functionality as in 
``merge2d``.

Synopsis
--------

.. code-block:: bash

   gmt ssh2d [-A model.nc] -Rregion -Iincrement -Dstddev [statistics] \
       -Goutput.nc

Behavior
--------

The default von Karman model uses ``-D`` fractional standard deviation, ``-C``
correlation lengths, and ``-U`` Hurst exponent. Gaussian, exponential, and
white-noise spectra are also available. One correlation length gives isotropic
statistics. x/y lengths give axis-aligned anisotropy. Rotated anisotropy is not
yet implemented.

Shared statistical options apply to every ``-F`` field, while repeatable
field/value forms override individual parameters. Fields use a common Gaussian
realization by default. ``-Q+i`` gives each field an independent realization,
and padding controls periodic edge effects. Every realization has zero mean
and its requested sample standard deviation before localization.

Without ``-A``, ``-R`` and ``-I`` define the output lattice and ``-F`` names
the NetCDF fields. Their output names receive an ``_heterogeneity`` suffix.
Without ``-F``, the field is named ``heterogeneity``. In application mode,
geometry is inherited unless ``-R`` or ``-I`` requests a subset or new regular
lattice. ``-H`` fills only enclosed horizontal NaN holes. Edge-connected NaNs
are preserved. Horizontal resampling follows and uses GMT's common ``-n``
interpolation setting. Each valid value then becomes ``m * (1 + epsilon)``.

Source coordinate and value scaling precedes gap filling and generation.
Scaling does not reorder data, and both transformed coordinates must be regular
and increasing. ``-Z`` applies final coordinate and field scaling without
reordering. When the lattice changes, scalar ancillary variables are retained,
while unselected variables tied to changed coordinates are omitted. Unresolved
missing values remain NaN.

``-P`` supplies an xy-monotone support. ``-EE`` and ``-EB`` convert a
non-monotone polygon using the selected BLEND envelope method, and ``+w``
writes the converted polygon. ``-W`` permits distinct x/y windows and symmetric
or side-specific taper ratios. The taper is shared by all fields, is applied
after normalization, and can be written as the ``weight`` variable with
``long_name="heterogeneity taper weight"`` and units ``1``.

Usage
-----

.. gq-usage:: ssh2d

Examples
--------

See :doc:`../examples/ssh2d/index`.

See also
--------

:doc:`ssh1d`, :doc:`ssh3d`, :doc:`../reference/statistical-models`

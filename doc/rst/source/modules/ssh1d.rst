ssh1d
=====

``ssh1d`` generates a statistically defined one-dimensional fractional
perturbation field or applies it multiplicatively to selected model fields
in multiparameter one-dimensional tables or NetCDF series. The perturbation
field can be tapered using similar functionality as in ``merge1d``.

Synopsis
--------

.. code-block:: bash

   gmt ssh1d [-A model] -Tmin/max/inc -Dstddev [statistics] -Goutput

Behavior
--------

The default model is von Karman, which is the noted preference for 
geophysical applications. Gaussian, exponential, and uncorrelated white
noise are also available. ``-D`` is the fractional standard deviation, ``-C``
is the correlation length, and ``-U`` is the Hurst exponent, which is required 
for the von Karman model. The generated realization is adjusted to zero mean 
and the requested sample standard deviation before tapering. Spectral padding 
is one correlation length by default and may be changed or disabled with ``-Q``.

Without ``-A``, ``-T`` defines a regular output axis and ``-F`` names one or
more heterogeneity fields. Text and NetCDF output are supported. With ``-A``,
the input may be a regular text table whose first column is the coordinate, or 
a NetCDF file. ``-F`` must name all selected data fields, and each finite model 
value is changed according to

.. math::

   m' = m(1 + \epsilon).

Input ``+x`` and ``+v`` transforms are applied before generation and
application. Their uppercase forms set target-unit metadata. Input scaling
does not reorder samples, and the transformed coordinate must be regular and
increasing. In application mode, ``-T`` resamples within the transformed input
domain using the method selected by ``-S``. The ``+g`` modifier bridges
internal missing runs, optionally up to a maximum gap measured in transformed
coordinate units. Without ``+g``, separate valid runs are interpolated
independently and gaps remain missing.

``-Z`` scales the output coordinate and selected fields after application and
may set final unit metadata. It also does not reorder samples, so a negative
output axis scale can restore a descending coordinate convention. Missing
values remain NaN, and valid values are not clipped.

``-L`` restricts the support to an interval. ``-W`` applies any BLEND window
inside it, with independent beginning and ending taper ratios. Tapering occurs
after statistical normalization, so the localized field is not renormalized.
The ``+w`` modifier adds the shared taper as ``weight`` in NetCDF output or as
the final column of text output. Its NetCDF ``long_name`` is
``heterogeneity taper weight`` and its units are ``1``.

Usage
-----

.. gq-usage:: ssh1d

Examples
--------

See :doc:`../examples/ssh1d/index`.

See also
--------

:doc:`ssh2d`, :doc:`ssh3d`, :doc:`../reference/statistical-models`

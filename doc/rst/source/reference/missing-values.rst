Missing Values
==============

Recognition
-----------

GQ recognizes IEEE NaNs and declared NetCDF ``_FillValue`` and
``missing_value`` attributes. Use ``+n<value>`` on an input source when a file
uses an undeclared sentinel such as ``-99999``. For text input, GMT's ``-di``
option may also identify the input nodata value.

Output missing values are written as NaN.

Merge precedence
----------------

Interpolation, when enabled, is attempted before optional replacement from a
paired secondary. Any holes left after interpolation may be filled by the
secondary only when the corresponding replacement option is selected. The
default is to preserve primary missing values.

At an ordinary merge node where one member of an active primary/secondary
pair is finite and the other is missing, the finite member is used according
to the module's selected missing-value behavior. If neither member is finite,
the result is NaN.

Gap interpolation
-----------------

``merge1d``, ``ssh1d``, and vertical interpolation in ``merge3d`` and
``ssh3d`` remain within contiguous valid runs by default. Their ``-S+g`` gap
modifiers bridge internal runs subject to an optional maximum coordinate span,
but do not extrapolate beyond the first or last valid sample.

``merge2d``, ``merge3d``, ``topobath``, ``elygtl``, ``ssh2d``, and ``ssh3d``
use ``-H`` to interpolate strictly internal horizontal holes before resampling
and subsequent operations. Edge-connected missing regions remain missing. In
the three-dimensional modules, ``-H`` operates independently on each native
x-y layer, while ``-S+g`` controls internal vertical gaps.

SSH application
---------------

After requested gap filling and resampling, unresolved model values remain
missing when an SSH field is applied. Valid values are multiplied by the
perturbation factor.

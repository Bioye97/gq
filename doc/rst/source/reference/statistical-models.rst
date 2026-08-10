Small-Scale Heterogeneity Models
================================

The ``ssh1d``, ``ssh2d``, and ``ssh3d`` modules generate fractional
perturbations with zero mean and a user-specified sample standard deviation 
before local tapering.

Models
------

von Karman
   The default model. It uses correlation length ``-C`` and Hurst exponent
   ``-U``. The default Hurst exponent is 0.15. This is the preferred default
   for geophysical applications.

Gaussian
   A smooth correlated model controlled by ``-C``.

Exponential
   A rougher correlated model controlled by ``-C``.

White noise
   Uncorrelated samples. Correlation length and Hurst exponent are not used here.

Anisotropy
----------

One correlation length produces isotropic statistics. A length for each
coordinate dimension produces axis-aligned anisotropy. Rotated anisotropy is
not yet implemented.

Multiple fields
---------------

Shared ``-D``, ``-C``, and ``-U`` values apply to every selected field.
Repeatable field/value forms override one parameter. Multidimensional SSH
modules use a shared underlying Gaussian realization by default so equivalent
statistics produce equivalent patterns apart from scale. The independent
seed modifier creates a separate realization for each field.

Application
-----------

In application mode a model value ``m`` becomes ``m(1 + epsilon)``. The same
taper is used for all selected fields, while each field may retain distinct
statistical parameters.

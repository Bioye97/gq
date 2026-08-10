elygtl
======

``elygtl`` applies the Ely geotechnical layering method to dry columns of a
three-dimensional multiparamter NetCDF model using a Vs30 grid and either a 
constant or spatially variable transition depth. This is one of the modules
that applies specifically to seismic wavespeed model parameters.

Synopsis
--------

.. code-block:: bash

   gmt elygtl model.nc vs30.nc -Goutput.nc -Fvs=vs [options]

Behavior
--------

``-F`` maps existing Vp, Vs, and optional density variables. At least Vp or Vs
is required. ``-C`` may create a property that is absent from the source:
Brocher relationships convert between Vp and Vs, and density is obtained from
final Vp with the Nafe-Drake relationship. Newly created properties are inferred
throughout the eligible solid model, not only inside the GTL. Existing
properties are otherwise retained outside the GTL.

For normalized depth ``q`` from the local surface to the transition depth,
the Ely profile uses

.. math::

   f(q) = q + \frac{2}{3}(q-q^2),

.. math::

   g(q) = \frac{1}{2} - \frac{q}{2}
          + \frac{3}{2}(q^2 + 2\sqrt{q} - 3q),

and combines the transition-depth value with the Vs30-derived surface value:

.. math::

   V(q) = f(q)V_T + g(q)V_{30}.

The local surface is the shallowest finite value in the available Vp or Vs
field. The transition thickness is 350 m by default and may be replaced by a
positive constant or a spatially variable grid with ``-E``. The anchor is
sampled with the vertical interpolation selected by ``-S``, so the GTL meets
the original model there. ``-T`` may replace the model z lattice, and the
``+g`` modifier of ``-S`` bridges internal missing layers when requested.

Calculations use metres, seconds, m/s, and kg/m3 internally. Lowercase source
modifiers first transform stored coordinates and properties. ``-U`` then
converts velocities and density to SI and applies the inverse conversion on
output. After input scaling, x, y, and z must be strictly increasing and z must
be positive down. Scaling does not reorder layers or data. ``-Z`` independently
scales output coordinates and properties after the Ely calculation, making it
possible to restore a preferred positive-up or positive-down convention without
changing the data layering order.

``-H`` fills strictly internal holes in native horizontal layers before
resampling. ``-R`` must lie within the transformed model domain, and ``-I`` may
resample mapped properties, Vs30, transition thickness, and the wet mask
horizontally. Common option ``-n`` controls this horizontal interpolation.
``-T`` defines an increasing positive-down output z lattice, while ``-S``
controls vertical interpolation and optional internal-gap bridging. None of
these operations extrapolates beyond the model footprint.

Wet columns are identified using the same GSHHG hierarchy or user-mask scheme
as in ``topobath``. ``-Mg`` gives GMT shoreline classification priority, ``-Mm``
gives selected model evidence priority, and ``-Ml`` or ``-Mw`` classifies the
complete domain as land or wet. A ``-K`` mask is authoritative. The
``+e<vs30|vp|vs|rho>`` modifier selects the model evidence. Vs30 is the default. 
For a mapped cube property, a shallowest finite sample above sea level indicates
land and one below sea level indicates wet. At sea level, ``+w`` supplies the
water value and ``+t`` its matching tolerance. Model Vs defaults to zero in
water, while Vp and density require an explicit water value. These values use
transformed model units before ``-U`` conversion.

Unselected compatible variables, coordinates, and metadata are copied to the
output. When ``-R``, ``-I``, or ``-T`` changes a coordinate lattice, unselected
variables that depend on a changed coordinate are omitted while compatible
variables and scalar metadata are retained in the NetCDF file.

Usage
-----

.. gq-usage:: elygtl

Examples
--------

See :doc:`../examples/elygtl/index`.

See also
--------

:doc:`topobath`, :doc:`../reference/scaling-units`,
:doc:`../reference/missing-values`

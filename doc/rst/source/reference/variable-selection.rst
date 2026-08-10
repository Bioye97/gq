NetCDF Variable Selection
=========================

Selectors
---------

Select NetCDF fields by appending ``?`` and a comma-separated list to the
NetCDF filename:

.. code-block:: text

   model.nc?vp,vs,rho

Use quotations for selectors containing shell-sensitive square brackets or 
parentheses. If ``?`` is omitted, the module uses its documented default 
field-selection behavior. Input modifiers follow the selected field list, 
for example ``model.nc?vp,vs+x0.001+Xkm+v0.001,0.001+Vkm/s,km/s`` scales
an input axis in metres to kilometres and the selected fields from m/s to
km/s. A selector containing only modifiers, such as
``model.nc?+x0.001+Xkm``, applies them to the default field without naming it.
An undeclared numeric missing sentinel may be defined with ``+n``.

Positional mapping
------------------

The merge modules map selected variables by position, so source names may be
different when they represent equivalent quantities. For exammple, given:

.. code-block:: text

   model1.nc?vp,vs,den
   model2.nc?p,s,d

the option ``-Fvp,vs,rho`` writes both triples as ``vp``, ``vs``, and ``rho``.
Every source record must list equivalent variables in the same order.
``-F`` names output variables. It does not select variables from an input
file.

A single explicit selector retains its source name when ``-F`` is omitted.
When neither a selector nor ``-F`` supplies a name and one default field is
used, the merge output variable is named ``z``.

Input selector modifiers are applied before interpolation and merging. The
merge modules use ``-Z`` for transforms applied to the completed output. A
single field scale or unit is broadcast. Otherwise, values follow ``-F``
order when ``-F`` is supplied and selector order otherwise. ``-Z`` scales
output coordinates and fields in place and does not reorder coordinates,
fields, or weights. See :doc:`scaling-units` for the full processing order 
and modifier meanings.

Selecting a 3-D layer in merge2d
---------------------------------

Use a zero-based index in square brackets:

.. code-block:: bash

   gmt merge2d 'model.nc?vs[3]' ...

Use parentheses to select the layer nearest a coordinate value without
vertical interpolation:

.. code-block:: bash

   gmt merge2d 'model.nc?vs(20)' ...

For multiple variables, give one layer selector per field. Source coordinate
scaling is applied before coordinate-value selection, so ``(20)`` is
interpreted in the transformed/scaled source coordinate system.

Property mappings
-----------------

``elygtl`` uses explicit semantic mappings such as ``-Fvp=p,vs=s,rho=density``
because its calculations rely on seismic wavespeed properties. At least Vp
or Vs must be mapped. ``-C`` names properties to create when they are entirely
absent from the model.

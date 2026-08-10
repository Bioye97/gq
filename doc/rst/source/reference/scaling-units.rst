Scaling and Units
=================

Processing order
----------------

GQ decodes NetCDF ``scale_factor`` and ``add_offset`` packing and sets
missing values before applying user-specified transforms. Numerical source 
transforms therefore operate on unpacked values. Geometry selection,
interpolation, support polygon tests, and merging use the transformed 
coordinates and fields.

Input transforms
----------------

Lowercase modifiers apply numerical scales to an input source:

* ``+x``, ``+y``, and ``+z`` scale coordinate axes.
* ``+v`` scales selected field values.

Uppercase ``+X``, ``+Y``, ``+Z``, and ``+V`` assign target-unit metadata to
the corresponding transformed values. A single field scale or unit is
broadcast. Otherwise lists follow selector or ``-F`` order.

For example, a source with negative-down depth in metres can use
``+z-0.001+Zkm`` to produce an increasing positive-down coordinate in
kilometres. In the merge, ``topobath``, ``elygtl``, and SSH modules, input
coordinate scaling does not reorder coordinates or associated data. Every
transformed input axis must instead be strictly increasing. Use a negative
input scale when it makes a decreasing source axis increase, and use output
``-Z`` to restore a coordinate convention of your choosing.

For example, ``+z-1/1000+Zkm`` converts a source z axis stored as
``4000 ... -16000 m`` to ``-4 ... 16 km`` in the same sample order. After
merging, ``-Z+z-1000+Zm`` restores the original decreasing convention without
reordering any data. Thus, parameters defined at -4 km are still the same
at 4000 m.

Output transforms
-----------------

The merge, ``topobath``, ``elygtl``, and SSH modules provide ``-Z`` for output
coordinate and field transforms.
The lowercase modifiers scale output values, while uppercase modifiers set
their unit metadata. Field scales and units are positional for
multiparameter output. ``-Z`` scales output coordinates and fields in place and
does not reorder coordinates, fields, or weights. A negative axis scale
therefore writes that coordinate in decreasing order.

In ``topobath``, field scales and units follow the selected model-field order.
Its coordinate modifiers also transform the optional ``-Q`` diagnostic grids,
but classification codes cannot be scaled. Please consult the usage at 
:doc:`../modules/index` for the complete accepted syntax in each module.

For SSH application, source scaling occurs before gap filling and resampling,
so correlation lengths and maximum vertical gap spans are interpreted in the
transformed working units. ``-Z`` follows heterogeneity generation, tapering,
and model application. Field scales and units follow ``-F`` ordering.

Topobath convention
-------------------

``topobath`` applies source scaling first and then works in the resulting
vertical convention. The transformed model z coordinate must increase from
top to bottom, with negative elevations above sea level and positive depths
below it. Transformed old and new topography values must use the same signs. 
Use a model ``+z`` scale and a surface ``+v`` or ``+z`` scale to standardize 
inputs before ``-T<zmin>/<zmax>/<dz>`` is interpreted. ``-Z`` is a final output
transform for x, y, z, and selected model fields. A negative axis scale may
restore a preferred convention without reordering coordinates or model
layers.

Ely GTL units
-------------

``elygtl`` calculates in metres, seconds, m/s, and kg/m3. Input transforms
standardize stored data before the module's unit conversion.

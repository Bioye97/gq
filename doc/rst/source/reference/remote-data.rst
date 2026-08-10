GMT Remote Data
===============

All GQ input filenames accept GMT's ``@`` remote-data notation and  `data <https://www.generic-mapping-tools.org/remote-datasets/>`_. 
GMT downloads the named dataset when it is first required and reuses its cached 
local copy in later runs. For example:

.. code-block:: bash

   gmt topobath model.nc?vp,vs @earth_relief_01d_g+z-0.001 \
       -Gtopographic.nc -Oa -Mp -Wvp/1.5 -Wvs/0

Selectors and GQ input modifiers remain attached to the remote name:

.. code-block:: text

   @model.nc?vp,vs+z-0.001

Remote notation may be used for model files, text tables, mergefiles, polygon
supports, masks, and auxiliary grids. A first run requires network access and
may be slower. Documentation builds use the scripts and figures already stored
with GQ and do not execute examples or download remote data.

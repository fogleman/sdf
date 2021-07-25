"""
Copyright 2010 Lars Kruse <devel@sumpfralle.de>

This file is part of PyCAM.

PyCAM is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

PyCAM is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with PyCAM.  If not, see <http://www.gnu.org/licenses/>.
"""

import os
import tempfile

from pycam.errors import AbortOperationException, LoadFileError
from pycam.Importers.SVGImporter import convert_eps2dxf
import pycam.Importers.DXFImporter
import pycam.Utils
from pycam.Utils.locations import create_named_temporary_file

log = pycam.Utils.log.get_logger()


def import_model(filename, program_locations=None, unit="mm", callback=None, **kwargs):
    local_file = False
    if hasattr(filename, "read"):
        infile = filename
        ps_file_handle, ps_file_name = tempfile.mkstemp(suffix=".ps")
        try:
            temp_file = os.fdopen(ps_file_handle, "w")
            temp_file.write(infile.read())
            temp_file.close()
        except IOError as exc:
            raise LoadFileError("PSImporter: Failed to create temporary local file ({}): {}"
                                .format(ps_file_name, exc))
        filename = ps_file_name
    else:
        uri = pycam.Utils.URIHandler(filename)
        if not uri.exists():
            raise LoadFileError("PSImporter: file ({}) does not exist".format(filename))
        if not uri.is_local():
            # non-local file - write it to a temporary file first
            ps_file_handle, ps_file_name = tempfile.mkstemp(suffix=".ps")
            os.close(ps_file_handle)
            log.debug("Retrieving PS file for local access: %s -> %s", uri, ps_file_name)
            if not uri.retrieve_remote_file(ps_file_name, callback=callback):
                raise LoadFileError("PSImporter: Failed to retrieve the PS model file: {} -> {}"
                                    .format(uri, ps_file_name))
            filename = ps_file_name
        else:
            filename = uri.get_local_path()
            local_file = True

    if program_locations and "pstoedit" in program_locations:
        pstoedit_path = program_locations["pstoedit"]
    else:
        pstoedit_path = None

    def remove_temp_file(filename):
        if os.path.isfile(filename):
            try:
                os.remove(filename)
            except OSError as exc:
                log.warning("PSImporter: failed to remove temporary file ({}): {}"
                            .format(filename, exc))

    # convert eps to dxf via pstoedit
    with create_named_temporary_file(suffix=".dxf") as dxf_file_name:
        success = convert_eps2dxf(filename, dxf_file_name, unit=unit, location=pstoedit_path)
        if not local_file:
            remove_temp_file(ps_file_name)
        if not success:
            raise LoadFileError("Failed to convert EPS to DXF file")
        elif callback and callback():
            raise AbortOperationException("PSImporter: load model operation cancelled")
        else:
            log.info("Successfully converted PS file to DXF file")
            # pstoedit uses "inch" -> force a scale operation
            return pycam.Importers.DXFImporter.import_model(dxf_file_name, unit=unit,
                                                            callback=callback)

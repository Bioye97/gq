#include <netcdf.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define CHECK(call) do { \
	int status_ = (call); \
	if (status_ != NC_NOERR) { \
		fprintf(stderr, "%s: %s\n", #call, nc_strerror(status_)); \
		return EXIT_FAILURE; \
	} \
} while (0)

struct field {
	const char *name;
	const char *path;
	int input;
	int variable;
};

static int data_variable(int ncid, int *variable)
{
	int nvariables, candidate = -1;
	CHECK(nc_inq_nvars(ncid, &nvariables));
	for (int id = 0; id < nvariables; id++) {
		int ndims;
		CHECK(nc_inq_varndims(ncid, id, &ndims));
		if (ndims == 3) {
			if (candidate >= 0) {
				fprintf(stderr, "Input cube contains more than one 3-D field\n");
				return EXIT_FAILURE;
			}
			candidate = id;
		}
	}
	if (candidate < 0) {
		fprintf(stderr, "Input cube does not contain a 3-D field\n");
		return EXIT_FAILURE;
	}
	*variable = candidate;
	return EXIT_SUCCESS;
}

static int copy_text_attribute(int input, int input_var, const char *name,
	                           int output, int output_var)
{
	size_t length;
	char *value;
	if (nc_inq_attlen(input, input_var, name, &length) != NC_NOERR)
		return NC_NOERR;
	value = malloc(length + 1);
	if (!value) return NC_ENOMEM;
	if (nc_get_att_text(input, input_var, name, value) == NC_NOERR)
		nc_put_att_text(output, output_var, name, length, value);
	free(value);
	return NC_NOERR;
}

int main(int argc, char **argv)
{
	int reference, output, dimensions[3], coordinates[3], coordinate_out[3];
	int reference_variable, source_dimensions[3];
	int output_fields[16];
	size_t lengths[3], total = 1;
	struct field fields[16];
	double *coordinate = NULL;
	float *values = NULL;

	if (argc < 4 || argc > 18) {
		fprintf(stderr, "usage: %s output.nc name=cube.nc [name=cube.nc ...]\n",
		        argv[0]);
		return EXIT_FAILURE;
	}
	for (int k = 2; k < argc; k++) {
		char *equals = strchr(argv[k], '=');
		if (!equals || equals == argv[k] || !equals[1]) {
			fprintf(stderr, "Invalid field source: %s\n", argv[k]);
			return EXIT_FAILURE;
		}
		*equals = '\0';
		fields[k - 2].name = argv[k];
		fields[k - 2].path = equals + 1;
	}

	CHECK(nc_open(fields[0].path, NC_NOWRITE, &reference));
	if (data_variable(reference, &reference_variable)) return EXIT_FAILURE;
	CHECK(nc_inq_vardimid(reference, reference_variable, source_dimensions));
	for (int axis = 0; axis < 3; axis++) {
		char source_name[NC_MAX_NAME + 1];
		int source_position = 2 - axis;
		CHECK(nc_inq_dimlen(reference, source_dimensions[source_position],
		                    &lengths[axis]));
		CHECK(nc_inq_dimname(reference, source_dimensions[source_position],
		                     source_name));
		CHECK(nc_inq_varid(reference, source_name, &coordinates[axis]));
		total *= lengths[axis];
	}

	for (int k = 0; k < argc - 2; k++) {
		CHECK(nc_open(fields[k].path, NC_NOWRITE, &fields[k].input));
		if (data_variable(fields[k].input, &fields[k].variable))
			return EXIT_FAILURE;
		CHECK(nc_inq_vardimid(fields[k].input, fields[k].variable,
		                       source_dimensions));
		for (int axis = 0; axis < 3; axis++) {
			size_t length;
			CHECK(nc_inq_dimlen(fields[k].input,
			                    source_dimensions[2 - axis], &length));
			if (length != lengths[axis]) {
				fprintf(stderr, "%s has incompatible dimensions\n", fields[k].path);
				return EXIT_FAILURE;
			}
		}
	}

	CHECK(nc_create(argv[1], NC_NETCDF4 | NC_CLOBBER, &output));
	for (int axis = 0; axis < 3; axis++) {
		char axis_name[2] = {"xyz"[axis], '\0'};
		CHECK(nc_def_dim(output, axis_name, lengths[axis], &dimensions[axis]));
		CHECK(nc_def_var(output, axis_name, NC_DOUBLE, 1, &dimensions[axis],
		                 &coordinate_out[axis]));
		copy_text_attribute(reference, coordinates[axis], "long_name",
		                    output, coordinate_out[axis]);
		copy_text_attribute(reference, coordinates[axis], "units",
		                    output, coordinate_out[axis]);
		CHECK(nc_put_att_text(output, coordinate_out[axis], "axis", 1,
		                      axis_name));
	}
	for (int k = 0; k < argc - 2; k++) {
		float missing = NC_FILL_FLOAT;
		int dims[3] = {dimensions[2], dimensions[1], dimensions[0]};
		CHECK(nc_def_var(output, fields[k].name, NC_FLOAT, 3, dims,
		                 &output_fields[k]));
		CHECK(nc_put_att_float(output, output_fields[k], "_FillValue", NC_FLOAT,
		                       1, &missing));
		copy_text_attribute(fields[k].input, fields[k].variable, "long_name",
		                    output, output_fields[k]);
		copy_text_attribute(fields[k].input, fields[k].variable, "units",
		                    output, output_fields[k]);
		CHECK(nc_def_var_deflate(output, output_fields[k], 1, 1, 3));
	}
	CHECK(nc_put_att_text(output, NC_GLOBAL, "Conventions", 6, "CF-1.7"));
	CHECK(nc_enddef(output));

	for (int axis = 0; axis < 3; axis++) {
		coordinate = realloc(coordinate, lengths[axis] * sizeof(*coordinate));
		if (!coordinate) return EXIT_FAILURE;
		CHECK(nc_get_var_double(reference, coordinates[axis], coordinate));
		CHECK(nc_put_var_double(output, coordinate_out[axis], coordinate));
	}
	values = malloc(total * sizeof(*values));
	if (!values) return EXIT_FAILURE;
	for (int k = 0; k < argc - 2; k++) {
		CHECK(nc_get_var_float(fields[k].input, fields[k].variable, values));
		CHECK(nc_put_var_float(output, output_fields[k], values));
	}

	free(values);
	free(coordinate);
	for (int k = 0; k < argc - 2; k++) CHECK(nc_close(fields[k].input));
	CHECK(nc_close(reference));
	CHECK(nc_close(output));
	return EXIT_SUCCESS;
}

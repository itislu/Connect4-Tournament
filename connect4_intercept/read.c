#define _GNU_SOURCE
#include "defines.h"
#include <dlfcn.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

static ssize_t (*og_read)(int fd, void *buf, size_t nbytes) = NULL;
static int first_col_index = 0;
static int slowdown = DEFAULT_SLOWDOWN;
static bool initialized = false;
static void adjust_index(ssize_t *ret, char *buf);
static void initialize(void);

ssize_t read(int fd, void *buf, size_t nbytes)
{
	if (!initialized) {
		initialize();
	}

	ssize_t ret = og_read(fd, buf, nbytes);
	printf("Got %d%s\n",
	       atoi(buf) + first_col_index,
	       (slowdown > 0) ? ", slowing the game down..." : "");
	adjust_index(&ret, buf);
	sleep(slowdown);
	return ret;
}

static void adjust_index(ssize_t *ret, char *buf)
{
	*ret = snprintf(buf, *ret + 2, "%d\n", atoi(buf) + first_col_index);
}

static void initialize(void)
{
	// Load original function
	og_read = (ssize_t(*)(int, void *, size_t))dlsym(RTLD_NEXT, "read");
	if (!og_read) {
		fprintf(stdout, "Error finding original read function\n");
		exit(1);
	}

	// Get index type from environment variable
	char *env_first_col_index = getenv(ENV_FIRST_COL_INDEX);
	if (env_first_col_index != NULL) {
		first_col_index = atoi(env_first_col_index);
	}

	// Get read slowdown from environment variable
	char *env_slowdown = getenv(ENV_READ_SLOWDOWN);
	if (env_slowdown != NULL) {
		int time = atoi(env_slowdown);
		if (time >= 0) {
			slowdown = time;
		}
	}

	initialized = true;
}

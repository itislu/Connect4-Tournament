#define _GNU_SOURCE
#include "defines.h"
#include <dlfcn.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdio.h>
#include <stdlib.h>

static int (*og_rand)(void) = NULL;
static int rand_number = 0;
static bool initialized = false;
static void initialize(void);

int rand(void)
{
	if (!initialized) {
		initialize();
	}

	return rand_number;
}

static void initialize(void)
{
	// Load original function
	og_rand = (int(*)(void))dlsym(RTLD_NEXT, "rand");
	if (!og_rand) {
		fprintf(stdout, "Error finding original rand function\n");
		exit(1);
	}

	// Get number to return from environment variable
	char *env_rand_number = getenv(ENV_RAND_NUMBER);
	if (env_rand_number != NULL) {
		rand_number = atoi(env_rand_number);
	}

	initialized = true;
}

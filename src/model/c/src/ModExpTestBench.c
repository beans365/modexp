#include <stdio.h>
#include <stdlib.h>
#include "simple_tests.h"
#include "autogenerated_tests.h"
#include "montgomery_array_test.h"

int main(void) {
  simple_tests();
  autogenerated_tests();
  montgomery_array_tests(0);

  return EXIT_SUCCESS;
}

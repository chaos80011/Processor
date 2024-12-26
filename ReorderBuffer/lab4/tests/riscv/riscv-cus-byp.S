#include "riscv-macros.h"

        TEST_RISCV_BEGIN

        li    x2, 2
        mul   x3, x2, x2
        li    x5, 5
        add   x4, x5, x5
        TEST_CHECK_EQ( x4, 10 )

        TEST_RISCV_END